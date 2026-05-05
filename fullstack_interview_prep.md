# Full-Stack Developer Interview Preparation

**Role:** Full-Stack Developer — Laravel & Vue.js

---

## 1. Job Post Breakdown

### What they are looking for

Envaysoft is looking for a full-stack developer who can build scalable backend systems with Laravel and create smooth frontend interfaces using Vue.js. The job post strongly focuses on practical development ability, REST API integration, debugging, performance optimization, and teamwork.

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

### Q1. Why do you want to join Envaysoft?

```text
I want to join Envaysoft because the role matches my full-stack development interest. The company works on eCommerce and custom software solutions, which gives me the chance to work on real business applications. I like that the role involves Laravel backend, Vue frontend, REST APIs, performance, and scalable systems. I believe I can contribute quickly and also grow by working with the team.
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
2. Why Envaysoft?
3. Why should we hire you?
4. What are your strengths?
5. What are your weaknesses?
6. Are you comfortable with on-site work in Banasree?
7. Are you comfortable with 10 AM–6 PM office time?
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
