#!/usr/bin/env python3
"""PreToolUse hook: nothing runs on the JSC clusters unless the user approves it.

Answers "ask" (the permission prompt, also in auto mode) for:

  Bash / Monitor
    - ssh, scp, sftp, rsync, sshfs, mosh or git remote traffic to a cluster host
      (`ssh -O check HOST` excepted: it only asks the local master if it is up)
    - TRAMP paths of a cluster host (/ssh:jureca:..., e.g. in `emacsclient -e`)
    - shell commands run in, or naming, a mounted cluster share (sshfs from a
      cluster host, e.g. /mnt/jureca). Claude sessions started from an Emacs TRAMP
      buffer run there (emacs/.config/doom/lisp/+claude-remote.el), so every shell
      command of such a session asks.
  mcp__ide__executeCode (elisp in Emacs, which reaches the clusters through TRAMP)
    - from a session in a cluster share, or code naming a cluster host or TRAMP path

Not affected: Read/Edit/Write/Glob/Grep on the share (working on the project files
is fine) and everything else, which keeps the normal permission flow. A guard rail
against Claude's own initiative, not a sandbox: a script file that calls ssh is not
inspected.
"""

import json
import os
import re
import sys

# -- Tables -------------------------------------------------------------------

# Cluster hosts: ssh_config aliases, JSC node names (jrlogin05, jrc0123, jwb0042, ...)
# and *.fz-juelich.de hosts other than the git and account services.
HOST = (r"(?:jureca|jupiter|juwels|jusuf|j[rwp][a-z0-9-]*\d[\w-]*"
        r"|(?!jugit\.|judoor\.|gitlab\.)[\w-]+(?:\.[\w-]+)*\.fz-juelich\.de)")

# HOST as a destination: a whole word, optionally user@, followed by :path or the end.
DEST = re.compile(r"(?:^|[\s'\"=/@])" + HOST + r"(?=[:\s'\"/]|$)", re.I)

# Commands that run things on, or copy to/from, another host.
REMOTE_CMD = re.compile(r"(?:^|[\s;|&(`'\"/])(?:ssh|scp|sftp|rsync|sshfs|mosh|autossh)(?=[\s'\"]|$)")

# Harmless: asks the local ssh master whether it is up.
SSH_CHECK = re.compile(r"\bssh\s+(?:-[^O\s]\S*(?:\s+[^-\s]\S*)?\s+)*-O\s*check\s+\S+")

GIT_REMOTE = re.compile(r"\bgit\b")
GIT_DEST = re.compile(r"(?:ssh://(?:[^@/\s]+@)?" + HOST + r"|(?:^|[\s'\"@])" + HOST + r":)", re.I)

TRAMP = re.compile(r"/(?:ssh|sshx|scp|scpx|rsync|-):(?:[^@:|/\s]+@)?" + HOST + r"[:|#]", re.I)

EXEC_CODE = "mcp__ide__executeCode"


# -- Checks -------------------------------------------------------------------

def cluster_mounts():
    """Mount points of sshfs/FUSE shares whose source is a cluster host."""
    found = []
    try:
        with open("/proc/mounts") as f:
            for line in f:
                fields = line.split()
                if len(fields) < 3 or not fields[2].startswith("fuse"):
                    continue
                if re.fullmatch(r"(?:[^@\s]+@)?" + HOST + r":.*", fields[0], re.I):
                    found.append(fields[1].replace("\\040", " "))
    except OSError:
        pass
    return found


def under(path, mount):
    return path == mount or path.startswith(mount.rstrip("/") + "/")


def names_mount(text, mount):
    return re.search(re.escape(mount.rstrip("/")) + r"(?=[/\s'\":;|&)]|$)", text) is not None


def check_shell(cmd, cwd):
    """Reason to ask for shell command CMD run in CWD, or None."""
    if TRAMP.search(cmd):
        return "it names a TRAMP path on a cluster host"
    stripped = SSH_CHECK.sub("", cmd)
    if REMOTE_CMD.search(stripped) and DEST.search(stripped):
        return "it connects to a cluster host"
    if GIT_REMOTE.search(cmd) and GIT_DEST.search(cmd):
        return "git talks to a repository on a cluster host"
    for mount in cluster_mounts():
        if under(cwd, mount):
            return f"it runs in the cluster share {mount}"
        if names_mount(cmd, mount):
            return f"it works on the cluster share {mount}"
    return None


def check_elisp(code, cwd):
    if any(under(cwd, m) for m in cluster_mounts()):
        return "this session works on a cluster share"
    if TRAMP.search(code) or "/ssh:" in code or DEST.search(code):
        return "the code names a cluster host or TRAMP path"
    return None


def respond(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))


def main():
    data = json.load(sys.stdin)
    tool = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    cwd = data.get("cwd") or os.getcwd()
    if tool in ("Bash", "Monitor"):
        reason = check_shell(tool_input.get("command", ""), cwd)
    elif tool == EXEC_CODE:
        reason = check_elisp(tool_input.get("code", ""), cwd)
    else:
        return
    if reason:
        respond("ask", f"cluster guard: {reason}. Claude runs nothing on the clusters "
                       "unless the user explicitly allowed it: approve only if you asked for "
                       "this. If denied, do not retry or work around it; project files can "
                       "be read and edited with Read/Edit/Write/Glob/Grep without approval.")


if __name__ == "__main__":
    main()
