---
name: reflect
description: Session retrospective. Analyzes the current session for friction, corrections and repeated patterns, proposes concrete improvements to the Claude Code setup (memory, skills, hooks, settings, CLAUDE.md), auto-implements safe quick wins, and saves a report.
argument-hint: "[focus]"
disable-model-invocation: true
---
Run a retrospective on the current session to improve the Claude Code setup itself. This is a learning loop, not a session save (that's `/pause`).

Execute immediately. No acknowledgment, no explaining what you're about to do.

Optional focus from the user: $ARGUMENTS

## 1. Locate the transcript and the setup

```sh
SESSION=$(ls ~/.claude/projects/*/${CLAUDE_SESSION_ID}.jsonl)
echo "$SESSION"; wc -l "$SESSION"
MEMDIR="$(dirname "$SESSION")/memory"; echo "$MEMDIR"
```

Collect the existing setup so the analysis can check for overlap:

```sh
ls ~/.claude/skills/*/SKILL.md .claude/skills/*/SKILL.md ~/.claude/agents/*.md ~/.claude/hooks/* 2>/dev/null
ls ~/.claude/CLAUDE.md CLAUDE.md "$MEMDIR" 2>/dev/null
jq '{hooks: (.hooks // {} | keys), enabledPlugins}' ~/.claude/settings.json
```

## 2. Delegate the analysis

Spawn one `general-purpose` Agent so the transcript dump stays out of the main context. Give it the transcript path, the memory dir, the setup listing from step 1, the focus (if any), and the framework below. It reads the transcript itself and returns the report as text. It must not write or change any file.

Transcript extraction for the agent (user and assistant text only; it should also grep for `"is_error":true` to find failed tool calls):

```sh
jq -r '
  if .type == "user" and (.message.content | type) == "string" then "USER: " + .message.content
  elif .type == "user" then (.message.content[]? | select(.type == "text") | "USER: " + .text)
  elif .type == "assistant" then (.message.content[]? | select(.type == "text") | "ASSISTANT: " + .text)
  else empty end' "$SESSION"
```

For very long transcripts, prioritize user messages (the main signal), corrections, and failed tool calls.

### Analysis framework

Dedup rule: each issue goes in exactly one section, the most relevant one.

- **A. Friction:** tool failures or retries, wrong approaches that had to be corrected, missing information that needed extra lookups, manual steps that could be automated.
- **B. Corrections:** misunderstood intent, wrong paths or API usage, incorrect assumptions, "no, I meant..." moments.
- **C. Repeated patterns:** similar queries or workflows, lookups that could be remembered.
- **D. Discoveries:** how a system actually works vs. the assumption, gotchas, new capabilities.
- **E. Skill gaps:** long ad-hoc workflows or multi-step processes that could be a skill, hook or agent.
- **F. Documentation gaps:** missing or outdated notes in CLAUDE.md, skills or memory.

Before suggesting anything, check the setup listing (read files if needed). Prefer updating an existing skill or memory over creating a new one.

### Report template

```markdown
# Session Retrospective - <YYYY-MM-DD>

**Session focus:** <one sentence>
**Duration:** <approximate>
**Key files touched:** <list>

## Friction Points
### <title>
- **What happened:** <specific>
- **Impact:** <time/effort wasted>
- **Suggested fix:** <concrete>
- **Type:** memory | skill | hook | settings | CLAUDE.md | code
- **Effort:** Small | Medium | Large
- **Auto-implement?** Yes (memory) | No (needs review)

## Corrections
### <title>
- **User said:** "<quote or close paraphrase>"
- **What was wrong / root cause:** <...>
- **Prevention:** <...>
- **Type / Auto-implement?:** <...>

## Patterns Worth Capturing
### <title>
- **Pattern / frequency:** <...>
- **Suggested action + draft content:** <exact text to add>
- **Auto-implement?** <...>

## Skill / Hook Suggestions
### /<name>
- **Trigger / what it does / evidence:** <...>
- **Effort / priority:** <Small|Medium|Large> / <now | nice to have | someday>

## Memory Updates
### <name>
- **File:** <MEMDIR>/<slug>.md (or the existing file it updates)
- **Content:** <exact frontmatter + body, format below>
- **Auto-implement?** Yes

## Documentation Gaps
### <title>
- **Where / draft content / auto-implement?:** <...>

## Summary
**Total actionable improvements:** <n> (<a> auto-implemented + <b> need approval)
**Top 3 by impact:** 1. ... 2. ... 3. ...
```

Counting rule: count distinct actionable items. A memory that fixes a friction point is one item. Auto-implemented plus needs-approval must equal the total. Omit empty sections.

Memory file format (one fact per file):

```markdown
---
name: <short-kebab-case-slug>
description: <one-line summary used for recall>
metadata:
  type: user | feedback | project | reference
---

<the fact; for feedback/project add **Why:** and **How to apply:** lines. Link related memories with [[name]].>
```

Memories hold only what isn't already recorded in code, git history or CLAUDE.md, and nothing that only matters to this one conversation.

## 3. Auto-implement quick wins

Implement only items marked `Auto-implement? Yes` where the need is unambiguous from the transcript:

- New or updated memory files in `$MEMDIR`. Check for an existing file covering the same fact first and update it instead of duplicating. Add or update a one-line pointer in `$MEMDIR/MEMORY.md`: `- [Title](file.md) — hook`.
- Fixing an obviously wrong reference in a skill or doc.

Never auto-implement new skills, hooks, agents, `settings.json` changes, or anything that could change existing behavior. Those go in the report for approval.

Add a "Quick Wins Auto-Implemented" section to the report listing each applied change with its file path.

## 4. Save and summarize

1. Save the report to `~/.claude/reflections/<YYYY-MM-DD>-<first 8 chars of session id>-<1-3 word slug>.md` (create the directory if needed).
2. Show a short summary: what the session accomplished, how many improvements were found, what was auto-implemented (with paths), and the items that need approval, highest impact first.
3. Ask which of the approval items to implement.

## Out of scope

- No git commits or pushes.
- No session-saving or resume prompts (that's `/pause`).
- Nothing with breaking changes or meaningful risk without approval.

## Guidelines

- Be honest about struggles. The point is to learn, not to look good.
- Be specific. "Improve error handling" is useless. "Add a memory that the calendar CLI needs RFC3339 timestamps with seconds, because event creation failed twice" is useful.
- Prioritize by impact: preventing recurring friction beats nice-to-haves.
- Draft the actual content, never "add a memory about X".
- A clean session is a valid outcome: "Clean session, no improvements needed." Don't invent problems.
