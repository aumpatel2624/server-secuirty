---
tags: [ssh, hardening]
---

# SSH Hardening

Do this before anything else. If you break SSH and lock yourself out, ufw/fail2ban won't help —
Hostinger's browser console (or rescue mode) becomes your only way back in.

## 1. Add your SSH key first (before disabling passwords)

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub deployer@your-vps-ip
# or manually:
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA... you@laptop" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Why:** everything below assumes key auth works. Test it in a *second* terminal before touching
`sshd_config` — never edit `sshd_config` in the only session you have open.

## 2. Edit `/etc/ssh/sshd_config`

```
Port 2222                      # non-default port — cuts automated bot noise, NOT real security
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 20
AllowUsers deployer             # explicit allowlist — nobody else can even attempt login
ClientAliveInterval 300
ClientAliveCountMax 2
```

**Why each line:**
- `PermitRootLogin no` — root over SSH is the single highest-value credential on the box. Force
  `sudo` instead, which is logged per-user and revocable per-user.
- `PasswordAuthentication no` — kills all brute-force/credential-stuffing attempts outright. Keys
  can't be guessed.
- `MaxAuthTries 3` / `LoginGraceTime 20` — slows down anything that does get a session open.
- `AllowUsers deployer` — belt and suspenders: even a leaked/misissued key for another account
  can't be used to log in.
- `Port 2222` — optional, mild. Only reduces log noise from mass scanners; a targeted attacker
  finds it in seconds. Don't treat this as a real control.

## 3. Test before reload

```bash
sudo sshd -t                    # syntax check — MUST pass clean before restart
sudo systemctl restart ssh
```

Open a **brand new terminal** and confirm login still works (on the new port if changed) before
closing your current session. If it fails, your current session is still open — fix it there.

## 4. Confirm

```bash
ssh -p 2222 deployer@your-vps-ip "whoami"
```

## Related
- [[../02-firewall/README|Firewall]] — must allow the new SSH port before/when you change it, or
  you lock yourself out at the network layer instead.
