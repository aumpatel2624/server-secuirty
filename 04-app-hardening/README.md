---
tags: [app, php, node, uploads, secrets]
---

# App-layer hardening

Nginx and the firewall protect the perimeter; these are things only the app itself can fix.

## Secrets

- Never commit `.env` / credentials to git. Confirm `.gitignore` covers it BEFORE first commit —
  removing a secret from git history later requires a force-push rewrite, painful on a shared repo.
- Rotate any secret that ever touched a chat log, ticket, or screen share — including this
  conversation. Treat as compromised the moment it's typed anywhere outside the terminal it's used in.
- DB credentials, API keys, session secrets: environment variables or a secrets manager, never
  hardcoded in source.

## File uploads (the webshell vector)

- Validate file type by **content** (magic bytes), not filename extension or `Content-Type`
  header — both are trivially spoofed by the client.
- Store uploads outside the webroot where possible, or in a directory nginx is configured to
  never execute as PHP/CGI (see [[../03-nginx/php-isolation|PHP isolation]]).
- Rename uploaded files on save (random name + validated extension) — never trust the original
  filename, which can contain path traversal (`../../etc/passwd`) or a double extension
  (`shell.php.jpg`) trick.
- Enforce a server-side size limit that matches (or is tighter than) the nginx `client_max_body_size`.

## PHP-specific (if/when a client PHP site lands here)

`php.ini` hardening:
```ini
expose_php = Off              ; don't leak PHP version in headers
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source
; Why: these are the functions webshells use to run OS commands or read
; arbitrary files. Most CMS/framework code never calls them directly — if
; the app breaks after disabling one, that's worth investigating, not
; blindly re-enabling.
allow_url_fopen = Off         ; stops remote file inclusion (RFI) attacks
allow_url_include = Off
open_basedir = /var/www/SITE/:/tmp/
; Why: hard filesystem jail — even a successful code-execution bug can't
; read/write outside the site's own directory. This is the app-layer
; equivalent of the per-site PHP-FPM pool in php-isolation.md — belt and
; suspenders together.
```

## Node/PM2-specific

- Run the PM2 process as a dedicated non-root user, never root.
- Set `NODE_ENV=production` — disables verbose stack traces in error responses that leak file
  paths and dependency versions to attackers.
- Keep `npm audit` / `npm outdated` in CI or a scheduled check — dependency CVEs are the most
  common real-world Node compromise vector, not custom code bugs.

## Related
- [[../03-nginx/php-isolation|Nginx PHP isolation]] — the perimeter half of this
- [[../05-monitoring-backups/README|Monitoring]] — catching what got through anyway
