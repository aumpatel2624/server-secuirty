---
tags: [nginx, reverse-proxy, hardening, headers, rate-limiting, php]
---

# Nginx Hardening

Two layers: [[global-nginx-conf|global nginx.conf changes]] (apply to every site on the box) and
[[site-template|per-site template]] (copy for each new vhost). Then the specific fix for PHP
cross-site contamination: [[php-isolation|PHP isolation]].

## Why nginx-level hardening even when the app sets its own headers

If the app (Express/helmet, Laravel, etc.) already sets security headers, **don't duplicate them
in nginx** — two sources for one header means they can disagree, and the browser uses whichever
arrives, which is non-deterministic to debug. Nginx should only set headers for things the app
*can't* control: TLS behavior, request-level attack surface (rate limiting, method filtering,
bad-bot blocking), and static-file-serving concerns.

Rule of thumb: **nginx defends the perimeter, the app defends the request.**

## Files in this section
- [[global-nginx-conf]] — `/etc/nginx/nginx.conf` changes, apply once per box
- [[site-template]] — annotated vhost template for a new site
- [[php-isolation]] — stop PHP execution outside intended directories (the "cross-hatching"
  concern — one compromised upload endpoint shouldn't be able to drop a webshell anywhere else
  on the filesystem nginx can reach)
- [[rate-limiting]] — `limit_req` zones and why
