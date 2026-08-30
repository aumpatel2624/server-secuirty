---
tags: [nginx, vhost, template]
---

# Per-site vhost template (annotated)

Copy into `/etc/nginx/sites-available/SITE.conf`, symlink into `sites-enabled/`. If the project
uses a git-deployed config pipeline (check for a header comment saying so — see
[[../00-Home|ground rules]]), put this in the repo instead and let the deploy pipeline install it.

```nginx
# ---------------------------------------------------------------------------
# HTTP — ACME challenge only, everything else redirected to HTTPS.
# ---------------------------------------------------------------------------
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# ---------------------------------------------------------------------------
# HTTPS — the real site.
# ---------------------------------------------------------------------------
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com www.example.com;

    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    include             /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam         /etc/letsencrypt/ssl-dhparams.pem;

    # --- Security headers ----------------------------------------------
    # ONLY add these if the app itself does not already set them (helmet,
    # Laravel secure-headers middleware, etc). Check first — duplicate
    # headers from two layers can conflict and browsers pick unpredictably.
    add_header X-Content-Type-Options "nosniff" always;
    # Why: stops browsers "sniffing" a response's content-type and
    # executing e.g. an uploaded .txt file as JS/HTML. Cheap, no downside.

    add_header X-Frame-Options "SAMEORIGIN" always;
    # Why: prevents this site being iframed by another origin —
    # clickjacking defense. Use "DENY" if the site never needs framing at
    # all, SAMEORIGIN if you frame your own pages.

    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    # Why: stops leaking full URLs (which may contain tokens/IDs in query
    # strings) to third-party sites via the Referer header.

    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    # Why: explicitly disables browser features the site doesn't use —
    # defense against a compromised third-party script trying to access
    # camera/mic/location.

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    # Why: tells browsers to NEVER attempt plain HTTP to this domain again
    # for a year, even if a link/bookmark uses http://. Kills SSL-stripping
    # MITM attacks. Only add once you're CERTAIN the site will stay on
    # HTTPS permanently — this is hard to walk back quickly (browsers cache
    # it for max-age).
    # Do NOT add `preload` until you've tested max-age for a while — the
    # HSTS preload list is very hard to get removed from.

    # Content-Security-Policy is deliberately NOT set here — it is highly
    # app-specific (depends on what scripts/styles/fonts the app loads) and
    # a wrong CSP silently breaks the site. Set it in the app layer where
    # someone testing the app will notice breakage immediately.

    # --- Request limits ---------------------------------------------------
    client_max_body_size 12m;
    # Match this to the app's own upload limit (e.g. multer FILE_SIZE_LIMITS)
    # plus a small margin for multipart overhead — see demo.vyaris.com.conf
    # for a real example of this reasoning. Bare nginx errors are uglier
    # than the app's own 413 handler.

    # --- Rate limiting — see rate-limiting.md ------------------------------
    limit_conn addr 10;

    # --- Bad-bot blocking (uses $blocked_ua map from nginx.conf) ----------
    if ($blocked_ua) {
        return 403;
    }

    # --- Dotfiles / sensitive extensions — see php-isolation.md -----------
    location ~ /\. {
        deny all;
    }
    location ~* \.(env|log|sql|bak|swp|ini|conf|old)$ {
        deny all;
    }

    # --- PHP isolation — only if this site runs PHP, see php-isolation.md -
    # location ~* ^/(uploads|storage)/.*\.php$ { deny all; return 403; }
    # location = /index.php { fastcgi_pass unix:/var/run/php/SITE.sock; ... }
    # location ~ \.php$ { return 403; }

    access_log /var/log/nginx/example.com.access.log;
    error_log  /var/log/nginx/example.com.error.log;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_types text/plain text/css text/javascript application/javascript application/json image/svg+xml;

    # --- Proxy to app backend ----------------------------------------------
    location / {
        limit_req zone=general burst=20 nodelay;

        proxy_pass http://127.0.0.1:PORT;
        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host  $host;
        # X-Forwarded-Proto is required if the app sets secure cookies and
        # checks `trust proxy` — without it the app can't tell the original
        # request was HTTPS and will refuse to set the cookie.

        proxy_connect_timeout  10s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }

    location /login {
        limit_req zone=login burst=5;
        proxy_pass http://127.0.0.1:PORT;
        include proxy_params_snippet;  # reuse the same proxy_set_header block
    }
}
```

**After any edit:**
```bash
sudo nginx -t && sudo systemctl reload nginx
```
Never reload without `-t` passing first — a syntax error in a reload takes down every site on the
box, not just the one you edited.
