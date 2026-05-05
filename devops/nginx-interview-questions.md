# Nginx Interview Questions

**Level:** Mid to Senior
**Topics:** Architecture, Reverse Proxy, Load Balancing, TLS, Caching, Rate Limiting, Security, Performance Tuning

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Configuration Structure](#configuration-structure)
3. [Reverse Proxy](#reverse-proxy)
4. [Load Balancing](#load-balancing)
5. [SSL/TLS and HTTP/2 / HTTP/3](#ssltls-and-http2--http3)
6. [Caching](#caching)
7. [Rate Limiting and Compression](#rate-limiting-and-compression)
8. [Static Files, FastCGI, WebSockets](#static-files-fastcgi-websockets)
9. [Locations, Rewrites, and Headers](#locations-rewrites-and-headers)
10. [Security](#security)
11. [Performance Tuning](#performance-tuning)
12. [Operations and Debugging](#operations-and-debugging)

---

## Fundamentals

### Q1. What is Nginx?

**Answer:**
A high-performance HTTP server, reverse proxy, load balancer, and TCP/UDP proxy. Known for its event-driven, asynchronous architecture that handles tens of thousands of concurrent connections with low memory.

---

### Q2. Nginx vs Apache?

| Aspect | Nginx | Apache |
|--------|-------|--------|
| Architecture | Event-driven, async | Process/thread per connection |
| Concurrency | Excellent (C10K+) | Lower without `event` MPM |
| Static files | Very fast | Fast |
| Dynamic content | Via FastCGI/upstream | mod_php, etc. embedded |
| Config | Block-based | `.htaccess`, directives |
| `.htaccess` | No (better perf) | Yes |
| Modules | Compile-time mostly | Loadable at runtime |

Nginx is typically the front edge; Apache is fine as an app server.

---

### Q3. Nginx architecture?

**Answer:**
- **Master process** — reads config, manages workers, binds ports.
- **Worker processes** — handle connections; one per CPU core typically.
- **Event-driven loop** — uses `epoll` (Linux), `kqueue` (BSD/macOS) — non-blocking I/O.

A single worker handles thousands of connections via the event loop, instead of one thread per connection.

---

### Q4. Why is Nginx so fast?

**Answer:**
1. Async event-driven model.
2. Non-blocking I/O.
3. Efficient memory use (small per-connection footprint).
4. `sendfile()` zero-copy for static files.
5. Fixed worker pool (no fork-per-request).
6. Optimized C implementation.

---

## Configuration Structure

### Q5. Top-level config blocks?

```nginx
# /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
  worker_connections 1024;
  multi_accept on;
  use epoll;
}

http {
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
```

Hierarchy: `main` → `events`, `http` → `server` → `location`. Nginx also supports `stream {}` for TCP/UDP proxying and `mail {}`.

---

### Q6. Server block (virtual host) example?

```nginx
server {
  listen 80;
  listen [::]:80;
  server_name example.com www.example.com;
  root /var/www/example;
  index index.html;

  location / {
    try_files $uri $uri/ =404;
  }

  access_log /var/log/nginx/example.access.log;
  error_log  /var/log/nginx/example.error.log warn;
}
```

Multiple server blocks share a port — the `Host` header chooses the match. The first listed block matching the listen address is the "default" if no `server_name` matches.

---

### Q7. How does Nginx select a server block?

**Answer:**
1. Match `listen` directive (IP:port).
2. Match `server_name` (exact > leading wildcard `*.example.com` > trailing wildcard `mail.*` > regex).
3. Otherwise, default server (first block on that listen, or one with `default_server`).

```nginx
listen 443 ssl default_server;
```

---

## Reverse Proxy

### Q8. Reverse proxy basics?

```nginx
server {
  listen 80;
  server_name api.example.com;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host  $host;

    proxy_connect_timeout 5s;
    proxy_read_timeout    60s;
    proxy_send_timeout    60s;
  }
}
```

---

### Q9. Why use Nginx as a reverse proxy?

**Answer:**
- **TLS termination** — offload crypto from app.
- **Load balancing** — distribute across upstreams.
- **Caching** — reduce backend load.
- **Rate limiting** — protect backend.
- **Static file serving** — faster than most app servers.
- **Compression** — gzip/brotli.
- **Security** — WAF features, hide backend, header policies.
- **Header manipulation**.
- **HTTP/2 and HTTP/3** at the edge while backend stays HTTP/1.1.

---

### Q10. `proxy_pass` with vs without trailing slash?

**Answer:**

```nginx
location /api/ {
  proxy_pass http://backend/;        # request /api/users → backend /users
}

location /api/ {
  proxy_pass http://backend;         # request /api/users → backend /api/users
}
```

- Trailing slash on `proxy_pass` URI replaces the matched location prefix.
- No URI on `proxy_pass` (just host:port) preserves the full path.

A small but common bug source.

---

### Q11. Forward proxy vs reverse proxy?

| | Forward proxy | Reverse proxy |
|---|---|---|
| Sits in front of | Clients | Servers |
| Used by | Clients to reach servers | Servers to receive client traffic |
| Examples | Squid, corporate proxy | Nginx, HAProxy, Cloudflare |
| Visible to | Server doesn't see real client | Client doesn't see real server |

---

## Load Balancing

### Q12. Load balancing methods?

```nginx
upstream backend {
  # round-robin (default)
  server 10.0.0.1:3000;
  server 10.0.0.2:3000;
}

upstream backend_lc {
  least_conn;
  server 10.0.0.1:3000;
  server 10.0.0.2:3000;
}

upstream backend_iphash {
  ip_hash;                    # session stickiness
  server 10.0.0.1:3000;
  server 10.0.0.2:3000;
}

upstream backend_weighted {
  server 10.0.0.1:3000 weight=3;
  server 10.0.0.2:3000 weight=1;
  server 10.0.0.3:3000 backup;     # used only when others fail
}

upstream backend_hash {
  hash $request_uri consistent;     # consistent hashing
  server 10.0.0.1:3000;
  server 10.0.0.2:3000;
}
```

| Method | Use case |
|--------|----------|
| Round-robin | Default; even distribution |
| `least_conn` | Backends with varying request times |
| `ip_hash` | Sticky sessions by client IP |
| `hash $key` | Sticky by arbitrary key (URI, cookie) |
| `random two least_conn` | Power-of-two-choices, scales well |

---

### Q13. Health checks?

**Answer:**
- **Open-source Nginx** — passive only:
  ```nginx
  upstream backend {
    server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
    server 10.0.0.2:3000 max_fails=3 fail_timeout=30s;
  }
  ```
  After 3 failures within 30s, the server is marked down and skipped for 30s.

- **Nginx Plus** — active probes (HTTP, TCP) on a dedicated path.

For active health checks in OSS Nginx, use third-party modules (`nginx_upstream_check_module`) or rely on a separate health checker.

---

### Q14. Upstream failover?

```nginx
upstream backend {
  server primary.local:3000 max_fails=2 fail_timeout=10s;
  server secondary.local:3000 backup;
}

location / {
  proxy_pass http://backend;
  proxy_next_upstream error timeout http_502 http_503 http_504;
  proxy_next_upstream_tries 2;
  proxy_next_upstream_timeout 10s;
}
```

---

### Q15. Sticky sessions?

**Answer:**
- `ip_hash` — same client IP → same backend (breaks behind NATs).
- `hash $cookie_session consistent` — sticky by app cookie.
- Nginx Plus has cookie-based sticky out of the box.

Better: make backends stateless by storing sessions in Redis/DB.

---

## SSL/TLS and HTTP/2 / HTTP/3

### Q16. Basic TLS configuration?

```nginx
server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name example.com;

  ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers off;
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;

  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 1d;
  ssl_session_tickets off;

  ssl_stapling on;
  ssl_stapling_verify on;

  add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
}

server {
  listen 80;
  server_name example.com;
  return 301 https://$host$request_uri;
}
```

---

### Q17. What is OCSP stapling?

**Answer:**
The server fetches its OCSP response from the CA periodically and serves it in the TLS handshake. Saves the client an extra request to verify the cert isn't revoked, improving handshake latency and privacy.

---

### Q18. HTTP/2 vs HTTP/3?

| | HTTP/2 | HTTP/3 |
|---|---|---|
| Transport | TCP + TLS | QUIC (UDP) + TLS 1.3 |
| Multiplexing | Yes (over TCP) | Yes (no head-of-line blocking) |
| Head-of-line blocking | TCP-level | None |
| Connection migration | No | Yes (survives IP changes) |
| TLS | Optional in spec, required in browsers | Mandatory |

HTTP/2: `listen 443 ssl http2;`
HTTP/3 (Nginx 1.25+):
```nginx
listen 443 ssl;
listen 443 quic reuseport;
http2 on;
http3 on;
add_header Alt-Svc 'h3=":443"; ma=86400' always;
```

---

### Q19. Why TLS 1.3?

**Answer:**
- 1-RTT handshake (vs 2-RTT in TLS 1.2); 0-RTT for resumption.
- Removed weak ciphers (RC4, CBC modes, SHA-1).
- Forward secrecy mandatory.
- Encrypted handshake messages.

Disable TLS 1.0/1.1 — they're insecure.

---

## Caching

### Q20. proxy_cache configuration?

```nginx
http {
  proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=mycache:100m
                   max_size=10g inactive=60m use_temp_path=off;

  proxy_cache_key "$scheme$request_method$host$request_uri";

  server {
    location / {
      proxy_cache mycache;
      proxy_cache_valid 200 302 10m;
      proxy_cache_valid 404 1m;
      proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
      proxy_cache_background_update on;
      proxy_cache_lock on;
      add_header X-Cache-Status $upstream_cache_status;

      proxy_pass http://backend;
    }
  }
}
```

`$upstream_cache_status` values: `MISS`, `HIT`, `EXPIRED`, `BYPASS`, `STALE`, `UPDATING`, `REVALIDATED`.

---

### Q21. Cache invalidation strategies?

**Answer:**
- **TTL-based** — `proxy_cache_valid` with appropriate expiry.
- **Bypass on cookies** — don't cache responses for logged-in users:
  ```nginx
  proxy_cache_bypass $cookie_session;
  proxy_no_cache     $cookie_session;
  ```
- **PURGE module** (Nginx Plus or `ngx_cache_purge`) — explicit invalidation.
- **Versioned URLs** — change asset URLs (`app.abc123.js`) on deploy.
- **`Cache-Control` headers** — backend controls cacheability.

---

### Q22. Open file cache?

```nginx
open_file_cache          max=10000 inactive=60s;
open_file_cache_valid    60s;
open_file_cache_min_uses 2;
open_file_cache_errors   on;
```

Caches file descriptors and metadata — big win for static-heavy sites.

---

## Rate Limiting and Compression

### Q23. Rate limiting?

```nginx
http {
  limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
  limit_conn_zone $binary_remote_addr zone=conn:10m;

  server {
    location /api/ {
      limit_req zone=api burst=20 nodelay;
      limit_conn conn 10;
      limit_req_status 429;
      limit_conn_status 429;

      proxy_pass http://backend;
    }
  }
}
```

- `rate=10r/s` — token bucket at 10 requests/second per IP.
- `burst=20` — allow burst of 20 above the rate.
- `nodelay` — process burst immediately (otherwise queued/throttled).
- `$binary_remote_addr` — uses 4 bytes (IPv4) instead of string (saves memory).

---

### Q24. Compression?

```nginx
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 5;
gzip_min_length 1024;
gzip_types
  text/plain text/css application/json application/javascript
  text/xml application/xml application/xml+rss text/javascript
  image/svg+xml font/ttf font/otf;

# Brotli (requires module)
brotli on;
brotli_comp_level 5;
brotli_types text/plain text/css application/json application/javascript image/svg+xml;
```

Don't compress already-compressed assets (jpg, png, mp4, woff2). Pre-compress assets at build time and serve with `gzip_static on;` or `brotli_static on;`.

---

## Static Files, FastCGI, WebSockets

### Q25. Static files?

```nginx
server {
  listen 80;
  root /var/www/site;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
  }
}
```

`try_files` is essential for SPAs — falls back to `index.html` for client-side routes.

---

### Q26. PHP via FastCGI (PHP-FPM)?

```nginx
server {
  listen 80;
  server_name app.local;
  root /var/www/app/public;
  index index.php;

  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_buffer_size 16k;
    fastcgi_buffers 4 16k;
  }

  location ~ /\.ht { deny all; }
}
```

---

### Q27. WebSocket proxying?

```nginx
location /ws/ {
  proxy_pass http://backend;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header Host $host;
  proxy_read_timeout 3600s;          # long-lived
  proxy_send_timeout 3600s;
}
```

Without `Upgrade`/`Connection` headers, the WebSocket handshake fails.

---

### Q28. Keep-alive to upstream?

```nginx
upstream backend {
  server 10.0.0.1:3000;
  keepalive 32;
}

server {
  location / {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
  }
}
```

Without `Connection ""`, the default `close` header tears down upstream connections per request.

---

## Locations, Rewrites, and Headers

### Q29. Location matching priority?

**Order:**
1. `=` exact match — highest priority.
2. `^~` prefix match — if matches, regex skipped.
3. `~` (case-sensitive) and `~*` (case-insensitive) regex — first match wins.
4. Plain prefix match — longest one wins.

```nginx
location = /favicon.ico { ... }   # exact
location ^~ /images/    { ... }   # prefix, no regex
location ~* \.(png|jpg)$ { ... }  # case-insensitive regex
location / { ... }                # catch-all
```

---

### Q30. Rewrites?

```nginx
# Permanent redirect
rewrite ^/old/(.*)$ /new/$1 permanent;

# Internal rewrite
rewrite ^/blog/([0-9]+)/?$ /index.php?post_id=$1 last;

# Redirect via return (preferred for static cases)
return 301 https://$host$request_uri;

# Rewrite flags
# last  - re-evaluate locations
# break - stop in current location
# redirect - 302
# permanent - 301
```

Use `return` for simple redirects — faster than `rewrite`.

---

### Q31. Common variables?

| Variable | Meaning |
|----------|---------|
| `$host` | `Host` header (or server_name fallback) |
| `$http_<name>` | Any incoming header |
| `$remote_addr` | Client IP |
| `$request_uri` | Full URI with args |
| `$uri` | Normalized URI (no args) |
| `$args` / `$query_string` | Query string |
| `$arg_NAME` | Specific query param |
| `$scheme` | `http` or `https` |
| `$request_method` | `GET`, `POST`, etc. |
| `$cookie_NAME` | Specific cookie |
| `$server_name` | Matched server_name |
| `$upstream_addr` | Upstream server used |
| `$upstream_response_time` | Backend latency |
| `$request_time` | Total request time |

---

### Q32. X-Forwarded-For vs X-Real-IP?

**Answer:**
- `X-Real-IP` — single value, the immediate client.
- `X-Forwarded-For` — comma-separated chain across multiple proxies.

```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

`$proxy_add_x_forwarded_for` appends `$remote_addr` to any incoming `X-Forwarded-For`. Only trust these from known proxies (`set_real_ip_from`):

```nginx
set_real_ip_from 10.0.0.0/8;
real_ip_header X-Forwarded-For;
real_ip_recursive on;
```

---

### Q33. Custom error pages?

```nginx
error_page 404 /404.html;
error_page 500 502 503 504 /50x.html;

location = /404.html { internal; root /var/www/errors; }
location = /50x.html { internal; root /var/www/errors; }
```

Use `internal;` to prevent direct access.

---

## Security

### Q34. Security headers?

```nginx
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self'" always;
```

The `always` flag ensures headers are added on error responses too.

---

### Q35. Hide Nginx version?

```nginx
server_tokens off;
# Errors and Server header no longer leak version.
# To remove the Server header entirely, use the headers-more module.
```

---

### Q36. Block by IP / country / user-agent?

```nginx
deny  10.10.10.0/24;
allow 10.0.0.0/8;
deny  all;

# Bad bots
if ($http_user_agent ~* (curl|wget|nikto|sqlmap)) { return 403; }
```

Avoid `if` where possible (it has caveats); use `map` for clarity:

```nginx
map $http_user_agent $bad_bot {
  default 0;
  ~*nikto 1;
  ~*sqlmap 1;
}
server {
  if ($bad_bot) { return 403; }
}
```

---

### Q37. Limit request size and methods?

```nginx
client_max_body_size 10M;

# Allow only standard methods
if ($request_method !~ ^(GET|HEAD|POST|PUT|DELETE|OPTIONS)$) {
  return 405;
}
```

---

## Performance Tuning

### Q38. Worker tuning?

```nginx
worker_processes auto;          # = number of CPU cores
worker_rlimit_nofile 65536;     # raise FD limit

events {
  worker_connections 8192;      # per worker
  use epoll;                    # Linux
  multi_accept on;
}
```

Max connections ≈ `worker_processes * worker_connections`. For reverse proxies, halve that for client+upstream pairs.

---

### Q39. sendfile, tcp_nopush, tcp_nodelay?

```nginx
sendfile on;       # zero-copy file -> socket
tcp_nopush on;     # send headers + start of file in one packet
tcp_nodelay on;    # disable Nagle for keep-alive responses
```

`tcp_nopush` works with `sendfile` to fill packets before sending; `tcp_nodelay` ensures small responses on keep-alive aren't delayed.

---

### Q40. Buffer sizing?

```nginx
client_body_buffer_size      16k;
client_header_buffer_size    1k;
large_client_header_buffers  4 8k;
client_max_body_size         10M;

proxy_buffering    on;
proxy_buffer_size  8k;
proxy_buffers      8 16k;
proxy_busy_buffers_size 32k;
```

Disable `proxy_buffering` for streaming/SSE so chunks pass straight through.

---

### Q41. Keepalive tuning?

```nginx
keepalive_timeout    65;
keepalive_requests   1000;        # per connection
```

For idle backends, ensure `upstream { keepalive 32; }` and `proxy_set_header Connection "";` (see Q28).

---

### Q42. How many concurrent connections can Nginx handle?

**Answer:**
Hundreds of thousands per box, given enough memory and FDs. Typical bottlenecks: ulimit, ephemeral ports, kernel network stack tuning, backend latency.

---

## Operations and Debugging

### Q43. Reload vs restart?

```bash
nginx -t                       # test config
nginx -s reload                # graceful reload (no dropped connections)
systemctl reload nginx
systemctl restart nginx        # full restart, brief downtime
```

Reload spawns new workers with new config; old workers finish in-flight requests then exit.

---

### Q44. Custom log format?

```nginx
log_format main '$remote_addr - $remote_user [$time_local] '
                '"$request" $status $body_bytes_sent '
                '"$http_referer" "$http_user_agent" '
                'rt=$request_time uct=$upstream_connect_time '
                'urt=$upstream_response_time uaddr=$upstream_addr '
                'uri="$request_uri"';

access_log /var/log/nginx/access.log main buffer=32k flush=5s;
```

JSON access log:
```nginx
log_format json escape=json '{'
  '"time":"$time_iso8601",'
  '"remote_addr":"$remote_addr",'
  '"method":"$request_method",'
  '"uri":"$request_uri",'
  '"status":$status,'
  '"bytes":$body_bytes_sent,'
  '"rt":$request_time,'
  '"urt":"$upstream_response_time",'
  '"ua":"$http_user_agent"'
  '}';
```

---

### Q45. Debugging?

```bash
nginx -T                        # dump full effective config
nginx -t                        # syntax check

tail -f /var/log/nginx/error.log
journalctl -u nginx -f

# Verbose error log for a specific server
error_log /var/log/nginx/example.error.log debug;
```

Common 502: upstream not reachable, wrong port, SELinux/AppArmor blocking, backend crashed, upstream slow + Nginx timeout.
Common 504: upstream too slow — check `proxy_read_timeout`.

---

### Q46. Blue-green deploy with Nginx?

```nginx
upstream blue  { server 10.0.0.10:3000; }
upstream green { server 10.0.0.11:3000; }

map $http_x_color $upstream_pool {
  default blue;
  green   green;
}

server {
  listen 443 ssl;
  location / {
    proxy_pass http://$upstream_pool;
  }
}
```

To switch, change `default` and `nginx -s reload`. Or use a single `upstream` and swap `server` entries via templating + reload.

---

### Q47. Canary deploy?

```nginx
split_clients "${remote_addr}${request_uri}" $variant {
  10%     canary;
  *       stable;
}

upstream stable { server 10.0.0.10:3000; }
upstream canary { server 10.0.0.11:3000; }

server {
  location / {
    proxy_pass http://$variant;
  }
}
```

---

### Q48. Nginx as API gateway?

**Answer:**
At a basic level, Nginx can do:
- Routing by path/host/header.
- Auth via subrequests (`auth_request`).
- Rate limiting per consumer (using API key as the limit_req key).
- Header rewriting and CORS.
- Caching responses.
- TLS termination and mTLS.

For richer features (token validation, request transformation, observability), Kong or other gateways built on Nginx provide a fuller feature set.

```nginx
location = /_auth {
  internal;
  proxy_pass http://auth-svc/verify;
  proxy_pass_request_body off;
  proxy_set_header Content-Length "";
  proxy_set_header X-Original-URI $request_uri;
}

location /api/ {
  auth_request /_auth;
  proxy_pass http://api-backend/;
}
```

---

### Q49. CORS handling?

```nginx
location /api/ {
  if ($request_method = OPTIONS) {
    add_header Access-Control-Allow-Origin  $http_origin always;
    add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header Access-Control-Allow-Headers 'Authorization, Content-Type' always;
    add_header Access-Control-Allow-Credentials true always;
    add_header Access-Control-Max-Age 86400 always;
    return 204;
  }
  add_header Access-Control-Allow-Origin $http_origin always;
  add_header Access-Control-Allow-Credentials true always;
  proxy_pass http://backend;
}
```

For multiple origins, validate against an allowlist via `map`.

---

### Q50. Nginx Plus features (vs OSS)?

**Answer:**
Commercial features:
- Active health checks.
- Dynamic config (DNS-resolved upstreams, on-the-fly updates).
- Live activity monitoring dashboard.
- Cookie-based sticky sessions.
- JWT validation.
- Cache PURGE API.
- Session persistence beyond `ip_hash`.

Open-source Nginx covers most needs; many shops use OpenResty, Lua modules, or custom builds for advanced features.

---

### Q51. Common pitfalls?

1. Forgetting `proxy_http_version 1.1` and `Connection ""` — kills upstream keepalive.
2. Wrong `proxy_pass` URI semantics (trailing slash).
3. `if` inside `location` (use sparingly — many directives don't behave as expected).
4. Missing `try_files` for SPA routing.
5. Not setting `client_max_body_size` (default 1M can break uploads).
6. Trusting `X-Forwarded-For` from anywhere (set `set_real_ip_from`).
7. Reusing TLS sessions improperly across server blocks.
8. Forgetting `always` on `add_header` — error responses lack the header.
9. Compressing already-compressed assets.
10. Logging at debug level in production (huge files, slow).
11. No log rotation (logrotate config).
12. Not increasing `worker_rlimit_nofile` for high-concurrency setups.

---

### Q52. Production-ready snippet?

```nginx
server {
  listen 443 ssl http2;
  server_name app.example.com;

  ssl_certificate     /etc/ssl/app.fullchain.pem;
  ssl_certificate_key /etc/ssl/app.privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_session_cache shared:SSL:10m;
  ssl_stapling on;
  ssl_stapling_verify on;

  add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  server_tokens off;

  client_max_body_size 20M;
  gzip on;
  gzip_types text/plain text/css application/json application/javascript;

  set_real_ip_from 10.0.0.0/8;
  real_ip_header X-Forwarded-For;
  real_ip_recursive on;

  limit_req_zone $binary_remote_addr zone=api:10m rate=20r/s;

  location /healthz {
    access_log off;
    return 200 "ok\n";
  }

  location /api/ {
    limit_req zone=api burst=40 nodelay;
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Connection        "";
    proxy_connect_timeout 5s;
    proxy_read_timeout    30s;
    proxy_pass http://api_upstream;
  }

  location / {
    root /var/www/app;
    try_files $uri /index.html;
    expires 1h;
  }
}

upstream api_upstream {
  least_conn;
  keepalive 64;
  server 10.0.1.10:3000 max_fails=3 fail_timeout=10s;
  server 10.0.1.11:3000 max_fails=3 fail_timeout=10s;
}
```
