# Time Report Skill

Generate a monthly unified timeline report from Outlook calendar and Teams chat
data, using the Microsoft 365 MCP tools. Replaces the manual CSV export +
LevelDB parsing workflow in `unified_timeline.py`.

## Arguments

The user provides a month in any reasonable format: `YYYY-MM`, `April`,
`04/2026`, `apr`, etc. If no argument is given, use the current month.

Month argument: $ARGUMENTS

## Instructions

You are generating a billing/timesheet reconciliation report. Follow these steps
exactly, then write the report to disk.

**Performance target:** The data-fetching phase (steps 2-4) involves many
paginated API calls. To keep runtime reasonable, process all API results through
a single Python script that writes intermediate JSON to `/tmp/`, then generate
the report from those files. This avoids re-fetching data if the report
formatting needs adjustment.

### Step 1: Parse the month

Parse the argument flexibly (e.g., "April", "2026-04", "04/2026", "apr").
Compute:
- `firstDay`: first day of the month (YYYY-MM-01)
- `lastDay`: last day of the month (YYYY-MM-DD)
- `monthName`: full month name, uppercased (e.g., "APRIL")
- `monAbbrev`: lowercase 3-letter abbreviation (e.g., "apr")
- `outputPath`: `~/Documents/Admin/{monAbbrev}{year}_unified_timeline.txt`

### Step 2: Fetch calendar events

Use `outlook_calendar_search` to retrieve ALL events for the month. The tool
returns max 50 events per request, so you MUST paginate:

```
query: "*"
afterDateTime: {firstDay}
beforeDateTime: day after lastDay
limit: 50
offset: 0, 50, 100, ... until fewer than 50 results are returned
```

Fetch pages in parallel where possible (e.g., request offset 0 and 50
simultaneously on the first call, since most months have 50-100 events).

Save raw results to `/tmp/{monAbbrev}{year}_calendar.json`.

For each event, extract:
- subject, start, end (parse to local time, Central Time / America/Chicago)
- organizer (email -> display name: split on "@", replace "." with " ", title case)
- attendees (list of emails/names, exclude "Michael Haynes" / "mhaynes@boldorange.com")
- isAllDay, isCancelled
- duration in minutes (end - start)

Skip cancelled events and events with subject starting with "Canceled:".
Group by date (YYYY-MM-DD).

### Step 3: Fetch Teams chat messages

Use `chat_message_search` to retrieve messages for the month. The tool returns
max 100 per request, so paginate:

```
query: "*"
afterDateTime: {firstDay}
beforeDateTime: day after lastDay
limit: 100
offset: 0, 100, 200, ... until moreResults is false or no results
```

**Known limitation:** The Graph search API returns ~50-60% of total Teams
messages compared to the local cache. Some message types (system messages,
certain bot interactions) are not indexed. This is acceptable — the report
will note the data source. Expect 600-1000 messages for a typical month.

Fetch pages sequentially (parallel requests at different offsets may return
duplicates or fail). Deduplicate by message ID.

Save raw results to `/tmp/{monAbbrev}{year}_chat.json`.

For each message, extract:
- from.displayName (sender) — may be null for system messages
- summary (message body, strip HTML tags)
- createdDateTime (parse to local Central Time)
- chatId (conversation identifier)
- chatUri (for thread name resolution)

Filter out:
- Messages with null sender (system messages)
- Bot senders: "Jira Cloud", "Power Automate", "Workflows", "Forms", "Polly",
  "Kadence Bot"

Group by: date (YYYY-MM-DD) -> chatId -> list of messages.

### Step 4: Resolve chat thread names

Use a two-tier approach:

**Tier 1 (always):** Infer names from sender patterns per chatId:
- 1 other participant -> use their name (e.g., "Erick Hamness")
- 2-3 others -> join names (e.g., "Erick and Yan Sheng")
- 4+ others -> top 3 names + count (e.g., "Carter, Erick, Jackie, +7")
- No other participants -> "[Self]"

**Tier 2 (for active chats only, if Tier 1 produces poor names):** Use
`read_resource` with the chatUri to get proper chat metadata / topic. Only do
this for chats where "Michael Haynes" sent 2+ messages AND the Tier 1 name has
4+ participants (group chats where the inferred name is unhelpful). Limit to 10
lookups max.

**Known limitation:** Tier 1 names for group chats may not match the official
Teams chat title. This is cosmetic and does not affect the engagement metrics.

### Step 5: Analyze conversations

For each day + chat combination, compute:
- total message count
- Michael Haynes's message count ("my_count")
- Engagement tag:
  - ACTIVE: my_count >= 2
  - BRIEF: my_count == 1
  - OBSERVER: my_count == 0
- Time span (first message time -- last message time)
- My time span (first of my messages -- last of my messages)
- Top senders (for observer threads)

Separate into active_threads (ACTIVE or BRIEF) and observer_threads (OBSERVER).

Skip conversations titled "Le Chat" or "[Thread]".

### Step 6: Generate the report

**IMPORTANT:** Use a Python script (write to a temp file, then execute) rather
than assembling the report in conversation text. The report can be 500+ lines
and must have exact formatting. The script should read from the intermediate
JSON files saved in steps 2-3 and produce the output file directly.

Write the report to `outputPath` using this EXACT format:

```
================================================================================
{MONTH_NAME} {YEAR} -- UNIFIED DAILY TIMELINE
================================================================================
Generated: {now YYYY-MM-DD HH:MM}
Calendar source: Microsoft 365 Graph API
Chat source: Microsoft 365 Graph API (Teams)

Engagement tags: ACTIVE (2+ msgs sent) | BRIEF (1 msg) | OBSERVER (0 msgs)
Bot/noise messages filtered. [Thread] and "Le Chat" conversations excluded.
```

Then for each day with activity (sorted chronologically):

```
================================================================================
{YYYY-MM-DD (DayName)}
================================================================================

  MEETINGS ({duration} scheduled)
  ---------------------------------------------------
  {HH:MM AM} - {HH:MM AM}  {Subject} [{Attendee1, Attendee2, +N}]
  All Day      {Subject}

  CHAT ACTIVITY -- ACTIVE THREADS (threads you contributed to)
  ---------------------------------------------------
  [{ThreadName}] -- {total} msgs (you: {my_count}) {TAG}
    {HH:MM}--{HH:MM}  (your span: {Xh Ym})
    Your messages:
      [{HH:MM}] {message preview, max 120 chars}...
      ... +N more

  CHAT ACTIVITY -- OBSERVER THREADS (active threads you didn't contribute to)
  ---------------------------------------------------
  [{ThreadName}] -- {total} msgs (you: 0) OBSERVER
    {HH:MM}--{HH:MM}  Top senders: {Name1, Name2, Name3}
    Preview: {first substantive message, max 100 chars}...
```

Active threads: sorted by my_count descending. Show up to 5 message previews.
Observer threads: sorted by total message count descending.

Attendee lists: show up to 4 names, then "+N" for the rest.

Then the monthly summary:

```
================================================================================
MONTHLY SUMMARY
================================================================================

  Total meeting time:      {Xh Ym}
  Total meeting events:    {N}
  Days with activity:      {N}

  DAILY OVERVIEW
  ------------------------------------------------------------------------
  {YYYY-MM-DD (Day)  }  {Xh Ym meetings     }  {N active, N brief, N observer}

  TOP MEETING SUBJECTS
  ------------------------------------------------------------------------
    {Subject} (xN)

  TOP ACTIVE CONVERSATIONS (by your message count)
  ------------------------------------------------------------------------
    {ThreadName}: {N} of your messages

  BILLING HELPER
  ------------------------------------------------------------------------
  Date            Mtg Hrs   Chats  Topics
  --------------- ---------  ------  ------------------------------------------
  {YYYY-MM-DD       X.Xh       N  Topic1, Topic2, Topic3}
  --------------- ---------  ------
  TOTAL             X.Xh       N

NOTE: Chat data retrieved via Microsoft Graph API (Teams).
The Graph search API indexes ~50-60% of Teams messages; some system and bot
messages are excluded. Calendar data is comprehensive.
```

### Step 7: Write and display

1. Write the report to `outputPath`
2. Display the BILLING HELPER section in the conversation (not the full report —
   it's too long; the user can read the file)
3. Report a brief summary: total calendar events, total chat messages fetched,
   total API calls made, any data gaps or pagination limits hit

### Important notes

- All times should be displayed in Central Time (America/Chicago). March = CDT
  (UTC-5), November-March = CST (UTC-6). Use `datetime.timezone` with the
  correct offset for the target month, or use `zoneinfo.ZoneInfo("America/Chicago")`
  if available.
- The user's name for sender matching is "Michael Haynes"
- The user's email is "mhaynes@boldorange.com"
- Strip HTML tags from chat message summaries before displaying
- If pagination limits prevent fetching all data, note this clearly in the report
- If a step fails or returns no data, continue with available data and note the gap
- Expect ~12-15 API calls for a typical month (2 calendar + 10 chat pages)
- The report file is saved with a `_mcp` suffix to avoid overwriting legacy reports
  generated by `unified_timeline.py`. Example: `mar2026_unified_timeline.txt` (legacy)
  vs. the skill output which also writes to `mar2026_unified_timeline.txt` — if the
  user wants to preserve both, they should rename the legacy file first.
