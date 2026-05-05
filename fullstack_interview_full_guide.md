# Full-Stack Developer Interview Preparation — Complete Q&A Guide

**Role:** Full-Stack Developer — Laravel & Vue.js  
**Focus:** Laravel, PHP, Raw PHP, Vue 3, JavaScript/TypeScript, MySQL, REST API, debugging, performance, scalability

---

## How to Use This Guide

This guide is designed for a practical 2–4 year full-stack developer interview. Do not memorize blindly. Read each answer, understand the idea, then practice explaining it in your own words.

Your target in the interview is simple:

> “I can build a complete feature from database design to Laravel API to Vue UI, and I can debug and optimize it.”

---

# 1. Interview Self-Introduction

## Q1. Tell me about yourself.

**Answer:**

I am a full-stack developer with practical experience in backend API development, database design, and frontend integration. I mainly work with PHP/Laravel, MySQL, REST APIs, and Vue.js. I enjoy building complete features end-to-end: designing tables, writing Laravel APIs, validating requests, handling business logic, and integrating the frontend with API responses. I also focus on debugging, clean code, performance, and maintainability.

For this role, I think my backend and frontend combination fits well because the position requires Laravel, Vue.js, REST API, MySQL, and problem-solving ability.

## Q2. Why do you want this job?

**Answer:**

This role matches my skill set because it requires Laravel, PHP, Vue.js, REST API, and MySQL. I like working on full-stack systems where I can understand both the business logic and the user experience. Envaysoft works on custom software and eCommerce solutions, so I believe I can contribute by building scalable backend systems and smooth frontend interfaces.

## Q3. What are your strongest technical skills?

**Answer:**

My strongest skills are backend API development, database design, Laravel MVC, request validation, REST API integration, debugging, and building frontend interfaces with Vue. I am also comfortable reading existing codebases, fixing bugs, and improving performance.

## Q4. What kind of projects have you worked on?

**Answer Template:**

I have worked on systems where users can create, update, search, filter, and manage business data. My responsibilities included database table design, API development, validation, authentication, frontend API integration, and debugging. I also worked on improving performance by optimizing queries and reducing unnecessary API calls.

---

# 2. Laravel Core Questions

## Q1. What is Laravel?

**Answer:**

Laravel is a modern PHP framework used to build web applications and APIs. It follows MVC architecture and provides built-in features like routing, controllers, middleware, validation, Eloquent ORM, migrations, authentication, queues, caching, events, jobs, and testing.

## Q2. Explain MVC in Laravel.

**Answer:**

MVC means Model, View, Controller.

| Layer      | Responsibility                                         |
| ---------- | ------------------------------------------------------ |
| Model      | Represents database tables and business data           |
| View       | Displays UI, usually Blade or frontend output          |
| Controller | Handles request, calls model/service, returns response |

Example flow:

```text
User Request → Route → Controller → Model/Service → Database → Response
```

## Q3. What is the difference between `web.php` and `api.php`?

**Answer:**

`web.php` is used for browser-based routes. It uses web middleware like session, CSRF protection, and cookies.

`api.php` is used for stateless API routes. It usually uses token-based authentication like Sanctum or Passport and does not depend on sessions.

## Q4. What is middleware in Laravel?

**Answer:**

Middleware filters HTTP requests before they reach the controller or after the response is created. It is used for authentication, authorization, logging, CORS, rate limiting, and request modification.

Example:

```php
Route::middleware('auth:sanctum')->get('/profile', [ProfileController::class, 'show']);
```

## Q5. What is Eloquent ORM?

**Answer:**

Eloquent is Laravel’s ORM. It allows developers to interact with database tables using PHP classes instead of writing raw SQL for every query. Each model usually maps to one database table.

```php
$users = User::where('status', 'active')->get();
```

## Q6. What is a migration?

**Answer:**

Migration is version control for database schema. It allows developers to create, modify, and rollback database tables through code.

```php
Schema::create('products', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->decimal('price', 10, 2);
    $table->timestamps();
});
```

## Q7. What is a seeder?

**Answer:**

A seeder inserts sample or default data into the database. It is useful for testing, development, and initial setup.

```php
User::factory()->count(10)->create();
```

## Q8. What is a factory?

**Answer:**

A factory creates fake model data for testing or seeding. It works with Faker to generate realistic data.

## Q9. What is mass assignment?

**Answer:**

Mass assignment means inserting or updating multiple model fields at once using an array.

```php
Product::create($request->all());
```

To protect against unsafe fields, Laravel uses `$fillable` or `$guarded`.

```php
protected $fillable = ['name', 'price', 'status'];
```

## Q10. Difference between `$fillable` and `$guarded`?

**Answer:**

`$fillable` defines which fields are allowed for mass assignment.

`$guarded` defines which fields are blocked from mass assignment.

Usually `$fillable` is safer because it explicitly allows only specific fields.

## Q11. What are accessors and mutators?

**Answer:**

Accessors modify data when reading from the model. Mutators modify data before saving into the database.

Example mutator:

```php
public function setNameAttribute($value)
{
    $this->attributes['name'] = ucfirst($value);
}
```

## Q12. What is route model binding?

**Answer:**

Route model binding automatically injects a model instance based on route parameter.

```php
Route::get('/products/{product}', [ProductController::class, 'show']);

public function show(Product $product)
{
    return $product;
}
```

Laravel automatically finds the product by ID.

## Q13. What is dependency injection in Laravel?

**Answer:**

Dependency injection means passing required classes into a controller or service instead of creating them manually. Laravel’s service container resolves the dependency automatically.

```php
public function __construct(ProductService $productService)
{
    $this->productService = $productService;
}
```

## Q14. What is the service container?

**Answer:**

The service container is Laravel’s dependency injection system. It manages class dependencies and resolves objects automatically.

## Q15. What is a service provider?

**Answer:**

A service provider bootstraps application services. It is used to register bindings, event listeners, routes, observers, or package services.

## Q16. What is the difference between `get()`, `first()`, `find()`, and `pluck()`?

**Answer:**

| Method          | Meaning                                |
| --------------- | -------------------------------------- |
| `get()`         | Returns collection of matching records |
| `first()`       | Returns first matching record or null  |
| `find($id)`     | Finds one record by primary key        |
| `pluck('name')` | Returns specific column values         |

## Q17. Difference between `find()` and `findOrFail()`?

**Answer:**

`find()` returns null if no record exists.

`findOrFail()` throws a 404 exception if no record exists.

## Q18. Difference between `first()` and `firstOrFail()`?

**Answer:**

`first()` returns null if no row matches.

`firstOrFail()` throws an exception, usually converted into a 404 response.

## Q19. What is soft delete?

**Answer:**

Soft delete marks a record as deleted without physically removing it from the database. Laravel uses a `deleted_at` column.

```php
use SoftDeletes;
```

## Q20. What is the difference between `delete()` and `forceDelete()`?

**Answer:**

`delete()` soft-deletes the record if the model uses SoftDeletes.

`forceDelete()` permanently removes the record from the database.

---

# 3. Laravel Relationships

## Q1. What are Eloquent relationships?

**Answer:**

Eloquent relationships define how tables/models are connected. Common relationships are one-to-one, one-to-many, many-to-many, has-many-through, and polymorphic relationships.

## Q2. Explain one-to-one relationship.

**Answer:**

One user has one profile.

```php
public function profile()
{
    return $this->hasOne(Profile::class);
}
```

## Q3. Explain one-to-many relationship.

**Answer:**

One user can have many posts.

```php
public function posts()
{
    return $this->hasMany(Post::class);
}
```

## Q4. Explain many-to-many relationship.

**Answer:**

A user can have many roles, and a role can belong to many users. This requires a pivot table.

```php
public function roles()
{
    return $this->belongsToMany(Role::class);
}
```

## Q5. What is a pivot table?

**Answer:**

A pivot table connects two tables in a many-to-many relationship. Example: `role_user` table with `user_id` and `role_id`.

## Q6. What is eager loading?

**Answer:**

Eager loading loads related data in fewer queries to avoid the N+1 problem.

```php
$users = User::with('posts')->get();
```

## Q7. What is lazy loading?

**Answer:**

Lazy loading loads related data only when accessed.

```php
$user = User::first();
$posts = $user->posts;
```

This can cause many queries if used inside loops.

## Q8. What is the N+1 query problem?

**Answer:**

The N+1 problem happens when one query fetches parent records and then one additional query runs for each parent to fetch child records.

Bad:

```php
$users = User::all();
foreach ($users as $user) {
    echo $user->posts->count();
}
```

Good:

```php
$users = User::with('posts')->get();
```

## Q9. What is `withCount()`?

**Answer:**

`withCount()` adds related record counts without loading all related records.

```php
$users = User::withCount('posts')->get();
```

## Q10. What is polymorphic relationship?

**Answer:**

A polymorphic relationship allows one model to belong to multiple model types. Example: comments can belong to posts or videos.

---

# 4. Laravel Validation, Request, Response

## Q1. How do you validate request data in Laravel?

**Answer:**

Validation can be done using `$request->validate()` or Form Request classes.

```php
$request->validate([
    'name' => 'required|string|max:255',
    'price' => 'required|numeric|min:0'
]);
```

## Q2. What is Form Request validation?

**Answer:**

Form Request is a separate class for validation logic. It keeps controllers cleaner.

```bash
php artisan make:request StoreProductRequest
```

## Q3. Why use Form Request instead of controller validation?

**Answer:**

Because it separates validation from controller logic, improves readability, allows authorization logic, and makes the code easier to maintain.

## Q4. How do you return JSON response in Laravel?

**Answer:**

```php
return response()->json([
    'success' => true,
    'data' => $product
], 200);
```

## Q5. What HTTP status codes do you commonly use?

**Answer:**

| Code | Meaning          |
| ---- | ---------------- |
| 200  | Success          |
| 201  | Created          |
| 204  | No content       |
| 400  | Bad request      |
| 401  | Unauthenticated  |
| 403  | Forbidden        |
| 404  | Not found        |
| 422  | Validation error |
| 500  | Server error     |

## Q6. Difference between 401 and 403?

**Answer:**

401 means the user is not authenticated.

403 means the user is authenticated but does not have permission.

## Q7. What is API Resource in Laravel?

**Answer:**

API Resource transforms model data into a clean JSON structure.

```php
return new ProductResource($product);
```

It helps avoid returning raw database models directly.

## Q8. Why should we not always return Eloquent models directly?

**Answer:**

Because raw models may expose unnecessary fields, internal columns, or relationship data. API Resources provide controlled response formatting.

---

# 5. Laravel Authentication and Security

## Q1. What authentication methods are common in Laravel APIs?

**Answer:**

Common methods are Laravel Sanctum, Passport, JWT, and session-based authentication for web apps.

## Q2. What is Laravel Sanctum?

**Answer:**

Sanctum is Laravel’s lightweight authentication package for SPAs, mobile apps, and simple token-based APIs.

## Q3. What is Laravel Passport?

**Answer:**

Passport is Laravel’s OAuth2 authentication package. It is used when the application needs full OAuth2 flows.

## Q4. Sanctum vs Passport?

**Answer:**

| Sanctum                        | Passport                      |
| ------------------------------ | ----------------------------- |
| Simple token auth              | Full OAuth2 server            |
| Good for SPA/mobile/simple API | Good for complex OAuth2 needs |
| Easier setup                   | More complex setup            |

## Q5. What is CSRF protection?

**Answer:**

CSRF protection prevents attackers from submitting unwanted requests from another site using the user’s logged-in session. Laravel automatically enables CSRF protection for web routes.

## Q6. What is XSS?

**Answer:**

XSS means Cross-Site Scripting. It happens when malicious JavaScript is injected into a page. To prevent it, escape output, validate input, and avoid rendering unsafe HTML.

## Q7. What is SQL injection?

**Answer:**

SQL injection happens when user input is directly inserted into SQL queries. Laravel prevents it by using query bindings and Eloquent.

Bad:

```php
DB::select("SELECT * FROM users WHERE email = '$email'");
```

Good:

```php
DB::select('SELECT * FROM users WHERE email = ?', [$email]);
```

## Q8. How do you protect sensitive fields in models?

**Answer:**

Use `$hidden` to hide fields from JSON responses.

```php
protected $hidden = ['password', 'remember_token'];
```

## Q9. How should passwords be stored?

**Answer:**

Passwords should never be stored as plain text. They should be hashed using Laravel’s Hash facade.

```php
Hash::make($request->password);
```

## Q10. What is rate limiting?

**Answer:**

Rate limiting restricts how many requests a user can make in a given time. It helps prevent abuse, brute-force attacks, and API overload.

---

# 6. Laravel Performance and Scalability

## Q1. How do you improve Laravel performance?

**Answer:**

I improve Laravel performance by optimizing database queries, using eager loading, pagination, caching frequently used data, queueing heavy tasks, avoiding unnecessary loops, using indexes, and using Laravel optimization commands in production.

## Q2. What Laravel optimization commands are useful in production?

**Answer:**

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize
```

## Q3. Why should we use pagination?

**Answer:**

Pagination avoids loading too many records at once. It improves response time, reduces memory usage, and makes the UI faster.

```php
Product::paginate(20);
```

## Q4. What is caching?

**Answer:**

Caching stores frequently used data temporarily so the application does not repeatedly query the database or recompute expensive results.

```php
Cache::remember('active_products', 3600, function () {
    return Product::where('active', true)->get();
});
```

## Q5. What are queues in Laravel?

**Answer:**

Queues allow time-consuming tasks to run in the background, such as sending emails, generating reports, image processing, or third-party API calls.

## Q6. What is a job in Laravel?

**Answer:**

A job is a class that contains background task logic. Jobs are dispatched to queues.

```php
SendOrderEmail::dispatch($order);
```

## Q7. What causes slow Laravel APIs?

**Answer:**

Common causes include N+1 queries, missing indexes, loading too much data, inefficient loops, large JSON responses, unnecessary relationship loading, slow external APIs, and no caching.

## Q8. How do you debug slow queries?

**Answer:**

Use Laravel Debugbar, Telescope, query logs, database `EXPLAIN`, slow query logs, and check missing indexes or N+1 queries.

---

# 7. Laravel Version Differences

## Q1. What Laravel versions are commonly seen in projects?

**Answer:**

Many companies still use Laravel 8, 9, 10, or 11 depending on project age. Laravel 10 and 11 are more modern. Laravel 8/9 are common in older production systems.

## Q2. Laravel 8 vs Laravel 9?

**Answer:**

| Laravel 8                     | Laravel 9                                |
| ----------------------------- | ---------------------------------------- |
| Older LTS-style generation    | Requires newer PHP versions              |
| Common in legacy systems      | Improved Symfony components              |
| Uses older default structures | Better performance and framework updates |

The main interview point: Laravel 9 modernized dependencies and required newer PHP compared to Laravel 8.

## Q3. Laravel 9 vs Laravel 10?

**Answer:**

Laravel 10 introduced stronger type declarations in skeleton code, newer dependency versions, and continued framework cleanup. The developer experience is similar, but Laravel 10 expects more modern PHP practices.

## Q4. Laravel 10 vs Laravel 11?

**Answer:**

Laravel 11 simplified the application structure. Some default files are reduced, middleware and exception configuration are more centralized, and the framework skeleton is cleaner.

## Q5. If company uses older Laravel, can you work on it?

**Answer:**

Yes. Laravel concepts are mostly stable: routes, controllers, middleware, Eloquent, migrations, validation, jobs, events, and queues. I would first check the Laravel version, PHP version, package compatibility, coding style, and existing architecture before making changes.

## Q6. What should you check before upgrading Laravel?

**Answer:**

Check PHP version, composer dependencies, breaking changes, package compatibility, deprecated APIs, test coverage, config changes, authentication packages, queue workers, deployment pipeline, and database migration safety.

---

# 8. Raw PHP Interview Questions

## Q1. What is PHP?

**Answer:**

PHP is a server-side scripting language mainly used for web development. It can generate dynamic pages, handle form submissions, interact with databases, process files, and build APIs.

## Q2. Difference between `echo` and `print`?

**Answer:**

`echo` can output one or more strings and does not return a value.

`print` outputs one string and returns 1.

In practice, both are used for output, but `echo` is slightly more common.

## Q3. Difference between `include`, `require`, `include_once`, and `require_once`?

**Answer:**

| Function       | Behavior                                            |
| -------------- | --------------------------------------------------- |
| `include`      | Includes file, warning if missing, script continues |
| `require`      | Includes file, fatal error if missing, script stops |
| `include_once` | Includes only once                                  |
| `require_once` | Requires only once                                  |

## Q4. Difference between `==` and `===` in PHP?

**Answer:**

`==` compares values after type conversion.

`===` compares both value and type.

```php
'5' == 5;   // true
'5' === 5;  // false
```

## Q5. What is type juggling in PHP?

**Answer:**

Type juggling means PHP automatically converts variables from one type to another during operations or comparisons. It can cause unexpected bugs, so strict comparison `===` is preferred.

## Q6. What are PHP superglobals?

**Answer:**

Superglobals are built-in global arrays available everywhere.

Examples:

| Superglobal | Purpose                  |
| ----------- | ------------------------ |
| `$_GET`     | Query parameters         |
| `$_POST`    | Form data                |
| `$_REQUEST` | GET/POST/Cookie combined |
| `$_SESSION` | Session data             |
| `$_COOKIE`  | Cookie data              |
| `$_SERVER`  | Server/request info      |
| `$_FILES`   | Uploaded files           |

## Q7. What is session in PHP?

**Answer:**

A session stores user data on the server across multiple requests. The browser usually stores only a session ID cookie.

```php
session_start();
$_SESSION['user_id'] = 10;
```

## Q8. What is a cookie?

**Answer:**

A cookie stores small data in the user’s browser. It is often used for preferences, tracking, or session IDs.

## Q9. Session vs Cookie?

**Answer:**

| Session                        | Cookie                  |
| ------------------------------ | ----------------------- |
| Stored on server               | Stored in browser       |
| More secure for sensitive data | Can be modified by user |
| Uses session ID                | Has expiry and value    |

## Q10. How do you connect raw PHP with MySQL?

**Answer:**

Use PDO or MySQLi. PDO is often preferred because it supports prepared statements and multiple databases.

```php
$pdo = new PDO('mysql:host=localhost;dbname=test', 'root', '');
```

## Q11. What are prepared statements?

**Answer:**

Prepared statements separate SQL logic from user input. They prevent SQL injection.

```php
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
```

## Q12. What is Composer?

**Answer:**

Composer is PHP’s dependency manager. It installs packages and manages autoloading.

```bash
composer install
composer require guzzlehttp/guzzle
```

## Q13. What is PSR?

**Answer:**

PSR means PHP Standards Recommendation. It defines coding standards like autoloading, coding style, logging interfaces, and HTTP message interfaces.

## Q14. What is autoloading in PHP?

**Answer:**

Autoloading automatically loads PHP classes when they are used, instead of manually requiring every file.

Composer provides PSR-4 autoloading.

## Q15. What is namespace in PHP?

**Answer:**

Namespace organizes classes and avoids name conflicts.

```php
namespace App\Services;

class PaymentService {}
```

## Q16. What is trait in PHP?

**Answer:**

A trait allows code reuse in multiple classes without inheritance.

```php
trait HasUuid {
    public function generateUuid() {}
}
```

## Q17. What is the difference between abstract class and interface?

**Answer:**

| Abstract Class                   | Interface                               |
| -------------------------------- | --------------------------------------- |
| Can contain implemented methods  | Defines contract for methods            |
| Can have properties              | Usually no instance properties          |
| Class extends one abstract class | Class can implement multiple interfaces |

## Q18. What is late static binding?

**Answer:**

Late static binding uses `static::` to refer to the called class at runtime, not the class where the method is defined.

## Q19. What are magic methods in PHP?

**Answer:**

Magic methods are special methods starting with double underscores.

Examples: `__construct`, `__destruct`, `__get`, `__set`, `__call`, `__toString`.

## Q20. How do you handle errors in PHP?

**Answer:**

Use exceptions, try-catch blocks, logging, and proper error reporting configuration.

```php
try {
    // code
} catch (Exception $e) {
    error_log($e->getMessage());
}
```

---

# 9. Vue.js Core Questions

## Q1. What is Vue.js?

**Answer:**

Vue.js is a progressive JavaScript framework for building user interfaces. It is component-based, reactive, and easy to integrate with APIs.

## Q2. What is Vue component?

**Answer:**

A component is a reusable UI block with its own template, logic, props, state, events, and styles.

## Q3. What is Single File Component?

**Answer:**

A Single File Component is a `.vue` file that contains template, script, and style in one file.

```vue
<template>
  <h1>{{ title }}</h1>
</template>

<script setup>
const title = "Hello Vue";
</script>

<style scoped>
h1 {
  color: green;
}
</style>
```

## Q4. What is reactivity in Vue?

**Answer:**

Reactivity means Vue automatically updates the UI when data changes.

```js
const count = ref(0);
count.value++;
```

## Q5. Difference between `ref()` and `reactive()`?

**Answer:**

| `ref()`                               | `reactive()`                 |
| ------------------------------------- | ---------------------------- |
| Used for primitive or object values   | Used mainly for objects      |
| Access value using `.value` in script | Direct property access       |
| Works well for single values          | Works well for grouped state |

```js
const name = ref("John");
const user = reactive({ name: "John", age: 25 });
```

## Q6. What is `computed`?

**Answer:**

`computed` is used for derived values. It is cached until its dependencies change.

```js
const fullName = computed(() => firstName.value + " " + lastName.value);
```

## Q7. What is `watch`?

**Answer:**

`watch` runs code when a reactive value changes. It is useful for API calls, side effects, or reacting to form changes.

```js
watch(search, () => {
  fetchProducts();
});
```

## Q8. Difference between `computed` and `watch`?

**Answer:**

`computed` returns a derived value and is cached.

`watch` performs side effects when data changes.

Use `computed` for values, use `watch` for actions.

## Q9. What are props?

**Answer:**

Props pass data from parent component to child component.

```vue
<UserCard :user="user" />
```

## Q10. What are emits?

**Answer:**

Emits send events from child component to parent component.

```js
const emit = defineEmits(["save"]);
emit("save", formData);
```

## Q11. What is `v-model`?

**Answer:**

`v-model` creates two-way binding between form input and state.

```vue
<input v-model="name" />
```

## Q12. What is `v-if` vs `v-show`?

**Answer:**

| `v-if`                             | `v-show`                               |
| ---------------------------------- | -------------------------------------- |
| Adds/removes element from DOM      | Uses CSS display none/block            |
| Better for rarely toggled elements | Better for frequently toggled elements |

## Q13. What is `v-for`?

**Answer:**

`v-for` loops over arrays or objects to render repeated elements.

```vue
<li v-for="user in users" :key="user.id">{{ user.name }}</li>
```

## Q14. Why is `key` important in `v-for`?

**Answer:**

`key` helps Vue track each item correctly and update the DOM efficiently. Without a proper key, rendering bugs can happen.

## Q15. What is lifecycle hook?

**Answer:**

Lifecycle hooks run at different stages of a component’s life, such as creation, mounting, updating, and unmounting.

Common Vue 3 hooks:

```js
onMounted(() => {});
onUpdated(() => {});
onUnmounted(() => {});
```

## Q16. What is Vue Router?

**Answer:**

Vue Router manages navigation between pages/components in a Vue single-page application.

## Q17. What is Pinia?

**Answer:**

Pinia is the recommended state management library for Vue. It stores shared state across components.

## Q18. Vuex vs Pinia?

**Answer:**

| Vuex                         | Pinia                         |
| ---------------------------- | ----------------------------- |
| Older official state library | New recommended state library |
| More boilerplate             | Simpler API                   |
| Mutations/actions structure  | Direct state changes allowed  |

## Q19. How do you call API in Vue?

**Answer:**

Usually using Axios or Fetch.

```js
const response = await axios.get("/api/products");
products.value = response.data.data;
```

## Q20. How do you handle loading and error state?

**Answer:**

Use separate reactive variables.

```js
const loading = ref(false);
const error = ref(null);

async function fetchData() {
  loading.value = true;
  error.value = null;
  try {
    const res = await axios.get("/api/products");
    products.value = res.data.data;
  } catch (e) {
    error.value = "Failed to load products";
  } finally {
    loading.value = false;
  }
}
```

---

# 10. Vue Version Differences

## Q1. Vue 2 vs Vue 3 main differences?

**Answer:**

| Vue 2                                            | Vue 3                            |
| ------------------------------------------------ | -------------------------------- |
| Options API is primary                           | Composition API introduced       |
| Uses `new Vue()`                                 | Uses `createApp()`               |
| Vuex commonly used                               | Pinia recommended                |
| Reactivity based mainly on Object.defineProperty | Reactivity uses Proxy            |
| Limited TypeScript support                       | Better TypeScript support        |
| Single root element required                     | Multiple root elements supported |

## Q2. What is Options API?

**Answer:**

Options API organizes component logic into options like `data`, `methods`, `computed`, and `watch`.

```js
export default {
  data() {
    return { count: 0 };
  },
  methods: {
    increment() {
      this.count++;
    },
  },
};
```

## Q3. What is Composition API?

**Answer:**

Composition API allows organizing logic by feature using `setup()`, `ref`, `reactive`, `computed`, and composables.

```js
const count = ref(0);
const increment = () => count.value++;
```

## Q4. Options API vs Composition API?

**Answer:**

| Options API                | Composition API          |
| -------------------------- | ------------------------ |
| Easier for beginners       | Better for complex logic |
| Logic split by option type | Logic grouped by feature |
| Uses `this`                | Avoids `this`            |
| Less TypeScript-friendly   | More TypeScript-friendly |

## Q5. What is `<script setup>`?

**Answer:**

`<script setup>` is a Vue 3 syntax that makes Composition API simpler and cleaner. Variables and functions declared inside it are directly available in the template.

## Q6. What is Teleport in Vue 3?

**Answer:**

Teleport renders a component’s HTML outside its normal DOM hierarchy. It is useful for modals, dialogs, and dropdowns.

## Q7. What is Fragment in Vue 3?

**Answer:**

Vue 3 supports multiple root elements in a component. This is called Fragment support.

## Q8. What is Suspense in Vue 3?

**Answer:**

Suspense helps handle async components and loading states. It can show fallback content while async setup is loading.

## Q9. How would you migrate Vue 2 to Vue 3?

**Answer:**

I would check dependencies, upgrade Vue Router and Vuex/Pinia, replace `new Vue()` with `createApp()`, test components, gradually introduce Composition API, fix breaking changes, and run regression testing.

## Q10. What should you say if they ask: “Do you know Vue 3?”

**Answer:**

Yes, I understand Vue 3 concepts like Composition API, `ref`, `reactive`, `computed`, `watch`, lifecycle hooks, `<script setup>`, component props/emits, Vue Router, and Pinia. I can build CRUD screens and integrate them with Laravel REST APIs.

---

# 11. JavaScript and TypeScript Questions

## Q1. Difference between `var`, `let`, and `const`?

**Answer:**

| Keyword | Scope          | Reassignable | Notes                     |
| ------- | -------------- | ------------ | ------------------------- |
| `var`   | Function scope | Yes          | Hoisted, older style      |
| `let`   | Block scope    | Yes          | Modern variable           |
| `const` | Block scope    | No           | Cannot reassign reference |

## Q2. What is hoisting?

**Answer:**

Hoisting means JavaScript moves declarations to the top of their scope during compilation. `var` is hoisted with `undefined`, while `let` and `const` are hoisted but not accessible before declaration due to temporal dead zone.

## Q3. What is closure?

**Answer:**

A closure is when a function remembers variables from its outer scope even after the outer function has finished executing.

```js
function counter() {
  let count = 0;
  return function () {
    count++;
    return count;
  };
}
```

## Q4. What is promise?

**Answer:**

A Promise represents a future value from an asynchronous operation. It can be pending, fulfilled, or rejected.

## Q5. `async/await` vs Promise `.then()`?

**Answer:**

Both handle asynchronous code. `async/await` makes async code look cleaner and easier to read.

## Q6. What is event loop?

**Answer:**

The event loop allows JavaScript to handle asynchronous operations despite being single-threaded. It manages the call stack, callback queue, microtask queue, and execution order.

## Q7. What is destructuring?

**Answer:**

Destructuring extracts values from arrays or objects.

```js
const { name, age } = user;
const [first, second] = items;
```

## Q8. What is spread operator?

**Answer:**

Spread expands arrays or objects.

```js
const newUser = { ...user, status: "active" };
```

## Q9. What is REST operator?

**Answer:**

Rest collects remaining values.

```js
function sum(...numbers) {}
```

## Q10. What is TypeScript?

**Answer:**

TypeScript is JavaScript with static typing. It helps catch errors during development and improves code maintainability.

## Q11. Why use TypeScript with Vue?

**Answer:**

TypeScript improves type safety for props, API responses, store data, function parameters, and large codebases.

## Q12. What is interface in TypeScript?

**Answer:**

An interface defines the shape of an object.

```ts
interface User {
  id: number;
  name: string;
}
```

## Q13. Type vs Interface?

**Answer:**

Both define types. Interfaces are commonly used for object shapes and can be extended. Type aliases are more flexible for unions, intersections, and primitives.

## Q14. What is optional chaining?

**Answer:**

Optional chaining safely accesses nested properties.

```js
user?.profile?.email;
```

## Q15. What is nullish coalescing?

**Answer:**

`??` returns the right value only when the left value is `null` or `undefined`.

```js
const name = user.name ?? "Unknown";
```

---

# 12. REST API Questions

## Q1. What is REST API?

**Answer:**

REST API is an architectural style for building APIs using HTTP methods, resources, status codes, and stateless communication.

## Q2. Common HTTP methods?

**Answer:**

| Method | Purpose             |
| ------ | ------------------- |
| GET    | Read data           |
| POST   | Create data         |
| PUT    | Replace/update data |
| PATCH  | Partial update      |
| DELETE | Delete data         |

## Q3. PUT vs PATCH?

**Answer:**

PUT usually replaces the full resource.

PATCH updates only selected fields.

## Q4. What is stateless API?

**Answer:**

Stateless means each request contains all information needed to process it. The server does not depend on previous request state.

## Q5. What is API versioning?

**Answer:**

API versioning allows changes without breaking existing clients.

Example:

```text
/api/v1/products
/api/v2/products
```

## Q6. What makes a good REST API response?

**Answer:**

A good response is consistent, clear, uses proper status codes, returns useful messages, and does not expose sensitive data.

Example:

```json
{
  "success": true,
  "message": "Product created successfully",
  "data": {
    "id": 1,
    "name": "Laptop"
  }
}
```

## Q7. How do you handle validation errors in API?

**Answer:**

Return HTTP 422 with field-specific error messages.

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "email": ["The email field is required."]
  }
}
```

## Q8. What is CORS?

**Answer:**

CORS controls which domains can access APIs from browsers. It is important when frontend and backend run on different domains or ports.

## Q9. What is idempotency?

**Answer:**

An operation is idempotent if repeating the same request produces the same result. GET, PUT, and DELETE are usually idempotent. POST is usually not.

## Q10. How do you secure REST APIs?

**Answer:**

Use HTTPS, authentication tokens, authorization checks, input validation, rate limiting, proper CORS, secure error handling, and avoid exposing sensitive fields.

---

# 13. SQL and MySQL Common Questions

## Q1. What is SQL?

**Answer:**

SQL means Structured Query Language. It is used to store, retrieve, update, and manage data in relational databases.

## Q2. What is primary key?

**Answer:**

A primary key uniquely identifies each row in a table. It cannot be null and should be unique.

## Q3. What is foreign key?

**Answer:**

A foreign key connects one table to another table’s primary key. It enforces referential integrity.

## Q4. What is index?

**Answer:**

An index improves query performance by allowing the database to find rows faster. But too many indexes can slow down insert/update/delete operations.

## Q5. What columns should be indexed?

**Answer:**

Columns frequently used in `WHERE`, `JOIN`, `ORDER BY`, and foreign keys should often be indexed.

## Q6. What is normalization?

**Answer:**

Normalization organizes data to reduce duplication and improve consistency.

## Q7. What is denormalization?

**Answer:**

Denormalization intentionally adds some duplicate data to improve read performance, usually in reporting or high-read systems.

## Q8. What are common SQL joins?

**Answer:**

| Join       | Meaning                                            |
| ---------- | -------------------------------------------------- |
| INNER JOIN | Matching records from both tables                  |
| LEFT JOIN  | All left table records plus matching right records |
| RIGHT JOIN | All right table records plus matching left records |
| FULL JOIN  | All records from both sides, if supported          |

## Q9. INNER JOIN vs LEFT JOIN?

**Answer:**

INNER JOIN returns only matching rows.

LEFT JOIN returns all rows from the left table, even if no matching row exists on the right side.

## Q10. What is GROUP BY?

**Answer:**

GROUP BY groups rows based on column values, usually with aggregate functions.

```sql
SELECT status, COUNT(*)
FROM orders
GROUP BY status;
```

## Q11. WHERE vs HAVING?

**Answer:**

`WHERE` filters rows before grouping.

`HAVING` filters grouped results after aggregation.

```sql
SELECT customer_id, COUNT(*)
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 5;
```

## Q12. What is aggregate function?

**Answer:**

Aggregate functions calculate values from multiple rows.

Examples: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`.

## Q13. What is transaction?

**Answer:**

A transaction groups multiple database operations into one unit. Either all succeed or all fail.

## Q14. What are ACID properties?

**Answer:**

| Property    | Meaning                                       |
| ----------- | --------------------------------------------- |
| Atomicity   | All operations succeed or rollback            |
| Consistency | Database remains valid                        |
| Isolation   | Transactions do not wrongly affect each other |
| Durability  | Committed data is saved permanently           |

## Q15. What is rollback?

**Answer:**

Rollback cancels changes made during a transaction if something fails.

## Q16. What is commit?

**Answer:**

Commit permanently saves transaction changes.

## Q17. What is deadlock?

**Answer:**

A deadlock happens when two transactions wait for each other’s locks and neither can continue. Databases usually detect and stop one transaction.

## Q18. How do you avoid deadlocks?

**Answer:**

Keep transactions short, access tables in the same order, use proper indexes, avoid unnecessary locks, and retry failed transactions when appropriate.

## Q19. What is query optimization?

**Answer:**

Query optimization means improving SQL performance by using indexes, avoiding unnecessary columns, filtering early, optimizing joins, using pagination, and analyzing execution plans.

## Q20. What is `EXPLAIN`?

**Answer:**

`EXPLAIN` shows how the database plans to execute a query. It helps identify full table scans, missing indexes, and join issues.

## Q21. Difference between DELETE, TRUNCATE, and DROP?

**Answer:**

| Command  | Meaning                                     |
| -------- | ------------------------------------------- |
| DELETE   | Deletes selected rows, can use WHERE        |
| TRUNCATE | Removes all rows quickly, resets table data |
| DROP     | Deletes the entire table structure          |

## Q22. What is unique constraint?

**Answer:**

A unique constraint ensures that values in a column or group of columns are not duplicated.

## Q23. What is composite key?

**Answer:**

A composite key uses multiple columns together to uniquely identify a record.

## Q24. What is one-to-many database relationship?

**Answer:**

One record in a table can be related to many records in another table. Example: one customer has many orders.

## Q25. What is many-to-many database relationship?

**Answer:**

Many records in one table relate to many records in another table. Example: users and roles. It requires a junction table.

## Q26. How do you design product and category tables?

**Answer:**

Simple one-to-many design:

```text
categories
- id
- name

products
- id
- category_id
- name
- price
```

A category has many products. A product belongs to one category.

## Q27. How do you design order tables?

**Answer:**

Use separate order header and order items tables.

```text
orders
- id
- customer_id
- total_amount
- status
- created_at

order_items
- id
- order_id
- product_id
- quantity
- unit_price
- subtotal
```

This avoids repeating order-level data for every item.

## Q28. How do you store money in database?

**Answer:**

Use `DECIMAL`, not floating point, because money requires exact precision.

```sql
price DECIMAL(10,2)
```

## Q29. What is database migration in Laravel?

**Answer:**

Migration is a PHP file that creates or modifies database schema. It keeps schema changes version-controlled.

## Q30. What is the difference between MySQL and PostgreSQL?

**Answer:**

Both are relational databases. MySQL is widely used with PHP/Laravel and is simple and fast for many web apps. PostgreSQL is often stronger for advanced queries, strict data integrity, JSONB, indexing options, and complex database workloads.

For this job, MySQL is more important because the job post mentions relational databases like MySQL.

---

# 14. Practical SQL Questions with Answers

## Q1. Find all active users.

```sql
SELECT * FROM users WHERE status = 'active';
```

## Q2. Find users created in the last 7 days.

```sql
SELECT *
FROM users
WHERE created_at >= NOW() - INTERVAL 7 DAY;
```

## Q3. Count orders by status.

```sql
SELECT status, COUNT(*) AS total
FROM orders
GROUP BY status;
```

## Q4. Find customers with more than 5 orders.

```sql
SELECT customer_id, COUNT(*) AS total_orders
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 5;
```

## Q5. Get order list with customer name.

```sql
SELECT o.id, o.total_amount, o.status, c.name AS customer_name
FROM orders o
JOIN customers c ON c.id = o.customer_id;
```

## Q6. Find products that were never ordered.

```sql
SELECT p.*
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.id
WHERE oi.id IS NULL;
```

## Q7. Get total sales by date.

```sql
SELECT DATE(created_at) AS sale_date, SUM(total_amount) AS total_sales
FROM orders
WHERE status = 'paid'
GROUP BY DATE(created_at)
ORDER BY sale_date DESC;
```

## Q8. Get top 5 selling products.

```sql
SELECT p.name, SUM(oi.quantity) AS total_quantity
FROM order_items oi
JOIN products p ON p.id = oi.product_id
GROUP BY p.id, p.name
ORDER BY total_quantity DESC
LIMIT 5;
```

## Q9. Update product price.

```sql
UPDATE products
SET price = 500
WHERE id = 1;
```

## Q10. Delete inactive users.

```sql
DELETE FROM users
WHERE status = 'inactive';
```

---

# 15. Full-Stack Laravel + Vue Practical Questions

## Q1. How would you build a product CRUD feature?

**Answer:**

I would first design the `products` table with fields like id, name, category_id, price, stock, status, and timestamps. Then I would create a Laravel model, migration, controller, request validation, and API routes. I would return API responses using resources. On the Vue side, I would create a product list page, create/edit form, validation messages, API service using Axios, loading state, error state, and success notifications.

## Q2. How would you build search and pagination?

**Answer:**

In Laravel, I would accept query parameters like `search`, `page`, and `per_page`. I would apply conditional `where` clauses and return paginated data. In Vue, I would bind the search input, call the API when search changes or when the user clicks search, and render pagination controls based on backend metadata.

Laravel example:

```php
$query = Product::query();

if ($request->filled('search')) {
    $query->where('name', 'like', '%' . $request->search . '%');
}

return ProductResource::collection($query->paginate(20));
```

## Q3. How would you handle form validation from Laravel to Vue?

**Answer:**

Laravel returns validation errors with HTTP 422. In Vue, I would catch the error and map `error.response.data.errors` to the form fields.

## Q4. How do you structure frontend API calls?

**Answer:**

I prefer creating a separate API service file instead of writing Axios directly in every component.

```js
export function getProducts(params) {
  return axios.get("/products", { params });
}
```

## Q5. How would you handle authentication in Laravel + Vue?

**Answer:**

Use Laravel Sanctum or token authentication. After login, Vue stores the token securely depending on the architecture. Every protected API call includes the token. Laravel middleware validates the token and returns the authenticated user.

## Q6. How do you handle unauthorized API response in Vue?

**Answer:**

If API returns 401, I would clear user state/token and redirect to login.

## Q7. How would you prevent duplicate form submit?

**Answer:**

Use a loading/submitting flag. Disable the button while the request is running.

```vue
<button :disabled="submitting">Save</button>
```

## Q8. How would you debug a form that does not save?

**Answer:**

I would check browser console, network request payload, API response, Laravel logs, validation errors, route/controller method, database query, and whether the frontend field names match backend validation rules.

## Q9. How would you optimize a slow product list page?

**Answer:**

Use pagination, backend filtering, database indexes, eager loading, avoid loading unnecessary relationships, return only required fields, debounce search input, and avoid unnecessary frontend re-renders.

## Q10. How would you design roles and permissions?

**Answer:**

Use tables like users, roles, permissions, role_user, and permission_role. In Laravel, I can use policies, gates, middleware, or a package like Spatie Permission.

---

# 16. Debugging Questions

## Q1. Laravel returns 500 error. What do you check?

**Answer:**

Check Laravel logs in `storage/logs/laravel.log`, environment config, database connection, exception message, stack trace, recent code changes, missing class/import, migration status, and request payload.

## Q2. API returns 404. What do you check?

**Answer:**

Check route definition, HTTP method, URL prefix, route cache, controller namespace, parameter value, and whether route is in `api.php` or `web.php`.

## Q3. API returns 419. What does it mean?

**Answer:**

In Laravel, 419 often means CSRF token mismatch for web routes. For APIs, routes should usually be in `api.php` or configured properly.

## Q4. API returns 422. What does it mean?

**Answer:**

422 means validation failed. Check validation rules and request payload fields.

## Q5. Vue page is blank. What do you check?

**Answer:**

Check browser console errors, build errors, component imports, route configuration, API errors, undefined variables in template, and runtime exceptions.

## Q6. Vue API call blocked by CORS. What do you check?

**Answer:**

Check Laravel CORS config, allowed origins, frontend URL, request method, headers, and preflight OPTIONS request.

## Q7. Data exists in database but not showing in frontend. What do you check?

**Answer:**

Check API response in Network tab, backend query filters, resource transformation, frontend property names, pagination data path, and conditional rendering.

## Q8. Why is login working in Postman but not browser?

**Answer:**

Possible causes: CORS issue, CSRF issue, cookie domain mismatch, missing credentials flag, wrong frontend base URL, or missing Authorization header.

## Q9. How do you debug SQL query in Laravel?

**Answer:**

Use query logging, Laravel Debugbar, Telescope, `toSql()`, `DB::listen()`, or database slow query logs.

## Q10. How do you debug production issue safely?

**Answer:**

Check logs first, reproduce carefully, avoid changing data manually without backup, identify exact request/user/time, inspect recent deployments, add temporary safe logs if needed, and create a minimal fix with testing.

---

# 17. OOP and Design Questions

## Q1. What are the four pillars of OOP?

**Answer:**

Encapsulation, abstraction, inheritance, and polymorphism.

## Q2. What is encapsulation?

**Answer:**

Encapsulation hides internal data and exposes controlled methods to interact with it.

## Q3. What is abstraction?

**Answer:**

Abstraction hides implementation details and exposes only necessary behavior.

## Q4. What is inheritance?

**Answer:**

Inheritance allows one class to reuse or extend another class’s properties and methods.

## Q5. What is polymorphism?

**Answer:**

Polymorphism allows different classes to implement the same interface or method differently.

## Q6. What is SOLID?

**Answer:**

SOLID is a set of object-oriented design principles.

| Letter | Principle             |
| ------ | --------------------- |
| S      | Single Responsibility |
| O      | Open/Closed           |
| L      | Liskov Substitution   |
| I      | Interface Segregation |
| D      | Dependency Inversion  |

## Q7. What is Single Responsibility Principle?

**Answer:**

A class should have one main responsibility and one reason to change.

## Q8. Why use service classes in Laravel?

**Answer:**

Service classes keep business logic outside controllers. Controllers should handle request/response, while services handle business rules.

## Q9. What is repository pattern?

**Answer:**

Repository pattern separates database access logic from business logic. It makes the code more testable and maintainable, but should not be overused in simple Laravel apps.

## Q10. What is DTO?

**Answer:**

DTO means Data Transfer Object. It carries structured data between layers without exposing raw request or model objects everywhere.

---

# 18. Git and Teamwork Questions

## Q1. What is Git?

**Answer:**

Git is a version control system used to track code changes and collaborate with other developers.

## Q2. Git pull vs fetch?

**Answer:**

`git fetch` downloads remote changes but does not merge them.

`git pull` downloads and merges changes into the current branch.

## Q3. Merge vs rebase?

**Answer:**

Merge combines branches and keeps history with merge commits.

Rebase moves commits on top of another branch and creates a cleaner linear history.

## Q4. How do you resolve merge conflict?

**Answer:**

Open conflicted files, choose correct changes, remove conflict markers, test the code, add files, and commit.

## Q5. What is pull request?

**Answer:**

A pull request is a request to merge code into another branch after review.

## Q6. What should a good commit message look like?

**Answer:**

It should clearly describe what changed.

Example:

```text
Fix product search filter validation
Add product pagination API
Refactor order total calculation
```

## Q7. What do you do before pushing code?

**Answer:**

Run the project, test the feature, check formatting, run tests if available, review changed files, and ensure no secrets or debug code are committed.

---

# 19. Critical Laravel Coding Tasks They May Ask

## Task 1. Create a REST API endpoint to store product.

**Answer:**

```php
Route::post('/products', [ProductController::class, 'store']);

class ProductController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'stock' => 'required|integer|min:0',
        ]);

        $product = Product::create($validated);

        return response()->json([
            'message' => 'Product created successfully',
            'data' => $product
        ], 201);
    }
}
```

## Task 2. Write product search query.

```php
public function index(Request $request)
{
    $products = Product::query()
        ->when($request->search, function ($query, $search) {
            $query->where('name', 'like', "%{$search}%");
        })
        ->when($request->category_id, function ($query, $categoryId) {
            $query->where('category_id', $categoryId);
        })
        ->latest()
        ->paginate(20);

    return response()->json($products);
}
```

## Task 3. Use transaction for order creation.

```php
DB::transaction(function () use ($request) {
    $order = Order::create([
        'customer_id' => $request->customer_id,
        'total_amount' => 0,
        'status' => 'pending',
    ]);

    $total = 0;

    foreach ($request->items as $item) {
        $product = Product::findOrFail($item['product_id']);
        $subtotal = $product->price * $item['quantity'];
        $total += $subtotal;

        $order->items()->create([
            'product_id' => $product->id,
            'quantity' => $item['quantity'],
            'unit_price' => $product->price,
            'subtotal' => $subtotal,
        ]);
    }

    $order->update(['total_amount' => $total]);
});
```

## Task 4. Prevent N+1 query.

Bad:

```php
$orders = Order::all();
foreach ($orders as $order) {
    echo $order->customer->name;
}
```

Good:

```php
$orders = Order::with('customer')->get();
```

## Task 5. Create Vue API call with loading state.

```vue
<script setup>
import { ref, onMounted } from "vue";
import axios from "axios";

const products = ref([]);
const loading = ref(false);
const error = ref(null);

async function fetchProducts() {
  loading.value = true;
  error.value = null;

  try {
    const response = await axios.get("/api/products");
    products.value = response.data.data;
  } catch (e) {
    error.value = "Failed to load products";
  } finally {
    loading.value = false;
  }
}

onMounted(fetchProducts);
</script>
```

---

# 20. Common HR + Technical Mixed Questions

## Q1. Are you comfortable working on-site?

**Answer:**

Yes, I am comfortable working on-site. I think for a full-stack role, close communication with the team helps clarify requirements and deliver faster.

## Q2. Are you comfortable working independently?

**Answer:**

Yes. I can take a requirement, break it into backend, database, and frontend tasks, then implement and test it. At the same time, I communicate when I need clarification.

## Q3. How do you handle a task you do not understand?

**Answer:**

First, I clarify the business requirement. Then I check existing code patterns, database structure, and related APIs. If still unclear, I ask specific questions instead of making risky assumptions.

## Q4. How do you handle deadline pressure?

**Answer:**

I break the task into smaller parts, prioritize the core functionality first, communicate risks early, and avoid overengineering. After the main feature works, I improve edge cases and code quality.

## Q5. How do you work with senior developers?

**Answer:**

I listen carefully, ask focused questions, follow project standards, accept code review feedback, and try to understand the reasoning behind architectural decisions.

## Q6. What do you do when you disagree with a technical decision?

**Answer:**

I explain my concern with technical reasoning, listen to the other perspective, and focus on what is best for the project. If the team decides differently, I follow the team decision professionally.

## Q7. What is your expected salary?

**Answer:**

The job post mentions BDT 40,000–50,000. Based on my skills and experience, I am open to discussion within that range depending on responsibilities, growth opportunity, and overall benefits.

---

# 21. Must-Know Short Questions

## Laravel Short Answers

| Question                     | Answer                                               |
| ---------------------------- | ---------------------------------------------------- |
| What is Artisan?             | Laravel command-line tool                            |
| What is `.env`?              | Environment configuration file                       |
| What is config cache?        | Cached config for faster production loading          |
| What is route cache?         | Cached route definitions                             |
| What is policy?              | Authorization logic for models/actions               |
| What is gate?                | Closure/class-based authorization check              |
| What is event?               | Something that happened in the app                   |
| What is listener?            | Handles an event                                     |
| What is queue worker?        | Process that runs queued jobs                        |
| What is observer?            | Listens to model events like created/updated/deleted |
| What is collection?          | Laravel wrapper around arrays with useful methods    |
| What is resource controller? | Controller with standard CRUD methods                |

## Vue Short Answers

| Question              | Answer                                        |
| --------------------- | --------------------------------------------- |
| What is component?    | Reusable UI block                             |
| What is prop?         | Parent-to-child data                          |
| What is emit?         | Child-to-parent event                         |
| What is Pinia?        | Vue state management library                  |
| What is router guard? | Navigation control logic                      |
| What is computed?     | Cached derived value                          |
| What is watcher?      | Side-effect on data change                    |
| What is directive?    | Special Vue attribute like `v-if` or `v-for`  |
| What is slot?         | Content passed from parent to child component |
| What is composable?   | Reusable Composition API logic function       |

## SQL Short Answers

| Question      | Answer                                        |
| ------------- | --------------------------------------------- |
| Primary key   | Unique row identifier                         |
| Foreign key   | Reference to another table                    |
| Index         | Speeds up lookup                              |
| Transaction   | Group of DB operations                        |
| ACID          | Atomicity, Consistency, Isolation, Durability |
| Join          | Combines rows from tables                     |
| Group by      | Groups rows for aggregation                   |
| Having        | Filters grouped data                          |
| Explain       | Shows query execution plan                    |
| Normalization | Reduces duplication                           |

---

# 22. Scenario-Based Questions

## Q1. A page is loading slowly. What will you do?

**Answer:**

I will check whether the slowness is from frontend, backend, database, or network. I will inspect browser Network tab, API response time, Laravel logs, query count, database indexes, and payload size. Then I will optimize based on the cause: pagination, eager loading, query indexes, caching, or reducing frontend re-rendering.

## Q2. A user says data disappeared after update. What will you check?

**Answer:**

I will check request payload, validation, update logic, mass assignment fields, database transaction, frontend form binding, and logs. I will also check whether the update endpoint overwrites fields with null because the frontend sent partial data incorrectly.

## Q3. Product search works locally but not in production. What can be wrong?

**Answer:**

Possible causes include different database collation, missing index, wrong environment variables, route cache/config cache issue, different API base URL, deployment mismatch, or old frontend build.

## Q4. API works in Postman but Vue shows CORS error. What is wrong?

**Answer:**

Postman does not enforce browser CORS policy, but browsers do. So Laravel CORS configuration or allowed origin/header/method may be wrong.

## Q5. How do you safely change an existing feature?

**Answer:**

I first understand current behavior, check related APIs/components/tables, make a minimal change, test existing flows, verify edge cases, and avoid breaking request/response contracts unless required.

---

# 23. Questions You Can Ask the Interviewer

Ask 2–3 good questions near the end.

1. What kind of projects will this developer mainly work on: eCommerce, custom ERP, dashboard, or client-specific systems?
2. Is the frontend mostly Vue 3 Composition API or Options API?
3. Do you use Laravel Sanctum, Passport, or another authentication system?
4. How does the team handle code review and deployment?
5. Are there existing coding standards for API response format and frontend structure?
6. What are the main technical challenges the team is currently solving?

---

# 24. Final 2-Day Preparation Plan

## Day 1 — Backend Heavy

Study:

- Laravel MVC
- Routes, controllers, middleware
- Eloquent relationships
- Validation and API resources
- Authentication basics
- SQL joins, indexes, transactions
- N+1 query and eager loading

Practice:

- Build a product CRUD API
- Add search and pagination
- Write SQL joins manually
- Explain transaction-based order creation

## Day 2 — Frontend + Full Stack

Study:

- Vue 3 Composition API
- `ref`, `reactive`, `computed`, `watch`
- Props and emits
- Vue Router
- Pinia basics
- Axios API integration
- Loading/error states

Practice:

- Build a product list page
- Create product form
- Show Laravel validation errors in Vue
- Explain debugging workflow

---

# 25. Final Interview Checklist

Before the interview, make sure you can explain:

- Laravel MVC flow
- Eloquent relationships
- Migration and validation
- REST API status codes
- Sanctum/token authentication
- SQL joins and indexes
- Transactions and ACID
- Vue 2 vs Vue 3
- Options API vs Composition API
- `ref` vs `reactive`
- `computed` vs `watch`
- Axios API integration
- Debugging Laravel 500/422/404 errors
- Debugging Vue blank page/CORS/API errors
- How to build a CRUD feature end-to-end

---

# 26. Emergency Quick Revision

## Backend explanation in one line

Laravel receives a request through route, sends it to controller, validates it, uses service/model to process logic, queries database through Eloquent, and returns JSON response.

## Frontend explanation in one line

Vue renders components, manages reactive state, calls Laravel APIs using Axios, handles loading/errors, and updates the UI automatically when data changes.

## Database explanation in one line

A good database design uses proper relationships, primary keys, foreign keys, indexes, normalization, and transactions to keep data accurate and fast.

## Full-stack feature explanation in one line

For a feature, I design the table, create migration/model/controller/API, validate requests, return clean JSON, build Vue UI, integrate API, handle errors, and test the full flow.

---

# 27. High-Probability Questions for This Specific Job

These are the questions most likely to appear based on the job post.

## 1. Explain your experience with Laravel and PHP.

**Strong answer:**

I have worked with Laravel for building backend APIs and business features. I understand routing, controllers, middleware, Eloquent models, relationships, migrations, validation, authentication, and API responses. I can also work with raw PHP concepts like sessions, cookies, PDO, prepared statements, OOP, Composer, and namespaces.

## 2. Explain your experience with Vue 3.

**Strong answer:**

I can build Vue 3 components using Composition API and `<script setup>`. I understand `ref`, `reactive`, `computed`, `watch`, props, emits, lifecycle hooks, Vue Router, and API integration using Axios. I can build CRUD screens and handle loading, validation errors, and user interactions.

## 3. How do you design a REST API?

**Strong answer:**

I design APIs around resources, use proper HTTP methods, consistent response format, validation, correct status codes, authentication, pagination for lists, filtering where needed, and avoid exposing sensitive data.

## 4. What database experience do you have?

**Strong answer:**

I have experience with relational database design, primary keys, foreign keys, joins, indexes, transactions, normalization, and writing SQL queries. I also understand how Laravel migrations and Eloquent relationships map to database design.

## 5. How do you solve bugs?

**Strong answer:**

I reproduce the bug first, identify whether it is frontend, backend, database, or environment related, check logs and network requests, isolate the failing part, fix the root cause, and test related flows so the fix does not break other features.

---

# 28. Things Not to Miss

- Do not confuse Vue 2 and Vue 3 syntax.
- Do not say `computed` and `watch` are the same.
- Do not ignore SQL indexes.
- Do not return passwords or sensitive fields from API.
- Do not use raw SQL with string concatenation.
- Do not load all records without pagination.
- Do not put all business logic inside controllers.
- Do not forget Laravel validation error status is usually 422.
- Do not forget CORS only appears in browser, not Postman.
- Do not say `float` is ideal for money; use `decimal`.
- Do not say frontend validation is enough; backend validation is mandatory.

---

# 29. Final Confidence Script

Use this mindset before entering the interview:

```text
I do not need to know every library in the world.
I need to prove I understand Laravel, Vue, PHP, SQL, REST APIs, debugging, and full-stack feature development.
If I do not know something deeply, I will explain how I would investigate and solve it professionally.
```

Good luck. Focus on practical confidence, not memorized theory.
