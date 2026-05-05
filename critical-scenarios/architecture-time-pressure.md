# Architecture Under Time Pressure

**Purpose:** Direct, ready-to-say answers for "we do not have time for architecture" scenarios. Each question gets a concrete answer, with code examples for technical decisions.

---

## Q1. We do not have much time for architecture. What do you do?

**Answer:**

When time is short, I do not skip architecture — I shrink it. I focus on three things only: the data model, the trust boundary (authentication and authorization), and the irreversible decisions like API contracts and money flows. Everything else I treat as code I can refactor later.

The risk is not "no architecture." The risk is making one decision now that I cannot undo cheaply later. So my time goes to those decisions only. After that, I write the simplest working version, ship it, and iterate.

In practice, this looks like:

```
Time spent before coding (10 minutes total):
- Data model and key relationships: 3-4 minutes
- Auth model (who can do what): 1-2 minutes
- Critical API surface (3-5 endpoints): 2-3 minutes
- Failure modes (3 worst cases): 1-2 minutes
- What I will defer: 1 minute
```

That is the architecture. Everything else is code.

---

## Q2. You are spending too much time designing. What would a senior engineer do?

**Answer:**

A senior engineer protects irreversible decisions and treats everything else as cheap. So I would lock down the schema and the auth boundary, then write the simplest version that works. I would not draw diagrams for things I can refactor in an hour. Architecture is not the artifact — it is the small set of decisions I cannot easily change later.

Specifically, I would say something like: "Give me sixty seconds to confirm the data model and auth, then I move to code."

---

## Q3. Skip the architecture, just give me the code.

**Answer:**

I will start coding. Two quick assumptions I will make explicit so you can correct them if needed: I will use users → orders → order_items as the schema, and I will authenticate with JWT in the Authorization header. If those are wrong, the rework cost is high, so I want to surface them now. Otherwise I move forward.

The technique here is to name your assumptions out loud, even while coding. That way the interviewer can catch a mistake before it becomes expensive.

---

## Q4. We are in startup mode, no time for over-engineering.

**Answer:**

Agreed. Over-engineering is the enemy. My rule is to build the simplest thing that handles today's load and one obvious near-term change. No abstraction without two real use cases. No microservices, no event buses, no premature caching. Just modular code, clean boundaries between business logic and I/O, and tests around the money paths. That is enough.

For example, for a typical CRUD module, I would write:

```javascript
// Three layers, three DTOs, no extras
// repository.js
const userRepo = {
  findById: (id) => db.users.findOne({ id }),
  create: (data) => db.users.insert(data),
  update: (id, data) => db.users.update({ id }, data),
};

// service.js
const userService = {
  async createUser(input) {
    validate(input);
    return userRepo.create(input);
  },
};

// controller.js
app.post('/users', async (req, res) => {
  const user = await userService.createUser(req.body);
  res.json(user);
});
```

No caching layer, no soft delete, no audit trail unless the business explicitly needs them.

---

## Q5. How would you balance design and delivery?

**Answer:**

I think in three buckets: irreversible, expensive-to-change, and free-to-change.

Irreversible decisions get design time — schemas with live data, public API contracts, security model, money flows, vendor lock-in.

Expensive-to-change decisions get a short discussion — query patterns, framework choice, file storage paths.

Everything else I write fast and refactor when it hurts.

The trap is treating reversible decisions like irreversible ones. That is where weeks get burned on architecture for things that do not matter.

---

## Q6. Build a payment integration in two hours. Go.

**Answer:**

Before I write code, I lock three things in two minutes each.

First, idempotency strategy. What happens if the same charge request hits twice? I need an idempotency key on every charge.

Second, money type. I will store money as integer cents, never float.

Third, transaction boundary. When exactly do we mark an order as paid?

Then I code:

```javascript
async function charge(req, res) {
  const idempotencyKey = req.headers['idempotency-key'];
  if (!idempotencyKey) return res.status(400).json({ error: 'Missing idempotency key' });

  // Check if this key was processed before
  const existing = await db.charges.findOne({ idempotency_key: idempotencyKey });
  if (existing) return res.json(existing);

  const amountCents = Math.round(req.body.amount * 100); // never float math
  
  const trx = await db.transaction();
  try {
    // Reserve the slot first
    const charge = await trx.charges.insert({
      idempotency_key: idempotencyKey,
      amount_cents: amountCents,
      currency: req.body.currency,
      status: 'pending',
    });
    
    const result = await paymentProvider.charge({
      amount: amountCents,
      currency: req.body.currency,
      reference: idempotencyKey,
    });
    
    await trx.charges.update({ id: charge.id }, {
      status: 'succeeded',
      provider_id: result.id,
    });
    
    await trx.commit();
    res.json(charge);
  } catch (e) {
    await trx.rollback();
    res.status(500).json({ error: e.message });
  }
}
```

These three decisions cause real bugs and refactoring is painful. After I lock them, the integration is mechanical.

---

## Q7. Quick MVP feature in one hour, multi-user. Go.

**Answer:**

Multi-user means tenant isolation is the silent killer. Before I touch features, I set up the current_user context so every query filters by it. Otherwise I will spend the last ten minutes hunting cross-tenant data leaks.

```javascript
// Middleware to attach current user
app.use(async (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  
  const user = await verifyToken(token);
  if (!user) return res.status(401).json({ error: 'Invalid token' });
  
  req.currentUser = user;
  next();
});

// Every query filters by current user
app.get('/items', async (req, res) => {
  const items = await db.items.find({ user_id: req.currentUser.id });
  res.json(items);
});

app.get('/items/:id', async (req, res) => {
  const item = await db.items.findOne({ 
    id: req.params.id, 
    user_id: req.currentUser.id, // ownership check
  });
  if (!item) return res.status(404).json({ error: 'Not found' });
  res.json(item);
});
```

Defining `current_user` and the data ownership rule first is my one design moment. Everything else is feature code.

---

## Q8. Add a search feature. Fast.

**Answer:**

I will not reach for Elasticsearch yet. Postgres LIKE with a trigram index covers most use cases below the millions of rows. I move to full-text or external search only when query times prove it is needed. Premature search infrastructure is a classic time-sink.

```sql
-- Enable trigram extension once
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Index for fast LIKE searches
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);

-- Query
SELECT * FROM products 
WHERE name ILIKE '%' || $1 || '%' 
ORDER BY similarity(name, $1) DESC 
LIMIT 20;
```

If usage data shows this is too slow, then I add Postgres full-text search:

```sql
ALTER TABLE products ADD COLUMN search_vector tsvector;
UPDATE products SET search_vector = to_tsvector('english', name || ' ' || description);
CREATE INDEX idx_products_search ON products USING gin(search_vector);

-- Query
SELECT * FROM products 
WHERE search_vector @@ plainto_tsquery('english', $1)
LIMIT 20;
```

Only after both of those have been measured and ruled out would I move to Elasticsearch.

---

## Q9. Set up a CRUD module fast.

**Answer:**

Three layers, three DTOs, no extras. Caching, soft delete, and audit logs are valid concerns, but only when there is a real reason. I would rather add them when needed than carry the weight from day one.

```javascript
// dto.js
const createDto = (body) => ({
  name: body.name,
  email: body.email,
});

const updateDto = (body) => ({
  name: body.name,
});

const responseDto = (entity) => ({
  id: entity.id,
  name: entity.name,
  email: entity.email,
  created_at: entity.created_at,
});

// repository.js
const repo = {
  findAll: () => db.users.find(),
  findById: (id) => db.users.findOne({ id }),
  create: (data) => db.users.insert(data),
  update: (id, data) => db.users.update({ id }, data),
  delete: (id) => db.users.delete({ id }),
};

// service.js
const service = {
  async list() { return repo.findAll(); },
  async get(id) {
    const user = await repo.findById(id);
    if (!user) throw new NotFoundError();
    return user;
  },
  async create(input) {
    validate(input);
    return repo.create(input);
  },
};

// controller.js
app.get('/users', async (req, res) => {
  const users = await service.list();
  res.json(users.map(responseDto));
});
```

Done in twenty minutes. Refactor when patterns emerge.

---

## Q10. How do you decide what to skip when time is tight?

**Answer:**

I check three lists.

What is irreversible? Database schema with live data, public API contracts, authentication and authorization model, file storage paths, money and financial logic, vendor lock-in. These need design time. Always.

What is reversible? Internal class structure, file and folder organization, library choices that have alternatives, UI layout, helper utilities, naming inside the code. These can be refactored. Skip the design meeting.

What can go wrong silently? Money rounding, concurrent updates, authentication holes, unbounded queries, missing indexes, unhandled async errors, time zones. These need a checklist, not a design document.

I spend my limited time on the irreversible items and the silent-failure items. Reversible items I write fast.

---

## Q11. Build a feature with a deadline tomorrow. The customer is breathing down our neck.

**Answer:**

I cut scope first, then code. Specifically:

I list what the customer actually needs versus what they are asking for. There is usually a thirty to fifty percent reduction available without losing core value.

I lock in the irreversible parts in the first twenty minutes: data model, auth, money handling if any. I get those wrong and I am rewriting tomorrow under more pressure.

I write the simplest working version. No fancy abstractions. No premature optimization. One pattern repeated consistently.

I deploy behind a feature flag so I can disable it if it breaks in production.

```javascript
// Feature flag pattern
const FEATURE_FLAGS = {
  newFeature: process.env.FEATURE_NEW === 'true',
};

app.get('/api/new-thing', async (req, res) => {
  if (!FEATURE_FLAGS.newFeature) {
    return res.status(404).json({ error: 'Not available' });
  }
  // feature code
});
```

I tell the customer exactly what is shipping and what is not. They prefer honest scope cuts to silent slips.

---

## Q12. We need to scale this to ten times traffic next month. What do you do first?

**Answer:**

I do not refactor for theoretical scale. I measure first.

Step one: profile the current system. Find the actual bottlenecks. Usually one or two endpoints dominate the load.

Step two: fix the obvious wins. Missing indexes, N+1 queries, unbounded result sets, synchronous calls that should be async.

```sql
-- Find slow queries (Postgres)
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;

-- Find missing indexes (Postgres)
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE schemaname = 'public'
ORDER BY n_distinct DESC;
```

Step three: add caching where it makes sense. Cache static lookups, slow computed values, and read-heavy endpoints. Use Redis or memcached, not in-memory if you have multiple servers.

```javascript
async function getProduct(id) {
  const cached = await redis.get(`product:${id}`);
  if (cached) return JSON.parse(cached);
  
  const product = await db.products.findOne({ id });
  await redis.setex(`product:${id}`, 300, JSON.stringify(product)); // 5 min TTL
  return product;
}
```

Step four: scale horizontally if the database is the bottleneck. Read replicas for read-heavy endpoints. Connection pooling tuned to actual concurrency.

I do not jump to Kafka, Kubernetes, or microservices unless data shows we need them. Most ten-times scaling is achieved with database tuning and caching.

---

## Q13. What architectural shortcuts are dangerous to take?

**Answer:**

Some shortcuts save time. Others create lasting damage. Here is the line I draw.

Smart shortcuts I will take:
- Use a single table where two would be ideal but the migration is reversible
- Skip an in-memory cache layer initially
- Use simple sessions instead of JWT until I need stateless auth
- Hardcode config values I will move later
- Skip retries until I see real failures
- Combine controller and service layer in early code, split later

Dangerous shortcuts I will never take:
- Storing passwords in plain text "for now"
- Disabling SSL in any environment that touches real data
- String concatenation for SQL queries (use parameterized queries)
- Storing money as floats
- Skipping database transactions on multi-step operations
- Trusting client-supplied user IDs
- Letting one user's data leak into another's

```javascript
// Wrong - SQL injection
const user = await db.query(`SELECT * FROM users WHERE email = '${email}'`);

// Right - parameterized
const user = await db.query('SELECT * FROM users WHERE email = $1', [email]);

// Wrong - float money
const total = price * quantity;

// Right - integer cents
const totalCents = Math.round(priceCents * quantity);

// Wrong - trusting client
app.get('/orders/:id', async (req, res) => {
  const order = await db.orders.findOne({ id: req.params.id });
  res.json(order); // anyone can read any order
});

// Right - server-side ownership check
app.get('/orders/:id', async (req, res) => {
  const order = await db.orders.findOne({ 
    id: req.params.id, 
    user_id: req.currentUser.id, 
  });
  if (!order) return res.status(404).json({ error: 'Not found' });
  res.json(order);
});
```

Speed comes from simpler code, not from skipping safety.

---

## Q14. The interviewer says "just hardcode the user ID for now."

**Answer:**

I would push back, gently and with the cost. "Skipping authentication means I will need to refactor every endpoint when we add real users. That is a one-day rework. Adding a current_user context now is fifteen minutes." I would propose a minimal stub:

```javascript
// Minimal auth that we can replace later
app.use((req, res, next) => {
  // For now, accept user ID in a header
  const userId = req.headers['x-user-id'];
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  req.currentUser = { id: userId };
  next();
});
```

This gives us a real `req.currentUser` everywhere. Later, swapping the header check for JWT is a five-line change in one place. I never want to grep for hardcoded user IDs across a codebase.

---

## Q15. The interviewer says "we will add validation later."

**Answer:**

I would say: "Validation at the boundary is non-negotiable. It is fifteen lines of code. Adding it later means I have to audit every code path that already trusts the input."

The pattern is to validate at the entry point, then trust the data inside.

```javascript
const { z } = require('zod');

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).max(150),
});

app.post('/users', async (req, res) => {
  const result = createUserSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({ errors: result.error.issues });
  }
  
  // Inside the function, we trust the data
  const user = await userService.create(result.data);
  res.json(user);
});
```

Validation is not optional. It is the contract between the outside world and your code.

---

## Q16. How do you communicate trade-offs to a non-technical interviewer or PM?

**Answer:**

I use four patterns.

Pattern one — "I am protecting against X." Whenever I spend time on something, I name the specific risk. "I am spending two minutes on the schema because once we have production data, ALTER TABLE on a million rows is a four-hour migration."

Pattern two — "I will handle that in code." For things I am skipping. "Logging strategy and helper utilities I will handle in code. They are cheap to refactor."

Pattern three — "Two assumptions I am making." When I am moving forward without confirmation. "Two assumptions: payments are processed asynchronously via webhook, and refunds are a separate flow. If those do not match, the design needs to change."

Pattern four — "What would change my answer?" When I am not sure. "My current design assumes single-region deployment. If we need multi-region with sub-100ms latency, I would add a different layer. Is single-region okay?"

This makes me look thoughtful, not indecisive.

---

## Q17. What if you realize halfway through coding that your initial design was wrong?

**Answer:**

I stop and assess, but I do not panic.

I ask: is the wrong decision irreversible at this point, or can I refactor cheaply? If reversible, I keep coding and refactor at the end. If irreversible — say I picked the wrong primary key type — I stop and fix it now, because the cost grows fast.

```javascript
// Example: realized I should have used UUIDs not auto-increment IDs
// because we will have multiple data sources

// Wrong - already coded with integer IDs
CREATE TABLE orders (id SERIAL PRIMARY KEY, ...);

// Right - switch to UUID before adding more code
CREATE TABLE orders (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), ...);
```

I tell the interviewer what I noticed, what the trade-off is, and what I am doing about it. That demonstrates the senior signal: catching your own mistakes early and adjusting without ego.

---

## Q18. What do you do if you have already spent too long on architecture?

**Answer:**

I acknowledge it and pivot. I would say: "I notice I have been in design longer than needed. Let me lock in the data model and auth — those two only — and start coding. I will refine the rest as I go."

Then I time-box myself: "Give me ninety seconds to confirm the schema, then I move to code."

If the interviewer is still impatient, I convert design questions into clarifying questions: "Rather than design more, let me ask three quick questions: what is the expected concurrent user count, do we need real-time updates, and is this customer-facing or internal? Answers from you save me from designing for the wrong assumptions."

---

## Q19. Walk me through how you would design a URL shortener under time pressure.

**Answer:**

Five-minute design before coding.

Data model:
```sql
CREATE TABLE links (
  short_code VARCHAR(10) PRIMARY KEY,
  long_url TEXT NOT NULL,
  user_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  click_count BIGINT DEFAULT 0
);
CREATE INDEX idx_links_user ON links(user_id);
```

API surface:
- POST /shorten — input: long URL, output: short code
- GET /:code — redirect to long URL, increment counter

Two key decisions: 
- Short code generation. I use a base62 hash of an auto-incrementing counter, or random short codes with collision check.
- Click counting. Atomic increment, async to avoid blocking the redirect.

Code:

```javascript
const ALPHABET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

function generateShortCode(length = 7) {
  let code = '';
  for (let i = 0; i < length; i++) {
    code += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  }
  return code;
}

app.post('/shorten', async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: 'URL required' });
  
  // Try a few times in case of collision
  for (let i = 0; i < 5; i++) {
    const code = generateShortCode();
    try {
      await db.links.insert({
        short_code: code,
        long_url: url,
        user_id: req.currentUser?.id,
      });
      return res.json({ short_code: code });
    } catch (e) {
      if (e.code === '23505') continue; // unique violation, retry
      throw e;
    }
  }
  res.status(500).json({ error: 'Failed to generate code' });
});

app.get('/:code', async (req, res) => {
  const link = await db.links.findOne({ short_code: req.params.code });
  if (!link) return res.status(404).send('Not found');
  
  // Async increment, do not block redirect
  db.query('UPDATE links SET click_count = click_count + 1 WHERE short_code = $1', [req.params.code])
    .catch(err => console.error('Counter update failed:', err));
  
  res.redirect(301, link.long_url);
});
```

Skipped: caching (add when traffic grows), analytics (add when product asks), custom codes (add when feature requested).

---

## Q20. Final question: what is the biggest mistake engineers make under time pressure?

**Answer:**

The biggest mistake is treating reversible decisions like irreversible ones. Engineers spend hours debating file structure, naming conventions, or which library to use, when those choices can be changed in an afternoon. Meanwhile, they rush past the schema design, the auth model, and the money handling — the decisions that cost weeks to fix.

The reverse mistake is also bad: skipping all design and treating everything as reversible. That is how you end up with passwords in plaintext and SQL injection in production.

The right answer is proportional architecture. High-risk decisions get design time. Low-risk decisions get code time. Most decisions are low-risk. The senior skill is knowing which is which, fast.
