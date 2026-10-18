#!/usr/bin/env python3
"""PreToolUse hook: keep Claude's dcal calls inside the allowed calendars.

Claude may only use three calendars of lorenzobaracco01@gmail.com (Work,
Important, Free time). Bash commands that do not mention dcal pass through
silently. For dcal calls the hook decides:

  allow  creating/reading events in an allowed calendar, plus harmless
         listing/help/sync commands
  ask    anything that can reach events Claude did not create
         (events.list, events.update, events.delete, unscoped events.get),
         so the user approves it explicitly in the permission prompt
  deny   other calendars, account or calendar changes, imports, RSVPs,
         daemon control, and any method not listed below

Calendar ids come from `dcal --json ipc calendars.list`; update ALLOWED if
the calendars are recreated.
"""

import json
import re
import shlex
import sys

# -- Tables -------------------------------------------------------------------

ALLOWED = {
    "fb1d426f-9b48-4baa-9df4-398059688e50": "Work",
    "8d6323ac-30f8-42f3-b565-6e3b625a2011": "Important",
    "32f65470-83a7-4409-a8cc-6c33663e2d29": "Free time",
}

# IPC methods that are always fine (read calendar metadata or help only).
IPC_ALLOW = {"calendars.list", "accounts.list", "list", "ping", "version", "describe"}

# IPC methods that need an allowed calendarId.
IPC_SCOPED = {"events.create", "events.get"}

# IPC methods the user must approve: they address events by id only, or
# return events from every account.
IPC_ASK = {"events.list", "events.update", "events.delete"}

# Top-level subcommands that are always fine.
TOP_ALLOW = {"help", "version", "completion", "sync", "reminders"}

SEPARATORS = {"|", "||", "&&", ";", "\n"}

# Read-only filters that may follow dcal in a pipeline without losing "allow".
FILTERS = {"jq", "head", "tail", "grep", "wc", "cat"}

# Wrappers that could run dcal out of sight of the parser.
WRAPPERS = {"bash", "sh", "fish", "zsh", "env", "xargs", "eval", "exec", "sudo",
            "nohup", "timeout", "command", "nix", "nix-shell", "python", "python3"}


class Deny(Exception):
    pass


class Ask(Exception):
    pass


# -- Checks -------------------------------------------------------------------

def tokenize(cmd):
    lex = shlex.shlex(cmd, posix=True, punctuation_chars="();<>|&\n")
    lex.whitespace = " \t\r"
    lex.commenters = ""
    lex.whitespace_split = True
    return list(lex)


def params(args):
    out = {}
    for a in args:
        if "=" in a and not a.startswith("-"):
            k, v = a.split("=", 1)
            out[k] = v
    return out


def check_ipc(args):
    pos = [a for a in args if not a.startswith("-")]
    if not pos or "-h" in args or "--help" in args:
        return
    method, kv = pos[0], params(pos[1:])
    if method in IPC_ALLOW:
        return
    if method in IPC_SCOPED:
        cal = kv.get("calendarId")
        if cal in ALLOWED:
            return
        if method == "events.get" and cal is None:
            raise Ask("events.get without calendarId can read events in any calendar")
        raise Deny(f"calendarId {cal!r} is not Work, Important or Free time "
                   f"({', '.join(f'{n}={i}' for i, n in ALLOWED.items())})")
    if method in IPC_ASK:
        raise Ask(f"{method} can read or change events Claude did not create")
    raise Deny(f"ipc method {method} is off-limits for Claude")


def check_dcal(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        if args[i] in ("-c", "--config") or args[i].startswith("--config="):
            raise Deny("dcal --config loads a different UI; not needed")
        i += 1
    rest = args[i:]
    if not rest or rest[0] in ("-h", "--help"):
        return
    sub, sub_args = rest[0], rest[1:]
    if sub in TOP_ALLOW or "-h" in sub_args or "--help" in sub_args:
        return
    if sub == "account" and sub_args[:1] in (["list"], ["providers"]):
        return
    if sub == "ipc":
        check_ipc(sub_args)
        return
    raise Deny(f"`dcal {' '.join(rest[:2])}` is off-limits; "
               "create events with `dcal ipc events.create calendarId=<allowed id> ...`")


def check(cmd):
    """Return True if every segment is a vetted dcal call or a pure filter.

    False means the command runs dcal safely but also does other things, so
    the normal permission flow should decide."""
    if re.search(r"`[^`]*\bdcal\b|\$\([^)]*\bdcal\b", cmd):
        raise Deny("no dcal inside command substitution")
    try:
        tokens = tokenize(cmd)
    except ValueError as e:
        raise Deny(f"could not parse command ({e})")
    segments, current = [], []
    for t in tokens:
        if t in SEPARATORS:
            segments.append(current)
            current = []
        else:
            current.append(t)
    segments.append(current)
    ran_dcal, only_dcal = False, True
    for words in segments:
        while words and re.match(r"[A-Za-z_][A-Za-z0-9_]*=", words[0]):
            words = words[1:]
        if not words:
            continue
        head = words[0].rsplit("/", 1)[-1]
        if head == "dcal":
            check_dcal(words[1:])
            ran_dcal = True
        elif head in WRAPPERS and any(re.search(r"\bdcal\b", w) for w in words[1:]):
            raise Deny(f"run dcal directly as a command, not via {head}")
        elif head.startswith("$"):
            raise Deny("run dcal directly as a command, not via a variable")
        elif head not in FILTERS or any(t in words for t in ("-i", "--in-place")):
            only_dcal = False
    if any(t and set(t) <= set("();<>&") for t in tokens):
        only_dcal = False
    return ran_dcal and only_dcal


def respond(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Bash":
        return
    cmd = data.get("tool_input", {}).get("command", "")
    if not re.search(r"\bdcal\b", cmd):
        return
    try:
        vetted = check(cmd)
    except Deny as e:
        respond("deny", f"dcal guard: {e}. Only Work, Important and Free time on "
                        "lorenzobaracco01@gmail.com are allowed; do not work around this.")
        return
    except Ask as e:
        respond("ask", f"dcal guard: {e}. Approve only if you asked for this.")
        return
    if vetted:
        respond("allow", "dcal guard: allowed calendar operation")


if __name__ == "__main__":
    main()
