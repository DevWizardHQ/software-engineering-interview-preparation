# Node.js Interview Questions

A pedagogical Q&A guide for backend developers preparing for Node.js interviews. Each question includes a clear explanation and a working code example.

---

## 1. Core Node.js

## Q1. What is Node.js?

**Answer:**

Node.js is a JavaScript runtime built on top of Google's V8 engine. It lets you run JavaScript outside the browser, typically on a server. The runtime is single-threaded but handles thousands of concurrent connections using a non-blocking, event-driven I/O model.

```js
// hello.js
const http = require('http');

const server = http.createServer((req, res) => {
  res.end('Hello from Node.js');
});

server.listen(3000, () => console.log('Listening on 3000'));
```

Run it with `node hello.js`. A single process can serve many clients without spawning a thread per request.

## Q2. Why is Node.js good for I/O-intensive applications?

**Answer:**

Most server work is waiting: waiting for the database, waiting for an external API, waiting for a file. Traditional thread-per-request servers waste memory while threads sit idle. Node.js uses one thread plus an event loop. While one request is waiting, the thread serves another.

```js
const fs = require('fs/promises');

async function readBoth() {
  const [a, b] = await Promise.all([
    fs.readFile('a.txt', 'utf8'),
    fs.readFile('b.txt', 'utf8'),
  ]);
  return a + b;
}
```

Both reads happen in parallel at the OS level while the main thread is free to handle other work.

## Q3. How does Node.js handle concurrency if it is single-threaded?

**Answer:**

JavaScript runs on a single thread, but Node.js uses **libuv**, a C library that provides a thread pool for blocking work (file system, DNS, crypto) and an event loop that schedules callbacks. When you call `fs.readFile`, libuv hands the work to a worker thread, and your callback runs on the main thread once it finishes.

```js
const fs = require('fs');

console.log('1');
fs.readFile('big.txt', () => console.log('3 — file read'));
console.log('2');
// Output: 1, 2, 3
```

The main thread never blocks on the file read.

## Q4. What is the difference between `process.nextTick` and `setImmediate`?

**Answer:**

`process.nextTick` runs **before** the next phase of the event loop. `setImmediate` runs **on** the next iteration of the event loop, in the check phase. `nextTick` has higher priority and can starve I/O if abused.

```js
setImmediate(() => console.log('setImmediate'));
process.nextTick(() => console.log('nextTick'));
console.log('sync');

// Output:
// sync
// nextTick
// setImmediate
```

Use `nextTick` for "run right after the current operation," and `setImmediate` for "yield to I/O, then run."

## Q5. What is the difference between `require` and `import`?

**Answer:**

`require` is CommonJS: synchronous, dynamic, returns `module.exports`. `import` is ES modules: static, hoisted, supports tree-shaking. CommonJS is the default for `.js` files unless `package.json` has `"type": "module"`.

```js
// CommonJS
const express = require('express');
module.exports = function () {};

// ES Modules
import express from 'express';
export default function () {}
```

ES modules are the modern standard; new projects should prefer them.

## Q6. What are Node.js built-in modules?

**Answer:**

Node ships with modules for common tasks: `fs` (file system), `http`/`https`, `path`, `os`, `crypto`, `url`, `events`, `stream`, `child_process`, `worker_threads`. They require no installation.

```js
const path = require('path');
const os = require('os');
const crypto = require('crypto');

console.log(path.join('/var', 'log', 'app.log'));
console.log(os.totalmem());
console.log(crypto.randomUUID());
```

---

## 2. Event Loop and Async

## Q7. Explain the Node.js event loop.

**Answer:**

The event loop has six phases that run in order on every iteration:

1. **Timers** — `setTimeout`, `setInterval` callbacks
2. **Pending callbacks** — some system callbacks
3. **Idle/prepare** — internal
4. **Poll** — retrieve new I/O events
5. **Check** — `setImmediate` callbacks
6. **Close callbacks** — e.g. `socket.on('close')`

Between every phase, the microtask queue (Promises, `process.nextTick`) is drained.

```js
setTimeout(() => console.log('timeout'), 0);
setImmediate(() => console.log('immediate'));
Promise.resolve().then(() => console.log('promise'));
process.nextTick(() => console.log('nextTick'));
console.log('sync');

// sync, nextTick, promise, timeout, immediate
```

## Q8. What is callback hell and how do you avoid it?

**Answer:**

Callback hell is deeply nested callbacks that become unreadable. Solve it with named functions, Promises, or `async/await`.

```js
// Bad
fs.readFile('a.txt', (e, a) => {
  fs.readFile('b.txt', (e, b) => {
    fs.writeFile('c.txt', a + b, (e) => {
      console.log('done');
    });
  });
});

// Good
async function combine() {
  const a = await fs.promises.readFile('a.txt');
  const b = await fs.promises.readFile('b.txt');
  await fs.promises.writeFile('c.txt', a + b);
}
```

## Q9. What is a Promise?

**Answer:**

A Promise is an object representing the future result of an async operation. It has three states: pending, fulfilled, rejected. You attach handlers with `.then`, `.catch`, `.finally`.

```js
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

delay(1000)
  .then(() => console.log('1 second passed'))
  .catch((err) => console.error(err));
```

## Q10. How does `async/await` work?

**Answer:**

`async` makes a function return a Promise. `await` pauses the function until the Promise resolves, then returns its value. It is syntactic sugar over `.then` chains, but reads like synchronous code.

```js
async function getUser(id) {
  try {
    const res = await fetch(`/api/users/${id}`);
    if (!res.ok) throw new Error('Not found');
    return await res.json();
  } catch (err) {
    console.error(err);
    throw err;
  }
}
```

## Q11. How do you run multiple async operations in parallel?

**Answer:**

Use `Promise.all` for "all must succeed" or `Promise.allSettled` for "wait for all regardless of failure."

```js
// Sequential — slow
const a = await getA(); // 1s
const b = await getB(); // 1s -> total 2s

// Parallel — fast
const [a, b] = await Promise.all([getA(), getB()]); // 1s

// Don't fail fast
const results = await Promise.allSettled([getA(), getB()]);
results.forEach((r) => {
  if (r.status === 'fulfilled') console.log(r.value);
  else console.error(r.reason);
});
```

## Q12. What is `Promise.race` vs `Promise.any`?

**Answer:**

`Promise.race` resolves or rejects with the **first settled** Promise (whichever finishes first, win or lose). `Promise.any` resolves with the **first fulfilled** Promise and ignores rejections unless all reject.

```js
// Timeout pattern with race
function withTimeout(promise, ms) {
  const timeout = new Promise((_, rej) =>
    setTimeout(() => rej(new Error('Timeout')), ms)
  );
  return Promise.race([promise, timeout]);
}

await withTimeout(fetch('/slow'), 3000);
```

## Q13. What is an EventEmitter?

**Answer:**

`EventEmitter` is the core pattern for emitting and handling named events in Node.js. Many built-ins (HTTP server, streams) extend it.

```js
const EventEmitter = require('events');

class Cart extends EventEmitter {}
const cart = new Cart();

cart.on('item-added', (item) => console.log('Added:', item));
cart.emit('item-added', { sku: 'A1', qty: 2 });
```

---

## 3. Modules and npm

## Q14. What is `package.json`?

**Answer:**

`package.json` is the manifest of a Node project. It records the package name, version, scripts, dependencies, entry point, and metadata.

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "jest"
  },
  "dependencies": { "express": "^4.18.0" },
  "devDependencies": { "jest": "^29.0.0" }
}
```

## Q15. Difference between `dependencies` and `devDependencies`?

**Answer:**

`dependencies` are required at runtime in production (e.g. Express, Mongoose). `devDependencies` are only needed during development (e.g. Jest, ESLint, TypeScript).

```bash
npm install express              # dependencies
npm install --save-dev jest      # devDependencies
```

`npm install --production` skips devDependencies.

## Q16. What is `package-lock.json`?

**Answer:**

It locks the exact installed version of every dependency and sub-dependency, so all teammates and CI install the same tree. Always commit it.

```bash
npm ci   # uses lock file exactly, faster than npm install for CI
```

## Q17. What is the difference between `npm install` and `npm ci`?

**Answer:**

`npm install` may update the lock file. `npm ci` requires a clean `node_modules`, installs strictly from the lock file, and fails if `package.json` and `package-lock.json` disagree. Use `npm ci` in CI/CD.

## Q18. What are scoped packages?

**Answer:**

A scoped package belongs to a namespace prefixed with `@`, e.g. `@myorg/utils`. Useful for organizations that want to publish multiple related packages without name collisions.

```bash
npm install @nestjs/common
```

---

## 4. Streams and Buffers

## Q19. What are streams in Node.js?

**Answer:**

Streams process data piece by piece instead of loading everything into memory. Four types: Readable, Writable, Duplex, Transform. Use them for files, network sockets, and large data.

```js
const fs = require('fs');

// Stream a 5GB file with constant memory
fs.createReadStream('huge.log')
  .pipe(fs.createWriteStream('copy.log'))
  .on('finish', () => console.log('Done'));
```

## Q20. What is a Buffer?

**Answer:**

A Buffer is a fixed-size chunk of binary data outside the V8 heap. Use it for raw bytes: file reads, network packets, image processing.

```js
const buf = Buffer.from('hello', 'utf8');
console.log(buf);             // <Buffer 68 65 6c 6c 6f>
console.log(buf.toString());  // hello
console.log(buf.length);      // 5
```

## Q21. How do you transform stream data?

**Answer:**

Use a Transform stream to read input, modify it, and emit output.

```js
const { Transform } = require('stream');

const upper = new Transform({
  transform(chunk, enc, cb) {
    cb(null, chunk.toString().toUpperCase());
  },
});

process.stdin.pipe(upper).pipe(process.stdout);
```

## Q22. What is backpressure?

**Answer:**

Backpressure is when a writable stream is slower than its readable source. `pipe()` handles it automatically by pausing the readable side when the writable buffer is full.

```js
const ok = writable.write(chunk);
if (!ok) {
  readable.pause();
  writable.once('drain', () => readable.resume());
}
```

---

## 5. Express.js

## Q23. What is Express.js?

**Answer:**

Express is the most widely used minimal web framework for Node.js. It provides routing, middleware, and request/response helpers without imposing structure.

```js
const express = require('express');
const app = express();

app.use(express.json());

app.get('/users/:id', (req, res) => {
  res.json({ id: req.params.id });
});

app.listen(3000);
```

## Q24. What is middleware in Express?

**Answer:**

Middleware are functions with the signature `(req, res, next)` that run before the route handler. They can modify the request, send a response, or pass control with `next()`.

```js
function logger(req, res, next) {
  console.log(`${req.method} ${req.url}`);
  next();
}

function auth(req, res, next) {
  if (!req.headers.authorization) return res.status(401).end();
  next();
}

app.use(logger);
app.get('/private', auth, (req, res) => res.send('ok'));
```

## Q25. What is the order of middleware execution?

**Answer:**

Middleware runs in the order it was registered. Always register error-handling middleware (4 args: `err, req, res, next`) **last**.

```js
app.use(logger);          // 1
app.use(express.json());  // 2
app.use('/api', router);  // 3
app.use((err, req, res, next) => {  // last — errors only
  res.status(500).json({ error: err.message });
});
```

## Q26. How do you structure a large Express project?

**Answer:**

Split by feature: routes, controllers, services, models, middleware, validators. Keep route files thin.

```
src/
  routes/users.routes.js
  controllers/users.controller.js
  services/users.service.js
  models/user.model.js
  middleware/auth.js
  app.js
  server.js
```

```js
// users.routes.js
const router = require('express').Router();
const ctrl = require('../controllers/users.controller');
router.get('/', ctrl.list);
router.post('/', ctrl.create);
module.exports = router;
```

## Q27. What is `app.use` vs `app.get`?

**Answer:**

`app.use` mounts middleware for **all HTTP methods** at the given path. `app.get` only matches GET requests at the exact path. `use` paths are prefixes (`/api` matches `/api/anything`); `get` paths are exact unless they include params.

---

## 6. REST API Design

## Q28. What are RESTful API design principles?

**Answer:**

REST uses HTTP verbs against resource URLs. Be consistent, stateless, and predictable.

| Verb   | URL              | Action       |
| ------ | ---------------- | ------------ |
| GET    | /users           | List users   |
| GET    | /users/123       | Get one      |
| POST   | /users           | Create       |
| PUT    | /users/123       | Replace      |
| PATCH  | /users/123       | Partial update |
| DELETE | /users/123       | Remove       |

## Q29. What are common HTTP status codes?

**Answer:**

| Code | Meaning                |
| ---- | ---------------------- |
| 200  | OK                     |
| 201  | Created                |
| 204  | No Content             |
| 400  | Bad Request            |
| 401  | Unauthorized           |
| 403  | Forbidden              |
| 404  | Not Found              |
| 409  | Conflict               |
| 422  | Unprocessable Entity   |
| 429  | Too Many Requests      |
| 500  | Internal Server Error  |

```js
res.status(201).json(newUser);
res.status(404).json({ error: 'Not found' });
```

## Q30. How do you implement pagination?

**Answer:**

Two common styles: offset/limit (simple) and cursor (stable for large data).

```js
// Offset pagination
app.get('/users', async (req, res) => {
  const page = Number(req.query.page) || 1;
  const limit = Number(req.query.limit) || 20;
  const offset = (page - 1) * limit;

  const [rows, [{ count }]] = await Promise.all([
    db.query('SELECT * FROM users LIMIT ? OFFSET ?', [limit, offset]),
    db.query('SELECT COUNT(*) AS count FROM users'),
  ]);

  res.json({ data: rows, page, total: count });
});
```

```js
// Cursor pagination
app.get('/feed', async (req, res) => {
  const cursor = req.query.cursor;
  const rows = await db.query(
    'SELECT * FROM posts WHERE id < ? ORDER BY id DESC LIMIT 20',
    [cursor || Number.MAX_SAFE_INTEGER],
  );
  res.json({ data: rows, nextCursor: rows[rows.length - 1]?.id });
});
```

## Q31. How do you handle input validation?

**Answer:**

Validate every input at the boundary. Use a schema library like `zod`, `joi`, or `express-validator`.

```js
const { z } = require('zod');

const schema = z.object({
  email: z.string().email(),
  age: z.number().int().min(0),
});

app.post('/users', (req, res) => {
  const result = schema.safeParse(req.body);
  if (!result.success) return res.status(422).json(result.error);
  res.json(result.data);
});
```

## Q32. What is HATEOAS?

**Answer:**

Hypermedia as the Engine of Application State — REST responses include links to related actions so clients can discover the API.

```json
{
  "id": 1,
  "name": "Alice",
  "_links": {
    "self": "/users/1",
    "orders": "/users/1/orders"
  }
}
```

Most real APIs do not implement strict HATEOAS, but include relevant links in responses.

---

## 7. Authentication and Security

## Q33. How do you implement JWT authentication in Node.js?

**Answer:**

Generate a signed token at login, send it as a Bearer header on subsequent requests, verify it in middleware.

```js
const jwt = require('jsonwebtoken');
const SECRET = process.env.JWT_SECRET;

app.post('/login', async (req, res) => {
  const user = await User.findOne({ email: req.body.email });
  if (!user || !(await bcrypt.compare(req.body.password, user.hash))) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  const token = jwt.sign({ sub: user.id }, SECRET, { expiresIn: '15m' });
  res.json({ token });
});

function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.replace('Bearer ', '');
  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

app.get('/me', auth, (req, res) => res.json(req.user));
```

## Q34. How do you hash passwords?

**Answer:**

Use bcrypt or argon2 — never store plain or simple-hashed passwords. They are slow on purpose to defeat brute force.

```js
const bcrypt = require('bcrypt');

const hash = await bcrypt.hash(plain, 12);
const isMatch = await bcrypt.compare(plain, hash);
```

## Q35. How do you secure a Node.js API?

**Answer:**

- Use `helmet` to set safe HTTP headers
- Validate all inputs (`zod`, `joi`)
- Rate limit (`express-rate-limit`)
- Hash passwords (bcrypt)
- Sign and verify JWTs
- Use HTTPS, HSTS
- Sanitize against SQL injection (parameterized queries)
- Configure CORS strictly
- Keep secrets in env vars
- Run dependencies through `npm audit`

```js
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

app.use(helmet());
app.use(rateLimit({ windowMs: 60_000, max: 60 }));
```

## Q36. What is CORS and how do you configure it?

**Answer:**

CORS (Cross-Origin Resource Sharing) lets a browser call your API from a different origin. By default, browsers block cross-origin XHR/fetch.

```js
const cors = require('cors');

app.use(cors({
  origin: ['https://app.example.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
}));
```

## Q37. What is a refresh token?

**Answer:**

A longer-lived token used to obtain a new access token without re-login. Store it server-side (DB) so you can revoke it.

```js
// At login: issue both
const access = jwt.sign({ sub: user.id }, SECRET, { expiresIn: '15m' });
const refresh = jwt.sign({ sub: user.id }, REFRESH_SECRET, { expiresIn: '7d' });
await db.saveRefreshToken(user.id, refresh);

// /refresh endpoint
app.post('/refresh', async (req, res) => {
  const { refresh } = req.body;
  const valid = await db.findRefreshToken(refresh);
  if (!valid) return res.status(401).end();
  const payload = jwt.verify(refresh, REFRESH_SECRET);
  const access = jwt.sign({ sub: payload.sub }, SECRET, { expiresIn: '15m' });
  res.json({ access });
});
```

---

## 8. Database Integration

## Q38. How do you connect Node.js to PostgreSQL?

**Answer:**

Use the `pg` driver with a connection pool.

```js
const { Pool } = require('pg');
const pool = new Pool({
  host: 'localhost',
  user: 'app',
  password: 'secret',
  database: 'shop',
  max: 10,
});

const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [1]);
```

## Q39. What is connection pooling?

**Answer:**

Opening a database connection is expensive. A pool keeps a fixed set of open connections and lends them to requests. The pool reuses connections instead of opening one per query.

```js
const pool = new Pool({ max: 20, idleTimeoutMillis: 30_000 });

async function getUsers() {
  const client = await pool.connect();
  try {
    return await client.query('SELECT * FROM users');
  } finally {
    client.release();
  }
}
```

## Q40. How do you handle database transactions?

**Answer:**

Begin a transaction, commit on success, rollback on error. Always release the client.

```js
async function transfer(fromId, toId, amount) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, fromId]);
    await client.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, toId]);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
```

## Q41. What is an ORM and why use one?

**Answer:**

An ORM (Sequelize, Prisma, TypeORM) maps database rows to JavaScript objects. Pros: less boilerplate, migrations, type safety. Cons: hides SQL, can produce slow queries (N+1).

```js
// Prisma example
const user = await prisma.user.findUnique({
  where: { email: 'a@b.com' },
  include: { posts: true },
});
```

## Q42. What is the N+1 query problem?

**Answer:**

Looping over N records and doing one query per record yields 1+N total queries. Solve it by joining or batch-loading.

```js
// Bad: N+1
const users = await User.findAll();
for (const u of users) {
  u.posts = await Post.findAll({ where: { userId: u.id } });
}

// Good: eager load
const users = await User.findAll({ include: [Post] });
```

---

## 9. Performance and Scalability

## Q43. How do you scale a Node.js application?

**Answer:**

- **Vertical**: more CPU/RAM on one machine
- **Horizontal**: multiple instances behind a load balancer
- **Cluster module**: fork worker processes equal to CPU cores
- **PM2**: process manager that handles cluster + restart
- **Stateless** servers + shared cache (Redis) so any instance can serve any request

```js
const cluster = require('cluster');
const os = require('os');

if (cluster.isPrimary) {
  for (let i = 0; i < os.cpus().length; i++) cluster.fork();
} else {
  require('./server');
}
```

## Q44. How do you handle CPU-intensive tasks?

**Answer:**

Move them off the event loop. Use `worker_threads` for in-process parallelism or a queue (BullMQ + Redis) for offloading to a separate worker service.

```js
const { Worker } = require('worker_threads');

function runHeavy(data) {
  return new Promise((resolve, reject) => {
    const w = new Worker('./heavy.js', { workerData: data });
    w.on('message', resolve);
    w.on('error', reject);
  });
}
```

## Q45. What is caching in Node.js?

**Answer:**

Cache frequently accessed data to reduce DB load and latency. In-memory for one process, Redis for shared cache across instances.

```js
const Redis = require('ioredis');
const redis = new Redis();

async function getProduct(id) {
  const cached = await redis.get(`product:${id}`);
  if (cached) return JSON.parse(cached);

  const product = await db.findProduct(id);
  await redis.set(`product:${id}`, JSON.stringify(product), 'EX', 60);
  return product;
}
```

## Q46. How do you find performance bottlenecks?

**Answer:**

- `node --inspect` + Chrome DevTools profiler
- `clinic.js` for flame graphs and event loop lag
- Monitor with `prom-client` (Prometheus) + Grafana
- Track P95/P99 latency, not just averages

```js
console.time('query');
await db.query(sql);
console.timeEnd('query'); // query: 23ms
```

## Q47. What is event loop lag and how do you measure it?

**Answer:**

Lag is the gap between a scheduled timer and when it actually runs — high lag means CPU-bound code is blocking the loop.

```js
let last = Date.now();
setInterval(() => {
  const now = Date.now();
  const lag = now - last - 1000;
  console.log('Lag:', lag, 'ms');
  last = now;
}, 1000);
```

---

## 10. Error Handling

## Q48. How do you handle errors in Express?

**Answer:**

Use try/catch in async handlers, forward errors with `next(err)`, and define a single error-handling middleware.

```js
app.get('/users/:id', async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'Not found' });
    res.json(user);
  } catch (err) {
    next(err);
  }
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message });
});
```

A small wrapper removes try/catch boilerplate:

```js
const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);
app.get('/users', wrap(async (req, res) => { /* ... */ }));
```

## Q49. How do you handle unhandled promise rejections?

**Answer:**

Catch them at the process level, log, and crash the process so a supervisor restarts it.

```js
process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
  process.exit(1);
});

process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  process.exit(1);
});
```

## Q50. What is graceful shutdown?

**Answer:**

When the process receives SIGTERM, stop accepting new requests, finish in-flight ones, close DB connections, then exit.

```js
const server = app.listen(3000);

function shutdown() {
  console.log('Shutting down...');
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
```

## Q51. How do you create a custom error class?

**Answer:**

Extend `Error` to carry extra context like an HTTP status.

```js
class AppError extends Error {
  constructor(message, status = 500) {
    super(message);
    this.status = status;
  }
}

class NotFoundError extends AppError {
  constructor(msg = 'Not found') { super(msg, 404); }
}

throw new NotFoundError('User not found');
```

---

## 11. Testing

## Q52. How do you test a Node.js API?

**Answer:**

Use Jest or Vitest as the test runner and `supertest` for HTTP assertions.

```js
const request = require('supertest');
const app = require('../app');

describe('GET /users', () => {
  it('returns 200 and a list', async () => {
    const res = await request(app).get('/users');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
```

## Q53. What is the difference between unit, integration, and e2e tests?

**Answer:**

| Type        | Scope                              | Speed | Example                   |
| ----------- | ---------------------------------- | ----- | ------------------------- |
| Unit        | One function or class, mocks deps  | Fast  | `formatPrice(100)`        |
| Integration | Multiple modules + DB              | Med   | Service hits real Postgres |
| E2E         | Full stack from HTTP to DB         | Slow  | `POST /orders` end-to-end |

## Q54. How do you mock a dependency in Jest?

**Answer:**

```js
jest.mock('../services/email');
const email = require('../services/email');
email.send.mockResolvedValue(true);

await registerUser({ email: 'a@b.com' });
expect(email.send).toHaveBeenCalledWith('a@b.com', expect.any(String));
```

---

## 12. Deployment and Operations

## Q55. How do you containerize a Node.js app?

**Answer:**

Use a multi-stage Dockerfile so the production image only contains what is needed.

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

## Q56. How do you manage environment variables?

**Answer:**

Never commit secrets. Load `.env` in development with `dotenv`; in production, set them in the host (Docker, Kubernetes, Heroku).

```js
require('dotenv').config();
const port = process.env.PORT || 3000;
const dbUrl = process.env.DATABASE_URL;
```

```bash
# .env (gitignored)
PORT=3000
DATABASE_URL=postgres://...
JWT_SECRET=long-random-string
```

## Q57. What is health checking and why do you need it?

**Answer:**

A `/health` endpoint reports whether the app and its dependencies are alive. Load balancers and orchestrators (Kubernetes) use it to route traffic only to healthy instances.

```js
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok' });
  } catch {
    res.status(503).json({ status: 'degraded' });
  }
});
```

## Q58. What is logging best practice in Node.js?

**Answer:**

- Use a structured logger (`pino`, `winston`)
- Log JSON in production for log aggregation
- Include request IDs so you can trace a single request
- Never log secrets

```js
const pino = require('pino')();

app.use((req, res, next) => {
  req.id = crypto.randomUUID();
  pino.info({ reqId: req.id, method: req.method, url: req.url });
  next();
});
```

## Q59. What is clustering vs worker_threads?

**Answer:**

- **Cluster**: multiple Node **processes**, each with its own memory and event loop. Good for scaling I/O work across CPU cores.
- **worker_threads**: multiple **threads** in the same process, sharing memory via `SharedArrayBuffer`. Good for CPU-heavy tasks.

## Q60. How do you reduce cold-start time?

**Answer:**

- Cache `node_modules` in CI
- Tree-shake / bundle for serverless (esbuild)
- Lazy-require heavy modules
- Avoid heavy work at module load time
- Use `node --enable-source-maps` only when needed

```js
// Lazy require
let pdf;
function makePdf(data) {
  pdf = pdf || require('pdfkit');
  return new pdf().text(data);
}
```

---

## 13. Quick Reference

### Common npm packages

| Package           | Purpose                       |
| ----------------- | ----------------------------- |
| express           | Web framework                 |
| helmet            | Secure HTTP headers           |
| cors              | CORS handling                 |
| dotenv            | Load `.env`                   |
| jsonwebtoken      | JWT signing/verifying         |
| bcrypt            | Password hashing              |
| zod / joi         | Input validation              |
| pg / mysql2       | SQL drivers                   |
| prisma / sequelize| ORM                           |
| ioredis           | Redis client                  |
| pino / winston    | Logging                       |
| jest / vitest     | Test runner                   |
| supertest         | HTTP integration tests        |
| pm2               | Process manager               |
| nodemon / ts-node | Dev tooling                   |
