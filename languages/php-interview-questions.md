# PHP Interview Questions

**Level:** Mid to Senior
**Topics:** PHP 8.x, OOP, Modern Features, Performance, Security, Composer, PSR

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Types and Type Juggling](#types-and-type-juggling)
3. [Modern PHP 8.x Features](#modern-php-8x-features)
4. [OOP](#oop)
5. [Errors and Exceptions](#errors-and-exceptions)
6. [Closures, Generators, References](#closures-generators-references)
7. [Namespaces, Autoloading, Composer](#namespaces-autoloading-composer)
8. [Web Layer](#web-layer)
9. [Security](#security)
10. [Performance and Runtime](#performance-and-runtime)
11. [Standards and Testing](#standards-and-testing)

---

## Fundamentals

### Q1. What is PHP and how does it run?

**Answer:**
A server-side, dynamically-typed language designed for web. Common runtimes:

- **PHP-FPM** behind nginx/Apache — process pool, request-per-process model.
- **Apache mod_php** — embedded in the web server (legacy).
- **CLI** — for scripts, queues, scheduled jobs.
- **Long-running** runtimes: Swoole, RoadRunner, FrankenPHP, Laravel Octane — keep workers alive between requests.

Each request typically starts a fresh execution scope (no shared in-memory state) which avoids many concurrency bugs but limits performance vs persistent runtimes.

---

### Q2. PHP execution model — what happens per request?

**Answer:**
1. FPM picks a worker from the pool.
2. Worker boots PHP, parses your scripts (cached by OPcache).
3. Executes the request, builds response.
4. Tears down the world (objects destroyed, globals reset).
5. Worker returns to pool.

This isolation is why "stateless" frameworks dominate, and why the bootstrap cost matters (Composer autoload, container setup) — Octane-like runtimes skip steps 2 and 4.

---

### Q3. Single quotes vs double quotes vs heredoc/nowdoc.

**Answer:**

```php
'no $interpolation, faster, escape only \\ and \''
"interpolates $vars and {$obj->prop}, processes \n \t"
<<<EOT
heredoc — like double quotes, multiline
$name here is interpolated
EOT;
<<<'EOT'
nowdoc — like single quotes, no interpolation
EOT;
```

Performance differences are negligible since PHP 7+; choose by readability.

---

### Q4. `==` vs `===`, `<=>`?

**Answer:**

```php
0 == 'abc';     // PHP 7: true (string was coerced to 0). PHP 8+: false (semantics fixed)
0 == '0';       // true
0 === '0';      // false
1 <=> 2;        // -1 (spaceship — returns -1, 0, 1)
```

Always prefer `===`. PHP 8 made comparing 0 to non-numeric strings sane — a frequent legacy bug source.

---

### Q5. Arrays — what are they really?

**Answer:**
Ordered hash maps. Numeric and string keys coexist; insertion order is preserved.

```php
$a = ['x' => 1, 0 => 'first'];
$a[] = 'next';              // appends with key 1
array_is_list($a);          // false
array_is_list([10, 20]);    // true
```

Watch the index gotcha: numeric strings are coerced to int keys (`'1'` and `1` collide), and floats truncate.

---

## Types and Type Juggling

### Q6. PHP type system overview.

**Answer:**

| Category    | Types                                          |
|-------------|------------------------------------------------|
| Scalar      | `int`, `float`, `string`, `bool`               |
| Compound    | `array`, `object`, `callable`, `iterable`      |
| Special     | `null`, `resource`                             |
| Pseudo      | `mixed`, `void`, `never`, `self`, `static`, `parent` |

PHP supports type declarations on parameters, return types, and (PHP 7.4+) properties. Use `declare(strict_types=1);` per file to enforce strict scalar types — otherwise weak coercion applies.

---

### Q7. `declare(strict_types=1)` — what does it do?

**Answer:**
By default, scalar type hints coerce on call: `function f(int $n)` accepts `'5'`. With `declare(strict_types=1);` at file top, mismatched scalar types throw `TypeError`. Recommended in all modern code.

The directive applies at the **calling** file's scope, not the callee — you opt into strictness at your call sites.

---

### Q8. `null` handling and nullable types.

**Answer:**

```php
function find(int $id): ?User { ... }   // ?User === User|null

$x = $user?->profile?->name;             // null-safe (PHP 8)
$y = $arr['key'] ?? 'default';           // null coalescing
$arr['key'] ??= 'default';               // null coalescing assignment
```

`isset` checks defined and not null; `empty` is loose (treats `'0'`, `0`, `[]`, `null` as empty — surprising).

---

### Q9. `mixed`, `never`, `void`.

**Answer:**
- `mixed` — explicitly any type. Better than missing a hint because it documents intent.
- `void` — function does not return a value. `return;` allowed; `return $x;` is an error.
- `never` — function never returns normally (always throws or exits). Helps static analyzers narrow types.

```php
function fail(string $m): never { throw new RuntimeException($m); }
```

---

## Modern PHP 8.x Features

### Q10. Constructor property promotion.

**Answer:**

```php
final class User {
  public function __construct(
    public readonly string $id,
    public string $name,
    private ?string $email = null,
  ) {}
}
```

Eliminates the boilerplate of declaring properties and assigning them in the constructor. Combined with `readonly`, gives you immutable value objects in one block.

---

### Q11. Named arguments.

**Answer:**

```php
function createUser(string $name, bool $active = true, ?string $role = null) {}
createUser(name: 'Ada', role: 'admin');
```

- Skip optional parameters cleanly.
- Self-documenting at call site.
- Caveat: parameter names become part of the public API — renaming is a breaking change.

---

### Q12. Enums.

**Answer:**

```php
enum Status: string {
  case Active = 'active';
  case Pending = 'pending';
  case Closed = 'closed';

  public function label(): string {
    return match ($this) {
      self::Active => 'Active',
      self::Pending => 'Pending Review',
      self::Closed => 'Closed',
    };
  }
}

Status::from('active');      // Status::Active or throws
Status::tryFrom('xyz');      // null
Status::cases();             // array of all cases
```

Pure enums (no backing type) are also valid. Massive improvement over `const` constants for state machines.

---

### Q13. Readonly properties and classes.

**Answer:**

```php
final class Money {
  public function __construct(
    public readonly int $amountCents,
    public readonly string $currency,
  ) {}
}
```

PHP 8.1 introduced readonly properties; PHP 8.2 added readonly classes (every property is implicitly readonly). Cannot be modified after initialization in the constructor — gives you proper value objects.

Caveat: readonly objects are still **mutable through references inside collection properties**. For deep immutability, hold value objects, not arrays of mutable refs.

---

### Q14. The `match` expression.

**Answer:**

```php
$result = match ($status) {
  Status::Active, Status::Pending => 'open',
  Status::Closed => 'done',
  default => throw new InvalidArgumentException(),
};
```

Differences from `switch`:
- Strict comparison (`===`).
- No fallthrough.
- An expression — returns a value.
- Throws `UnhandledMatchError` if no arm matches and there's no default.

---

### Q15. Nullsafe operator.

**Answer:**

```php
$city = $user?->address?->city;
$name = $repo?->find(1)?->name;
```

Short-circuits to `null` if any link is `null`. Cannot be used on the left of an assignment.

---

### Q16. Attributes.

**Answer:**
Native annotations:

```php
#[Attribute]
final class Route {
  public function __construct(public string $path) {}
}

class UserController {
  #[Route('/users')]
  public function index() {}
}

$method = new ReflectionMethod(UserController::class, 'index');
foreach ($method->getAttributes(Route::class) as $attr) {
  $route = $attr->newInstance();
}
```

Replaces docblock-based annotations (Doctrine, Symfony) with first-class language support.

---

### Q17. First-class callable syntax.

**Answer:**

```php
$strlen = strlen(...);             // closure for built-in
$method = $service->process(...);  // closure for instance method
$static = User::create(...);       // closure for static method
```

Cleaner than `Closure::fromCallable('strlen')` or `[$service, 'process']`.

---

### Q18. Fibers.

**Answer:**
PHP 8.1 introduced fibers — stackful coroutines for cooperative concurrency. Foundation of async runtimes like ReactPHP and AMPHP v3.

```php
$fiber = new Fiber(function () {
  $value = Fiber::suspend('paused');
  return $value * 2;
});
$first = $fiber->start();    // 'paused'
$result = $fiber->resume(5); // 10
```

Most apps don't use fibers directly — they consume async libraries built on top.

---

### Q19. Disjunctive Normal Form (DNF) types.

**Answer:**

```php
function process((HasId&Cacheable)|null $entity) {}
```

PHP 8.2 lets you combine union and intersection types. The intersection requires both interfaces.

---

## OOP

### Q20. `abstract` vs `interface`.

**Answer:**

| Aspect              | `abstract class`              | `interface`                |
|---------------------|-------------------------------|----------------------------|
| Implementation      | can have method bodies         | only signatures (and constants since 8.1) |
| Properties          | yes                           | no (until 8.4 property hooks experimental) |
| Inheritance         | single                        | multiple `implements`      |
| Constructor         | yes                           | no                         |

Rule: interfaces describe **what**, abstract classes provide **partial how**.

---

### Q21. Traits.

**Answer:**
Code reuse mechanism — copy/paste at compile time, inserted into using class.

```php
trait Timestampable {
  public ?DateTimeImmutable $createdAt = null;
  public function touch(): void { $this->createdAt = new DateTimeImmutable(); }
}

class Order { use Timestampable; }
```

Conflicts resolved with `insteadof` and aliasing. Use traits for cross-cutting concerns (logging, timestamps), not as a substitute for composition. Overuse leads to "horizontal" reuse that's hard to test.

---

### Q22. Late static binding — `self` vs `static`.

**Answer:**

```php
class A {
  public static function make(): static { return new static(); }
  public static function name(): string { return self::class; }   // always 'A'
  public static function brand(): string { return static::class; } // resolves at call time
}
class B extends A {}

B::make();       // instance of B (because of `new static`)
B::name();       // 'A'
B::brand();      // 'B'
```

`self::` refers to the class where the method is **defined**. `static::` refers to the class on which it was **called**. Late static binding is essential for fluent factories.

---

### Q23. Magic methods.

**Answer:**

| Method        | Triggered by                                         |
|---------------|------------------------------------------------------|
| `__construct` | `new Foo()`                                          |
| `__destruct`  | object destruction                                   |
| `__call`      | calling inaccessible/missing instance method         |
| `__callStatic`| same for static                                      |
| `__get`/`__set`| reading/writing inaccessible property               |
| `__isset`/`__unset` | `isset`/`unset` on inaccessible property        |
| `__invoke`    | object called as function `$obj()`                   |
| `__toString`  | string context                                       |
| `__clone`     | after cloning                                        |
| `__serialize`/`__unserialize` | (de)serialization                    |
| `__debugInfo` | `var_dump`                                           |

Keep magic minimal — it hurts static analysis and IDE help.

---

### Q24. Object cloning.

**Answer:**
`clone $obj` does a **shallow** copy. Nested objects are still shared references. Implement `__clone` to deep-copy:

```php
class Order {
  public Customer $customer;
  public function __clone() { $this->customer = clone $this->customer; }
}
```

---

### Q25. Visibility modifiers.

**Answer:**
- `public` — accessible everywhere.
- `protected` — class and subclasses.
- `private` — class only (PHP's `private` is per-class, not per-instance — same-class instances can access each other's privates).
- PHP 8.4 adds `private(set)` / `protected(set)` for asymmetric visibility (read-only outside the class).

---

### Q26. `final`.

**Answer:**
- `final class` — cannot be extended.
- `final` method — cannot be overridden.
- `final` constant (PHP 8.1+) — cannot be redefined in subclasses.

Use `final` aggressively in application code — it makes refactors safer and signals "not designed for inheritance."

---

### Q27. Composition over inheritance — what does it look like in PHP?

**Answer:**

```php
final class OrderService {
  public function __construct(
    private readonly OrderRepository $orders,
    private readonly PaymentGateway $payments,
    private readonly Logger $log,
  ) {}
}
```

Dependencies injected through the constructor; behavior assembled, not inherited. This is the dominant style in modern Laravel/Symfony apps.

---

## Errors and Exceptions

### Q28. Errors vs exceptions.

**Answer:**
PHP 7 unified the hierarchy under `Throwable`:

```
Throwable (interface)
├── Error           — engine-level (TypeError, ParseError, ...)
└── Exception       — userland exceptions
    ├── RuntimeException
    └── LogicException
```

Catch `Throwable` in top-level handlers, `Exception` for "expected" failures, specific subclasses for known error categories.

---

### Q29. `try/catch/finally`.

**Answer:**

```php
try {
  $r = $client->call();
} catch (NetworkException | TimeoutException $e) {
  retry();
} catch (Throwable $e) {
  $log->error($e->getMessage(), ['ex' => $e]);
  throw $e;
} finally {
  $client->close();
}
```

Multi-catch (`|`) reduces duplication. Always re-throw or handle — silent swallow is a top source of production bugs.

---

### Q30. Custom exceptions.

**Answer:**

```php
class DomainException extends \RuntimeException {}
class OrderNotFound extends DomainException {
  public static function for(string $id): self {
    return new self("Order {$id} not found");
  }
}
```

Define a small hierarchy for your domain. Use named constructors to capture context.

---

### Q31. Error handling at the global level.

**Answer:**

```php
set_exception_handler(fn(Throwable $e) => $logger->critical($e));
set_error_handler(function ($severity, $msg, $file, $line) {
  if (!(error_reporting() & $severity)) return false;
  throw new ErrorException($msg, 0, $severity, $file, $line);
});
register_shutdown_function(function () {
  $err = error_get_last();
  if ($err && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR])) {
    // log fatal
  }
});
```

Frameworks set these for you — but understand the layers for production debugging.

---

## Closures, Generators, References

### Q32. Closures and `use`.

**Answer:**

```php
$prefix = 'Mr ';
$greet = function (string $name) use ($prefix) {
  return $prefix . $name;
};

// By reference:
$count = 0;
$inc = function () use (&$count) { $count++; };

// Arrow function (PHP 7.4+) — captures by value automatically:
$mult = fn($x) => $x * $factor;
```

Arrow functions auto-capture but are single-expression only.

---

### Q33. Binding closures to objects.

**Answer:**

```php
$closure = function () { return $this->secret; };
$bound = Closure::bind($closure, $object, MyClass::class);
$bound();
```

Used in tests to reach into private state, or in Laravel macros to extend classes at runtime.

---

### Q34. Generators.

**Answer:**

```php
function readLines(string $file): Generator {
  $h = fopen($file, 'r');
  try { while (!feof($h)) yield fgets($h); }
  finally { fclose($h); }
}

foreach (readLines('big.csv') as $line) { ... }
```

Memory-efficient iteration over huge data. `yield` pauses, `Generator::send()` injects values back. Used by ORMs to stream rows and by HTTP clients for chunked responses.

---

### Q35. References.

**Answer:**

```php
function bump(int &$n): void { $n++; }

$a = [1, 2, 3];
foreach ($a as &$v) { $v *= 2; }
unset($v);   // critical — leftover reference causes bugs
```

References create aliases. Forgetting to `unset` after a `foreach (... as &$v)` is a notorious bug source — the last element keeps reference semantics into subsequent operations.

---

## Namespaces, Autoloading, Composer

### Q36. PSR-4 autoloading.

**Answer:**
The dominant autoload standard. Maps a namespace prefix to a directory:

```json
{
  "autoload": {
    "psr-4": { "App\\": "src/" }
  }
}
```

`App\Services\OrderService` → `src/Services/OrderService.php`. Run `composer dump-autoload -o` for an optimized class map in production.

---

### Q37. Composer essentials.

**Answer:**

```bash
composer require vendor/pkg
composer require --dev phpunit/phpunit
composer install                  # respects composer.lock
composer update                   # bumps dependencies
composer dump-autoload --optimize
composer outdated
```

`composer.json` declares constraints; `composer.lock` records exact installed versions. Always commit the lock file.

---

### Q38. `composer.json` constraints.

**Answer:**

| Constraint    | Meaning                          |
|---------------|----------------------------------|
| `^1.2`        | >=1.2.0, <2.0.0 (caret — common) |
| `~1.2`        | >=1.2.0, <1.3.0                  |
| `>=1.2 <2.0`  | range                            |
| `1.2.*`       | wildcard                         |
| `dev-main`    | git branch                       |

Caret (`^`) is the modern default — semver-compatible updates.

---

### Q39. Namespaces.

**Answer:**

```php
namespace App\Services;

use App\Repositories\OrderRepository;
use function App\Helpers\format_currency;
use const App\Constants\API_VERSION;

class OrderService { ... }
```

`use` aliases via `as`: `use Long\Namespace\Foo as ShortFoo;`. Namespaces aren't physical (file paths) — autoloading happens to map them via PSR-4.

---

## Web Layer

### Q40. Sessions.

**Answer:**

```php
session_start([
  'cookie_secure' => true,
  'cookie_httponly' => true,
  'cookie_samesite' => 'Lax',
  'use_strict_mode' => 1,
]);
$_SESSION['user_id'] = 123;
```

Sessions are file-based by default. For scale use Redis/Memcached (`session.save_handler = redis`). Always regenerate on privilege change: `session_regenerate_id(true);`.

---

### Q41. Output buffering.

**Answer:**

```php
ob_start();
echo "buffered output";
$content = ob_get_clean();
```

Useful for capturing template output, post-processing, sending compressed responses (`ob_gzhandler`). Watch for headers-already-sent issues — anything echoed flushes implicitly without buffering.

---

### Q42. Headers and cookies.

**Answer:**

```php
header('Content-Type: application/json');
header('X-Frame-Options: DENY');
http_response_code(201);
setcookie('token', $jwt, [
  'expires'  => time() + 3600,
  'path'     => '/',
  'secure'   => true,
  'httponly' => true,
  'samesite' => 'Strict',
]);
```

Headers must be sent before any body output — buffer or check `headers_sent()` if unsure.

---

### Q43. Multibyte string handling.

**Answer:**
`strlen('café')` returns the number of **bytes**, not characters. Use `mbstring`:

```php
mb_strlen('café');          // 4
mb_substr($s, 0, 5);
mb_strtolower($s, 'UTF-8');
```

Set defaults at app boot: `mb_internal_encoding('UTF-8');`. Database columns must use a UTF-8 collation (`utf8mb4` for MySQL).

---

### Q44. File uploads.

**Answer:**

```php
$file = $_FILES['avatar'];
if ($file['error'] !== UPLOAD_ERR_OK) { /* handle */ }
if (!is_uploaded_file($file['tmp_name'])) abort();
move_uploaded_file($file['tmp_name'], $dest);
```

Validate size, MIME (don't trust extension; use `finfo`), randomize filenames, store outside web root, scan if untrusted. `php.ini` controls limits: `upload_max_filesize`, `post_max_size`, `max_file_uploads`.

---

## Security

### Q45. SQL injection — prevention.

**Answer:**
**Never concatenate user input into SQL.** Use parameterized queries (PDO / mysqli prepared statements):

```php
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = :email');
$stmt->execute(['email' => $email]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);
```

Use `PDO::ATTR_EMULATE_PREPARES = false` so the driver sends real prepared statements. ORMs (Eloquent, Doctrine) do this automatically — but raw queries you write yourself must still be parameterized.

---

### Q46. XSS prevention.

**Answer:**
Escape on **output**, contextually:

```php
echo htmlspecialchars($input, ENT_QUOTES | ENT_HTML5, 'UTF-8'); // HTML body
echo json_encode($data, JSON_HEX_TAG | JSON_HEX_AMP);            // inside <script>
```

Templating engines (Blade, Twig) auto-escape — never use the raw output directive (`{!! !!}`) on user data. Pair with a strict CSP.

---

### Q47. CSRF.

**Answer:**
Generate a token tied to the session, embed in forms, verify on POST:

```php
$_SESSION['csrf'] ??= bin2hex(random_bytes(32));
// in form
echo '<input type="hidden" name="_token" value="' . $_SESSION['csrf'] . '">';
// on submit
if (!hash_equals($_SESSION['csrf'], $_POST['_token'])) abort(419);
```

Frameworks bake this in (Laravel `@csrf`, Symfony FormType). Use `hash_equals` not `==` — constant-time comparison resists timing attacks.

---

### Q48. Password hashing.

**Answer:**

```php
$hash = password_hash($plain, PASSWORD_DEFAULT);            // bcrypt by default; argon2id if available
if (password_verify($plain, $hash)) {
  if (password_needs_rehash($hash, PASSWORD_DEFAULT)) {
    $hash = password_hash($plain, PASSWORD_DEFAULT);        // upgrade
  }
}
```

Never use `md5`, `sha1`, or fixed salts. `password_hash` handles salt and cost factor; tune cost so a hash takes ~250ms on your hardware.

---

### Q49. Common security gotchas.

**Answer:**
- `unserialize` on untrusted input → RCE via gadget chains. Use `json_decode` for data.
- Filename inputs without basename — path traversal (`../etc/passwd`).
- Direct file inclusion (`include $_GET['page']`) — code execution. Whitelist.
- Disclosing errors in production (`display_errors=Off`).
- Trusting `$_SERVER['HTTP_X_FORWARDED_FOR']` without verifying the proxy chain.

---

### Q50. Random values.

**Answer:**
Use cryptographic randomness for tokens:

```php
random_bytes(32);              // CSPRNG
random_int(1, 1000);           // unbiased random int
bin2hex(random_bytes(16));     // hex token
```

Never use `rand`, `mt_rand`, or `uniqid` for security.

---

## Performance and Runtime

### Q51. OPcache — what is it?

**Answer:**
Bytecode cache. PHP normally re-parses every file on every request; OPcache stores compiled opcodes in shared memory.

Production settings:

```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0      ; never re-check file mtimes
opcache.preload=/app/preload.php   ; PHP 7.4+ preloading
```

`validate_timestamps=0` means deploys must clear OPcache (`opcache_reset` or restart FPM).

---

### Q52. JIT.

**Answer:**
PHP 8 added a JIT compiler on top of OPcache. Big wins on CPU-bound math (image processing, simulations); modest wins on typical web workloads (which are I/O bound). Enable cautiously and benchmark:

```ini
opcache.jit_buffer_size=128M
opcache.jit=1255
```

---

### Q53. PHP-FPM tuning.

**Answer:**
Worker pools:

```ini
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 500    ; recycle to release leaked memory
```

Sizing rule: `max_children ≈ (RAM available) / (memory per worker)`. Each worker handles one request at a time — tune to your concurrency target.

---

### Q54. Common performance pitfalls.

**Answer:**
- N+1 queries — eager-load relations.
- Loading huge result sets into memory — use generators/streaming.
- Calling `count()` on Doctrine collections inside loops.
- Overuse of `array_merge` in loops (O(n²)) — append with `[]=` instead.
- Excessive `Closure::bind`/reflection in hot paths.
- Missing OPcache or autoloader optimization.

Profile with Xdebug/Blackfire/Tideways before optimizing — intuition lies.

---

### Q55. Memory and `unset`.

**Answer:**
PHP uses reference counting + cycle collection. `unset($x)` decrements the count; memory is freed when count hits zero. For huge intermediate arrays, `unset` early to release memory in long-running scripts (queue workers, Octane).

```php
$rows = $repo->all();
process($rows);
unset($rows); // helpful before another big load in the same request
```

---

### Q56. Long-running PHP — Octane, Swoole, RoadRunner.

**Answer:**
Workers stay alive between requests, eliminating bootstrap cost. Wins:
- 5–20× throughput.
- Persistent DB connections, in-memory caches.

Hazards:
- Static state leaks across requests.
- Singletons holding request-specific data → data leakage.
- Memory leaks accumulate over time (worker recycling helps).

Discipline: assume nothing is reset between requests except what your framework explicitly resets.

---

## Standards and Testing

### Q57. PSR — what are the important ones?

**Answer:**

| PSR        | Topic                              |
|------------|------------------------------------|
| PSR-1, PSR-12 | Coding style                    |
| PSR-3      | Logger interface                   |
| PSR-4      | Autoloading                        |
| PSR-7      | HTTP message interfaces            |
| PSR-11     | Container interface                |
| PSR-14     | Event dispatcher                   |
| PSR-15     | HTTP middleware                    |
| PSR-17     | HTTP factories                     |
| PSR-18     | HTTP client                        |

Frameworks implement these to be interoperable. Knowing the interfaces lets you swap implementations (Guzzle ↔ Symfony HTTP client).

---

### Q58. PHP 7 vs PHP 8 highlights.

**Answer:**

| Feature                       | Introduced |
|-------------------------------|------------|
| Scalar types, return types     | 7.0        |
| Nullable types, void           | 7.1        |
| Object type                    | 7.2        |
| Typed properties               | 7.4        |
| Arrow functions                | 7.4        |
| Constructor promotion          | 8.0        |
| Named args, attributes         | 8.0        |
| `match`, nullsafe              | 8.0        |
| Union types, JIT               | 8.0        |
| Enums, readonly props, fibers, intersection types | 8.1 |
| Readonly classes, DNF types    | 8.2        |
| Typed class constants, `#[\Override]` | 8.3 |
| Property hooks, asymmetric visibility | 8.4 |

---

### Q59. PHPUnit basics.

**Answer:**

```php
final class CalculatorTest extends \PHPUnit\Framework\TestCase {
  public function test_it_adds(): void {
    $sum = (new Calculator)->add(2, 3);
    self::assertSame(5, $sum);
  }

  /** @dataProvider invalidInputs */
  public function test_it_throws($a, $b): void {
    $this->expectException(\InvalidArgumentException::class);
    (new Calculator)->add($a, $b);
  }
  public static function invalidInputs(): array {
    return [['x', 1], [null, 2]];
  }
}
```

Test doubles via `createMock`, `createStub`. Pest is a popular alternative DSL on top of PHPUnit.

---

### Q60. Test pyramid in PHP apps.

**Answer:**
- **Unit** — pure logic, fast, no framework.
- **Integration** — touches DB/cache/HTTP; transactional rollback per test.
- **Feature/HTTP** — Laravel `$this->getJson('/api/users')` style.
- **Browser** — Dusk (Selenium), Cypress, Playwright.

Optimize for fast feedback — write unit tests for invariants, integration for boundaries, end-to-end sparingly.

---

### Q61. `static` vs `self` in factory methods.

**Answer:**

```php
abstract class Model {
  public static function newInstance(): static { return new static(); }
}
class User extends Model {}
User::newInstance(); // returns User, type-checks correctly thanks to `static` return type
```

Always prefer `static` return type for fluent base-class builders so subclass types flow.

---

### Q62. Common PHP gotchas to watch in interviews.

**Answer:**
- `0 == 'foo'` — PHP 7 yes, PHP 8 no.
- `array_key_exists` vs `isset` — `isset` is false for `null` values.
- `==` between arrays compares by keys/values regardless of order; `===` requires same order.
- Reference leftover after `foreach (... as &$x)` — always `unset($x)`.
- `(int) '10abc'` is `10`; `intval('abc')` is `0`.
- Integer overflow silently promotes to float on 32-bit ints — use 64-bit builds.
- `empty('0')` is `true` (string '0' counts as empty).
- `private` is per-class, not per-instance.

---
