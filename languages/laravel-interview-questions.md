# Laravel Interview Questions

**Level:** Mid to Senior
**Topics:** Routing, Container, Eloquent, Queues, Events, Auth, Caching, Testing, Performance, Laravel 10/11

---

## Table of Contents

1. [Architecture and Lifecycle](#architecture-and-lifecycle)
2. [Routing and Controllers](#routing-and-controllers)
3. [Middleware](#middleware)
4. [Service Container](#service-container)
5. [Service Providers and Facades](#service-providers-and-facades)
6. [Eloquent ORM](#eloquent-orm)
7. [Migrations, Seeders, Factories](#migrations-seeders-factories)
8. [Validation and Form Requests](#validation-and-form-requests)
9. [Queues and Jobs](#queues-and-jobs)
10. [Events, Listeners, Broadcasting](#events-listeners-broadcasting)
11. [Authentication and Authorization](#authentication-and-authorization)
12. [API and Resources](#api-and-resources)
13. [Caching and Sessions](#caching-and-sessions)
14. [Filesystem and Storage](#filesystem-and-storage)
15. [Mail and Notifications](#mail-and-notifications)
16. [Scheduling](#scheduling)
17. [Blade, Inertia, Livewire](#blade-inertia-livewire)
18. [Testing](#testing)
19. [Performance and Octane](#performance-and-octane)
20. [Modern Laravel 10/11 and Pitfalls](#modern-laravel-1011-and-pitfalls)

---

## Architecture and Lifecycle

### Q1. Walk me through the Laravel request lifecycle.

**Answer:**
1. `public/index.php` boots — Composer autoloader loads.
2. The application instance is built from `bootstrap/app.php`.
3. The HTTP kernel resolves and runs **bootstrappers** (env, config, log, exception handling, facades, providers).
4. Service providers are registered then booted.
5. The request is sent through **global middleware**.
6. Router matches the route, runs route middleware.
7. Controller action executes, returns a response (or model/array auto-converted).
8. Response goes back through middleware (terminating middleware run after send).
9. Kernel sends the response, app terminates.

Knowing this sequence explains where to hook in (provider boot vs register, middleware vs controller, terminating middleware for after-response cleanup).

---

### Q2. `register` vs `boot` in service providers.

**Answer:**
- `register()` — bind things into the container only. **Other providers may not be registered yet** — never use facades or other services here.
- `boot()` — all providers have registered. Safe to use facades, listen for events, define routes, register macros, publish config.

A common bug: calling a facade in `register()` triggers premature resolution and breaks order-sensitive services.

---

### Q3. What's in `bootstrap/app.php` (Laravel 11)?

**Answer:**
Laravel 11 collapsed many config files into a fluent app builder:

```php
return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias(['can' => Authorize::class]);
        $middleware->web(append: [EnsureProfileComplete::class]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->dontReport([SoftException::class]);
    })->create();
```

Replaces `app/Http/Kernel.php`, `app/Console/Kernel.php`, and most of `app/Exceptions/Handler.php`.

---

## Routing and Controllers

### Q4. Route definition styles.

**Answer:**

```php
Route::get('/users', [UserController::class, 'index']);
Route::post('/users', [UserController::class, 'store'])->middleware('auth');
Route::resource('posts', PostController::class);          // 7 RESTful routes
Route::apiResource('posts', PostController::class);       // resource minus create/edit
Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('/dashboard', DashboardController::class);
});
Route::get('/users/{user}', fn(User $user) => $user);     // implicit binding
```

Use `php artisan route:list` to see all routes. Cache routes in production with `php artisan route:cache` (only works with closure-free routes).

---

### Q5. Route model binding.

**Answer:**

```php
Route::get('/users/{user}', fn(User $user) => $user);

// Custom key column:
Route::get('/posts/{post:slug}', fn(Post $post) => $post);

// Customize globally on the model:
public function getRouteKeyName() { return 'slug'; }

// Explicit binding in a service provider:
Route::bind('user', fn($value) => User::active()->findOrFail($value));
```

Auto-resolves the model or returns 404. Use `Route::scopeBindings()` to constrain `/users/{user}/posts/{post}` so the post must belong to the user.

---

### Q6. Single-action controllers.

**Answer:**

```php
class CheckoutController {
  public function __invoke(CheckoutRequest $r) { ... }
}
Route::post('/checkout', CheckoutController::class);
```

One-class-per-action keeps controllers tiny and testable. Combined with form requests and resources, the action becomes 3–5 lines.

---

### Q7. Why does `dispatch` from a controller behave differently in tests?

**Answer:**
Default queue connection in tests is `sync`. Use `Queue::fake()` to capture jobs without executing them:

```php
Queue::fake();
$response = $this->post('/orders');
Queue::assertPushed(ProcessOrder::class);
```

In production, jobs hit Redis/SQS — verify configuration per environment.

---

## Middleware

### Q8. Middleware basics.

**Answer:**

```php
class EnsureFeature {
  public function handle(Request $req, Closure $next, string $flag) {
    if (! Feature::active($flag)) abort(404);
    return $next($req);
  }
}
Route::get('/beta', BetaController::class)->middleware('feature:new-checkout');
```

The `$next` closure is the **next middleware/controller**. Run code before `$next($req)` for "before" logic, after for "after" logic.

---

### Q9. `terminate` middleware.

**Answer:**

```php
public function terminate(Request $req, Response $res) { /* runs after response sent */ }
```

For work that should not delay the response — analytics, audit logs. Note: only runs in FastCGI/FPM (PHP can `fastcgi_finish_request`); on built-in server it is synchronous.

---

### Q10. Global vs route vs group middleware.

**Answer:**

| Type     | Where defined            | Runs                |
|----------|--------------------------|---------------------|
| Global   | `withMiddleware(append:)` | every request      |
| Group    | `web`, `api` arrays       | matching group      |
| Route    | `->middleware()`          | specific route      |
| Aliased  | named alias               | usable as `'name'`  |

Order matters — auth before authorization, throttling early to shed load.

---

## Service Container

### Q11. What is the service container?

**Answer:**
A powerful IoC container that resolves classes and their dependencies. Two main operations:

- **Bind** — register how to build something.
- **Resolve** — ask for an instance, the container constructs it.

Auto-wiring uses constructor type hints to satisfy dependencies — most app classes need no explicit binding.

---

### Q12. Binding flavors.

**Answer:**

```php
// Transient — new instance each time
$this->app->bind(PaymentGateway::class, StripeGateway::class);

// Singleton — same instance throughout request
$this->app->singleton(Cache::class, fn() => new RedisCache(...));

// Existing instance
$this->app->instance('settings', $obj);

// Scoped (Laravel 9+) — singleton per request, reset between requests under Octane
$this->app->scoped(RequestContext::class, fn() => new RequestContext());
```

Under Octane, use `scoped` for per-request services to avoid leaking state.

---

### Q13. Contextual binding.

**Answer:**

```php
$this->app->when(VideoController::class)
          ->needs(Filesystem::class)
          ->give(fn() => Storage::disk('s3'));

$this->app->when(PhotoController::class)
          ->needs(Filesystem::class)
          ->give(fn() => Storage::disk('local'));
```

Different injections for different consumers without polluting the global container.

---

### Q14. Tagging and resolving collections.

**Answer:**

```php
$this->app->bind(StripeReport::class, ...);
$this->app->bind(QuickbooksReport::class, ...);
$this->app->tag([StripeReport::class, QuickbooksReport::class], 'reports');

$this->app->bind(ReportAggregator::class, function ($app) {
  return new ReportAggregator($app->tagged('reports'));
});
```

Useful for plug-in style architecture where many implementations satisfy a role.

---

### Q15. `make` vs `resolve` vs `app()`.

**Answer:**
- `app(ClassName::class)` — global helper to resolve.
- `resolve(ClassName::class)` — same.
- `$this->app->make(ClassName::class, [$primitive])` — pass extra params.
- Constructor injection (preferred) — type-hint and let Laravel auto-wire.

Calling `app()` from inside services (Service Locator pattern) is a code smell; prefer constructor DI for testability.

---

### Q16. Resolving by interface.

**Answer:**

```php
interface PaymentGateway { ... }
class StripeGateway implements PaymentGateway { ... }

// In a provider
$this->app->bind(PaymentGateway::class, StripeGateway::class);

// In a controller
public function __construct(private PaymentGateway $gateway) {}
```

Foundation of testable Laravel code — swap implementations in tests via `$this->app->bind` or `$this->mock(PaymentGateway::class)`.

---

## Service Providers and Facades

### Q17. What is a service provider?

**Answer:**
The bootstrap unit of Laravel — registers bindings, event listeners, view composers, route macros, etc. Listed in `bootstrap/providers.php` (Laravel 11) or `config/app.php`.

Defer expensive providers — implement `DeferrableProvider` and a `provides()` method so they only load when first needed.

---

### Q18. Facades — what are they really?

**Answer:**
Static-looking accessors to container-resolved objects.

```php
Cache::get('key');       // proxies to $app->make('cache')->get('key');
```

Implementation: `Facade::__callStatic` resolves the underlying instance the first time. Real classes; auto-completes with the right IDE plugins.

Trade-off: facades couple call sites to global state; for deeply tested code, prefer DI of `CacheRepository`. Most Laravel teams mix both pragmatically.

---

### Q19. Real-time facades.

**Answer:**

```php
use Facades\App\Services\PaymentGateway;
PaymentGateway::charge(...);   // works without writing a facade class
```

Prefix any class with `Facades\` to get a static accessor at runtime. Niche but handy.

---

## Eloquent ORM

### Q20. Active Record pattern in Eloquent.

**Answer:**
Models map to tables and carry both data and persistence behavior. Conventions:

- Class `App\Models\Order` → table `orders` (snake_case plural).
- Primary key `id`.
- Timestamps `created_at` / `updated_at`.
- Foreign keys `<model>_id` (`user_id`).

Override defaults via `protected $table`, `$primaryKey`, `$timestamps = false`.

---

### Q21. Mass assignment — `$fillable` vs `$guarded`.

**Answer:**

```php
class User extends Model {
  protected $fillable = ['name', 'email'];   // whitelist (recommended)
  // or
  protected $guarded = [];                   // empty = allow all (use only for trusted input)
}
```

`User::create($request->all())` only sets attributes in `$fillable`. Avoid `$guarded = []` paired with raw request input — that's how mass-assignment vulnerabilities happen.

---

### Q22. Relationship types.

**Answer:**

| Relationship             | Method               | Use case                          |
|--------------------------|----------------------|-----------------------------------|
| One-to-One               | `hasOne` / `belongsTo` | user → profile                  |
| One-to-Many              | `hasMany` / `belongsTo`| user → posts                    |
| Many-to-Many             | `belongsToMany`        | users ↔ roles (pivot)            |
| Has-One-Through          | `hasOneThrough`        | mechanic → car → owner          |
| Has-Many-Through         | `hasManyThrough`       | country → users → posts         |
| One-to-One Polymorphic   | `morphOne`             | Order, User → image             |
| One-to-Many Polymorphic  | `morphMany`            | Post, Video → comments          |
| Many-to-Many Polymorphic | `morphToMany`          | Post, Video → tags              |

```php
class User extends Model {
  public function posts() { return $this->hasMany(Post::class); }
  public function roles() { return $this->belongsToMany(Role::class)->withPivot('granted_at'); }
}
```

---

### Q23. The N+1 query problem.

**Answer:**

```php
$users = User::all();
foreach ($users as $u) echo $u->posts->count();   // 1 + N queries
```

Fix by **eager loading**:

```php
$users = User::with('posts')->get();              // 2 queries
$users = User::with(['posts' => fn($q) => $q->where('published', true)])->get();
$users = User::withCount('posts')->get();         // count without loading
$users = User::with('posts.comments')->get();     // nested
```

In development, throw on lazy loads:

```php
Model::preventLazyLoading(! app()->isProduction());
```

This catches N+1 issues before they ship.

---

### Q24. Query scopes.

**Answer:**

```php
class Post extends Model {
  // Local scope
  public function scopePublished(Builder $q): Builder {
    return $q->where('published_at', '<=', now());
  }
  public function scopeOfType(Builder $q, string $type): Builder {
    return $q->where('type', $type);
  }
}

Post::published()->ofType('blog')->latest()->paginate();
```

**Global scopes** apply to every query (e.g., soft deletes use one). Use `withoutGlobalScope` to bypass.

---

### Q25. Accessors and mutators.

**Answer:**

Modern syntax (Laravel 9+):

```php
use Illuminate\Database\Eloquent\Casts\Attribute;

protected function fullName(): Attribute {
  return Attribute::make(
    get: fn($value, $attrs) => "{$attrs['first']} {$attrs['last']}",
    set: fn($value) => ['first' => explode(' ', $value)[0], ...],
  )->shouldCache();
}
```

`shouldCache()` memoizes within the model instance — important when accessor is hit in loops.

---

### Q26. Attribute casting.

**Answer:**

```php
protected $casts = [
  'options' => 'array',
  'is_active' => 'boolean',
  'published_at' => 'datetime',
  'price' => 'decimal:2',
  'status' => Status::class,                // backed enum
  'metadata' => AsArrayObject::class,        // mutable array-like
  'address' => AsValueObject::class.':'.Address::class, // value-object cast (custom)
];
```

Casts are **idempotent** at the boundary — values come out as the cast type, go back to the DB serialized.

---

### Q27. Polymorphic relations.

**Answer:**

```php
class Comment extends Model {
  public function commentable() { return $this->morphTo(); }
}

class Post extends Model {
  public function comments() { return $this->morphMany(Comment::class, 'commentable'); }
}
```

`comments` table has `commentable_id` and `commentable_type`. To avoid leaking class names, register a morph map:

```php
Relation::enforceMorphMap([
  'post' => Post::class,
  'video' => Video::class,
]);
```

This also makes namespace refactors safe — DB stores aliases, not FQCNs.

---

### Q28. Has-many-through.

**Answer:**

```php
class Country extends Model {
  public function posts() {
    return $this->hasManyThrough(Post::class, User::class);
    // Country -> Users -> Posts (via users.country_id, posts.user_id)
  }
}
```

Skips the intermediate model in queries. Useful for read paths; for writes, go through the intermediate model.

---

### Q29. Observers and model events.

**Answer:**

```php
class UserObserver {
  public function creating(User $u) { $u->id = (string) Str::uuid(); }
  public function created(User $u)  { $this->mailer->welcome($u); }
}

User::observe(UserObserver::class);
```

Available events: `retrieved`, `creating`, `created`, `updating`, `updated`, `saving`, `saved`, `deleting`, `deleted`, `restoring`, `restored`, `replicating`, `forceDeleted`.

Caveat: events do **not fire** on bulk operations (`Model::query()->update(...)`). Use `chunkById` + `save()` if you need them.

---

### Q30. Soft deletes.

**Answer:**

```php
use Illuminate\Database\Eloquent\SoftDeletes;
class Post extends Model { use SoftDeletes; }
```

Adds `deleted_at` column. `delete()` sets the timestamp, `forceDelete()` removes the row, `restore()` clears the timestamp. A global scope hides soft-deleted rows; bypass with `withTrashed()` or `onlyTrashed()`.

---

### Q31. Eloquent vs Query Builder vs raw.

**Answer:**

| Layer        | When to use                       |
|--------------|-----------------------------------|
| Eloquent     | CRUD, relations, business logic   |
| Query Builder (`DB::table`) | reports, joins, performance-critical reads |
| Raw (`DB::select`) | DB-specific features, complex CTEs |

Use the lowest level needed. For dashboards aggregating millions of rows, the Query Builder or raw SQL is often clearer and faster than hydrating models.

---

### Q32. Chunking large datasets.

**Answer:**

```php
User::where('active', true)->chunkById(1000, function ($users) {
  foreach ($users as $u) process($u);
});

User::lazy()->each(fn($u) => process($u));            // generator-based
User::cursor()->each(fn($u) => process($u));          // streams via PDO cursor
```

Prefer `chunkById` over `chunk` — `chunk` re-runs LIMIT/OFFSET, which can skip rows when records are deleted/inserted mid-iteration.

---

### Q33. Transactions and deadlocks.

**Answer:**

```php
DB::transaction(function () {
  $order = Order::create($data);
  $order->items()->createMany($items);
  Inventory::lockForUpdate()->where('sku', $sku)->decrement('qty');
}, attempts: 3);   // retries on deadlock
```

`lockForUpdate` (`SELECT ... FOR UPDATE`) prevents concurrent updates. `sharedLock` for read locks. Always order locks consistently across transactions to avoid deadlocks.

---

## Migrations, Seeders, Factories

### Q34. Migration essentials.

**Answer:**

```php
public function up(): void {
  Schema::create('orders', function (Blueprint $t) {
    $t->id();
    $t->foreignId('user_id')->constrained()->cascadeOnDelete();
    $t->string('reference')->unique();
    $t->decimal('total', 12, 2);
    $t->json('metadata')->nullable();
    $t->timestamps();
    $t->index(['user_id', 'created_at']);
  });
}
```

Migrations should be **idempotent in spirit** but Laravel tracks them in `migrations` table. Never edit a shipped migration — write a new one.

---

### Q35. Migration patterns for production.

**Answer:**
- Add columns nullable first; backfill in a separate migration; then add NOT NULL.
- Avoid renaming columns/tables in busy systems; deploy in two stages with both names.
- Beware `dropColumn` on SQLite (limited support).
- Don't put data manipulation in schema migrations on huge tables — use a queued backfill job.

---

### Q36. Factories.

**Answer:**

```php
class UserFactory extends Factory {
  public function definition(): array {
    return [
      'name' => fake()->name(),
      'email' => fake()->unique()->safeEmail(),
      'password' => bcrypt('password'),
    ];
  }

  public function admin(): static {
    return $this->state(['role' => 'admin']);
  }
}

User::factory()->count(10)->admin()->has(Post::factory()->count(3))->create();
```

States compose; `has()` and `for()` create related records. Essential for tests and seeding.

---

### Q37. Seeders.

**Answer:**

```php
class DatabaseSeeder extends Seeder {
  public function run(): void {
    $this->call([RoleSeeder::class, AdminUserSeeder::class]);
    User::factory(50)->create();
  }
}
// php artisan db:seed
// php artisan migrate:fresh --seed
```

Idempotent seeders use `firstOrCreate` / `updateOrCreate`. Keep seeders small — heavy data via factories.

---

## Validation and Form Requests

### Q38. Form requests.

**Answer:**

```php
class StoreOrderRequest extends FormRequest {
  public function authorize(): bool {
    return $this->user()->can('create', Order::class);
  }
  public function rules(): array {
    return [
      'items' => ['required', 'array', 'min:1'],
      'items.*.sku' => ['required', 'exists:products,sku'],
      'items.*.qty' => ['required', 'integer', 'min:1'],
      'shipping' => ['required', new ValidShippingMethod],
    ];
  }
  protected function prepareForValidation(): void {
    $this->merge(['reference' => Str::upper($this->reference ?? '')]);
  }
}
```

Inject in the controller — validation runs before the action; failures auto-return 422 (JSON) or redirect (web).

---

### Q39. Custom validation rules.

**Answer:**

Single-method invokable rule (Laravel 10+):

```php
class IsbnRule implements ValidationRule {
  public function validate(string $attr, mixed $value, Closure $fail): void {
    if (! $this->isValidIsbn($value)) $fail("The {$attr} is not a valid ISBN.");
  }
}
```

Use closures for one-off checks. Use `Rule::*` builders for compound rules (`Rule::unique()->ignore($id)`).

---

### Q40. Validation gotchas.

**Answer:**
- `sometimes:rules` runs only if the field is present.
- `nullable` allows `null` to bypass other rules; `present` requires the key (any value, including null).
- Array rules: `'tags' => 'array'`, `'tags.*' => 'string'`.
- Converting empty strings to null: enable `ConvertEmptyStringsToNull` middleware (default).
- Custom messages live in `messages()` or `lang/*/validation.php`.

---

## Queues and Jobs

### Q41. Why queues?

**Answer:**
Move slow work (email, notifications, exports, third-party APIs) out of the request cycle. Improves response time, lets you control concurrency, and adds retry semantics.

Connections: `sync` (in-process), `database`, `redis`, `sqs`, `beanstalkd`. Redis is the most common production choice.

---

### Q42. Defining a job.

**Answer:**

```php
class SendInvoice implements ShouldQueue {
  use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

  public int $tries = 3;
  public int $backoff = 30;       // or array for progressive: [30, 60, 120]
  public int $timeout = 60;
  public int $maxExceptions = 2;

  public function __construct(public Order $order) {}

  public function handle(InvoicePdf $pdf, Mailer $mailer): void {
    $mailer->send(new InvoiceMail($this->order, $pdf->render($this->order)));
  }

  public function failed(Throwable $e): void { /* notify ops */ }
}

SendInvoice::dispatch($order)->onQueue('mail')->delay(now()->addMinutes(5));
```

`SerializesModels` stores model identifiers, not data — re-fetched on execution to avoid stale state.

---

### Q43. Job middleware.

**Answer:**

```php
public function middleware(): array {
  return [
    new RateLimited('reports'),
    (new WithoutOverlapping($this->order->id))->expireAfter(120)->dontRelease(),
    new ThrottlesExceptions(10, 5),
  ];
}
```

Solves common issues at the framework level: rate limit per resource, prevent two workers running same job, throttle when downstream is failing.

---

### Q44. `dispatchSync` vs `dispatch` vs `dispatchAfterResponse`.

**Answer:**
- `dispatch` — queues for later.
- `dispatchSync` — runs immediately in the same process (still goes through pipeline).
- `dispatchAfterResponse` — runs after HTTP response is sent (no queue worker needed; doesn't block the user).

Use `afterResponse` for fire-and-forget work like analytics where you don't need durability.

---

### Q45. Batches and chains.

**Answer:**

```php
Bus::chain([
  new ProcessPodcast($podcast),
  new OptimizePodcast($podcast),
  new ReleasePodcast($podcast),
])->dispatch();   // sequential, stops on failure

Bus::batch([
  new ImportCsvChunk($file, 0),
  new ImportCsvChunk($file, 1),
])
  ->name('csv import')
  ->onQueue('imports')
  ->then(fn (Batch $b) => Notifications::send('Done!'))
  ->catch(fn (Batch $b, Throwable $e) => log($e))
  ->finally(fn (Batch $b) => cleanup())
  ->dispatch();   // parallel
```

Track progress via `Bus::findBatch($id)`.

---

### Q46. Failed jobs.

**Answer:**

```bash
php artisan queue:failed
php artisan queue:retry all
php artisan queue:flush
```

Tune `tries`, `backoff`, and `failed()` callback. Configure a `failed_jobs` table or DLQ. Send alerts on `Queue::failing(...)` events. Most production issues with queues come from missing alerting, not the framework.

---

### Q47. Horizon.

**Answer:**
A dashboard and supervisor for Redis queues. Configures workers per queue with auto-balancing, exposes metrics, lists failed jobs, allows pause/restart.

```php
'environments' => [
  'production' => [
    'supervisor-1' => [
      'connection' => 'redis',
      'queue' => ['high', 'default', 'low'],
      'balance' => 'auto',
      'maxProcesses' => 20,
      'tries' => 3,
    ],
  ],
],
```

The balancing strategies (`simple`, `auto`, `false`) affect how processes are distributed among queues — `auto` adapts to load.

---

### Q48. Worker hygiene.

**Answer:**
- Restart workers on deploys (`php artisan queue:restart`) — workers cache classes.
- Limit memory: `--memory=128`. The supervisor restarts on OOM.
- Set `--timeout` lower than your queue driver's visibility timeout.
- Use `--max-jobs` and `--max-time` so workers self-terminate periodically (mitigates leaks).
- For long-running jobs, prefer chunking and re-dispatching.

---

## Events, Listeners, Broadcasting

### Q49. Events and listeners.

**Answer:**

```php
class OrderPlaced { public function __construct(public Order $order) {} }

class SendOrderConfirmation implements ShouldQueue {
  public function handle(OrderPlaced $event): void { ... }
}

// Auto-discovery (default in Laravel 11) wires them via attribute or convention.
event(new OrderPlaced($order));
```

Events decouple producers from consumers. Implement `ShouldQueue` on listeners for async handling. Use **listeners** for side effects, **observers** for model lifecycle.

---

### Q50. Should listeners be queued?

**Answer:**
Yes for anything I/O bound (email, HTTP, slow DB). No for in-process synchronous logic that the caller depends on. Mixing both within one event is fine — each listener can independently implement `ShouldQueue`.

---

### Q51. Broadcasting overview.

**Answer:**
Push events to the browser via WebSockets/Server-Sent Events. Drivers: Pusher, Ably, Reverb (Laravel 11 self-hosted), log (dev).

```php
class OrderPlaced implements ShouldBroadcast {
  public function broadcastOn(): Channel { return new PrivateChannel("user.{$this->userId}"); }
  public function broadcastAs(): string { return 'order.placed'; }
}
```

Authorize private channels in `routes/channels.php`. Use Laravel Echo on the client.

---

## Authentication and Authorization

### Q52. Auth options.

**Answer:**

| Tool       | Use case                                   |
|------------|--------------------------------------------|
| Breeze     | minimal Blade/Inertia/Livewire scaffolding |
| Jetstream  | richer scaffolding, teams, 2FA             |
| Fortify    | headless backend (no UI)                   |
| Sanctum    | SPA + simple API tokens                    |
| Passport   | full OAuth2 server                         |
| Socialite  | OAuth client (login with Google etc.)      |

Sanctum is the default API auth for most modern apps. Reach for Passport only if you need OAuth2 flows (issuing tokens to third parties).

---

### Q53. Sanctum SPA vs API tokens.

**Answer:**
- **API tokens** — `$user->createToken('name')->plainTextToken`, sent as `Authorization: Bearer ...`. Stateless, suits mobile apps and machine clients.
- **SPA mode** — uses the session cookie + CSRF token; same-origin SPA hits `/sanctum/csrf-cookie` then logs in. No token shipped to the browser.

Don't mix — pick the model per consumer.

---

### Q54. Gates and policies.

**Answer:**

```php
// Gate (closure-based)
Gate::define('access-admin', fn(User $u) => $u->is_admin);

// Policy (class-based, model-bound)
class PostPolicy {
  public function update(User $u, Post $p): bool { return $u->id === $p->user_id; }
}

// Usage
$this->authorize('update', $post);   // throws 403 on fail
$user->can('update', $post);          // bool
@can('update', $post) ... @endcan     // Blade

// In API responses
abort_unless($user->can('update', $post), 403);
```

Policies auto-resolve by model class. Gates for non-model checks. Use `before()` in a policy to short-circuit super-admin logic.

---

### Q55. Password reset and email verification.

**Answer:**
Built-in via Fortify/Breeze:
- `MustVerifyEmail` interface on the User triggers verification flow.
- `ResetPasswordController` and notifications come ready-made.
- Customize via configuration and notification overrides — don't hand-roll.

---

## API and Resources

### Q56. API resources.

**Answer:**

```php
class UserResource extends JsonResource {
  public function toArray($req): array {
    return [
      'id' => $this->id,
      'name' => $this->name,
      'email' => $this->when($req->user()?->is_admin, $this->email),
      'posts' => PostResource::collection($this->whenLoaded('posts')),
      'meta' => $this->whenAppended('full_name', fn() => $this->full_name),
    ];
  }
}

return UserResource::collection(User::with('posts')->paginate());
```

`whenLoaded` avoids triggering N+1 by checking if relation was eager-loaded. Resources keep API contract decoupled from DB schema.

---

### Q57. API versioning.

**Answer:**
Common patterns:

- URL prefix: `/api/v1/users`, `/api/v2/users` (most readable).
- Header: `Accept: application/vnd.app.v2+json`.
- Subdomain: `v2.api.example.com`.

Group routes per version and own resource classes per version. Never silently change v1 — make a v2.

---

### Q58. Rate limiting.

**Answer:**

```php
RateLimiter::for('api', fn(Request $r) =>
  Limit::perMinute(60)->by($r->user()?->id ?: $r->ip()));

Route::middleware('throttle:api')->group(...);
```

Customize `for` per route. For burst handling use `perMinute(...)->response(...)` to send a custom 429 response.

---

### Q59. Sanctum token abilities.

**Answer:**

```php
$token = $user->createToken('mobile', ['posts:read', 'posts:write']);

Route::middleware('auth:sanctum')->group(function () {
  Route::get('/posts', ...)->middleware('ability:posts:read');
});
```

Coarse RBAC at the token level — useful for delegated machine access. Combine with policies for finer authorization.

---

## Caching and Sessions

### Q60. Cache drivers.

**Answer:**

| Driver     | Use case                          |
|------------|-----------------------------------|
| `array`    | tests, in-process only            |
| `file`     | dev, single server                |
| `database` | small scale, no extra infra       |
| `redis`    | production (recommended)          |
| `memcached`| production, simpler than Redis    |
| `dynamodb` | serverless (multi-region session) |

`Cache::remember('key', 300, fn() => User::active()->count())` is the bread-and-butter pattern.

---

### Q61. Cache tags.

**Answer:**

```php
Cache::tags(['posts', 'users'])->put('post:42', $post, 600);
Cache::tags(['posts'])->flush();   // invalidate everything tagged posts
```

Only supported on tagged stores (Redis, Memcached). Powerful but watch invalidation cost — flushing a hot tag can cause stampedes.

---

### Q62. Cache stampede mitigation.

**Answer:**
- `Cache::remember` with random TTL jitter to spread expirations.
- `Cache::lock($key)` to serialize cold-start computation:

```php
$value = Cache::lock("compute:$key", 10)->block(5, function () use ($key) {
  return Cache::remember($key, 600, fn() => expensive());
});
```

Or use a "stale-while-revalidate" pattern: serve stale value, refresh in a job.

---

### Q63. Sessions.

**Answer:**
Driver options mirror the cache (file, cookie, database, redis, dynamodb). For multi-server deployments use Redis or DB. For SPAs use Sanctum cookie sessions; for stateless APIs avoid sessions entirely.

---

## Filesystem and Storage

### Q64. Filesystem abstraction.

**Answer:**

```php
Storage::disk('s3')->put($path, $content);
$url = Storage::disk('s3')->temporaryUrl($path, now()->addMinutes(5));
$stream = Storage::disk('s3')->readStream($path);
```

Same API for local, S3, GCS, FTP, in-memory. Backed by Flysystem. Configure disks in `config/filesystems.php`. Use `temporaryUrl` for signed downloads instead of proxying through PHP.

---

### Q65. File uploads.

**Answer:**

```php
$path = $request->file('avatar')->store('avatars', 's3');
$path = $request->file('avatar')->storeAs('avatars', "{$user->id}.png", 's3');
```

Validate with rules: `'avatar' => ['required', 'image', 'max:2048', 'mimes:png,jpg']`. Use `dimensions:` for image sizing.

---

## Mail and Notifications

### Q66. Mailables.

**Answer:**

```php
class OrderShipped extends Mailable {
  public function __construct(public Order $order) {}
  public function envelope(): Envelope { return new Envelope(subject: 'Your order has shipped'); }
  public function content(): Content { return new Content(markdown: 'mail.orders.shipped'); }
  public function attachments(): array { return [Attachment::fromStorage($this->order->invoicePath)]; }
}

Mail::to($user)->queue(new OrderShipped($order));
```

Use `queue` not `send` for any production user-facing email — synchronous SMTP is a request killer.

---

### Q67. Notifications.

**Answer:**
Single class can deliver to many channels (mail, database, Slack, SMS, broadcast):

```php
class OrderShipped extends Notification implements ShouldQueue {
  public function via($notifiable): array { return ['mail', 'database', 'slack']; }
  public function toMail($n) { ... }
  public function toArray($n) { return ['order_id' => $this->order->id]; }
  public function toSlack($n) { ... }
}
$user->notify(new OrderShipped($order));
```

Notifications routing per channel via `routeNotificationFor*` on the Notifiable.

---

## Scheduling

### Q68. Task scheduling.

**Answer:**
Single cron entry: `* * * * * cd /path && php artisan schedule:run >> /dev/null 2>&1`.

Define schedule in `routes/console.php` (Laravel 11) or `app/Console/Kernel.php`:

```php
Schedule::command('reports:nightly')->dailyAt('02:00')->onOneServer();
Schedule::call(fn() => Cache::forget('stats'))->everyFifteenMinutes();
Schedule::job(new SyncSubscribers)->hourly()->withoutOverlapping();
```

Important modifiers:
- `onOneServer()` — multi-server safe (requires cache lock).
- `withoutOverlapping()` — skip if previous still running.
- `runInBackground()` — don't block subsequent scheduled tasks.
- `evenInMaintenanceMode()` — run during deploys.

---

## Blade, Inertia, Livewire

### Q69. Blade essentials.

**Answer:**

```blade
@extends('layouts.app')

@section('content')
  @foreach ($users as $user)
    <p>{{ $user->name }}</p>     {{-- escaped --}}
    {!! $user->bio_html !!}      {{-- raw — only for trusted HTML --}}
  @endforeach

  @auth
    Welcome, {{ Auth::user()->name }}
  @endauth

  <x-alert type="error" :message="$msg" />
@endsection
```

Components (`x-`) are the modern reusable unit. Inline view models with `@props`, anonymous components in `resources/views/components/`.

---

### Q70. Inertia vs Livewire.

**Answer:**

| Aspect           | Inertia                                  | Livewire                       |
|------------------|------------------------------------------|--------------------------------|
| Frontend         | React/Vue/Svelte                         | Blade + tiny JS runtime        |
| Mental model     | classic SPA, server-side routing         | server-rendered components, server round-trips on interactions |
| State location   | client                                   | server                         |
| Best for         | rich client-side UX, existing JS skills  | Laravel teams not wanting JS heavy lifting |
| Real-time-ish    | manual                                   | reactive props out of the box  |

Both share the same backend — controllers/policies/queues are identical.

---

## Testing

### Q71. Test setup.

**Answer:**

```php
class OrderTest extends TestCase {
  use RefreshDatabase;     // wraps each test in a transaction; rolls back

  public function test_user_can_place_order(): void {
    $user = User::factory()->create();
    $product = Product::factory()->create(['stock' => 10]);

    $response = $this->actingAs($user)->postJson('/api/orders', [
      'items' => [['product_id' => $product->id, 'qty' => 2]],
    ]);

    $response->assertStatus(201)->assertJsonPath('data.total', 200);
    $this->assertDatabaseHas('orders', ['user_id' => $user->id]);
  }
}
```

`RefreshDatabase` uses transactions where the DB supports them — far faster than re-migrating.

---

### Q72. HTTP testing helpers.

**Answer:**

```php
$this->postJson('/api/x', $data, $headers)
     ->assertOk()
     ->assertJson(fn (AssertableJson $json) =>
       $json->where('id', 1)
            ->whereType('created_at', 'string')
            ->has('items', 3)
            ->etc()
     );

$this->withoutMiddleware(VerifyCsrfToken::class);
$this->freezeTime();
```

Fake services: `Storage::fake('s3')`, `Mail::fake()`, `Notification::fake()`, `Bus::fake()`, `Queue::fake()`, `Event::fake()`, `Http::fake()`.

---

### Q73. Pest vs PHPUnit.

**Answer:**
Pest is a layer on top of PHPUnit with a more concise DSL:

```php
it('places an order', function () {
  $user = User::factory()->create();
  actingAs($user)
    ->postJson('/api/orders', [...])
    ->assertCreated();
})->group('orders');
```

Same engine; choose by team preference. Pest's `dataset()` and architecture tests are the standout features.

---

### Q74. Browser testing with Dusk.

**Answer:**

```php
$this->browse(function (Browser $b) {
  $b->visit('/login')
    ->type('email', 'a@b.com')
    ->type('password', 'secret')
    ->press('Login')
    ->assertPathIs('/dashboard');
});
```

Real Chrome via WebDriver. Slow — keep these to critical user flows; use HTTP tests for everything else.

---

## Performance and Octane

### Q75. Common Laravel performance wins.

**Answer:**
- Eager-load relations (`with`); detect N+1 with `Model::preventLazyLoading`.
- Cache config and routes in production: `config:cache`, `route:cache`, `view:cache`, `event:cache`.
- Optimize Composer autoload: `composer install --optimize-autoloader --no-dev`.
- Switch session/cache to Redis.
- Use queued listeners for slow side effects.
- Add DB indexes for filter/sort columns.
- Paginate or chunk large reads.
- Octane for true persistent runtime.

---

### Q76. Laravel Octane.

**Answer:**
Runs Laravel on Swoole, RoadRunner, or FrankenPHP — application stays in memory between requests.

Benefits:
- 5–10× throughput.
- Shared in-memory caches (`Octane::tick`, `Octane::table`).
- Concurrent tasks (`Octane::concurrently`).

Hazards:
- Memory leaks accumulate.
- Static state and singletons leak between requests.
- Service providers' `boot` runs once, not per request.

Use container `scoped` bindings, listen to `RequestReceived`/`RequestTerminated`, and avoid module-level mutable state.

---

### Q77. Database performance practices.

**Answer:**
- Composite indexes ordered by selectivity matching query patterns.
- Use `select()` to avoid loading unused columns.
- Avoid `latest()->first()` on huge tables without an indexed `created_at`.
- `whereIn` with millions of values is slow — chunk or use temp tables.
- Use a read replica for heavy reports (`DB::connection('reports')`).
- Profile with Laravel Telescope or Debugbar in dev; APM (Datadog, New Relic) in prod.

---

### Q78. Caching Eloquent.

**Answer:**

```php
$user = Cache::remember("user:$id", 600, fn() => User::with('roles')->find($id));
```

Be careful with cached relations — invalidate on model events:

```php
User::updated(fn($u) => Cache::forget("user:$u->id"));
```

Packages like `laravel-model-caching` automate this but add complexity. For most apps, hand-rolled caching of expensive aggregates is enough.

---

### Q79. Why does production sometimes behave differently from local?

**Answer:**
Common causes:
- Config/route/view cache out of sync (`php artisan optimize:clear`).
- `APP_ENV`, `APP_DEBUG` differences expose caching/error pages.
- Different queue driver (sync locally, redis in prod).
- File permissions on `storage/` and `bootstrap/cache/`.
- Different PHP versions or extensions.
- Reverse proxies — trust them via `TrustProxies` middleware so `request()->ip()` works correctly.

---

## Modern Laravel 10/11 and Pitfalls

### Q80. Laravel 11 highlights.

**Answer:**
- Slimmer skeleton — no `Http/Kernel.php`, `Console/Kernel.php`, `Exceptions/Handler.php`.
- `bootstrap/app.php` configures middleware, exceptions, routing fluently.
- Per-second rate limiting (`Limit::perSecond`).
- Health endpoint (`/up`) out of the box.
- Easier API auth scaffolding (`php artisan install:api`).
- Reverb (first-party WebSocket server) replaces external broadcasters for self-hosted.
- Default DB driver SQLite for new projects.
- Eager loading by default behavior tweaks (`Model::automaticallyEagerLoadRelationships`).

---

### Q81. Laravel 10 highlights.

**Answer:**
- Native types throughout the framework (drops doc-block hints).
- Process facade for shell commands.
- Pest tests scaffolded by default option.
- Invokable validation rules became the standard.

---

### Q82. Common Laravel pitfalls.

**Answer:**
- N+1 queries — biggest perf killer; use `with`.
- Relying on facades inside service provider `register()` — race condition.
- Models in queued jobs serialized by ID; if deleted before processing, job fails.
- `where('a', '=', null)` — must use `whereNull`. (Eloquent translates to `IS NULL`.)
- Soft deletes hidden by global scope; `withTrashed()` to include.
- Mass-assigning `$request->all()` with `$guarded = []` — vulnerability.
- Calling `count()` on an unindexed column in a hot path.
- Forgetting to restart workers and Octane after deploys.
- Trusting `$request->user()` in jobs — the user may have been deleted.
- Middleware order — auth before throttle vs after has security implications.

---

### Q83. Architectural patterns in larger Laravel apps.

**Answer:**
- **Service classes** for business logic, controllers stay thin.
- **Action classes** (single `handle` method) for use cases.
- **Form requests** for validation + authorization.
- **Resources** for response shaping.
- **DTOs/Value Objects** to type data flow.
- **Repositories** — debated; usually unnecessary for Eloquent, useful when you mix multiple data sources.
- **Domain events** to decouple modules.

Avoid premature DDD layering on small apps — Laravel's defaults scale well to mid-size systems.

---

### Q84. Laravel package development basics.

**Answer:**
Structure:

```
acme/widgets
├── composer.json    (psr-4 autoload, requires)
├── src/
│   ├── WidgetsServiceProvider.php
│   ├── Widget.php
│   └── Facades/Widget.php
├── config/widgets.php
├── routes/widgets.php
├── resources/views/
└── database/migrations/
```

In `WidgetsServiceProvider::boot`:

```php
$this->loadRoutesFrom(__DIR__.'/../routes/widgets.php');
$this->loadViewsFrom(__DIR__.'/../resources/views', 'widgets');
$this->loadMigrationsFrom(__DIR__.'/../database/migrations');
$this->publishes([__DIR__.'/../config/widgets.php' => config_path('widgets.php')], 'config');
```

Auto-discover by `composer.json`'s `extra.laravel.providers` array.

---

### Q85. Real interview scenario — design a queue-backed import.

**Answer:**
Outline:

1. HTTP endpoint accepts the file, validates, stores it on S3, dispatches a `StartImportJob`.
2. `StartImportJob` reads the file with a generator, splits into chunks, dispatches a batch of `ImportChunkJob`s.
3. Each `ImportChunkJob` validates rows, upserts via `Model::upsert` (single SQL), records errors to a sibling table, uses `WithoutOverlapping` and `RateLimited` middleware to be gentle on third-party APIs.
4. Batch `then`/`catch`/`finally` hooks notify the user, update import status, clean up the file.
5. Idempotency — chunk jobs keyed by file hash + chunk index.
6. Observability — track progress via `Bus::findBatch`, log structured events, expose status via API.
7. Tests — `Bus::fake()` for the start job; integration test for the chunk job with a small fixture.

This kind of question tests breadth: queues, batches, idempotency, error handling, UX, monitoring.

---

### Q86. How would you structure authorization at scale?

**Answer:**
- Policies bound per Eloquent model.
- Gates for cross-cutting capabilities (`access-admin`, `manage-billing`).
- Roles + permissions package (`spatie/laravel-permission`) for dynamic configuration.
- Sanctum token abilities for machine clients.
- Centralize complex authorization in dedicated services if logic spans multiple models.
- Always test policies in isolation — easy to misalign with controllers.

Pattern: in API controllers, `$this->authorize('action', $model)` early; in queues, re-check inside the job (the user state may have changed since dispatch).

---

### Q87. Debugging slow Laravel apps — your toolbox.

**Answer:**
- **Telescope** in non-prod: queries, jobs, events, requests with timing.
- **Debugbar** for local dev page-level metrics.
- **Clockwork** as alternative.
- **Database `DB::listen`** to log every query.
- **Octane / Horizon** dashboards for runtime metrics.
- **APM** (Datadog, New Relic, Sentry Performance) for production traces.
- **`Model::preventLazyLoading`** to surface N+1.
- **`stopOnSlowQueries(...)`** in tests to fail on regressions.
- Compare DB query plans (`EXPLAIN`) against indexes.

Always measure before optimizing — Laravel's perceived slowness is often a single missing index or N+1 loop.

---
