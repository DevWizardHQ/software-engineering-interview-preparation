# Node.js Backend Optimization — Senior Engineer Guide

**Purpose:** Master Node.js backend performance for senior interviews. Covers V8, the event loop, memory and CPU profiling, HTTP server tuning, async patterns, caching, streams, microservice latency, and real production case studies.

---

## Table of Contents

1. [Node.js Runtime Fundamentals](#nodejs-runtime-fundamentals)
2. [Event Loop Deep Dive](#event-loop-deep-dive)
3. [V8 Engine Optimization](#v8-engine-optimization)
4. [Memory Management and Profiling](#memory-management-and-profiling)
5. [CPU Profiling](#cpu-profiling)
6. [HTTP Server Tuning](#http-server-tuning)
7. [Express vs Fastify vs Others](#express-vs-fastify-vs-others)
8. [Cluster, Worker Threads, Child Processes](#cluster-worker-threads-child-processes)
9. [Database and Connection Pooling](#database-and-connection-pooling)
10. [Caching](#caching)
11. [Async Patterns](#async-patterns)
12. [Streams and Large Data](#streams-and-large-data)
13. [Logging Performance](#logging-performance)
14. [Background Jobs and Queues](#background-jobs-and-queues)
15. [Microservice Latency](#microservice-latency)
16. [Real Production Case Studies](#real-production-case-studies)

---

## Node.js Runtime Fundamentals

### Q1. What does Node.js actually do?

A V8 JavaScript engine + libuv (event loop, async I/O, thread pool) + a standard library of modules. Single-threaded JavaScript, multi-threaded I/O.

A typical request lifecycle:
1. HTTP server receives bytes (TCP, libuv)
2. Parser builds Request/Response (Node core or fastify)
3. Middleware chain executes JS
4. Async I/O (DB, HTTP, file) yields back to libuv
5. Response sent

The single thread runs all your JavaScript. Anything CPU-heavy on this thread blocks every concurrent request.

---

### Q2. What's a healthy latency budget for a Node API?

| Endpoint type | p50 | p95 | p99 |
|---------------|-----|-----|-----|
| Cached lookup | < 5 ms | < 20 ms | < 50 ms |
| Single DB query | < 20 ms | < 100 ms | < 250 ms |
| Multi-DB / external API | < 100 ms | < 500 ms | < 1 s |
| CPU-light compute | < 10 ms | < 50 ms | < 100 ms |
| File / large payload | depends | depends | depends |

If p99 is wildly higher than p50, you have a long-tail problem (GC, event loop blocking, slow third party).

---

### Q3. Top 10 Node.js performance killers.

1. Synchronous code on the event loop (`fs.readFileSync`, large `JSON.parse`)
2. Memory leaks from unbounded caches / listeners
3. Missing `await` (unhandled promise rejection or fire-and-forget)
4. Sequential `await` where parallel would work
5. Connection pool too small or leaking
6. Logging at info/debug in production with synchronous writes
7. CPU-bound regex (ReDoS)
8. Unbounded payload size
9. No timeouts on outgoing HTTP
10. `console.log` in hot paths

---

## Event Loop Deep Dive

### Q4. Phases of the event loop.

```
   ┌───────────────────────────┐
┌─>│           timers          │ <- setTimeout, setInterval callbacks
│  ├───────────────────────────┤
│  │     pending callbacks     │ <- some I/O callbacks deferred
│  ├───────────────────────────┤
│  │       idle, prepare       │ (internal)
│  ├───────────────────────────┤      ┌───────────────┐
│  │           poll            │ <─── │   incoming    │
│  ├───────────────────────────┤      │   data, etc.  │
│  │           check           │ <─── setImmediate callbacks
│  ├───────────────────────────┤
│  │      close callbacks      │ <─── socket.on('close', ...)
└──┴───────────────────────────┘
```

Microtasks (Promises, queueMicrotask) and `process.nextTick` run between every phase, draining their queues each time.

---

### Q5. Why does this matter in practice?

A long-running synchronous task blocks every phase. If you have 100 concurrent users and a single endpoint runs a 200ms loop, you've added up to 200ms latency to every other in-flight request.

Detection:
```js
const lag = require('event-loop-lag')(1000);
setInterval(() => {
  if (lag() > 50) console.warn('Event loop lag', lag(), 'ms');
}, 1000);
```

Or `perf_hooks.monitorEventLoopDelay()` (built in):
```js
const { monitorEventLoopDelay } = require('perf_hooks');
const h = monitorEventLoopDelay({ resolution: 20 });
h.enable();
setInterval(() => console.log('p99 lag:', h.percentile(99) / 1e6, 'ms'), 5000);
```

---

### Q6. setImmediate vs setTimeout vs nextTick.

- `process.nextTick` — runs before next phase, before any other I/O. Easy to starve the loop.
- `queueMicrotask` — like nextTick but standard.
- `setImmediate` — runs in the check phase, after I/O callbacks.
- `setTimeout(fn, 0)` — runs in timers phase, minimum 1ms in practice.

Rule: if you need to break up CPU work across ticks, use `setImmediate`. It yields more cleanly than `nextTick` (which can starve I/O).

---

### Q7. libuv thread pool — what runs there?

libuv has a thread pool (default 4 threads) for:
- File system operations (mostly)
- DNS lookups (`dns.lookup`, not `dns.resolve`)
- `crypto.pbkdf2`, `crypto.scrypt`, bcrypt
- Some zlib operations

Tune via:
```bash
UV_THREADPOOL_SIZE=16 node app.js
```

If your app does many concurrent file/crypto/DNS, the default 4 is a bottleneck. Each Node process can use up to 1024.

---

## V8 Engine Optimization

### Q8. V8 hidden classes and inline caching.

V8 builds hidden classes based on object shape. Mutating shape (adding properties later) invalidates optimization.

```js
// Slow
function User(name) { this.name = name; }
const u = new User('a'); u.email = 'b'; // shape change

// Fast
function User(name, email) { this.name = name; this.email = email; }
```

Always initialize all properties in the constructor in the same order.

---

### Q9. Monomorphic vs polymorphic.

A function that's called with a single object shape stays optimized:
```js
function getName(u) { return u.name; }
getName({ name: 'a', email: 'b' });        // monomorphic
getName({ name: 'a', age: 1 });            // polymorphic
getName({ name: 'a', height: 2, etc: 3 }); // megamorphic - deopt
```

For hot paths, prefer consistent shapes.

---

### Q10. Common V8 deoptimization triggers.

- Mixing types (`x = 1` then `x = 'string'`)
- `delete` on object properties (changes hidden class)
- `arguments` object misuse — use rest params instead
- `try/catch` was a deopt killer in old V8; OK in modern V8 but minimize hot-path try/catch
- Using `Function.prototype.apply/call` with non-Array

For most apps, don't micro-optimize V8. Profile first.

---

## Memory Management and Profiling

### Q11. Node memory model.

| Region | Description |
|--------|-------------|
| New Space (Young Gen) | Short-lived objects, scavenged frequently |
| Old Space (Old Gen) | Long-lived, mark-sweep-compact |
| Large Object Space | Objects > ~1 MB |
| Code Space | Compiled code |
| Map Space | Hidden classes |

`--max-old-space-size=4096` raises old-space limit (default ~1.7 GB on 64-bit). Beyond ~8 GB, Node GC pauses get long; consider sharding.

---

### Q12. Common memory leak patterns.

1. **Caches without TTL or size limit** (`const cache = {}`)
2. **Event listeners not removed** (`emitter.on(...)` in a handler)
3. **Closures holding large data** (`req` captured in a long-lived callback)
4. **Timers not cleared** (`setInterval` in a per-request closure)
5. **Streams not consumed** (HTTP response not piped or destroyed)
6. **Global state** accumulating (`logEntries.push(...)`)
7. **DB connection / query handles leaking**

---

### Q13. Heap snapshot debugging.

```bash
node --inspect server.js
```

Open `chrome://inspect`, take heap snapshot, do some work, take another, compare.

Look for:
- Detached DOM (irrelevant in Node)
- Large arrays / Maps growing
- Closures retaining HTTP requests

Or programmatically:
```js
const v8 = require('v8');
v8.writeHeapSnapshot('./snap-' + Date.now() + '.heapsnapshot');
```

Trigger via `kill -USR2 <pid>` (set up a signal handler).

---

### Q14. clinic.js suite.

```bash
npm i -g clinic
clinic doctor -- node server.js
clinic flame -- node server.js
clinic bubbleprof -- node server.js
clinic heapprofiler -- node server.js
```

- **doctor:** classifies issue (CPU, memory, event loop, I/O)
- **flame:** flame graph of CPU
- **bubbleprof:** async flow visualization
- **heapprofiler:** allocation profiling

Combined with load tester (`autocannon`).

---

### Q15. 0x — flame graphs.

```bash
npm i -g 0x
0x server.js
# stop and a flame graph HTML opens in your browser
```

Lighter than clinic, focused on CPU time.

---

### Q16. WeakMap / WeakRef for caches.

```js
const cache = new WeakMap();
function getMeta(obj) {
  if (!cache.has(obj)) cache.set(obj, expensive(obj));
  return cache.get(obj);
}
```

WeakMap entries are GC'd when the key has no other references. Only useful when the key is an object you control the lifetime of.

`WeakRef` (newer) lets you hold references that don't prevent GC, with explicit `.deref()`.

---

### Q17. LRU cache.

```js
const LRU = require('lru-cache');
const cache = new LRU({ max: 1000, ttl: 60_000 });
cache.set('k', value);
const v = cache.get('k');
```

Always set `max` and `ttl`. An unbounded `Map()` is the most common Node memory leak.

For multi-instance services, prefer Redis — in-process LRU per instance can cause cache divergence and inefficiency.

---

## CPU Profiling

### Q18. CPU profiling with `--cpu-prof`.

```bash
node --cpu-prof --cpu-prof-dir=./profiles server.js
```

Generates a `.cpuprofile` file you can load in Chrome DevTools (Performance → Load profile).

Or programmatic:
```js
const inspector = require('node:inspector/promises');
const session = new inspector.Session();
await session.connect();
await session.post('Profiler.enable');
await session.post('Profiler.start');
// ... workload ...
const { profile } = await session.post('Profiler.stop');
fs.writeFileSync('profile.cpuprofile', JSON.stringify(profile));
```

---

### Q19. Common CPU hot spots in Node apps.

- JSON.parse / JSON.stringify of large bodies
- bcrypt / scrypt / argon2 password hashing (move to thread pool, tune cost)
- RegExp with backtracking
- Sync hashing (`crypto.createHash` is sync but fast)
- Manual sort/filter/map chains over huge arrays
- Templating (EJS, Pug compile)
- ORM overhead (Sequelize, TypeORM)

Profile to find your specific hot spot.

---

### Q20. perf_hooks.

Built-in:
```js
const { performance, PerformanceObserver } = require('node:perf_hooks');

performance.mark('A');
doWork();
performance.mark('B');
performance.measure('A→B', 'A', 'B');

new PerformanceObserver(list => {
  list.getEntries().forEach(e => console.log(e.name, e.duration));
}).observe({ entryTypes: ['measure'] });
```

Lightweight enough for production use on critical paths.

---

## HTTP Server Tuning

### Q21. Keep-alive and connection reuse.

```js
const server = http.createServer(handler);
server.keepAliveTimeout = 65_000;     // longer than load balancer's idle timeout
server.headersTimeout = 66_000;
```

For outgoing HTTP:
```js
const http = require('http');
const agent = new http.Agent({ keepAlive: true, maxSockets: 50, maxFreeSockets: 10, keepAliveMsecs: 30_000 });
fetch(url, { agent });
```

Reusing TCP+TLS connections eliminates handshakes, saving 50–200 ms per call.

---

### Q22. Server timeouts you must set.

```js
server.requestTimeout = 30_000;     // total request time limit
server.headersTimeout = 60_000;     // time to receive headers
server.keepAliveTimeout = 65_000;
server.timeout = 0;                 // socket inactivity (use requestTimeout instead)
```

Without these, a slow-loris client can hold a connection forever.

---

### Q23. Body size limits.

Express:
```js
app.use(express.json({ limit: '1mb' }));
```

Fastify:
```js
fastify({ bodyLimit: 1048576 });
```

Without limits, a single request with a 500 MB body can OOM your process.

---

### Q24. HTTP/2 in Node.

```js
const http2 = require('node:http2');
const fs = require('node:fs');
const server = http2.createSecureServer({
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem'),
});
```

Most production setups terminate TLS / HTTP/2 at the load balancer (ALB, nginx, Caddy) and proxy HTTP/1.1 to Node — simpler and equally fast.

---

### Q25. Compression in Node.

```js
const compression = require('compression');
app.use(compression({ threshold: 1024 }));
```

Better: terminate compression at the proxy (nginx, ALB) where it's faster and frees Node CPU.

For static responses, precompress at build time.

---

## Express vs Fastify vs Others

### Q26. Performance comparison.

Approximate req/s for a "Hello World" on a single core:

| Framework | req/s |
|-----------|-------|
| Bare http | ~70k |
| uWS.js | ~150k |
| Fastify | ~50k |
| Hono | ~60k |
| Koa | ~30k |
| Express | ~15k |
| NestJS (Express) | ~10k |
| NestJS (Fastify) | ~30k |

Numbers vary by version and benchmark setup. Real-world apps rarely max these — you're DB-bound first.

---

### Q27. Why is Fastify faster than Express?

- Schema-based serialization (compile JSON schema → fast serializer, ~5–10x faster than `JSON.stringify`)
- Lighter middleware chain
- Built-in logging (pino) vs manual setup
- Plugin system avoids global pollution
- Avoids `req`/`res` mutation overhead

---

### Q28. When does framework choice actually matter?

Most apps spend their time in the database, not the framework. A 200 ms endpoint won't get faster by switching frameworks.

Where it matters:
- High-throughput API gateways
- Real-time (WebSocket) servers
- Microservices with tight latency budgets

For typical CRUD apps, prioritize productivity over micro-throughput differences.

---

### Q29. Avoiding middleware bloat.

Each middleware adds overhead. Stack only what you need:
- Don't apply auth middleware globally if half your routes are public
- Avoid `morgan` in production (use pino + structured logs)
- Don't `body-parser` JSON for routes that don't need it
- Skip CORS middleware on routes not requiring CORS

---

## Cluster, Worker Threads, Child Processes

### Q30. Cluster mode.

```js
if (cluster.isPrimary) {
  for (let i = 0; i < os.cpus().length; i++) cluster.fork();
} else {
  http.createServer(handler).listen(3000);
}
```

Forks N workers, each running on a separate core, sharing the listening port. Linear scaling for CPU.

In production: use **PM2** or systemd template units instead of writing your own clustering code.

---

### Q31. Worker threads for CPU-bound work.

```js
// main.js
const { Worker } = require('node:worker_threads');
function runTask(data) {
  return new Promise((resolve, reject) => {
    const w = new Worker('./worker.js', { workerData: data });
    w.on('message', resolve);
    w.on('error', reject);
  });
}

// worker.js
const { workerData, parentPort } = require('node:worker_threads');
parentPort.postMessage(expensiveSyncWork(workerData));
```

Use a **worker pool** (`piscina`) — spinning up a thread per request is slow.

```js
const Piscina = require('piscina');
const pool = new Piscina({ filename: './worker.js' });
const result = await pool.run(data);
```

Use cases: image processing, PDF generation, large JSON parsing, crypto, machine learning inference.

---

### Q32. Cluster vs worker_threads — when?

| Use case | Pick |
|----------|------|
| Scale a stateless HTTP server across cores | Cluster |
| Run CPU-bound function without blocking event loop | Worker threads |
| Run a separate program | child_process |
| Share memory across threads | Worker threads with SharedArrayBuffer |

Cluster workers don't share memory; worker_threads can.

---

### Q33. Child processes.

```js
const { spawn } = require('node:child_process');
const child = spawn('ffmpeg', [...args]);
child.stdout.on('data', chunk => ...);
```

For shelling out to heavy tools (ffmpeg, imagemagick, pandoc). Don't `exec` with user input — command injection.

---

### Q34. PM2 vs raw cluster.

PM2:
- Cluster mode with one command (`pm2 start app.js -i max`)
- Auto-restart on crash, log management, deployment hooks
- Web UI, metrics

Production-ready alternatives: systemd template units, container orchestrator (Kubernetes scales horizontally instead).

---

## Database and Connection Pooling

### Q35. Pool sizing for Node.

A common mistake: configuring 100 connections per pool, then running 4 instances → 400 connections to Postgres → exhaustion.

Rule:
```
total_db_connections = pool_size × instance_count + headroom
total ≤ db_max_connections × 0.8
```

Practical: pool of 10 per instance, 4 instances = 40 connections. Plenty for most apps.

---

### Q36. pg / mysql2 / mongoose pool config.

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
const pool = mysql.createPool({
  connectionLimit: 10,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
});

// mongoose
mongoose.connect(uri, { maxPoolSize: 10, serverSelectionTimeoutMS: 5000 });
```

Always set query timeouts. A hung query holds a connection until the DB times out (often minutes), starving the pool.

---

### Q37. ORM overhead.

Prisma, Sequelize, TypeORM, Mongoose all add overhead compared to raw drivers. Often 2–5x for a simple query.

Mitigations:
- Use raw SQL for hot paths (`pool.query(...)`, Prisma's `$queryRaw`)
- Avoid hydration of large models (`SELECT specific columns` not whole entity)
- Don't load relations you don't need
- Beware "magic" relations that fire on access

---

### Q38. Statement caching / prepared statements.

```js
const stmt = await client.query({ name: 'get-user', text: 'SELECT * FROM users WHERE id = $1', values: [id] });
```

The pg driver caches prepared statements per connection. Saves planning time on repeated queries. Drivers vary — verify your DB and library.

---

## Caching

### Q39. In-process LRU.

```js
const LRU = require('lru-cache');
const cache = new LRU({ max: 1000, ttl: 60_000 });
```

Pros: fastest (sub-microsecond), no network.
Cons: per-instance, divergence between instances, can't be invalidated globally.

Best for: small reference data, hot read paths, frequently used config.

---

### Q40. Redis caching pattern.

```js
async function getUser(id) {
  const key = `user:${id}`;
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);
  const user = await db.users.findOne({ id });
  await redis.set(key, JSON.stringify(user), 'EX', 300);
  return user;
}
```

Use `ioredis` for clustering and pipelining. `redis` (node-redis 4) is also good. Use `setex` / `set ... EX` so unbounded keys don't accumulate.

---

### Q41. Cache stampede protection.

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
    await sleep(50);
    return getOrSet(key, ttl, loader);
  }
}
```

Or use `cache-manager` or a battle-tested library.

---

### Q42. ETag / Cache-Control for API responses.

```js
res.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=300');
res.setHeader('ETag', etag(JSON.stringify(body)));
if (req.headers['if-none-match'] === res.getHeader('ETag')) return res.status(304).end();
res.json(body);
```

For public APIs, an ETag + CDN can offload 90%+ of read traffic.

---

## Async Patterns

### Q43. Sequential vs parallel awaits.

Slow:
```js
const a = await fetchA();
const b = await fetchB();
const c = await fetchC();   // 3× latency
```

Fast:
```js
const [a, b, c] = await Promise.all([fetchA(), fetchB(), fetchC()]);
```

But beware: `Promise.all` rejects on first error. For independent calls where partial failure is OK:
```js
const results = await Promise.allSettled([fetchA(), fetchB(), fetchC()]);
```

---

### Q44. Limiting parallelism.

A naive `Promise.all` over 10000 items can spawn 10000 concurrent DB queries → instant pool exhaustion.

```js
const pLimit = require('p-limit');
const limit = pLimit(20);
await Promise.all(items.map(i => limit(() => process(i))));
```

Or split:
```js
for (let i = 0; i < items.length; i += 50) {
  const batch = items.slice(i, i + 50);
  await Promise.all(batch.map(process));
}
```

---

### Q45. AbortController for cancellation.

```js
const ctrl = new AbortController();
setTimeout(() => ctrl.abort(), 5000);
const res = await fetch(url, { signal: ctrl.signal });
```

Always set timeouts on outgoing HTTP. A hung third party can pile up requests until you OOM.

---

### Q46. Request batching.

```js
const DataLoader = require('dataloader');
const userLoader = new DataLoader(async ids => {
  const users = await db.users.find({ id: { $in: ids } });
  return ids.map(id => users.find(u => u.id === id));
});

await userLoader.load(1);  // batched with concurrent calls in same tick
```

DataLoader collapses N+1 by batching loads within a single event loop tick. Common in GraphQL.

---

### Q47. Debouncing and throttling.

For events that fire fast (resize, scroll, keyboard, sensor data) — handle less often.

```js
const { debounce, throttle } = require('lodash-es');
const onChange = debounce(value => persist(value), 300);
const onScroll = throttle(handle, 100);
```

For server-side: rate limiting incoming events with `bottleneck` or token-bucket libraries.

---

## Streams and Large Data

### Q48. Why streams matter.

Loading a 1 GB CSV into memory:
```js
const data = fs.readFileSync('huge.csv');  // OOM
```

Streaming:
```js
const { pipeline } = require('node:stream/promises');
const fs = require('node:fs');
const csv = require('csv-parse');

await pipeline(
  fs.createReadStream('huge.csv'),
  csv.parse({ columns: true }),
  async function* (source) {
    for await (const row of source) {
      yield JSON.stringify(row) + '\n';
    }
  },
  fs.createWriteStream('out.ndjson'),
);
```

Constant memory regardless of file size.

---

### Q49. Backpressure.

When the consumer is slower than the producer, streams pause the producer. Native streams handle this via `.write()` returning `false` and `'drain'` event.

Wrong:
```js
res.write(line);  // ignore return value, fire as fast as possible
```

Right:
```js
if (!res.write(line)) await once(res, 'drain');
```

Or use `pipeline` which handles it.

---

### Q50. Streaming HTTP responses.

```js
res.setHeader('Transfer-Encoding', 'chunked');
for await (const row of db.queryStream('SELECT ...')) {
  res.write(JSON.stringify(row) + '\n');
}
res.end();
```

Send large datasets without buffering. NDJSON or SSE for streaming JSON.

---

## Logging Performance

### Q51. pino vs winston vs bunyan.

| Library | Speed | Features |
|---------|-------|----------|
| pino | Fastest (~5x winston) | Async, structured JSON |
| winston | Slower | Pluggable transports |
| bunyan | Older | JSON, similar to pino |
| console | Synchronous | Don't use in production |

`console.log` is synchronous — every call blocks the event loop. Use pino:

```js
const logger = require('pino')();
logger.info({ user_id: 123 }, 'login successful');
```

---

### Q52. Async logging with pino.

```js
const logger = require('pino')(pino.destination({ sync: false, dest: '/var/log/app.log' }));
```

Logs are buffered and flushed asynchronously. ~10x throughput vs synchronous.

For multi-process: pipe to a separate transport:
```js
const transport = pino.transport({ target: 'pino-pretty' });
const logger = pino(transport);
```

---

### Q53. Log volume management.

- Sample noisy logs (`if (Math.random() < 0.01) logger.info(...)`)
- Rate limit error logs to prevent log floods on incidents
- Use levels properly: `info` for normal, `debug` not in prod
- Structure logs for searchability (don't string-concat)
- Rotate (`logrotate` or pino's `pino.transport` with rotation)

A logging-heavy app can spend 30% CPU just on logging if misused.

---

## Background Jobs and Queues

### Q54. BullMQ for Redis-backed jobs.

```js
const { Queue, Worker } = require('bullmq');
const queue = new Queue('emails', { connection });

await queue.add('send', { to: 'a@b.c' }, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } });

new Worker('emails', async job => {
  await sendEmail(job.data);
}, { connection, concurrency: 10 });
```

Features: retries, delayed jobs, repeatable jobs, rate limiting, priorities, flow (DAG), parent-child.

---

### Q55. Queue performance considerations.

- **Concurrency** per worker: balance between throughput and downstream load
- **Multiple workers** on multiple machines for horizontal scale
- **Lock duration** longer than max job time to avoid duplicate processing
- **Stalled job detection** — workers heartbeat every N seconds
- **Job size**: store payload references (S3 URL), not huge JSON in Redis

---

### Q56. SQS / RabbitMQ / Kafka — when to switch.

- **BullMQ (Redis):** simple, fast, < 10k jobs/s per Redis instance
- **SQS (AWS):** managed, virtually unlimited, ~10s p99 latency
- **RabbitMQ:** rich routing (topic, fanout), strong delivery guarantees
- **Kafka:** event streams, replay, retention, very high throughput

Most apps start with BullMQ; move to Kafka only when log/event volume justifies it.

---

## Microservice Latency

### Q57. Internal call latency budget.

If a user request fans out to 5 services synchronously, each adding 50 ms, you're at 250+ ms before the user sees anything.

Tactics:
- **Parallel fan-out** with timeouts and circuit breakers
- **Request hedging** (issue duplicate requests, use first response)
- **Caching** at gateway layer
- **gRPC over HTTP/JSON** — 5–10x faster for cross-service calls
- **Connection reuse** (keep-alive, gRPC channels)
- **Co-locate** services in the same AZ (cross-AZ adds 1–2 ms)

---

### Q58. gRPC.

```proto
service UserService {
  rpc GetUser (GetUserRequest) returns (User);
}
```

Pros:
- Binary protobuf is smaller and faster than JSON
- HTTP/2 multiplexing, single connection
- Streaming (server, client, bidirectional)
- Strict schemas, generated clients

Cons:
- Harder to debug (no curl)
- Browser support requires gRPC-Web proxy
- Less ergonomic than REST in some languages

---

### Q59. Circuit breaker.

```js
const CircuitBreaker = require('opossum');
const breaker = new CircuitBreaker(callExternalApi, {
  timeout: 3000,
  errorThresholdPercentage: 50,
  resetTimeout: 30_000,
});
```

When error rate exceeds threshold, the breaker opens and fails fast. Prevents cascade failure when a downstream is down.

---

### Q60. Retries and backoff.

```js
async function withRetry(fn, attempts = 3) {
  for (let i = 0; i < attempts; i++) {
    try { return await fn(); }
    catch (e) {
      if (i === attempts - 1) throw e;
      await sleep(2 ** i * 100 + Math.random() * 100);
    }
  }
}
```

Always include **jitter** to avoid thundering herd. Don't retry idempotent operations only — be careful with POST.

Use library: `cockatiel`, `p-retry`, `async-retry`.

---

### Q61. JSON parsing alternatives.

For inter-service traffic where both ends are Node:
- **MessagePack** (`@msgpack/msgpack`) — ~30% smaller, 2x faster than JSON
- **Protobuf** — schema-based, fastest, smallest
- **CBOR** — similar to MessagePack
- **Avro** — schema evolution

For client-facing APIs, JSON is usually fine — overhead is rarely the bottleneck.

---

### Q62. Avoid synchronous JSON.stringify on huge payloads.

For 50+ MB JSON, `JSON.stringify` blocks the event loop for hundreds of ms.

Alternatives:
- Stream via `JSONStream`
- Use `fast-json-stringify` (Fastify) with schema for 5–10x speedup
- Move serialization to a worker thread

---

## Real Production Case Studies

### Q63. Memory leak from unbounded cache.

Service hit OOM after 24h. Heap snapshot showed `Map` growing forever.

Code:
```js
const userCache = new Map();
function getUser(id) {
  if (!userCache.has(id)) userCache.set(id, fetchUser(id));
  return userCache.get(id);
}
```

Fix: replaced with `lru-cache` with `max: 10000, ttl: 5 * 60 * 1000`. Memory plateaued at 800 MB.

---

### Q64. Event loop blocking from sync crypto.

Latency p99 spiked from 50 ms to 2 s under load. Profile showed `crypto.createHash` and `bcrypt.hashSync` on the request path.

Fixes:
1. Replace `bcrypt.hashSync` with `bcrypt.hash` (uses libuv pool)
2. `UV_THREADPOOL_SIZE=16` to allow more concurrent hashes
3. Lower bcrypt cost from 12 to 10 (still secure, much faster)
4. Move hash to a worker pool for isolation

---

### Q65. Pool exhaustion from unbounded parallelism.

Job processed 100k records, each with a DB call. Used `Promise.all`. Pool of 10 connections maxed; queries timed out; downstream services flooded.

Fix:
```js
const pLimit = require('p-limit');
const limit = pLimit(20);
await Promise.all(records.map(r => limit(() => process(r))));
```

Constant 20 concurrent DB queries — no exhaustion, no flood.

---

### Q66. Slow JSON serialization.

Endpoint returning 100k records took 4 seconds. Profile showed `JSON.stringify` taking 3.2 seconds.

Solutions tried:
1. `fast-json-stringify` with schema → 800 ms
2. Switched to NDJSON streaming response → ~50 ms TTFB, full transfer in 1.2 s
3. Eventually added pagination (real fix)

---

### Q67. The retry storm.

Downstream API got slow → service retried 3× → load on downstream tripled → made it slower → more retries.

Fixes:
- Circuit breaker (opossum) opens after 50% errors
- Retry budget: max 10% of original request volume
- Exponential backoff with jitter
- Token-bucket rate limiter on retries

---

### Q68. The keep-alive surprise.

ALB had idle timeout 60 s. Node `keepAliveTimeout` was default 5 s. Result: ALB sent requests to a closing socket → 502s in logs.

Fix: set `server.keepAliveTimeout = 65_000` (longer than ALB) and `server.headersTimeout = 66_000` (must be > keepAliveTimeout).

---

### Q69. Large heap, slow GC.

Service grew to 6 GB old space. Each GC pause was 800 ms. Latency p99 was terrible.

Fixes:
1. Find the largest retained objects (heap snapshot)
2. Move large in-memory caches to Redis
3. Lower `--max-old-space-size` to force earlier GC and accept process restart at 4 GB
4. Use multiple smaller processes (4 × 2 GB) instead of one big one

Smaller heaps = faster GC pauses.

---

### Q70. Production readiness checklist.

- [ ] Server timeouts configured (request, headers, keep-alive)
- [ ] Body size limits set
- [ ] Outgoing HTTP has timeouts
- [ ] Connection pool sized correctly with reasonable defaults
- [ ] Graceful shutdown (SIGTERM → drain → close DB → exit)
- [ ] Health and readiness endpoints
- [ ] Cluster mode or container replicas
- [ ] PM2 / systemd / orchestrator manages restarts
- [ ] Async logging with pino
- [ ] Structured logs with correlation IDs
- [ ] Metrics exported (Prometheus, OpenTelemetry)
- [ ] Tracing for distributed flows
- [ ] Memory ceiling with `--max-old-space-size` matching container limit
- [ ] No synchronous file or crypto on request path
- [ ] Bcrypt / crypto cost tuned
- [ ] Caches bounded (LRU + TTL)
- [ ] Circuit breaker on flaky downstreams
- [ ] Rate limiting (express-rate-limit, fastify-rate-limit, or Redis-backed)
- [ ] Stress-tested with autocannon / wrk before production

---

### Q71. Senior signal: "Make this Node service handle 10x traffic."

Walk through:

1. **Measure** — autocannon load test, RUM, find the actual bottleneck
2. **Quick wins** — pool size, keep-alive, missing indexes (downstream), payload limits
3. **Caching** — in-process LRU for hot keys, Redis for shared
4. **Reduce work** — pagination, projection, schema-based serialization
5. **Async** — queue non-critical work
6. **Horizontal scale** — cluster on box, then more boxes
7. **Pre-fetch / batch** — DataLoader for fan-out reads
8. **Move CPU work** — worker threads, dedicated services, language change for hot paths
9. **Architecture** — read replicas, CDN, edge functions
10. **Iterate** — measure again, find new bottleneck, repeat

Senior-level is about diagnosis discipline: never optimize without a measurement.
