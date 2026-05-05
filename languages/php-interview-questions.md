# PHP Interview Questions and Answers

A pedagogical Q&A guide for full-stack interviews. Each question has a plain-language explanation and a concrete code example. Read it once to understand, read it twice to recall in the room.

---

## 1. Fundamentals

## Q1. What is PHP and how does it run?

**Answer:**

PHP is a server-side scripting language designed for the web. The most common way to run it is behind a web server (Nginx or Apache) connected to PHP-FPM, which spawns worker processes. Each request is handled by a worker that reads your script, executes it, and returns the response. After the request, all variables and memory are thrown away.

```php
<?php
// index.php
echo "Hello " . htmlspecialchars($_GET['name'] ?? 'world');
```

## Q2. PHP execution model — what happens per request?

**Answer:**

PHP has a "share-nothing" model. Every request starts fresh: the SAPI hands the request to a worker, the worker bootstraps the script, runs it, returns output, and resets. State does not persist between requests unless you explicitly use session, cache, or database storage. This makes PHP simple to scale horizontally but means caching matters.

```php
<?php
// $globalVar exists only for THIS request
$globalVar = 'hello';
session_start();                    // persisted in session storage
$_SESSION['user_id'] = 42;          // available next request
```

## Q3. Single quotes vs double quotes vs heredoc/nowdoc.

**Answer:**

Single quotes are literal — no variable interpolation, no escape sequences (except `\\` and `\'`). Double quotes interpolate variables and process escapes. Heredoc behaves like double quotes but spans multiple lines. Nowdoc is heredoc's literal version (like single quotes).

```php
$name = 'Iqbal';

echo 'Hello $name';        // Hello $name
echo "Hello $name\n";      // Hello Iqbal (with newline)

echo <<<EOT
Hello $name
this is heredoc
EOT;

echo <<<'EOT'
Hello $name (literal)
EOT;
```

## Q4. `==` vs `===`, and the `<=>` operator?

**Answer:**

`==` compares with type juggling — `0 == "abc"` was true before PHP 8 (now false). `===` requires identical types and values. `<=>` is the spaceship operator — returns -1, 0, or 1 for comparison, useful in sort callbacks.

```php
var_dump(1 == "1");     // true  — values match after coercion
var_dump(1 === "1");    // false — different types

usort($arr, fn($a, $b) => $a['price'] <=> $b['price']);
```

## Q5. PHP arrays — what are they really?

**Answer:**

A PHP array is an ordered map. The same structure works as a list (numeric keys), a hash map (string keys), or both at the same time. They preserve insertion order and can be nested freely.

```php
$list = [10, 20, 30];                 // numeric keys 0, 1, 2
$map  = ['name' => 'Iqbal', 'age' => 25];
$mixed = ['a', 'name' => 'Iqbal', 'b'];
// keys: 0, 'name', 1
```

---

## 2. Types and Type Juggling

## Q6. PHP type system overview.

**Answer:**

PHP is dynamically typed but supports type declarations on function signatures, properties, and return types. Modern PHP supports scalar types (`int`, `float`, `string`, `bool`), compound types (`array`, `object`, `iterable`), and special types (`mixed`, `void`, `never`, `null`).

```php
function add(int $a, int $b): int {
    return $a + $b;
}

class User {
    public string $name;
    public ?int $age = null;
}
```

## Q7. `declare(strict_types=1)` — what does it do?

**Answer:**

By default PHP coerces scalar arguments — passing `"5"` to an `int` parameter works. With `strict_types=1` at the top of a file, type mismatches throw a `TypeError`. This catches bugs early.

```php
<?php
declare(strict_types=1);

function double(int $n): int { return $n * 2; }

double(5);        // 10
double("5");      // TypeError — string given, int expected
```

## Q8. `null` handling and nullable types.

**Answer:**

Use `?Type` to allow null. Use the null coalescing operator `??` to provide a default. Use the nullsafe operator `?->` to short-circuit method calls on null.

```php
function findUser(int $id): ?User { /* ... */ return null; }

$user = findUser(1);
$name = $user?->name ?? 'Anonymous';   // safe even if $user is null
```

## Q9. `mixed`, `never`, `void`.

**Answer:**

`mixed` accepts anything — use sparingly. `void` means the function returns no value. `never` means the function never returns normally — it throws or exits. The compiler uses `never` to know dead code follows.

```php
function any(mixed $v): mixed { return $v; }

function log(string $msg): void { error_log($msg); }

function fail(string $reason): never {
    throw new RuntimeException($reason);
}
```

---

## 3. Modern PHP 8.x Features

## Q10. Constructor property promotion.

**Answer:**

PHP 8 lets you declare properties directly in the constructor signature with a visibility modifier. The compiler creates the property and assigns it from the parameter automatically.

```php
class Product {
    public function __construct(
        public readonly string $name,
        public readonly float $price,
        private int $stock = 0,
    ) {}
}

$p = new Product('Phone', 499.99, 10);
$p->name;     // "Phone"
```

## Q11. Named arguments.

**Answer:**

PHP 8 lets you pass arguments by parameter name. Useful with functions having many optional parameters — you skip the ones you don't care about and improve call-site readability.

```php
function createUser(string $name, string $role = 'guest', bool $active = true) {
    /* ... */
}

createUser(name: 'Iqbal', active: false);
// $role takes its default 'guest'
```

## Q12. Enums.

**Answer:**

PHP 8.1 enums are first-class types with a fixed set of cases. Pure enums have only cases; backed enums have a scalar value (`int` or `string`). Enums can have methods.

```php
enum Status: string {
    case Active   = 'active';
    case Inactive = 'inactive';
    case Banned   = 'banned';

    public function label(): string {
        return match ($this) {
            Status::Active   => 'Active user',
            Status::Inactive => 'Inactive user',
            Status::Banned   => 'Banned user',
        };
    }
}

$s = Status::Active;
$s->value;        // "active"
$s->label();      // "Active user"
Status::from('active');         // Status::Active
Status::tryFrom('xxx');         // null
```

## Q13. Readonly properties and classes.

**Answer:**

`readonly` properties (8.1) can be set once in the constructor and never changed. `readonly` classes (8.2) make every property readonly. Great for value objects.

```php
final readonly class Money {
    public function __construct(
        public int $amount,
        public string $currency,
    ) {}
}

$m = new Money(100, 'USD');
// $m->amount = 200;   // Error
```

## Q14. The `match` expression.

**Answer:**

`match` is an expression that returns a value, uses strict comparison, and requires exhaustiveness (or a `default`). Cleaner replacement for `switch` in many cases.

```php
$status = 'active';

$label = match ($status) {
    'active', 'pending' => 'visible',
    'banned'            => 'blocked',
    default             => 'unknown',
};
```

## Q15. Nullsafe operator.

**Answer:**

`?->` short-circuits a method or property access if the left side is `null`, returning `null` instead of erroring.

```php
$city = $user?->address?->city ?? 'Unknown';
```

## Q16. Attributes.

**Answer:**

Attributes are PHP's native annotation syntax. They are class constants that read at runtime via Reflection and replace docblock-based annotations.

```php
#[Attribute]
class Route {
    public function __construct(public string $path) {}
}

class Controller {
    #[Route('/users')]
    public function index() {}
}

$ref = new ReflectionMethod(Controller::class, 'index');
$attrs = $ref->getAttributes(Route::class);
$route = $attrs[0]->newInstance();
echo $route->path;   // "/users"
```

## Q17. First-class callable syntax.

**Answer:**

PHP 8.1 lets you create a closure from any callable using `(...)`. Cleaner than `Closure::fromCallable` or string callable names.

```php
class Math {
    public function double(int $n): int { return $n * 2; }
}

$m = new Math();
$fn = $m->double(...);    // closure bound to $m
$fn(5);                   // 10

$strlen = strlen(...);
$strlen('hello');         // 5
```

## Q18. Fibers.

**Answer:**

Fibers are a primitive for cooperative multitasking — you can pause execution mid-function and resume later. Typically used by async runtimes like ReactPHP and Amp, not directly in app code.

```php
$fiber = new Fiber(function () {
    $value = Fiber::suspend('paused');
    echo "resumed with $value";
});

echo $fiber->start();    // "paused"
$fiber->resume('hi');    // "resumed with hi"
```

## Q19. Disjunctive Normal Form (DNF) types.

**Answer:**

PHP 8.2 lets you combine union and intersection types with parentheses. Useful when a parameter must satisfy multiple interfaces OR be null.

```php
function handle((Countable&Iterator)|null $value): void {
    if ($value === null) return;
    echo count($value);
}
```

---

## 4. OOP

## Q20. `abstract` vs `interface`.

**Answer:**

An interface declares a contract — only method signatures, no implementation, no state. A class can implement many interfaces. An abstract class can have implemented methods, properties, and constructors but cannot be instantiated. A class can extend only one abstract class.

```php
interface Logger {
    public function log(string $msg): void;
}

abstract class BaseRepository {
    public function __construct(protected PDO $db) {}
    abstract public function find(int $id): ?array;
}
```

## Q21. Traits.

**Answer:**

A trait is a piece of reusable code that gets copied into a class at compile time. Useful for sharing methods across unrelated classes without inheritance. Conflicts must be resolved with `insteadof` and `as`.

```php
trait Timestamps {
    public ?DateTimeImmutable $createdAt = null;

    public function touch(): void {
        $this->createdAt = new DateTimeImmutable();
    }
}

class Post {
    use Timestamps;
}

$p = new Post();
$p->touch();
$p->createdAt;   // current time
```

## Q22. Late static binding — `self` vs `static`.

**Answer:**

Inside a class, `self::` refers to the class where the code was written. `static::` refers to the class on which the method was actually called. Use `static` for methods that subclasses might override or extend.

```php
class A {
    public static function create(): static {
        return new static();      // refers to actual subclass
    }
    public static function createSelf(): self {
        return new self();        // always returns A
    }
}

class B extends A {}

A::create()       instanceof A;   // true
B::create()       instanceof B;   // true  — late static binding
B::createSelf()   instanceof B;   // false — always A
```

## Q23. Magic methods.

**Answer:**

Magic methods are special method names PHP calls automatically. `__construct` and `__destruct` for lifecycle. `__get`/`__set` for dynamic property access. `__call`/`__callStatic` for dynamic method calls. `__toString` for string casting. `__invoke` to make an object callable.

```php
class Bag {
    private array $items = [];

    public function __set(string $k, $v): void { $this->items[$k] = $v; }
    public function __get(string $k) { return $this->items[$k] ?? null; }
    public function __invoke(string $k) { return $this->__get($k); }
}

$b = new Bag();
$b->name = 'Iqbal';
echo $b->name;     // "Iqbal"
echo $b('name');   // "Iqbal"
```

## Q24. Object cloning.

**Answer:**

`clone` makes a shallow copy. To customize, define `__clone` and copy nested objects yourself.

```php
class Order {
    public DateTimeImmutable $createdAt;
    public array $items = [];

    public function __clone(): void {
        // shallow copy is fine for primitives and immutables
        // deep-copy mutables here if needed
    }
}

$copy = clone $order;
```

## Q25. Visibility modifiers.

**Answer:**

`public` is accessible everywhere. `protected` is accessible in the class and its subclasses. `private` is accessible only in the declaring class. PHP 8.4 adds asymmetric visibility (`public(set)`).

```php
class User {
    public string $name;
    protected int $age;
    private string $password;
}
```

## Q26. `final`.

**Answer:**

`final` on a class prevents extension. `final` on a method prevents overriding. Used to lock down APIs and value objects.

```php
final class UserId {
    public function __construct(public readonly int $value) {}
}

// class Subclass extends UserId {}   // Error
```

## Q27. Composition over inheritance — what does it look like in PHP?

**Answer:**

Instead of extending a class to reuse behavior, inject collaborators through the constructor. This makes dependencies explicit, easier to test, and avoids deep hierarchies.

```php
// Inheritance
class Service extends BaseLogger { /* ... */ }

// Composition
final class Service {
    public function __construct(private Logger $logger) {}

    public function process(): void {
        $this->logger->log('processed');
    }
}
```

---

## 5. Errors and Exceptions

## Q28. Errors vs exceptions.

**Answer:**

In modern PHP, most errors are throwable — they extend `Throwable`. Two main branches: `Error` for engine-level problems (`TypeError`, `ParseError`) and `Exception` for application-level. Both can be caught with `try/catch`.

```php
try {
    intdiv(10, 0);
} catch (DivisionByZeroError $e) {
    echo "engine error: ", $e->getMessage();
} catch (Throwable $e) {
    echo "anything else: ", $e->getMessage();
}
```

## Q29. `try/catch/finally`.

**Answer:**

`try` runs code that might throw. `catch` handles specific types. `finally` runs whether or not an exception was thrown — perfect for cleanup. PHP 8 supports catching multiple types in one block.

```php
try {
    $fp = fopen('file.txt', 'r');
    if (!$fp) throw new RuntimeException('cannot open');
    // work
} catch (RuntimeException | InvalidArgumentException $e) {
    echo "failed: ", $e->getMessage();
} finally {
    if (isset($fp) && $fp) fclose($fp);
}
```

## Q30. Custom exceptions.

**Answer:**

Define meaningful exception classes per domain so callers can catch what they care about. Add context fields when useful.

```php
class UserNotFoundException extends RuntimeException {
    public function __construct(public readonly int $userId) {
        parent::__construct("User {$userId} not found");
    }
}

try {
    findUser(99);
} catch (UserNotFoundException $e) {
    echo $e->userId;   // 99
}
```

## Q31. Error handling at the global level.

**Answer:**

Set a global handler to log uncaught errors and present a friendly response. Use `set_exception_handler` for uncaught exceptions, and `set_error_handler` to convert legacy PHP warnings/notices.

```php
set_exception_handler(function (Throwable $e) {
    error_log($e->getMessage());
    http_response_code(500);
    echo "Internal error";
});

set_error_handler(function (int $sev, string $msg, string $file, int $line) {
    throw new ErrorException($msg, 0, $sev, $file, $line);
});
```

---

## 6. Closures, Generators, References

## Q32. Closures and `use`.

**Answer:**

Closures are anonymous functions. They do not capture variables automatically — you must `use ($var)` to pull from the surrounding scope (by value) or `use (&$var)` (by reference).

```php
$factor = 2;
$double = function (int $n) use ($factor) {
    return $n * $factor;
};

echo $double(5);   // 10

// Arrow functions auto-capture by value
$triple = fn (int $n) => $n * $factor;
echo $triple(5);   // 10
```

## Q33. Binding closures to objects.

**Answer:**

A closure has its own `$this`. You can bind or rebind it with `Closure::bind` or call it on an object with `Closure::call`. Useful for testing and dynamic behavior.

```php
class Counter { private int $count = 0; }

$inspect = Closure::bind(function () { return $this->count; }, new Counter(), Counter::class);
echo $inspect();   // 0
```

## Q34. Generators.

**Answer:**

A generator yields values lazily without building the whole list in memory. Looks like a function with `yield` instead of `return`. Iterating runs the function up to the next yield.

```php
function range_lazy(int $start, int $end): Generator {
    for ($i = $start; $i <= $end; $i++) {
        yield $i;
    }
}

foreach (range_lazy(1, 1_000_000) as $n) {
    if ($n > 5) break;
    echo $n;   // 1 2 3 4 5
}
```

## Q35. References.

**Answer:**

A reference (`&`) makes two variables point to the same value. Modifying one changes the other. Use sparingly — most use cases are clearer with explicit return values.

```php
$a = 10;
$b = &$a;
$b = 20;
echo $a;   // 20

function increment(int &$n): void { $n++; }
$x = 5;
increment($x);
echo $x;   // 6
```

---

## 7. Namespaces, Autoloading, Composer

## Q36. PSR-4 autoloading.

**Answer:**

PSR-4 maps a namespace prefix to a directory. The class `App\Services\UserService` lives at `src/Services/UserService.php`. Composer generates the autoloader for you.

```json
{
  "autoload": {
    "psr-4": {
      "App\\": "src/"
    }
  }
}
```

```php
require 'vendor/autoload.php';
$service = new App\Services\UserService();
```

## Q37. Composer essentials.

**Answer:**

Composer is PHP's dependency manager. `composer.json` declares dependencies; `composer.lock` pins exact versions; `vendor/` holds installed packages. Use `composer require` to add and `composer install` to install from the lock file.

```bash
composer require monolog/monolog
composer install              # respects composer.lock
composer update monolog/monolog
composer dump-autoload -o     # rebuild + optimize autoload
```

## Q38. `composer.json` version constraints.

**Answer:**

Constraints control which versions are accepted. `^1.2` allows `>=1.2.0 <2.0.0`. `~1.2` allows `>=1.2.0 <1.3.0`. `1.2.*` allows any patch in 1.2. Use `^` for libraries, exact pins for apps when needed.

```json
{
  "require": {
    "monolog/monolog": "^3.0",
    "symfony/console": "~6.4",
    "guzzlehttp/guzzle": "7.5.*"
  }
}
```

## Q39. Namespaces.

**Answer:**

Namespaces avoid name collisions across packages. Declared with `namespace`. Imports use `use`. The fully qualified name starts with `\`.

```php
namespace App\Services;

use App\Models\User;
use Psr\Log\LoggerInterface;

class UserService {
    public function __construct(private LoggerInterface $logger) {}
}
```

---

## 8. Web Layer

## Q40. Sessions.

**Answer:**

Sessions persist per-user data across requests using a cookie that holds the session ID. Files are the default backend; production usually uses Redis or databases for scaling.

```php
session_start();
$_SESSION['user_id'] = 42;

// Next request
session_start();
echo $_SESSION['user_id'];   // 42

session_destroy();
```

## Q41. Output buffering.

**Answer:**

Output buffering captures `echo`/`print` output instead of sending it to the client. Useful for capturing partial output, modifying it, or sending headers after some output.

```php
ob_start();
echo "Hello world";
$content = ob_get_clean();   // captured

echo strtoupper($content);   // "HELLO WORLD"
```

## Q42. Headers and cookies.

**Answer:**

Use `header()` to set HTTP response headers and `setcookie()` for cookies. Both must be called before any output, otherwise PHP throws "headers already sent."

```php
header('Content-Type: application/json');
http_response_code(201);

setcookie('token', $value, [
    'expires'  => time() + 3600,
    'path'     => '/',
    'secure'   => true,
    'httponly' => true,
    'samesite' => 'Lax',
]);

echo json_encode(['id' => 1]);
```

## Q43. Multibyte string handling.

**Answer:**

Default string functions work on bytes. For Unicode strings (UTF-8), use the `mb_*` family and set the default encoding.

```php
mb_internal_encoding('UTF-8');

$s = 'héllo';
strlen($s);          // 6  — bytes
mb_strlen($s);       // 5  — characters

mb_substr($s, 0, 3); // "hél"
```

## Q44. File uploads.

**Answer:**

Uploaded files appear in `$_FILES`. Validate the size, MIME type, and original name. Move to a permanent location with `move_uploaded_file`.

```php
if (isset($_FILES['avatar']) && $_FILES['avatar']['error'] === UPLOAD_ERR_OK) {
    $tmp  = $_FILES['avatar']['tmp_name'];
    $mime = mime_content_type($tmp);
    if (!in_array($mime, ['image/jpeg', 'image/png'])) {
        throw new RuntimeException('invalid type');
    }
    $name = bin2hex(random_bytes(16)) . '.bin';
    move_uploaded_file($tmp, __DIR__ . "/uploads/{$name}");
}
```

---

## 9. Security

## Q45. SQL injection — prevention.

**Answer:**

Never concatenate user input into SQL. Use prepared statements with placeholders, and the database driver handles escaping.

```php
// Vulnerable
$pdo->query("SELECT * FROM users WHERE email = '$email'");

// Safe — prepared statement
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);
```

## Q46. XSS prevention.

**Answer:**

Escape user input on output, not input. Use `htmlspecialchars($value, ENT_QUOTES, 'UTF-8')` for HTML contexts, JSON encode for `<script>` blocks, and never trust attribute names or URLs without validation.

```php
echo '<p>' . htmlspecialchars($comment, ENT_QUOTES, 'UTF-8') . '</p>';

// For attributes use ENT_QUOTES too
$href = htmlspecialchars($url, ENT_QUOTES, 'UTF-8');
echo "<a href=\"$href\">link</a>";
```

## Q47. CSRF.

**Answer:**

Cross-Site Request Forgery tricks a browser into sending an authenticated request. Defend with anti-CSRF tokens on state-changing forms and with `SameSite` cookies.

```php
// Generate
session_start();
$_SESSION['csrf'] = $_SESSION['csrf'] ?? bin2hex(random_bytes(32));

// Check
if (!hash_equals($_SESSION['csrf'], $_POST['csrf'] ?? '')) {
    http_response_code(403);
    exit('invalid token');
}
```

## Q48. Password hashing.

**Answer:**

Never store plaintext passwords or weak hashes (MD5, SHA-1). Use `password_hash` (defaults to bcrypt; argon2 available) and `password_verify`.

```php
$hash = password_hash($plain, PASSWORD_DEFAULT);

if (password_verify($input, $hash)) {
    if (password_needs_rehash($hash, PASSWORD_DEFAULT)) {
        $hash = password_hash($input, PASSWORD_DEFAULT);
    }
}
```

## Q49. Common security gotchas.

**Answer:**

Disable verbose errors in production (`display_errors=0`). Set `session.cookie_secure=1` and `httponly=1`. Validate file uploads. Never trust `$_SERVER['HTTP_HOST']` without a whitelist. Use HTTPS-only cookies.

```ini
display_errors = 0
log_errors = 1
session.cookie_secure = 1
session.cookie_httponly = 1
session.cookie_samesite = Lax
```

## Q50. Random values.

**Answer:**

Use `random_bytes` and `random_int` for cryptographic randomness (tokens, IDs). `rand`/`mt_rand` are NOT cryptographically secure.

```php
$token = bin2hex(random_bytes(32));     // 64 hex chars
$pin   = random_int(100000, 999999);    // 6-digit OTP
```

---

## 10. Performance and Runtime

## Q51. OPcache — what is it?

**Answer:**

OPcache stores precompiled bytecode in shared memory so PHP doesn't recompile your scripts on every request. It is the single biggest PHP performance win and is enabled by default in modern installations.

```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0   ; in production, deploy invalidates
```

## Q52. JIT.

**Answer:**

PHP 8 added a JIT (Just-in-Time compiler) that turns hot bytecode into machine code at runtime. It rarely helps typical web request workloads but boosts CPU-bound tasks (image processing, math, long-running scripts).

```ini
opcache.jit_buffer_size=128M
opcache.jit=tracing
```

## Q53. PHP-FPM tuning.

**Answer:**

PHP-FPM manages worker processes. The pool config controls how many workers start, max children, and process management strategy. Match worker count to CPU and memory budget.

```ini
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 10
pm.max_requests = 500       ; recycle workers to fight memory leaks
```

## Q54. Common performance pitfalls.

**Answer:**

N+1 database queries (fix with eager loading or joins), unbounded memory loads (read large files line-by-line), repeated computation in loops (cache once), missing indexes on WHERE columns, and recompiling regex inside loops.

```php
// Pitfall — reads full file into memory
$lines = file('big.csv');

// Better — generator-based
$fp = fopen('big.csv', 'r');
while (($line = fgets($fp)) !== false) {
    process($line);
}
fclose($fp);
```

## Q55. Memory and `unset`.

**Answer:**

`unset` releases the variable. Memory is reclaimed when no references remain. PHP's reference-counting GC works for most cases; the cycle collector handles object graphs.

```php
$big = file_get_contents('huge.json');
process($big);
unset($big);                  // free memory
gc_collect_cycles();          // force cycle collector if needed
```

## Q56. Long-running PHP — Octane, Swoole, RoadRunner.

**Answer:**

Traditional PHP boots and dies per request. Long-running runtimes (Swoole, RoadRunner, Laravel Octane) keep the application in memory between requests for big speedups, but require care: avoid global state, watch for memory leaks, reset per-request services.

```php
// Pseudocode pattern
while ($req = $server->accept()) {
    $response = $app->handle($req);
    $server->respond($response);
    // App stays in memory — no shutdown
}
```

---

## 11. Standards and Testing

## Q57. PSR — what are the important ones?

**Answer:**

PSR-1 / PSR-12 — coding style. PSR-4 — autoloading. PSR-7 — HTTP messages. PSR-11 — container interface. PSR-15 — HTTP middleware. PSR-18 — HTTP client.

```php
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Message\ResponseInterface;

interface MiddlewareInterface {
    public function process(
        ServerRequestInterface $req,
        RequestHandlerInterface $next
    ): ResponseInterface;
}
```

## Q58. PHP 7 vs PHP 8 highlights.

**Answer:**

PHP 8 introduced JIT, named arguments, attributes, match, constructor promotion, nullsafe operator, union types, `Stringable`, `WeakMap`, and stricter type juggling. PHP 8.1+ added enums, readonly, fibers, never type, first-class callable syntax. PHP 8.2+ added readonly classes, DNF types.

```php
// PHP 8 features mixed
class User {
    public function __construct(
        public readonly string $name,
        public readonly ?int $age = null,
    ) {}
}

$role = match ($status) {
    'A', 'B' => 'admin',
    default  => 'user',
};
```

## Q59. PHPUnit basics.

**Answer:**

PHPUnit is the standard testing framework. Tests extend `TestCase`. Use assertions to verify outcomes, mocks to isolate, and data providers for parameterized tests.

```php
use PHPUnit\Framework\TestCase;

final class CalculatorTest extends TestCase {
    public function testAdd(): void {
        $calc = new Calculator();
        $this->assertSame(5, $calc->add(2, 3));
    }

    /** @dataProvider divideProvider */
    public function testDivide(int $a, int $b, int $expected): void {
        $this->assertSame($expected, (new Calculator())->divide($a, $b));
    }

    public static function divideProvider(): array {
        return [
            [10, 2, 5],
            [9, 3, 3],
        ];
    }
}
```

## Q60. Test pyramid in PHP apps.

**Answer:**

Lots of fast unit tests at the bottom (pure logic, value objects). Fewer integration tests in the middle (database, services). A handful of end-to-end/browser tests at the top. Mock at unit level only.

```php
// Unit — pure
$this->assertSame(120, (new Pricing())->total(100, 0.20));

// Integration — uses real DB
$repo = new UserRepository($this->pdo);
$this->assertNotNull($repo->find(1));
```

## Q61. `static` vs `self` in factory methods.

**Answer:**

`new self()` always builds the class where the method is written. `new static()` uses late static binding — the actual called class. Factories should usually return `static` so subclasses get instances of themselves.

```php
class Model {
    public static function create(): static {
        return new static();
    }
}

class Post extends Model {}

Post::create()  instanceof Post;   // true
```

## Q62. Common PHP gotchas to watch in interviews.

**Answer:**

`==` coercion (use `===`), arrays vs objects (`(object) []` casts), `true == 'any-string'` quirks, `count()` on null (deprecated), float precision (`0.1 + 0.2 != 0.3`), and silent failures from `@`.

```php
echo (0 == "abc");      // false in PHP 8 (true in PHP 7)
echo (0.1 + 0.2 == 0.3); // false — IEEE-754 floats
echo (PHP_INT_MAX + 1); // becomes float
```

---

## 12. Standard Library Essentials

## Q63. Useful array functions.

**Answer:**

`array_map` transforms each item. `array_filter` keeps matching items. `array_reduce` collapses to a value. `array_column` extracts a single column from a list of rows. `array_combine` zips keys with values.

```php
$nums = [1, 2, 3, 4];
array_map(fn ($n) => $n * 2, $nums);          // [2, 4, 6, 8]
array_filter($nums, fn ($n) => $n % 2 === 0); // [1 => 2, 3 => 4]
array_reduce($nums, fn ($a, $b) => $a + $b, 0); // 10

$rows = [['id' => 1, 'name' => 'A'], ['id' => 2, 'name' => 'B']];
array_column($rows, 'name');                  // ["A", "B"]
array_column($rows, 'name', 'id');            // [1 => "A", 2 => "B"]
```

## Q64. String functions to know.

**Answer:**

`str_contains`, `str_starts_with`, `str_ends_with` (PHP 8), `trim`, `explode`/`implode`, `sprintf`, `preg_match`, `preg_replace`, `mb_*` for Unicode.

```php
str_contains('hello world', 'world');   // true
str_starts_with('foo.txt', 'foo');      // true

sprintf('%s is %d years old', 'Iqbal', 25);
preg_match('/(\d+)/', 'abc123', $m);    // $m[1] === "123"
```

## Q65. Date and time.

**Answer:**

Prefer immutable `DateTimeImmutable` over `DateTime` for safety. Use `DateInterval` for offsets and `DateTimeZone` for time zones.

```php
$now    = new DateTimeImmutable();
$later  = $now->modify('+1 day');
$diff   = $now->diff($later);
echo $diff->days;                  // 1

$dt = new DateTimeImmutable('2024-01-01', new DateTimeZone('Asia/Dhaka'));
echo $dt->format('Y-m-d H:i:s T');
```

## Q66. JSON handling.

**Answer:**

`json_encode` and `json_decode` convert between PHP and JSON. Pass `JSON_THROW_ON_ERROR` so you don't have to check `json_last_error`.

```php
$json = json_encode(['id' => 1, 'name' => 'Iqbal'], JSON_THROW_ON_ERROR);
$data = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
// $data is associative array
```

## Q67. PDO vs mysqli.

**Answer:**

PDO supports many database backends with one API and prepared statements. mysqli is MySQL-only. Most modern PHP code uses PDO or an ORM built on top of it.

```php
$pdo = new PDO('mysql:host=localhost;dbname=app;charset=utf8mb4', 'user', 'pass', [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
]);

$stmt = $pdo->prepare('SELECT * FROM users WHERE id = :id');
$stmt->execute(['id' => 1]);
$row = $stmt->fetch();
```

## Q68. Database transactions.

**Answer:**

Wrap related writes in a transaction so they all succeed or all fail. Always handle exceptions and roll back.

```php
$pdo->beginTransaction();
try {
    $pdo->prepare('UPDATE accounts SET balance = balance - ? WHERE id = ?')
        ->execute([100, 1]);
    $pdo->prepare('UPDATE accounts SET balance = balance + ? WHERE id = ?')
        ->execute([100, 2]);
    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;
}
```

## Q69. `array` vs `SplFixedArray`/`SplObjectStorage`.

**Answer:**

PHP arrays are flexible but use more memory than fixed-size arrays. `SplFixedArray` is faster for large numeric arrays. `SplObjectStorage` lets you use objects as keys (a `WeakMap` was added in PHP 8).

```php
$a = new SplFixedArray(1_000_000);
for ($i = 0; $i < 1_000_000; $i++) $a[$i] = $i * 2;

$weak = new WeakMap();
$obj = new stdClass();
$weak[$obj] = 'value';
```

## Q70. Iterators in the standard library.

**Answer:**

PHP has many iterator classes for streaming data: `ArrayIterator`, `IteratorAggregate`, `LimitIterator`, `FilterIterator`, `RecursiveDirectoryIterator`. Useful for memory-efficient processing.

```php
$it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator('.'));
foreach (new RegexIterator($it, '/\.php$/') as $file) {
    echo $file->getPathname(), PHP_EOL;
}
```
