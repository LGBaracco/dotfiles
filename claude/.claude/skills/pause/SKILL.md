---
name: pause
description: Pause the current session. Commits work if in a git repo and generates a copy-paste resume prompt for a fresh session. Quick mode for short breaks, full mode for end of day.
argument-hint: "[quick]"
disable-model-invocation: true
---
Prepare the current session to be paused and resumed later in a fresh session.

Arguments: $ARGUMENTS

## Mode

- `quick`, `--quick` or `brb` → **quick mode**: short breaks, context switches.
- anything else, or nothing → **full mode**: end of day, long breaks.

## 1. Git (only if the working directory is in a git repo)

Run `git rev-parse --is-inside-work-tree 2>/dev/null`. If it is not a repo, skip to step 2 and say "No git repo, nothing committed."

1. `git status --short`. If clean, skip the rest of this step.
2. Stage only the files this session changed, by name. Never `git add .` or `git add -A`. If there are other uncommitted changes, leave them and list them in the status line.
3. Commit:
   - quick: `Quick pause: <brief context>`
   - full: a descriptive message of what was done
4. Full mode only: if the branch has an upstream (`git rev-parse --abbrev-ref @{u}`), run `git pull --rebase` then `git push`, and confirm with `git status` that it is up to date. If there is no upstream, don't push; say so in the status line. If the rebase conflicts, stop and report it.

## 2. Resume prompt

### Quick template

```
Resume: <one-line task description>
Next: <single next step>
Files: <1-2 key files with absolute paths>
```

### Full template

```
Resume work on <project/task> in <working directory>. Context:
- Current status: <where we left off>
- Completed: <what's done>
- Next steps: <what to do when returning, in order>
- Remaining work / open issues: <anything still to follow up, so nothing gets lost>
- Files involved: <key files with absolute paths>
- Pending proposals/questions: <anything proposed but not yet answered, VERBATIM, not summarized>
- Conversational tone: <focused? frustrated? brainstorming? debugging? helps the next session match the user's headspace>

Key learnings (patterns worth repeating):
1. <specific pattern, decision or gotcha that should carry forward>
2. <if applicable>
```

Include key learnings when patterns emerged, decisions should be remembered, or gotchas were found. Omit the section otherwise.

### Quality check (full mode)

Apply the **amnesia test**: read the prompt back and ask, "If I woke up with ONLY this, could I seamlessly continue?" If not, add detail.

Never write:
- Vague summaries like "discussed dashboard stuff" or "worked on various things".
- "No active task" or "Idle" without saying what we are waiting for.
- A prompt that drops pending proposals. These are the first thing lost across session breaks.

## 3. Output

1. The resume prompt in a single fenced code block, so it can be copied in one go.
2. One status line after it: `✅ Resume prompt ready. <git result>`. Examples: "Committed locally (abc1234), not pushed." / "Committed and pushed to origin/main." / "No git repo, nothing committed." / "Left uncommitted: notes.txt (not touched this session)."
