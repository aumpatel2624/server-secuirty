---
tags: [ssh, logging, auth]
---

# SSH session logging

## 1. Basic login events (already logged, just know where)

```bash
sudo journalctl -u ssh --since "24 hours ago"
# or on older setups:
sudo cat /var/log/auth.log | grep sshd
```
Shows: successful/failed logins, which user, source IP, which key fingerprint used. This exists
by default — no setup needed — but it's easy to miss because nothing surfaces it proactively.

**Why this alone isn't enough:** it tells you a session opened and closed. It does NOT tell you
what commands ran inside that session.

## 2. Full command logging per SSH session — `auditd` execve tracking

```bash
sudo apt install -y auditd audispd-plugins
```

`/etc/audit/rules.d/audit.rules` — add:
```
-a always,exit -F arch=b64 -S execve -k session_commands
-a always,exit -F arch=b32 -S execve -k session_commands
```
**Why:** logs every command executed on the box (`execve` = the syscall that runs a program),
tagged with the key `session_commands` so it's greppable. Combined with auth.log's session-open
timestamp, you get "user X logged in at T, then ran these commands."

```bash
sudo systemctl enable --now auditd
sudo ausearch -k session_commands --start today
```

**Caveat:** this logs *every* exec on the whole box, not just SSH sessions — cron jobs, app
subprocesses, etc. also show up. That's usually wanted (see [[resource-monitoring]]) but means
volume is higher than "just SSH." Filter by `ausearch -ua <uid>` for a specific user if needed.

## 3. Full session recording (optional, higher overhead) — `auditd` + shell logging via `script`
   or `tlog`

If you need literal keystroke/output replay (not just "which commands ran" but full terminal
transcript), use `tlog`:

```bash
sudo apt install -y tlog
```
Configure as the login shell for SSH users (`/etc/tlog/tlog-rec-session.conf`) — every session is
recorded to a file/journal and replayable with `tlog-play`. Heavier than auditd, use only if
literal session replay is a real requirement (e.g. contractor access to a client's box), not by
default on every server — it adds noticeable overhead and disk usage.

## 4. Centralize + protect the logs

Logs sitting only on the box that got compromised can be tampered with by whoever compromised it.
Minimum: ship `/var/log/auth.log` and audit logs to a separate log destination (rsyslog forward to
a central box, or a lightweight service) so a post-breach attacker can't cover tracks by editing
local logs.

```bash
# /etc/rsyslog.d/50-remote.conf — example, point at your own log collector
*.* @@log-collector.internal:514
```

## Related
- [[file-change-auditing]] — auditd rules for file writes, same daemon, different rule set
- [[../00-Home|Home]]
