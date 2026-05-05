# Laravel Interview Questions and Answers

A pedagogical Q&A guide for full-stack interviews. Each question has a plain-language explanation and a concrete code example. Read it once to understand, read it twice to recall in the room.

---

## 1. Architecture and Lifecycle

## Q1. Walk me through the Laravel request lifecycle.

**Answer:**

A request enters through `public/index.php`, which boots the framework. Laravel resolves the HTTP kernel, runs global middleware, then matches the URL to a route. Route middleware runs, the controller executes, the response goes back through middleware, and the kernel sends it. After the response is sent, terminable middleware can perform cleanup like logging.

```php
// public/index.php (simplified)
$app = require_once __DIR__ . '/../bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);

$response = $kernel->handle(
    $request = Illuminate\Http\Request::capture()
)->send();

$kernel->terminate($request, $response);
```

## Q2. `register` vs `boot` in service providers.

**Answer:**

`register()` is called first across all providers — bind classes into the container here only. Do not access other services. `boot()` runs after every provider has registered, so you can safely use any binding (events, routes, view composers).

```php
public function register(): void
{
    $this->app->singleton(PaymentGateway::class, StripeGateway::class);
}

public function boot(): void
{
    View::composer('layout', LayoutComposer::class);
}
```

## Q3. What's in `bootstrap/app.php` (Laravel 11)?

**Answer:**

Laravel 11 simplifies bootstrapping by configuring the entire app from `bootstrap/app.php`. You wire routes, middleware, exception handling, and providers there instead of separate kernel files.

```php
return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        commands: __DIR__ . '/../routes/console.php',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->web(append: [EnsureUserLogged::class]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->render(fn ($e, $req) => response()->json(['err' => $e->getMessage()], 500));
    })
    ->create();
```

---

## 2. Routing and Controllers

## Q4. Route definition styles.

**Answer:**

Routes can target a Closure, a controller method as `[Controller::class, 'method']`, or an invokable single-action controller. Group routes by prefix, name, middleware, or namespace.

```php
Route::get('/users', [UserController::class, 'index'])->name('users.index');

Route::middleware('auth')->prefix('admin')->group(function () {
    Route::get('/dashboard', DashboardController::class);
    Route::resource('posts', PostController::class);
});
```

## Q5. Route model binding.

**Answer:**

Laravel can resolve a model from a route parameter automatically. Implicit binding maps `{user}` to a `User` instance by primary key. You can customize the column or scope by overriding `getRouteKeyName` or using `Route::scopeBindings`.

```php
// Implicit binding
Route::get('/users/{user}', function (User $user) {
    return $user;
});

// Custom column
class Post extends Model {
    public function getRouteKeyName(): string { return 'slug'; }
}
Route::get('/posts/{post}', fn (Post $post) => $post);

// Scoped binding
Route::get('/users/{user}/posts/{post}', fn (User $user, Post $post) => $post)
    ->scopeBindings();
```

## Q6. Single-action controllers.

**Answer:**

A single-action controller defines `__invoke()`. Use it when a controller's only purpose is one action — keeps file sizes small and intent clear.

```php
class ProcessPaymentController extends Controller
{
    public function __invoke(Request $request, PaymentService $service)
    {
        $service->process($request->validated());
        return response()->json(['ok' => true]);
    }
}

Route::post('/payments', ProcessPaymentController::class);
```

---

## 3. Middleware

## Q7. Middleware basics.

**Answer:**

Middleware filters requests entering or responses leaving the app. Each middleware decides whether to pass control to the next layer. Common uses: authentication, logging, CORS, throttling.

```php
class EnsureTokenIsValid
{
    public function handle(Request $request, Closure $next)
    {
        if ($request->bearerToken() !== config('app.token')) {
            abort(401);
        }
        return $next($request);
    }
}
```

## Q8. `terminate` middleware.

**Answer:**

A `terminate(Request, Response)` method runs after the response has been sent to the client. Useful for slow tasks like logging that should not delay the user.

```php
class LogRequest
{
    public function handle($request, Closure $next) { return $next($request); }

    public function terminate($request, $response): void
    {
        Log::info('hit', ['url' => $request->fullUrl(), 'status' => $response->status()]);
    }
}
```

## Q9. Global vs route vs group middleware.

**Answer:**

Global middleware runs on every request (set in `bootstrap/app.php`). Route middleware runs on a single route. Group middleware applies to a group of routes via prefix or aliases.

```php
// global
$middleware->append(LogRequest::class);

// route
Route::get('/admin', AdminController::class)->middleware('auth');

// group via alias
Route::middleware(['auth', 'admin'])->group(function () { /* ... */ });
```

---

## 4. Service Container

## Q10. What is the service container?

**Answer:**

The service container is a registry that stores how to build classes (bindings) and resolves them when needed. It also performs constructor injection automatically — you ask for a class in your controller, and the container builds and injects it.

```php
public function __construct(private OrderService $orders) {}
// $orders is built and injected automatically
```

## Q11. Binding flavors.

**Answer:**

`bind()` runs the closure every time it resolves. `singleton()` runs once and reuses the instance. `instance()` registers an existing object. `scoped()` is per-request (Octane, jobs).

```php
$this->app->bind(Logger::class, fn () => new FileLogger(storage_path('app.log')));
$this->app->singleton(Cache::class, RedisCache::class);
$this->app->instance('config', $config);
$this->app->scoped(RequestId::class, fn () => new RequestId());
```

## Q12. Contextual binding.

**Answer:**

Different consumers can receive different implementations of the same interface. Useful when one class needs a different configuration of the same dependency.

```php
$this->app
    ->when(VideoController::class)
    ->needs(Filesystem::class)
    ->give(fn () => Storage::disk('videos'));

$this->app
    ->when(PhotoController::class)
    ->needs(Filesystem::class)
    ->give(fn () => Storage::disk('photos'));
```

## Q13. Tagging and resolving collections.

**Answer:**

Tag multiple bindings together so you can resolve them as a group. Useful for plugin systems and notification channels.

```php
$this->app->bind(SlackNotifier::class);
$this->app->bind(EmailNotifier::class);
$this->app->tag([SlackNotifier::class, EmailNotifier::class], 'notifiers');

$notifiers = $this->app->tagged('notifiers');
foreach ($notifiers as $notifier) $notifier->send($message);
```

## Q14. `make` vs `resolve` vs `app()`.

**Answer:**

All three resolve a binding. `app($abstract)` and `resolve($abstract)` are global helpers. `app()->make($abstract, $params)` lets you pass extra parameters. They are functionally equivalent — pick one and stay consistent.

```php
$logger = app(Logger::class);
$logger = resolve(Logger::class);
$logger = app()->make(Logger::class, ['channel' => 'stack']);
```

## Q15. Resolving by interface.

**Answer:**

Bind an interface to a concrete implementation. The container injects the concrete whenever the interface is type-hinted. This makes swapping easy in tests and across environments.

```php
interface PaymentGateway { public function charge(int $cents): string; }

class StripeGateway implements PaymentGateway { /* ... */ }

// AppServiceProvider
$this->app->bind(PaymentGateway::class, StripeGateway::class);

// Anywhere
public function __construct(private PaymentGateway $gateway) {}
```

---

## 5. Service Providers and Facades

## Q16. What is a service provider?

**Answer:**

A service provider is the central place to register bindings and bootstrap services. Laravel discovers them via `bootstrap/providers.php` (Laravel 11) or `config/app.php` and runs `register()` then `boot()` on each.

```php
class PaymentServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(PaymentGateway::class, StripeGateway::class);
    }

    public function boot(): void
    {
        $this->loadRoutesFrom(__DIR__ . '/../routes/payments.php');
    }
}
```

## Q17. Facades — what are they really?

**Answer:**

A facade is a static-looking proxy to a service in the container. Calling `Cache::get(...)` resolves the cache repository from the container, then calls `get` on it. They give terse syntax with full container resolution.

```php
// These two are equivalent
Cache::put('key', 'val', 60);
app('cache')->put('key', 'val', 60);
```

## Q18. Real-time facades.

**Answer:**

You can turn any class into a facade on the fly by prefixing its namespace with `Facades\`. Useful for testing or quick static-style access without writing a facade class.

```php
use Facades\App\Services\PaymentService;

PaymentService::charge($amount);
// equivalent to: app(PaymentService::class)->charge($amount);
```

---

## 6. Eloquent ORM

## Q19. What is Eloquent and the Active Record pattern?

**Answer:**

Eloquent is Laravel's ORM. Each model class maps to a database table. A model instance holds a row's attributes and provides methods to query, save, and relate. This combined data + behavior style is the Active Record pattern.

```php
class User extends Model
{
    protected $fillable = ['name', 'email'];
}

$user = new User(['name' => 'Iqbal', 'email' => 'a@b.com']);
$user->save();

$found = User::where('email', 'a@b.com')->first();
```

## Q20. Mass assignment — `$fillable` vs `$guarded`.

**Answer:**

Mass assignment fills multiple columns from a single array. Without protection, a malicious user could set `is_admin=true`. `$fillable` is an allowlist of columns you accept. `$guarded` is a blocklist. Use `$fillable` because it's explicit.

```php
class User extends Model
{
    protected $fillable = ['name', 'email', 'password'];
}

User::create($request->all());   // safe — only the three columns are mass-assigned
```

## Q21. Relationship types.

**Answer:**

Eloquent supports `hasOne`, `hasMany`, `belongsTo`, `belongsToMany`, `hasManyThrough`, and morph relationships. Each method returns a relationship object that builds the right query.

```php
class User extends Model {
    public function posts() { return $this->hasMany(Post::class); }
    public function profile() { return $this->hasOne(Profile::class); }
    public function roles() { return $this->belongsToMany(Role::class); }
}

class Post extends Model {
    public function author() { return $this->belongsTo(User::class, 'user_id'); }
}
```

## Q22. The N+1 query problem.

**Answer:**

If you fetch many parents and access a related model in a loop, you trigger one query per parent — N+1 total. Solve with eager loading via `with()`, which makes 2 queries total.

```php
// N+1 — one query for users, then one per user's posts
$users = User::all();
foreach ($users as $user) echo $user->posts->count();

// Eager loaded — 2 queries total
$users = User::with('posts')->get();
foreach ($users as $user) echo $user->posts->count();

// Strict mode — surface accidental lazy loading in development
Model::preventLazyLoading(! app()->isProduction());
```

## Q23. Query scopes.

**Answer:**

A scope is a reusable query constraint defined as a method on the model. Local scopes are prefixed with `scope` and chain like other query methods. Global scopes apply automatically to every query.

```php
class Post extends Model
{
    public function scopePublished(Builder $q): Builder
    {
        return $q->where('status', 'published');
    }
}

Post::published()->latest()->take(10)->get();
```

## Q24. Accessors and mutators.

**Answer:**

Accessors transform a value when reading; mutators transform when writing. Modern syntax uses the `Attribute` class — clean, single method per attribute.

```php
use Illuminate\Database\Eloquent\Casts\Attribute;

class User extends Model
{
    protected function name(): Attribute
    {
        return Attribute::make(
            get: fn (string $value) => ucfirst($value),
            set: fn (string $value) => strtolower($value),
        );
    }
}
```

## Q25. Attribute casting.

**Answer:**

Casts convert database columns to typed PHP values automatically — booleans, dates, JSON, enums, custom value objects.

```php
class Post extends Model
{
    protected $casts = [
        'is_published' => 'boolean',
        'meta'         => 'array',
        'published_at' => 'datetime',
        'status'       => Status::class,   // backed enum
    ];
}

$post->meta;            // already an array
$post->published_at;    // Carbon instance
```

## Q26. Polymorphic relations.

**Answer:**

A polymorphic relation lets one model belong to many others through a single foreign key column pair (`*_id` and `*_type`). Common for comments, attachments, and likes.

```php
class Comment extends Model
{
    public function commentable() { return $this->morphTo(); }
}

class Post extends Model
{
    public function comments() { return $this->morphMany(Comment::class, 'commentable'); }
}

class Video extends Model
{
    public function comments() { return $this->morphMany(Comment::class, 'commentable'); }
}
```

## Q27. Has-many-through.

**Answer:**

When two models are connected via a third intermediate table, `hasManyThrough` lets you reach the far model directly.

```php
class Country extends Model
{
    // Country -> User -> Post
    public function posts() { return $this->hasManyThrough(Post::class, User::class); }
}
```

## Q28. Observers and model events.

**Answer:**

Observers listen to model lifecycle events (`creating`, `created`, `updating`, `deleted`). Use them for side effects like sending emails or invalidating cache. Watch out for infinite loops if observers update the same model.

```php
class UserObserver
{
    public function created(User $user): void
    {
        Mail::to($user)->send(new WelcomeEmail($user));
    }
}

// AppServiceProvider
User::observe(UserObserver::class);
```

## Q29. Soft deletes.

**Answer:**

Soft deletes mark a row as deleted without removing it. Use the `SoftDeletes` trait and add a `deleted_at` column. Queries automatically filter out trashed records; restore with `restore()`.

```php
use Illuminate\Database\Eloquent\SoftDeletes;

class Post extends Model {
    use SoftDeletes;
}

$post->delete();         // sets deleted_at
Post::withTrashed()->find($id);
$post->restore();
$post->forceDelete();    // removes permanently
```

## Q30. Eloquent vs Query Builder vs raw.

**Answer:**

Eloquent is highest-level — most ergonomic, slightly more overhead. Query Builder skips models for plain rows. Raw SQL is for complex queries Eloquent cannot express. Use Eloquent for normal CRUD, Query Builder for reports, raw for last-resort cases.

```php
$users = User::where('active', true)->get();        // Eloquent
$users = DB::table('users')->where('active', true)->get();  // Builder
$users = DB::select('SELECT * FROM users WHERE active = ?', [1]);  // raw
```

## Q31. Chunking large datasets.

**Answer:**

Loading millions of rows blows up memory. Chunk processes them in batches. `chunkById` is safer when you mutate the rows during iteration.

```php
User::chunk(500, function ($users) {
    foreach ($users as $user) sendNewsletter($user);
});

User::where('active', true)->chunkById(500, function ($users) {
    foreach ($users as $user) $user->update(['notified' => true]);
});

foreach (User::lazy() as $user) {     // generator
    process($user);
}
```

## Q32. Transactions and deadlocks.

**Answer:**

Wrap related writes in a transaction so they all commit or all roll back. Laravel's `DB::transaction` retries on deadlocks. Keep transactions short and never make HTTP calls inside them.

```php
DB::transaction(function () use ($order) {
    $order->save();
    Inventory::where('product_id', $order->product_id)->decrement('stock');
}, 3);   // retry up to 3 times on deadlock
```

---

## 7. Migrations, Seeders, Factories

## Q33. Migration essentials.

**Answer:**

Migrations are PHP classes that describe schema changes. `up()` applies the change; `down()` reverses it. Run with `php artisan migrate`. Use `Schema::create` for new tables and `Schema::table` for changes.

```php
return new class extends Migration {
    public function up(): void
    {
        Schema::create('posts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->text('body');
            $table->timestamps();
            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void { Schema::dropIfExists('posts'); }
};
```

## Q34. Migration patterns for production.

**Answer:**

Prefer additive migrations: add columns nullable, deploy code, then backfill, then enforce. Avoid renaming columns under load — rename creates a new column and migrates data. Write reversible migrations whenever possible.

```php
public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->string('phone')->nullable()->after('email');
    });
}
```

## Q35. Factories.

**Answer:**

Factories generate fake model data for tests and seeding. Use states for variations.

```php
class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name'  => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'role'  => 'user',
        ];
    }

    public function admin(): static
    {
        return $this->state(['role' => 'admin']);
    }
}

User::factory()->count(10)->create();
User::factory()->admin()->create();
User::factory()->has(Post::factory()->count(3))->create();
```

## Q36. Seeders.

**Answer:**

A seeder populates the database with default or sample data. Run with `php artisan db:seed`. Compose multiple seeders from `DatabaseSeeder`.

```php
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([RoleSeeder::class, UserSeeder::class]);

        User::factory()
            ->count(50)
            ->has(Post::factory()->count(5))
            ->create();
    }
}
```

---

## 8. Validation and Form Requests

## Q37. Form requests.

**Answer:**

Form requests are classes that hold validation and authorization for a single request. They run before the controller method, so the controller only sees clean data.

```php
class StorePostRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Post::class);
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'body'  => ['required', 'string'],
            'tags'  => ['array'],
            'tags.*' => ['string', 'max:50'],
        ];
    }
}

class PostController
{
    public function store(StorePostRequest $request)
    {
        Post::create($request->validated());
    }
}
```

## Q38. Custom validation rules.

**Answer:**

Implement `Illuminate\Contracts\Validation\ValidationRule` for one-off rules. Use closures for very simple rules.

```php
class Uppercase implements ValidationRule
{
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (strtoupper($value) !== $value) {
            $fail('The :attribute must be uppercase.');
        }
    }
}

$request->validate(['code' => ['required', new Uppercase]]);
```

## Q39. Validation gotchas.

**Answer:**

`required` allows empty strings as missing only with caveats — use `present|filled` for nuance. `nullable` lets a value be `null` and skips other rules if so. `sometimes` runs the rule only when the field is present.

```php
$rules = [
    'name'  => ['required', 'string'],
    'phone' => ['nullable', 'regex:/\+?\d+/'],
    'plan'  => ['sometimes', 'in:free,pro'],
];
```

---

## 9. Queues and Jobs

## Q40. Why queues?

**Answer:**

Long-running work (sending email, calling external APIs, generating reports) makes HTTP responses slow. Queues defer that work to background workers, returning quickly to the user. Drivers include database, Redis, and SQS.

```php
// In a controller
SendInvoice::dispatch($order);   // returns immediately
return response()->json(['queued' => true]);
```

## Q41. Defining a job.

**Answer:**

A job is a class that implements `ShouldQueue`. Constructor stores data; `handle()` runs on the worker. Configure tries, timeouts, and backoff via class properties.

```php
class SendInvoice implements ShouldQueue
{
    use Queueable, SerializesModels;

    public int $tries = 3;
    public int $timeout = 60;
    public array $backoff = [10, 30, 60];

    public function __construct(public Order $order) {}

    public function handle(InvoiceMailer $mailer): void
    {
        $mailer->send($this->order);
    }

    public function failed(Throwable $e): void
    {
        Log::error('invoice failed', ['order' => $this->order->id, 'err' => $e->getMessage()]);
    }
}
```

## Q42. Job middleware.

**Answer:**

Job middleware wraps `handle()` with concerns like rate limiting, locking, and skip-if-already-running. Reusable across jobs.

```php
public function middleware(): array
{
    return [
        new WithoutOverlapping($this->order->id),
        new RateLimited('invoices'),
    ];
}
```

## Q43. `dispatchSync` vs `dispatch` vs `dispatchAfterResponse`.

**Answer:**

`dispatch()` sends the job to the queue. `dispatchSync()` runs it immediately in the current process — useful in tests. `dispatchAfterResponse()` runs after the HTTP response is sent to the user, in the same process.

```php
SendEmail::dispatch($user);                  // queued
SendEmail::dispatchSync($user);              // run inline
SendEmail::dispatchAfterResponse($user);     // run after sending response
```

## Q44. Batches and chains.

**Answer:**

A chain runs jobs sequentially — if one fails, later ones don't run. A batch runs jobs in parallel and reports overall progress. Both useful for orchestrating work.

```php
// Chain
Bus::chain([
    new ProcessPayment($order),
    new ShipOrder($order),
    new NotifyUser($order),
])->dispatch();

// Batch
Bus::batch([
    new ImportRow($r1),
    new ImportRow($r2),
])->then(fn (Batch $b) => Log::info('done'))
  ->catch(fn (Batch $b, Throwable $e) => Log::error('failed'))
  ->dispatch();
```

## Q45. Failed jobs.

**Answer:**

When a job exhausts its tries, it goes to the `failed_jobs` table. Inspect with `php artisan queue:failed`, retry with `queue:retry`, prune with `queue:flush`. Implement `failed()` on the job class for custom handling.

```bash
php artisan queue:failed
php artisan queue:retry all
php artisan queue:flush
```

## Q46. Horizon.

**Answer:**

Horizon is a Redis-only queue dashboard with auto-balancing, real-time metrics, and tag-based monitoring. Configure supervisor pools per queue type.

```php
// config/horizon.php
'environments' => [
    'production' => [
        'supervisor-1' => [
            'connection' => 'redis',
            'queue'      => ['high', 'default', 'emails'],
            'maxProcesses' => 10,
            'balance'      => 'auto',
        ],
    ],
],
```

## Q47. Worker hygiene.

**Answer:**

Restart workers after code deploys (`queue:restart`) so they pick up new code. Use `--max-jobs` and `--max-time` flags to recycle workers and combat memory leaks. Use a process supervisor like Supervisord or systemd.

```bash
php artisan queue:work redis --queue=high,default --tries=3 --max-jobs=1000 --max-time=3600
php artisan queue:restart
```

---

## 10. Events, Listeners, Broadcasting

## Q48. Events and listeners.

**Answer:**

Events represent something that happened. Listeners react to events. Decouples senders from receivers — anyone can listen without changing the sender.

```php
class OrderShipped {
    use Dispatchable;
    public function __construct(public Order $order) {}
}

class SendShipmentNotification implements ShouldQueue
{
    public function handle(OrderShipped $event): void
    {
        Mail::to($event->order->user)->send(new ShipmentMail($event->order));
    }
}

OrderShipped::dispatch($order);   // anywhere in code
```

## Q49. Should listeners be queued?

**Answer:**

Queue listeners that are slow or fault-prone (sending email, hitting external APIs). Run synchronously when the work is fast and must complete before the response.

```php
class SendShipmentNotification implements ShouldQueue
{
    public function viaQueue(): string { return 'notifications'; }
}
```

## Q50. Broadcasting overview.

**Answer:**

Broadcasting pushes events from your server to the client over WebSockets (Pusher, Ably, Reverb, Soketi). Implement `ShouldBroadcast`. The frontend uses Echo to subscribe.

```php
class MessageSent implements ShouldBroadcast
{
    public function __construct(public Message $message) {}

    public function broadcastOn(): Channel
    {
        return new PrivateChannel('chat.' . $this->message->room_id);
    }
}
```

```js
// Frontend
Echo.private(`chat.${roomId}`)
    .listen('MessageSent', (e) => append(e.message));
```

---

## 11. Authentication and Authorization

## Q51. Auth options.

**Answer:**

`session` for browser auth (Breeze, Jetstream). `sanctum` for SPAs and lightweight API tokens. `passport` for full OAuth2 server. `JWT` via third-party packages when needed.

```php
// Sanctum cookie auth (SPA)
Route::middleware('auth:sanctum')->get('/me', fn (Request $r) => $r->user());

// Sanctum token auth
$token = $user->createToken('mobile')->plainTextToken;
```

## Q52. Sanctum SPA vs API tokens.

**Answer:**

SPA mode uses cookies + CSRF — first-party single-page apps on the same root domain. Token mode issues bearer tokens for mobile apps and third-party clients. Choose based on who is calling your API.

```php
// SPA: send cookies, hit /sanctum/csrf-cookie first

// Token mode
$token = $user->createToken('iphone', ['posts:read'])->plainTextToken;
// frontend sends: Authorization: Bearer <token>
```

## Q53. Gates and policies.

**Answer:**

Gates are simple closures keyed by name. Policies are classes per model, methods per action. Use policies for model-bound permissions.

```php
// Gate
Gate::define('access-admin', fn (User $u) => $u->is_admin);
if (Gate::allows('access-admin')) { /* ... */ }

// Policy
class PostPolicy
{
    public function update(User $user, Post $post): bool
    {
        return $user->id === $post->user_id;
    }
}

// Usage
$this->authorize('update', $post);
@can('update', $post) <button>Edit</button> @endcan
```

## Q54. Password reset and email verification.

**Answer:**

Laravel ships with built-in flows. Use the `MustVerifyEmail` interface on User and route middleware `verified`. Password reset uses `Password` facade with notifications.

```php
class User extends Authenticatable implements MustVerifyEmail {}

Route::middleware(['auth', 'verified'])->get('/dashboard', DashboardController::class);

Password::sendResetLink(['email' => $email]);
```

---

## 12. API and Resources

## Q55. API resources.

**Answer:**

Resources transform models (or collections) into JSON for API responses. They give you control over field names, hide sensitive fields, and conditionally include data.

```php
class UserResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id'    => $this->id,
            'name'  => $this->name,
            'email' => $this->email,
            'posts' => PostResource::collection($this->whenLoaded('posts')),
            'is_admin' => $this->when($request->user()?->is_admin, true),
        ];
    }
}

return UserResource::collection(User::with('posts')->paginate());
```

## Q56. API versioning.

**Answer:**

Common strategies: URL prefix (`/api/v1`), Accept header, or subdomain. URL versioning is the simplest and most explicit.

```php
Route::prefix('v1')->group(function () {
    Route::apiResource('users', V1\UserController::class);
});

Route::prefix('v2')->group(function () {
    Route::apiResource('users', V2\UserController::class);
});
```

## Q57. Rate limiting.

**Answer:**

Use `RateLimiter` to define named limiters and `throttle:name` middleware. Limits are per key — usually IP or user ID.

```php
// AppServiceProvider boot()
RateLimiter::for('api', fn (Request $r) =>
    Limit::perMinute(60)->by($r->user()?->id ?: $r->ip())
);

Route::middleware('throttle:api')->group(function () {
    Route::get('/posts', [PostController::class, 'index']);
});
```

## Q58. Sanctum token abilities.

**Answer:**

When issuing tokens, you can attach abilities (scopes). Check them in routes with the `abilities` middleware.

```php
$token = $user->createToken('app', ['posts:read', 'posts:write'])->plainTextToken;

Route::middleware(['auth:sanctum', 'abilities:posts:write'])
    ->post('/posts', [PostController::class, 'store']);
```

---

## 13. Caching and Sessions

## Q59. Cache drivers.

**Answer:**

Drivers: `redis` (production), `memcached`, `database` (small apps), `file` (dev), `array` (per-request). Redis is the standard for serious apps.

```php
Cache::put('key', 'value', 300);          // seconds
Cache::remember('users.count', 60, fn () => User::count());

Cache::tags(['users'])->put('user.1', $user, 600);
Cache::tags(['users'])->flush();           // tag flushing — Redis/Memcached only
```

## Q60. Cache stampede mitigation.

**Answer:**

When a popular key expires, many concurrent requests recompute it. Use `Cache::lock` or `Cache::remember` with a lock to dedupe.

```php
$value = Cache::remember('expensive', 600, function () {
    $lock = Cache::lock('expensive-rebuild', 30);
    if ($lock->get()) {
        try {
            return computeExpensive();
        } finally {
            $lock->release();
        }
    }
    sleep(1);
    return Cache::get('expensive');
});
```

## Q61. Sessions.

**Answer:**

Sessions persist user data across requests. Drivers: `database`, `redis`, `file`, `cookie`. Use Redis or database in production for multi-server setups.

```php
session(['user' => $user->toArray()]);
$user = session('user');
session()->forget('user');
session()->flash('status', 'Saved!');     // available next request only
```

---

## 14. Filesystem and Storage

## Q62. Filesystem abstraction.

**Answer:**

Laravel wraps Flysystem so the same API works for local disks, S3, etc. Configure disks in `config/filesystems.php`.

```php
Storage::disk('s3')->put('uploads/' . $name, $contents);
$url = Storage::disk('s3')->temporaryUrl('uploads/' . $name, now()->addMinutes(5));
$ok  = Storage::disk('local')->exists($path);
```

## Q63. File uploads.

**Answer:**

Validate the file, then store with `store()` or `storeAs()`. For public access, use the `public` disk and run `php artisan storage:link`.

```php
public function store(Request $request)
{
    $request->validate(['avatar' => 'required|image|max:2048']);
    $path = $request->file('avatar')->store('avatars', 'public');
    auth()->user()->update(['avatar_path' => $path]);
    return Storage::disk('public')->url($path);
}
```

---

## 15. Mail and Notifications

## Q64. Mailables.

**Answer:**

A Mailable describes one email. Build it with subject, view, and data; send via the `Mail` facade. Mailables can be queued.

```php
class WelcomeMail extends Mailable implements ShouldQueue
{
    public function __construct(public User $user) {}

    public function build()
    {
        return $this->subject('Welcome ' . $this->user->name)
                    ->view('emails.welcome');
    }
}

Mail::to($user)->send(new WelcomeMail($user));
```

## Q65. Notifications.

**Answer:**

Notifications send messages over multiple channels (mail, database, broadcast, SMS). One class supports many channels via `via()`.

```php
class InvoicePaid extends Notification implements ShouldQueue
{
    public function via($notifiable): array { return ['mail', 'database']; }

    public function toMail($notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Invoice paid')
            ->line('Thanks for your payment.');
    }

    public function toArray($notifiable): array
    {
        return ['amount' => $this->amount];
    }
}

$user->notify(new InvoicePaid($amount));
```

---

## 16. Scheduling

## Q66. Task scheduling.

**Answer:**

Define recurring tasks in `routes/console.php` (Laravel 11) or `Console/Kernel.php`. A single cron entry runs `schedule:run` every minute, and Laravel decides which tasks to fire.

```php
// routes/console.php
use Illuminate\Support\Facades\Schedule;

Schedule::command('reports:daily')->dailyAt('02:00')->onOneServer();
Schedule::job(new CleanupOldFiles)->hourly();
Schedule::call(fn () => DB::table('logs')->whereOld()->delete())->weekly();
```

```cron
* * * * * cd /path/to/app && php artisan schedule:run >> /dev/null 2>&1
```

---

## 17. Blade, Inertia, Livewire

## Q67. Blade essentials.

**Answer:**

Blade is Laravel's templating engine. Output `{{ $var }}` is escaped automatically. Directives like `@if`, `@foreach`, `@auth`, `@can` cover common cases. Components and slots build reusable UI.

```blade
{{-- resources/views/post.blade.php --}}
<x-layout :title="$post->title">
    <h1>{{ $post->title }}</h1>
    @auth
        @can('update', $post)
            <a href="{{ route('posts.edit', $post) }}">Edit</a>
        @endcan
    @endauth

    @foreach ($post->comments as $comment)
        <p>{{ $comment->body }}</p>
    @endforeach
</x-layout>
```

## Q68. Inertia vs Livewire.

**Answer:**

Inertia bridges Laravel with Vue/React/Svelte SPAs — server returns props, client renders components, no separate API needed. Livewire renders Blade and uses small Ajax calls to update parts of the page on interactions. Inertia for SPA-like experience; Livewire for interactivity without writing JS.

```php
// Inertia
return Inertia::render('Posts/Index', ['posts' => Post::paginate()]);

// Livewire (v3)
class PostList extends Component
{
    public string $search = '';

    public function render()
    {
        return view('livewire.post-list', [
            'posts' => Post::where('title', 'like', "%{$this->search}%")->get(),
        ]);
    }
}
```

---

## 18. Testing

## Q69. Test setup.

**Answer:**

Tests live in `tests/Feature` (HTTP) and `tests/Unit` (isolated). Use `RefreshDatabase` to reset between tests. Run with `php artisan test`.

```php
use Illuminate\Foundation\Testing\RefreshDatabase;

class PostTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_view_posts(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(3)->create();

        $this->actingAs($user)
             ->get('/posts')
             ->assertOk()
             ->assertSee('Posts');
    }
}
```

## Q70. HTTP testing helpers.

**Answer:**

`get`, `post`, `put`, `delete` simulate HTTP requests. Assertions check status, JSON, redirects, sessions. `actingAs` sets the auth user.

```php
$this->postJson('/api/posts', ['title' => 'Hi', 'body' => 'Body'])
     ->assertStatus(201)
     ->assertJson(['title' => 'Hi'])
     ->assertJsonStructure(['id', 'title', 'created_at']);

$this->assertDatabaseHas('posts', ['title' => 'Hi']);
```

## Q71. Pest vs PHPUnit.

**Answer:**

Pest is a modern wrapper over PHPUnit with cleaner syntax: `it('does X')`, expectations, datasets. Same engine, friendlier API. Many teams use Pest for new projects.

```php
// PHPUnit
public function test_addition(): void {
    $this->assertSame(4, 2 + 2);
}

// Pest
it('adds two numbers', function () {
    expect(2 + 2)->toBe(4);
});
```

## Q72. Browser testing with Dusk.

**Answer:**

Dusk drives a real Chrome via ChromeDriver. Use it for end-to-end UI tests when feature tests are not enough.

```php
$this->browse(function (Browser $browser) {
    $browser->visit('/login')
            ->type('email', 'a@b.com')
            ->type('password', 'secret')
            ->press('Login')
            ->assertPathIs('/dashboard');
});
```

---

## 19. Performance and Octane

## Q73. Common Laravel performance wins.

**Answer:**

Eager-load relationships to fix N+1. Cache config and routes in production (`config:cache`, `route:cache`). Add indexes for queried columns. Use Redis for cache and sessions. Move slow work to queues.

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
php artisan optimize           # all-in-one
```

## Q74. Laravel Octane.

**Answer:**

Octane keeps the app booted between requests using Swoole, RoadRunner, or FrankenPHP. Big speedups but requires care: avoid singletons holding per-request state, watch memory, reset services between requests.

```php
// config/octane.php
'flush' => [
    \App\Services\RequestContext::class,
],

'listeners' => [
    RequestReceived::class => [
        FlushUploadedFiles::class,
    ],
],
```

## Q75. Database performance practices.

**Answer:**

Index columns used in WHERE/JOIN/ORDER. Use covering indexes when possible. Avoid `SELECT *` for big tables. Paginate large lists. Prefer `cursorPaginate` over `paginate` for large datasets — no count query, uses keyset pagination.

```php
$posts = Post::where('status', 'published')
    ->select(['id', 'title', 'published_at'])
    ->cursorPaginate(20);
```

## Q76. Caching Eloquent.

**Answer:**

Wrap expensive queries in `Cache::remember`. Invalidate via observer events. Be careful caching paginated results — keys must include page and filters.

```php
$top = Cache::remember(
    "posts.top.{$category}.page.{$page}",
    600,
    fn () => Post::where('category', $category)
        ->orderByDesc('views')
        ->paginate(20, ['*'], 'page', $page)
);

// Invalidate
class PostObserver
{
    public function saved(Post $post): void
    {
        Cache::forget("posts.top.{$post->category}.page.1");
    }
}
```

---

## 20. Modern Laravel 10/11 and Pitfalls

## Q77. Laravel 11 highlights.

**Answer:**

Slimmer skeleton — fewer files, kernel logic moved to `bootstrap/app.php`. Per-second rate limiting. Health check route. Auto-discovered model casts. Improved queue testing helpers.

```php
// Per-second rate limit
RateLimiter::for('api', fn (Request $r) =>
    Limit::perSecond(10)->by($r->user()?->id ?: $r->ip())
);

// Casts as method (no $casts array needed)
class User extends Model
{
    protected function casts(): array
    {
        return ['email_verified_at' => 'datetime'];
    }
}
```

## Q78. Laravel 10 highlights.

**Answer:**

PHP 8.1+ requirement. Native types in core methods. `Process` facade for shell commands. Pest scaffolding option. Dropped support for several deprecated features.

```php
$result = Process::run('git status');
echo $result->output();
```

## Q79. Common Laravel pitfalls.

**Answer:**

N+1 queries (eager load). Hidden config caches in dev (`php artisan optimize:clear`). `dd()` left in production code. Forgetting `verified` middleware. Storing huge job payloads (queue table grows). Testing without `RefreshDatabase` (state leaks).

```php
// Reset all caches when something feels off
// php artisan optimize:clear
```

## Q80. Architectural patterns in larger Laravel apps.

**Answer:**

Service classes for orchestration (one method per use case). Action classes (single-public-method invokables). Repositories sometimes — but Eloquent often replaces them. Domain-driven folders by feature, not by file type.

```php
final class CreateOrderAction
{
    public function __construct(
        private Inventory $inventory,
        private PaymentGateway $gateway,
    ) {}

    public function execute(User $user, array $items): Order
    {
        return DB::transaction(function () use ($user, $items) {
            $order = Order::create(['user_id' => $user->id]);
            $this->inventory->reserve($items);
            $this->gateway->charge($order->total);
            return $order;
        });
    }
}
```

## Q81. Laravel package development basics.

**Answer:**

Create a new package with composer, register a service provider, publish config and migrations, optionally provide facades.

```php
class GreeterServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->mergeConfigFrom(__DIR__ . '/../config/greeter.php', 'greeter');
        $this->app->singleton('greeter', Greeter::class);
    }

    public function boot(): void
    {
        $this->publishes([
            __DIR__ . '/../config/greeter.php' => config_path('greeter.php'),
        ], 'config');
    }
}
```

## Q82. Designing a queue-backed import.

**Answer:**

Stream the source (CSV/JSON), chunk it, dispatch one job per batch. Use a `Bus::batch` for visibility. Persist progress to a table the user can poll.

```php
class StartImport
{
    public function execute(string $path): string
    {
        $batch = Bus::batch([])
            ->name('import-' . basename($path))
            ->dispatch();

        $reader = SimpleExcelReader::create($path);
        foreach ($reader->getRows()->chunk(500) as $chunk) {
            $batch->add(new ImportRowsJob($chunk->all()));
        }

        return $batch->id;
    }
}
```

## Q83. How would you structure authorization at scale?

**Answer:**

Use policies for model-bound rules. Use gates for global capabilities. Centralize role-permission logic in a service rather than scattering `if`s. For complex tenant-aware rules, use middleware that injects a "scope" object.

```php
class PostPolicy
{
    public function update(User $user, Post $post): bool
    {
        return $user->hasPermission('posts.update')
            && $user->tenant_id === $post->tenant_id;
    }
}

// Controller
$this->authorize('update', $post);
```

## Q84. Debugging slow Laravel apps — your toolbox.

**Answer:**

Telescope and Debugbar in development for query and request inspection. Clockwork for timeline view. `DB::listen` to log queries. Laravel Pulse for production traffic. Profile with Blackfire or Tideways for hot paths.

```php
// Quick query log
DB::listen(function ($query) {
    Log::info($query->sql, ['time' => $query->time]);
});

// Detect lazy loading in dev
Model::preventLazyLoading(! app()->isProduction());
```

## Q85. Difference between `find`, `findOrFail`, `first`, `firstOrFail`.

**Answer:**

`find($id)` returns the model or `null`. `findOrFail($id)` throws `ModelNotFoundException` (becomes 404). `first()` returns the first match or null. `firstOrFail()` throws if no match.

```php
$user = User::find($id);            // ?User
$user = User::findOrFail($id);      // User or 404

$user = User::where('email', $e)->first();
$user = User::where('email', $e)->firstOrFail();
```

## Q86. `firstOrCreate` vs `updateOrCreate`.

**Answer:**

`firstOrCreate` returns an existing record or creates one. `updateOrCreate` finds and updates, or creates if missing. Both atomic in concept, but use a unique index plus a transaction to avoid race conditions in heavy load.

```php
$user = User::firstOrCreate(
    ['email' => $email],
    ['name' => $name, 'role' => 'guest']
);

$user = User::updateOrCreate(
    ['email' => $email],
    ['name' => $name, 'last_seen' => now()]
);
```

## Q87. What is a resource controller?

**Answer:**

`php artisan make:controller PostController --resource` creates a controller with seven REST methods (`index`, `create`, `store`, `show`, `edit`, `update`, `destroy`). Pair with `Route::resource` for clean RESTful routes.

```php
Route::resource('posts', PostController::class);
// produces:
// GET    /posts          posts.index
// GET    /posts/create   posts.create
// POST   /posts          posts.store
// GET    /posts/{post}   posts.show
// GET    /posts/{post}/edit posts.edit
// PUT    /posts/{post}   posts.update
// DELETE /posts/{post}   posts.destroy
```

## Q88. What is `tinker`?

**Answer:**

Tinker is an interactive PHP REPL for your Laravel app. Run `php artisan tinker` and access models, services, and helpers — perfect for quick debugging.

```bash
php artisan tinker
>>> User::count()
>>> User::factory()->create(['email' => 'test@x.com'])
>>> Cache::flush()
```

## Q89. What is `php artisan` and how to make a custom command?

**Answer:**

Artisan is Laravel's CLI. You can write your own commands for cron jobs, maintenance, and utilities.

```php
class CleanOldLogs extends Command
{
    protected $signature = 'logs:clean {days=30}';
    protected $description = 'Delete logs older than N days';

    public function handle(): int
    {
        $days = (int) $this->argument('days');
        $count = Log::where('created_at', '<', now()->subDays($days))->delete();
        $this->info("Deleted {$count} logs.");
        return self::SUCCESS;
    }
}
```

## Q90. What is `withCount` and how does it differ from `with`?

**Answer:**

`with('relation')` eager loads the related models. `withCount('relation')` runs a single subquery to add a `relation_count` column without loading the rows.

```php
$users = User::withCount('posts')->get();
foreach ($users as $u) echo $u->posts_count;

// Combine
$users = User::withCount('posts')->with(['posts' => fn ($q) => $q->latest()->limit(3)])->get();
```
