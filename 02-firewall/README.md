---
tags: [firewall, ufw, fail2ban]
---

# Firewall (ufw) + fail2ban

## ufw — default-deny, explicit allow

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 2222/tcp comment 'ssh'     # match whatever port you set in sshd_config
sudo ufw allow 80/tcp comment 'http'
sudo ufw allow 443/tcp comment 'https'

sudo ufw enable
sudo ufw status verbose
```

**Why default-deny:** every port not explicitly opened is closed. This is the actual perimeter —
ufw is a friendly wrapper over iptables/nftables. Never `ufw allow` a broad range "just in case";
every open port is attack surface.

**Order matters:** allow the SSH port BEFORE `ufw enable`, or enabling the firewall cuts your own
session if it's not already allowed.

Do NOT open:
- Database ports (5432/3306/27017) to the public — app connects to `127.0.0.1` or a private
  network only, never expose DB directly.
- App backend ports (e.g. 7002 for a Node/PM2 process) — Nginx proxies to it over localhost;
  the port itself never needs a public ufw rule.
- Docker's own iptables rules can silently bypass ufw for published container ports — see note
  below if using Docker.

### If using Docker

Docker manipulates iptables directly and can expose container ports to the internet even when ufw
shows them closed. Fix:

```bash
# /etc/docker/daemon.json
{ "iptables": false }
```
Then manage all port exposure through ufw + explicit `-p 127.0.0.1:PORT:PORT` bindings in
docker-compose, never bare `-p PORT:PORT`. Restart docker after the daemon.json change.

## fail2ban — ban repeat offenders

```bash
sudo apt update && sudo apt install -y fail2ban
```

`/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = 2222

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true
filter  = nginx-botsearch
logpath = /var/log/nginx/*access.log
maxretry = 10
```

**Why:** ufw is a static allow/deny list — it doesn't react to behavior. fail2ban watches logs and
temp-bans IPs that show brute-force or scanning patterns (repeated SSH auth failures, repeated
404/403 probing for `wp-login.php`, `.env`, `phpmyadmin`, etc). `nginx-botsearch` specifically
catches the PHP/CMS exploit-scanner traffic every public IP gets constantly.

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd        # confirm jail active
```

## Related
- [[../01-ssh/README|SSH hardening]] — do first
- [[../03-nginx/README|Nginx hardening]] — nginx-botsearch jail depends on nginx access logs
  existing per-site (default `/var/log/nginx/*access.log` covers it if sites log there).
