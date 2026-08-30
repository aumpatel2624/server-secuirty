---
tags: [monitoring, backups, logging, updates]
---

# Monitoring, logging, backups

Hardening reduces attack surface; this section is what catches what gets through anyway and lets
you recover instead of starting over.

## Unattended security updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```
**Why:** most real-world compromises are unpatched known CVEs, not zero-days. Auto-applying
security patches closes that gap without needing someone to remember to `apt upgrade`.

## Backups — 3-2-1 minimum

- Database dumps + uploaded files, daily, automated (cron or systemd timer).
- At least one copy off this VPS entirely (S3/Backblaze/another provider). A backup stored only
  on the same box a ransomware/wiper attack hits is not a backup.
- Test restore quarterly — an untested backup is a hope, not a plan.

```bash
# example: daily pg_dump + rsync offsite, adjust per stack
0 2 * * * pg_dump dbname | gzip > /backups/db-$(date +\%F).sql.gz
0 3 * * * rsync -az /backups/ user@offsite-host:/backups/
```

## Log review

- `sudo fail2ban-client status sshd` — check ban counts weekly, spikes indicate targeted attention.
- `/var/log/nginx/*.error.log` — watch for repeated 403s from [[../03-nginx/php-isolation|PHP
  isolation rules]] firing — that's a real attempted webshell drop, not noise, worth knowing which
  IP and when.
- `sudo journalctl -u ssh --since "24 hours ago" | grep Failed` — failed SSH attempts, should be
  near-zero once password auth is off; any pubkey-auth failures for `AllowUsers`-listed accounts
  deserve a look.

## Centralizing (optional, once more than 1-2 boxes)

Ship logs to a central place (Loki, ELK, or even a simple centralized syslog) once managing more
than a couple of client VPSs — checking each box individually doesn't scale past that.

## Related
- [[../02-firewall/README|fail2ban]] — source of the ban-count log
- [[../03-nginx/php-isolation|PHP isolation]] — source of the 403 signal above
