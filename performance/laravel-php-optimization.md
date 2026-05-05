# Laravel and PHP Performance Optimization — Interview Q&A Guide

This guide covers PHP runtime tuning, opcache, FPM configuration, Composer autoloading, Eloquent query optimization, caching, queues, Octane, and HTTP-level optimization. Each answer pairs explanation with working configuration or code.

---

## PHP Runtime

## Q1. What does the PHP request lifecycle look like with PHP-FPM?

**Answer:**

A typical request flows like this:

1. Nginx or Apache receives the HTTP request
2. The web server forwards it to PHP-FPM via FastCGI socket
3. FPM picks an idle worker from its pool
4. The worker bootstraps PHP (or uses opcache for compiled bytecode)
5. The script runs (Laravel: `index.php` to kernel to router to controller to response)
6. The worker sends the response, resets state, returns to the pool

In a typical Laravel request the time breakdown looks like:

| Phase | Time |
| --- | --- |
| Bootstrap | 5-30 ms (without opcache: 100+ ms) |
| Routing + middleware | 1-5 ms |
| Controller + DB | usually the bulk |
| Response render | 1-10 ms |

If your "Hello World" Laravel response takes 50+ ms on a warm cache, your runtime is misconfigured.

## Q2. How much do PHP version upgrades actually help?

**Answer:**

Each major version brings real performance gains:

| Version | Notable | Gain vs prior |
| --- | --- | --- |
| PHP 7.0 | New engine (PHPNG) | ~2x over 5.6 |
| PHP 7.4 | Preloading | ~10% |
| PHP 8.0 | JIT, named args | 5-15% on CPU-bound |
| PHP 8.1 | Enums, fibers | 5-8% |
| PHP 8.2 | Readonly classes | 2-5% |
| PHP 8.3 | Typed class constants | 3-7% |

Always run a recent supported version. PHP 8.3 or later is recommended.

## Q3. What is the realpath cache and why does it matter?

**Answer:**

Every `require` and file open does path resolution: symlinks, parent directory traversal, etc. The realpath cache stores resolved paths so PHP does not re-resolve them.

```ini
; php.ini
realpath_cache_size = 4096K
realpath_cache_ttl = 600
```

The default is 16K, far too small for Laravel which touches thousands of files. Bumping to 4 MB can drop a cold Laravel request from 200 ms to 60 ms.

---

## Opcache and JIT

## Q4. What is opcache and why is it essential?

**Answer:**

PHP normally parses source, compiles to bytecode, and executes it on every request. Opcache stores the compiled opcodes in shared memory so subsequent requests skip parsing and compilation.

Without opcache, about 80 percent of bootstrap time is wasted recompiling files that have not changed. Opcache typically gives a 3-5x throughput increase on Laravel apps.

## Q5. What is a good production opcache configuration?

**Answer:**

```ini
; /etc/php/8.3/fpm/conf.d/10-opcache.ini

opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=512
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=20000

; Production: do not check files for changes
opcache.validate_timestamps=0
opcache.revalidate_freq=0

; Saves CPU
opcache.save_comments=1   ; needed for annotations and attributes
opcache.fast_shutdown=1
```

Critical: in production set `validate_timestamps=0`. PHP will not detect changed files, so you must call `opcache_reset()` or restart FPM on deploy.

## Q6. How do you size opcache memory?

**Answer:**

Run on staging:

```php
print_r(opcache_get_status(false));
```

Look at:

- `memory_usage.used_memory`
- `memory_usage.wasted_memory` (high means restart soon)
- `interned_strings_usage.used_memory`
- `opcache_statistics.num_cached_scripts`
- `opcache_statistics.opcache_hit_rate` should be greater than 99 percent

Rule of thumb: 256 MB for medium apps, 512 MB or more for large monoliths.

## Q7. Does JIT in PHP 8 help web apps?

**Answer:**

JIT helps CPU-bound code (computation, parsers, image processing). For typical Laravel apps that are DB or I/O bound, JIT gives 1-3 percent improvement at best.

```ini
opcache.jit_buffer_size=256M
opcache.jit=tracing
```

Test before and after with realistic load. JIT is not free — it consumes shared memory.

## Q8. When is preloading worth using?

**Answer:**

Preloading loads classes once at FPM start, available read-only to all workers.

```php
// preload.php
$files = glob(__DIR__.'/vendor/laravel/framework/src/**/*.php', GLOB_BRACE);
foreach ($files as $file) {
    opcache_compile_file($file);
}
```

```ini
opcache.preload=/var/www/preload.php
opcache.preload_user=www-data
```

Typical gain: 5-10 percent on bootstrap. Less impactful with Octane, which already keeps the app warm. Caveats: preloaded classes cannot be redefined, so every deploy requires an FPM restart.

---

## PHP-FPM Tuning

## Q9. What are the PHP-FPM process manager modes?

**Answer:**

```ini
; www.conf
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 1000
```

| Mode | Behavior | Use when |
| --- | --- | --- |
| static | Fixed worker count | Predictable load, max throughput |
| dynamic | Scales between min and max spare | Default, variable load |
| ondemand | Spawn on request, kill when idle | Low-traffic, resource-constrained |

For high-traffic production, `static` with sized workers gives the best throughput because there is no fork latency on each request.

## Q10. How do you size `pm.max_children`?

**Answer:**

```
pm.max_children = (Total RAM - other services) / Avg memory per worker
```

Measure average worker memory:

```bash
ps -ylC php-fpm8.3 --sort:rss
```

A typical Laravel worker uses 50-200 MB.

Example: a 16 GB server with 2 GB reserved for OS, Nginx, and Redis. Worker uses 100 MB. Max workers = 14 GB / 100 MB = 140.

CPU also matters: each working worker uses CPU. If your app is CPU-bound, more workers thrash. Generally keep workers no higher than `cpu_cores * 4`.

## Q11. What is `pm.max_requests` and how should you set it?

**Answer:**

```ini
pm.max_requests = 1000
```

After N requests, the worker is killed and respawned. This helps with:
- Memory leaks (PHP holds references over time)
- Stale opcache associations
- Preventing one request's bad state from persisting

Do not set it too low (excess fork overhead) or too high (memory growth). 500-2000 is typical.

## Q12. How do you find slow PHP-FPM requests?

**Answer:**

Enable the FPM slowlog:

```ini
slowlog = /var/log/php-fpm/slow.log
request_slowlog_timeout = 5s
request_terminate_timeout = 60s
```

This captures a backtrace of any request running longer than 5 seconds. It is invaluable for tracking down hung external API calls or missing query timeouts.

Sample slowlog output:

```
[22-May-2025 14:01:13] [pool www] pid 12345
script_filename = /var/www/public/index.php
[0x00007f1234] curl_exec() /vendor/.../Client.php:142
[0x00007f1235] App\Services\PaymentClient->charge() /app/...:67
```

## Q13. How do you monitor FPM in production?

**Answer:**

Enable the status page:

```ini
pm.status_path = /fpm-status
ping.path = /ping
```

Sample output:

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
- `listen queue > 0` consistently means workers are exhausted
- `idle processes = 0` means scale up

Scrape with the `hipages/php-fpm_exporter` Prometheus exporter.

---

## Composer Autoloading

## Q14. What flags should Composer use in production?

**Answer:**

```bash
composer install --no-dev --optimize-autoloader --classmap-authoritative
```

- `--optimize-autoloader` (`-o`): builds a classmap from PSR-4 namespaces
- `--classmap-authoritative` (`-a`): all classes must be in the classmap; never falls back to filesystem scan
- `--no-dev`: skip dev dependencies

Effect: reduces autoload resolution from about 5 ms to 0.5 ms per cold request.

## Q15. What does `php artisan optimize` do?

**Answer:**

In Laravel 11+, `php artisan optimize` runs:

```
route:cache
view:cache
event:cache
config:cache
```

Reverse with `php artisan optimize:clear`. Each cache shaves 5-30 ms off bootstrap, so it is essential in production.

## Q16. What are the pitfalls of config caching?

**Answer:**

After `php artisan config:cache`:
- `env()` calls outside config files return `null`
- Closure-based config values fail to cache (must be plain arrays)

Bad:

```php
// Anywhere in the app outside config/*
$key = env('STRIPE_KEY');   // returns null after config:cache
```

Good:

```php
// In config/services.php
'stripe' => ['key' => env('STRIPE_KEY')],

// Anywhere
$key = config('services.stripe.key');
```

Rule: use `env()` only inside `config/*.php`. Use `config('...')` everywhere else.

---

## Laravel Built-in Caches

## Q17. What does route caching do?

**Answer:**

```bash
php artisan route:cache
```

All routes are loaded into a single compiled file. Closure routes break — they must be `Controller@method` style. Boot becomes 5-20 ms faster on apps with 500+ routes. Re-run on every deploy.

## Q18. What does view caching do?

**Answer:**

Blade templates compile to PHP on first hit. `view:cache` pre-compiles them all at deploy time:

```bash
php artisan view:cache
```

This saves the per-page first-hit compile cost (5-50 ms depending on template complexity). Necessary under Octane where state persists across requests.

## Q19. What does event caching do?

**Answer:**

Laravel discovers event listeners by reflection. `event:cache` writes them to a manifest:

```bash
php artisan event:cache
```

Saves about 10 ms on apps with many listeners.

## Q20. What is a recommended production deploy script?

**Answer:**

```bash
php artisan down
composer install --no-dev --optimize-autoloader --classmap-authoritative
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
php artisan queue:restart
sudo systemctl reload php8.3-fpm
php artisan up
```

For zero-downtime deploys: deploy to a new release directory, atomically swap the symlink, then reload FPM.

---

## Eloquent Optimization

## Q21. How do you eager-load relationships with `with()`?

**Answer:**

Without eager loading you get N+1 queries:

```php
$users = User::all();
foreach ($users as $u) {
    echo $u->profile->name;   // 1 query per user
}
```

With:

```php
$users = User::with('profile')->get();   // 2 queries total
```

Nested:

```php
User::with(['profile', 'orders.items'])->get();
```

Conditional:

```php
User::with(['orders' => fn ($q) => $q->where('status', 'pending')])->get();
```

## Q22. How do you select only the columns you need?

**Answer:**

```php
User::select('id', 'name')
    ->with(['profile:user_id,bio'])
    ->get();
```

When eager-loading, you must include the foreign key column in the related select, otherwise Eloquent cannot match.

For wide tables this saves significant bytes, and on the DB side it can enable index-only scans.

## Q23. When should you use `chunk()`, `lazy()`, or `cursor()`?

**Answer:**

`chunk()` runs your callback per batch:

```php
User::where('active', 1)->chunk(1000, function ($users) {
    foreach ($users as $u) { /* ... */ }
});
```

`chunkById()` is safer when modifying rows during iteration:

```php
User::chunkById(1000, function ($users) { /* ... */ });
```

`lazy()` is a generator, more idiomatic:

```php
foreach (User::where('active', 1)->lazy(1000) as $u) { /* ... */ }
```

`cursor()` keeps one DB cursor open and yields rows. Lowest memory but holds a connection:

```php
foreach (User::where('active', 1)->cursor() as $u) { /* ... */ }
```

For million-row jobs, prefer `lazyById()`.

## Q24. Cursor pagination vs offset pagination?

**Answer:**

Offset:

```php
User::orderBy('id')->paginate(20);   // page 1000 = OFFSET 20000
```

Page 1000 scans 20,020 rows. Performance dies at scale.

Cursor:

```php
User::orderBy('id')->cursorPaginate(20);
// Generates: WHERE id > ? LIMIT 21
```

Constant time regardless of position. The trade-off: cannot jump to a specific page, only next or previous.

## Q25. Eloquent vs Query Builder vs raw SQL — when to use which?

**Answer:**

| Layer | Speed | Features | Use |
| --- | --- | --- | --- |
| Eloquent | Slowest (~2-5x) | Models, relations, casting, events | Most app code |
| Query Builder | Fast | Fluent SQL, no model overhead | Bulk operations, reports |
| Raw SQL | Fastest | Total control | Hot paths, complex queries |

```php
// Eloquent: convenient
Order::create($data);

// Query Builder: bulk insert with no model events
DB::table('events')->insert($rows);

// Raw SQL: maximum control
DB::statement('UPDATE counters SET count = count + 1 WHERE id = ?', [$id]);
```

Profile first, then drop to a lower layer if needed.

## Q26. How do you avoid model boot overhead in batch jobs?

**Answer:**

For high-throughput batch jobs:

```php
// Disable model events (boot, observers, etc)
User::withoutEvents(function () {
    User::insert($rows);
});

// Use Query Builder to skip model construction entirely
DB::table('events')->insert($rows);
```

Avoid eager casts on hot fields if you do not need them. For tightest performance, `DB::table()` is best.

## Q27. What are the most common Eloquent performance pitfalls?

**Answer:**

1. Accessing relations in a loop without eager loading (N+1)
2. `$model->fresh()` in a loop refetches every time
3. JSON casts on huge fields are unmarshaled on every access
4. `$collection->where(...)` instead of `Model::where(...)->get()` pulls all rows then filters in PHP
5. Boot-time global scopes that always add joins
6. Implicit `count()` in `paginate()` on huge tables — use `simplePaginate()` instead

```php
// BAD: pulls 10k rows, filters in PHP
$active = User::all()->where('active', 1);

// GOOD: filters in DB
$active = User::where('active', 1)->get();
```

---

## N+1 Detection

## Q28. What tools detect N+1?

**Answer:**

- Laravel Debugbar (`barryvdh/laravel-debugbar`) shows the query log per request
- Laravel Telescope shows the query timeline
- Clockwork is a Chrome devtools panel
- `beyondcode/laravel-query-detector` throws when N+1 is detected
- APM tools (Datadog, New Relic, Inspector) for production

In dev, fail fast:

```php
// AppServiceProvider::boot()
Model::preventLazyLoading(! app()->isProduction());
```

This throws on any lazy load, forcing explicit `with()`.

## Q29. What is `preventLazyLoading` vs `preventAccessingMissingAttributes`?

**Answer:**

Three guards in Laravel 9+:

```php
Model::preventLazyLoading();
Model::preventAccessingMissingAttributes();
Model::preventSilentlyDiscardingAttributes();
```

They catch:
- Lazy loading (N+1)
- Accessing a column you did not select
- Setting an attribute not in `$fillable` (which Laravel silently drops)

In production, turn off lazy loading prevention but keep the others.

## Q30. What does `Model::shouldBeStrict()` do in Laravel 11?

**Answer:**

A one-liner that enables all three:

```php
// AppServiceProvider::boot()
Model::shouldBeStrict(! app()->isProduction());
```

Use it in dev and staging. Free safety net against silent data bugs.

---

## Caching with Redis

## Q31. What cache stores does Laravel support?

**Answer:**

| Driver | Speed | Multi-instance | Use |
| --- | --- | --- | --- |
| array | Fastest | No (per-process) | Tests |
| file | Slow | Local disk only | Tiny apps, dev |
| database | Slow | Yes | Avoid for cache |
| memcached | Fast | Yes | Legacy |
| redis | Fast | Yes, plus features | Production default |
| octane | Fastest | Per-server | Octane only |

For multi-server production: Redis for cache, sessions, queues, and locks.

## Q32. Should you use predis or phpredis?

**Answer:**

| Feature | predis (PHP) | phpredis (extension) |
| --- | --- | --- |
| Speed | Slower | 5-10x faster |
| Install | Composer | apt or pecl |
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
        'serializer' => Redis::SERIALIZER_IGBINARY,
    ],
],
```

## Q33. What is the `Cache::remember` pattern?

**Answer:**

```php
$users = Cache::remember('users:active', 300, fn () =>
    User::where('active', 1)->get()
);
```

This is cache-aside: fetch from cache; on miss, compute the value, store, return.

Watch out for stampedes — 1000 concurrent misses all hit the DB. Use a lock:

```php
Cache::lock('users:active:lock', 5)->block(3, function () {
    return User::where('active', 1)->get();
});
```

In Laravel 11+, use `flexible` for stale-while-revalidate:

```php
Cache::flexible('users:active', [60, 300], fn () => User::where('active', 1)->get());
// 60 seconds fresh, up to 300 seconds stale-while-revalidate
```

## Q34. How do cache tags work?

**Answer:**

```php
Cache::tags(['users', 'tenant:5'])->put('users:active', $data, 300);

// Invalidate all entries tagged with tenant:5
Cache::tags(['tenant:5'])->flush();
```

Only works with redis and memcached drivers. Each tag flush iterates the tag set, so use coarse tags rather than per-record.

## Q35. How do you use atomic locks for critical sections?

**Answer:**

```php
Cache::lock('process-order:'.$orderId, 10)->get(function () use ($order) {
    // Only one worker runs this at a time
    $this->processOrder($order);
});
```

`block($wait, $callback)` waits up to N seconds for the lock to free.

Use cases: dedupe webhooks, prevent double-processing, leader election.

## Q36. How does the session driver impact performance?

**Answer:**

The default `file` driver works on a single server but has problems:
- Multi-server: requires sticky sessions or a shared filesystem (slow)
- Locks the file per request, so concurrent requests for the same user serialize

Production: Redis sessions.

```php
// config/session.php
'driver' => 'redis',
'connection' => 'session',   // separate Redis DB from cache
```

---

## Queues

## Q37. What queue drivers does Laravel support?

**Answer:**

| Driver | Throughput | Reliability | Use |
| --- | --- | --- | --- |
| sync | N/A | Zero (runs inline) | Tests, dev |
| database | Low (~100/s) | Good | Tiny apps |
| redis | High (10k+/s) | Good (with Horizon) | Default production |
| sqs | Moderate (managed) | Excellent | AWS shops |
| beanstalkd | Moderate | Good | Niche |

Redis with Horizon is the standard Laravel choice. For very high scale: SQS or RabbitMQ.

## Q38. What does Horizon add over plain Redis queues?

**Answer:**

- Auto-balancing workers across queues based on load
- Web dashboard with metrics, throughput, failures
- Job tagging for tracing
- Alerting on long wait times

```php
// config/horizon.php
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

`balance: auto` shifts workers to the queue with the most pending jobs.

## Q39. What are common job optimization patterns?

**Answer:**

```php
// Prevent duplicate processing
class ProcessUser implements ShouldQueue, ShouldBeUnique
{
    public $uniqueFor = 3600;
    public function uniqueId() { return $this->user->id; }
}

// Batch fan-out
Bus::batch([
    new ProcessUser(1),
    new ProcessUser(2),
])->then(fn () => Log::info('done'))->dispatch();

// Job chaining for sequential dependencies
Bus::chain([
    new GenerateInvoice($order),
    new SendInvoiceEmail($order),
])->dispatch();

// Rate-limit jobs hitting third-party APIs
public function handle()
{
    Redis::throttle('mailgun')
        ->allow(60)->every(60)
        ->then(fn () => $this->send());
}
```

## Q40. How do you keep worker memory under control?

**Answer:**

Long-running workers leak. Mitigate with limits:

```bash
php artisan queue:work \
    --max-jobs=1000 \
    --max-time=3600 \
    --memory=256 \
    --tries=3 \
    --backoff=10,30,60
```

The worker exits when any limit is hit; supervisor restarts it. This prevents unbounded growth.

## Q41. Why is `queue:restart` essential after a deploy?

**Answer:**

Workers boot the app once and reuse it across jobs. After a deploy, old workers run the old code until restarted.

```bash
php artisan queue:restart
```

This broadcasts a signal; workers exit gracefully after their current job. Supervisor or Horizon respawns them with the new code.

---

## Laravel Octane

## Q42. What is Octane?

**Answer:**

Octane keeps the Laravel app booted in memory across requests, served by Swoole, RoadRunner, or FrankenPHP. No bootstrapping per request.

Performance gain: 2-10x throughput on the same hardware. p99 latency drops dramatically because there is no boot variance.

```bash
composer require laravel/octane
php artisan octane:install --server=frankenphp
php artisan octane:start --workers=8 --max-requests=500
```

## Q43. Swoole vs RoadRunner vs FrankenPHP — how do they compare?

**Answer:**

| Feature | Swoole | RoadRunner | FrankenPHP |
| --- | --- | --- | --- |
| Language | C extension | Go | Go (Caddy) |
| Coroutines | Yes | No | Yes (8.3+) |
| WebSockets / async | Yes | Limited | Yes |
| Setup ease | Medium | Easy | Easiest |
| HTTP/2/3 | Manual | Manual | Built-in |
| HTTPS auto | No | No | Yes (Caddy) |

For most apps, FrankenPHP is the modern default. Swoole if you need coroutines for huge concurrency. RoadRunner is solid and stable.

## Q44. What are the state-leakage gotchas in Octane?

**Answer:**

App state persists across requests. Globals, statics, and singletons must reset.

Common bugs:

```php
// BAD: static cache accumulates forever
class UserService {
    private static array $cache = [];
    public function find($id) {
        return self::$cache[$id] ??= User::find($id);
    }
}
```

```php
// GOOD: listen to RequestReceived to flush per-request state
use Laravel\Octane\Events\RequestReceived;

Event::listen(RequestReceived::class, function () {
    UserService::resetCache();
});
```

Other pitfalls:
- DB connections held by long-running workers may time out — use connection healthchecks
- Auth user from a previous request can leak if you create custom singletons that hold the user

## Q45. What are useful Octane configuration options?

**Answer:**

```bash
php artisan octane:start \
    --workers=8 \
    --task-workers=4 \
    --max-requests=500
```

- `--workers`: HTTP workers, match CPU cores or 2x cores
- `--task-workers`: for `Octane::concurrently()` parallel operations
- `--max-requests`: respawn after N requests to prevent leaks

For Swoole, run code in parallel coroutines:

```php
[$users, $posts] = Octane::concurrently([
    fn () => User::all(),
    fn () => Post::all(),
]);
```

## Q46. What are Octane caches?

**Answer:**

```php
// Per-server in-memory cache, sub-microsecond access
Octane::cache('key', $value, $seconds);

// Swoole shared table — shared across workers on this server
Octane::table('users')->set($id, $user);
```

Useful for hot reference data shared across workers on the same machine. Not replicated across servers — combine with Redis for global cache.

---

## HTTP Caching and Assets

## Q47. How do you set Cache-Control and ETag in Laravel?

**Answer:**

```php
return response($content)
    ->header('Cache-Control', 'public, max-age=3600, s-maxage=86400, stale-while-revalidate=600')
    ->setEtag(md5($content));
```

When the client sends `If-None-Match`, Laravel returns 304 if the ETag matches, saving bandwidth. Combine with a CDN to serve 95+ percent of repeat hits at the edge.

## Q48. What is the difference between Vite and Mix?

**Answer:**

Laravel 9+ defaults to Vite — much faster HMR, smaller production bundles, and native ES modules.

```js
// vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [laravel({
        input: ['resources/css/app.css', 'resources/js/app.js'],
        refresh: true,
    })],
    build: {
        manifest: true,
        sourcemap: false,
        chunkSizeWarningLimit: 500,
    },
});
```

In Blade:

```blade
@vite(['resources/css/app.css', 'resources/js/app.js'])
```

Vite emits hashed filenames and a manifest, and Laravel resolves to versioned URLs for cache-busting.

## Q49. How do you serve assets from a CDN?

**Answer:**

```bash
# .env
ASSET_URL=https://cdn.example.com
```

Production setup:
1. Build assets locally
2. Push to S3, Cloudflare R2, or similar
3. Set `ASSET_URL` in `.env`
4. Set immutable cache headers on the CDN — safe because filenames are content-hashed

```
Cache-Control: public, max-age=31536000, immutable
```

The `asset()` helper now prefixes with the CDN URL.

## Q50. Where should you do response compression?

**Answer:**

In Nginx, not PHP. PHP-side `ob_gzhandler` wastes CPU.

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml;
gzip_comp_level 6;
gzip_vary on;

# Brotli (better than gzip when available)
brotli on;
brotli_types text/plain text/css application/json application/javascript;
brotli_comp_level 4;
```

---

## Service Providers and Boot Time

## Q51. What are deferred service providers?

**Answer:**

A provider whose services are not used on every request should be deferred:

```php
class HeavyServiceProvider extends ServiceProvider implements DeferrableProvider
{
    public function provides(): array
    {
        return [HeavyService::class];
    }

    public function register(): void
    {
        $this->app->singleton(HeavyService::class, fn () => new HeavyService(...));
    }
}
```

Effect: Laravel skips bootstrapping until the service is first requested. Saves 1-10 ms per request on apps with many providers.

## Q52. How do you remove unused middleware?

**Answer:**

Audit `app/Http/Kernel.php`:
- Is `EncryptCookies` needed if you do not use cookies?
- `VerifyCsrfToken` adds overhead — skip it for stateless APIs
- `ShareErrorsFromSession` only useful for views

For API-only apps, use a slim middleware stack:

```php
'api' => [
    'throttle:api',
    \Illuminate\Routing\Middleware\SubstituteBindings::class,
],
```

## Q53. How do you control package auto-discovery?

**Answer:**

Each installed Laravel package may register providers and aliases. Check what is being registered:

```bash
php artisan package:discover
```

Disable in `composer.json`:

```json
{
    "extra": {
        "laravel": {
            "dont-discover": ["barryvdh/laravel-debugbar"]
        }
    }
}
```

Move dev tools to `require-dev` and exclude them from auto-discovery in production.

---

## Profiling Tools

## Q54. What is Blackfire?

**Answer:**

The standard PHP profiler. Captures function-level CPU and memory.

```bash
blackfire run php artisan some:command
# Or use the browser extension for HTTP requests
```

Reads:
- Wall time vs CPU time
- I/O wait
- Memory peak per function
- Comparison against baseline

Has a continuous profiling mode that samples 1 percent of production requests, ideal for spotting regressions.

## Q55. What are XHProf and Tideways?

**Answer:**

Open source and commercial alternatives.

```php
xhprof_enable(XHPROF_FLAGS_CPU + XHPROF_FLAGS_MEMORY);
// ... code ...
$data = xhprof_disable();
```

Tideways is a hosted alternative to Blackfire with similar features.

## Q56. What is Laravel Telescope?

**Answer:**

Local dev tool that captures requests, queries, jobs, exceptions, mail, notifications, scheduled tasks, and dumps.

```bash
composer require laravel/telescope --dev
php artisan telescope:install
```

Avoid in production unless you restrict by IP or tag and prune aggressively — it has security and performance costs.

## Q57. What is Clockwork?

**Answer:**

A Chrome and Firefox devtools panel showing requests, queries, and events.

```bash
composer require itsgoingd/clockwork
```

Lighter than Telescope and runs only when the browser extension is active.

## Q58. What is Pulse in Laravel 11?

**Answer:**

A built-in lightweight performance dashboard:
- Slow requests, slow queries, slow jobs
- Server load
- Top users by request count
- Cache hit rates

```bash
composer require laravel/pulse
php artisan pulse:install
```

Designed for production use.

---

## Production Patterns

## Q59. How do you take an API endpoint from 800 ms to 80 ms?

**Answer:**

Starting state:
- Eloquent loop fetching related models (N+1, 100 queries)
- No caching
- Returning all columns including a 50 KB JSON blob

Steps:

```php
// Step 1: eager load -> 800ms to 200ms (3 queries instead of 100)
$users = User::with(['profile', 'orders'])->get();

// Step 2: select only required columns -> 200ms to 150ms
$users = User::select('id', 'name', 'email')
    ->with(['profile:user_id,bio', 'orders:user_id,total'])
    ->get();

// Step 3: cache by user id, 5 min TTL -> 150ms to 12ms warm
return Cache::remember("user:{$id}:dashboard", 300, fn () =>
    User::with(['profile:user_id,bio', 'orders:user_id,total'])->find($id)
);

// Step 4: HTTP cache header -> client revalidates with 304
return response()->json($data)
    ->header('Cache-Control', 'private, max-age=60');
```

Result: p95 from 800 ms to 80 ms, DB load down 95 percent.

## Q60. What is a slow controller debugging checklist?

**Answer:**

```php
// 1. Enable query log and dump after the controller
DB::enableQueryLog();
// ...
dd(DB::getQueryLog());

// 2. Wrap suspicious blocks in microtime
$start = microtime(true);
$result = doSomething();
Log::info('took', ['ms' => (microtime(true) - $start) * 1000]);

// 3. Use clockwork or telescope to see the timeline
```

Common culprits:
1. ORM hydration of models with 200 columns
2. Middleware chain (auth, policies) loading relations
3. Response serialization (`Resource::collection()` on 10k items)
4. Huge JSON request body parsing
5. Synchronous third-party API calls without timeouts

## Q61. How do you optimize a heavy Artisan command?

**Answer:**

Anti-pattern:

```php
// OOM on 10M rows
foreach (Order::all() as $order) {
    process($order);
}
```

Stream by ID:

```php
Order::whereDate('created_at', yesterday())
    ->select('id', 'user_id', 'total')
    ->lazyById(2000)
    ->each(function ($order) {
        process($order);
    });
```

Best: aggregate in SQL and skip PHP iteration entirely:

```php
DB::statement("
    INSERT INTO daily_revenue (day, total)
    SELECT date(created_at), SUM(total)
    FROM orders
    WHERE created_at >= ?
    GROUP BY date(created_at)
", [yesterday()]);
```

## Q62. How do you optimize the Laravel scheduler?

**Answer:**

```php
// app/Console/Kernel.php
$schedule->job(new ProcessQueue)
    ->everyMinute()
    ->withoutOverlapping();

$schedule->command('reports:daily')
    ->dailyAt('02:00')
    ->onOneServer()
    ->runInBackground();
```

- `withoutOverlapping()` prevents pile-up if a job runs long
- `onOneServer()` (with cache lock) prevents N servers all firing the same task
- `runInBackground()` does not block the scheduler tick

For high-frequency tasks, prefer dispatching to queues over the scheduler.

## Q63. What is the cost of `update()` vs `fill()` plus `save()`?

**Answer:**

```php
// Always issues an UPDATE even if nothing changed
$user->update($request->all());

// No-op if nothing changed (Eloquent tracks dirty attributes)
$user->fill($request->only(['name', 'email']))->save();
```

On hot paths this matters: thousands of unchanged rows can mean thousands of unnecessary writes plus replication traffic.

## Q64. How do you serialize huge JSON responses efficiently?

**Answer:**

`json_encode` is fast but allocates memory for the whole structure. For 10k+ rows, stream:

```php
return response()->stream(function () use ($users) {
    echo '[';
    $first = true;
    foreach ($users->lazyById() as $u) {
        echo ($first ? '' : ',') . json_encode($u);
        $first = false;
    }
    echo ']';
}, 200, ['Content-Type' => 'application/json']);
```

Or use API Resource collections with cursor pagination:

```php
return UserResource::collection(User::cursorPaginate(50));
```

## Q65. What are good database transaction patterns?

**Answer:**

Wrap related writes:

```php
DB::transaction(function () use ($data) {
    $user = User::create($data);
    Profile::create(['user_id' => $user->id]);
    Audit::log($user, 'created');
});
```

Avoid:
- Long transactions wrapping HTTP or file I/O — they hold connection pool slots
- Nested transactions if not needed (savepoints add overhead)
- Calling `DB::beginTransaction()` without try/finally — leaves the connection in a transaction state

For batch inserts of unrelated rows, do not wrap in a single transaction — it serializes parallelism.

## Q66. What is the bug with `Cache::has()` plus `Cache::get()`?

**Answer:**

```php
// RACE CONDITION
if (Cache::has('key')) {
    return Cache::get('key');   // key might have expired here
}
```

Two requests can both pass `has()`, then both call the DB. Use the atomic `Cache::remember()` instead:

```php
return Cache::remember('key', 300, fn () => fetch());
```

For cross-process atomicity, use `Cache::lock()`.

## Q67. How do you reduce a long-running worker's memory from 2 GB to 256 MB?

**Answer:**

Symptoms: `php artisan queue:work` worker grows to 2 GB over hours.

Common causes:

```php
// 1. Query log left enabled — every query stays in memory
DB::enableQueryLog();   // never call this in workers

// 2. Globally bound singletons accumulating state
$this->app->singleton(Cache::class, fn () => new BigCache);

// 3. Eloquent collections held in module-level statics
class Reporter {
    private static array $allUsers = [];   // grows forever
}
```

Fixes:

```bash
# Recycle workers periodically
php artisan queue:work --max-jobs=100 --memory=256
```

```php
// In each job, flush per-job state
DB::flushQueryLog();
```

## Q68. How do you tune the Guzzle HTTP client?

**Answer:**

```php
// Always set timeouts. Missing timeouts cause FPM workers to pile up
Http::timeout(2)
    ->connectTimeout(1)
    ->retry(3, 100)
    ->get('https://api.example.com/x');

// Run multiple requests in parallel
$responses = Http::pool(fn ($pool) => [
    $pool->get('https://a.example.com/x'),
    $pool->get('https://b.example.com/y'),
    $pool->get('https://c.example.com/z'),
]);
// Total time = slowest one
```

A missing timeout is the number-one cause of FPM workers piling up under a slow third-party API.

## Q69. What is a complete production checklist for Laravel?

**Answer:**

- [ ] PHP 8.3 or later
- [ ] Opcache enabled, `validate_timestamps=0`, sized correctly
- [ ] FPM `static` mode, sized for RAM
- [ ] Realpath cache 4 MB or larger
- [ ] `composer install -o -a --no-dev`
- [ ] `php artisan optimize` in deploy
- [ ] Redis for cache, queue, and session
- [ ] Horizon (or supervised workers) with `--max-jobs`
- [ ] All HTTP clients have timeouts
- [ ] FPM slowlog at 5 seconds
- [ ] FPM status scraped by Prometheus or similar
- [ ] APM (Datadog, Pulse, New Relic)
- [ ] Logs to stdout (12-factor) or async sink
- [ ] CDN for assets, hashed filenames
- [ ] Nginx gzip or brotli
- [ ] DB connection pooling (PgBouncer or ProxySQL)
- [ ] `Model::shouldBeStrict()` in non-prod
- [ ] Octane considered for high-throughput services

## Q70. How would you 10x a Laravel app's throughput?

**Answer:**

Walk through the layers in order, from cheapest to most complex:

1. **Profile** to find the actual bottleneck (CPU, DB, external API). Do not optimize blindly.
2. **DB** — fix slow queries, add missing indexes, eliminate N+1, cache at app layer.
3. **Caching** — Redis for hot data, HTTP cache headers, CDN.
4. **PHP runtime** — opcache, FPM static, JIT if CPU-bound.
5. **Octane** — keep the app warm, the biggest single-dial win for warm-cache CPU bound.
6. **Async** — move slow work to queues, reply fast to user.
7. **Scale out** — multiple FPM nodes behind a load balancer (stateless).
8. **DB scale** — read replicas, then partition, then shard.

Each step is a multiplier. 10x throughput is rarely one change.
