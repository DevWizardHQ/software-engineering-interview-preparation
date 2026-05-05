# Laravel & PHP Optimization — Senior Engineer Guide

**Purpose:** Master end-to-end PHP and Laravel performance optimization for senior interviews. Covers PHP runtime, FPM tuning, opcache, JIT, Laravel-specific caches, Eloquent optimization, queues, Octane, profiling, and real production patterns.

---

## Table of Contents

1. [PHP Runtime Optimization](#php-runtime-optimization)
2. [Opcache and JIT Deep Dive](#opcache-and-jit-deep-dive)
3. [PHP-FPM Tuning](#php-fpm-tuning)
4. [Autoloading and Composer](#autoloading-and-composer)
5. [Laravel Built-in Caches](#laravel-built-in-caches)
6. [Eloquent and Query Optimization](#eloquent-and-query-optimization)
7. [N+1 Detection and Prevention](#n1-detection-and-prevention)
8. [Caching with Redis](#caching-with-redis)
9. [Queues and Background Jobs](#queues-and-background-jobs)
10. [Laravel Octane (Swoole / RoadRunner / FrankenPHP)](#laravel-octane)
11. [HTTP Caching and Assets](#http-caching-and-assets)
12. [Service Providers and Boot Time](#service-providers-and-boot-time)
13. [Profiling Tools](#profiling-tools)
14. [Common Production Patterns](#common-production-patterns)

---

## PHP Runtime Optimization

### Q1. What does the PHP request lifecycle look like (with FPM)?

1. Nginx/Apache receives HTTP request
2. Forwards to PHP-FPM via FastCGI socket
3. FPM picks an idle worker from its pool
4. Worker bootstraps PHP (or uses opcache)
5. Worker executes the script (Laravel: index.php → kernel → router → controller → response)
6. Worker returns response, resets state, returns to pool
7. Nginx sends response to client

**Where time is spent in a typical Laravel request:**
- Bootstrap: 5–30 ms (without opcache: 100+ ms)
- Routing + middleware: 1–5 ms
- Controller logic + DB: usually the bulk
- Response render + serialize: 1–10 ms

If your "Hello World" Laravel response is 50+ ms, your runtime is misconfigured.

---

### Q2. PHP versions and performance.

| Version | Notable | Real-world gain vs prior |
|---------|---------|--------------------------|
| PHP 7.0 | New engine (PHPNG) | ~2x over 5.6 |
| PHP 7.4 | Preloading | ~10% over 7.3 |
| PHP 8.0 | JIT, named args | 5–15% CPU-bound |
| PHP 8.1 | Enums, fibers, never type | 5–8% |
| PHP 8.2 | Readonly classes | 2–5% |
| PHP 8.3 | typed class constants | 3–7% |

Always run a recent supported version. PHP 8.3+ recommended in 2025.

---

### Q3. Realpath cache — what is it and why does it matter?

Every `require` and file operation does path resolution (symlinks, ../). Realpath cache stores the resolved paths.

```ini
realpath_cache_size = 4096K
realpath_cache_ttl = 600
```

Default is 16K — way too small for Laravel which touches thousands of files. Bump to at least 4 MB. For a large app, 16 MB.

Effect: a Laravel cold request can drop from 200 ms to 60 ms with proper realpath cache.

---

## Opcache and JIT Deep Dive

### Q4. What is opcache exactly?

PHP normally parses, compiles to bytecode (opcodes), and executes — every request. Opcache stores the compiled opcodes in shared memory so subsequent requests skip parsing/compilation.

Without opcache: ~80% of bootstrap time is wasted on compilation.

---

### Q5. Production opcache configuration.

```ini
; /etc/php/8.3/fpm/conf.d/10-opcache.ini

opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=512
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=20000

; Production: don't check files for changes
opcache.validate_timestamps=0
opcache.revalidate_freq=0

; Saves CPU
opcache.save_comments=1   ; needed for annotations / attributes
opcache.fast_shutdown=1

; Preloading (PHP 7.4+)
opcache.preload=/var/www/preload.php
opcache.preload_user=www-data
```

**Critical:** in production set `validate_timestamps=0`. PHP will not detect changed files — you must `opcache_reset()` or restart FPM on deploy.

---

### Q6. Opcache memory sizing.

Run on staging:
```php
print_r(opcache_get_status(false));
```

Look at:
- `memory_usage.used_memory`
- `memory_usage.wasted_memory` (high = restart soon)
- `interned_strings_usage.used_memory`
- `opcache_statistics.num_cached_scripts`
- `opcache_statistics.opcache_hit_rate` — should be > 99%

Rule of thumb: 256 MB for medium apps, 512 MB+ for large monoliths.

---

### Q7. JIT in PHP 8 — does it help web apps?

JIT helps **CPU-bound** code (computation, parsers, image processing). For typical Laravel (DB-bound, I/O-bound), JIT gives 1–3% improvement, sometimes nothing.

```ini
opcache.jit_buffer_size=256M
opcache.jit=tracing      ; or 1255 for "tracing"
```

JIT modes (4-digit number = CRTO):
- `1255` (tracing): for most workloads
- `1235` (function): more conservative
- `0` or `disable`: off

Test before/after with realistic load. JIT is not free — it consumes shared memory.

---

### Q8. Preloading — when is it worth it?

Preloading loads classes once at FPM start, available read-only to all workers.

```php
// preload.php
$files = glob(__DIR__.'/vendor/laravel/framework/src/**/*.php', GLOB_BRACE);
foreach ($files as $file) {
    opcache_compile_file($file);
}
```

Typical gain: 5–10% on bootstrap. Less impactful with Octane (which already keeps the app warm).

Caveats:
- Preloaded classes can't be redefined → all deploys require FPM restart
- Some Laravel binders break preloading; whitelist carefully

---

## PHP-FPM Tuning

### Q9. PHP-FPM process manager modes.

```ini
pm = dynamic            ; or static, ondemand
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 1000  ; restart workers periodically
```

| Mode | Behavior | Use when |
|------|----------|----------|
| static | Fixed worker count | Predictable load, max throughput |
| dynamic | Scales between min/max spare | Default, variable load |
| ondemand | Spawn on request, kill when idle | Low-traffic / resource-constrained |

For high-traffic production, **static** with sized workers is best — no fork latency.

---

### Q10. Sizing pm.max_children.

```
pm.max_children = (Total RAM - other services) / Avg Memory Per Worker
```

Measure avg worker memory (50–200 MB typical for Laravel):
```bash
ps -ylC php-fpm8.3 --sort:rss
```

Example: 16 GB server, 1 GB OS+Nginx+Redis, 1 GB headroom → 14 GB / 100 MB = 140 workers.

But CPU also matters: each worker uses CPU during request. If your app is CPU-bound, more workers thrash. Generally keep workers ≤ `cpu_cores × 4`.

---

### Q11. pm.max_requests — why and how much?

```ini
pm.max_requests = 1000
```

After N requests, the worker is killed and respawned. Helps with:
- Memory leaks (over time PHP holds references)
- Stale opcache associations
- Preventing one bad request's state from persisting

Don't set too low (too much fork overhead) or too high (memory growth). 500–2000 is typical.

---

### Q12. Slowlog — finding slow requests.

```ini
slowlog = /var/log/php-fpm/slow.log
request_slowlog_timeout = 5s
request_terminate_timeout = 60s
```

Captures backtrace of any request running > 5 seconds. Invaluable for tracking down hung external API calls or slow queries.

---

### Q13. Status page — production monitoring.

```ini
pm.status_path = /fpm-status
ping.path = /ping
```

Returns:
```
pool:                 www
process manager:      static
total processes:      50
active processes:     12
idle processes:       38
listen queue:         0
max listen queue:     5
```

Alert if:
- `listen queue > 0` consistently → workers exhausted
- `idle processes = 0` → scale up

Scrape via Prometheus exporter (`hipages/php-fpm_exporter`).

---

## Autoloading and Composer

### Q14. Composer autoload — production optimization.

```bash
composer install --no-dev --optimize-autoloader --classmap-authoritative
```

- `--optimize-autoloader` (`-o`): builds classmap from PSR-4 namespaces
- `--classmap-authoritative` (`-a`): all classes must be in classmap; never falls back to filesystem scan
- `--no-dev`: skip dev dependencies

Effect: reduce `composer/autoload_real.php` resolution from ~5 ms to ~0.5 ms per cold request.

---

### Q15. `php artisan optimize` — what does it do?

In Laravel 11+:
```
php artisan optimize
```
runs:
- `route:cache`
- `view:cache`
- `event:cache`
- `config:cache`

Reverse with `php artisan optimize:clear`.

This is essential in production. Each cache shaves 5–30 ms off bootstrap.

---

### Q16. Pitfalls of config caching.

After `php artisan config:cache`:
- `env()` calls outside config files return `null`
- Closure-based config values fail to cache (must be plain arrays)

**Rule:** use `env()` only inside `config/*.php` files. Everywhere else, use `config('services.foo')`.

---

## Laravel Built-in Caches

### Q17. Route caching — what changes?

```bash
php artisan route:cache
```

- All routes loaded at once into a compiled file
- Closure routes break — must be controller@method style
- Boot becomes ~5–20 ms faster on apps with 500+ routes

Always re-run on deploy.

---

### Q18. View caching.

Blade templates compile to PHP on first hit. `view:cache` pre-compiles all of them at deploy time.

```bash
php artisan view:cache
```

Saves the per-page first-hit compile time (~5–50 ms depending on template complexity). Necessary under Octane where state persists.

---

### Q19. Event caching.

Laravel discovers event listeners by reflection. `event:cache` writes them to a manifest:
```bash
php artisan event:cache
```

Saves ~10 ms on apps with many listeners.

---

### Q20. Production deploy script — recommended order.

```bash
php artisan down
composer install --no-dev --optimize-autoloader --classmap-authoritative
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
php artisan queue:restart    # tell horizon/queue workers to reload
sudo systemctl reload php8.3-fpm   # opcache reset
php artisan up
```

For zero-downtime: deploy to a new release dir, atomically swap symlink, then reload FPM.

---

## Eloquent and Query Optimization

### Q21. Eager loading — `with()`.

Without:
```php
$users = User::all();
foreach ($users as $u) {
    echo $u->profile->name;  // N+1
}
```

With:
```php
$users = User::with('profile')->get();   // 2 queries total
```

For nested:
```php
User::with(['profile', 'orders.items'])->get();
```

For conditional eager:
```php
User::with(['orders' => fn($q) => $q->where('status', 'pending')])->get();
```

---

### Q22. select() specific columns.

```php
User::select('id', 'name')->with(['profile:user_id,bio'])->get();
```

Watch out: when eager-loading, you must include the FK column in the related select, or Eloquent can't match.

For very wide tables, this saves significant bytes — and enables index-only scans on the DB.

---

### Q23. lazy() and chunk() — when to use which?

`chunk` runs your callback per batch:
```php
User::where('active', 1)->chunk(1000, function ($users) {
    foreach ($users as $u) { /* ... */ }
});
```

`chunkById` is safer (avoids skipping rows when you modify them):
```php
User::chunkById(1000, function ($users) { ... });
```

`lazy()` (Laravel 8+) is a generator — same effect, more idiomatic:
```php
foreach (User::where('active', 1)->lazy(1000) as $u) { ... }
```

`cursor()` keeps one DB cursor open and yields rows — lowest memory, but holds a connection:
```php
foreach (User::where('active', 1)->cursor() as $u) { ... }
```

For million-row jobs, prefer `lazyById()`.

---

### Q24. Cursor pagination vs offset pagination.

Offset:
```php
User::orderBy('id')->paginate(20);   // page 1000 = OFFSET 20000
```
Page 1000 scans 20020 rows. Death at scale.

Cursor:
```php
User::orderBy('id')->cursorPaginate(20);
// uses WHERE id > ? — uses index seek
```
Constant time regardless of position. Cannot jump to a specific page, only next/prev.

---

### Q25. Eloquent vs Query Builder vs Raw SQL.

| Layer | Speed | Features | Use |
|-------|-------|----------|-----|
| Eloquent | Slowest (~2–5x) | Models, relations, casting, events | Most app code |
| Query Builder | Fast | Fluent SQL, no model overhead | Bulk ops, reports |
| Raw SQL | Fastest | Total control | Hot paths, complex queries |

Don't prematurely optimize. Profile, then drop to lower layers when needed:
```php
// Hot insert loop
DB::table('events')->insert($rows);   // bulk insert, no model events

// Bulk update
DB::statement('UPDATE foo SET x = x + 1 WHERE y = ?', [$id]);
```

---

### Q26. Avoiding model boot overhead.

For high-throughput batch jobs:
- Disable observers and events temporarily: `Event::fake()` or use `withoutEvents()`
- Avoid casts on hot fields if you don't need them
- `toArray()` skips relations not loaded — but `toArray()` itself iterates

For tightest perf: `DB::table()` instead of Eloquent.

---

### Q27. Eloquent performance pitfalls.

1. **Accessing relations in a loop without eager loading** — N+1
2. **`$model->fresh()` in a loop** — refetches every time
3. **JSON casts on huge fields** — unmarshaled every access
4. **`$collection->where(...)` instead of `where(...)->get()`** — pulls all rows then filters in PHP
5. **Boot-time global scopes** that always add joins
6. **Implicit `count()` in pagination on huge tables** — disable with `simplePaginate()`

---

## N+1 Detection and Prevention

### Q28. Tools to detect N+1.

- **Laravel Debugbar** (`barryvdh/laravel-debugbar`) — query log per request
- **Laravel Telescope** — query timeline per request
- **Clockwork** — Chrome devtools panel
- **`beyondcode/laravel-query-detector`** — blows up if N+1 detected
- **APM** (Datadog, New Relic, Inspector) — production monitoring

In dev, fail fast:
```php
// AppServiceProvider boot()
Model::preventLazyLoading(! app()->isProduction());
```

This throws on any lazy load. Forces explicit `with()`.

---

### Q29. preventLazyLoading vs preventAccessingMissingAttributes.

Both Laravel 9+:
```php
Model::preventLazyLoading();
Model::preventAccessingMissingAttributes();
Model::preventSilentlyDiscardingAttributes();
```

Catches:
- Lazy load (N+1)
- Accessing a column you didn't select
- Setting an attribute not in `$fillable` (silently dropped → bugs)

Prod: turn off lazy loading prevention but keep the others.

---

### Q30. Model::shouldBeStrict() — Laravel 11.

One-liner that enables all three:
```php
Model::shouldBeStrict(! app()->isProduction());
```

Use in dev/staging. Gives you free safety net.

---

## Caching with Redis

### Q31. Cache stores in Laravel.

| Driver | Speed | Multi-instance | Use |
|--------|-------|----------------|-----|
| array | Fastest | No (per-process) | Tests |
| file | Slow | Local disk only | Tiny apps, dev |
| database | Slow | Yes | Avoid for cache |
| memcached | Fast | Yes | Legacy |
| redis | Fast | Yes, plus features | Production default |
| octane | Fastest | Per-server | Octane only |

For multi-server production: **Redis** for cache, sessions, queues, locks.

---

### Q32. Redis client choice — predis vs phpredis.

| Feature | predis (PHP) | phpredis (extension) |
|---------|--------------|----------------------|
| Speed | Slower | 5–10x faster |
| Install | composer | apt-get / pecl |
| Cluster support | Yes | Yes |
| Persistent connections | Limited | Yes |

Use phpredis in production:
```ini
; /etc/php/8.3/fpm/conf.d/20-redis.ini
extension=redis.so
```

```php
// config/database.php
'redis' => [
    'client' => 'phpredis',
    'options' => [
        'persistent' => true,
        'serializer' => Redis::SERIALIZER_IGBINARY,  // smaller, faster
    ],
],
```

---

### Q33. Cache::remember pattern.

```php
$users = Cache::remember('users:active', 300, fn () =>
    User::where('active', 1)->get()
);
```

Equivalent to cache-aside. Watch for:
- Stampede: 1000 concurrent misses all hit DB
- Cache::lock for stampede protection:

```php
Cache::lock('users:active:lock', 5)->block(3, function () { ... });
```

Or `flexible` (Laravel 11):
```php
Cache::flexible('users:active', [60, 300], fn () => ...);
// 60s fresh, up to 300s stale-while-revalidate
```

---

### Q34. Cache tags.

```php
Cache::tags(['users', 'tenant:5'])->put('users:active', $data, 300);

// Invalidate all entries tagged 'tenant:5'
Cache::tags(['tenant:5'])->flush();
```

Only works with redis/memcached drivers. Cost: each tag flush iterates the tag set.

---

### Q35. Atomic locks for critical sections.

```php
Cache::lock('process-order:'.$orderId, 10)->get(function () use ($order) {
    // Only one worker runs this at a time
    $this->processOrder($order);
});
```

`block($wait, $callback)` waits up to N seconds for the lock.

Use cases: dedupe webhooks, prevent double-processing, leader election.

---

### Q36. Session driver impact.

Default `file` driver works on a single server, but:
- Multi-server: requires sticky sessions or shared filesystem (slow)
- Locks the file per request — concurrent requests for same user serialize

**Production:** redis (or database with caveat). Redis sessions:
```php
'driver' => 'redis',
'connection' => 'session',  // separate DB from cache
```

---

## Queues and Background Jobs

### Q37. Queue drivers — comparison.

| Driver | Throughput | Reliability | Use |
|--------|------------|-------------|-----|
| sync | N/A | Zero (runs inline) | Tests, dev |
| database | Low (~100/s) | Good | Tiny apps |
| redis | High (10k+/s) | Good (+ Horizon) | Default production |
| sqs | Moderate (managed) | Excellent | AWS shops |
| beanstalkd | Moderate | Good | Niche |

Redis with Horizon is the standard Laravel choice. For very high scale: SQS or RabbitMQ.

---

### Q38. Horizon — what does it add over plain Redis queues?

- Auto-balancing workers across queues based on load
- Web dashboard with metrics, throughput, failures
- Job tagging for tracing
- Alerting on long wait times

Configuration:
```php
'production' => [
    'supervisor-1' => [
        'connection' => 'redis',
        'queue' => ['critical', 'default', 'low'],
        'balance' => 'auto',
        'minProcesses' => 5,
        'maxProcesses' => 30,
        'tries' => 3,
        'timeout' => 60,
    ],
],
```

`balance: auto` shifts workers to the queue with most pending jobs.

---

### Q39. Job optimization patterns.

- **Use `ShouldBeUnique`** to prevent duplicates
- **Use `ShouldBeEncrypted`** for sensitive payloads
- **Batch jobs** for fan-out:
  ```php
  Bus::batch([
      new ProcessUser(1), new ProcessUser(2), ...
  ])->then(fn() => Log::info('done'))->dispatch();
  ```
- **Job chaining** for sequential dependencies
- **Rate-limit** jobs hitting third-party APIs:
  ```php
  Redis::throttle('mailgun')->allow(60)->every(60)->then(fn() => $this->send());
  ```

---

### Q40. Worker memory management.

Long-running workers leak. Mitigations:
```bash
php artisan queue:work --max-jobs=1000 --max-time=3600 --memory=256
```

Worker exits when any limit hit; supervisor restarts. Prevents unbounded growth.

`--tries=3 --backoff=10,30,60` for retries with exponential delays.

---

### Q41. Why `queue:restart` is essential after deploys.

Workers boot the app once and reuse it. After a code deploy, old workers run old code until restarted.

```bash
php artisan queue:restart   # broadcasts a signal; workers exit gracefully after current job
```

Supervisor (or Horizon) respawns them with the new code.

---

## Laravel Octane

### Q42. What is Octane?

Octane keeps the Laravel app booted in memory across requests, served by Swoole, RoadRunner, or FrankenPHP. No more boot per request.

**Performance gain:** 2–10x throughput on the same hardware. p99 latency drops dramatically (no boot variance).

---

### Q43. Swoole vs RoadRunner vs FrankenPHP.

| Feature | Swoole | RoadRunner | FrankenPHP |
|---------|--------|------------|------------|
| Language | C extension | Go | Go (Caddy) |
| Coroutines | Yes | No | Yes (8.3+) |
| WebSockets / async | Yes | Limited | Yes |
| Setup ease | Medium | Easy | Easiest |
| Worker model | Multi-worker | Multi-worker | Multi-worker |
| HTTP/2/3 | Manual | Manual | Built-in |
| HTTPS auto | No | No | Yes (Caddy) |

For most apps, FrankenPHP is the new default. Swoole if you need coroutines for huge concurrency. RoadRunner is solid and stable.

---

### Q44. State leakage in Octane.

The biggest gotcha: app state persists across requests. Globals, statics, singletons must reset.

**Common bugs:**
- Auth user from previous request leaks (Octane resets the auth singleton, but custom singletons don't)
- Static caches in custom services accumulate forever
- DB connections held by long-running workers timeout

**Fixes:**
- Use `OctaneServiceProvider` to register listeners that reset state on each request
- Use `app()->singleton()` cautiously; prefer `bind()` for stateful services
- Listen to `RequestReceived` event to flush per-request caches

---

### Q45. Octane configuration tips.

```bash
php artisan octane:start --workers=8 --task-workers=4 --max-requests=500
```

- `--workers`: HTTP workers — match CPU cores or 2× cores
- `--task-workers`: for `Octane::concurrently()` parallel ops
- `--max-requests`: respawn after N to prevent leaks

For Swoole, `concurrently()`:
```php
[$users, $posts] = Octane::concurrently([
    fn () => User::all(),
    fn () => Post::all(),
]);   // run in parallel coroutines
```

---

### Q46. Octane caches.

```php
Octane::cache('key', $value, $seconds);        // Per-server in-memory
Octane::table('users')->set($id, $user);       // Swoole shared table
```

Sub-microsecond access. Useful for hot reference data shared across workers on the same machine. Not replicated across servers — combine with Redis for global cache.

---

## HTTP Caching and Assets

### Q47. Cache-Control and ETag in Laravel.

```php
return response($content)
    ->header('Cache-Control', 'public, max-age=3600, s-maxage=86400, stale-while-revalidate=600')
    ->setEtag(md5($content));
```

For automatic ETag, use middleware:
```php
// Route::middleware('etag')->...
```

Saves bandwidth and serves 304 quickly. Best paired with CDN.

---

### Q48. Vite vs Mix.

Laravel 9+ defaults to **Vite** — much faster HMR, smaller production bundles, native ES modules.

```js
// vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [laravel({ input: ['resources/css/app.css', 'resources/js/app.js'], refresh: true })],
    build: { manifest: true, sourcemap: false, chunkSizeWarningLimit: 500 },
});
```

In Blade:
```blade
@vite(['resources/css/app.css', 'resources/js/app.js'])
```

Vite emits hashed assets and a manifest — Laravel resolves to versioned URLs for cache-busting.

---

### Q49. CDN for assets.

Production setup:
- Build assets locally
- Push to S3 / Cloudflare R2 / etc
- Set `ASSET_URL=https://cdn.example.com` in `.env`
- Set immutable cache headers (`max-age=31536000, immutable`) — safe because filenames are hashed

```php
// .env
ASSET_URL=https://cdn.example.com
```

`asset()` helper now prefixes with the CDN.

---

### Q50. Response compression.

Best done in nginx, not PHP:
```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
gzip_comp_level 6;
gzip_vary on;

# Brotli (better than gzip)
brotli on;
brotli_types text/plain text/css application/json application/javascript text/xml application/xml;
brotli_comp_level 4;
```

Avoid `ob_gzhandler` in PHP — wastes CPU compared to nginx.

---

## Service Providers and Boot Time

### Q51. Deferred service providers.

A provider that registers services not used on every request should defer:
```php
class HeavyServiceProvider extends ServiceProvider implements DeferrableProvider
{
    public function provides() { return [HeavyService::class]; }
    public function register() {
        $this->app->singleton(HeavyService::class, fn () => new HeavyService(...));
    }
}
```

Effect: Laravel skips bootstrapping until the service is actually requested. Saves 1–10 ms per request on typical apps with many providers.

---

### Q52. Removing unused middleware.

Audit `app/Http/Kernel.php`:
- Is `EncryptCookies` needed if you don't use cookies?
- `VerifyCsrfToken` adds overhead — skip for stateless APIs
- `ShareErrorsFromSession` only useful for views

For API-only apps, use a slim middleware stack:
```php
'api' => [
    'throttle:api',
    \Illuminate\Routing\Middleware\SubstituteBindings::class,
],
```

---

### Q53. Auto-discovery and package overhead.

Each installed Laravel package may register providers and aliases. Check:
```bash
php artisan package:discover
```

Then `composer.json`:
```json
"extra": {
    "laravel": {
        "dont-discover": ["barryvdh/laravel-debugbar"]
    }
}
```

Move dev tools to `require-dev` and don't auto-discover them in prod.

---

## Profiling Tools

### Q54. Blackfire.

The de-facto profiler for PHP/Laravel. Captures function-level CPU and memory.

```bash
blackfire run php artisan some:command
# or browser extension for HTTP requests
```

Reads:
- Wall time vs CPU time
- I/O wait
- Memory peak per function
- Comparison against baseline

Has a continuous profiling mode (samples 1% of prod requests) — invaluable for finding regressions.

---

### Q55. XHProf / Tideways.

Open source / commercial alternative:
```php
xhprof_enable(XHPROF_FLAGS_CPU + XHPROF_FLAGS_MEMORY);
// ... code ...
$data = xhprof_disable();
```

Tideways is a hosted alternative to Blackfire with similar features.

---

### Q56. Laravel Telescope.

Local dev tool — captures requests, queries, jobs, exceptions, mail, notifications, schedule, dumps.

```bash
composer require laravel/telescope --dev
php artisan telescope:install
```

In production: avoid (security and performance cost). If you need it, restrict by IP and tag, prune aggressively.

---

### Q57. Clockwork.

Chrome/Firefox devtools panel showing requests, queries, events.

```bash
composer require itsgoingd/clockwork
```

Less heavy than Telescope, runs only with the extension installed.

---

### Q58. Pulse — Laravel 11.

Built-in performance dashboard:
- Slow requests, slow queries, slow jobs
- Server load
- Top users by request count
- Cache hit rates

Lightweight, designed for production.

```bash
composer require laravel/pulse
php artisan pulse:install
```

---

## Common Production Patterns

### Q59. Real example: API endpoint going from 800 ms to 80 ms.

Starting state:
- Eloquent loop fetching related models (N+1, 100 queries)
- No caching
- Returning all columns including a 50 KB JSON blob

Steps:
1. Added `with(['profile', 'orders'])` → 3 queries instead of 100. Latency: 200 ms.
2. Selected only required columns. Latency: 150 ms.
3. Cached response by user id, 5 min TTL. Latency: 12 ms (warm), 150 ms (cold).
4. Added `Cache-Control` header for clients. Saves 90% of repeat hits at the edge.

Result: p95 from 800 ms to 80 ms, DB load down 95%.

---

### Q60. Slow controller debugging checklist.

1. Enable query log: `DB::enableQueryLog()` and dump
2. Wrap suspicious blocks in `microtime(true)`
3. Use `dd()` after each major step to see where the wall is
4. Check `request()` size — huge JSON request body parsing
5. Check ORM hydration — model with 200 columns is slow
6. Check middleware chain — auth/policy resolving relations
7. Check response serialization — `Resource::collection()` on 10k items

---

### Q61. Heavy command optimization.

Daily report job processing 10M rows.

Anti-pattern:
```php
foreach (Order::all() as $o) { ... }   // OOM
```

Pattern:
```php
Order::whereDate('created_at', yesterday())
    ->select('id', 'user_id', 'total')
    ->lazyById(2000)
    ->each(function ($o) { /* ... */ });
```

Better: aggregate in SQL and avoid PHP iteration entirely:
```php
DB::statement("INSERT INTO daily_revenue ... SELECT ... FROM orders WHERE ...");
```

---

### Q62. Laravel scheduler optimization.

```php
$schedule->job(new ProcessQueue)->everyMinute()->withoutOverlapping();
$schedule->command('reports:daily')->dailyAt('02:00')->onOneServer()->runInBackground();
```

- `withoutOverlapping()` prevents pile-up if job runs long
- `onOneServer()` (with cache lock) prevents N servers all firing the same task
- `runInBackground()` doesn't block the scheduler tick

For high-frequency tasks, prefer queues over scheduler.

---

### Q63. Avoiding common mass-assignment performance traps.

```php
$user->update($request->all());   // updates every fillable column even if unchanged
```

vs:
```php
$user->fill($request->only(['name', 'email']))->save();  // only saves if dirty
```

`update()` always issues an UPDATE; `save()` is a no-op if nothing changed. On hot paths this matters.

---

### Q64. Serializer performance.

`json_encode` is fast but uses memory. For 10k+ row responses, stream:
```php
return response()->stream(function () use ($users) {
    echo '[';
    foreach ($users->lazyById() as $i => $u) {
        echo ($i ? ',' : '') . json_encode($u);
    }
    echo ']';
}, 200, ['Content-Type' => 'application/json']);
```

Or use API Resource collections with cursor pagination.

---

### Q65. Database transaction tuning.

Wrap related writes:
```php
DB::transaction(function () use ($data) {
    User::create($data);
    Profile::create(...);
    Audit::log(...);
});
```

Avoid:
- Long transactions wrapping HTTP / file I/O — kill connection pool
- `nestedTransactions` if not needed — savepoints add overhead
- `DB::beginTransaction()` without try/finally → connection stays in tx state

For batch inserts of unrelated rows, **don't** wrap in a transaction — defeats parallelism.

---

### Q66. Common pitfall: `Cache::has()` + `Cache::get()` race.

```php
if (Cache::has('key')) return Cache::get('key');   // race!
```

Two requests can both pass `has()`, both call DB. Use `Cache::remember` which is atomic at the application level.

For true atomicity across processes, use `Cache::lock`.

---

### Q67. Reducing memory: 2 GB → 256 MB on a long job.

Symptoms: `php artisan queue:work` worker grows to 2 GB over hours.

Common causes:
1. `DB::enableQueryLog()` left on — every query stays in memory
2. Globally bound singletons accumulating state
3. Eloquent collections in module-level statics
4. `Log::channel('daily')` writing massive files in memory before flush

Fixes:
- Disable query log in workers
- Use `--max-jobs` to recycle
- Flush model events after each job
- `gc_collect_cycles()` periodically (rarely needed but sometimes)

---

### Q68. HTTP client tuning (Guzzle).

```php
Http::pool(fn ($pool) => [
    $pool->get('https://a.example.com/x'),
    $pool->get('https://b.example.com/y'),
    $pool->get('https://c.example.com/z'),
]);   // parallel, total time = slowest one
```

Always set timeouts:
```php
Http::timeout(2)->connectTimeout(1)->retry(3, 100)->get(...);
```

A missing timeout is the #1 cause of FPM workers piling up under a slow third-party API.

---

### Q69. Real production checklist.

- [ ] PHP 8.3+
- [ ] Opcache enabled, `validate_timestamps=0`, sized correctly
- [ ] FPM `static` mode, sized for RAM
- [ ] Realpath cache 4MB+
- [ ] `composer install -o -a --no-dev`
- [ ] `php artisan optimize` in deploy
- [ ] Redis for cache + queue + session
- [ ] Horizon (or supervised workers) with `max-jobs`
- [ ] All HTTP clients have timeouts
- [ ] Slowlog at 5s
- [ ] FPM status scraped
- [ ] APM (Datadog / Pulse / New Relic)
- [ ] Logs to stdout (12-factor) or async sink
- [ ] CDN for assets, hashed filenames
- [ ] Nginx gzip / brotli
- [ ] DB connection pooling (PgBouncer / ProxySQL)
- [ ] `Model::shouldBeStrict()` in non-prod
- [ ] Octane considered for high-throughput services

---

### Q70. Senior signal: "How would you 10x this Laravel app's throughput?"

Walk through layers:

1. **Profile** — find the actual bottleneck (CPU? DB? external API?). Don't optimize blindly.
2. **DB** — slow queries, missing indexes, N+1, caching at app layer.
3. **Caching** — Redis for hot data, HTTP cache headers, CDN.
4. **PHP runtime** — opcache, FPM static, JIT if CPU-bound.
5. **Octane** — keep the app warm, biggest single-dial win for warm-cache CPU bound.
6. **Async** — move slow work to queues; reply fast to user.
7. **Scale out** — multiple FPM nodes behind a load balancer; stateless.
8. **DB scale** — read replicas, then partition, then shard.
9. **Cost-benefit** at each step. "10x throughput" is rarely one change.
