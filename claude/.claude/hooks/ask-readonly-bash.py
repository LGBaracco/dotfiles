#!/usr/bin/env python3
"""PreToolUse hook for Claude Code's Ask mode: allow only read-only Bash.

Inactive (exits silently, normal permission flow applies) unless one of:
  --force argument (used by the /ask skill), CLAUDE_ASK_MODE=1 in the
  environment (set by the `ask` fish alias, inherited by subagents), or
  agent_type == "ask" in the hook input.

When active, every Bash command is either auto-allowed (no prompt) or denied
with a reason Claude can act on. Edit the tables below to extend it.
"""

import json
import os
import re
import shlex
import sys

# -- Tables -------------------------------------------------------------------

# Commands with no write or exec capability: allowed with any arguments.
PLAIN = {
    "ls", "eza", "cat", "head", "tail", "wc", "pwd", "echo", "printf", "which",
    "type", "stat", "du", "df", "diff", "cmp", "realpath", "readlink",
    "basename", "dirname", "cut", "tr", "column", "nl", "grep", "uname",
    "whoami", "id", "test", "[", "true", "false", "cd", "nvd", "shellcheck",
    "jq", "printenv", "md5sum", "sha1sum", "sha256sum",
}

# Commands checked by a dedicated function below.
GUARDED = {"rg", "fd", "find", "sort", "uniq", "yq", "bat", "xargs", "command",
           "git", "gh", "nix", "nix-instantiate", "nh"}

# Unquoted globs on these could expand into a dangerous flag (e.g. -delete).
GLOB_SENSITIVE = GUARDED - {"command"}

# Leading VAR=value assignments that are allowed before a command.
SAFE_ENV = {"LC_ALL", "LANG", "NO_COLOR", "TERM", "COLUMNS"}

# Redirections that are harmless and stripped before parsing.
HARMLESS_REDIRECT = re.compile(r"(?<!\S)(?:[012]?>>?|&>)\s*/dev/null(?!\S)|(?<!\S)[12]>&[12](?!\S)")

SEPARATORS = {"|", "||", "&&", ";", "\n"}

GIT_SUBCOMMANDS = {
    "status", "log", "show", "diff", "blame", "shortlog", "describe",
    "rev-parse", "ls-files", "ls-tree", "cat-file", "grep", "merge-base",
    "show-ref", "for-each-ref", "ls-remote", "reflog", "branch", "tag",
    "remote", "stash", "config", "worktree", "rev-list", "name-rev", "help",
    "version",
}
GIT_DENY_ANYWHERE = ("--output", "--ext-diff", "--upload-pack", "--exec", "--open-files-in-pager")

GH_GROUPS = {"pr", "issue", "run", "release", "repo", "workflow"}
GH_ACTIONS = {"view", "list", "status", "diff", "checks"}

NIX_SUBCOMMANDS = {("eval",), ("search",), ("path-info",), ("why-depends",),
                   ("flake", "show"), ("flake", "metadata")}
NIX_DENY = ("--option", "--write-to", "--recreate-lock-file", "--update-input",
            "--commit-lock-file", "--output-lock-file", "--override-input",
            "--allow-unsafe-native-code-during-evaluation")


class Deny(Exception):
    pass


# -- Helpers ------------------------------------------------------------------

def short_flags(args):
    """Characters of all bundled short options, e.g. -Hx -> {'H', 'x'}."""
    chars = set()
    for a in args:
        if re.fullmatch(r"-[A-Za-z]+", a):
            chars.update(a[1:])
    return chars


def has_long(args, *names):
    return any(a == n or a.startswith(n + "=") for a in args for n in names)


def positionals(args):
    return [a for a in args if not a.startswith("-")]


def scan(cmd):
    """Return (command_substitution, unquoted_glob) by tracking quote state."""
    subst = glob = False
    state = None  # None, "'", '"'
    i = 0
    while i < len(cmd):
        c = cmd[i]
        if state == "'":
            if c == "'":
                state = None
        elif c == "\\":
            i += 1
        elif c == "`" or (c == "$" and cmd[i + 1:i + 2] == "("):
            subst = True
        elif state == '"':
            if c == '"':
                state = None
        elif c in "'\"":
            state = c
        elif c in "*?[":
            glob = True
        elif c == "{":
            word = re.match(r"\{[^\s}]*\}", cmd[i:])
            if word and ("," in word.group() or ".." in word.group()):
                glob = True
        i += 1
    return subst, glob


def tokenize(cmd):
    lex = shlex.shlex(cmd, posix=True, punctuation_chars="();<>|&\n")
    lex.whitespace = " \t\r"
    lex.commenters = ""  # `#` mid-word (nix .#attr) is not a comment
    lex.whitespace_split = True
    return list(lex)


# -- Per-command checks -------------------------------------------------------

def check_rg(args):
    if has_long(args, "--pre"):
        raise Deny("rg --pre runs an external program")


def check_fd(args):
    if has_long(args, "--exec", "--exec-batch") or short_flags(args) & {"x", "X"}:
        raise Deny("fd -x/-X executes commands; list files and read them instead")


def check_find(args):
    bad = {"-delete", "-exec", "-execdir", "-ok", "-okdir", "-fls", "-fprint",
           "-fprint0", "-fprintf"}
    if bad & set(args):
        raise Deny("find actions that write or execute are not allowed")


def check_sort(args):
    if has_long(args, "--output", "--compress-program") or "o" in short_flags(args):
        raise Deny("sort -o writes a file")


def check_uniq(args):
    if len([a for a in positionals(args) if not a.isdigit()]) > 1:
        raise Deny("uniq with two file arguments writes the second one")


def check_yq(args):
    if has_long(args, "--in-place", "--inplace") or "i" in short_flags(args):
        raise Deny("yq -i edits files in place")


def check_bat(args):
    if positionals(args)[:1] == ["cache"] or has_long(args, "--generate-config-file", "--pager"):
        raise Deny("bat cache/--pager/--generate-config-file are not read-only")


def check_xargs(args):
    takes_value = {"-I", "-n", "-P", "-L", "-d", "-E", "-s", "-a"}
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in takes_value else 1
    if i < len(args):
        check_segment(args[i:])


def check_command(args):
    if not args or args[0] not in ("-v", "-V"):
        raise Deny("only `command -v` is allowed")


def check_git(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        a = args[i]
        if a in ("-c", "--config-env") or a.startswith(("--config-env", "--exec-path")):
            raise Deny("git -c/--config-env/--exec-path can run arbitrary programs")
        i += 2 if a in ("-C", "--git-dir", "--work-tree") else 1
    if i == len(args):
        return
    sub, rest = args[i], args[i + 1:]
    if sub not in GIT_SUBCOMMANDS:
        raise Deny(f"git {sub} is not a read-only subcommand")
    if has_long(rest, *GIT_DENY_ANYWHERE):
        raise Deny("git --output/--ext-diff/--upload-pack/--exec are not allowed")
    pos = positionals(rest)
    if sub == "grep" and "O" in short_flags(rest):
        raise Deny("git grep -O opens files in a pager program")
    if sub == "ls-remote" and "u" in short_flags(rest):
        raise Deny("git ls-remote -u runs a custom upload-pack program")
    if sub == "reflog" and pos[:1] and pos[0] in ("expire", "delete"):
        raise Deny("git reflog expire/delete modifies the reflog")
    if sub in ("branch", "tag"):
        write = ({"d", "D", "m", "M", "c", "C", "f", "u", "t"} if sub == "branch"
                 else {"a", "s", "u", "d", "f", "m", "F", "e"})
        if short_flags(rest) & write or has_long(
                rest, "--delete", "--move", "--copy", "--force", "--set-upstream-to",
                "--unset-upstream", "--edit-description", "--track", "--annotate",
                "--sign", "--message", "--file", "--create-reflog"):
            raise Deny(f"git {sub} with write flags is not allowed")
        listing = "l" in short_flags(rest) or "--list" in rest
        filters = {"--contains", "--no-contains", "--merged", "--no-merged", "--points-at",
                   "--sort", "--format", "--color", "--column"}
        stray = [a for j, a in enumerate(rest)
                 if not a.startswith("-") and not (j and rest[j - 1] in filters)]
        if stray and not listing:
            raise Deny(f"git {sub} <name> creates a {sub}; use --list to filter")
    if sub == "remote" and pos[:1] and pos[0] not in ("show", "get-url"):
        raise Deny("only `git remote [-v|show|get-url]` is allowed")
    if sub == "stash" and pos[:1] != ["list"] and pos[:1] != ["show"]:
        raise Deny("only `git stash list/show` is allowed")
    if sub == "worktree" and pos[:1] != ["list"]:
        raise Deny("only `git worktree list` is allowed")
    if sub == "config":
        reading = has_long(rest, "--get", "--get-all", "--get-regexp", "--get-urlmatch",
                           "--list") or "l" in short_flags(rest) or pos[:1] in (["get"], ["list"])
        writing = has_long(rest, "--add", "--unset", "--unset-all", "--replace-all",
                           "--rename-section", "--remove-section", "--edit") or "e" in short_flags(rest)
        if not reading or writing:
            raise Deny("only reading git config (--get*/--list) is allowed")


def check_gh(args):
    if has_long(args, "--web") or "w" in short_flags(args):
        raise Deny("gh --web opens a browser")
    pos = positionals(args)
    if pos[:1] == ["search"] or pos[:2] == ["auth", "status"]:
        return
    if pos[:1] == ["api"]:
        for j, a in enumerate(args):
            method = None
            if a in ("-X", "--method") and j + 1 < len(args):
                method = args[j + 1]
            elif a.startswith("--method="):
                method = a.split("=", 1)[1]
            elif re.fullmatch(r"-X\w+", a):
                method = a[2:]
            if method is not None and method.upper() != "GET":
                raise Deny("gh api is limited to GET requests")
        if has_long(args, "--field", "--raw-field", "--input") or {"f", "F"} & short_flags(args):
            raise Deny("gh api with fields/input sends a POST")
        return
    if len(pos) >= 2 and pos[0] in GH_GROUPS and pos[1] in GH_ACTIONS:
        return
    raise Deny("gh is limited to view/list/status/diff/checks, search, and GET api calls")


def check_nix(args):
    if has_long(args, *NIX_DENY):
        raise Deny("that nix option can write files or enable unsafe evaluation")
    pos = positionals(args)
    if tuple(pos[:1]) not in NIX_SUBCOMMANDS and tuple(pos[:2]) not in NIX_SUBCOMMANDS:
        raise Deny("nix is limited to eval, search, path-info, why-depends, flake show/metadata")
    if "--no-write-lock-file" not in args:
        raise Deny("add --no-write-lock-file so nix cannot rewrite flake.lock")


def check_nix_instantiate(args):
    if "--eval" not in args:
        raise Deny("nix-instantiate is only allowed with --eval")
    if has_long(args, "--add-root", "--read-write-mode", *NIX_DENY) or "r" in short_flags(args):
        raise Deny("nix-instantiate store-writing options are not allowed")


def check_nh(args):
    if positionals(args)[:1] != ["search"]:
        raise Deny("only `nh search` is allowed")


CHECKS = {
    "rg": check_rg, "fd": check_fd, "find": check_find, "sort": check_sort,
    "uniq": check_uniq, "yq": check_yq, "bat": check_bat, "xargs": check_xargs,
    "command": check_command, "git": check_git, "gh": check_gh, "nix": check_nix,
    "nix-instantiate": check_nix_instantiate, "nh": check_nh,
}


# -- Driver -------------------------------------------------------------------

def check_segment(words):
    while words and re.match(r"[A-Za-z_][A-Za-z0-9_]*=", words[0]):
        var = words[0].split("=", 1)[0]
        if var not in SAFE_ENV:
            raise Deny(f"setting {var} is not allowed")
        words = words[1:]
    if not words:
        return
    head, args = words[0], words[1:]
    if "/" in head:
        raise Deny(f"run commands by name, not path ({head})")
    if head in PLAIN:
        return
    if head in CHECKS:
        CHECKS[head](args)
        return
    raise Deny(f"`{head}` is not on the read-only allowlist")


def check(cmd):
    cmd = HARMLESS_REDIRECT.sub(" ", cmd)
    subst, glob = scan(cmd)
    if subst:
        raise Deny("command substitution ($(...) or backticks) is not allowed")
    try:
        tokens = tokenize(cmd)
    except ValueError as e:
        raise Deny(f"could not parse command ({e})")
    segments, current = [], []
    for t in tokens:
        if t in SEPARATORS:
            segments.append(current)
            current = []
        elif t and set(t) <= set("();<>|&"):
            raise Deny(f"shell operator `{t}` is not allowed (no redirects, subshells, or background jobs)")
        else:
            current.append(t)
    segments.append(current)
    for words in segments:
        check_segment(words)
    if glob and any(w and w[0] in GLOB_SENSITIVE for w in segments):
        raise Deny("quote glob patterns (e.g. '*.nix') so they cannot expand into flags")


def respond(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))


def main():
    data = json.load(sys.stdin)
    active = ("--force" in sys.argv[1:] or os.environ.get("CLAUDE_ASK_MODE") == "1"
              or data.get("agent_type") == "ask")
    if not active or data.get("tool_name") != "Bash":
        return
    cmd = data.get("tool_input", {}).get("command", "")
    try:
        check(cmd)
    except Deny as e:
        respond("deny", f"Ask mode (read-only): {e}. Use Read/Grep/Glob, rg, fd, "
                        "or WebFetch instead; do not try to work around this.")
        return
    respond("allow", "Ask mode: read-only command")


if __name__ == "__main__":
    main()
