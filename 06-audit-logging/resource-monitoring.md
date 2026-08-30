---
tags: [monitoring, cpu, process-accounting, incident-response]
---

# Resource monitoring — root-causing CPU/resource spikes after the fact

Directly addresses the incident: VPS hit 100% CPU, provider auto-shut it off, root cause still
unknown. The fix is making sure the NEXT spike leaves evidence, since this one didn't.

## Why the last incident left no trace

Default Ubuntu has no historical process-level accounting. `top`/`htop` only show *current* state
— once the box is rebooted/shut off, whatever was consuming CPU at the time is gone with no
record of which process/user/command it was. This is the actual gap to close.

## 1. `sysstat` — historical CPU/memory/disk/network graphs

```bash
sudo apt install -y sysstat
sudo systemctl enable --now sysstat
```
Enable 1-minute-resolution collection in `/etc/default/sysstat` and `/etc/cron.d/sysstat`
(package sets 10-min default — tighten it):
```
# /etc/cron.d/sysstat
*/1 * * * * root /usr/lib/sysstat/debian-sa1 1 1
```
**Why 1-minute not the 10-minute default:** a CPU spike that causes a shutdown can happen and
resolve within minutes. 10-minute sampling can miss the entire event between two samples. 1-minute
costs negligible disk and catches short spikes.

After an incident:
```bash
sar -u -f /var/log/sysstat/saDD        # CPU usage, DD = day of month
sar -r -f /var/log/sysstat/saDD        # memory
```
Tells you WHEN CPU spiked and HOW HIGH — but not WHICH PROCESS. Need #2 for that.

## 2. `atop` — per-process history (the actual "which process" answer)

```bash
sudo apt install -y atop
sudo systemctl enable --now atop
```
Default logs to `/var/log/atop/atop_YYYYMMDD`, one snapshot per 10 min by default — tighten in
`/etc/default/atop`:
```
INTERVAL=60
```
Replay history for a specific time:
```bash
sudo atop -r /var/log/atop/atop_20260830 -b 03:00
```
**Why atop over sysstat for this specific question:** sysstat aggregates system-wide totals. atop
keeps a per-process breakdown AND — critically — accounts for short-lived processes that exited
before the next sample by reading `/proc` exit accounting. A process that spiked CPU for 90
seconds and then died (e.g. a crashed cryptominer, a runaway build process) still shows up in atop
history. This is the single most direct fix for "we don't know what caused the spike."

## 3. `psacct` / `acct` — full process accounting, every process that ever ran

```bash
sudo apt install -y acct
sudo systemctl enable --now acct
```
```bash
lastcomm                    # every command run, by whom, how much CPU/time it used
sa                          # summarized accounting report
```
**Why on top of atop:** atop samples at intervals (default now 60s); a process that starts and
finishes entirely between two samples can still be missed. `acct` hooks the kernel's process
accounting directly — every process that exits is logged, no sampling gap possible. This is the
belt-and-suspenders layer for the exact failure mode that caused the unexplained incident.

## 4. Alerting BEFORE it hits 100% and gets auto-shut-off

Reactive logging tells you what happened after. This stops the auto-shutdown from happening again:

```bash
# simple cron-based watchdog, adjust threshold/action to taste
*/2 * * * * root /usr/local/bin/cpu-alert.sh
```
```bash
#!/bin/bash
# /usr/local/bin/cpu-alert.sh
THRESHOLD=90
LOAD=$(awk '{print int($1)}' /proc/loadavg)
CORES=$(nproc)
if [ "$LOAD" -gt "$((CORES * 90 / 100))" ]; then
    echo "$(date): load $LOAD on $CORES cores" >> /var/log/cpu-alerts.log
    top -bn1 | head -20 >> /var/log/cpu-alerts.log
    # optionally: curl a webhook / send mail here
fi
```
**Why this matters more than the logging tools above:** logging tells you the cause after a
shutdown already happened and the client was already impacted. An alert firing at 90% gives a
chance to intervene (kill the runaway process, scale resources) BEFORE the provider's own
auto-shutoff trips at 100%. For a client-facing box, prevention beats postmortem.

For anything beyond a single box, replace this cron script with a real monitoring stack
(Netdata, Prometheus + node_exporter + Alertmanager) — the cron version is a minimum-viable
stopgap, not a long-term answer once managing multiple client VPSs.

## Related
- [[file-change-auditing]] — correlate a CPU spike against a file write at the same timestamp
  (e.g. a webshell that also runs a cryptominer)
- [[ssh-session-logging]] — rule in/out whether an SSH session was active during the spike
