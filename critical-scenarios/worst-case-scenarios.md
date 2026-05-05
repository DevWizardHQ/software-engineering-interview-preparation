# Worst Case Scenarios — Incident Response Playbook

**Purpose:** Direct, ready-to-say answers for "what would you do if X breaks?" questions. Each scenario includes the answer you would give, the diagnostic steps, and code examples for the fix or prevention.

---

## Production Outages

## Q1. The site is down. Users cannot log in. What do you do?

**Answer:**

First, I stop the bleeding. I check if it is truly down or partial — load balancer health, status page, monitoring dashboard. If it is fully down and we deployed in the last thirty minutes, I attempt a rollback to the last known good version. I post on the status page so users know we are aware.

Second, I diagnose. Error logs first — most outages leave a trace. Then infrastructure metrics: CPU, memory, database connections. Then recent deploys. Then third-party services: auth providers, payment, DNS.

Third, I mitigate. If it is a recent deploy, rollback. If it is database connection saturation, restart the pool or reduce workers. If it is an auth provider issue, switch to fallback or buy time with a banner.

Fourth, I resolve the root cause. Find the bad commit, missing index, or leaked connection. Fix it properly with tests. Deploy with verification.

Fifth, I prevent recurrence. Blameless post-mortem, add monitoring that would have caught this earlier, add automated tests for the failure mode.

The communication style I use: I do not change things based on guesses while the system is on fire. I gather signals first, then act.

---

## Q2. The API is responding slowly. P95 latency is 8 seconds.

**Answer:**

I look at the latency distribution first. Is it across all endpoints or just one?

If it is one endpoint, it is likely a slow query, missing index, N+1 query, or external API call. I check the query plan with EXPLAIN ANALYZE and look at application traces.

If it is all endpoints, it is likely infrastructure: database connection saturation, CPU at 100 percent, memory pressure causing GC pauses, or network issues.

The most common culprits in order of frequency:

1. Missing or stale database index
2. N+1 query introduced by recent code
3. External API call that suddenly got slow with no timeout set
4. Background job stealing CPU
5. Memory leak causing GC thrashing

Diagnostic queries I would run:

```sql
-- Postgres: find currently-running slow queries
SELECT pid, now() - query_start AS duration, query, state
FROM pg_stat_activity
WHERE state != 'idle' AND now() - query_start > interval '1 second'
ORDER BY duration DESC;

-- Find queries spending the most total time
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

For the immediate fix, I would identify the worst offender and either kill it or apply the cheapest mitigation (add an index, add a timeout, scale horizontally).

---

## Q3. CPU is at 100 percent on production servers. What is your move?

**Answer:**

First, I find what process is using CPU — is it the application or something else like a background job or runaway script?

If it is the application, I capture a profile or thread dump.

The common causes:

- Infinite loop in code, often from a recent deploy
- Cryptography too expensive under load (bcrypt cost too high)
- Regex backtracking, also called ReDoS
- JSON parsing of huge payloads
- Image or PDF processing without offloading to background workers

Short-term: I scale horizontally by adding instances and rate-limit the trigger endpoint.

Long-term: fix the hot code path and move CPU-heavy work to background workers.

```javascript
// Wrong - synchronous expensive work in request handler
app.post('/upload', async (req, res) => {
  const result = await processLargeImage(req.body.image); // CPU spike
  res.json(result);
});

// Right - queue for background processing
app.post('/upload', async (req, res) => {
  const job = await queue.add('process-image', { imageId: req.body.imageId });
  res.json({ jobId: job.id });
});

// Worker handles it asynchronously
queue.process('process-image', async (job) => {
  const result = await processLargeImage(job.data.imageId);
  await db.images.update({ id: job.data.imageId }, { result });
});
```

---

## Q4. The site works but feels slow only for some users. What is happening?

**Answer:**

This is usually region-specific or user-segment specific. Possible causes:

- CDN cache miss in their region
- Slow database replica in their region
- Country-specific third-party service blocked
- Their user has much more data than typical (the "power user problem")
- Cold start on serverless if their region has low traffic

My approach: filter logs by user, region, or session ID. Reproduce with their account if possible. Check if it is data-volume related.

The classic case is when a feature works fine for ninety-nine percent of users but is unusable for the one percent with the most data because pagination was not applied.

```javascript
// Wrong - unbounded query
app.get('/items', async (req, res) => {
  const items = await db.items.find({ user_id: req.currentUser.id });
  res.json(items); // 10,000 items for power user, slow for them
});

// Right - paginated
app.get('/items', async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 100);
  const offset = parseInt(req.query.offset) || 0;
  
  const items = await db.items.find({ 
    user_id: req.currentUser.id,
  }).limit(limit).offset(offset);
  
  res.json({ items, limit, offset });
});
```

---

## Database Catastrophes

## Q5. The database is at 100 percent CPU and connections are timing out. What now?

**Answer:**

Immediate stop-bleeding actions:

I identify the slow queries. In Postgres, I run:

```sql
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;
```

I kill the worst offenders if safe:

```sql
SELECT pg_cancel_backend(pid); -- graceful
SELECT pg_terminate_backend(pid); -- force
```

I temporarily increase max connections if memory allows. I add app-side timeouts to reject new long-running queries.

Diagnose: Is one query hammering the database? Did a query plan change because of stale statistics? Is a missing index causing sequential scans on a big table? Did someone deploy a new ORM query that is accidentally an N+1? Is it a lock storm from a long-running transaction?

Mitigate: add the missing index using CONCURRENTLY in Postgres so it does not lock writes:

```sql
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);
```

Refactor the bad query. Move heavy reads to a replica.

Prevent: slow query log alerts at one second or more, run pgBadger weekly to analyze patterns, enforce query budget per request in code.

---

## Q6. The database is corrupt. Some rows have wrong data. What do you do?

**Answer:**

This is a "stop and do not panic" moment.

Step one: stop writes immediately if the corruption is spreading. Use a feature flag, take the affected service offline, or revoke write permissions temporarily.

Step two: snapshot the current state before any fix attempts.

```sql
CREATE TABLE accounts_snapshot_20240115 AS SELECT * FROM accounts;
```

Step three: identify the bug. Corrupt data has a cause — race condition, bad migration, code bug. Find it before fixing data.

Step four: quantify the damage. How many rows, how much money, how many users?

Step five: choose a restore strategy.

- Point-in-time restore from backup if before corruption started
- Reconstruct from event log or audit log
- Manual correction with verification

Step six: communicate. Affected users need to know.

Step seven: prevent recurrence. Add a constraint, add a test, fix the cause.

The critical rule: never edit production data with raw SQL during an incident without (a) a backup, (b) a second engineer reviewing the SQL, (c) wrapping in BEGIN; with explicit COMMIT; so you can ROLLBACK, and (d) running a SELECT first to verify the WHERE clause matches expected rows.

```sql
BEGIN;
-- Verify the rows we are about to change
SELECT id, balance FROM accounts WHERE user_id = '123' AND balance < 0;
-- If correct, proceed
UPDATE accounts SET balance = 0 WHERE user_id = '123' AND balance < 0;
-- Verify the change
SELECT id, balance FROM accounts WHERE user_id = '123';
-- Now commit (or ROLLBACK if anything looks wrong)
COMMIT;
```

---

## Q7. Replica lag is now 30 minutes and growing. What is wrong?

**Answer:**

Possible causes:

- Massive write on the primary, like a bulk insert or ALTER TABLE
- Replica is undersized compared to the primary
- Network bottleneck between primary and replica
- A long-running query on the replica blocking replay
- Cascading replica chain has a slow link

Mitigations:

If users read from the replica, fail back reads to the primary temporarily, knowing it will add load. Identify the slow operation on the primary and stop it if possible. Resize the replica or add more replicas.

The senior point: lag is not just a number. It is a correctness issue. If users read from a lagged replica, they see stale data. In banking, this is a bug. In social feeds, it is tolerable.

Code-level fix to read your own writes:

```javascript
// After a write, read from primary for X seconds
const writeTimestamp = new Map();

async function updateUser(userId, data) {
  await primaryDb.users.update({ id: userId }, data);
  writeTimestamp.set(userId, Date.now());
}

async function getUser(userId) {
  const lastWrite = writeTimestamp.get(userId);
  if (lastWrite && Date.now() - lastWrite < 5000) {
    return primaryDb.users.findOne({ id: userId });
  }
  return replicaDb.users.findOne({ id: userId });
}
```

---

## Q8. A migration is taking 4 hours on production and locks the table.

**Answer:**

This is a deploy disaster. Common causes:

- ALTER TABLE ADD COLUMN NOT NULL DEFAULT on a 50-million-row table — rewrites the whole table
- Adding a unique index on a non-unique column
- Foreign key check on a huge table

Recovery: cancel the migration if reversible. If not reversible, run during low-traffic windows. Use online migration tools: gh-ost or pt-online-schema-change for MySQL, pg_repack for some Postgres cases.

The right way next time:

```sql
-- Wrong - rewrites the whole table
ALTER TABLE orders ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'pending';

-- Right - three steps, no long lock

-- Step 1: add nullable column (instant)
ALTER TABLE orders ADD COLUMN status VARCHAR(20);

-- Step 2: backfill in batches in app code
-- (looped, with sleep between batches)
UPDATE orders SET status = 'pending' 
WHERE status IS NULL AND id IN (
  SELECT id FROM orders WHERE status IS NULL LIMIT 1000
);

-- Step 3: after backfill complete, add NOT NULL (fast since all rows have a value)
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'pending';
```

For indexes:

```sql
-- Wrong - locks the table for writes
CREATE INDEX idx_orders_status ON orders(status);

-- Right - does not lock writes
CREATE INDEX CONCURRENTLY idx_orders_status ON orders(status);
```

---

## Security Incidents

## Q9. We are under a credential stuffing attack. Login attempts are flooding.

**Answer:**

Stop the bleeding:

I add aggressive rate limiting on /login, for example five attempts per IP per minute. I add captcha after three failed attempts. I block known malicious IPs using IP reputation services. I add a delay (200-500ms) on failed login responses to slow attackers.

```javascript
const rateLimit = require('express-rate-limit');

const loginLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 5, // 5 attempts per IP
  message: 'Too many login attempts, please try again later',
  standardHeaders: true,
});

app.post('/login', loginLimiter, async (req, res) => {
  const user = await db.users.findOne({ email: req.body.email });
  
  // Constant-time comparison to avoid timing attacks
  const valid = user && await bcrypt.compare(req.body.password, user.password_hash);
  
  if (!valid) {
    // Add a delay to slow down attackers
    await new Promise(r => setTimeout(r, 300));
    
    // Track failed attempts per email too
    await db.failed_logins.insert({ email: req.body.email, ip: req.ip });
    
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  res.json({ token: generateToken(user) });
});
```

Diagnose: how many accounts compromised? Check successful logins from new IPs. Look at password reuse — were these credentials leaked elsewhere?

Resolve: force password reset for affected accounts. Notify users. Add MFA option, require it for admin accounts.

Prevent: use HaveIBeenPwned API on password creation to reject leaked passwords. Implement device-based auth with device fingerprint. Geographic anomaly detection. WAF rules.

---

## Q10. SQL injection found in production. What now?

**Answer:**

Immediate actions:

1. Patch the vulnerable endpoint by replacing string concatenation with parameterized queries.
2. If the vulnerability is exploitable in seconds, deploy a WAF rule blocking the pattern as a temporary shield.
3. Audit logs to see if it was exploited.
4. Check what data the attacker could access.

```javascript
// Wrong - vulnerable to SQL injection
app.get('/users', async (req, res) => {
  const search = req.query.search;
  const users = await db.query(`SELECT * FROM users WHERE name LIKE '%${search}%'`);
  res.json(users);
});

// Right - parameterized query
app.get('/users', async (req, res) => {
  const search = req.query.search || '';
  const users = await db.query(
    'SELECT * FROM users WHERE name LIKE $1', 
    [`%${search}%`]
  );
  res.json(users);
});
```

Damage assessment: what tables could be read? What data could be modified? Are there backups predating any modification?

Resolution: code review every SQL query in the codebase for similar issues. Add static analysis like Semgrep to CI. Train the team on parameterized queries.

Communicate: if user data leaked, comply with breach disclosure laws.

---

## Q11. We discovered passwords are stored in plaintext in our database. Now what?

**Answer:**

This is a critical incident.

Step one: stop further damage. Disable any code paths that can read these passwords.

Step two: force password reset for all users. Old passwords cannot be trusted.

Step three: migrate to proper hashing. Use bcrypt with cost factor 12 or higher, or Argon2id.

Step four: audit. Who had database access? Who could have read these passwords?

Step five: disclose. Depending on jurisdiction, this is a reportable breach.

Step six: implement properly. Never store passwords. Hash and salt with bcrypt or Argon2.

```javascript
const bcrypt = require('bcrypt');

// Storing a password
async function createUser(email, password) {
  const passwordHash = await bcrypt.hash(password, 12);
  return db.users.insert({ email, password_hash: passwordHash });
}

// Verifying a password
async function verifyLogin(email, password) {
  const user = await db.users.findOne({ email });
  if (!user) return null;
  
  const valid = await bcrypt.compare(password, user.password_hash);
  return valid ? user : null;
}
```

---

## Q12. Auth bypass discovered — a user can access another user's data.

**Answer:**

Immediate actions: roll back the affected endpoint or feature. Audit logs to find affected users. Reset session tokens to force re-authentication.

Diagnose root cause. The most common is trusting client-supplied IDs without verifying ownership. The second most common is incorrect SQL filter — missing the WHERE user_id = current_user clause. Third is improperly configured RBAC.

Fix: server-side ownership check in every endpoint that accesses user data. Authorization at the data layer using Row Level Security in Postgres or repository-level filters. Add automated tests for cross-tenant access.

```javascript
// Wrong - trusting client-supplied user ID
app.get('/orders/:id', async (req, res) => {
  const order = await db.orders.findOne({ id: req.params.id });
  if (!order) return res.status(404).end();
  res.json(order); // any user can read any order
});

// Right - server-side ownership check
app.get('/orders/:id', async (req, res) => {
  const order = await db.orders.findOne({ 
    id: req.params.id,
    user_id: req.currentUser.id, // ownership check
  });
  if (!order) return res.status(404).end();
  res.json(order);
});

// Better - test cross-tenant access in CI
test('cannot read another users order', async () => {
  const userA = await createUser();
  const userB = await createUser();
  const order = await createOrder(userB);
  
  const res = await request(app)
    .get(`/orders/${order.id}`)
    .set('Authorization', `Bearer ${userA.token}`);
  
  expect(res.status).toBe(404);
});
```

The rule: never trust the client. Authenticate the user, then derive what they can access from server-side data.

---

## Performance Collapses

## Q13. After deploying, response time tripled. We need to fix it now.

**Answer:**

Step one: rollback if possible. Restore service first, debug after.

Step two: if you cannot rollback because of a database migration or other state change, identify what changed.

Step three: use a profiler or APM to find the slowest endpoint or query.

Step four: look for common deploy regressions:

- New ORM query introduced N+1
- New feature loaded too much data per request
- New library has higher overhead
- Caching was removed accidentally
- Synchronous call to a slow service

Step five: patch fast, deploy fast, monitor.

```javascript
// Common N+1 introduced by new code
// Wrong
app.get('/orders', async (req, res) => {
  const orders = await db.orders.find({ user_id: req.currentUser.id });
  for (const order of orders) {
    order.items = await db.order_items.find({ order_id: order.id }); // N+1
  }
  res.json(orders);
});

// Right - single query with join or eager loading
app.get('/orders', async (req, res) => {
  const orders = await db.orders.find({ 
    user_id: req.currentUser.id 
  }).include('items');
  res.json(orders);
});
```

---

## Q14. Memory usage is growing slowly until the app crashes. How do you debug a memory leak?

**Answer:**

For Node.js: use the --inspect flag and Chrome DevTools heap snapshot. Take three snapshots over time and compare growing object types. Common leaks are event listeners not removed, closures holding large objects, caches without TTL, and global maps that only grow.

```javascript
// Common leak - listener not removed
class DataFetcher {
  constructor() {
    eventBus.on('data', this.handleData.bind(this)); // never removed
  }
}

// Fix - clean up
class DataFetcher {
  constructor() {
    this.handler = this.handleData.bind(this);
    eventBus.on('data', this.handler);
  }
  
  destroy() {
    eventBus.off('data', this.handler);
  }
}

// Common leak - cache without TTL
const cache = new Map();
function get(key) {
  if (!cache.has(key)) {
    cache.set(key, expensive(key));
  }
  return cache.get(key);
}

// Fix - LRU cache with size limit
const LRU = require('lru-cache');
const cache = new LRU({ max: 1000, ttl: 5 * 60 * 1000 }); // 5 min TTL, max 1000 entries
```

For PHP: look for static caches not cleared. ORMs that hold object identity maps like Doctrine or Eloquent collections. Long-running CLI scripts and workers that do not reset state.

For Java: jmap for heap dump, Eclipse MAT to analyze. Common: static List accumulating, ThreadLocal not cleared.

Mitigation while debugging: recycle workers periodically, every 1000 requests. Increase memory temporarily. Restart on schedule.

---

## Q15. We have an N+1 query and do not know which endpoint.

**Answer:**

Detect:

- Use pg_stat_statements to find queries called many times
- APM tools like New Relic or Datadog show this at the request level
- Most ORMs have logging modes that count queries per request — enable in dev

Pattern to look for: a loop iterating over a collection and fetching related data per item, or lazy loading on a collection in a template.

Fix: use eager loading or batch the queries.

```javascript
// Wrong - N+1
const users = await db.users.find();
for (const user of users) {
  user.posts = await db.posts.find({ user_id: user.id }); // N queries
}

// Right - eager loading
const users = await db.users.find().include('posts');

// Right - batch fetch and map
const users = await db.users.find();
const userIds = users.map(u => u.id);
const posts = await db.posts.find({ user_id: { $in: userIds } });
const postsByUser = groupBy(posts, 'user_id');
for (const user of users) {
  user.posts = postsByUser[user.id] || [];
}
```

Prevent: enable query counting in development. Set a budget like 10 queries per request. Alert if exceeded.

---

## Data Loss and Corruption

## Q16. A developer ran DELETE FROM users without a WHERE clause. What now?

**Answer:**

This is a stop-and-do-not-panic moment.

Step one: did they commit? If still in transaction, ROLLBACK immediately:

```sql
ROLLBACK;
```

Step two: if committed, restore from the most recent backup. If point-in-time recovery is enabled, restore to the moment before the DELETE.

Step three: for the lost data between the last backup and the DELETE:

- Application logs may have user activity
- Audit tables (if enabled) may have inserts
- Replicas may not have replayed yet (slim chance — pause replication immediately)
- WAL archives in Postgres have all changes — replay them

Prevent:

- Production database access requires two-person review for destructive queries
- Use a query tool that requires explicit LIMIT or WHERE for DELETE/UPDATE
- Always backup before bulk operations
- Use soft-delete by default in app code; raw DELETE requires a flag

```sql
-- Pre-flight checks every developer should do
BEGIN;
-- Always verify WHERE clause first
SELECT COUNT(*) FROM users WHERE created_at < '2020-01-01';
-- If count looks right, then DELETE
DELETE FROM users WHERE created_at < '2020-01-01';
-- Verify rowcount matches
-- COMMIT only if everything matches
COMMIT;
-- Or ROLLBACK if anything is suspicious
```

---

## Q17. Backups exist but have never been tested. Now we need to restore.

**Answer:**

This is the classic untested-backup-is-no-backup problem.

Step one: restore to a non-production environment first.

Step two: verify the data is consistent and recent.

Step three: time the restore. Know how long it takes for next time.

Step four: add monthly restore drills to the runbook.

The senior insight: a backup you have never restored is hope, not a strategy. Senior engineers test restores quarterly minimum.

---

## Q18. We deployed a migration that wiped a column. How do we recover?

**Answer:**

Step one: stop writes to the affected table if recovery is possible.

Step two: restore from backup to a separate database.

Step three: copy the column data from the backup to production.

Step four: verify integrity with counts and checksums.

Step five: resume writes.

```sql
-- Restore to a new database
-- (depends on backup tool: pg_restore, etc.)

-- Connect to the restored database, dump the column
COPY (SELECT id, lost_column FROM users) TO '/tmp/recovery.csv' CSV HEADER;

-- On production, create a temporary table to load the data
CREATE TABLE users_recovery (id UUID, lost_column TEXT);
COPY users_recovery FROM '/tmp/recovery.csv' CSV HEADER;

-- Add the column back if it was dropped
ALTER TABLE users ADD COLUMN lost_column TEXT;

-- Update from recovery data
UPDATE users SET lost_column = r.lost_column 
FROM users_recovery r 
WHERE users.id = r.id;

-- Verify
SELECT COUNT(*) FROM users WHERE lost_column IS NOT NULL;

DROP TABLE users_recovery;
```

Prevent: migration code review with another engineer. Migrations should never use DROP COLUMN directly. Instead, RENAME to _deprecated_<col> first, then DROP in a later migration after verifying no impact. Same rule for DROP TABLE.

---

## Deployment Disasters

## Q19. The deploy failed halfway. Some servers have new code, some have old. Behavior is mixed.

**Answer:**

This is a partial deploy state — very dangerous.

Step one: choose a direction. Finish the deploy or rollback. Do not stay in mixed state.

Step two: if finishing, disable the load balancer for old-version servers, deploy them, re-enable.

Step three: if rolling back, rollback all servers, including ones that succeeded.

The lesson: deployments should be atomic per environment. Use blue-green, canary, or rolling deploy with health checks that auto-rollback on failure.

```javascript
// Health check endpoint that fails if version is broken
app.get('/health', async (req, res) => {
  try {
    // Verify critical dependencies
    await db.query('SELECT 1');
    await redis.ping();
    
    // Verify version-specific functionality
    const versionCheck = await runVersionSpecificCheck();
    
    res.json({ 
      status: 'ok', 
      version: process.env.APP_VERSION,
    });
  } catch (e) {
    res.status(503).json({ status: 'unhealthy', error: e.message });
  }
});
```

Prevent: health check endpoint that fails fast on broken deploys. Auto-rollback on failure. Pre-deploy smoke tests in staging.

---

## Q20. We deployed and now the database cannot connect. The connection string was wrong.

**Answer:**

Step one: rollback the config change.

Step two: if it was a secret rotation, rotate again to the right value.

Step three: lesson learned. Secrets and config should be tested in a staging environment first.

The senior pattern: use a config validation step at startup that fails fast with a clear message. Do not read secrets only when needed — read at boot and crash if missing or unreachable. This way, deploys fail fast instead of silently breaking later.

```javascript
// Config validation at startup
async function validateConfig() {
  const required = ['DATABASE_URL', 'REDIS_URL', 'JWT_SECRET'];
  for (const key of required) {
    if (!process.env[key]) {
      throw new Error(`Missing required env var: ${key}`);
    }
  }
  
  // Test database connection
  try {
    await db.query('SELECT 1');
  } catch (e) {
    throw new Error(`Database connection failed: ${e.message}`);
  }
  
  // Test redis connection
  try {
    await redis.ping();
  } catch (e) {
    throw new Error(`Redis connection failed: ${e.message}`);
  }
  
  console.log('Config validation passed');
}

// At startup
validateConfig().catch(err => {
  console.error('Startup failed:', err);
  process.exit(1);
});
```

---

## Q21. The deploy succeeded but a feature is broken. Tests passed.

**Answer:**

Tests passed but reality did not. Why?

- Tests use mocks; real integration is broken
- Test data does not match production data shape
- Tests run against in-memory database, but production has different DB version
- Migration that ran in tests was different from production
- Feature flag set differently in production
- Environment variable mismatch

Fix the feature first by rolling back or hot-fixing, then fix the test gap.

```javascript
// Add an integration test that hits real services
describe('Integration: payment flow', () => {
  beforeAll(async () => {
    // Use a real test database, not in-memory
    await testDb.migrate.latest();
  });
  
  it('completes a full payment flow with real API', async () => {
    // Use real Stripe test mode, not a mock
    const response = await request(app)
      .post('/payments')
      .send({ amount: 100, currency: 'usd', source: 'tok_visa' });
    
    expect(response.status).toBe(200);
    expect(response.body.charge_id).toBeDefined();
    
    // Verify the charge exists in Stripe
    const charge = await stripe.charges.retrieve(response.body.charge_id);
    expect(charge.amount).toBe(100);
  });
});
```

Pre-prod environments should mirror production for critical paths.

---

## Third-Party Failures

## Q22. The payment provider is down. We are losing transactions.

**Answer:**

Architecture must handle this in advance:

- Queue payment requests when the provider is down
- Retry with exponential backoff
- Have a fallback provider for critical paths
- Communicate clearly to users — "Payment processing is delayed, you will be charged when service resumes"
- Idempotency keys ensure no double-charge on retry

Right now: show users a clear message. Queue intent with idempotency key. Process when provider returns. Monitor and verify all queued requests eventually complete.

```javascript
async function processPayment(orderId, amount, idempotencyKey) {
  // Save intent first
  await db.payment_intents.insert({
    order_id: orderId,
    amount,
    idempotency_key: idempotencyKey,
    status: 'pending',
  });
  
  try {
    const result = await paymentProvider.charge({ 
      amount, 
      idempotency_key: idempotencyKey,
      timeout: 5000,
    });
    
    await db.payment_intents.update(
      { idempotency_key: idempotencyKey },
      { status: 'succeeded', provider_id: result.id }
    );
    return result;
  } catch (err) {
    if (err.code === 'PROVIDER_DOWN' || err.code === 'TIMEOUT') {
      // Queue for retry
      await queue.add('retry-payment', { idempotencyKey }, { 
        delay: 30000,
        attempts: 5,
        backoff: { type: 'exponential', delay: 30000 },
      });
      throw new Error('Payment queued, will be processed when service returns');
    }
    throw err;
  }
}
```

---

## Q23. An external API we depend on changed without notice. Things break.

**Answer:**

Step one: identify the affected calls quickly.

Step two: adapt the request and response handling to the new API.

Step three: long-term, never depend on a third party without:

- A circuit breaker pattern so their outage does not take you down
- A timeout — no API call should hang forever
- A fallback or graceful degradation
- A version pin if available

```javascript
// Circuit breaker pattern
class CircuitBreaker {
  constructor(fn, options = {}) {
    this.fn = fn;
    this.failures = 0;
    this.threshold = options.threshold || 5;
    this.timeout = options.timeout || 60000;
    this.state = 'closed';
    this.openedAt = null;
  }
  
  async call(...args) {
    if (this.state === 'open') {
      if (Date.now() - this.openedAt < this.timeout) {
        throw new Error('Circuit breaker is open');
      }
      this.state = 'half-open';
    }
    
    try {
      const result = await this.fn(...args);
      this.failures = 0;
      this.state = 'closed';
      return result;
    } catch (err) {
      this.failures++;
      if (this.failures >= this.threshold) {
        this.state = 'open';
        this.openedAt = Date.now();
      }
      throw err;
    }
  }
}

const apiBreaker = new CircuitBreaker(externalApi.call, { threshold: 5, timeout: 60000 });
```

---

## Q24. Email provider is rejecting our emails as spam. Users miss password resets.

**Answer:**

Step one: switch to a backup provider for transactional emails.

Step two: diagnose why the current provider flagged us:

- Sender reputation (IP/domain)
- Content (suspicious links, unusual words, missing unsubscribe)
- Recipient signals (high bounce rate, complaints)

Step three: set up SPF, DKIM, and DMARC properly.

Step four: use a separate sending domain for transactional versus marketing emails.

Step five: monitor delivery rate as a metric.

```javascript
// Multiple providers with fallback
const providers = [sendgrid, mailgun, ses];

async function sendEmail(to, subject, body) {
  for (const provider of providers) {
    try {
      const result = await provider.send({ to, subject, body });
      await db.email_log.insert({
        to,
        subject,
        provider: provider.name,
        status: 'sent',
        sent_at: new Date(),
      });
      return result;
    } catch (err) {
      console.error(`Provider ${provider.name} failed:`, err);
      continue; // try the next provider
    }
  }
  throw new Error('All email providers failed');
}
```

---

## Concurrency Hell

## Q25. Two users update the same record at the same time. One overwrites the other.

**Answer:**

This is the classic lost update problem. Three solutions:

Optimistic locking is my default — add a version column and check it on update:

```sql
-- Schema
ALTER TABLE orders ADD COLUMN version INT NOT NULL DEFAULT 0;

-- Update with version check
UPDATE orders 
SET status = 'shipped', version = version + 1
WHERE id = $1 AND version = $2;
-- If 0 rows affected, the version was stale → return conflict to user
```

```javascript
async function updateOrder(id, expectedVersion, updates) {
  const result = await db.query(
    `UPDATE orders 
     SET status = $1, version = version + 1 
     WHERE id = $2 AND version = $3
     RETURNING *`,
    [updates.status, id, expectedVersion]
  );
  
  if (result.rowCount === 0) {
    throw new ConflictError('Order was modified by another user, please refresh');
  }
  return result.rows[0];
}
```

Pessimistic locking with SELECT FOR UPDATE for high-contention scenarios:

```sql
BEGIN;
SELECT * FROM accounts WHERE id = $1 FOR UPDATE;
-- modify based on current state
UPDATE accounts SET balance = balance - 100 WHERE id = $1;
COMMIT;
```

Application-level merge for collaborative editing — show conflict to user, let them resolve, like Google Docs.

Default to optimistic locking. Use pessimistic only when conflicts are frequent.

---

## Q26. A background job ran twice on the same record. Side effects happened twice.

**Answer:**

Idempotency is the answer.

Each operation has an idempotency key. The server checks if the key was processed before. If yes, return the cached result without re-executing.

```javascript
async function processPayment(orderId, idempotencyKey) {
  // Check if already processed
  const existing = await db.idempotency_keys.findOne({ key: idempotencyKey });
  if (existing) return existing.result;
  
  // Process
  const result = await paymentProvider.charge({ orderId });
  
  // Save result
  await db.idempotency_keys.insert({
    key: idempotencyKey,
    result: JSON.stringify(result),
    created_at: new Date(),
  });
  
  return result;
}
```

For background jobs:

```javascript
// Job has unique ID; worker checks before processing
queue.process('charge-customer', async (job) => {
  const { orderId, jobId } = job.data;
  
  // Check if this job was already processed
  const existing = await db.processed_jobs.findOne({ job_id: jobId });
  if (existing) {
    console.log(`Job ${jobId} already processed, skipping`);
    return existing.result;
  }
  
  const result = await chargeCustomer(orderId);
  
  await db.processed_jobs.insert({ 
    job_id: jobId, 
    result: JSON.stringify(result),
  });
  
  return result;
});
```

The unique constraint on job_id ensures even concurrent retries cannot double-process.

---

## Q27. A race condition causes incorrect inventory counts.

**Answer:**

The classic race condition:

```javascript
// Wrong - race condition
const item = await db.inventory.findById(id);
if (item.stock > 0) {
  item.stock -= 1;
  await db.inventory.update(item);
}
// Two concurrent requests can both pass the check and decrement
```

The fix is atomic decrement with a WHERE clause:

```javascript
// Right - atomic decrement
const result = await db.query(
  `UPDATE inventory 
   SET stock = stock - 1 
   WHERE id = $1 AND stock > 0
   RETURNING *`,
  [id]
);
if (result.rowCount === 0) {
  throw new OutOfStockError();
}
```

Or use a database transaction with SELECT FOR UPDATE:

```sql
BEGIN;
SELECT stock FROM inventory WHERE id = $1 FOR UPDATE;
-- check stock in app code
UPDATE inventory SET stock = stock - 1 WHERE id = $1;
COMMIT;
```

The atomic version is preferred because it does not hold a lock during application logic.

---

## Q28. A deadlock keeps happening between two transactions.

**Answer:**

Cause: transaction A holds a lock on row 1 and waits for row 2. Transaction B holds a lock on row 2 and waits for row 1. The database detects the deadlock and aborts one.

Fix:

1. Always acquire locks in the same order (e.g., always update by ID ascending).
2. Reduce transaction scope. Keep transactions short.
3. Use a lower isolation level if business allows.
4. Catch deadlock errors and retry the transaction.

```javascript
// Acquire locks in deterministic order
async function transferMoney(fromId, toId, amount) {
  // Sort IDs to always lock in same order
  const [first, second] = [fromId, toId].sort();
  
  return db.transaction(async (trx) => {
    await trx.query('SELECT * FROM accounts WHERE id IN ($1, $2) ORDER BY id FOR UPDATE', 
      [first, second]);
    
    await trx.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', 
      [amount, fromId]);
    await trx.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', 
      [amount, toId]);
  });
}

// Retry on deadlock
async function withDeadlockRetry(fn, maxAttempts = 3) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      return await fn();
    } catch (e) {
      if (e.code === '40P01' && i < maxAttempts - 1) {
        // Postgres deadlock detected
        await new Promise(r => setTimeout(r, Math.random() * 100));
        continue;
      }
      throw e;
    }
  }
}
```

---

## Money Disasters

## Q29. A bug double-charged customers. What now?

**Answer:**

Critical sequence:

Step one: stop the bleeding. Disable the buggy code path immediately.

Step two: quantify. How many customers, how much money?

Step three: communicate. Be transparent early. "We discovered an issue, we are investigating."

Step four: refund automatically. Do not make customers ask.

Step five: audit. Verify refunds completed for all affected customers.

Step six: prevent recurrence with idempotency keys, audit log of every payment, alerts on duplicate charge patterns, and tests for the duplicate-charge case explicitly.

```javascript
// Idempotency on every charge
app.post('/charge', async (req, res) => {
  const idempotencyKey = req.headers['idempotency-key'];
  if (!idempotencyKey) {
    return res.status(400).json({ error: 'Missing idempotency key' });
  }
  
  // Atomic insert; if already exists, return existing
  try {
    await db.query(
      `INSERT INTO charges (idempotency_key, amount, status) 
       VALUES ($1, $2, 'pending')`,
      [idempotencyKey, req.body.amount]
    );
  } catch (e) {
    if (e.code === '23505') {
      // Unique violation - already processed
      const existing = await db.charges.findOne({ idempotency_key: idempotencyKey });
      return res.json(existing);
    }
    throw e;
  }
  
  // Now process the charge
  const result = await paymentProvider.charge({ 
    amount: req.body.amount,
    idempotency_key: idempotencyKey, // pass to provider too
  });
  
  await db.charges.update(
    { idempotency_key: idempotencyKey },
    { status: 'succeeded', provider_id: result.id }
  );
  
  res.json(result);
});
```

The rule: money operations must be idempotent. Always.

---

## Q30. Sum of all account balances does not match the ledger total. There is $50K missing.

**Answer:**

This is an integrity violation.

Step one: freeze writes to affected accounts if the discrepancy is growing.

Step two: audit the journal. Every transaction should debit one account and credit another (double-entry). The sum should always be zero.

Step three: find the gap. Which transaction broke the rule?

Step four: restore consistency. Correct the books with a tracked adjustment entry, not by editing balances directly.

Step five: prevent. Every financial change must go through a journal_entries table with both sides recorded atomically. Never update balances directly — derive them from journal entries.

```sql
-- Double-entry schema
CREATE TABLE accounts (
  id UUID PRIMARY KEY,
  type VARCHAR(50) NOT NULL,
  user_id UUID,
  currency CHAR(3) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  reference_id VARCHAR(255),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE journal_entries (
  id BIGSERIAL PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES transactions(id),
  account_id UUID NOT NULL REFERENCES accounts(id),
  amount_minor BIGINT NOT NULL, -- positive=debit, negative=credit
  currency CHAR(3) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Reconciliation query: every transaction must sum to zero
SELECT transaction_id, SUM(amount_minor) AS imbalance
FROM journal_entries
GROUP BY transaction_id
HAVING SUM(amount_minor) != 0;
```

```javascript
// Always insert in a transaction, validate sum
async function transferMoney(fromAccount, toAccount, amount, currency) {
  return db.transaction(async (trx) => {
    const txnId = uuid();
    await trx.transactions.insert({ id: txnId, description: 'Transfer' });
    
    await trx.journal_entries.insert([
      { transaction_id: txnId, account_id: fromAccount, amount_minor: -amount, currency },
      { transaction_id: txnId, account_id: toAccount, amount_minor: amount, currency },
    ]);
    
    // Verify the entries sum to zero
    const sum = await trx.query(
      'SELECT SUM(amount_minor) AS total FROM journal_entries WHERE transaction_id = $1',
      [txnId]
    );
    if (sum.rows[0].total !== '0') {
      throw new Error('Journal entries do not sum to zero');
    }
  });
}
```

---

## Q31. Floats were used to store money. Customers are over-or-undercharged by pennies.

**Answer:**

This is the classic floating-point trap.

```javascript
0.1 + 0.2 === 0.3  // false — actually 0.30000000000000004
```

Fix: store money as integer cents (or smallest unit), or use decimal/numeric SQL types.

```javascript
// Wrong - float math
const total = 0.1 + 0.2; // 0.30000000000000004

// Right - integer cents
const total = 10 + 20; // 30 cents

// In Node, use a decimal library for complex math
const Decimal = require('decimal.js');
const total = new Decimal('0.1').plus('0.2').toString(); // '0.3'
```

In PHP, use bcmath or Brick\Math. In Postgres, NUMERIC(19, 4) with strict precision.

Migration plan:

```sql
-- Step 1: add new column
ALTER TABLE invoices ADD COLUMN amount_cents BIGINT;

-- Step 2: backfill from existing floats with rounding
UPDATE invoices SET amount_cents = ROUND(amount * 100);

-- Step 3: switch reads/writes to new column (in app code)

-- Step 4: drop old column after verification
ALTER TABLE invoices DROP COLUMN amount;

-- Step 5: reconcile any errors and refund where needed
```

---

## Q32. We need to refund 1000 customers because of a bug. What is the safest way?

**Answer:**

Step one: identify the exact list with audit trail.

Step two: calculate the exact refund amount per customer. Verify against the original transaction, not your bug calculation.

Step three: test the refund process on one or two internal accounts first.

Step four: run in batches of fifty at a time, with verification.

Step five: reconcile. The total refunded should equal the total over-charged.

Step six: communicate. Send a proactive email to each affected customer.

Step seven: document. Incident report, timeline, what is being done.

```javascript
async function processBatchRefunds(affectedCharges) {
  const BATCH_SIZE = 50;
  const results = { succeeded: [], failed: [] };
  
  for (let i = 0; i < affectedCharges.length; i += BATCH_SIZE) {
    const batch = affectedCharges.slice(i, i + BATCH_SIZE);
    
    for (const charge of batch) {
      try {
        // Verify the original charge matches expected amount
        const original = await paymentProvider.getCharge(charge.provider_id);
        if (original.amount !== charge.expected_refund_amount) {
          results.failed.push({ charge_id: charge.id, reason: 'Amount mismatch' });
          continue;
        }
        
        // Idempotent refund
        const refund = await paymentProvider.refund({
          charge_id: charge.provider_id,
          amount: charge.expected_refund_amount,
          idempotency_key: `refund-${charge.id}`,
          reason: 'duplicate_charge',
        });
        
        await db.refunds.insert({
          charge_id: charge.id,
          provider_refund_id: refund.id,
          amount: charge.expected_refund_amount,
          processed_at: new Date(),
        });
        
        results.succeeded.push(charge.id);
      } catch (err) {
        results.failed.push({ charge_id: charge.id, reason: err.message });
      }
    }
    
    // Small delay between batches
    await new Promise(r => setTimeout(r, 1000));
  }
  
  return results;
}
```

Never bulk-refund 1000 customers in a single command without batching and verification.

---

## Q33. A user is reporting a transaction they did not make. What do you investigate first?

**Answer:**

Step one: verify the transaction in the audit log. Was it actually processed by our system?

Step two: check the source. What IP address, device, and session initiated it? Does it match the user's typical pattern?

Step three: check authentication. Was the user logged in? Was their session valid? Was there an MFA challenge?

Step four: check for fraud signals: unusual amount, unusual location, unusual time of day.

Step five: if confirmed fraudulent, refund immediately, force password reset, end all sessions, and notify the user about steps to secure their account.

```sql
-- Audit query
SELECT 
  t.id, t.amount, t.created_at, t.status,
  s.ip_address, s.user_agent, s.created_at AS session_created,
  l.created_at AS login_time, l.ip_address AS login_ip
FROM transactions t
LEFT JOIN sessions s ON s.id = t.session_id
LEFT JOIN logins l ON l.session_id = t.session_id
WHERE t.id = $1;
```

Prevent: every transaction must have a session ID, IP, user agent. Anomaly detection on transaction patterns. MFA for transactions above a threshold.

---

## Q34. The CDN is serving stale content. Users see old data.

**Answer:**

Step one: identify what is cached and why. Check cache headers — Cache-Control, ETag, Last-Modified.

Step two: purge the affected URLs from the CDN.

Step three: fix the cache strategy if it is wrong:

- Static assets: cache forever with versioned URLs
- API responses: cache briefly with short TTL, or do not cache
- HTML pages: cache with revalidation

```javascript
// Wrong - caching dynamic data with long TTL
app.get('/api/user/me', (req, res) => {
  res.set('Cache-Control', 'public, max-age=86400'); // 1 day on user data!
  res.json(req.currentUser);
});

// Right - no caching for personal data
app.get('/api/user/me', (req, res) => {
  res.set('Cache-Control', 'private, no-cache');
  res.json(req.currentUser);
});

// Right - long cache for versioned assets
app.use('/assets', express.static('public', {
  maxAge: '1y',
  immutable: true,
}));
```

Prevent: explicit cache strategy per endpoint type. Cache key includes user identity for personalized content. Versioned URLs for static assets.

---

## Q35. The on-call alert just woke me up at 3 AM. What is your process?

**Answer:**

Step one: assess severity. Is this user-facing? Is data being lost? Is money flowing incorrectly? Decide P0, P1, or P2.

Step two: communicate. Acknowledge the alert. Post in the incident channel. If P0, page additional engineers.

Step three: triage. Do not start fixing yet. Look at dashboards. What changed in the last hour? Last deploy?

Step four: mitigate. Bias toward reversible action. Rollback, feature flag off, throttle, etc.

Step five: diagnose in parallel. Logs, metrics, traces. Talk to whoever deployed last.

Step six: resolve once you understand. Test the fix in staging if possible. Deploy with verification. Monitor.

Step seven: post-mortem within a week. Blameless write-up. Timeline. Root cause. Action items with owners.

The senior signal: I do not just fix things. I walk through these phases visibly. Other engineers can join in at any phase.

---

## Q36. The status page is being overwhelmed by user complaints during an incident.

**Answer:**

Step one: post a clear status update right away. Even "We are aware of an issue and investigating" is better than silence.

Step two: update every fifteen minutes during an active incident, even if there is nothing new. Silence makes users panic.

Step three: route customer support. Brief them on what is happening so they can answer consistently.

Step four: consider proactive email or banner if the impact is large.

Step five: post-incident, write a clear summary of what happened, what was affected, what was fixed, and what we are doing to prevent recurrence.

```
Status update template:

[Investigating] Some users may be experiencing slow response times on the dashboard.
We are investigating the cause. Updates every 15 minutes.
Posted: 14:32 UTC

[Identified] We have identified the cause as database connection saturation.
Mitigation in progress. Expected resolution: 15:00 UTC.
Posted: 14:47 UTC

[Resolved] The issue has been resolved. All services are operating normally.
A full post-mortem will be published within 48 hours.
Posted: 14:58 UTC
```

---

## Q37. We just realized our monitoring did not catch a critical issue.

**Answer:**

Step one: own the gap. Do not get defensive.

Step two: write down what was missed. Was it a missing alert, a wrong threshold, or a metric we were not collecting?

Step three: add the missing alerts immediately.

Step four: write a post-mortem with a specific section on monitoring gaps.

Step five: review monitoring quarterly going forward — every six months at minimum.

```javascript
// Common gap: we monitor errors but not silent failures

// Wrong - only catches thrown exceptions
app.get('/api/data', async (req, res) => {
  try {
    const data = await fetchData();
    res.json(data);
  } catch (err) {
    metrics.increment('api.error');
    res.status(500).json({ error: err.message });
  }
});

// Right - also monitor for empty results, slow responses, business metrics
app.get('/api/data', async (req, res) => {
  const start = Date.now();
  try {
    const data = await fetchData();
    
    metrics.timing('api.duration', Date.now() - start);
    metrics.gauge('api.result_count', data.length);
    
    if (data.length === 0) {
      metrics.increment('api.empty_result'); // alert if this spikes
    }
    
    res.json(data);
  } catch (err) {
    metrics.increment('api.error');
    res.status(500).json({ error: err.message });
  }
});
```

The principle: monitor what matters to users, not just what your code throws.

---

## Q38. A senior engineer pushed a hotfix without review during an incident. It made things worse.

**Answer:**

Step one: rollback the hotfix.

Step two: do not blame the engineer in the moment. Incidents are stressful, and pressure leads to mistakes.

Step three: in the post-mortem, address the process: under what circumstances can someone push without review? Should there be a hot-line peer review even during incidents?

Step four: codify a rule: even during incidents, all production changes need a second pair of eyes — even just a thirty-second screen-share. Most fixes are not that urgent.

The senior signal in the post-mortem: focus on the process, not the person. Anyone can make a mistake under pressure. The fix is to make the system safer, not to punish.

---

## Q39. We are losing money every minute the bug is in production. The fix is risky.

**Answer:**

The trade-off is between cost of inaction and cost of action.

Step one: quantify both. How much are we losing per minute? What is the worst case if the fix breaks something else?

Step two: deploy the fix behind a feature flag if possible, so we can disable it instantly.

Step three: deploy to a small percentage of traffic first if possible (canary).

Step four: have a rollback plan ready. Test the rollback in staging.

Step five: deploy with a war room — at least one other engineer watching dashboards in real time.

Step six: communicate at every step.

```javascript
// Feature flag pattern for risky fixes
const CRITICAL_FIX_ENABLED = process.env.CRITICAL_FIX === 'true';
const CANARY_PERCENT = parseInt(process.env.CANARY_PERCENT || '0');

app.post('/critical-endpoint', async (req, res) => {
  // Roll out to canary percentage of users
  const useFix = CRITICAL_FIX_ENABLED && (
    Math.random() * 100 < CANARY_PERCENT
  );
  
  if (useFix) {
    return newImplementation(req, res);
  }
  return oldImplementation(req, res);
});
```

The principle: when both options are bad, pick the reversible one. Deploy with feature flags. Monitor closely. Be ready to rollback in seconds.

---

## Q40. Walk me through your post-mortem process.

**Answer:**

A blameless post-mortem within a week. The format I use:

```
Title: Brief description of incident

Date and Duration:
- Started: 2024-01-15 14:32 UTC
- Detected: 2024-01-15 14:45 UTC (13 min)
- Mitigated: 2024-01-15 15:10 UTC (38 min)
- Resolved: 2024-01-15 16:00 UTC (88 min)

Impact:
- Approximately 5% of users affected
- 200 failed transactions
- $X estimated revenue impact

Timeline:
14:32 - Database connection pool saturated
14:45 - First alert fired
14:47 - On-call engineer began investigation
14:52 - Identified root cause: long-running query holding connections
15:00 - Mitigation: killed the query, scaled connection pool
15:10 - Service returned to baseline
16:00 - Root cause fix deployed (added query timeout)

Root Cause:
A new feature deployed at 14:00 included a query without a timeout. 
Under load, several copies of this query held connections for several 
minutes, exhausting the pool.

Contributing Factors:
- No automatic timeout on database queries
- No alert on connection pool utilization
- Code review did not catch the missing timeout

What Went Well:
- Fast detection (13 min from start to alert)
- Clear escalation path
- Status page updated promptly

What Did Not Go Well:
- Took 7 minutes to identify the root cause
- No connection pool dashboard existed

Action Items:
- [ ] Add default query timeout (Owner: Alice, Due: this week)
- [ ] Add connection pool utilization alert (Owner: Bob, Due: this week)
- [ ] Code review checklist: verify queries have timeouts (Owner: Carol, Due: next sprint)
- [ ] Build a connection pool dashboard (Owner: Dave, Due: next sprint)
```

The post-mortem is blameless. Focus on what the system or process failed to catch, not who made the mistake. Fix the system so anyone could make the same mistake without causing the incident.

---

## Final Note

For any "what if X breaks?" question, hit these notes:

1. Acknowledge the user impact. "Users cannot do X."
2. Stop the bleeding with short-term mitigation.
3. Do not guess. Gather data first.
4. Communicate internally and externally.
5. Find the root cause, not just the symptom.
6. Prevent recurrence with tests, monitors, and process changes.

If you cover all six and ground your answer in concrete code or queries, you sound like a senior engineer.
