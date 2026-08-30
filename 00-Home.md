---
tags: [vps, security, hostinger, playbook]
---

# VPS Hardening Playbook — Fresh Hostinger VPS Baseline

Target: brand-new Ubuntu 22.04/24.04 VPS from Hostinger (or any provider), before any client site
is deployed on it. This is the checklist we run on every new box so client VPSs match one hardened
baseline instead of drifting.

Assumes: Nginx as reverse proxy, app backends (Node/PM2, or PHP-FPM if a client stack needs it)
behind it, no Docker required but notes included where Docker is used instead.

## Order of operations

1. [[01-ssh/README|SSH hardening]] — do this FIRST, before firewall, so you don't lock yourself out
2. [[02-firewall/README|Firewall (ufw) + fail2ban]]
3. [[03-nginx/README|Nginx hardening]]
4. [[04-app-hardening/README|App-layer hardening]] (PHP, Node, uploads, secrets)
5. [[05-monitoring-backups/README|Monitoring, logging, backups]]

## Ground rules

- **Never edit nginx site configs live if they're git-deployed.** Check for a header comment
  saying "source of truth is the repo" before touching `/etc/nginx/sites-available/*` directly.
  Edit in repo, deploy, let the pipeline install + `nginx -t` + reload.
- **SSH hardening before firewall.** If you lock SSH to key-only and then lock yourself out with
  no working key, ufw won't save you. Test a NEW session stays open before closing the old one.
- **One change, one test.** `nginx -t` after every nginx edit. `sshd -t` after every sshd_config
  edit. Never batch untested changes.
- **Multi-tenant box = blast radius.** If this VPS hosts more than one client site, any nginx.conf
  or OS-level change affects all of them. Test in a maintenance window, not mid-day.
