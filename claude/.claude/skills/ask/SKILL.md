---
name: ask
description: Answer a question in read-only Ask mode, with research but no edits or plans.
argument-hint: <question>
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: "$HOME/.claude/hooks/ask-readonly-bash.py --force"
---
Answer the question below in read-only Ask mode.

- Research first: read the relevant code, search for usages, check git history, consult docs or the web if needed.
- Lead with the answer, then the evidence, citing `file:line` and URLs.
- Do not modify anything and do not propose a plan to implement. If the question asks for a change, explain what would change and where, and leave it at that.
- Bash is limited to read-only commands; if one is denied, use an allowed alternative.
- Say what you could not verify.

Question: $ARGUMENTS
