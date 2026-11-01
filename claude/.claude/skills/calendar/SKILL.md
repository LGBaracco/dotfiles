---
name: calendar
description: Create calendar events for Lorenzo with the dcal CLI (Work, Important, Free time calendars of lorenzobaracco01@gmail.com). Use when asked to add, schedule, book, block or put something in the calendar, or to fix an event Claude just created.
argument-hint: <event description>
---
Create calendar events with `dcal`. The `dcal-guard.py` hook in `~/.claude/hooks` enforces the limits below. If it denies a call, fix the call; never route around the hook.

## Scope (strict)

Only the account `lorenzobaracco01@gmail.com`, and only these three calendars:

| Calendar | Use for |
|---|---|
| Work | anything work related: meetings, talks, deadlines at FZJ, conferences |
| Important | personal appointments (doctor, dentist), bureaucratic deadlines (taxes, visa, Anmeldung, contracts, bills) |
| Free time | everything else: friends, sport, hobbies, trips, events |

### Getting the calendar ids

Calendar ids are local to each machine's dcal database, so never reuse ids from another session or host. Look them up once per conversation, before the first call that needs a `calendarId`:

```sh
dcal --json ipc calendars.list \
  | jq -r '[.. | objects | select(.accountId? == "lorenzobaracco01@gmail.com" and (.name == "Work" or .name == "Important" or .name == "Free time"))] | unique_by(.id) | .[] | "\(.name)\t\(.id)"'
```

Expect exactly three lines. If one is missing or a name appears twice, stop and tell Lorenzo instead of guessing. The hook runs the same lookup, so only these ids pass. Below, `<Work id>` etc. stand for the ids from this output; write them literally into commands.

- If the right calendar is unclear, ask before creating.
- Do not list, read, update or delete any event Claude did not create in this conversation, unless Lorenzo explicitly asks. Claude is allowed to read back, fix or delete events it created itself.
- Never touch other calendars or accounts (kingfosu6@gmail.com, the FZJ CalDAV account, Holidays, My Tasks, bda_absence_google). Never change account or calendar settings.

## Creating an event

1. Run `date` to get today's date and the UTC offset. Germany and Rome use the same offset (+01:00 in winter, +02:00 in summer). Resolve relative dates like "next Tuesday" from that output, and pick the offset for the event's own date, which may differ from today's across a DST change.
2. In one line, state the title, calendar, date and time. If no duration was given, use 1 hour and say so.
3. Create it. Write every value literally (no shell variables or `$(...)`; the hook rejects them):

```sh
dcal --json ipc events.create \
  calendarId='<Work id>' \
  summary='Group meeting' \
  start=2026-10-20T14:00:00+02:00 \
  end=2026-10-20T15:00:00+02:00 \
  location='Building 16.3, room 301' \
  description='Agenda: ...'
```

4. Report the result in one line, with the `id` and `uid` from the JSON output. They are needed to fix the event later in the conversation.

The output is the event as JSON. Its times are in UTC (`Z`); that is expected.

### Parameters

`dcal ipc` passes every `key=value` as a **string**. Put quotes around values that contain spaces or `;`.

| Param | Required | Format / notes |
|---|---|---|
| `calendarId` | yes | one of the three ids from the lookup above |
| `summary` | yes | title |
| `start`, `end` | yes | RFC3339 with offset, e.g. `2026-10-20T14:00:00+02:00` |
| `location`, `description` | no | free text |
| `allDay` | no | `allDay=true`; set `start` to the date at `T00:00:00Z` and `end` to the **next** day at `T00:00:00Z`. For multi-day events, `end` is the day after the last day. |
| `recurrence` | no | **one** RRULE without the `RRULE:` prefix, e.g. `'recurrence=FREQ=WEEKLY;COUNT=10'`, `'recurrence=FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261231T235959Z'` |
| `transparency` | no | `free` or `busy` (`transparent`/`opaque` also accepted). Default is busy. |
| `status` | no | `confirmed` (default), `tentative`, `cancelled` |

Not possible through the CLI:
- `reminders`: the daemon requires a JSON array, and the CLI can only send strings. New events get the calendar's default reminders. If Lorenzo asks for a specific reminder, say it has to be set in the dcal UI or Google Calendar.
- More than one RRULE per event.

## Reading back / fixing an event Claude created

```sh
dcal --json ipc events.get uid=<uid> calendarId=<one of the three ids>
dcal --json ipc events.update id=<id> start=... end=...   # only the keys to change
dcal --json ipc events.delete id=<id>
```

- `events.get` takes the `uid`. `update` and `delete` take the `id`. Both come from the create output.
- For a recurring event:
  - `events.get ... start=<occurrence start>` fetches one occurrence.
  - `events.delete id=<id> occurrenceStart=<RFC3339>` removes a single occurrence.
- `update` and `delete` always trigger a permission prompt (the hook can't see which calendar the id belongs to). This is expected; explain what will change so Lorenzo can approve it.
- `events.list` searches **all** accounts, so the hook also prompts for it. Use it only when Lorenzo explicitly asks to look at his calendar, and filter the output to the three calendarIds so other events are never printed. The output isn't a flat list, so match recursively:

```sh
dcal --json ipc events.list query='dentist' from=2026-10-01T00:00:00Z to=2026-11-01T00:00:00Z \
  | jq -c '[.. | objects | select(.calendarId? as $c | ["<Work id>","<Important id>","<Free time id>"] | index($c))] | unique_by(.id) | .[] | {id,uid,calendarId,summary,start,end}'
```

## Allowed helper commands

- `dcal --json ipc calendars.list`: look up calendar ids (see above), or re-check them if a create fails with "calendar not found".
- `dcal ipc list`: every IPC method and its params.
- `dcal sync lorenzobaracco01@gmail.com`: force a sync.

## Errors

- `dcal daemon not running`: tell Lorenzo to run `dcal show`. Don't start or restart dcal yourself.
- `... must be RFC3339`: the timestamp is missing seconds or the offset.
- `googleapi: Error 400: Invalid recurrence rule`: remove the `RRULE:` prefix, or check the RRULE syntax.
- Hook denial: read the reason. It names the allowed calendar ids.

## Off-limits

- `dcal account add/remove/reauth`
- `calendars.create/delete/rename/set*`
- `events import`, `events.importIcs`, `rsvp`
- `tasks.*`, `files.*`, `ui.*`
- `kill`, `restart`, `run`, `open`, `--config`

The hook denies all of these.
