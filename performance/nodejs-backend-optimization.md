# Node.js Backend Performance Optimization — Interview Q&A Guide

This guide covers Node.js runtime fundamentals, the event loop, V8 optimization, memory and CPU profiling, HTTP server tuning, framework comparison, clustering and worker threads, database pooling, caching, async patterns, streams, logging, queues, and microservice latency.

---

## Node.js Runtime

## Q1. What does Node.js actually do?

**Answer:**

Node.js is a V8 JavaScript engine plus libuv (event loop, async I/O, thread pool) plus a standard library of modules. It runs JavaScript on a single thread and offloads I/O to multiple threads inside libuv.

Typical request lifecycle:
1. HTTP server receives bytes (TCP, libuv)
2. Parser builds Request and Response objects
3. Middleware chain executes JS
4. Async I/O (DB, HTTP, file) yields back to libuv
5. Response sent

The single thread runs all your JavaScript. Anything CPU-heavy on this thread blocks every concurrent request.

## Q2. What is a healthy latency budget for a Node API?

**Answer:**

| Endpoint type | p50 | p95 | p99 |
| --- | --- | --- | --- |
| Cached lookup | < 5 ms | < 20 ms | < 50 ms |
| Single DB query | < 20 ms | < 100 ms | < 250 ms |
| Multi-DB or external API | < 100 ms | < 500 ms | < 1 s |
| CPU-light compute | < 10 ms | < 50 ms | < 100 ms |

If p99 is wildly higher than p50, you have a long-tail problem (GC pauses, event loop blocking, slow third party).

## Q3. What are the top Node.js performance killers?

**Answer:**

1. Synchronous code on the event loop (`fs.readFileSync`, large `JSON.parse`)
2. Memory leaks from unbounded caches or listeners
3. Missing `await` (unhandled promise rejection or fire-and-forget)
4. Sequential `await` where parallel would work
5. Connection pool too small or leaking
6. Logging at info or debug in production with synchronous writes
7. CPU-bound regex (ReDoS)
8. Unbounded payload size
9. No timeouts on outgoing HTTP
10. `console.log` in hot paths

---

## Event Loop

## Q4. What are the phases of the event loop?

**Answer:**

```
   timers          <- setTimeout, setInterval callbacks
   pending callbacks <- some I/O callbacks deferred
   idle, prepare   (internal)
   poll            <- incoming data
   check           <- setImmediate callbacks
   close callbacks <- socket.on('close', ...)
```

Microtasks (Promises, `queueMicrotask`) and `process.nextTick` run between every phase, draining their queues each time.

## Q5. Why does event loop blocking matter?

**Answer:**

A long-running synchronous task blocks every phase. If 100 concurrent users hit an endpoint that runs a 200 ms loop, you have added up to 200 ms of latency to every other in-flight request.

Detect using built-in `perf_hooks`:

```js
const { monitorEventLoopDelay } = require('node:perf_hooks');
const h = monitorEventLoopDelay({ resolution: 20 });
h.enable();
setInterval(() => {
    console.log('p99 lag:', h.percentile(99) / 1e6, 'ms');
    h.reset();
}, 5000);
```

A healthy loop has p99 lag below 50 ms.

## Q6. setImmediate vs setTimeout vs nextTick — what is the difference?

**Answer:**

- `process.nextTick` runs before the next phase, before any other I/O. Easy to starve the loop.
- `queueMicrotask` is the standardized version of `nextTick`.
- `setImmediate` runs in the check phase, after I/O callbacks.
- `setTimeout(fn, 0)` runs in the timers phase, with a minimum of 1 ms in practice.

```js
// Break up CPU work without starving I/O
function processChunked(items, i = 0) {
    const start = Date.now();
    while (i < items.length && Date.now() - start < 10) {
        processItem(items[i++]);
    }
    if (i < items.length) {
        setImmediate(() => processChunked(items, i));
    }
}
```

Rule: use `setImmediate` to yield to I/O.

## Q7. What runs on the libuv thread pool?

**Answer:**

libuv has a thread pool (default 4 threads) for:
- File system operations
- DNS lookups (`dns.lookup`, not `dns.resolve`)
- `crypto.pbkdf2`, `crypto.scrypt`, bcrypt
- Some zlib operations

Tune via environment variable:

```bash
UV_THREADPOOL_SIZE=16 node app.js
```

If your app does many concurrent file, crypto, or DNS operations, the default 4 is a bottleneck. The maximum is 1024.

---

## V8 Engine Optimization

## Q8. What are V8 hidden classes and inline caching?

**Answer:**

V8 builds hidden classes based on object shape. Mutating shape (adding properties later) invalidates optimization.

```js
// SLOW: shape changes after construction
function User(name) { this.name = name; }
const u = new User('a');
u.email = 'b';   // hidden class changes

// FAST: all properties initialized in constructor
function User(name, email) {
    this.name = name;
    this.email = email;
}
```

Always initialize all properties in the constructor in the same order.

## Q9. What is the difference between monomorphic and polymorphic call sites?

**Answer:**

A function that is called with a single object shape stays optimized:

```js
function getName(u) { return u.name; }

// Monomorphic — same shape
getName({ name: 'a', email: 'b' });
getName({ name: 'c', email: 'd' });

// Polymorphic — second shape introduced
getName({ name: 'a', age: 1 });

// Megamorphic — V8 gives up on inline caching
getName({ name: 'a', height: 2, etc: 3 });
```

For hot paths, prefer consistent shapes.

## Q10. What are common V8 deoptimization triggers?

**Answer:**

- Mixing types (`x = 1` then `x = 'string'`)
- `delete` on object properties (changes hidden class)
- `arguments` object misuse — use rest parameters instead
- `try/catch` was a deopt killer in old V8; OK in modern V8 but avoid in hot paths
- `Function.prototype.apply` or `call` with non-array arguments

For most apps, do not micro-optimize V8. Profile first.

---

## Memory

## Q11. What is the Node memory model?

**Answer:**

| Region | Description |
| --- | --- |
| New Space (Young Gen) | Short-lived objects, scavenged frequently |
| Old Space (Old Gen) | Long-lived, mark-sweep-compact |
| Large Object Space | Objects over ~1 MB |
| Code Space | Compiled code |
| Map Space | Hidden classes |

`--max-old-space-size=4096` raises the old-space limit (default ~1.7 GB on 64-bit). Beyond ~8 GB, GC pauses get long; consider sharding into multiple processes.

## Q12. What are common memory leak patterns?

**Answer:**

1. Caches without TTL or size limit
2. Event listeners not removed
3. Closures holding large data
4. Timers not cleared
5. Streams not consumed
6. Global state accumulating

```js
// BAD: unbounded cache, classic leak
const cache = {};
function getUser(id) {
    if (!cache[id]) cache[id] = fetchUser(id);
    return cache[id];
}
```

```js
// GOOD: bounded LRU with TTL
const { LRUCache } = require('lru-cache');
const cache = new LRUCache({ max: 10000, ttl: 5 * 60 * 1000 });

function getUser(id) {
    let user = cache.get(id);
    if (!user) {
        user = fetchUser(id);
        cache.set(id, user);
    }
    return user;
}
```

## Q13. How do you debug with heap snapshots?

**Answer:**

```bash
node --inspect server.js
```

Open `chrome://inspect`, take a heap snapshot, do some work, take another, then compare.

Look for large arrays, growing Maps, or closures retaining HTTP requests.

Programmatic capture:

```js
const v8 = require('node:v8');

process.on('SIGUSR2', () => {
    const path = `./snap-${Date.now()}.heapsnapshot`;
    v8.writeHeapSnapshot(path);
    console.log('Wrote', path);
});
```

Trigger via `kill -USR2 <pid>`.

## Q14. What does the clinic.js suite do?

**Answer:**

```bash
npm i -g clinic autocannon

clinic doctor -- node server.js
clinic flame -- node server.js
clinic bubbleprof -- node server.js
clinic heapprofiler -- node server.js
```

- `doctor`: classifies the issue (CPU, memory, event loop, I/O)
- `flame`: flame graph of CPU
- `bubbleprof`: async flow visualization
- `heapprofiler`: allocation profiling

Combine with `autocannon` to drive load.

## Q15. What is `0x` and when do you use it?

**Answer:**

```bash
npm i -g 0x
0x server.js
# Stop with Ctrl+C and a flame graph HTML opens in your browser
```

Lighter than clinic, focused on CPU time.

## Q16. When do you use WeakMap or WeakRef?

**Answer:**

```js
const cache = new WeakMap();

function getMeta(obj) {
    let meta = cache.get(obj);
    if (!meta) {
        meta = expensive(obj);
        cache.set(obj, meta);
    }
    return meta;
}
```

WeakMap entries are garbage-collected when the key has no other references. Useful when the key is an object whose lifetime you control.

`WeakRef` (newer) lets you hold references that do not prevent GC, with explicit `.deref()`.

## Q17. How do you use an LRU cache?

**Answer:**

```js
const { LRUCache } = require('lru-cache');

const cache = new LRUCache({
    max: 1000,
    ttl: 60_000,
    updateAgeOnGet: false,
    allowStale: false,
});

cache.set('user:1', user);
const u = cache.get('user:1');
```

Always set `max` and `ttl`. An unbounded `Map()` is the most common Node memory leak.

For multi-instance services, prefer Redis — in-process LRU per instance can cause cache divergence.

---

## CPU Profiling

## Q18. How do you do CPU profiling with `--cpu-prof`?

**Answer:**

```bash
node --cpu-prof --cpu-prof-dir=./profiles server.js
```

Generates a `.cpuprofile` file you can load in Chrome DevTools (Performance tab, Load profile).

Programmatic:

```js
const inspector = require('node:inspector/promises');
const fs = require('node:fs');

const session = new inspector.Session();
session.connect();

await session.post('Profiler.enable');
await session.post('Profiler.start');

// ... workload ...

const { profile } = await session.post('Profiler.stop');
fs.writeFileSync('profile.cpuprofile', JSON.stringify(profile));
```

## Q19. What are common CPU hot spots in Node apps?

**Answer:**

- `JSON.parse` and `JSON.stringify` on large bodies
- bcrypt, scrypt, argon2 password hashing (move to thread pool, tune cost)
- RegExp with backtracking
- Manual sort, filter, or map chains over huge arrays
- Templating (EJS, Pug)
- ORM overhead (Sequelize, TypeORM)

Profile to find your specific hot spot.

## Q20. How do you use `perf_hooks`?

**Answer:**

```js
const { performance, PerformanceObserver } = require('node:perf_hooks');

performance.mark('A');
doWork();
performance.mark('B');
performance.measure('A->B', 'A', 'B');

new PerformanceObserver((list) => {
    list.getEntries().forEach((e) => {
        console.log(e.name, e.duration, 'ms');
    });
}).observe({ entryTypes: ['measure'] });
```

Lightweight enough for production use on critical paths.

---

## HTTP Server Tuning

## Q21. How do you set up keep-alive and connection reuse?

**Answer:**

For incoming connections:

```js
const http = require('node:http');
const server = http.createServer(handler);

server.keepAliveTimeout = 65_000;   // longer than load balancer's idle timeout
server.headersTimeout = 66_000;
server.listen(3000);
```

For outgoing HTTP:

```js
const http = require('node:http');

const agent = new http.Agent({
    keepAlive: true,
    maxSockets: 50,
    maxFreeSockets: 10,
    keepAliveMsecs: 30_000,
});

await fetch(url, { agent });
```

Reusing TCP and TLS connections eliminates handshakes, saving 50-200 ms per call.

## Q22. What server timeouts do you need to set?

**Answer:**

```js
server.requestTimeout = 30_000;     // total request time limit
server.headersTimeout = 60_000;     // time to receive headers
server.keepAliveTimeout = 65_000;
server.timeout = 0;                  // socket inactivity (use requestTimeout)
```

Without these, a slow-loris client can hold a connection forever.

## Q23. How do you set body size limits?

**Answer:**

Express:

```js
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
```

Fastify:

```js
const fastify = require('fastify')({ bodyLimit: 1_048_576 });
```

Without limits, a single request with a 500 MB body can OOM your process.

## Q24. How do you use HTTP/2 in Node?

**Answer:**

```js
const http2 = require('node:http2');
const fs = require('node:fs');

const server = http2.createSecureServer({
    key: fs.readFileSync('key.pem'),
    cert: fs.readFileSync('cert.pem'),
});

server.on('stream', (stream, headers) => {
    stream.respond({ 'content-type': 'text/html', ':status': 200 });
    stream.end('<h1>Hello HTTP/2</h1>');
});
```

Most production setups terminate TLS and HTTP/2 at the load balancer (ALB, Nginx, Caddy) and proxy HTTP/1.1 to Node. Simpler and equally fast.

## Q25. Where should you do compression?

**Answer:**

```js
// Possible in-process
const compression = require('compression');
app.use(compression({ threshold: 1024 }));
```

Better: terminate compression at the proxy (Nginx, ALB) where it is faster and frees Node CPU. For static responses, precompress at build time and serve with `gzip_static` and `brotli_static`.

---

## Express vs Fastify

## Q26. How do popular frameworks compare in throughput?

**Answer:**

Approximate req/s for a "Hello World" on a single core:

| Framework | req/s |
| --- | --- |
| Bare http | ~70k |
| uWS.js | ~150k |
| Fastify | ~50k |
| Hono | ~60k |
| Koa | ~30k |
| Express | ~15k |
| NestJS (Express) | ~10k |
| NestJS (Fastify) | ~30k |

Numbers vary by version and benchmark setup. Real-world apps rarely max these — you are DB-bound first.

## Q27. Why is Fastify faster than Express?

**Answer:**

- Schema-based serialization compiles JSON schema to a fast serializer (5-10x faster than `JSON.stringify`)
- Lighter middleware chain
- Built-in pino logging vs manual setup
- Plugin system avoids global pollution
- Avoids `req`/`res` mutation overhead

```js
// Fastify schema-based serialization
fastify.get('/user/:id', {
    schema: {
        response: {
            200: {
                type: 'object',
                properties: {
                    id: { type: 'number' },
                    name: { type: 'string' },
                    email: { type: 'string' },
                },
            },
        },
    },
}, async (req) => {
    return await getUser(req.params.id);
});
```

## Q28. When does framework choice actually matter?

**Answer:**

Most apps spend their time in the database, not the framework. A 200 ms endpoint will not get faster by switching frameworks.

Where it matters:
- High-throughput API gateways
- Real-time (WebSocket) servers
- Microservices with tight latency budgets

For typical CRUD apps, prioritize productivity over micro-throughput differences.

## Q29. How do you avoid middleware bloat?

**Answer:**

Each middleware adds overhead. Stack only what you need.

```js
// BAD: blanket auth on every route
app.use(authMiddleware);

// GOOD: scope to authenticated routes only
app.use('/api/private', authMiddleware);
```

Other tips:
- Avoid `morgan` in production; use pino with structured logs
- Do not enable JSON body parsing on routes that do not need it
- Skip CORS middleware on routes not requiring CORS

---

## Cluster, Workers, Child Processes

## Q30. How do you use cluster mode?

**Answer:**

```js
const cluster = require('node:cluster');
const os = require('node:os');
const http = require('node:http');

if (cluster.isPrimary) {
    for (let i = 0; i < os.cpus().length; i++) {
        cluster.fork();
    }
    cluster.on('exit', () => cluster.fork());
} else {
    http.createServer(handler).listen(3000);
}
```

Forks N workers, each on a separate core, sharing the listening port. Linear scaling for CPU.

In production, prefer PM2 or systemd template units instead of writing your own clustering code.

## Q31. How do you use worker threads for CPU-bound work?

**Answer:**

```js
// main.js
const Piscina = require('piscina');
const path = require('node:path');

const pool = new Piscina({
    filename: path.resolve(__dirname, 'worker.js'),
    minThreads: 2,
    maxThreads: 8,
});

const result = await pool.run({ data: bigArray });
```

```js
// worker.js
module.exports = ({ data }) => {
    return expensiveSyncWork(data);
};
```

Use a worker pool — spinning up a thread per request is slow.

Use cases: image processing, PDF generation, large JSON parsing, crypto, ML inference.

## Q32. Cluster vs worker_threads — when to use which?

**Answer:**

| Use case | Pick |
| --- | --- |
| Scale a stateless HTTP server across cores | Cluster |
| Run CPU-bound function without blocking event loop | Worker threads |
| Run a separate program | child_process |
| Share memory across threads | Worker threads with SharedArrayBuffer |

Cluster workers do not share memory; worker threads can.

## Q33. How do you use child processes?

**Answer:**

```js
const { spawn } = require('node:child_process');

const child = spawn('ffmpeg', ['-i', 'input.mp4', 'output.mp4']);

child.stdout.on('data', (chunk) => console.log(chunk.toString()));
child.on('exit', (code) => console.log('exit', code));
```

Use for shelling out to heavy tools (ffmpeg, imagemagick, pandoc). Never `exec` with user input — command injection risk.

## Q34. PM2 vs raw cluster?

**Answer:**

PM2:

```bash
pm2 start app.js -i max --name api
pm2 startup
pm2 save
```

PM2 gives you cluster mode in one command, auto-restart on crash, log management, deployment hooks, web UI, and metrics.

Production-ready alternatives: systemd template units, container orchestrators (Kubernetes scales horizontally instead of clustering on one box).

---

## Database and Pooling

## Q35. How do you size connection pools for Node?

**Answer:**

A common mistake: 100 connections per pool, then 4 instances = 400 connections to Postgres = exhaustion.

```
total_db_connections = pool_size * instance_count + headroom
total <= db_max_connections * 0.8
```

Practical: pool of 10 per instance, 4 instances = 40 connections. Plenty for most apps.

## Q36. How do you configure pg, mysql2, and mongoose pools?

**Answer:**

```js
// pg
const { Pool } = require('pg');
const pool = new Pool({
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 2_000,
    statement_timeout: 5_000,
    query_timeout: 5_000,
});

// mysql2
const mysql = require('mysql2/promise');
const pool = mysql.createPool({
    connectionLimit: 10,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0,
});

// mongoose
const mongoose = require('mongoose');
mongoose.connect(uri, {
    maxPoolSize: 10,
    serverSelectionTimeoutMS: 5000,
});
```

Always set query timeouts. A hung query holds a connection until the DB times out (often minutes), starving the pool.

## Q37. How much overhead does an ORM add?

**Answer:**

Prisma, Sequelize, TypeORM, and Mongoose all add overhead compared to raw drivers. Often 2-5x for a simple query.

Mitigations:

```js
// BAD: ORM hydration of a wide entity
const user = await prisma.user.findUnique({
    where: { id },
    include: { orders: true, profile: true },
});

// GOOD: select specific columns
const user = await prisma.user.findUnique({
    where: { id },
    select: { id: true, name: true, email: true },
});

// HOT PATH: raw query
const result = await prisma.$queryRaw`
    SELECT id, name FROM users WHERE id = ${id}
`;
```

## Q38. What is statement caching?

**Answer:**

```js
// pg: named queries are cached as prepared statements per connection
const result = await client.query({
    name: 'get-user',
    text: 'SELECT * FROM users WHERE id = $1',
    values: [id],
});
```

The pg driver caches prepared statements per connection. This saves planning time on repeated queries. Drivers vary, so verify your DB and library.

---

## Caching

## Q39. When should you use in-process LRU?

**Answer:**

```js
const { LRUCache } = require('lru-cache');
const cache = new LRUCache({ max: 1000, ttl: 60_000 });
```

Pros: fastest (sub-microsecond), no network.
Cons: per-instance, divergence between instances, cannot be invalidated globally.

Best for: small reference data, hot read paths, frequently used config.

## Q40. What is the Redis caching pattern?

**Answer:**

```js
const Redis = require('ioredis');
const redis = new Redis();

async function getUser(id) {
    const key = `user:${id}`;
    const cached = await redis.get(key);
    if (cached) return JSON.parse(cached);

    const user = await db.users.findOne({ id });
    await redis.set(key, JSON.stringify(user), 'EX', 300);
    return user;
}
```

Use `ioredis` for clustering and pipelining. Use `setex` or `set ... EX` so unbounded keys do not accumulate.

## Q41. How do you protect against cache stampedes?

**Answer:**

```js
async function getOrSet(key, ttl, loader) {
    const cached = await redis.get(key);
    if (cached) return JSON.parse(cached);

    const lockKey = `lock:${key}`;
    const got = await redis.set(lockKey, '1', 'NX', 'EX', 5);
    if (got) {
        try {
            const fresh = await loader();
            await redis.set(key, JSON.stringify(fresh), 'EX', ttl);
            return fresh;
        } finally {
            await redis.del(lockKey);
        }
    } else {
        await new Promise((r) => setTimeout(r, 50));
        return getOrSet(key, ttl, loader);
    }
}
```

Or use a battle-tested library like `cache-manager`.

## Q42. How do you set ETag and Cache-Control on API responses?

**Answer:**

```js
const etag = require('etag');

app.get('/api/products', async (req, res) => {
    const body = await getProducts();
    const tag = etag(JSON.stringify(body));

    res.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=300');
    res.setHeader('ETag', tag);

    if (req.headers['if-none-match'] === tag) {
        return res.status(304).end();
    }
    res.json(body);
});
```

For public APIs, an ETag plus a CDN can offload 90 percent or more of read traffic.

---

## Async Patterns

## Q43. Sequential vs parallel awaits — what is the difference?

**Answer:**

```js
// SLOW: 3 sequential round trips
const a = await fetchA();
const b = await fetchB();
const c = await fetchC();   // total = sum of latencies

// FAST: parallel
const [a, b, c] = await Promise.all([fetchA(), fetchB(), fetchC()]);
// total = max latency
```

`Promise.all` rejects on first error. For partial failure tolerance:

```js
const results = await Promise.allSettled([fetchA(), fetchB(), fetchC()]);
for (const r of results) {
    if (r.status === 'fulfilled') console.log(r.value);
    else console.error(r.reason);
}
```

## Q44. How do you limit parallelism?

**Answer:**

A naive `Promise.all` over 10,000 items can spawn 10,000 concurrent DB queries — instant pool exhaustion.

```js
const pLimit = require('p-limit');
const limit = pLimit(20);

await Promise.all(items.map((i) => limit(() => process(i))));
```

Or batch:

```js
for (let i = 0; i < items.length; i += 50) {
    const batch = items.slice(i, i + 50);
    await Promise.all(batch.map(process));
}
```

## Q45. How do you use AbortController for cancellation?

**Answer:**

```js
const ctrl = new AbortController();
const timeout = setTimeout(() => ctrl.abort(), 5000);

try {
    const res = await fetch(url, { signal: ctrl.signal });
    return await res.json();
} finally {
    clearTimeout(timeout);
}
```

Always set timeouts on outgoing HTTP. A hung third party can pile up requests until you OOM.

## Q46. How does request batching with DataLoader work?

**Answer:**

```js
const DataLoader = require('dataloader');

const userLoader = new DataLoader(async (ids) => {
    const users = await db.users.find({ id: { $in: ids } });
    return ids.map((id) => users.find((u) => u.id === id) || null);
});

// In handlers
await userLoader.load(1);
await userLoader.load(2);
await userLoader.load(3);
// All three ids batched into one DB query within the same tick
```

DataLoader collapses N+1 by batching loads within a single event loop tick. Common in GraphQL.

## Q47. When do you debounce or throttle?

**Answer:**

For events that fire fast (resize, scroll, keyboard, sensor data) — handle less often.

```js
const { debounce, throttle } = require('lodash-es');

const onChange = debounce((value) => persist(value), 300);
const onScroll = throttle(handle, 100);
```

For server-side rate limiting use `bottleneck` or token-bucket libraries.

---

## Streams and Large Data

## Q48. Why do streams matter?

**Answer:**

Loading a 1 GB CSV into memory:

```js
// BAD: OOMs on large files
const data = require('node:fs').readFileSync('huge.csv');
```

Streaming uses constant memory:

```js
const { pipeline } = require('node:stream/promises');
const fs = require('node:fs');
const { parse } = require('csv-parse');

await pipeline(
    fs.createReadStream('huge.csv'),
    parse({ columns: true }),
    async function* (source) {
        for await (const row of source) {
            yield JSON.stringify(row) + '\n';
        }
    },
    fs.createWriteStream('out.ndjson'),
);
```

## Q49. What is backpressure?

**Answer:**

When the consumer is slower than the producer, streams pause the producer. Native streams handle this via `.write()` returning `false` and a `'drain'` event.

```js
// WRONG: ignores return value, fires as fast as possible
res.write(line);

// RIGHT: respect backpressure
const { once } = require('node:events');

if (!res.write(line)) {
    await once(res, 'drain');
}
```

Or use `pipeline` which handles backpressure for you.

## Q50. How do you stream HTTP responses?

**Answer:**

```js
res.setHeader('Content-Type', 'application/x-ndjson');
res.setHeader('Transfer-Encoding', 'chunked');

for await (const row of db.queryStream('SELECT * FROM big_table')) {
    res.write(JSON.stringify(row) + '\n');
}
res.end();
```

Send large datasets without buffering. NDJSON or Server-Sent Events for streaming JSON.

---

## Logging

## Q51. How do popular Node loggers compare?

**Answer:**

| Library | Speed | Notes |
| --- | --- | --- |
| pino | Fastest (~5x winston) | Async, structured JSON |
| winston | Slower | Pluggable transports |
| bunyan | Older | JSON, similar to pino |
| console | Synchronous | Do not use in production |

`console.log` is synchronous — every call blocks the event loop.

```js
const pino = require('pino');
const logger = pino();

logger.info({ user_id: 123 }, 'login successful');
logger.error({ err }, 'failed to send email');
```

## Q52. How does async logging with pino work?

**Answer:**

```js
const pino = require('pino');

const transport = pino.transport({
    target: 'pino/file',
    options: { destination: '/var/log/app.log' },
});
const logger = pino(transport);
```

Logs are buffered and flushed asynchronously by a worker thread. About 10x throughput vs synchronous.

## Q53. How do you manage log volume?

**Answer:**

```js
// Sample noisy logs
if (Math.random() < 0.01) {
    logger.info({ ...event }, 'sampled event');
}

// Use levels: info for normal, debug not in prod
logger.level = process.env.LOG_LEVEL || 'info';

// Structure logs for searchability
logger.info({ user_id, action }, 'action_taken');   // not "user 5 did X"
```

Rotate logs with `logrotate` or use pino's transport with rotation. A logging-heavy app can spend 30 percent CPU on logging if misused.

---

## Background Jobs

## Q54. How do you use BullMQ for Redis-backed jobs?

**Answer:**

```js
const { Queue, Worker } = require('bullmq');

const connection = { host: 'redis', port: 6379 };

const queue = new Queue('emails', { connection });

await queue.add('send', { to: 'a@b.c' }, {
    attempts: 3,
    backoff: { type: 'exponential', delay: 1000 },
});

new Worker('emails', async (job) => {
    await sendEmail(job.data);
}, {
    connection,
    concurrency: 10,
});
```

Features: retries, delayed jobs, repeatable jobs, rate limiting, priorities, flow (DAG), parent-child.

## Q55. What are queue performance considerations?

**Answer:**

- Concurrency per worker: balance throughput and downstream load
- Multiple workers across machines for horizontal scale
- Lock duration longer than max job time to avoid duplicate processing
- Stalled job detection — workers heartbeat every N seconds
- Job size: store payload references (S3 URL), not huge JSON in Redis

## Q56. SQS vs RabbitMQ vs Kafka — when to switch?

**Answer:**

- **BullMQ (Redis)**: simple, fast, under 10k jobs/s per Redis instance
- **SQS (AWS)**: managed, virtually unlimited, ~10s p99 latency
- **RabbitMQ**: rich routing (topic, fanout), strong delivery guarantees
- **Kafka**: event streams, replay, retention, very high throughput

Most apps start with BullMQ and move to Kafka only when log or event volume justifies it.

---

## Microservice Latency

## Q57. What is a typical internal call latency budget?

**Answer:**

If a user request fans out to 5 services synchronously, each adding 50 ms, you are at 250+ ms before the user sees anything.

Tactics:
- Parallel fan-out with timeouts and circuit breakers
- Request hedging (issue duplicate requests, use first response)
- Caching at the gateway layer
- gRPC instead of HTTP+JSON — 5-10x faster for cross-service calls
- Connection reuse (keep-alive, gRPC channels)
- Co-locate services in the same AZ (cross-AZ adds 1-2 ms)

## Q58. What is gRPC and when do you use it?

**Answer:**

```proto
// user.proto
service UserService {
    rpc GetUser (GetUserRequest) returns (User);
}

message GetUserRequest { int64 id = 1; }
message User { int64 id = 1; string name = 2; }
```

```js
// Node client
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

const def = protoLoader.loadSync('user.proto');
const proto = grpc.loadPackageDefinition(def);
const client = new proto.UserService('user-svc:50051', grpc.credentials.createInsecure());

client.getUser({ id: 42 }, (err, user) => console.log(user));
```

Pros: binary protobuf is smaller and faster than JSON, HTTP/2 multiplexing, streaming, strict schemas with generated clients.

Cons: harder to debug (no curl), browser support requires gRPC-Web proxy.

## Q59. How does a circuit breaker work?

**Answer:**

```js
const CircuitBreaker = require('opossum');

const breaker = new CircuitBreaker(callExternalApi, {
    timeout: 3000,
    errorThresholdPercentage: 50,
    resetTimeout: 30_000,
});

breaker.fallback(() => ({ items: [] }));

const result = await breaker.fire(args);
```

When the error rate exceeds the threshold, the breaker opens and fails fast. After the reset timeout, it goes half-open and tests one request before closing again. Prevents cascade failure when a downstream is down.

## Q60. How do you do retries with backoff?

**Answer:**

```js
async function withRetry(fn, attempts = 3) {
    for (let i = 0; i < attempts; i++) {
        try {
            return await fn();
        } catch (e) {
            if (i === attempts - 1) throw e;
            const backoff = 2 ** i * 100 + Math.random() * 100;
            await new Promise((r) => setTimeout(r, backoff));
        }
    }
}
```

Always include jitter to avoid thundering herd. Be careful retrying non-idempotent operations like POST without idempotency keys.

Libraries: `cockatiel`, `p-retry`, `async-retry`.

## Q61. What are alternatives to JSON for inter-service traffic?

**Answer:**

| Format | Size vs JSON | Speed | Notes |
| --- | --- | --- | --- |
| MessagePack | ~30% smaller | 2x faster | `@msgpack/msgpack` |
| Protobuf | Smallest | Fastest | Schema-based |
| CBOR | Similar to msgpack | Similar | Standard |
| Avro | Schema-based | Fast | Schema evolution |

For client-facing APIs, JSON is usually fine — overhead is rarely the bottleneck.

## Q62. Why avoid synchronous `JSON.stringify` on huge payloads?

**Answer:**

For 50+ MB JSON, `JSON.stringify` blocks the event loop for hundreds of ms.

```js
// BAD: blocks the loop
res.json(hugeArray);

// GOOD: stream NDJSON
res.setHeader('Content-Type', 'application/x-ndjson');
const { once } = require('node:events');
for (const row of hugeArray) {
    if (!res.write(JSON.stringify(row) + '\n')) {
        await once(res, 'drain');
    }
}
res.end();
```

Or use Fastify's schema-based serializer (5-10x faster).

---

## Production Case Studies

## Q63. Memory leak from unbounded cache.

**Answer:**

A service hit OOM after 24 hours. Heap snapshot showed a `Map` growing forever.

Bad code:

```js
const userCache = new Map();
function getUser(id) {
    if (!userCache.has(id)) userCache.set(id, fetchUser(id));
    return userCache.get(id);
}
```

Fix:

```js
const { LRUCache } = require('lru-cache');
const userCache = new LRUCache({
    max: 10_000,
    ttl: 5 * 60 * 1000,
});

function getUser(id) {
    let user = userCache.get(id);
    if (!user) {
        user = fetchUser(id);
        userCache.set(id, user);
    }
    return user;
}
```

Memory plateaued at 800 MB.

## Q64. Event loop blocking from sync crypto.

**Answer:**

Latency p99 spiked from 50 ms to 2 s under load. Profile showed `bcrypt.hashSync` on the request path.

```js
// BAD: blocks the loop
const hash = bcrypt.hashSync(password, 12);

// GOOD: uses libuv thread pool
const hash = await bcrypt.hash(password, 10);
```

Fixes:
1. Replace `bcrypt.hashSync` with the async version
2. Set `UV_THREADPOOL_SIZE=16` to allow more concurrent hashes
3. Lower bcrypt cost from 12 to 10 (still secure, much faster)
4. Optionally move hashing to a worker pool for isolation

## Q65. Pool exhaustion from unbounded parallelism.

**Answer:**

A job processed 100k records, each with a DB call. It used `Promise.all`. Pool of 10 connections maxed out, queries timed out, downstream services flooded.

Bad:

```js
await Promise.all(records.map((r) => process(r)));   // 100k parallel
```

Fix:

```js
const pLimit = require('p-limit');
const limit = pLimit(20);
await Promise.all(records.map((r) => limit(() => process(r))));
```

A constant 20 concurrent DB queries, no exhaustion, no flood.

## Q66. Slow JSON serialization.

**Answer:**

An endpoint returning 100k records took 4 seconds. Profile showed `JSON.stringify` taking 3.2 seconds.

Solutions tried in order:

```js
// 1. fast-json-stringify with schema -> 800 ms
const fastJson = require('fast-json-stringify');
const stringify = fastJson({
    type: 'array',
    items: {
        type: 'object',
        properties: {
            id: { type: 'integer' },
            name: { type: 'string' },
        },
    },
});

res.send(stringify(rows));
```

```js
// 2. Switch to NDJSON streaming -> 50 ms TTFB, 1.2s full transfer
res.setHeader('Content-Type', 'application/x-ndjson');
for await (const row of dbStream) {
    res.write(JSON.stringify(row) + '\n');
}
res.end();
```

3. Eventually added pagination — the real fix.

## Q67. The retry storm.

**Answer:**

A downstream API got slow. The service retried 3 times, tripling the load on the downstream, making it slower, causing more retries. Cascading failure.

Fixes:

```js
const breaker = new CircuitBreaker(downstreamCall, {
    timeout: 3000,
    errorThresholdPercentage: 50,
    resetTimeout: 30_000,
});

// Retry budget: cap at 10% of original requests
const RETRY_BUDGET = 0.1;
let retriesThisSecond = 0;
let requestsThisSecond = 0;
setInterval(() => { retriesThisSecond = 0; requestsThisSecond = 0; }, 1000);

async function callWithBudget(args) {
    requestsThisSecond++;
    try {
        return await breaker.fire(args);
    } catch (e) {
        if (retriesThisSecond / requestsThisSecond < RETRY_BUDGET) {
            retriesThisSecond++;
            await new Promise((r) => setTimeout(r, 100 + Math.random() * 200));
            return await breaker.fire(args);
        }
        throw e;
    }
}
```

## Q68. The keep-alive surprise.

**Answer:**

The ALB had idle timeout 60 s. Node's `keepAliveTimeout` was the default 5 s. Result: ALB sent requests to a closing socket, returning 502s.

Fix:

```js
server.keepAliveTimeout = 65_000;   // > ALB idle timeout
server.headersTimeout = 66_000;     // must be > keepAliveTimeout
```

## Q69. Large heap, slow GC.

**Answer:**

A service grew to 6 GB old space. Each GC pause was 800 ms. p99 latency was terrible.

Fixes:
1. Find the largest retained objects (heap snapshot)
2. Move large in-memory caches to Redis
3. Lower `--max-old-space-size` to force earlier GC and accept process restarts at 4 GB
4. Use multiple smaller processes (4 x 2 GB) instead of one big one

Smaller heaps mean faster GC pauses.

## Q70. What is a Node production readiness checklist?

**Answer:**

- [ ] Server timeouts configured (request, headers, keep-alive)
- [ ] Body size limits set
- [ ] Outgoing HTTP has timeouts
- [ ] Connection pool sized correctly
- [ ] Graceful shutdown (SIGTERM, drain, close DB, exit)
- [ ] Health and readiness endpoints
- [ ] Cluster mode or container replicas
- [ ] PM2 or systemd or orchestrator manages restarts
- [ ] Async logging with pino
- [ ] Structured logs with correlation IDs
- [ ] Metrics exported (Prometheus, OpenTelemetry)
- [ ] Tracing for distributed flows
- [ ] Memory ceiling with `--max-old-space-size` matching container limit
- [ ] No synchronous file or crypto on the request path
- [ ] bcrypt or crypto cost tuned
- [ ] Caches bounded (LRU + TTL)
- [ ] Circuit breaker on flaky downstreams
- [ ] Rate limiting (express-rate-limit, fastify-rate-limit, or Redis-backed)
- [ ] Stress-tested with autocannon or wrk before production

## Q71. How would you make a Node service handle 10x traffic?

**Answer:**

1. **Measure** — autocannon load test, RUM, find the actual bottleneck
2. **Quick wins** — pool size, keep-alive, missing indexes (downstream), payload limits
3. **Caching** — in-process LRU for hot keys, Redis for shared
4. **Reduce work** — pagination, projection, schema-based serialization
5. **Async** — queue non-critical work
6. **Horizontal scale** — cluster on box, then more boxes
7. **Pre-fetch and batch** — DataLoader for fan-out reads
8. **Move CPU work** — worker threads, dedicated services, language change for hot paths
9. **Architecture** — read replicas, CDN, edge functions
10. **Iterate** — measure again, find the new bottleneck, repeat

Never optimize without a measurement.
