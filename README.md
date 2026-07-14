# Bash Failed-Login Pattern Review

A Bash script that parses a semicolon-delimited access log and flags users 
exceeding a configurable failed-login threshold within a rolling time window. 
Outputs a complete audit trail — not just flagged rows — as RFC 4180-compliant CSV.

## What it does

Reads an access log line by line, tracking a per-user failure count and 
streak-start time using Bash associative arrays. A successful login resets the 
streak. If a user's failure count reaches the threshold (default: 5) within the 
configured window (default: 15 minutes), that row is flagged `True` in the output — 
but every failure is written to the report, flagged or not, so a reviewer can see 
the full picture rather than only the alerts.

## Why "flag for review," not "detect brute force"

A failure-count threshold tells you a pattern occurred — it doesn't tell you intent. 
Five failed logins in 15 minutes could be an attack, or it could be someone who 
forgot they changed their password. This script surfaces the pattern for a human 
to evaluate; it doesn't claim to distinguish malicious from benign on its own.

## Architecture decisions

- **Semicolon-delimited input parsing** — the sample log includes an Application 
  field that legitimately contains a comma (`Microsoft Graph, PowerShell`). Using 
  a comma as the field separator would silently misalign every column after it. 
  Semicolon avoids collision with real data.
- **Every field quoted in the output CSV** — the same comma-collision problem 
  exists on the output side. Rather than quoting only the one field known to 
  contain commas today, every field is quoted unconditionally, so the format stays 
  correct regardless of what a future dataset contains.
- **Epoch-second time comparisons** — timestamps are converted to epoch seconds 
  before arithmetic, since string comparison can't calculate duration and doesn't 
  handle date rollover (e.g., a streak spanning midnight) correctly.
- **Full audit trail output, not just flagged rows** — early version only wrote a 
  row when the threshold was crossed, meaning sub-threshold failures were silently 
  dropped from the report entirely. Restructured so every failure is recorded, 
  with `Flagged` as a column — a reviewer can filter for `True`, but the complete 
  record is always there if needed.
- **Streak resets on success, per user** — prevents flagging normal password-typo 
  behavior (e.g., 4 failures then a successful login) as suspicious.

## Known limitation / scope

This script only detects one pattern: repeated failures from a single flat log 
file. Two related patterns were considered and deliberately excluded:

- **Login-location anomaly detection** — requires a historical baseline per user, 
  which a single log export doesn't contain. This is a missing-data problem, not 
  a licensing one, and is better suited to a Python script comparing against 
  stored history (or a SIEM/UEBA platform, which exists specifically to solve 
  this at scale).
- **Impossible travel detection** — requires IP geolocation enrichment and 
  distance/time math, which Bash isn't built for. This is a tool-mismatch problem 
  — Python with a geolocation library would be the right approach, and this is 
  already a built-in detection in platforms like Entra ID Protection.

## Setup

1. Ensure you're running in a Linux environment (WSL, native Linux, or macOS with 
   GNU `date` — BSD `date` on stock macOS uses different syntax and isn't tested here)
2. `chmod +x flag_failed_logins.sh`
3. Place your log in the same directory as `access_log.txt`, semicolon-delimited, 
   with fields: `timestamp;user;application;status;errorcode`
4. Run: `./flag_failed_logins.sh`
5. Output is written to `failed_login_report.csv`

## Sample output

| Timestamp | User | Application | FailureCount | StreakStartTime | Flagged |
|---|---|---|---|---|---|
| 2026-07-13T09:15:32Z | jsmith | Microsoft Graph, PowerShell | 1 | 2026-07-13T09:15:32Z | False |
| 2026-07-13T09:19:55Z | jsmith | Microsoft Graph, PowerShell | 5 | 2026-07-13T09:15:32Z | True |
| 2026-07-13T10:02:11Z | agarcia | Outlook Web App | 1 | 2026-07-13T10:02:11Z | False |
