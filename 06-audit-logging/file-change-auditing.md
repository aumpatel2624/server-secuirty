---
tags: [auditd, aide, file-integrity, forensics]
---

# File-change auditing

Two complementary approaches: **auditd** (real-time, who/when/which-process changed a file) and
**AIDE** (periodic integrity snapshot, catches anything auditd rules didn't cover).

## 1. auditd — real-time file watch on the paths that matter

Already installed if you did [[ssh-session-logging|SSH session logging]]. Add watches for the
directories that actually matter — don't watch the whole filesystem, that's noise overload.

`/etc/audit/rules.d/audit.rules` — add:
```
# Webroot — catch any write, the actual "did someone drop a webshell" signal
-w /var/www/ -p wa -k webroot_changes

# Nginx config — catch unauthorized changes outside the deploy pipeline
-w /etc/nginx/ -p wa -k nginx_changes

# SSH config and authorized_keys — catch privilege-escalation persistence
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes
-w /home/deployer/.ssh/authorized_keys -p wa -k authkeys_changes

# sudoers — catch privilege escalation
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# cron — catch persistence via scheduled jobs (a common post-compromise foothold)
-w /etc/crontab -p wa -k cron_changes
-w /var/spool/cron/ -p wa -k cron_changes
```
`-p wa` = watch write + attribute-change (permissions/ownership). `-k` = searchable tag.

```bash
sudo systemctl restart auditd
sudo ausearch -k webroot_changes --start today
```

**Why these specific paths and not "everything":** auditd logs are only useful if you actually
read them. Watching `/` generates enormous noise (every log rotation, every temp file, every
package update) and the real signal — an unexpected write to the webroot or SSH config — drowns.
Watch high-value targets: places where a write means either code execution (webroot) or
persistence (SSH keys, sudoers, cron).

**Output includes:** timestamp, exact file path, which UID/process wrote it, success/failure. This
is what answers "what changed and who did it" after an incident — correlate the UID against the
SSH session log from the same timestamp.

## 2. AIDE — periodic integrity baseline (catches what auditd rules missed)

```bash
sudo apt install -y aide
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

Daily cron check:
```bash
# /etc/cron.daily/aide-check
#!/bin/bash
/usr/bin/aide --check | mail -s "AIDE report: $(hostname)" you@example.com
```

**Why run both auditd AND AIDE:** auditd only catches changes to paths you explicitly listed —
miss a path, miss the event. AIDE hashes the *entire* filesystem against a known-good baseline and
flags ANY change, including in paths nobody thought to watch. It's slower (daily batch, not
real-time) but has no blind spots. auditd = fast + real-time + narrow. AIDE = slow + periodic +
comprehensive. Together they cover each other's gap.

**Caveat:** re-baseline (`aideinit` again) after every legitimate deploy, or every deploy shows
up as a false-positive "unexpected change" flood and the report gets ignored — which defeats the
purpose.

## Related
- [[ssh-session-logging]] — correlate the UID/timestamp from here against session logs
- [[resource-monitoring]]
