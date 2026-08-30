---
tags: [nginx, php, webshell, isolation]
---

# PHP isolation — stopping cross-site / cross-directory execution

The concern from the original ask: an attacker who gets *any* file write into the webroot
(a vulnerable upload form, a compromised plugin, a misconfigured media library) tries to drop a
`.php` file — a webshell — and then requests it directly to get code execution. If nginx will
hand `.php` requests to PHP-FPM from *any* directory, that single write becomes full compromise.

This applies even if the box has no PHP site today — write the rule in now so it's not forgotten
when a client PHP site (WordPress, Laravel, etc.) gets added later.

## Rule 1 — PHP only executes from explicitly whitelisted paths

Bad (common copy-pasted config, executes PHP anywhere under the webroot):
```nginx
location ~ \.php$ {
    fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
}
```

Good — only the app's own entry point(s) can be executed:
```nginx
# Only index.php (or wherever the app's front controller lives) is
# reachable as PHP. Everything else that matches *.php is denied outright.
location = /index.php {
    fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}

location ~ \.php$ {
    return 403;
}
```

**Why:** most modern PHP frameworks (Laravel, Symfony, WordPress with front-controller rewriting)
only need ONE php file executed — everything else routes through it. Denying every other `.php`
means a webshell dropped in `/uploads/shell.php` returns 403 even though the file physically
exists on disk.

## Rule 2 — never execute PHP from upload/media directories, full stop

Belt-and-suspenders even with Rule 1 in place — put this BEFORE the general php block so it wins:
```nginx
location ~* ^/(uploads|wp-content/uploads|media|storage|public/uploads)/.*\.php$ {
    deny all;
    return 403;
}
```
**Why:** defense in depth. If Rule 1 is ever loosened by a future config change (someone
copy-pastes the "bad" example above during a migration), this still blocks the single most common
real-world webshell path — upload directories are, by definition, attacker-writable.

## Rule 3 — deny dotfiles and common sensitive extensions

```nginx
location ~ /\. {
    deny all;
}

location ~* \.(env|log|sql|bak|swp|ini|conf|old)$ {
    deny all;
}
```
**Why:** `.env`, `.git/`, backup files, and editor swap files leak secrets (DB credentials, API
keys) if left in the webroot and are among the most-scanned-for paths on the internet.

## Rule 4 — one PHP-FPM pool per site, not one shared pool

If multiple client sites share this box, give each its own PHP-FPM pool (`/etc/php/8.3/fpm/pool.d/clientA.conf`)
running as its own Linux user, not all as `www-data`.

```ini
[clientA]
user = clientA
group = clientA
listen = /var/run/php/clientA.sock
```

**Why this is the actual fix for "cross-hatching between attacks":** if every site's PHP-FPM
process runs as the same `www-data` user, a code-execution bug in Site A's PHP can read/write
Site B's files — they're the same OS user, filesystem permissions don't separate them. Per-site
pools + per-site Linux users make a compromise of one site NOT automatically a compromise of
every other site on the box. This is the single highest-leverage fix if this box is ever going to
host more than one client's PHP app.

## Related
- [[site-template]] — where these locations go in a real vhost
- [[../04-app-hardening/README|App hardening]] — upload validation, disabling PHP execution via
  `.htaccess`-equivalent belt-and-suspenders at the app/filesystem layer too
