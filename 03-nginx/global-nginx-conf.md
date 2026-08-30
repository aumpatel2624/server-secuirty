---
tags: [nginx, global-config]
---

# Global `/etc/nginx/nginx.conf` hardening

Edit `/etc/nginx/nginx.conf` directly (this file is not usually git-managed — the per-site vhosts
are). Back it up first: `sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak`.

```nginx
http {
    # --- Identity leakage -----------------------------------------------
    server_tokens off;
    # Why: default nginx sends "Server: nginx/1.24.0" on every response and
    # every error page. That version number is a lookup key for known CVEs.
    # Turning it off doesn't stop a determined attacker (fingerprinting
    # still works) but it removes the box's software+version from every
    # automated scanner's easiest signal.

    # --- Request size / slow-client limits -------------------------------
    client_max_body_size 10m;
    # Why: default is unlimited on some setups. A default cap makes every
    # site safe-by-default against oversized upload DoS; override per-site
    # in the vhost if a site genuinely needs bigger uploads (see site
    # template comment on this).

    client_body_timeout 12s;
    client_header_timeout 12s;
    send_timeout 10s;
    # Why: mitigates slow-loris style connection exhaustion — a client
    # trickling bytes to hold a worker open indefinitely.

    # --- Buffer overflow style requests ----------------------------------
    large_client_header_buffers 4 8k;
    # Why: default header buffer size is often fine, but this bounds it
    # explicitly rather than trusting the compiled default.

    # --- Rate limiting zones (defined here, applied per-location) --------
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=3r/m;
    limit_conn_zone $binary_remote_addr zone=addr:10m;
    # Why: see rate-limiting.md — defining zones here makes them available
    # to every vhost without redefining per-site.

    # --- TLS baseline (per-site still needs its own cert directives) -----
    ssl_protocols TLSv1.2 TLSv1.3;
    # Why: TLS 1.0/1.1 are deprecated (BEAST, POODLE-adjacent weaknesses)
    # and PCI-DSS has required disabling them since 2018. TLS 1.2+ only.
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    # Why: session tickets can be a forward-secrecy weakness if the
    # ticket key isn't rotated; sessions cache is the safer default for a
    # single-box setup.

    # --- Logging -----------------------------------------------------
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                     '$status $body_bytes_sent "$http_referer" '
                     '"$http_user_agent" rt=$request_time';
    access_log /var/log/nginx/access.log main;
    # Why: default log format doesn't include $request_time — you cannot
    # spot slow-endpoint abuse or diagnose performance without it.

    # --- Bad-bot / scanner user-agent blocking (optional, light touch) ---
    map $http_user_agent $blocked_ua {
        default 0;
        ~*(nikto|sqlmap|acunetix|nessus|masscan) 1;
    }
    # Why: trivially spoofed, so this is not a real security boundary —
    # it just cuts obvious noise from unsophisticated scanners out of logs
    # and off CPU. Applied via `if ($blocked_ua) { return 403; }` in the
    # site template, not here.
}
```

Test and reload:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

**Never `restart` when `reload` works** — restart drops in-flight connections, reload is graceful.
