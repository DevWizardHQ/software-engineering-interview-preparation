# Nginx Interview Questions

A practical, teaching-style Q&A guide for Nginx. Each question gives a plain-language explanation followed by a working configuration block you can drop into a real server.

---

## Table of Contents

1. Fundamentals
2. Configuration Structure
3. Reverse Proxy
4. Load Balancing
5. SSL/TLS and HTTP/2 / HTTP/3
6. Caching
7. Rate Limiting and Compression
8. Static Files, FastCGI, WebSockets
9. Locations, Rewrites, and Headers
10. Security
11. Performance Tuning
12. Operations and Debugging

---

## 1. Fundamentals

## Q1. What is Nginx?

**Answer:**

Nginx is a high-performance HTTP server, reverse proxy, load balancer, and TLS terminator. It is widely used in front of application servers (Node, PHP-FPM, Python, Java) to serve static files, terminate HTTPS, route requests, cache responses, and limit abusive traffic.

```bash
nginx -v
# nginx version: nginx/1.27.0

sudo systemctl status nginx
```

## Q2. What is the difference between Nginx and Apache?

**Answer:**

| Aspect          | Nginx                          | Apache (httpd)                 |
| --------------- | ------------------------------ | ------------------------------ |
| Architecture    | Event-driven, async            | Process / thread per connection |
| Static files    | Very fast                      | Fast                           |
| Concurrency     | Tens of thousands easily       | Heavier per connection         |
| Configuration   | One nginx.conf + includes      | `.htaccess` + httpd.conf       |
| Modules         | Compiled in (or dynamic since 1.9) | Loaded at runtime          |

For high-traffic, static-file-heavy, or reverse-proxy workloads, Nginx is the common choice.

## Q3. What is Nginx's architecture?

**Answer:**

Nginx uses an event-driven, asynchronous, non-blocking model. A single **master process** reads the config and manages **worker processes**. Each worker handles thousands of connections in a single OS thread using `epoll` (Linux) or `kqueue` (BSD).

Because workers do not spawn a thread per connection, Nginx scales to many concurrent connections with low memory.

```bash
ps -ef | grep nginx
# root      1234   1   0 May04 ?  00:00:00 nginx: master process
# nginx     1235 1234  0 May04 ?  00:00:00 nginx: worker process
# nginx     1236 1234  0 May04 ?  00:00:00 nginx: worker process
```

## Q4. Why is Nginx so fast?

**Answer:**

1. **Event loop**: a worker uses one thread to multiplex thousands of sockets via `epoll`.
2. **Zero-copy file delivery**: `sendfile()` ships file bytes from disk to network without copying through user space.
3. **No per-request processes/threads**: avoids context-switch overhead.
4. **Static-file path is highly optimized.**
5. **Configurable buffering and caching** to absorb slow clients without blocking workers.

---

## 2. Configuration Structure

## Q5. What are the top-level config blocks?

**Answer:**

```nginx
# /etc/nginx/nginx.conf

user www-data;
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile      on;
    tcp_nopush    on;
    keepalive_timeout 65;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

Key directives sit in three contexts: top level (main), `events`, and `http`. Inside `http` you have `server` (virtual hosts) and inside `server` you have `location` blocks.

## Q6. Show me a server block (virtual host) example.

**Answer:**

```nginx
server {
    listen 80;
    server_name example.com www.example.com;

    root /var/www/example;
    index index.html;

    access_log /var/log/nginx/example.access.log;
    error_log  /var/log/nginx/example.error.log warn;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

`try_files` checks for a literal file, then a directory index, then returns 404.

## Q7. How does Nginx select which server block to use?

**Answer:**

Nginx matches a request to a server block by:

1. **`listen` directive** — does the request's IP and port match?
2. **`server_name` directive** — does the request's `Host` header match?

If multiple server blocks listen on the same port, Nginx picks one in this order: exact name match, leading wildcard (`*.example.com`), trailing wildcard (`mail.*`), regex, then the **default_server**.

```nginx
server {
    listen 80 default_server;
    server_name _;
    return 444;        # close connection if no Host matches
}
```

---

## 3. Reverse Proxy

## Q8. What are the basics of a reverse proxy?

**Answer:**

A reverse proxy sits between clients and your application. The client connects to Nginx; Nginx forwards the request to your backend (Node, PHP-FPM, Python, etc.) and returns the response. The client never talks to the backend directly.

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
    }
}
```

## Q9. Why use Nginx as a reverse proxy?

**Answer:**

1. Terminate TLS once, in one place.
2. Route different paths or subdomains to different backends.
3. Buffer slow clients so they do not tie up backend workers.
4. Serve static files directly without bothering the app.
5. Apply rate limits, IP allowlists, and security headers centrally.
6. Gzip / Brotli compression.
7. Cache backend responses.
8. Health checks and load balancing across multiple app instances.

## Q10. What is the difference between `proxy_pass` with and without a trailing slash?

**Answer:**

This trips up many people. The trailing slash on `proxy_pass` changes whether Nginx rewrites the URI.

```nginx
# Without trailing slash — passes the full URI
location /api/ {
    proxy_pass http://backend;
}
# /api/users -> http://backend/api/users

# With trailing slash — strips the matched location prefix
location /api/ {
    proxy_pass http://backend/;
}
# /api/users -> http://backend/users
```

## Q11. Forward proxy vs reverse proxy?

**Answer:**

| Type           | Whom it serves           | Example                       |
| -------------- | ------------------------ | ----------------------------- |
| Forward proxy  | The clients              | A corporate web proxy         |
| Reverse proxy  | The servers              | Nginx in front of your app    |

A forward proxy hides the client from the internet. A reverse proxy hides the server (backend) from the client.

---

## 4. Load Balancing

## Q12. What load balancing methods does Nginx offer?

**Answer:**

```nginx
upstream backend {
    # round-robin (default)
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

upstream backend2 {
    least_conn;                          # send to least busy
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

upstream backend3 {
    ip_hash;                             # sticky by client IP
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}

upstream backend4 {
    hash $request_uri consistent;        # consistent hash by URI
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}
```

## Q13. How do health checks work in open-source Nginx?

**Answer:**

Open-source Nginx uses passive health checks: it marks a backend "unavailable" after `max_fails` failed connections within `fail_timeout`, and avoids it for `fail_timeout` seconds.

```nginx
upstream backend {
    server 10.0.0.1:3000 max_fails=3 fail_timeout=30s;
    server 10.0.0.2:3000 max_fails=3 fail_timeout=30s;
}
```

Active checks (probes the backend even when no traffic is flowing) require Nginx Plus or third-party modules.

## Q14. How do you configure upstream failover?

**Answer:**

`backup` marks a server as a failover that is only used when all primaries are down.

```nginx
upstream backend {
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
    server 10.0.0.3:3000 backup;
}
```

## Q15. How do you configure sticky sessions?

**Answer:**

`ip_hash` ties a client (by source IP) to one backend. Same IP -> same server.

```nginx
upstream backend {
    ip_hash;
    server 10.0.0.1:3000;
    server 10.0.0.2:3000;
}
```

For real session affinity by cookie (`sticky cookie`), you need Nginx Plus.

---

## 5. SSL/TLS and HTTP/2 / HTTP/3

## Q16. Show me a basic TLS configuration.

**Answer:**

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:3000;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}
```

## Q17. What is OCSP stapling?

**Answer:**

When a browser receives a TLS certificate, it normally checks revocation status by contacting the certificate's CA (OCSP). This is slow and leaks browsing data.

OCSP stapling has Nginx pre-fetch the OCSP response and "staple" it to the TLS handshake. The browser does not need to make an extra round-trip.

```nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
resolver 1.1.1.1 8.8.8.8 valid=300s;
resolver_timeout 5s;
```

## Q18. HTTP/2 vs HTTP/3?

**Answer:**

| Version | Transport | Key features                                                |
| ------- | --------- | ----------------------------------------------------------- |
| HTTP/1.1| TCP       | One request at a time per connection (with pipelining gone) |
| HTTP/2  | TCP + TLS | Multiplexed streams, header compression                     |
| HTTP/3  | UDP (QUIC)| No head-of-line blocking, faster handshake                  |

Enable HTTP/2:

```nginx
listen 443 ssl http2;
```

Enable HTTP/3 (Nginx 1.25+):

```nginx
listen 443 ssl http2;
listen 443 quic reuseport;
http3 on;
add_header Alt-Svc 'h3=":443"; ma=86400';
```

## Q19. Why use TLS 1.3?

**Answer:**

TLS 1.3 has fewer round-trips during the handshake (1-RTT, with 0-RTT for resumed sessions), removes outdated cipher suites, and provides forward secrecy by default. Faster and more secure than 1.2.

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

---

## 6. Caching

## Q20. Show me a `proxy_cache` configuration.

**Answer:**

```nginx
http {
    proxy_cache_path /var/cache/nginx
        levels=1:2
        keys_zone=app_cache:10m
        max_size=1g
        inactive=60m
        use_temp_path=off;

    server {
        location / {
            proxy_pass http://backend;
            proxy_cache app_cache;
            proxy_cache_valid 200 302 10m;
            proxy_cache_valid 404 1m;
            proxy_cache_use_stale error timeout updating http_500 http_502 http_503;
            proxy_cache_lock on;

            add_header X-Cache-Status $upstream_cache_status;
        }
    }
}
```

`X-Cache-Status` shows MISS, HIT, EXPIRED, BYPASS, etc. — useful for debugging.

## Q21. What are common cache invalidation strategies?

**Answer:**

1. **Time-based**: short TTL via `proxy_cache_valid`.
2. **`Cache-Control` from origin**: app sets `Cache-Control: max-age=...` and Nginx honors it.
3. **Cache key includes a version/hash**: deploy a new build under a new URL — old URLs simply age out.
4. **PURGE module**: open-source `ngx_cache_purge` can delete specific keys.

```nginx
proxy_cache_bypass $http_pragma $arg_nocache;     # skip cache when client says so
proxy_no_cache $cookie_session;                   # do not cache logged-in users
```

## Q22. What is `open_file_cache`?

**Answer:**

When serving static files, Nginx looks up file metadata (size, mtime, existence) on every request. `open_file_cache` keeps that metadata in memory.

```nginx
open_file_cache          max=10000 inactive=60s;
open_file_cache_valid    60s;
open_file_cache_min_uses 2;
open_file_cache_errors   on;
```

A measurable performance win for static-heavy sites.

---

## 7. Rate Limiting and Compression

## Q23. How do you configure rate limiting?

**Answer:**

Define a limit zone in `http`, then use it in a `location`.

```nginx
http {
    # 10 requests per second per IP, with bursts up to 20
    limit_req_zone $binary_remote_addr zone=api_rl:10m rate=10r/s;

    # 20 simultaneous connections per IP
    limit_conn_zone $binary_remote_addr zone=conn_zone:10m;

    server {
        location /api/ {
            limit_req  zone=api_rl burst=20 nodelay;
            limit_conn conn_zone 20;
            proxy_pass http://backend;
        }
    }
}
```

`burst=20 nodelay` allows quick bursts without delay. Without `nodelay`, requests above the rate are queued and served later.

## Q24. How do you configure compression?

**Answer:**

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_proxied any;
gzip_comp_level 5;
gzip_types
    text/plain
    text/css
    text/javascript
    application/javascript
    application/json
    application/xml
    image/svg+xml;
```

For Brotli (smaller than gzip on text), build Nginx with the Brotli module:

```nginx
brotli on;
brotli_comp_level 5;
brotli_types text/plain text/css application/javascript application/json image/svg+xml;
```

---

## 8. Static Files, FastCGI, WebSockets

## Q25. Show me a static-files configuration.

**Answer:**

```nginx
server {
    listen 80;
    server_name static.example.com;
    root /var/www/static;

    location / {
        try_files $uri $uri/ =404;
    }

    # Long cache for fingerprinted assets
    location ~* \.(?:css|js|woff2|png|jpg|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
```

## Q26. How do you serve PHP via FastCGI (PHP-FPM)?

**Answer:**

```nginx
server {
    listen 80;
    server_name example.com;
    root /var/www/example/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_index index.php;
    }

    location ~ /\.(ht|git) {
        deny all;
    }
}
```

## Q27. How do you proxy WebSockets?

**Answer:**

WebSockets need HTTP/1.1 with the `Upgrade` header preserved.

```nginx
location /ws/ {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade    $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host       $host;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}
```

The long timeouts allow long-lived connections.

## Q28. How do you keep connections alive to the upstream?

**Answer:**

By default Nginx opens a new TCP connection to the upstream for each request. With `keepalive`, it pools connections, which reduces latency and load.

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

---

## 9. Locations, Rewrites, and Headers

## Q29. What is the location matching priority?

**Answer:**

When multiple `location` blocks match, Nginx picks one with this priority:

1. **`= /exact/path`** — exact match (highest priority)
2. **`^~ /prefix/`** — preferred prefix match (skips regex)
3. **`~ /regex/` (case-sensitive)** or **`~* /regex/` (case-insensitive)** — first matching regex wins
4. **`/prefix/`** — longest matching prefix (lowest priority)

```nginx
location = /favicon.ico { log_not_found off; access_log off; }
location ^~ /static/    { root /var/www; }
location ~* \.php$      { fastcgi_pass ...; }
location /              { proxy_pass http://backend; }
```

## Q30. How do rewrites work?

**Answer:**

Rewrites change the URL Nginx is processing. Use them sparingly — `try_files` and `return` are usually clearer.

```nginx
# Permanent redirect (301)
rewrite ^/old/(.*)$ /new/$1 permanent;

# Internal rewrite (the URL doesn't change in the browser)
rewrite ^/api/v1/(.*)$ /v1/$1 last;

# Redirect via return (preferred for static cases)
location /old { return 301 /new; }
location /off { return 410; }            # gone

# Rewrite flags
# last       re-evaluate locations
# break      stop in current location
# redirect   302
# permanent  301
```

## Q31. What are some common Nginx variables?

**Answer:**

| Variable               | Meaning                                |
| ---------------------- | -------------------------------------- |
| `$host`                | Host header (or server_name fallback)  |
| `$remote_addr`         | Client IP                              |
| `$request_uri`         | Full original URI with query string    |
| `$uri`                 | Current (possibly rewritten) URI       |
| `$args`                | Query string                           |
| `$scheme`              | http or https                          |
| `$request_method`      | GET, POST, etc.                        |
| `$http_user_agent`     | User-Agent header                      |
| `$http_x_forwarded_for`| X-Forwarded-For header                 |
| `$server_name`         | The server_name that matched           |
| `$proxy_add_x_forwarded_for` | Existing XFF + client IP         |

## Q32. What is the difference between X-Forwarded-For and X-Real-IP?

**Answer:**

- `X-Real-IP` is a single value: the immediate client.
- `X-Forwarded-For` is a comma-separated chain: original client, then each proxy. The first IP is the original client.

```nginx
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

The backend should trust these headers only when they come from a known proxy.

## Q33. How do you serve custom error pages?

**Answer:**

```nginx
error_page 404 /404.html;
error_page 500 502 503 504 /50x.html;

location = /404.html { root /var/www/errors; internal; }
location = /50x.html { root /var/www/errors; internal; }
```

`internal` means the page can only be reached as a result of `error_page`, not by a direct request.

---

## 10. Security

## Q34. What security headers should I set?

**Answer:**

```nginx
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Content-Type-Options    "nosniff" always;
add_header X-Frame-Options           "DENY" always;
add_header Referrer-Policy           "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy   "default-src 'self'" always;
add_header Permissions-Policy        "geolocation=(), microphone=()" always;
```

`always` ensures the header is added even on error responses.

## Q35. How do you hide the Nginx version?

**Answer:**

```nginx
http {
    server_tokens off;
}
```

Errors and the Server header no longer leak the version. To remove the Server header entirely you need the `headers-more` module.

```nginx
more_set_headers "Server: ";
```

## Q36. How do you block by IP, country, or user-agent?

**Answer:**

```nginx
# By IP
location / {
    deny  192.0.2.0/24;
    allow all;
    proxy_pass http://backend;
}

# Bad bots
if ($http_user_agent ~* (badbot|scraper)) {
    return 403;
}

# By country (requires GeoIP2 module)
geoip2 /usr/share/GeoIP/GeoLite2-Country.mmdb {
    $geoip2_country_code default=XX source=$remote_addr country iso_code;
}
map $geoip2_country_code $blocked_country {
    default 0;
    CN      1;
    RU      1;
}
server {
    if ($blocked_country) { return 403; }
}
```

## Q37. How do you limit request size and HTTP methods?

**Answer:**

```nginx
client_max_body_size 10m;     # reject uploads larger than 10 MB

# Allow only standard methods
if ($request_method !~ ^(GET|HEAD|POST|PUT|DELETE|PATCH|OPTIONS)$) {
    return 405;
}
```

---

## 11. Performance Tuning

## Q38. How do you tune workers?

**Answer:**

```nginx
worker_processes auto;            # one per CPU core (auto detects)
worker_rlimit_nofile 65535;       # raise the open file limit
events {
    worker_connections 4096;      # connections each worker can handle
    multi_accept       on;
    use                epoll;     # Linux
}
```

Total max connections ≈ `worker_processes` × `worker_connections`.

## Q39. What do `sendfile`, `tcp_nopush`, `tcp_nodelay` do?

**Answer:**

| Directive    | Purpose                                                      |
| ------------ | ------------------------------------------------------------ |
| `sendfile`   | Use the kernel `sendfile()` syscall (zero-copy disk to net)  |
| `tcp_nopush` | Combined with sendfile, sends headers and beginning of file in one packet |
| `tcp_nodelay`| Disable Nagle's algorithm so small packets go out immediately |

```nginx
sendfile on;
tcp_nopush on;
tcp_nodelay on;
```

## Q40. How do you size buffers?

**Answer:**

If a request body or response header is larger than the buffer, Nginx writes to a temp file (slow) or fails (`upstream sent too big header`).

```nginx
client_body_buffer_size       16k;
client_header_buffer_size      1k;
large_client_header_buffers    4 8k;

proxy_buffer_size             16k;
proxy_buffers                  8 16k;
proxy_busy_buffers_size       32k;
```

Watch the error log for "too big" warnings and tune accordingly.

## Q41. How do you tune keepalive?

**Answer:**

```nginx
keepalive_timeout    65s;        # client keepalive
keepalive_requests   1000;       # requests per keepalive connection

upstream backend {
    server 10.0.0.1:3000;
    keepalive          32;       # idle upstream connections in pool
    keepalive_requests 1000;
    keepalive_timeout  60s;
}
```

## Q42. How many concurrent connections can Nginx handle?

**Answer:**

Practically, tens of thousands per server, limited by:

1. `worker_processes × worker_connections`
2. Open file descriptor limit (`worker_rlimit_nofile` and the OS `ulimit`)
3. Available RAM (each connection uses some buffers)
4. Source-port range and TIME_WAIT sockets if used as a proxy

A single modest VM commonly handles 50k+ idle keepalive connections.

---

## 12. Operations and Debugging

## Q43. What is the difference between reload and restart?

**Answer:**

- **Reload** (`nginx -s reload` or `systemctl reload nginx`) re-reads the config and gracefully replaces workers without dropping connections. Use for almost all changes.
- **Restart** (`systemctl restart nginx`) stops and re-starts the master. Drops in-flight connections. Needed if you change `user`, listen sockets bound at startup, or upgrade Nginx.

Always test before reloading:

```bash
sudo nginx -t                # validate config
sudo systemctl reload nginx
```

## Q44. How do you set a custom log format?

**Answer:**

```nginx
log_format main '$remote_addr - $remote_user [$time_local] '
                '"$request" $status $body_bytes_sent '
                '"$http_referer" "$http_user_agent" '
                '$request_time $upstream_response_time';

access_log /var/log/nginx/access.log main;
```

`$request_time` is the total time Nginx spent on the request; `$upstream_response_time` is just the backend.

## Q45. How do you debug Nginx?

**Answer:**

```bash
sudo nginx -t                        # syntax check
sudo nginx -T                        # dump full effective config
sudo tail -f /var/log/nginx/error.log
sudo journalctl -u nginx -f
```

Verbose error log for a specific server while diagnosing:

```nginx
error_log /var/log/nginx/example.debug.log debug;
```

Test that requests reach the right backend:

```bash
curl -I -H "Host: example.com" http://127.0.0.1
```

## Q46. How do you do a blue-green deploy with Nginx?

**Answer:**

Run two backend pools and switch traffic by toggling which one Nginx points at.

```nginx
upstream blue  { server 10.0.0.1:3000; }
upstream green { server 10.0.0.2:3000; }

server {
    location / {
        proxy_pass http://blue;          # change to green and reload to switch
    }
}
```

Reload (not restart) to apply with no dropped connections.

## Q47. How do you do a canary deploy?

**Answer:**

Send a small percentage of traffic to a new version, gradually increasing if it stays healthy.

```nginx
split_clients "${remote_addr}${request_uri}" $variant {
    10%     "canary";
    *       "stable";
}

upstream stable { server 10.0.0.1:3000; }
upstream canary { server 10.0.0.2:3000; }

server {
    location / {
        proxy_pass http://$variant;
    }
}
```

`split_clients` deterministically buckets clients by the hash of the given key.

## Q48. Can Nginx be used as an API gateway?

**Answer:**

Yes for basic gateway needs: routing, TLS termination, rate limiting, JWT validation (with `auth_request` or Lua), header rewriting. For advanced features (richer auth, request transforms, plugin ecosystems), consider Kong, Tyk, or APISIX (many are built on Nginx anyway).

```nginx
location /auth {
    internal;
    proxy_pass http://auth-service/validate;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URI $request_uri;
}

location /api/ {
    auth_request /auth;
    proxy_pass http://api-backend;
}
```

## Q49. How do you handle CORS?

**Answer:**

```nginx
location /api/ {
    if ($request_method = OPTIONS) {
        add_header Access-Control-Allow-Origin  "https://app.example.com";
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Authorization, Content-Type";
        add_header Access-Control-Max-Age       86400;
        return 204;
    }

    add_header Access-Control-Allow-Origin "https://app.example.com" always;
    proxy_pass http://backend;
}
```

The `OPTIONS` block handles CORS preflight; the second `add_header` handles real responses.

## Q50. What features does Nginx Plus add over open-source Nginx?

**Answer:**

- Active health checks
- Sticky-cookie session persistence
- Live activity dashboard and metrics API
- Dynamic upstream reconfiguration via API (no reload)
- JWT validation built-in
- Advanced caching (purge API)

For most workloads, open-source Nginx is enough.

## Q51. What are common Nginx pitfalls?

**Answer:**

1. Forgetting `proxy_set_header Host $host` — backends see "localhost" or wrong vhost.
2. The `proxy_pass` trailing-slash trap.
3. Using `if` inside locations for non-rewriting purposes (often broken; use `map`).
4. Skipping `nginx -t` and reloading bad config.
5. No HSTS / weak TLS settings.
6. `client_max_body_size` default of 1 MB rejecting uploads.
7. Logs filling disk because no `logrotate`.

## Q52. Show me a production-ready snippet.

**Answer:**

```nginx
worker_processes auto;
worker_rlimit_nofile 65535;

events { worker_connections 4096; multi_accept on; }

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile on; tcp_nopush on; tcp_nodelay on;
    keepalive_timeout 65; keepalive_requests 1000;
    server_tokens off;

    gzip on; gzip_vary on; gzip_min_length 1024;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" "$http_user_agent" '
                    '$request_time $upstream_response_time';
    access_log /var/log/nginx/access.log main;
    error_log  /var/log/nginx/error.log warn;

    limit_req_zone $binary_remote_addr zone=api_rl:10m rate=10r/s;

    upstream backend {
        server 10.0.0.1:3000;
        server 10.0.0.2:3000;
        keepalive 32;
    }

    server {
        listen 80;
        server_name example.com;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name example.com;

        ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_session_cache   shared:SSL:10m;

        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;

        client_max_body_size 10m;

        location /api/ {
            limit_req zone=api_rl burst=20 nodelay;
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location / {
            root /var/www/example;
            try_files $uri $uri/ /index.html;
        }
    }
}
```
