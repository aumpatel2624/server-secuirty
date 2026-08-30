---
tags: [nginx, rate-limiting]
---

# Rate limiting

Zones defined once in [[global-nginx-conf|nginx.conf]], applied per-location in each site.

```nginx
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=3r/m;
limit_conn_zone $binary_remote_addr zone=addr:10m;
```

Applied in a vhost:
```nginx
location / {
    limit_req zone=general burst=20 nodelay;
    limit_conn addr 10;
    proxy_pass http://app_upstream;
    ...
}

location /login {
    limit_req zone=login burst=5;
    proxy_pass http://app_upstream;
    ...
}

location /api/auth {
    limit_req zone=login burst=5;
    proxy_pass http://app_upstream;
    ...
}
```

**Why two zones:**
- `general` (10 req/s per IP) — generous enough for normal browsing/API use, but stops a single
  IP from hammering the app with thousands of requests/sec (scraping, naive DoS, brute-force on
  non-auth endpoints).
- `login` (3 req/min per IP) — auth endpoints are the highest-value target for credential
  stuffing / brute force. 3/min is enough for a real user mistyping a password twice, far too
  slow for an automated attack to be worth running against.

**Why `burst` + `nodelay`:** without `burst`, legitimate bursts (a page loading 15 assets at once)
get instantly rejected. `burst=20 nodelay` allows a short burst through immediately, then throttles,
rather than queuing (which would add latency) or hard-rejecting (which breaks normal page loads).

**Why `limit_conn` too:** `limit_req` limits *rate*, `limit_conn` limits *concurrent* connections
per IP — stops one IP holding open many simultaneous slow connections even if each individual
request rate looks fine.

Tune the numbers per site based on real traffic — these are safe starting defaults, not universal
constants. Check `/var/log/nginx/*.error.log` for `limiting requests` entries after deploying to
confirm you're not blocking real users.
