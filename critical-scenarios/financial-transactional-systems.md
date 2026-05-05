# Financial and Transactional Systems

**Purpose:** Direct, ready-to-say answers for money-handling and transaction questions. Each question has a clear answer plus code examples for the implementation. Bugs in financial code are unforgivable, so this material is meant to be memorized and applied.

---

## Money Representation

## Q1. How should money be represented in code and storage?

**Answer:**

Three rules.

Rule one: never use float. Floats lose precision in arithmetic. `0.1 + 0.2` does not equal `0.3` in any language that uses IEEE 754 floats.

Rule two: store as integer minor units (cents, paise) or use a decimal type. In Postgres, `NUMERIC(19, 4)` is the standard.

Rule three: always store the currency alongside the amount. Money without a currency is meaningless.

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  amount_minor BIGINT NOT NULL,    -- amount in minor units (cents, paise)
  currency CHAR(3) NOT NULL,       -- ISO 4217 (USD, EUR, BDT)
  created_at TIMESTAMPTZ DEFAULT now()
);
```

In code, I use a decimal library when arithmetic gets complex.

```javascript
// Wrong - float
const total = 0.1 + 0.2; // 0.30000000000000004

// Right - integer cents
const total = 10 + 20; // 30 cents

// Right - decimal library for complex arithmetic
const Decimal = require('decimal.js');
const tax = new Decimal('99.99').times('0.0825').toFixed(2); // '8.25'
```

In PHP, use bcmath or Brick\Math. In Java, BigDecimal. In Python, the decimal module.

---

## Q2. Why is using float for money so dangerous?

**Answer:**

Floats are stored in IEEE 754 binary format, which cannot exactly represent decimal fractions like 0.1 or 0.2. Arithmetic accumulates tiny errors.

```javascript
// Real example
0.1 + 0.2 === 0.3        // false
0.1 + 0.2                // 0.30000000000000004

// In a billing system
let total = 0;
for (let i = 0; i < 10; i++) total += 0.1;
console.log(total);      // 0.9999999999999999, not 1
```

Over thousands of transactions, these errors accumulate. Customers get charged a few pennies off. Accounting reconciliation breaks. Audit trails do not balance. The fix is always: use integer cents or a decimal type.

---

## Q3. Display vs storage — what is the rule?

**Answer:**

Store as canonical units, display as formatted strings.

I store $123.45 as the integer 12345 (cents). I display it by dividing by 100 with proper formatting at the boundary, never inside arithmetic.

```javascript
function formatAmount(amountMinor, currency) {
  const formatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
  });
  return formatter.format(amountMinor / 100);
}

formatAmount(12345, 'USD'); // "$123.45"
```

Never round during arithmetic. Only at display.

---

## Q4. How do you handle multi-currency systems?

**Answer:**

Store the original amount and currency, plus optionally a converted amount in a base currency for reporting. Critically, store the exchange rate that was used at the time of the transaction.

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  amount_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL,
  -- For multi-currency reporting:
  base_amount_minor BIGINT,
  base_currency CHAR(3),
  exchange_rate NUMERIC(19, 8),
  exchange_rate_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

The reason: reports must use the historical rate, not today's rate. Otherwise, last month's totals change every day, which is wrong for accounting.

---

## ACID and Transactions

## Q5. What does ACID stand for, and why does it matter for money?

**Answer:**

ACID is a set of guarantees a database transaction provides.

Atomicity: all operations in a transaction succeed or none do.

Consistency: the database transitions from one valid state to another.

Isolation: concurrent transactions do not see each other's intermediate state.

Durability: once committed, the change survives crashes.

Why this matters for money: a transfer of $100 from account A to account B is two operations — debit A, credit B. Without atomicity, you can crash between them and create money out of thin air or destroy it. ACID is what prevents that.

---

## Q6. Show me a safe money transfer using a transaction.

**Answer:**

There are two safe patterns: pessimistic locking and optimistic locking with a balance check.

Pessimistic locking with SELECT FOR UPDATE:

```sql
BEGIN;

  -- Lock both rows in deterministic order to avoid deadlock
  SELECT * FROM accounts WHERE id IN ('A', 'B') 
  ORDER BY id FOR UPDATE;

  -- Verify A has balance (in app code: balance >= amount)

  UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
  UPDATE accounts SET balance = balance + 100 WHERE id = 'B';

  INSERT INTO transfers (from_id, to_id, amount, created_at)
  VALUES ('A', 'B', 100, now());

COMMIT;
```

Optimistic with balance check inline:

```sql
BEGIN;

  UPDATE accounts SET balance = balance - 100 
  WHERE id = 'A' AND balance >= 100;
  -- Check rows affected = 1, otherwise insufficient funds → ROLLBACK

  UPDATE accounts SET balance = balance + 100 WHERE id = 'B';

  INSERT INTO transfers (from_id, to_id, amount) 
  VALUES ('A', 'B', 100);

COMMIT;
```

The second pattern is faster because it does not need a SELECT FOR UPDATE, but the WHERE clause is the safety check.

In application code:

```javascript
async function transferMoney(fromId, toId, amount) {
  return db.transaction(async (trx) => {
    // Sort to lock in deterministic order
    const [first, second] = [fromId, toId].sort();
    
    await trx.query(
      'SELECT id FROM accounts WHERE id IN ($1, $2) ORDER BY id FOR UPDATE',
      [first, second]
    );
    
    const debitResult = await trx.query(
      'UPDATE accounts SET balance = balance - $1 WHERE id = $2 AND balance >= $1',
      [amount, fromId]
    );
    if (debitResult.rowCount === 0) {
      throw new Error('Insufficient funds');
    }
    
    await trx.query(
      'UPDATE accounts SET balance = balance + $1 WHERE id = $2',
      [amount, toId]
    );
    
    await trx.query(
      'INSERT INTO transfers (from_id, to_id, amount) VALUES ($1, $2, $3)',
      [fromId, toId, amount]
    );
  });
}
```

---

## Q7. When does a transaction NOT save you?

**Answer:**

Transactions are powerful but they have boundaries.

Network calls inside the transaction: if you call an external API mid-transaction, the API call may have succeeded but your database rolled back. Now they are out of sync. The fix is to not call external APIs from inside a transaction. Save state first, commit, then make the external call.

Multiple databases: a single database transaction does not span two different databases. For that, you need patterns like saga or two-phase commit.

Background jobs: queueing a job inside a transaction means the job may run before the commit completes (or never run if you rollback). The outbox pattern fixes this.

```javascript
// Wrong - external API inside transaction
await db.transaction(async (trx) => {
  await trx.orders.insert(order);
  await stripe.charges.create({ amount, source }); // bad
  await trx.orders.update({ id: order.id }, { status: 'paid' });
});

// Right - external call outside transaction
const order = await db.transaction(async (trx) => {
  return trx.orders.insert({ ...order, status: 'pending_payment' });
});

const charge = await stripe.charges.create({ amount, source });

await db.orders.update({ id: order.id }, { 
  status: 'paid', 
  charge_id: charge.id,
});
```

---

## Isolation Levels

## Q8. What are the four isolation levels?

**Answer:**

Read Uncommitted: allows dirty reads. Almost never used.

Read Committed: prevents dirty reads but allows non-repeatable reads. The default in Postgres.

Repeatable Read: prevents dirty reads and non-repeatable reads. Postgres also prevents phantom reads at this level via MVCC.

Serializable: prevents all anomalies. Highest correctness, slowest, highest abort rate.

```
Anomaly Types:

Dirty read: read uncommitted data from another transaction
Non-repeatable read: same SELECT returns different values within one transaction
Phantom read: same SELECT returns different rows within one transaction
Lost update: two transactions read the same row, both update, second overwrites the first
```

---

## Q9. What isolation level should I use for a money transfer?

**Answer:**

Read Committed is usually enough if I use one of these protective patterns:

- SELECT FOR UPDATE (pessimistic lock) on accounts
- Atomic UPDATE with a conditional WHERE clause
- Version-based optimistic locking

Serializable is safest but has higher abort rate. I use it when:

- Complex multi-row business rules
- Reports that need a consistent snapshot
- When correctness matters more than throughput

For a typical money transfer at Read Committed:

```sql
BEGIN;
SELECT * FROM accounts WHERE id = 'A' FOR UPDATE;
SELECT * FROM accounts WHERE id = 'B' FOR UPDATE;
-- update logic
COMMIT;
```

---

## Idempotency

## Q10. Why is idempotency mandatory in payment systems?

**Answer:**

Networks fail. Clients retry. Without idempotency, a retry equals a double charge.

The contract: the client generates a unique idempotency key for each operation. The server stores the result keyed by that ID. If the same key is sent again, the server returns the original result without re-executing.

```http
POST /api/payments
Idempotency-Key: 7f8e1d2c-3b4a-5c6d-7e8f-9a0b1c2d3e4f

{ "amount": 5000, "currency": "USD", "to": "merchant_123" }
```

Server side:

```javascript
async function charge(req) {
  const key = req.headers['idempotency-key'];
  if (!key) throw new Error('Missing idempotency key');
  
  // Check if already processed
  const existing = await db.idempotency_keys.findOne({ key });
  if (existing) return existing.response;
  
  // Process the charge
  const result = await paymentProvider.charge(req.body);
  
  // Save the result
  await db.idempotency_keys.insert({ 
    key, 
    response: JSON.stringify(result),
    created_at: new Date(),
  });
  
  return result;
}
```

But this naive version has a race condition.

---

## Q11. How do you handle idempotency under high concurrency?

**Answer:**

The naive check-then-insert has a race window. Two concurrent requests with the same key can both pass the existence check and both process the charge. The fix is to use a unique constraint and let the database arbitrate.

```sql
CREATE TABLE idempotency_keys (
  key VARCHAR(255) PRIMARY KEY,
  response JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

```javascript
async function charge(req) {
  const key = req.headers['idempotency-key'];
  
  // Try to insert a placeholder first
  try {
    await db.query(
      `INSERT INTO idempotency_keys (key, response, status) 
       VALUES ($1, '{}', 'pending')`,
      [key]
    );
  } catch (e) {
    if (e.code === '23505') { // unique violation
      // Another request is processing or done
      const existing = await db.idempotency_keys.findOne({ key });
      if (existing.status === 'pending') {
        // Wait briefly, then return current state
        await new Promise(r => setTimeout(r, 200));
        return db.idempotency_keys.findOne({ key }).then(r => r.response);
      }
      return existing.response;
    }
    throw e;
  }
  
  // We won the race; do the work
  const result = await paymentProvider.charge(req.body);
  
  await db.idempotency_keys.update(
    { key },
    { response: JSON.stringify(result), status: 'succeeded' }
  );
  
  return result;
}
```

The unique constraint on the key acts as a lock — only one transaction wins.

---

## Q12. What if the payment provider is non-idempotent?

**Answer:**

I wrap the provider with my own idempotency layer. Even if the provider does not deduplicate, I do.

```javascript
async function chargeWithIdempotency(amount, key) {
  // Check if we have already processed this
  const existing = await db.charges.findOne({ idempotency_key: key });
  if (existing?.provider_id) return existing;
  
  // Reserve the slot atomically
  await db.charges.upsert({
    idempotency_key: key,
    status: 'in_progress',
  });
  
  try {
    // Pass our key to provider as their reference if they support it
    const providerResult = await provider.charge({ 
      amount, 
      reference: key, // even if not idempotency, reduces dup risk
    });
    
    await db.charges.update(
      { idempotency_key: key },
      {
        status: 'succeeded',
        provider_id: providerResult.id,
      }
    );
    
    return providerResult;
  } catch (e) {
    await db.charges.update(
      { idempotency_key: key },
      { status: 'failed', error: e.message }
    );
    throw e;
  }
}
```

This way, even if the provider would happily charge twice, our wrapper prevents it.

---

## Double-Entry Bookkeeping

## Q13. What is double-entry bookkeeping?

**Answer:**

Every financial transaction has two equal and opposite entries: a debit on one account and a credit on another. The sum is always zero.

Example: User pays $100 cash to the platform.

| Account | Amount |
|---------|--------|
| User wallet | -$100 |
| Platform cash | +$100 |
| **Sum** | **$0** |

This is a centuries-old accounting principle, and it is still the gold standard for software.

---

## Q14. Why double-entry instead of just updating balances?

**Answer:**

Direct balance updates are error-prone. Double-entry gives you four advantages:

| Single-entry (update balance) | Double-entry (append journal entries) |
|-------------------------------|----------------------------------------|
| Update balance directly | Append journal entries |
| No history | Full audit trail |
| Cannot reconcile | Self-balancing — sum always zero |
| Bugs cause silent loss | Bugs detected by sum check |
| Hard to undo | Easy to reverse with a counter-entry |

The senior insight: balance is a derived value, not a stored value. It is `SUM(amount) WHERE account = ?`.

---

## Q15. Show me a double-entry schema.

**Answer:**

```sql
CREATE TABLE accounts (
  id UUID PRIMARY KEY,
  type VARCHAR(50) NOT NULL,  -- 'user_wallet', 'cash', 'fee_revenue'
  user_id UUID,                -- nullable; system accounts have no user
  currency CHAR(3) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  reference_id VARCHAR(255),   -- external ref, idempotency
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE entries (
  id BIGSERIAL PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES transactions(id),
  account_id UUID NOT NULL REFERENCES accounts(id),
  amount_minor BIGINT NOT NULL,    -- positive = debit, negative = credit
  currency CHAR(3) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_entries_account ON entries(account_id, created_at DESC);
CREATE INDEX idx_entries_transaction ON entries(transaction_id);
```

The constraint: for every transaction_id, SUM(amount_minor) = 0. Enforced by application code or database trigger.

Balance query:

```sql
SELECT SUM(amount_minor) AS balance
FROM entries 
WHERE account_id = $1;
```

For performance, materialize balances as a cache and update on every entry insert (within the same transaction).

---

## Q16. Walk me through a payment in a double-entry system.

**Answer:**

Scenario: User A pays User B $100, with $5 fee taken by the platform.

Entries (one transaction, three sides):

| Account | Amount |
|---------|--------|
| User A wallet | -$100 |
| User B wallet | +$95 |
| Platform fees | +$5 |
| **Sum** | **$0** |

```sql
BEGIN;
  INSERT INTO transactions (id, reference_id, description) 
  VALUES (uuid_generate_v4(), 'pmt_123', 'User payment');
  -- capture transaction_id as $txn
  
  INSERT INTO entries (transaction_id, account_id, amount_minor, currency) VALUES
    ($txn, $userA_wallet, -10000, 'USD'),
    ($txn, $userB_wallet,   9500, 'USD'),
    ($txn, $platform_fees,   500, 'USD');
COMMIT;
```

Verification before commit:

```sql
SELECT SUM(amount_minor) FROM entries WHERE transaction_id = $txn;
-- Must be 0; otherwise reject
```

In application code:

```javascript
async function processPayment(fromUserId, toUserId, amountMinor, feeMinor, currency) {
  return db.transaction(async (trx) => {
    const txnId = uuid();
    await trx.transactions.insert({ 
      id: txnId, 
      reference_id: `pmt_${Date.now()}`, 
      description: 'User payment',
    });
    
    const fromAccount = await getAccountId(trx, fromUserId, 'wallet');
    const toAccount = await getAccountId(trx, toUserId, 'wallet');
    const feesAccount = await getSystemAccountId(trx, 'fees');
    
    await trx.entries.insert([
      { transaction_id: txnId, account_id: fromAccount, amount_minor: -amountMinor, currency },
      { transaction_id: txnId, account_id: toAccount, amount_minor: amountMinor - feeMinor, currency },
      { transaction_id: txnId, account_id: feesAccount, amount_minor: feeMinor, currency },
    ]);
    
    // Verify sum is zero
    const sum = await trx.query(
      'SELECT SUM(amount_minor) AS total FROM entries WHERE transaction_id = $1',
      [txnId]
    );
    if (sum.rows[0].total !== '0') {
      throw new Error('Journal entries do not balance');
    }
  });
}
```

---

## Saga Pattern

## Q17. What is a saga, and when do you need one?

**Answer:**

A saga is a sequence of local transactions across multiple services. Each step has a compensating action that undoes its effect if a later step fails.

Why: in a microservice architecture, you cannot have an ACID transaction across services. A saga gives you eventual consistency with a defined recovery path.

---

## Q18. Walk me through an order saga.

**Answer:**

Steps:

1. Create order in Order Service
2. Reserve inventory in Inventory Service
3. Charge payment in Payment Service
4. Schedule shipping in Shipping Service

Compensations if a later step fails:

1. Cancel order
2. Release inventory
3. Refund payment
4. Cancel shipping

If step 3 (charge payment) fails, run compensation 2 (release inventory) then compensation 1 (cancel order) in reverse order.

```
Step 1 ✓ → Step 2 ✓ → Step 3 ✗
                         ↓
                   Compensate 2 → Compensate 1
```

```javascript
async function createOrderSaga(orderData) {
  const compensations = [];
  
  try {
    const order = await orderService.create(orderData);
    compensations.push(() => orderService.cancel(order.id));
    
    const reservation = await inventoryService.reserve(order.items);
    compensations.push(() => inventoryService.release(reservation.id));
    
    const charge = await paymentService.charge(order.amount, order.userId);
    compensations.push(() => paymentService.refund(charge.id));
    
    const shipment = await shippingService.schedule(order.id, order.address);
    compensations.push(() => shippingService.cancel(shipment.id));
    
    return { order, charge, shipment };
  } catch (err) {
    // Run compensations in reverse order
    for (const compensate of compensations.reverse()) {
      try {
        await compensate();
      } catch (compErr) {
        console.error('Compensation failed:', compErr);
        // Alert operations team — manual intervention may be needed
      }
    }
    throw err;
  }
}
```

---

## Q19. Choreography vs orchestration in sagas?

**Answer:**

Choreography: services emit events and others react. Decentralized.

Pros: no single point of failure.

Cons: hard to track end-to-end flow, hard to debug.

Orchestration: a central orchestrator calls each step explicitly.

Pros: clear flow, easier to monitor, easier to test.

Cons: orchestrator becomes critical infrastructure.

My take: start with orchestration if you can. It is simpler to reason about and debug. Choreography fits when teams are highly autonomous and you can accept the operational complexity.

---

## Q20. What is the outbox pattern?

**Answer:**

The outbox pattern is how you atomically commit a database change and publish an event.

The problem: if you save an order and then publish "order.created," a crash between the two leaves them inconsistent.

The solution: write the event to an outbox table inside the same database transaction. A separate worker reads the outbox and publishes events.

```sql
CREATE TABLE outbox (
  id BIGSERIAL PRIMARY KEY,
  event_type VARCHAR(100) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  published_at TIMESTAMPTZ
);

CREATE INDEX idx_outbox_pending ON outbox(status, created_at) WHERE status = 'pending';
```

```javascript
// Inside the transaction, write both the order and the event
async function createOrder(orderData) {
  return db.transaction(async (trx) => {
    const order = await trx.orders.insert(orderData);
    
    await trx.outbox.insert({
      event_type: 'order.created',
      payload: { order_id: order.id, user_id: order.user_id, amount: order.amount },
    });
    
    return order;
  });
}

// Worker reads outbox and publishes
async function outboxWorker() {
  while (true) {
    const events = await db.outbox.find({ status: 'pending' }).limit(100);
    
    for (const event of events) {
      try {
        await messageBus.publish(event.event_type, event.payload);
        await db.outbox.update({ id: event.id }, { 
          status: 'published', 
          published_at: new Date(),
        });
      } catch (err) {
        console.error('Failed to publish event:', err);
      }
    }
    
    await sleep(1000);
  }
}
```

This decouples the database from messaging without needing distributed transactions.

---

## Eventual Consistency

## Q21. Can financial systems use eventual consistency?

**Answer:**

Yes, with care.

Strict consistency required:
- User-facing balance after a transfer (the UI must show the right number)
- Available credit limit before charging
- Anti-fraud checks (must see latest data)

Eventual consistency tolerable:
- Reporting dashboards (slight delay tolerable)
- Statement generation (batched daily)
- Analytics (aggregated)
- Email notifications

The trade-off: strong consistency limits scale, eventual consistency requires reconciliation.

---

## Q22. How do you show a user's balance immediately after a transaction?

**Answer:**

Three options.

Option one: read your own writes. In the same database session and transaction, read after write. Easy if you are using a single primary database.

Option two: optimistic UI. Show the new balance based on the operation, even before the backend confirms.

```javascript
// Optimistic UI in the frontend
async function transfer(amount) {
  const oldBalance = balance;
  setBalance(oldBalance - amount); // optimistic
  
  try {
    const result = await api.transfer(amount);
    setBalance(result.newBalance); // confirmed
  } catch (err) {
    setBalance(oldBalance); // revert
    showError(err);
  }
}
```

Option three: sticky read. Route the user's reads to the primary (not replica) for X seconds after a write.

```javascript
const lastWriteAt = new Map();

async function getBalance(userId) {
  const lastWrite = lastWriteAt.get(userId);
  if (lastWrite && Date.now() - lastWrite < 5000) {
    return primaryDb.balance(userId);
  }
  return replicaDb.balance(userId);
}

async function performTransfer(userId, amount) {
  await primaryDb.transfer(userId, amount);
  lastWriteAt.set(userId, Date.now());
}
```

---

## Reconciliation

## Q23. What is reconciliation in financial systems?

**Answer:**

Reconciliation is a periodic verification that internal records match an external source of truth.

Examples:
- Bank statement reconciliation: daily check that bank balance matches database balance
- Payment provider reconciliation: monthly check of all charges in our database versus Stripe's records
- Inter-service reconciliation: account balance derived from journal entries should match the cached balance

If discrepancies are found, investigate, fix, and alert.

---

## Q24. Show me a basic reconciliation query.

**Answer:**

This compares the cached balance on the accounts table to the computed balance from the journal entries:

```sql
SELECT 
  a.id, 
  a.cached_balance, 
  COALESCE(SUM(e.amount_minor), 0) AS computed_balance,
  a.cached_balance - COALESCE(SUM(e.amount_minor), 0) AS drift
FROM accounts a
LEFT JOIN entries e ON e.account_id = a.id
GROUP BY a.id, a.cached_balance
HAVING a.cached_balance != COALESCE(SUM(e.amount_minor), 0);
```

Run this nightly. If results return any rows, alert the on-call.

For broader reconciliation, also check that all transactions sum to zero:

```sql
-- Every transaction must balance
SELECT transaction_id, SUM(amount_minor) AS imbalance
FROM entries
GROUP BY transaction_id
HAVING SUM(amount_minor) != 0;
```

---

## Q25. How do you reconcile against a third-party like a payment provider?

**Answer:**

Step one: pull the provider's transaction list (CSV export or API).

Step two: match against your database by reference ID.

Step three: categorize:

- Matched: counts and amounts equal — no action
- In our database but not provider: investigate (failed webhook, fake record, etc.)
- In provider but not our database: investigate (missed event, double-charge, etc.)
- Mismatched amount: investigate

Step four: generate a report of unmatched items.

Step five: resolve. Each unmatched item has a story: canceled, refunded, missed event, fraud.

Step six: keep an audit trail of resolution.

```javascript
async function reconcileWithProvider(date) {
  const providerCharges = await provider.listCharges({ date });
  const ourCharges = await db.charges.find({ date });
  
  const providerById = new Map(providerCharges.map(c => [c.reference_id, c]));
  const ourById = new Map(ourCharges.map(c => [c.id, c]));
  
  const matched = [];
  const onlyInProvider = [];
  const onlyInDb = [];
  const amountMismatch = [];
  
  for (const ours of ourCharges) {
    const theirs = providerById.get(ours.id);
    if (!theirs) {
      onlyInDb.push(ours);
    } else if (theirs.amount !== ours.amount) {
      amountMismatch.push({ ours, theirs });
    } else {
      matched.push(ours);
    }
  }
  
  for (const theirs of providerCharges) {
    if (!ourById.has(theirs.reference_id)) {
      onlyInProvider.push(theirs);
    }
  }
  
  return { matched, onlyInProvider, onlyInDb, amountMismatch };
}
```

Tools: usually built in-house, or with reconciliation platforms like Modern Treasury or Beam.

---

## Common Financial Bugs

## Q26. What is the off-by-penny rounding bug, and how do you fix it?

**Answer:**

If you split $10 across 3 users with Math.floor, each gets $3.33, total $9.99. The penny is missing.

```javascript
// Wrong - loses pennies
const total = 1000; // $10.00 in cents
const each = Math.floor(total / 3); // 333 cents
const distribution = [each, each, each]; // sum = 999, missing 1

// Right - assign rounding remainder explicitly
const each = Math.floor(total / 3); // 333
const remainder = total - each * 3; // 1
const distribution = [each, each, each + remainder]; // 333, 333, 334
```

For more complex splits, the typical pattern is to floor each share and assign the remainder to the last entry, or distribute remainders one cent at a time across entries.

---

## Q27. What is the time zone drift bug?

**Answer:**

Daily totals computed in UTC versus the user's local time can be off by one day for users near the day boundary.

```javascript
// Wrong - UTC for everything
function dailyRevenue(date) {
  return db.query(
    `SELECT SUM(amount) FROM transactions 
     WHERE created_at >= $1 AND created_at < $1 + INTERVAL '1 day'`,
    [date]
  );
}

// Right - explicit time zone
function dailyRevenue(date, timezone = 'America/New_York') {
  return db.query(
    `SELECT SUM(amount) FROM transactions 
     WHERE created_at >= ($1::timestamp AT TIME ZONE $2)
       AND created_at < ($1::timestamp + INTERVAL '1 day') AT TIME ZONE $2`,
    [date, timezone]
  );
}
```

The fix: explicitly state and document the time zone. Use the business's home time zone for accounting reports. Always store timestamps in UTC, but convert to local for reporting boundaries.

---

## Q28. How do you avoid the negative inventory or overdraft bug?

**Answer:**

The bug: a user can withdraw more than they have because the check happens before the actual decrement.

```javascript
// Wrong - race condition
const account = await db.accounts.findOne({ id });
if (account.balance >= amount) {
  account.balance -= amount;
  await db.accounts.update(account);
}
// Two concurrent withdrawals can both pass the check
```

Right approach — atomic decrement with WHERE clause:

```javascript
const result = await db.query(
  `UPDATE accounts 
   SET balance = balance - $1 
   WHERE id = $2 AND balance >= $1`,
  [amount, id]
);
if (result.rowCount === 0) {
  throw new Error('Insufficient funds');
}
```

Or pessimistic lock:

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = $1 FOR UPDATE;
-- check balance in app code
UPDATE accounts SET balance = balance - $1 WHERE id = $2;
COMMIT;
```

The atomic version is preferred because it does not hold a lock during application logic.

---

## Q29. Why should you never soft-delete a transaction?

**Answer:**

Soft-deleting marks a record as deleted but leaves the journal entry. The balance becomes wrong because the entry is still being summed.

The right pattern: never delete or modify financial transactions. If you need to reverse, create a new transaction with opposite entries.

```sql
-- Original payment
INSERT INTO entries (transaction_id, account_id, amount_minor, currency) VALUES
  ($txn1, $userA_wallet, -10000, 'USD'),
  ($txn1, $platform_cash, 10000, 'USD');

-- Refund (a new transaction with opposite entries, referencing the original)
INSERT INTO transactions (id, reference_id, description) 
VALUES ($txn2, 'refund_of_pmt_123', 'Refund');

INSERT INTO entries (transaction_id, account_id, amount_minor, currency) VALUES
  ($txn2, $platform_cash, -10000, 'USD'),
  ($txn2, $userA_wallet, 10000, 'USD');
```

The original transaction stays untouched. The refund is a new transaction. The audit trail is preserved. Partial refunds are easy — just smaller amounts in the new entries.

---

## Real Interview Scenarios

## Q30. Design a money transfer between users.

**Answer:**

The design has these components:

Schema with double-entry: accounts, transactions, entries.

API takes an idempotency key.

Atomic transaction with FOR UPDATE on accounts (in deterministic ID order to avoid deadlock).

Verify sufficient funds inside the transaction.

If anything fails, the whole thing rolls back.

For monitoring, reconcile balances against the entries table nightly.

```javascript
async function transferMoney(fromUserId, toUserId, amountMinor, currency, idempotencyKey) {
  // Idempotency check first
  const existing = await db.idempotency_keys.findOne({ key: idempotencyKey });
  if (existing) return JSON.parse(existing.response);
  
  return db.transaction(async (trx) => {
    const fromAccount = await getAccountId(trx, fromUserId, 'wallet', currency);
    const toAccount = await getAccountId(trx, toUserId, 'wallet', currency);
    
    // Lock both accounts in deterministic order
    const [first, second] = [fromAccount, toAccount].sort();
    await trx.query(
      'SELECT id FROM accounts WHERE id IN ($1, $2) ORDER BY id FOR UPDATE',
      [first, second]
    );
    
    // Verify sufficient funds
    const balance = await trx.query(
      'SELECT COALESCE(SUM(amount_minor), 0) AS balance FROM entries WHERE account_id = $1',
      [fromAccount]
    );
    if (parseInt(balance.rows[0].balance) + amountMinor < 0) {
      // amountMinor will be subtracted as -amountMinor; check effective balance
      throw new Error('Insufficient funds');
    }
    
    // Create transaction and entries
    const txnId = uuid();
    await trx.transactions.insert({
      id: txnId,
      reference_id: idempotencyKey,
      description: 'Transfer',
    });
    
    await trx.entries.insert([
      { transaction_id: txnId, account_id: fromAccount, amount_minor: -amountMinor, currency },
      { transaction_id: txnId, account_id: toAccount, amount_minor: amountMinor, currency },
    ]);
    
    // Save idempotency record
    const result = { transaction_id: txnId, status: 'succeeded' };
    await trx.idempotency_keys.insert({
      key: idempotencyKey,
      response: JSON.stringify(result),
    });
    
    return result;
  });
}
```

---

## Q31. Design a wallet with bonus rewards.

**Answer:**

Reward credits are still money — the same rules apply (double-entry, integer storage, audit trail). But rewards have additional constraints: expiration, withdrawal restrictions, spending order.

Design choices:

Sub-ledgers — separate "cash balance" and "reward balance" accounts per user.

Spending order — reward first, then cash (or vice versa, business choice).

Expiration runs as a scheduled job that debits expired rewards.

```sql
-- Accounts table extended
CREATE TABLE accounts (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  account_type VARCHAR(50) NOT NULL,  -- 'cash', 'reward', 'pending'
  currency CHAR(3) NOT NULL,
  expires_at TIMESTAMPTZ,             -- nullable; null = no expiration
  withdraw_restricted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_accounts_expiring ON accounts(expires_at) 
WHERE expires_at IS NOT NULL;
```

```javascript
// Spending order: reward first, then cash
async function spend(userId, amountMinor, currency) {
  return db.transaction(async (trx) => {
    const rewardBalance = await getBalance(trx, userId, 'reward', currency);
    const cashBalance = await getBalance(trx, userId, 'cash', currency);
    
    if (rewardBalance + cashBalance < amountMinor) {
      throw new Error('Insufficient funds');
    }
    
    const fromReward = Math.min(rewardBalance, amountMinor);
    const fromCash = amountMinor - fromReward;
    
    const txnId = uuid();
    await trx.transactions.insert({ id: txnId, description: 'Purchase' });
    
    const entries = [];
    if (fromReward > 0) {
      const rewardAccount = await getAccountId(trx, userId, 'reward', currency);
      entries.push({ transaction_id: txnId, account_id: rewardAccount, amount_minor: -fromReward, currency });
    }
    if (fromCash > 0) {
      const cashAccount = await getAccountId(trx, userId, 'cash', currency);
      entries.push({ transaction_id: txnId, account_id: cashAccount, amount_minor: -fromCash, currency });
    }
    
    const merchantAccount = await getSystemAccountId(trx, 'merchant_revenue');
    entries.push({ transaction_id: txnId, account_id: merchantAccount, amount_minor: amountMinor, currency });
    
    await trx.entries.insert(entries);
  });
}

// Expiration job runs nightly
async function expireRewards() {
  const expiredAccounts = await db.accounts.find({
    account_type: 'reward',
    expires_at: { $lt: new Date() },
  });
  
  for (const account of expiredAccounts) {
    const balance = await getBalance(null, account.user_id, 'reward', account.currency);
    if (balance > 0) {
      await debitToExpirationAccount(account.id, balance);
    }
  }
}
```

---

## Q32. Handle a refund correctly.

**Answer:**

Wrong: subtract from the original transaction. This breaks the audit trail.

Right: create a new transaction with the opposite entries, referencing the original.

```sql
-- Original payment
Transaction A:
  User A wallet: -$100
  Platform cash: +$100

-- Refund
Transaction B (references A):
  Platform cash: -$100
  User A wallet: +$100
```

The original transaction stays untouched. The refund is a new transaction with reference to the original. Audit trail preserved. Easy to handle partial refunds (just smaller amounts).

```javascript
async function refund(originalTransactionId, refundAmountMinor) {
  return db.transaction(async (trx) => {
    const originalEntries = await trx.entries.find({ 
      transaction_id: originalTransactionId 
    });
    
    if (originalEntries.length === 0) {
      throw new Error('Original transaction not found');
    }
    
    const refundTxnId = uuid();
    await trx.transactions.insert({
      id: refundTxnId,
      reference_id: `refund_of_${originalTransactionId}`,
      description: 'Refund',
    });
    
    // For partial refunds, scale the entries proportionally
    const originalTotal = Math.abs(
      originalEntries.find(e => e.amount_minor < 0).amount_minor
    );
    const ratio = refundAmountMinor / originalTotal;
    
    const refundEntries = originalEntries.map(entry => ({
      transaction_id: refundTxnId,
      account_id: entry.account_id,
      amount_minor: -Math.round(entry.amount_minor * ratio), // opposite sign
      currency: entry.currency,
    }));
    
    await trx.entries.insert(refundEntries);
    
    return { refund_transaction_id: refundTxnId };
  });
}
```

---

## Q33. How do you detect fraud in a financial system?

**Answer:**

I use real-time signals plus batch signals.

Real-time signals at transaction time:

- Velocity: transactions per minute exceed baseline
- Geographic impossibility: login in NYC, transaction in Tokyo five minutes later
- Device fingerprint mismatch
- Amount anomaly versus user history (10x normal)

Batch signals run nightly:

- Network analysis: multiple accounts with the same device or IP
- Pattern matching against known fraud signatures
- New account behavior anomalies

Action based on score:

- High score: block the transaction
- Medium score: challenge with MFA
- Low score: allow with delay (so we can review)
- Very low score: allow immediately

```javascript
async function evaluateRisk(transaction, user) {
  let score = 0;
  
  // Velocity check
  const recentCount = await db.transactions.count({
    user_id: user.id,
    created_at: { $gt: new Date(Date.now() - 60000) },
  });
  if (recentCount > 10) score += 30;
  
  // Geographic check
  const lastLogin = await db.logins.findOne({ user_id: user.id }, { sort: { created_at: -1 } });
  if (lastLogin && distanceInKm(lastLogin.geo, transaction.geo) > 5000) {
    const minutesSinceLogin = (Date.now() - lastLogin.created_at) / 60000;
    if (minutesSinceLogin < 60) score += 50; // impossible travel
  }
  
  // Amount anomaly
  const userAvg = await getUserAverageTransaction(user.id);
  if (transaction.amount > userAvg * 10) score += 20;
  
  // Device fingerprint
  const knownDevices = await db.devices.find({ user_id: user.id });
  if (!knownDevices.some(d => d.fingerprint === transaction.device_fingerprint)) {
    score += 15;
  }
  
  return score;
}

async function processTransaction(transaction, user) {
  const riskScore = await evaluateRisk(transaction, user);
  
  if (riskScore >= 70) {
    await blockTransaction(transaction);
    throw new Error('Transaction blocked due to fraud risk');
  } else if (riskScore >= 40) {
    await requireMFA(transaction);
  } else if (riskScore >= 20) {
    await flagForReview(transaction);
  }
  
  return executeTransaction(transaction);
}
```

Feedback loop: confirmed fraud trains the model; false positives tune the threshold.

Tools: Sift, Stripe Radar, or a custom rules engine.

---

## Q34. What if the database fails during a transfer?

**Answer:**

I walk through three failure points.

If failure happens before commit: the database rolls back automatically. No harm done.

If failure happens after commit but before the response is sent to the client: the client sees a timeout and retries with the same idempotency key. The second request returns the cached result, no double charge.

If the client does not have idempotency: there is a double-charge risk. This is exactly why idempotency is mandatory.

```javascript
async function safeTransfer(req, res) {
  const idempotencyKey = req.headers['idempotency-key'];
  if (!idempotencyKey) {
    return res.status(400).json({ error: 'Idempotency key required' });
  }
  
  // Check for existing result first (handles retry-after-success case)
  const existing = await db.idempotency_keys.findOne({ key: idempotencyKey });
  if (existing) {
    return res.json(JSON.parse(existing.response));
  }
  
  try {
    const result = await db.transaction(async (trx) => {
      // ... do transfer ...
      const txnResult = { /* ... */ };
      
      // Save idempotency record in same transaction
      await trx.idempotency_keys.insert({
        key: idempotencyKey,
        response: JSON.stringify(txnResult),
      });
      
      return txnResult;
    });
    
    res.json(result);
  } catch (e) {
    if (e.code === '23505') {
      // Duplicate idempotency key - another request committed first
      const existing = await db.idempotency_keys.findOne({ key: idempotencyKey });
      return res.json(JSON.parse(existing.response));
    }
    throw e;
  }
}
```

The senior point: network failures and crashes are not edge cases. They are routine. Design assuming requests will fail mid-flight.

---

## Q35. How do you handle currency conversion in transactions?

**Answer:**

Store the original amount and currency. If you need to record a base currency value, store the rate at the time of the transaction.

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  amount_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL,
  
  -- For multi-currency reporting
  base_amount_minor BIGINT,
  base_currency CHAR(3),
  exchange_rate NUMERIC(19, 8),
  exchange_rate_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT now()
);
```

```javascript
async function recordTransaction(amountMinor, currency, baseCurrency = 'USD') {
  const rate = await fxService.getRate(currency, baseCurrency);
  const baseAmount = Math.round(amountMinor * rate);
  
  return db.transactions.insert({
    amount_minor: amountMinor,
    currency,
    base_amount_minor: baseAmount,
    base_currency: baseCurrency,
    exchange_rate: rate,
    exchange_rate_at: new Date(),
  });
}
```

Reports use the stored rate, not today's rate. This way, last month's totals do not change every day.

---

## Q36. How would you implement a wallet with hold or pending balances?

**Answer:**

Use sub-ledger accounts to separate available, pending, and held balances. Money moves between sub-accounts as it changes state.

```sql
-- Each user has multiple sub-accounts
CREATE TABLE accounts (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  sub_type VARCHAR(50) NOT NULL,  -- 'available', 'pending', 'held'
  currency CHAR(3) NOT NULL
);
```

When a deposit is initiated, money goes to "pending":

```javascript
// Deposit started
async function startDeposit(userId, amount) {
  return db.transaction(async (trx) => {
    const txnId = uuid();
    const externalAccount = await getSystemAccount(trx, 'external_inflow');
    const pendingAccount = await getUserAccount(trx, userId, 'pending');
    
    await trx.entries.insert([
      { transaction_id: txnId, account_id: externalAccount, amount_minor: -amount, currency: 'USD' },
      { transaction_id: txnId, account_id: pendingAccount, amount_minor: amount, currency: 'USD' },
    ]);
  });
}

// Deposit confirmed - move from pending to available
async function confirmDeposit(userId, amount) {
  return db.transaction(async (trx) => {
    const txnId = uuid();
    const pendingAccount = await getUserAccount(trx, userId, 'pending');
    const availableAccount = await getUserAccount(trx, userId, 'available');
    
    await trx.entries.insert([
      { transaction_id: txnId, account_id: pendingAccount, amount_minor: -amount, currency: 'USD' },
      { transaction_id: txnId, account_id: availableAccount, amount_minor: amount, currency: 'USD' },
    ]);
  });
}
```

The user can only spend from "available." Pending and held balances are visible but locked.

---

## Q37. What is two-phase commit, and why is it usually avoided?

**Answer:**

Two-phase commit (2PC) is a protocol for committing a transaction across multiple databases or services. Phase one: a coordinator asks all participants to prepare. Phase two: if all said yes, the coordinator tells everyone to commit; if any said no, everyone rolls back.

It guarantees atomicity across systems, but it has serious downsides:

- Synchronous: all participants must be online and responsive
- Blocking: locks held during the prepare phase
- Coordinator failure: if the coordinator crashes mid-protocol, participants are in an unknown state
- Performance: latency is the sum of all participant latencies

For these reasons, modern systems prefer the saga pattern with eventual consistency, or the outbox pattern, over 2PC. 2PC is mostly used in legacy systems or specific environments like XA-compliant databases.

---

## Q38. How do you handle high-throughput payment processing?

**Answer:**

A few patterns I would combine.

Async processing: accept the payment request synchronously, queue the actual processing. Return a payment intent ID. The client polls or receives a webhook.

```javascript
app.post('/payments', async (req, res) => {
  const intentId = uuid();
  
  // Save intent synchronously
  await db.payment_intents.insert({
    id: intentId,
    amount: req.body.amount,
    currency: req.body.currency,
    status: 'queued',
    idempotency_key: req.headers['idempotency-key'],
  });
  
  // Queue for processing
  await queue.add('process-payment', { intentId });
  
  res.json({ payment_intent_id: intentId, status: 'queued' });
});
```

Sharding: shard the database by user_id or account_id. Each shard handles its own transactions in isolation.

Cached balances: maintain a denormalized balance per account, updated atomically with each entry. Read the balance directly without summing entries.

```sql
ALTER TABLE accounts ADD COLUMN cached_balance BIGINT DEFAULT 0;

-- Update both atomically
BEGIN;
INSERT INTO entries (...) VALUES (...);
UPDATE accounts SET cached_balance = cached_balance + $amount WHERE id = $account_id;
COMMIT;

-- Reconcile nightly to detect drift
```

Read replicas for reporting and historical queries, primary only for transaction processing.

Connection pooling tuned to actual concurrency.

---

## Q39. How do you audit a financial system?

**Answer:**

The audit trail is built into the design.

Every change to financial data is recorded as a journal entry. Entries are append-only. Never modified. Never deleted.

The transactions table records who initiated each transaction (user_id), when (created_at), and why (description, reference_id).

For administrative actions, log who, when, what, and the before/after state:

```sql
CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY,
  actor_id UUID NOT NULL,
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(100) NOT NULL,
  resource_id UUID NOT NULL,
  before_state JSONB,
  after_state JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

For reconciliation, run nightly:

- Sum of all journal entries equals zero (system balance)
- Cached balances match computed balances
- Provider records match our records
- Outbox events have been published

Any discrepancy triggers an alert.

---

## Q40. What is your final advice on building financial systems?

**Answer:**

Six rules I follow.

One: double-entry bookkeeping. Always. Balance is derived from entries, not stored.

Two: integer or decimal storage for money. Never float.

Three: idempotency on every state-changing operation. Mandatory.

Four: atomic transactions for any multi-step state change. No exceptions.

Five: reconcile periodically. Trust nothing. Compare cached values to computed values, internal records to external sources.

Six: append-only audit trail. Never delete. Never modify. Reverse with new entries.

If you follow these six rules, you will not introduce the bugs that haunt financial systems. They are not optional. They are the cost of being trusted with money.
