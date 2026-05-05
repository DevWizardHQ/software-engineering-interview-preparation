# Node.js Interview Questions

**Level:** Mid to Senior  
**Topics:** Core Node.js, Event Loop, Streams, Express.js, REST API, Security, Performance, Testing

---

## Table of Contents

1. [Core Node.js](#core-nodejs)
2. [Event Loop and Async](#event-loop-and-async)
3. [Modules and npm](#modules-and-npm)
4. [Streams and Buffers](#streams-and-buffers)
5. [Express.js](#expressjs)
6. [REST API Design](#rest-api-design)
7. [Authentication and Security](#authentication-and-security)
8. [Database Integration](#database-integration)
9. [Performance and Scalability](#performance-and-scalability)
10. [Error Handling](#error-handling)
11. [Testing](#testing)

---

## Core Node.js

### Q1. What is Node.js?

**Answer:**
Node.js is a JavaScript runtime built on Chrome's V8 engine. It enables JavaScript to run server-side, outside the browser.

Key characteristics:
- single-threaded (JS execution)
- non-blocking I/O
- event-driven architecture
- built-in modules (fs, http, path, crypto, etc.)
- npm ecosystem

---

### Q2. Why is Node.js good for I/O-intensive applications?

**Answer:**
Node.js uses non-blocking I/O. While waiting for a database query, file read, or network request, the main thread continues handling other requests. This is efficient when there are many concurrent I/O operations.

It is NOT ideal for CPU-intensive tasks (image processing, video encoding, cryptography) that block the main thread.

---

### Q3. How does Node.js handle concurrency if it's single-threaded?

**Answer:**
The main JavaScript thread is single-threaded, but Node.js uses:
- **Event loop** — coordinates async operations
- **libuv** — thread pool for I/O operations (default 4 threads)
- **OS async I/O** — delegate file/network operations to the OS

When an async operation completes, its callback is queued and picked up by the event loop.

---

### Q4. What is the difference between `process.nextTick` and `setImmediate`?

**Answer:**

- `process.nextTick` callbacks run before the event loop moves to the next phase (microtask-like, very high priority)
- `setImmediate` callbacks run in the check phase, after I/O events

```js
setImmediate(() => console.log('setImmediate'));
process.nextTick(() => console.log('nextTick'));
console.log('sync');

// Output: sync → nextTick → setImmediate
```

---

### Q5. What is the difference between `require` and `import`?

**Answer:**

| Feature | `require` (CommonJS) | `import` (ESM) |
|---------|---------------------|----------------|
| Loading | Synchronous | Asynchronous |
| Dynamic | `require(variable)` OK | `import()` for dynamic |
| Default in Node | Yes (historically) | Yes (with `"type": "module"`) |
| Tree shaking | No | Yes |

Modern Node.js supports both. Most new Node projects use ESM or TypeScript which compiles to either.

---

### Q6. What are Node.js built-in modules?

**Answer:**
Key built-in modules (no install needed):

| Module | Purpose |
|--------|---------|
| `fs` | File system operations |
| `path` | File path utilities |
| `http`/`https` | HTTP server/client |
| `crypto` | Cryptographic functions |
| `os` | Operating system info |
| `events` | EventEmitter |
| `stream` | Streaming data |
| `child_process` | Spawn subprocesses |
| `cluster` | Multi-process |
| `worker_threads` | CPU threads |

---

## Event Loop and Async

### Q7. Explain the Node.js event loop.

**Answer:**
The event loop processes async callbacks in phases:

```
timers → pending callbacks → idle/prepare → poll → check → close callbacks
```

1. **timers** — executes `setTimeout` and `setInterval` callbacks
2. **pending callbacks** — I/O error callbacks
3. **poll** — retrieves new I/O events, waits if queue is empty
4. **check** — executes `setImmediate` callbacks
5. **close callbacks** — `socket.on('close', ...)` etc.

Between each phase: microtasks run (Promises, `process.nextTick`).

---

### Q8. What is callback hell and how do you avoid it?

**Answer:**
Deeply nested callbacks that make code hard to read and maintain.

```js
// Callback hell
getUser(id, (user) => {
  getOrders(user.id, (orders) => {
    getItems(orders[0].id, (items) => {
      // ...
    });
  });
});
```

Solutions:
- **Promises** — `.then()` chaining
- **async/await** — reads like synchronous code
- **Named functions** — extract callbacks to separate functions

```js
// async/await
const user = await getUser(id);
const orders = await getOrders(user.id);
const items = await getItems(orders[0].id);
```

---

### Q9. What is a Promise?

**Answer:**
Represents the eventual result of an asynchronous operation.

States:
- `pending` — initial state
- `fulfilled` — operation succeeded
- `rejected` — operation failed

```js
const p = new Promise((resolve, reject) => {
  setTimeout(() => resolve('done'), 1000);
});

// Usage
p.then(result => console.log(result))
 .catch(err => console.error(err));
```

---

### Q10. How does `async/await` work?

**Answer:**
`async` functions always return a Promise. `await` pauses execution inside an `async` function until the Promise settles.

```js
async function fetchUser(id) {
  try {
    const user = await db.users.findById(id);
    return user;
  } catch (error) {
    throw new Error(`User not found: ${error.message}`);
  }
}
```

Under the hood, `async/await` is syntactic sugar over Promises.

---

### Q11. How do you run multiple async operations in parallel?

**Answer:**

```js
// Sequential (slower) — each awaits previous
const user = await getUser();
const posts = await getPosts();

// Parallel (faster) — all start simultaneously
const [user, posts] = await Promise.all([getUser(), getPosts()]);

// Parallel with error handling per promise
const results = await Promise.allSettled([getUser(), getPosts()]);

// Race — first to resolve wins
const first = await Promise.race([fast(), slow()]);
```

---

## Modules and npm

### Q12. What is `package.json`?

**Answer:**
Manifest file for a Node.js project. Contains:
- `name`, `version`, `description`
- `scripts` — npm script commands
- `dependencies` — runtime packages
- `devDependencies` — development-only packages
- `engines` — Node.js version requirements
- `type` — `"module"` for ESM

---

### Q13. Difference between `dependencies` and `devDependencies`?

**Answer:**

- `dependencies` — required in production (Express, Prisma, bcrypt)
- `devDependencies` — only for development/testing (ESLint, TypeScript, Jest, Nodemon)

```bash
npm install express          # → dependencies
npm install jest --save-dev  # → devDependencies
```

In production deployments: `npm install --production` skips devDependencies.

---

### Q14. What is `package-lock.json`?

**Answer:**
Locks exact versions of all installed packages (including transitive dependencies). Ensures reproducible installs across environments.

**Always commit `package-lock.json` to git.**

---

## Streams and Buffers

### Q15. What are streams in Node.js?

**Answer:**
Streams process data in chunks rather than loading everything into memory. Efficient for large files, network data.

Types:
- **Readable** — source of data (`fs.createReadStream`)
- **Writable** — destination (`fs.createWriteStream`)
- **Duplex** — both readable and writable (TCP socket)
- **Transform** — duplex that transforms data (gzip)

```js
const readable = fs.createReadStream('large-file.csv');
const writable = fs.createWriteStream('output.csv');

// Pipe: readable flows data into writable
readable.pipe(transform).pipe(writable);
```

---

### Q16. What is a Buffer?

**Answer:**
Fixed-size raw binary data allocated outside the V8 heap. Used for:
- file I/O
- network packets
- cryptographic operations
- working with binary protocols

```js
const buf = Buffer.from('Hello');
console.log(buf.toString()); // Hello
console.log(buf.toString('hex')); // 48656c6c6f
```

---

## Express.js

### Q17. What is Express.js?

**Answer:**
Minimal and flexible Node.js web framework. Provides:
- routing
- middleware system
- request/response helpers
- template engine integration

```js
const app = express();
app.use(express.json());

app.get('/users', async (req, res) => {
  const users = await User.findAll();
  res.json(users);
});

app.listen(3000);
```

---

### Q18. What is middleware in Express?

**Answer:**
Functions that execute during the request-response cycle. Each middleware receives `(req, res, next)` and either ends the request or calls `next()`.

```js
// Logging middleware
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

// Auth middleware
function authenticate(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  req.user = verifyToken(token);
  next();
}

app.get('/profile', authenticate, (req, res) => {
  res.json(req.user);
});
```

---

### Q19. What is the order of middleware execution?

**Answer:**
Middleware runs in the order it's defined with `app.use()`.

```js
app.use(logger);     // 1st
app.use(cors);       // 2nd
app.use(auth);       // 3rd
app.get('/', handler); // 4th (for GET /)
app.use(errorHandler); // last (4-arg function)
```

Error-handling middleware must have 4 parameters: `(err, req, res, next)`.

---

### Q20. How do you structure a large Express project?

**Answer:**

```
src/
├── app.js           ← express setup, middleware
├── server.js        ← start server, listen
├── routes/
│   ├── auth.routes.js
│   └── user.routes.js
├── controllers/     ← handle HTTP req/res
├── services/        ← business logic
├── repositories/    ← database queries
├── middleware/      ← auth, validation, error handling
├── models/          ← DB models/schemas
├── utils/           ← helpers, validators
└── config/          ← env, db config
```

---

## REST API Design

### Q21. What are RESTful API design principles?

**Answer:**
- **Resources** — nouns in URL (`/users`, `/orders`)
- **HTTP methods** — GET (read), POST (create), PUT/PATCH (update), DELETE (delete)
- **Stateless** — no client context stored on server
- **Standard status codes** — 200, 201, 400, 401, 403, 404, 422, 500
- **Consistent response format** — always same JSON structure
- **Versioning** — `/api/v1/`

---

### Q22. What are common HTTP status codes?

**Answer:**

| Code | Meaning | Use case |
|------|---------|----------|
| 200 | OK | Successful GET, PUT |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Invalid input |
| 401 | Unauthorized | Not authenticated |
| 403 | Forbidden | Authenticated but not allowed |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate resource |
| 422 | Unprocessable Entity | Validation failed |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server error |

---

### Q23. How do you implement pagination?

**Answer:**

**Offset-based:**
```js
// GET /jobs?page=2&limit=20
const { page = 1, limit = 20 } = req.query;
const offset = (page - 1) * limit;

const { rows, count } = await Job.findAndCountAll({
  limit: parseInt(limit),
  offset: parseInt(offset),
});

res.json({
  data: rows,
  meta: {
    total: count,
    page: parseInt(page),
    limit: parseInt(limit),
    totalPages: Math.ceil(count / limit),
  },
});
```

**Cursor-based (better for large datasets):**
```js
// GET /jobs?cursor=eyJpZCI6MTAwfQ==&limit=20
const jobs = await Job.findAll({
  where: { id: { [Op.gt]: decodedCursor.id } },
  limit: parseInt(limit),
});
```

---

### Q24. How do you handle input validation?

**Answer:**
Validate before reaching business logic. Use a library like **Zod**, **Joi**, or **class-validator** (NestJS).

```js
// With Zod
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(1).max(100),
});

app.post('/users', (req, res) => {
  const result = createUserSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({ errors: result.error.flatten() });
  }
  // proceed with result.data
});
```

---

## Authentication and Security

### Q25. How do you implement JWT authentication in Node.js?

**Answer:**

```js
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';

// Login
async function login(email, password) {
  const user = await User.findOne({ email });
  if (!user || !await bcrypt.compare(password, user.passwordHash)) {
    throw new Error('Invalid credentials');
  }
  
  const token = jwt.sign(
    { userId: user.id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
  
  const refreshToken = jwt.sign(
    { userId: user.id },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: '7d' }
  );
  
  return { token, refreshToken };
}

// Middleware
function authenticate(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });
  
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}
```

---

### Q26. How do you secure a Node.js API?

**Answer:**

```js
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import cors from 'cors';

// Security headers
app.use(helmet());

// CORS
app.use(cors({ origin: process.env.ALLOWED_ORIGIN }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
});
app.use('/api', limiter);

// Strict rate limit for auth
const authLimiter = rateLimit({ windowMs: 60 * 1000, max: 5 });
app.use('/api/auth', authLimiter);
```

Additional measures:
- validate and sanitize all input
- use parameterized queries (never string concatenation for SQL)
- hash passwords with bcrypt (cost factor ≥ 12)
- store secrets in environment variables
- log and monitor suspicious activity

---

### Q27. What is CORS and how do you configure it?

**Answer:**
CORS (Cross-Origin Resource Sharing) is a browser mechanism that restricts web pages from making requests to a different origin than the one that served the web page.

```js
app.use(cors({
  origin: ['https://myapp.com', 'https://admin.myapp.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true, // allow cookies
}));
```

---

## Database Integration

### Q28. How do you connect Node.js to PostgreSQL?

**Answer:**

**With `pg` (node-postgres):**
```js
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // connection pool size
});

const result = await pool.query(
  'SELECT * FROM users WHERE id = $1',
  [userId]
); // parameterized — prevents SQL injection
```

**With Prisma:**
```js
const user = await prisma.user.findUnique({ where: { id: userId } });
```

---

### Q29. What is connection pooling?

**Answer:**
Maintains a pool of open database connections instead of creating/closing one per request.

Benefits:
- eliminates connection overhead (~50-100ms per connection)
- limits concurrent connections to DB
- improves throughput under load

```js
const pool = new Pool({
  max: 20,        // max connections
  min: 2,         // min idle connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

---

### Q30. How do you handle database transactions?

**Answer:**

```js
// With pg
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('INSERT INTO orders ...', [orderData]);
  await client.query('UPDATE inventory SET stock = stock - 1 WHERE id = $1', [itemId]);
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
}

// With Prisma
await prisma.$transaction([
  prisma.order.create({ data: orderData }),
  prisma.inventory.update({ where: { id: itemId }, data: { stock: { decrement: 1 } } }),
]);
```

---

## Performance and Scalability

### Q31. How do you scale a Node.js application?

**Answer:**

**Single server — cluster module:**
```js
import cluster from 'cluster';
import os from 'os';

if (cluster.isPrimary) {
  const numCPUs = os.cpus().length;
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }
} else {
  app.listen(3000);
}
```

**Multi-server:**
- Load balancer (Nginx, AWS ALB) distributes traffic
- Keep instances stateless (no in-memory session)
- Shared session/cache via Redis
- Shared DB with connection pooling

---

### Q32. How do you handle CPU-intensive tasks?

**Answer:**
Move them off the main thread:
- **Worker threads** — Node.js built-in CPU threading
- **Child processes** — spawn separate Node processes
- **Job queues** — BullMQ + Redis, process in background workers

```js
import { Worker } from 'worker_threads';

const worker = new Worker('./image-processor.js', {
  workerData: { imagePath: req.file.path },
});

worker.on('message', (result) => res.json(result));
```

---

### Q33. What is caching in Node.js?

**Answer:**

**In-memory (single instance):**
```js
const cache = new Map();
const TTL = 60 * 1000;

function getCached(key, fetchFn) {
  const cached = cache.get(key);
  if (cached && Date.now() - cached.at < TTL) return cached.value;
  const value = fetchFn();
  cache.set(key, { value, at: Date.now() });
  return value;
}
```

**Redis (multi-instance, persistent):**
```js
const redis = new Redis(process.env.REDIS_URL);

async function getUser(id) {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);
  
  const user = await db.users.findById(id);
  await redis.setex(`user:${id}`, 300, JSON.stringify(user)); // TTL 5min
  return user;
}
```

---

## Error Handling

### Q34. How do you handle errors in Express?

**Answer:**

```js
// Async wrapper to catch promise rejections
function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

app.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) throw new NotFoundError('User not found');
  res.json(user);
}));

// Error handling middleware (must be last)
app.use((err, req, res, next) => {
  console.error(err);
  
  if (err instanceof ValidationError) {
    return res.status(422).json({ error: err.message, details: err.details });
  }
  if (err instanceof NotFoundError) {
    return res.status(404).json({ error: err.message });
  }
  
  res.status(500).json({ error: 'Internal server error' });
});
```

---

### Q35. How do you handle unhandled promise rejections?

**Answer:**

```js
// Catch unhandled promise rejections globally
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection:', reason);
  // Optionally: graceful shutdown
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});
```

With Node.js 15+, unhandled rejections throw by default.

---

### Q36. What is graceful shutdown?

**Answer:**
Stopping the server cleanly: stop accepting new requests, finish existing ones, close DB connections.

```js
const server = app.listen(3000);

async function shutdown() {
  console.log('Shutting down...');
  server.close(async () => {
    await db.pool.end();
    await redis.quit();
    process.exit(0);
  });
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
```

---

## Testing

### Q37. How do you test a Node.js API?

**Answer:**

**Unit tests — service layer:**
```js
import { describe, it, expect, vi } from 'vitest';

describe('UserService', () => {
  it('throws if user not found', async () => {
    vi.spyOn(userRepository, 'findById').mockResolvedValue(null);
    await expect(userService.getUser('123')).rejects.toThrow('User not found');
  });
});
```

**Integration tests — full HTTP:**
```js
import request from 'supertest';

describe('POST /api/auth/login', () => {
  it('returns token on valid credentials', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@test.com', password: 'password123' });
    
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });
});
```

---

### Q38. What is the difference between unit, integration, and e2e tests?

**Answer:**

| Type | Tests | Speed | Example |
|------|-------|-------|---------|
| Unit | One function/class | Fast | `hashPassword()` logic |
| Integration | Multiple layers together | Medium | API + DB interaction |
| E2E | Full user flow | Slow | Login → see dashboard |

**Testing pyramid:** many unit, some integration, few e2e.

---

## Quick Reference

### Common npm packages

| Package | Purpose |
|---------|---------|
| `express` | Web framework |
| `fastify` | Faster alternative to Express |
| `prisma` | TypeScript ORM |
| `pg` | PostgreSQL client |
| `mongoose` | MongoDB ODM |
| `jsonwebtoken` | JWT |
| `bcrypt` | Password hashing |
| `zod` | Schema validation |
| `joi` | Schema validation |
| `helmet` | Security headers |
| `cors` | CORS middleware |
| `express-rate-limit` | Rate limiting |
| `ioredis` | Redis client |
| `bullmq` | Job queues |
| `winston` | Logging |
| `pino` | Fast logging |
| `dotenv` | Env variables |
| `supertest` | HTTP testing |
| `vitest`/`jest` | Test runner |
