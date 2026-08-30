---
tags: [audit, logging, ssh, auditd, monitoring, forensics]
---

# Audit logging — who logged in, what changed, why CPU spiked

Answers three separate questions, each needing a different tool:

1. **Who SSH'd in, when, from where** → [[ssh-session-logging|SSH session logging]]
2. **What files changed, by whom, when** → [[file-change-auditing|auditd file-change auditing]]
3. **Why did CPU/resources spike (the past incident)** → [[resource-monitoring|resource monitoring
   + process accounting]]

Set up all three BEFORE the next incident — logs only exist going forward from when logging is
enabled; you cannot retroactively recover what already happened without them.

## Why one tool doesn't cover all three

- SSH logs (`journalctl -u ssh` / `/var/log/auth.log`) tell you *a session opened*, not what that
  session did once inside.
- File integrity alone (auditd/AIDE) tells you *a file changed*, not who was logged in when it
  happened — you correlate the two by timestamp.
- CPU/resource spikes are usually NOT an SSH session at all — cron jobs, a runaway app process, or
  a compromised web-facing endpoint (reverse shell, cryptominer) never touch SSH. Needs its own
  process-level accounting.

Cross-referencing all three by timestamp is what actually reconstructs an incident: "at 03:14 UTC,
`www-data` process PID 4821 spiked CPU to 100%, auditd shows `/var/www/site/uploads/x.php` was
written at 03:13 by `www-data`, no SSH session was active" → that's a webshell dropped through the
app, not a compromised SSH key. Without all three, you have one data point and a guess.
