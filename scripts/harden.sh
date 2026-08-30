#!/usr/bin/env bash
# Reference script tying together 01-ssh, 02-firewall, 03-nginx sections.
# DO NOT run blind against a live multi-tenant box — read each section's
# README first, adjust site names/ports/paths, and run commands interactively
# a step at a time. This exists as a copy-paste reference, not a one-shot
# automation for a box already serving traffic.
#
# Safe to run start-to-finish only on a genuinely fresh, not-yet-live VPS.
set -euo pipefail

SSH_PORT=2222
DEPLOY_USER=deployer

echo "== 1. ufw base rules (allow new SSH port BEFORE enabling) =="
ufw allow "${SSH_PORT}/tcp" comment 'ssh'
ufw allow 80/tcp comment 'http'
ufw allow 443/tcp comment 'https'
ufw default deny incoming
ufw default allow outgoing

echo "== 2. fail2ban =="
apt update
apt install -y fail2ban
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = ${SSH_PORT}

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true
filter  = nginx-botsearch
logpath = /var/log/nginx/*access.log
maxretry = 10
EOF
systemctl enable --now fail2ban

echo "== 3. unattended-upgrades =="
apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

echo "=================================================================="
echo "STOP HERE. SSH config and nginx.conf edits are NOT automated —"
echo "do those manually per 01-ssh/README.md and 03-nginx/global-nginx-conf.md,"
echo "testing sshd -t / nginx -t before every restart/reload, keeping a"
echo "second session open until each change is confirmed working."
echo "Only then: ufw enable"
echo "=================================================================="
