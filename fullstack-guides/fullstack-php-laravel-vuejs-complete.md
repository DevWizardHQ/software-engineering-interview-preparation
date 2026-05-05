# Full-Stack PHP / Laravel / Vue.js — Comprehensive Interview Reference

This is a merged reference combining strategic preparation, deep Laravel Q&A, and a broad 500-question bank covering PHP, Laravel, Vue, JavaScript/TypeScript, MySQL, REST API, Git, and Linux. For focused topic-by-topic study, see the topic-specific files in `/languages/`, `/frontend/`, `/databases/`, etc.

---

# PART 1 — Strategic Preparation, Mock Interview & 7-Day Plan

# Full-Stack Developer Interview Preparation

**Role:** Full-Stack Developer — Laravel & Vue.js

---

## 1. Job Post Breakdown

### What they are looking for

The role is for a full-stack developer who can build scalable backend systems with Laravel and create smooth frontend interfaces using Vue.js. The job post strongly focuses on practical development ability, REST API integration, debugging, performance optimization, and teamwork.

### Main requirements from the job post

| Area           | Requirement                                               |
| -------------- | --------------------------------------------------------- |
| Backend        | Laravel, PHP                                              |
| Frontend       | Vue 3, JavaScript, TypeScript as a plus                   |
| Database       | MySQL / relational databases                              |
| API            | REST API design and integration                           |
| Debugging      | Ability to debug and solve technical problems efficiently |
| Work style     | Comfortable working independently and in a team           |
| Documentation  | Clean, maintainable, documented code                      |
| System quality | Performance optimization and scalability                  |

### Your interview priority

Focus on proving that you can **build real features end-to-end**:

> Database design → Laravel API → Business logic → Validation → Vue UI → API integration → Debugging → Deployment awareness

---

## 2. Interview Strategy

### Your positioning statement

Use this when they ask, “Tell me about yourself.”

```text
I am a full-stack developer with practical experience in backend API development, database design, and frontend integration. My main strength is building complete business features from database to API to user interface. I am comfortable with Laravel/PHP, REST API design, relational databases like MySQL, and frontend development with Vue.js. I focus on clean code, debugging, performance, and maintainability. I enjoy working on scalable systems and collaborating with teams to deliver production-ready features.
```

### What you should highlight

- You understand MVC architecture.
- You can create REST APIs with validation and proper response structure.
- You know relational database design.
- You can integrate Vue frontend with backend APIs.
- You can debug issues from frontend, backend, and database.
- You care about clean code and maintainability.

### What not to do

- Do not say you only know Laravel basics.
- Do not overclaim if you are weak in Vue 3.
- Do not talk only about tutorials; talk about real features.
- Do not ignore database and API design, because this job clearly expects full-stack ability.

---

## 3. Laravel Interview Preparation

## 3.1 Laravel Core Concepts

### Q1. What is Laravel?

**Answer:**
Laravel is a PHP framework used to build web applications and APIs. It follows the MVC architecture and provides built-in features like routing, controllers, middleware, Eloquent ORM, validation, authentication, queues, migrations, caching, and testing.

### Q2. Explain MVC in Laravel.

**Answer:**
MVC means Model, View, Controller.

| Part       | Responsibility                                           |
| ---------- | -------------------------------------------------------- |
| Model      | Handles database-related logic using Eloquent ORM        |
| View       | Handles UI rendering using Blade or frontend integration |
| Controller | Receives request, calls business logic, returns response |

Example:

```php
Route::get('/products', [ProductController::class, 'index']);
```

```php
class ProductController extends Controller
{
    public function index()
    {
        return Product::all();
    }
}
```

### Q3. What is routing in Laravel?

**Answer:**
Routing maps HTTP requests to controller methods or closures. Routes are usually defined in `routes/web.php` for web pages and `routes/api.php` for APIs.

```php
Route::get('/users', [UserController::class, 'index']);
Route::post('/users', [UserController::class, 'store']);
Route::put('/users/{id}', [UserController::class, 'update']);
Route::delete('/users/{id}', [UserController::class, 'destroy']);
```

### Q4. What is middleware?

**Answer:**
Middleware filters HTTP requests before they reach the controller or after the response is generated. It is commonly used for authentication, authorization, logging, CORS, rate limiting, and request modification.

Example:

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/profile', [ProfileController::class, 'show']);
});
```

### Q5. What is Eloquent ORM?

**Answer:**
Eloquent is Laravel’s ORM. It allows developers to interact with database tables using PHP classes instead of writing raw SQL for every operation.

```php
$user = User::where('email', $email)->first();
```

### Q6. What is the difference between Eloquent and Query Builder?

| Eloquent                   | Query Builder                    |
| -------------------------- | -------------------------------- |
| Model-based ORM            | SQL-like fluent interface        |
| Easier relationships       | More lightweight                 |
| Good for business entities | Good for complex queries/reports |
| Returns model objects      | Returns generic objects/arrays   |

Example Query Builder:

```php
DB::table('users')->where('status', 'active')->get();
```

Example Eloquent:

```php
User::where('status', 'active')->get();
```

---

## 3.2 Laravel CRUD API Example

You should be able to explain and write a basic CRUD API.

### Migration

```php
Schema::create('products', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->decimal('price', 10, 2);
    $table->text('description')->nullable();
    $table->timestamps();
});
```

### Model

```php
class Product extends Model
{
    protected $fillable = ['name', 'price', 'description'];
}
```

### Controller

```php
class ProductController extends Controller
{
    public function index()
    {
        return response()->json(Product::paginate(10));
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'description' => 'nullable|string'
        ]);

        $product = Product::create($validated);

        return response()->json($product, 201);
    }

    public function show($id)
    {
        return response()->json(Product::findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $product = Product::findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'price' => 'sometimes|numeric|min:0',
            'description' => 'nullable|string'
        ]);

        $product->update($validated);

        return response()->json($product);
    }

    public function destroy($id)
    {
        Product::findOrFail($id)->delete();

        return response()->json(['message' => 'Product deleted successfully']);
    }
}
```

### Routes

```php
Route::apiResource('products', ProductController::class);
```

---

## 3.3 Laravel Validation

### Q. How do you validate request data in Laravel?

**Answer:**
Laravel provides request validation using `$request->validate()` or Form Request classes.

```php
$request->validate([
    'email' => 'required|email|unique:users,email',
    'password' => 'required|min:8|confirmed'
]);
```

### Better production approach: Form Request

```php
class StoreProductRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0'
        ];
    }
}
```

---

## 3.4 Laravel Authentication

### Q. How would you secure a Laravel API?

**Answer:**
For API authentication, I can use Laravel Sanctum or Passport. Sanctum is simpler and commonly used for SPA and token-based API authentication. I would protect routes using middleware like `auth:sanctum`, validate tokens, and return proper unauthorized responses.

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
});
```

### Login flow

1. User submits email and password.
2. Backend validates credentials.
3. Backend creates token.
4. Frontend stores token safely.
5. Frontend sends token in Authorization header.

```http
Authorization: Bearer <token>
```

---

## 3.5 Laravel Relationships

### One-to-One

```php
public function profile()
{
    return $this->hasOne(Profile::class);
}
```

### One-to-Many

```php
public function orders()
{
    return $this->hasMany(Order::class);
}
```

### Many-to-Many

```php
public function roles()
{
    return $this->belongsToMany(Role::class);
}
```

### Interview answer

Relationships allow models to connect with each other. For example, one user can have many orders, so the User model can define a `hasMany` relationship with the Order model.

---

## 3.6 Laravel Performance Optimization

Since the job post mentions performance and scalability, prepare this very well.

### Common Laravel performance techniques

| Problem                | Solution                                 |
| ---------------------- | ---------------------------------------- |
| N+1 query problem      | Use eager loading with `with()`          |
| Slow repeated queries  | Use caching                              |
| Large dataset loading  | Use pagination/chunking                  |
| Heavy background tasks | Use queues/jobs                          |
| Slow database queries  | Add indexes and optimize query structure |
| Large API response     | Return only required fields/resources    |

### N+1 problem example

Bad:

```php
$orders = Order::all();
foreach ($orders as $order) {
    echo $order->user->name;
}
```

Good:

```php
$orders = Order::with('user')->get();
```

### Caching example

```php
$products = Cache::remember('products', 3600, function () {
    return Product::all();
});
```

### Pagination example

```php
return Product::orderBy('created_at', 'desc')->paginate(20);
```

---

## 4. PHP Interview Preparation

### Q1. What are the main features of PHP?

**Answer:**
PHP is a server-side scripting language commonly used for web development. It supports OOP, database connectivity, sessions, file handling, error handling, and integration with frameworks like Laravel.

### Q2. Difference between `==` and `===` in PHP?

| Operator | Meaning                                     |
| -------- | ------------------------------------------- |
| `==`     | Compares value only, allows type conversion |
| `===`    | Compares value and type                     |

Example:

```php
'5' == 5    // true
'5' === 5   // false
```

### Q3. What is dependency injection?

**Answer:**
Dependency injection means providing a class its required dependencies from outside instead of creating them inside the class. It improves testability, flexibility, and clean architecture.

```php
class OrderService
{
    public function __construct(private PaymentService $paymentService) {}
}
```

### Q4. What are traits in PHP?

**Answer:**
Traits are reusable groups of methods that can be included in multiple classes.

```php
trait HasUuid
{
    public function generateUuid()
    {
        return Str::uuid();
    }
}
```

### Q5. What is Composer?

**Answer:**
Composer is a dependency manager for PHP. It manages packages, autoloading, and project dependencies using `composer.json`.

---

## 5. MySQL / Relational Database Preparation

### Q1. What is a primary key?

A primary key uniquely identifies each row in a table.

### Q2. What is a foreign key?

A foreign key connects one table to another and maintains referential integrity.

### Q3. What is indexing?

Indexing improves query performance by allowing the database to find rows faster. But too many indexes can slow down insert/update operations.

### Q4. What is normalization?

Normalization means organizing data to reduce duplication and improve integrity.

### Q5. What is the difference between INNER JOIN and LEFT JOIN?

| Join       | Meaning                                                                     |
| ---------- | --------------------------------------------------------------------------- |
| INNER JOIN | Returns only matching rows from both tables                                 |
| LEFT JOIN  | Returns all rows from the left table and matching rows from the right table |

### Example schema question

**Question:** Design tables for users, products, and orders.

```sql
users
- id
- name
- email
- password
- created_at
- updated_at

products
- id
- name
- price
- stock
- created_at
- updated_at

orders
- id
- user_id
- total_amount
- status
- created_at
- updated_at

order_items
- id
- order_id
- product_id
- quantity
- price
```

### Query practice

Find top 5 selling products:

```sql
SELECT p.id, p.name, SUM(oi.quantity) AS total_sold
FROM order_items oi
JOIN products p ON p.id = oi.product_id
GROUP BY p.id, p.name
ORDER BY total_sold DESC
LIMIT 5;
```

Find users with more than 3 orders:

```sql
SELECT u.id, u.name, COUNT(o.id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.id
GROUP BY u.id, u.name
HAVING COUNT(o.id) > 3;
```

---

## 6. REST API Preparation

### Q1. What is REST API?

REST API is an architectural style where resources are exposed through URLs and accessed using HTTP methods like GET, POST, PUT, PATCH, and DELETE.

### Common HTTP methods

| Method | Use                      |
| ------ | ------------------------ |
| GET    | Read data                |
| POST   | Create data              |
| PUT    | Replace/update full data |
| PATCH  | Partially update data    |
| DELETE | Delete data              |

### Common HTTP status codes

| Code | Meaning          |
| ---- | ---------------- |
| 200  | OK               |
| 201  | Created          |
| 400  | Bad Request      |
| 401  | Unauthorized     |
| 403  | Forbidden        |
| 404  | Not Found        |
| 422  | Validation Error |
| 500  | Server Error     |

### Good API response example

```json
{
  "success": true,
  "message": "Product created successfully",
  "data": {
    "id": 1,
    "name": "Rice Toner",
    "price": 550
  }
}
```

### Bad API response example

```json
"done"
```

### REST endpoint design example

```http
GET    /api/products
POST   /api/products
GET    /api/products/{id}
PUT    /api/products/{id}
DELETE /api/products/{id}
```

---

## 7. Vue 3 Interview Preparation

## 7.1 Vue Core Concepts

### Q1. What is Vue.js?

Vue.js is a progressive JavaScript framework used to build frontend interfaces and single-page applications. Vue 3 provides Composition API, reactivity, components, routing, and state management support.

### Q2. What are components?

Components are reusable UI blocks. A page can be built by combining multiple components.

```vue
<template>
  <button @click="handleClick">Save</button>
</template>

<script setup>
function handleClick() {
  console.log("Clicked");
}
</script>
```

### Q3. What is reactivity in Vue?

Reactivity means Vue automatically updates the UI when the underlying data changes.

```vue
<script setup>
import { ref } from "vue";

const count = ref(0);
</script>

<template>
  <button @click="count++">{{ count }}</button>
</template>
```

### Q4. Difference between `ref` and `reactive`?

| `ref`                                 | `reactive`             |
| ------------------------------------- | ---------------------- |
| Good for primitive values             | Good for objects       |
| Access value using `.value` in script | Direct property access |
| Can hold any value                    | Mainly for objects     |

```js
const name = ref("Jawwad");
const user = reactive({ name: "Jawwad", age: 25 });
```

### Q5. What is `computed`?

A computed property is a cached value derived from reactive data.

```js
const total = computed(() => price.value * quantity.value);
```

### Q6. What is `watch`?

`watch` runs code when a reactive value changes.

```js
watch(searchText, (newValue) => {
  fetchProducts(newValue);
});
```

---

## 7.2 Vue API Integration

### Axios example

```js
import axios from "axios";

const api = axios.create({
  baseURL: "http://localhost:8000/api",
  headers: {
    Accept: "application/json",
  },
});

export default api;
```

### Fetch product list

```vue
<script setup>
import { ref, onMounted } from "vue";
import api from "@/api";

const products = ref([]);
const loading = ref(false);
const error = ref(null);

async function fetchProducts() {
  loading.value = true;
  error.value = null;

  try {
    const response = await api.get("/products");
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

### Token interceptor

```js
api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
```

---

## 7.3 Vue Router

### Q. What is Vue Router?

Vue Router manages navigation between pages in a Vue single-page application.

```js
const routes = [
  { path: "/", component: HomePage },
  { path: "/products", component: ProductListPage },
  { path: "/products/:id", component: ProductDetailsPage },
];
```

---

## 7.4 Pinia / State Management

### Q. Why use state management?

State management helps share data between components without passing props deeply.

```js
export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    token: null,
  }),
  actions: {
    setToken(token) {
      this.token = token;
    },
  },
});
```

---

## 8. JavaScript / TypeScript Preparation

### Q1. What is the difference between `var`, `let`, and `const`?

| Keyword | Scope          | Reassignable |
| ------- | -------------- | ------------ |
| var     | Function scope | Yes          |
| let     | Block scope    | Yes          |
| const   | Block scope    | No           |

### Q2. What is a Promise?

A Promise represents a future result of an asynchronous operation.

```js
fetch("/api/products")
  .then((response) => response.json())
  .then((data) => console.log(data))
  .catch((error) => console.error(error));
```

### Q3. What is async/await?

`async/await` is a cleaner way to work with Promises.

```js
async function loadProducts() {
  try {
    const response = await fetch("/api/products");
    const data = await response.json();
    console.log(data);
  } catch (error) {
    console.error(error);
  }
}
```

### Q4. What is TypeScript?

TypeScript is a superset of JavaScript that adds static typing. It helps catch errors earlier and makes code easier to maintain.

```ts
type Product = {
  id: number;
  name: string;
  price: number;
};
```

---

## 9. Practical Coding Tasks They May Give

## Task 1: Build Product CRUD

Expected features:

- Product list
- Product create
- Product update
- Product delete
- Validation
- Pagination
- Vue API integration

### Preparation checklist

- Can create migration
- Can create model
- Can create controller
- Can write API routes
- Can validate request
- Can call API from Vue
- Can show loading/error states

---

## Task 2: Login API + Vue Login Page

Expected features:

- Login form
- Laravel credential validation
- Token creation
- Store token in frontend
- Use token in API requests
- Logout

### Backend sample idea

```php
public function login(Request $request)
{
    $request->validate([
        'email' => 'required|email',
        'password' => 'required'
    ]);

    if (!Auth::attempt($request->only('email', 'password'))) {
        return response()->json(['message' => 'Invalid credentials'], 401);
    }

    $user = Auth::user();
    $token = $user->createToken('api-token')->plainTextToken;

    return response()->json([
        'user' => $user,
        'token' => $token
    ]);
}
```

---

## Task 3: Search and Filter

Example:

```php
$query = Product::query();

if ($request->filled('search')) {
    $query->where('name', 'like', '%' . $request->search . '%');
}

if ($request->filled('min_price')) {
    $query->where('price', '>=', $request->min_price);
}

if ($request->filled('max_price')) {
    $query->where('price', '<=', $request->max_price);
}

return $query->paginate(10);
```

---

## Task 4: Fix N+1 Query Problem

They may show code like this:

```php
$orders = Order::all();
foreach ($orders as $order) {
    echo $order->user->name;
}
```

Correct answer:

```php
$orders = Order::with('user')->get();
```

---

## Task 5: Create Order With Items

Tables:

- orders
- order_items
- products
- users

Key things to mention:

- Use database transaction.
- Validate product stock.
- Calculate total on backend, not frontend.
- Reduce stock safely.
- Return clear response.

```php
DB::transaction(function () use ($request) {
    $order = Order::create([
        'user_id' => auth()->id(),
        'total_amount' => 0,
        'status' => 'pending'
    ]);

    $total = 0;

    foreach ($request->items as $item) {
        $product = Product::findOrFail($item['product_id']);
        $lineTotal = $product->price * $item['quantity'];
        $total += $lineTotal;

        $order->items()->create([
            'product_id' => $product->id,
            'quantity' => $item['quantity'],
            'price' => $product->price
        ]);
    }

    $order->update(['total_amount' => $total]);
});
```

---

## 10. Debugging Preparation

The job post specifically says debugging and solving technical problems efficiently.

### Laravel debugging checklist

- Check route exists: `php artisan route:list`
- Check request payload
- Check validation errors
- Check Laravel logs: `storage/logs/laravel.log`
- Check database query
- Use `dd()` only locally
- Use proper logging in real debugging
- Check `.env` database settings
- Clear config cache if needed:

```bash
php artisan config:clear
php artisan cache:clear
php artisan route:clear
```

### Vue debugging checklist

- Check browser console
- Check network tab
- Check API status code
- Check request payload
- Check Authorization header
- Check CORS issue
- Check reactive state update
- Check component lifecycle

### Example debugging answer

```text
First I reproduce the issue. Then I check whether the problem is frontend, backend, or database related. In the browser, I inspect the Network tab to confirm request URL, payload, status code, and response. In Laravel, I check routes, validation, controller logic, logs, and database queries. After identifying the root cause, I fix it and test the full flow again.
```

---

## 11. System Design Mini Preparation

They may ask: “How would you design an eCommerce system?”

### Basic modules

- User authentication
- Product management
- Category management
- Cart
- Order
- Payment status
- Admin panel
- Reports

### Basic database design

```text
users
categories
products
carts
cart_items
orders
order_items
payments
```

### API examples

```http
POST /api/auth/login
GET /api/products
POST /api/products
GET /api/categories
POST /api/cart/items
POST /api/orders
GET /api/orders/{id}
```

### Important design points

- Use validation for every request.
- Use authentication for protected routes.
- Use database transactions for order creation.
- Use pagination for product and order lists.
- Use indexes on frequently searched columns.
- Keep business calculations on backend.
- Use queues for email or slow background tasks.

---

## 12. Clean Code Preparation

### What clean code means for this role

- Meaningful class and method names
- Small focused methods
- Avoid duplicated logic
- Use Form Requests for validation
- Use services for business logic if controller becomes large
- Use API Resources for response formatting
- Use migrations instead of manual DB changes
- Write readable and documented code

### Bad controller style

```php
public function store(Request $request)
{
    // 200 lines of validation, calculation, DB queries, email sending
}
```

### Better style

```php
public function store(StoreOrderRequest $request, OrderService $orderService)
{
    $order = $orderService->createOrder($request->validated());

    return new OrderResource($order);
}
```

---

## 13. Common Interview Questions and Strong Answers

### Q1. Why do you want to join this company?

```text
I want to join because the role matches my full-stack development interest. Working on real business applications gives me the chance to contribute meaningfully. I like that the role involves Laravel backend, Vue frontend, REST APIs, performance, and scalable systems. I believe I can contribute quickly and also grow by working with the team.
```

### Q2. Why should we hire you?

```text
You should hire me because I can work on both backend and frontend parts of a feature. I understand how to design database tables, build Laravel APIs, validate requests, debug problems, and connect the frontend using Vue. I focus on clean code, maintainability, and practical delivery. I am also comfortable learning quickly and collaborating with a team.
```

### Q3. What is your strongest technical skill?

```text
My strongest skill is backend API development. I can design REST APIs, structure database tables, write validation, handle authentication, and debug issues. I also understand how the frontend consumes APIs, so I can build features end-to-end.
```

### Q4. How do you handle pressure?

```text
I handle pressure by breaking the problem into smaller parts. First, I identify the most important issue, then I debug step by step. I communicate clearly with the team if there is any blocker. I try to solve urgent production or delivery issues in a calm and structured way.
```

### Q5. What if you do not know something?

```text
If I do not know something, I first try to understand the requirement clearly. Then I check official documentation or reliable resources, test a small implementation, and ask senior team members if needed. I believe not knowing something is acceptable, but not trying to learn it properly is not acceptable.
```

---

## 14. Salary Discussion Preparation

The job post mentions BDT 40,000–50,000/month.

### If they ask expected salary

```text
Based on the role requirements, my experience, and the posted salary range, I am expecting around BDT 50,000. However, I am open to discussion depending on the full responsibilities, growth opportunity, and overall compensation structure.
```

### If they offer lower

```text
I appreciate the offer. Considering the full-stack responsibilities involving Laravel, Vue.js, REST APIs, database work, and performance optimization, I was expecting something closer to the upper range. Is there flexibility to revise the offer?
```

---

## 15. Questions You Can Ask Them

Ask 2–4 of these near the end.

1. What type of projects will I mostly work on: eCommerce, custom ERP, SaaS, or client projects?
2. What is the current backend and frontend architecture?
3. Does the team follow any code review process?
4. How are tasks assigned and tracked?
5. Do you use Git flow or any specific branching strategy?
6. Is there any testing or QA process before deployment?
7. What will be the first major responsibility for this role?

---

## 16. 7-Day Preparation Plan

## Day 1 — Laravel Core

- Routing
- Controllers
- Middleware
- Request validation
- API Resource
- CRUD practice

### Practice

Build a Product CRUD API.

---

## Day 2 — Eloquent + Database

- Models
- Relationships
- Migrations
- Seeders
- Query Builder
- Joins
- Indexes

### Practice

Create users, orders, and order_items tables with relationships.

---

## Day 3 — Authentication + REST API

- Laravel Sanctum
- Login/logout
- Protected routes
- API status codes
- Error response structure

### Practice

Build login API and protect product creation API.

---

## Day 4 — Vue 3 Basics

- Components
- Props
- Emits
- ref/reactive
- computed/watch
- forms
- conditional rendering

### Practice

Build product list and product form components.

---

## Day 5 — Vue API Integration

- Axios
- Loading state
- Error handling
- Token header
- Pagination
- Search/filter

### Practice

Connect Vue product page with Laravel API.

---

## Day 6 — Full-Stack Feature

Build one complete feature:

```text
Product management:
- Product list
- Product create
- Product edit
- Product delete
- Search
- Pagination
- Validation errors
```

---

## Day 7 — Mock Interview

Prepare:

- Tell me about yourself
- Laravel questions
- Vue questions
- REST API questions
- MySQL queries
- Debugging scenario
- Salary expectation

---

## 17. Last-Day Revision Sheet

### Laravel must know

- MVC
- Routing
- Controller
- Middleware
- Validation
- Eloquent
- Relationships
- Migration
- Authentication
- Pagination
- API Resource
- Queue basics
- Cache basics

### Vue must know

- Component
- Props
- Emits
- ref/reactive
- computed/watch
- Lifecycle hooks
- Vue Router
- Axios
- Form handling
- Error/loading states

### MySQL must know

- Primary key
- Foreign key
- Join
- Group by
- Having
- Index
- Normalization
- Transaction

### REST API must know

- HTTP methods
- Status codes
- Request/response structure
- Authentication header
- Validation error response

---

## 18. Quick Mock Interview

### Technical round

1. Explain Laravel request lifecycle.
2. What is middleware?
3. How do you validate data in Laravel?
4. What is Eloquent ORM?
5. How do you avoid N+1 query problems?
6. How do you design REST APIs?
7. What status code will you return for validation errors?
8. How do you secure an API?
9. How do you connect Vue with Laravel API?
10. What is the difference between ref and reactive in Vue?
11. How do you handle loading and error states in Vue?
12. Write a query to get top-selling products.
13. How do you debug a 500 error from Laravel?
14. How do you debug a 401 error from API?
15. How do you optimize slow API responses?

### HR round

1. Tell me about yourself.
2. Why this company?
3. Why should we hire you?
4. What are your strengths?
5. What are your weaknesses?
6. Are you comfortable with on-site work?
7. Are you comfortable with standard office hours?
8. What is your expected salary?
9. Can you work independently?
10. How do you handle deadlines?

---

## 19. Best Project to Present in Interview

Prepare one project story like this:

```text
I built a full-stack management system where the backend was responsible for authentication, product/order management, database relationships, validation, and REST APIs. The frontend consumed these APIs and displayed data with create, update, delete, search, and filter functionality. I handled validation both on backend and frontend, used relational database design, and focused on clean API response structure.
```

### Explain your project using this format

| Topic     | What to say                              |
| --------- | ---------------------------------------- |
| Problem   | What business problem the project solved |
| Backend   | Laravel APIs, validation, database, auth |
| Frontend  | Vue pages, forms, API integration        |
| Database  | Tables and relationships                 |
| Challenge | Debugging/performance/API issue          |
| Solution  | How you solved it                        |
| Result    | What worked after implementation         |

---

## 20. Final Confidence Notes

For this role, they will probably not expect only theory. They will expect you to explain practical implementation. So prepare with code examples.

Your strongest preparation should be:

1. Laravel CRUD API
2. Laravel authentication
3. MySQL relationships and joins
4. Vue 3 component and API integration
5. REST API status codes
6. Debugging strategy
7. Performance optimization
8. Clean project explanation

If you can confidently explain these, you will be well prepared for this interview.

---

# Final One-Minute Self Introduction

```text
Assalamu Alaikum. I am a full-stack developer with experience in backend API development, relational database design, and frontend integration. I mainly work with Laravel/PHP for backend and Vue.js for frontend. I can build complete features including database schema, REST API, validation, authentication, and frontend API integration. I also focus on debugging, performance optimization, and writing clean maintainable code. I am interested in this role because it matches my skills in Laravel, Vue.js, MySQL, and full-stack product development.
```

---

# PART 2 — Deep Laravel Q&A Reference

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

This role matches my skill set because it requires Laravel, PHP, Vue.js, REST API, and MySQL. I like working on full-stack systems where I can understand both the business logic and the user experience. The company's focus aligns with the kind of scalable backend systems and smooth frontend interfaces I enjoy building.

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

---

# PART 3 — 500 Questions Across PHP, Laravel, Vue, JS/TS, MySQL, REST API, Git, Linux

# Full-Stack Developer Interview Preparation

## 500 Questions & Answers

**Role:** Full-Stack Developer — Laravel & Vue.js

**Focus areas:** Raw PHP, Laravel, Vue 2/Vue 3, JavaScript, TypeScript, MySQL/SQL, REST API, Git, Linux, deployment, security, performance, scenario questions, and HR questions.

**Study method:** Practice 30–50 questions daily. For each answer, add one example from your own project.

---

## Raw PHP & Core PHP

### 1. What is PHP?

**Answer:** PHP is a server-side scripting language used to build dynamic web apps and APIs. In this role, PHP is the base language behind Laravel.

### 2. Why is PHP popular for web development?

**Answer:** It is easy to deploy, has huge hosting support, strong frameworks like Laravel, and integrates well with MySQL.

### 3. What is the difference between echo and print?

**Answer:** echo outputs one or more strings and has no return value. print outputs one string and returns 1.

### 4. What is the difference between include and require?

**Answer:** include gives a warning if the file is missing and continues. require gives a fatal error and stops.

### 5. What is include_once?

**Answer:** It includes a file only once to avoid duplicate class/function definitions.

### 6. What is require_once?

**Answer:** It requires a file once and stops execution if the file is missing.

### 7. What are PHP variables?

**Answer:** Variables start with $ and store dynamic values, for example $name = 'User';.

### 8. What are PHP scalar types?

**Answer:** String, integer, float, and boolean.

### 9. What are compound types in PHP?

**Answer:** Array, object, callable, and iterable.

### 10. What is null in PHP?

**Answer:** null means a variable has no value.

### 11. What is type juggling?

**Answer:** PHP automatically converts types in some operations, especially loose comparison.

### 12. What is strict comparison?

**Answer:** Using === checks both value and type.

### 13. Why prefer === over ==?

**Answer:** It avoids unexpected bugs from automatic type conversion.

### 14. What is an indexed array?

**Answer:** An array with numeric keys, such as ['a', 'b'].

### 15. What is an associative array?

**Answer:** An array with named keys, such as ['name' => 'Rahim'].

### 16. What is a multidimensional array?

**Answer:** An array containing other arrays.

### 17. What is isset()?

**Answer:** It checks whether a variable exists and is not null.

### 18. What is empty()?

**Answer:** It checks whether a variable is empty, such as '', 0, null, false, or [].

### 19. What is unset()?

**Answer:** It removes a variable or array element.

### 20. What is a function?

**Answer:** A reusable block of code that can take parameters and return a value.

### 21. What is pass by value?

**Answer:** A copy of the variable is passed, so the original is not changed.

### 22. What is pass by reference?

**Answer:** The original variable is passed using &, so it can be changed.

### 23. What is a closure?

**Answer:** An anonymous function that can be assigned or passed around.

### 24. What is namespace?

**Answer:** A way to organize classes and avoid name conflicts.

### 25. What is Composer?

**Answer:** Composer is PHP's dependency manager.

### 26. What is composer.json?

**Answer:** It defines dependencies, autoloading, scripts, and project metadata.

### 27. What is PSR-4?

**Answer:** A PHP autoloading standard mapping namespaces to directories.

### 28. What is OOP?

**Answer:** Object-oriented programming organizes code into classes and objects.

### 29. What is a class?

**Answer:** A blueprint containing properties and methods.

### 30. What is an object?

**Answer:** An instance of a class.

### 31. What is encapsulation?

**Answer:** Hiding internal state and exposing controlled methods.

### 32. What is inheritance?

**Answer:** A child class reuses or extends a parent class.

### 33. What is polymorphism?

**Answer:** Different classes can be used through the same interface but behave differently.

### 34. What is abstraction?

**Answer:** Hiding implementation details and exposing essential behavior.

### 35. What is an interface?

**Answer:** A contract that defines methods a class must implement.

### 36. What is an abstract class?

**Answer:** A class that cannot be instantiated and may contain abstract methods.

### 37. Interface vs abstract class?

**Answer:** Interface defines a contract; abstract class can also share common code.

### 38. What is a trait?

**Answer:** A reusable group of methods inserted into classes.

### 39. What is constructor?

**Answer:** \_\_construct() runs when an object is created.

### 40. What is static method?

**Answer:** A method called on the class itself using ClassName::method().

### 41. What are magic methods?

**Answer:** Special methods like **construct, **get, **set, **call, and \_\_toString.

### 42. What is exception handling?

**Answer:** Using try/catch/finally to handle runtime errors safely.

### 43. What is Throwable?

**Answer:** The base interface for Exception and Error in modern PHP.

### 44. What is PDO?

**Answer:** PHP Data Objects, a database abstraction layer with prepared statement support.

### 45. Why use prepared statements?

**Answer:** They prevent SQL injection by separating SQL from user input.

### 46. What is SQL injection?

**Answer:** An attack where malicious input changes SQL query behavior.

### 47. How prevent SQL injection in raw PHP?

**Answer:** Use prepared statements, bound parameters, and validation.

### 48. What is XSS?

**Answer:** Cross-site scripting, where malicious script executes in the browser.

### 49. How prevent XSS?

**Answer:** Escape output and avoid rendering unsafe user HTML.

### 50. What is CSRF?

**Answer:** An attack that tricks a logged-in user into submitting unwanted requests.

### 51. How prevent CSRF?

**Answer:** Use CSRF tokens and SameSite cookies.

### 52. What is a session?

**Answer:** Server-side storage for user-specific data across requests.

### 53. What is a cookie?

**Answer:** Small client-side data sent with requests.

### 54. Session vs cookie?

**Answer:** Session data is server-side; cookie data is client-side.

### 55. How store passwords safely?

**Answer:** Use password_hash() and password_verify(); never store plain passwords.

### 56. What is json_encode()?

**Answer:** It converts PHP data to JSON.

### 57. What is json_decode()?

**Answer:** It converts JSON to PHP data.

### 58. What is header()?

**Answer:** It sends HTTP headers before output.

### 59. What causes headers already sent?

**Answer:** Output was sent before header/session operations.

### 60. What is output buffering?

**Answer:** Temporarily storing output before sending it to the browser.

### 61. What is dependency injection?

**Answer:** Passing dependencies from outside instead of creating them inside a class.

### 62. What is MVC?

**Answer:** Model handles data, View handles UI, Controller handles request flow.

### 63. What is SOLID?

**Answer:** Five design principles for maintainable OOP code.

### 64. What is SRP?

**Answer:** Single Responsibility Principle: one class should have one main reason to change.

### 65. What is file upload validation?

**Answer:** Checking size, MIME type, extension, and safe storage path.

### 66. What is $\_GET?

**Answer:** Query string/request URL parameters.

### 67. What is $\_POST?

**Answer:** POST form/request body parameters.

### 68. What is $\_FILES?

**Answer:** Uploaded file metadata.

### 69. What is $\_SERVER?

**Answer:** Server and request environment information.

### 70. What is OPcache?

**Answer:** A PHP bytecode cache that improves performance.

### 71. What is PHP-FPM?

**Answer:** A FastCGI process manager for running PHP with servers like Nginx.

### 72. What is nullable type?

**Answer:** A type that allows null, like ?string.

### 73. What is union type?

**Answer:** A type that allows multiple types, like string|int.

### 74. What is enum in PHP?

**Answer:** A fixed set of named values, useful for statuses.

### 75. How debug PHP?

**Answer:** Use logs, var_dump, Xdebug, error reporting, and step-by-step isolation.

## Laravel

### 76. What is Laravel?

**Answer:** A PHP framework for building web apps and APIs with routing, ORM, validation, auth, queues, and more.

### 77. Why use Laravel?

**Answer:** It gives structure, security helpers, Eloquent ORM, migrations, validation, and faster development.

### 78. What is MVC in Laravel?

**Answer:** Models handle data, views handle UI, and controllers handle request flow.

### 79. Where are web routes defined?

**Answer:** routes/web.php.

### 80. Where are API routes defined?

**Answer:** routes/api.php.

### 81. What is a route?

**Answer:** A mapping between an HTTP request and controller/closure logic.

### 82. What is a controller?

**Answer:** A class that handles request logic and returns responses.

### 83. What is resource controller?

**Answer:** A controller with standard CRUD methods.

### 84. What is middleware?

**Answer:** A request filter used for auth, CSRF, throttling, or custom checks.

### 85. What is auth middleware?

**Answer:** It restricts routes to authenticated users.

### 86. What is CSRF middleware?

**Answer:** It verifies CSRF token for state-changing web requests.

### 87. What is Eloquent?

**Answer:** Laravel's ORM for interacting with database tables through models.

### 88. What is a model?

**Answer:** A class representing a database table and its relationships.

### 89. What is migration?

**Answer:** A version-controlled database schema change.

### 90. What is seeder?

**Answer:** A class that inserts initial/sample data.

### 91. What is factory?

**Answer:** A class/helper to generate fake model data for tests/seeding.

### 92. What is mass assignment?

**Answer:** Filling model attributes from an array.

### 93. What is $fillable?

**Answer:** A whitelist of fields allowed for mass assignment.

### 94. What is $guarded?

**Answer:** A blacklist of fields blocked from mass assignment.

### 95. What is Form Request?

**Answer:** A custom request class for validation and authorization.

### 96. Why use Form Request?

**Answer:** It keeps controllers clean and validation reusable.

### 97. What is route model binding?

**Answer:** Laravel automatically resolves route parameters into model instances.

### 98. What is Blade?

**Answer:** Laravel's templating engine.

### 99. What is {{ }} in Blade?

**Answer:** Escaped output to prevent XSS.

### 100. What is {!! !!} in Blade?

**Answer:** Raw unescaped output; use carefully.

### 101. What is hasOne?

**Answer:** One-to-one relationship from current model to one related model.

### 102. What is belongsTo?

**Answer:** The inverse relationship where current model has a foreign key.

### 103. What is hasMany?

**Answer:** One-to-many relationship.

### 104. What is belongsToMany?

**Answer:** Many-to-many relationship using a pivot table.

### 105. What is a pivot table?

**Answer:** A table connecting two many-to-many models.

### 106. What is eager loading?

**Answer:** Loading relationships upfront using with() to avoid N+1 queries.

### 107. What is lazy loading?

**Answer:** Loading relationships when accessed.

### 108. What is N+1 query problem?

**Answer:** One query loads parents, then many extra queries load children.

### 109. How fix N+1?

**Answer:** Use with(), load(), or withCount().

### 110. What is withCount()?

**Answer:** It loads related record count without loading full relation.

### 111. What is accessor?

**Answer:** A method that transforms an attribute when reading.

### 112. What is mutator?

**Answer:** A method that transforms an attribute before saving.

### 113. What are casts?

**Answer:** Automatic conversion of model attributes to types.

### 114. What is soft delete?

**Answer:** Marking records deleted using deleted_at instead of removing.

### 115. How enable soft deletes?

**Answer:** Use SoftDeletes trait and add deleted_at column.

### 116. What is query scope?

**Answer:** Reusable query logic in a model.

### 117. Local scope vs global scope?

**Answer:** Local is called manually; global applies automatically.

### 118. What is service container?

**Answer:** Laravel's dependency injection container.

### 119. What is service provider?

**Answer:** A bootstrap class that registers services/configuration.

### 120. What is dependency injection in Laravel?

**Answer:** Laravel automatically resolves type-hinted dependencies.

### 121. What is facade?

**Answer:** A static-looking interface to a service in the container.

### 122. Facade vs DI?

**Answer:** Facades are convenient; DI is more explicit and testable.

### 123. What is artisan?

**Answer:** Laravel command-line tool.

### 124. Common artisan commands?

**Answer:** serve, migrate, make:model, make:controller, route:list, cache:clear.

### 125. What is .env?

**Answer:** Environment-specific configuration file.

### 126. Why not commit .env?

**Answer:** It can contain secrets and environment-specific values.

### 127. What is config cache?

**Answer:** Cached config for faster production loading.

### 128. What is route cache?

**Answer:** Cached route definitions for performance.

### 129. What is queue?

**Answer:** Background processing system for slow tasks.

### 130. What is a job?

**Answer:** A task class that can be queued.

### 131. What is event/listener?

**Answer:** Event announces something happened; listener reacts.

### 132. What is notification?

**Answer:** A message sent through mail, database, SMS, etc.

### 133. What is scheduler?

**Answer:** Laravel feature for defining recurring tasks in code.

### 134. What is cache?

**Answer:** Temporary storage for frequently used data.

### 135. What is Redis used for?

**Answer:** Cache, queues, sessions, and rate limiting.

### 136. What is authentication?

**Answer:** Verifying who the user is.

### 137. What is authorization?

**Answer:** Checking what the user can do.

### 138. What is policy?

**Answer:** Authorization logic for a model.

### 139. What is gate?

**Answer:** Closure-based authorization rule.

### 140. What is Sanctum?

**Answer:** Simple API token/SPAs authentication package.

### 141. What is Passport?

**Answer:** OAuth2 server package for Laravel.

### 142. Sanctum vs Passport?

**Answer:** Sanctum is simpler; Passport is for full OAuth2 flows.

### 143. What is API Resource?

**Answer:** A class that transforms models into JSON responses.

### 144. Why use API Resource?

**Answer:** To control response shape and hide internal fields.

### 145. What is pagination?

**Answer:** Splitting large results into pages using paginate().

### 146. paginate vs simplePaginate?

**Answer:** paginate includes total count; simplePaginate avoids count and can be faster.

### 147. What is transaction?

**Answer:** A group of DB operations that commit or rollback together.

### 148. How use transaction?

**Answer:** DB::transaction(function () { ... });

### 149. When use transaction?

**Answer:** When multiple writes must stay consistent.

### 150. What is firstOrCreate?

**Answer:** Find first matching record or create it.

### 151. What is updateOrCreate?

**Answer:** Update matching record or create it.

### 152. What is findOrFail?

**Answer:** Find by ID or throw 404 exception.

### 153. What is abort()?

**Answer:** Stops request and returns an HTTP error.

### 154. What is Laravel logging?

**Answer:** Laravel uses Monolog channels to write application logs.

### 155. What is dd()?

**Answer:** Dump and die, for development debugging.

### 156. What is dump()?

**Answer:** Dump data without stopping execution.

### 157. What is Telescope?

**Answer:** Laravel debugging/monitoring tool for development.

### 158. What is rate limiting?

**Answer:** Restricting number of requests in a time window.

### 159. What is CORS?

**Answer:** Browser policy controlling cross-origin API access.

### 160. How handle CORS?

**Answer:** Configure allowed origins, methods, and headers.

### 161. What is storage disk?

**Answer:** Filesystem abstraction for local/public/cloud storage.

### 162. What is storage:link?

**Answer:** Creates public link to storage/app/public.

### 163. How upload file?

**Answer:** Validate file, store it, save path in DB.

### 164. How secure upload?

**Answer:** Validate size/type, rename safely, avoid executable public files.

### 165. What is Collection?

**Answer:** Fluent wrapper around arrays/data.

### 166. map vs each?

**Answer:** map returns transformed collection; each is for side effects.

### 167. filter vs reject?

**Answer:** filter keeps matching items; reject removes matching items.

### 168. What is pluck?

**Answer:** Extracts one column/key from results.

### 169. What is chunk?

**Answer:** Processes records in batches to save memory.

### 170. What is cursor?

**Answer:** Streams records one at a time.

### 171. What is repository pattern?

**Answer:** Separates data access from business logic.

### 172. What is service layer?

**Answer:** A layer for business logic outside controllers.

### 173. What is thin controller?

**Answer:** A controller that validates/co-ordinates but avoids heavy business logic.

### 174. Laravel 8 vs 9?

**Answer:** Laravel 9 moved to newer PHP/Symfony versions and modernized features.

### 175. Laravel 9 vs 10?

**Answer:** Laravel 10 removed deprecated behavior and modernized skeleton typing.

### 176. Laravel 10 vs 11?

**Answer:** Laravel 11 introduced a slimmer app skeleton and bootstrap/app.php configuration style.

### 177. What is bootstrap/app.php in Laravel 11?

**Answer:** Central place for routing, middleware, and exception configuration in new skeleton.

### 178. What is Vite in Laravel?

**Answer:** Modern frontend build tool used for assets.

### 179. Vite vs Mix?

**Answer:** Vite is faster and modern; Mix is Webpack-based and older.

### 180. How connect Vue with Laravel?

**Answer:** Use Laravel API + Vue SPA, or Blade with Vue components.

### 181. How return JSON?

**Answer:** return response()->json([...]);

### 182. How handle API errors?

**Answer:** Use proper status codes and consistent JSON error format.

### 183. How optimize Laravel?

**Answer:** Eager load, add indexes, cache, queue slow tasks, paginate, and use config/route cache.

### 184. How secure Laravel?

**Answer:** Validate input, use auth/policies, CSRF, escaped output, HTTPS, rate limits, safe uploads.

### 185. What is migrate:fresh?

**Answer:** Drops all tables and reruns migrations; dangerous in production.

### 186. What is migrate:rollback?

**Answer:** Rolls back the last migration batch.

### 187. What is observer?

**Answer:** Class that listens to model events.

### 188. What are model events?

**Answer:** creating, created, updating, updated, deleting, deleted, etc.

### 189. What is hidden property?

**Answer:** Fields hidden from JSON output.

### 190. What is appends property?

**Answer:** Accessor values appended to model JSON.

### 191. What is 422 response?

**Answer:** Validation error response.

### 192. What is 401?

**Answer:** Unauthenticated.

### 193. What is 403?

**Answer:** Authenticated but forbidden.

### 194. What is 404?

**Answer:** Resource not found.

### 195. What is 201?

**Answer:** Resource created.

## Vue.js

### 196. What is Vue.js?

**Answer:** A progressive JavaScript framework for reactive user interfaces.

### 197. What is Vue 2 vs Vue 3?

**Answer:** Vue 3 has Proxy reactivity, Composition API, better TypeScript, fragments, Teleport, Suspense, and better performance.

### 198. What is Options API?

**Answer:** Component logic organized by data, methods, computed, watch, lifecycle hooks.

### 199. What is Composition API?

**Answer:** Logic organized by feature using setup(), ref(), reactive(), computed(), and composables.

### 200. Options API vs Composition API?

**Answer:** Options is simple; Composition is better for large reusable logic and TypeScript.

### 201. What is script setup?

**Answer:** A concise Vue 3 syntax for Composition API components.

### 202. What is component?

**Answer:** Reusable UI block with template, logic, props, and events.

### 203. What is SFC?

**Answer:** Single File Component: .vue file with template, script, and style.

### 204. What is reactivity?

**Answer:** State changes automatically update the UI.

### 205. What is ref()?

**Answer:** Creates reactive value accessed with .value in script.

### 206. What is reactive()?

**Answer:** Creates a reactive object.

### 207. ref vs reactive?

**Answer:** ref works for any value; reactive is best for objects.

### 208. What is computed?

**Answer:** Cached derived reactive value.

### 209. Computed vs method?

**Answer:** Computed is cached; method runs when called.

### 210. What is watch?

**Answer:** Runs side effects when reactive data changes.

### 211. watch vs computed?

**Answer:** Computed derives values; watch handles side effects.

### 212. What is v-model?

**Answer:** Two-way binding between input and state.

### 213. What is v-if?

**Answer:** Conditionally renders/removes DOM.

### 214. What is v-show?

**Answer:** Toggles display CSS while keeping DOM.

### 215. v-if vs v-show?

**Answer:** v-if for rare toggles; v-show for frequent toggles.

### 216. What is v-for?

**Answer:** Renders lists.

### 217. Why key in v-for?

**Answer:** Helps Vue track list items correctly.

### 218. Why avoid index as key?

**Answer:** It can cause wrong DOM reuse after reorder/delete.

### 219. What are props?

**Answer:** Parent-to-child data inputs.

### 220. What are emits?

**Answer:** Child-to-parent event communication.

### 221. Props down events up?

**Answer:** Parent sends props; child emits events.

### 222. What is slot?

**Answer:** Parent-provided content inside child component.

### 223. What is named slot?

**Answer:** Slot with a specific name.

### 224. What is scoped slot?

**Answer:** Slot that receives data from child component.

### 225. What is lifecycle hook?

**Answer:** Function called during component lifecycle.

### 226. Common Vue 3 hooks?

**Answer:** onMounted, onUpdated, onUnmounted.

### 227. When use onMounted?

**Answer:** For initial API calls or DOM-dependent logic.

### 228. What is Vue Router?

**Answer:** Official SPA routing library.

### 229. What are route params?

**Answer:** Dynamic URL parts like /users/:id.

### 230. What are query params?

**Answer:** URL values like ?page=1.

### 231. How protect routes?

**Answer:** Use navigation guards.

### 232. What is Pinia?

**Answer:** Modern recommended Vue state management library.

### 233. Pinia vs Vuex?

**Answer:** Pinia is simpler and more TypeScript-friendly; Vuex is older.

### 234. What is Vuex?

**Answer:** Centralized state management with state, getters, mutations, actions.

### 235. What is store?

**Answer:** Shared application state container.

### 236. What is action?

**Answer:** Store method for async/business logic.

### 237. What is getter?

**Answer:** Derived store state.

### 238. What is mutation?

**Answer:** Vuex method to synchronously change state.

### 239. What is composable?

**Answer:** Reusable Composition API function like useAuth().

### 240. What is provide/inject?

**Answer:** Pass data from ancestor to descendant without prop drilling.

### 241. What is prop drilling?

**Answer:** Passing props through many levels unnecessarily.

### 242. What is Teleport?

**Answer:** Render component content elsewhere in DOM.

### 243. What is Fragment?

**Answer:** Multiple root elements in Vue 3 component.

### 244. What is Suspense?

**Answer:** Fallback UI for async dependencies.

### 245. What is dynamic component?

**Answer:** Rendering component with <component :is='...'>.

### 246. What is async component?

**Answer:** Component loaded lazily.

### 247. What is lazy route loading?

**Answer:** Loading route component only when visited.

### 248. What is Vite?

**Answer:** Fast frontend build tool.

### 249. Vite vs Vue CLI?

**Answer:** Vite is modern/faster; Vue CLI is Webpack-based.

### 250. What is template ref?

**Answer:** Reference to DOM element or child component.

### 251. What is directive?

**Answer:** Special template attribute like v-if or v-model.

### 252. What is custom directive?

**Answer:** Reusable low-level DOM behavior.

### 253. What happened to filters in Vue 3?

**Answer:** Filters were removed; use computed or methods.

### 254. What happened to event bus in Vue 3?

**Answer:** It is not recommended; use props/emits, Pinia, provide/inject.

### 255. What is $attrs?

**Answer:** Non-prop attributes passed to a component.

### 256. What is defineProps?

**Answer:** Declares props in script setup.

### 257. What is defineEmits?

**Answer:** Declares emitted events in script setup.

### 258. What is defineExpose?

**Answer:** Exposes selected internals to parent refs.

### 259. What is nextTick?

**Answer:** Waits for DOM update after state change.

### 260. Why use nextTick?

**Answer:** To safely access updated DOM.

### 261. How call API in Vue?

**Answer:** Use fetch/Axios in composables, stores, or lifecycle hooks.

### 262. How handle loading state?

**Answer:** Use reactive loading/error/data states.

### 263. How prevent duplicate submit?

**Answer:** Disable button while loading and guard handler.

### 264. How handle auth in Vue?

**Answer:** Store token/session, attach token, protect routes, clear state on logout.

### 265. Where store token?

**Answer:** HttpOnly cookie is safer; localStorage is convenient but XSS-exposed.

### 266. What is Axios interceptor?

**Answer:** Global request/response hook for token/error handling.

### 267. How handle Laravel 422 in Vue?

**Answer:** Map response errors to form fields.

### 268. What is debounce?

**Answer:** Delay action until user stops triggering.

### 269. What is throttle?

**Answer:** Limit action to once per interval.

### 270. How optimize Vue?

**Answer:** Lazy-load, use computed, stable keys, pagination, smaller components.

### 271. What is virtual DOM?

**Answer:** In-memory representation for efficient DOM updates.

### 272. What is SPA?

**Answer:** Single-page app with client-side routing.

### 273. What is SSR?

**Answer:** Server-side rendering for initial HTML.

### 274. What is Nuxt?

**Answer:** Vue framework for SSR/SSG/full-stack features.

### 275. What is TypeScript in Vue?

**Answer:** Static typing for props, emits, stores, API models.

### 276. How structure Vue project?

**Answer:** components, views, router, stores, services, composables, assets, types.

### 277. What is reusable table?

**Answer:** Component accepting columns/data/loading and emitting actions.

### 278. How sibling components communicate?

**Answer:** Lift state to parent or use store/provide-inject.

### 279. Vue anti-patterns?

**Answer:** Mutating props, huge components, index keys, too many watchers, direct DOM manipulation.

### 280. What is data() in Options API?

**Answer:** Function returning local reactive state.

### 281. Why data must be function?

**Answer:** Each component instance needs separate state.

### 282. What is this in Options API?

**Answer:** Component instance reference.

### 283. Why no this in script setup?

**Answer:** Variables are directly available from setup scope.

### 284. What is shallowRef?

**Answer:** Tracks only .value changes, not deep nested changes.

### 285. What is readonly?

**Answer:** Creates read-only reactive object.

### 286. What is toRefs?

**Answer:** Converts reactive object properties into refs.

### 287. Why destructuring can break reactivity?

**Answer:** It extracts plain values unless using toRefs/storeToRefs.

### 288. What is storeToRefs?

**Answer:** Pinia helper preserving reactivity when destructuring store state.

## JavaScript, TypeScript, HTML & CSS

### 289. What is JavaScript?

**Answer:** A language used to build interactive web behavior and frontend apps.

### 290. What is TypeScript?

**Answer:** JavaScript with static types.

### 291. JS vs TS?

**Answer:** TS adds compile-time type checking and compiles to JS.

### 292. What is var?

**Answer:** Function-scoped older variable declaration.

### 293. What is let?

**Answer:** Block-scoped variable that can be reassigned.

### 294. What is const?

**Answer:** Block-scoped variable that cannot be reassigned.

### 295. var vs let vs const?

**Answer:** var is function-scoped; let/const are block-scoped. Prefer const, then let.

### 296. What is hoisting?

**Answer:** Declarations are processed before execution.

### 297. What is temporal dead zone?

**Answer:** Period before let/const initialization where access throws error.

### 298. What is closure?

**Answer:** Function remembers outer scope variables.

### 299. What is callback?

**Answer:** Function passed to another function.

### 300. What is Promise?

**Answer:** Object representing future async result.

### 301. What is async/await?

**Answer:** Cleaner syntax for Promise-based async code.

### 302. Promise vs async/await?

**Answer:** Same async model; async/await improves readability.

### 303. What is event loop?

**Answer:** Mechanism handling call stack and async queues.

### 304. What is microtask?

**Answer:** Promise callbacks and similar high-priority async tasks.

### 305. What is macrotask?

**Answer:** setTimeout, events, I/O tasks.

### 306. What is DOM?

**Answer:** Object representation of HTML document.

### 307. What is event bubbling?

**Answer:** Event moves from target to ancestors.

### 308. What is event capturing?

**Answer:** Event moves from ancestors to target.

### 309. What is event delegation?

**Answer:** Handling child events at parent level.

### 310. What is this?

**Answer:** Execution context depending on call site.

### 311. Arrow vs normal function?

**Answer:** Arrow has lexical this; normal function has dynamic this.

### 312. What is destructuring?

**Answer:** Extracting values from arrays/objects.

### 313. What is spread?

**Answer:** Expanding arrays/objects using ...

### 314. What is rest?

**Answer:** Collecting remaining values using ...

### 315. What is template literal?

**Answer:** Backtick string with interpolation.

### 316. What is module?

**Answer:** File exporting/importing code.

### 317. Default vs named export?

**Answer:** Default exports one main value; named exports multiple named values.

### 318. What is optional chaining?

**Answer:** Safe access with ?..

### 319. What is nullish coalescing?

**Answer:** Fallback only for null/undefined using ??.

### 320. What are falsy values?

**Answer:** false, 0, '', null, undefined, NaN.

### 321. What is shallow copy?

**Answer:** Top-level copy with shared nested references.

### 322. What is deep copy?

**Answer:** Copy including nested values.

### 323. What is map()?

**Answer:** Transforms array and returns new array.

### 324. What is filter()?

**Answer:** Returns items matching condition.

### 325. What is reduce()?

**Answer:** Accumulates array into one result.

### 326. What is forEach()?

**Answer:** Iterates for side effects.

### 327. map vs forEach?

**Answer:** map returns array; forEach returns undefined.

### 328. What is find()?

**Answer:** Returns first matching item.

### 329. What is some()?

**Answer:** True if any item matches.

### 330. What is every()?

**Answer:** True if all items match.

### 331. What is sort() caveat?

**Answer:** It mutates array and sorts as string by default.

### 332. What is JSON?

**Answer:** Text format for structured data.

### 333. What is fetch?

**Answer:** Browser API for HTTP requests.

### 334. Fetch vs Axios?

**Answer:** Fetch is built-in; Axios has interceptors and easier error handling.

### 335. What is CORS?

**Answer:** Browser cross-origin request security.

### 336. What is localStorage?

**Answer:** Persistent browser key-value storage.

### 337. What is sessionStorage?

**Answer:** Tab/session-limited browser storage.

### 338. localStorage vs cookie?

**Answer:** localStorage is JS-accessible; cookies can be HttpOnly and auto-sent.

### 339. What is debounce?

**Answer:** Delay function until events stop.

### 340. What is throttle?

**Answer:** Limit function execution frequency.

### 341. What is immutability?

**Answer:** Avoid mutating existing data directly.

### 342. What is prototype?

**Answer:** JavaScript inheritance mechanism.

### 343. What is class in JS?

**Answer:** Syntax for constructor/prototype-based objects.

### 344. What is try/catch?

**Answer:** Error handling block.

### 345. How handle API errors?

**Answer:** Use try/catch, status checks, user messages, and logs.

### 346. What is form validation?

**Answer:** Checking user input before and after submit.

### 347. What is responsive design?

**Answer:** UI adapts to screen sizes.

### 348. What is Flexbox?

**Answer:** One-dimensional CSS layout system.

### 349. What is Grid?

**Answer:** Two-dimensional CSS layout system.

### 350. Flexbox vs Grid?

**Answer:** Flexbox for row/column flow; Grid for rows and columns.

### 351. What is specificity?

**Answer:** CSS rule priority calculation.

### 352. What is semantic HTML?

**Answer:** Meaningful tags like header, nav, main, section.

### 353. What is accessibility?

**Answer:** Making UI usable by everyone, including disabled users.

### 354. What is ARIA?

**Answer:** Accessibility attributes for complex UI.

### 355. What is npm?

**Answer:** JavaScript package manager.

### 356. What is package.json?

**Answer:** Project dependency and script metadata.

### 357. dependencies vs devDependencies?

**Answer:** Runtime/build needs vs development tools.

### 358. What is ESLint?

**Answer:** Code quality/linting tool.

### 359. What is Prettier?

**Answer:** Code formatting tool.

### 360. What is bundling?

**Answer:** Combining/transpiling assets for browser delivery.

### 361. What is tree shaking?

**Answer:** Removing unused code from bundle.

### 362. What is source map?

**Answer:** Maps built code back to source for debugging.

### 363. What is TS interface?

**Answer:** Defines object shape.

### 364. Interface vs type?

**Answer:** Interface is extendable/mergeable; type is flexible for unions/intersections.

### 365. What is generic?

**Answer:** Reusable type parameter.

### 366. What is union type?

**Answer:** A value can be one of several types.

### 367. What is any?

**Answer:** Disables type checking.

### 368. What is unknown?

**Answer:** Safer type requiring narrowing.

### 369. What is type narrowing?

**Answer:** Refining type using checks.

## SQL & MySQL

### 370. What is SQL?

**Answer:** Language for relational database queries.

### 371. What is MySQL?

**Answer:** A relational database commonly used with PHP/Laravel.

### 372. What is table?

**Answer:** Rows and columns storing one entity type.

### 373. What is row?

**Answer:** One record.

### 374. What is column?

**Answer:** One field/attribute.

### 375. What is primary key?

**Answer:** Unique row identifier.

### 376. What is foreign key?

**Answer:** Column referencing another table.

### 377. What is unique key?

**Answer:** Constraint preventing duplicate values.

### 378. Primary vs unique key?

**Answer:** Primary identifies row and is not null; unique prevents duplicates.

### 379. What is index?

**Answer:** Data structure improving query speed.

### 380. What is composite index?

**Answer:** Index on multiple columns.

### 381. What is normalization?

**Answer:** Reducing duplication and improving consistency.

### 382. What is denormalization?

**Answer:** Adding duplication/precomputed data for read performance.

### 383. What is SELECT?

**Answer:** Retrieves data.

### 384. What is WHERE?

**Answer:** Filters rows.

### 385. What is ORDER BY?

**Answer:** Sorts rows.

### 386. What is GROUP BY?

**Answer:** Groups rows for aggregation.

### 387. What is HAVING?

**Answer:** Filters grouped results.

### 388. WHERE vs HAVING?

**Answer:** WHERE before grouping; HAVING after grouping.

### 389. What is LIMIT?

**Answer:** Restricts returned rows.

### 390. What is OFFSET?

**Answer:** Skips rows.

### 391. What is INNER JOIN?

**Answer:** Returns matching rows from both tables.

### 392. What is LEFT JOIN?

**Answer:** Returns all left rows and matching right rows.

### 393. INNER vs LEFT JOIN?

**Answer:** INNER only matched; LEFT keeps left rows.

### 394. What is self join?

**Answer:** A table joined with itself.

### 395. What is subquery?

**Answer:** Query inside another query.

### 396. What is correlated subquery?

**Answer:** Subquery depending on outer query row.

### 397. What is aggregate function?

**Answer:** COUNT, SUM, AVG, MIN, MAX.

### 398. COUNT(\*) vs COUNT(column)?

**Answer:** COUNT(\*) counts rows; COUNT(column) counts non-null values.

### 399. What is DISTINCT?

**Answer:** Removes duplicates.

### 400. What is alias?

**Answer:** Temporary name for table/column.

### 401. What is transaction?

**Answer:** Atomic group of operations.

### 402. What is ACID?

**Answer:** Atomicity, Consistency, Isolation, Durability.

### 403. What is COMMIT?

**Answer:** Save transaction changes.

### 404. What is ROLLBACK?

**Answer:** Cancel transaction changes.

### 405. What is deadlock?

**Answer:** Transactions wait on each other's locks.

### 406. How reduce deadlocks?

**Answer:** Short transactions, consistent order, proper indexes.

### 407. What is lock?

**Answer:** Control for concurrent data access.

### 408. What is row lock?

**Answer:** Lock on selected rows.

### 409. What is optimistic locking?

**Answer:** Detect conflict using version/timestamp.

### 410. What is pessimistic locking?

**Answer:** Lock before update.

### 411. What is isolation level?

**Answer:** Controls transaction visibility.

### 412. What is dirty read?

**Answer:** Reading uncommitted data.

### 413. What is non-repeatable read?

**Answer:** Same row gives different values in one transaction.

### 414. What is phantom read?

**Answer:** Repeated query sees new/deleted rows.

### 415. What is EXPLAIN?

**Answer:** Shows query execution plan.

### 416. What is slow query?

**Answer:** Query taking too long due to scans/bad indexes/etc.

### 417. How optimize email search?

**Answer:** Index email and use exact match.

### 418. Why LIKE '%x%' is slow?

**Answer:** Leading wildcard prevents normal index use.

### 419. What is NULL?

**Answer:** Missing/unknown value.

### 420. How compare NULL?

**Answer:** Use IS NULL or IS NOT NULL.

### 421. What is COALESCE?

**Answer:** Returns first non-null value.

### 422. What is CASE?

**Answer:** Conditional expression in SQL.

### 423. What is UNION?

**Answer:** Combines SELECT results and removes duplicates.

### 424. UNION vs UNION ALL?

**Answer:** UNION removes duplicates; UNION ALL keeps them and is faster.

### 425. What is view?

**Answer:** Saved query used like virtual table.

### 426. What is trigger?

**Answer:** Auto-run logic on insert/update/delete.

### 427. What is stored procedure?

**Answer:** Database-side reusable procedure.

### 428. What is cascade delete?

**Answer:** Child rows delete automatically when parent deletes.

### 429. What is restrict delete?

**Answer:** Prevents deleting parent with children.

### 430. What is soft delete?

**Answer:** Mark deleted instead of removing row.

### 431. What are timestamps?

**Answer:** created_at and updated_at fields.

### 432. What is many-to-many?

**Answer:** Relationship through pivot table.

### 433. What is one-to-many?

**Answer:** One parent has many children.

### 434. What is one-to-one?

**Answer:** One row maps to one related row.

### 435. What is ERD?

**Answer:** Diagram of entities and relationships.

### 436. What is migration?

**Answer:** Versioned schema change.

### 437. What is seeding?

**Answer:** Inserting initial/sample data.

### 438. What is backup?

**Answer:** Data copy for recovery.

### 439. What is replication?

**Answer:** Copying data to replica servers.

### 440. What is read replica?

**Answer:** Database replica for read traffic.

### 441. What is connection pool?

**Answer:** Reusable DB connections.

### 442. What is decimal vs float for money?

**Answer:** Use DECIMAL for exact money values.

### 443. What is check constraint?

**Answer:** Rule like amount >= 0.

### 444. What is upsert?

**Answer:** Insert or update if conflict exists.

### 445. What is selectivity?

**Answer:** How well an index filters rows.

### 446. When not to index?

**Answer:** Rarely queried/low-selectivity columns or too many write-heavy indexes.

### 447. How design order tables?

**Answer:** orders for header, order_items for item lines.

### 448. Why store price snapshot?

**Answer:** Historical orders remain correct after price changes.

### 449. How filter by payment method?

**Answer:** Add validated payment_method filter in query and index if needed.

### 450. How prevent duplicate records?

**Answer:** Use unique constraints and handle duplicate errors.

## REST API & Web Backend

### 451. What is REST API?

**Answer:** Resource-based API using HTTP methods, status codes, and JSON.

### 452. What is resource?

**Answer:** An entity exposed by URL, like users or products.

### 453. What is GET?

**Answer:** Retrieve data.

### 454. What is POST?

**Answer:** Create resource or trigger action.

### 455. What is PUT?

**Answer:** Replace/update resource idempotently.

### 456. What is PATCH?

**Answer:** Partially update resource.

### 457. What is DELETE?

**Answer:** Delete or mark resource deleted.

### 458. PUT vs PATCH?

**Answer:** PUT full replacement; PATCH partial update.

### 459. What is idempotency?

**Answer:** Repeated same request has same final effect.

### 460. What is 200?

**Answer:** OK success.

### 461. What is 201?

**Answer:** Created.

### 462. What is 204?

**Answer:** Success with no body.

### 463. What is 400?

**Answer:** Bad request.

### 464. What is 401?

**Answer:** Unauthenticated.

### 465. What is 403?

**Answer:** Forbidden.

### 466. What is 404?

**Answer:** Not found.

### 467. What is 409?

**Answer:** Conflict.

### 468. What is 422?

**Answer:** Validation error.

### 469. What is 500?

**Answer:** Internal server error.

### 470. What is JSON response?

**Answer:** Structured API output in JSON format.

### 471. What is API versioning?

**Answer:** Maintaining versions like /api/v1.

### 472. What is pagination?

**Answer:** Returning data in pages.

### 473. What is sorting?

**Answer:** Ordering results using query parameters.

### 474. What is filtering?

**Answer:** Narrowing results with parameters.

### 475. What is JWT?

**Answer:** Signed token containing claims for auth.

### 476. What is Bearer token?

**Answer:** Token sent in Authorization: Bearer header.

### 477. What is refresh token?

**Answer:** Token used to get new access token.

### 478. What is rate limiting?

**Answer:** Restricting request frequency.

### 479. What is CORS preflight?

**Answer:** Browser OPTIONS check before cross-origin request.

### 480. What is OpenAPI/Swagger?

**Answer:** API documentation/testing specification.

### 481. What is Postman?

**Answer:** Tool to test APIs.

### 482. What is request validation?

**Answer:** Checking incoming data correctness.

### 483. What is response transformation?

**Answer:** Converting internal model to API-safe output.

### 484. Why not expose DB directly?

**Answer:** It leaks internals and breaks clients when schema changes.

### 485. What is consistent error format?

**Answer:** Standard message/errors/code structure.

### 486. What is correlation ID?

**Answer:** Unique request ID for tracing logs.

### 487. What should not be logged?

**Answer:** Passwords, tokens, secrets, and sensitive data.

### 488. What is timeout?

**Answer:** Maximum wait time for response.

### 489. What is retry?

**Answer:** Repeating failed request safely.

### 490. What is idempotency key?

**Answer:** Client key preventing duplicate processing.

### 491. What is webhook?

**Answer:** HTTP callback from external system.

### 492. How secure webhook?

**Answer:** Verify signature, timestamp, source, and idempotency.

### 493. How handle slow task?

**Answer:** Move to queue/background job.

### 494. What is API caching?

**Answer:** Store frequent responses/data temporarily.

### 495. What is ETag?

**Answer:** HTTP cache validator.

### 496. What is 304?

**Answer:** Not Modified.

### 497. What is API contract?

**Answer:** Agreed request/response behavior.

### 498. Why backward compatibility?

**Answer:** Avoid breaking frontend/mobile clients.

## Git, Linux & Deployment

### 499. What is Git?

**Answer:** Distributed version control system.

### 500. What is repository?

**Answer:** A project tracked by Git.

---

## Final Must-Revise Topics Before Interview

- Laravel routing, controllers, middleware, validation, Eloquent relationships, migrations, API Resources, queues, caching, authentication, and authorization.
- Vue 2 vs Vue 3, Options API vs Composition API, props/emits, Pinia/Vuex, router guards, Axios, validation errors, and reusable components.
- Raw PHP OOP, Composer, PDO, sessions/cookies, prepared statements, password hashing, file uploads, and security basics.
- SQL joins, indexes, transactions, normalization, pagination, slow query debugging, and order/order_items schema design.
- REST status codes, API filtering/sorting/pagination, JWT/Bearer auth, CORS, rate limiting, and consistent error responses.
- Practical debugging: Laravel 500, Vue blank page, 401/422, CORS, slow query, duplicate submit, and deployment issues.

## Suggested Self Introduction

> I am a full-stack developer focused on PHP/Laravel backend development and Vue.js frontend development. I have experience building REST APIs, working with MySQL databases, handling CRUD flows, validation, authentication, and debugging backend/frontend integration issues. I enjoy building scalable systems and smooth user experiences, and I am comfortable working independently as well as with a team.
