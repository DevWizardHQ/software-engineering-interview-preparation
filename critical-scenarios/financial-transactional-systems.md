# Financial and Transactional Systems

**Why this matters:** Senior engineering interviews routinely test money handling. Bugs in financial code are unforgivable — they cost real money and trust. This file covers the senior-level concepts and questions for transactions, money handling, ledgers, and reconciliation.

---

## Table of Contents

1. [Money Representation Rules](#money-representation-rules)
2. [ACID and Transactions](#acid-and-transactions)
3. [Isolation Levels — When and Why](#isolation-levels--when-and-why)
4. [Idempotency in Financial Systems](#idempotency-in-financial-systems)
5. [Double-Entry Bookkeeping](#double-entry-bookkeeping)
6. [Saga Pattern and Distributed Transactions](#saga-pattern-and-distributed-transactions)
7. [Eventual Consistency in Money Systems](#eventual-consistency-in-money-systems)
8. [Reconciliation](#reconciliation)
9. [Common Financial Bug Patterns](#common-financial-bug-patterns)
10. [Real Interview Scenarios](#real-interview-scenarios)

---

## Money Representation Rules

### Rule 1: Never use float for money

**Why:**
```
0.1 + 0.2 = 0.30000000000000004
```

**What to use instead:**
- Integer cents (or smallest currency unit)
- Decimal type in DB (`NUMERIC(19, 4)`)
- Decimal libraries in code (`Decimal.js`, `bcmath`, `Java BigDecimal`)

### Rule 2: Always know the currency

Money without currency is meaningless. Store both:

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  amount_minor BIGINT NOT NULL,    -- amount in minor units (cents, paise, etc.)
  currency CHAR(3) NOT NULL,       -- ISO 4217 (USD, EUR, BDT)
  -- ...
);
```

### Rule 3: Pick rounding rules deliberately

Banker's rounding (round half to even) vs round half up — pick one and document. Tax calculations and financial reports often have legal rounding requirements.

### Rule 4: Display ≠ Storage

Store as canonical units (e.g., `12345` cents). Display as `$123.45`. Never round during arithmetic, only at display.

### Rule 5: Conversion rates are time-stamped

If your system handles multiple currencies, the rate at the time of the transaction must be stored. Don't recalculate based on today's rate.

```sql
amount_minor BIGINT NOT NULL,
currency CHAR(3) NOT NULL,
-- For multi-currency reporting:
base_amount_minor BIGINT,        -- converted to base currency
base_currency CHAR(3),
exchange_rate NUMERIC(19, 8),
exchange_rate_at TIMESTAMPTZ
```

---

## ACID and Transactions

### Q1. What does ACID stand for?

| Letter | Meaning | What it guarantees |
|--------|---------|---------------------|
| A | Atomicity | All operations in a transaction succeed or none do |
| C | Consistency | The DB transitions from one valid state to another |
| I | Isolation | Concurrent transactions don't see each other's intermediate state |
| D | Durability | Once committed, the change survives crashes |

**Why this matters in finance:** A transfer of $100 from A to B is two operations: debit A, credit B. Without atomicity, you can crash between them and create money out of thin air or destroy it.

---

### Q2. What is a database transaction in SQL?

```sql
BEGIN;
  UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
  UPDATE accounts SET balance = balance + 100 WHERE id = 'B';
  INSERT INTO transfers (from_id, to_id, amount) VALUES ('A', 'B', 100);
COMMIT;
-- If anything fails: ROLLBACK;
```

If the server crashes between the two UPDATEs, the transaction is rolled back. No money is lost.

---

### Q3. What's the difference between a transaction and a unit of work?

- **Transaction** = DB-level guarantee
- **Unit of work** = application-level concept that maps to one transaction

A unit of work usually represents a business operation (e.g., "process order"). It's the application's responsibility to:
1. Begin transaction at the start
2. Track all changes
3. Commit at the end
4. Rollback on any error

ORMs like Hibernate, Doctrine, Entity Framework manage units of work automatically.

---

### Q4. When does a transaction NOT save you?

- **Network calls inside the transaction:** if you call an external API mid-transaction, the API succeeded but the DB rolled back → out of sync
- **Multiple databases:** a single DB transaction does not span multiple databases
- **Background jobs:** queueing a job inside a transaction means the job may run before commit (or never if you rollback)

**Solution patterns:**
- **Outbox pattern:** record events in the DB inside the transaction, a separate worker reads and publishes them after commit
- **Saga pattern:** for cross-service workflows
- **Two-phase commit:** rare, complex, generally avoided

---

## Isolation Levels — When and Why

### Q5. What are the four isolation levels?

| Level | Dirty Reads | Non-Repeatable Reads | Phantom Reads | Use Case |
|-------|-------------|---------------------|---------------|----------|
| Read Uncommitted | Possible | Possible | Possible | Almost never |
| Read Committed (default in Postgres) | Prevented | Possible | Possible | General use |
| Repeatable Read | Prevented | Prevented | Possible (Postgres prevents this too via MVCC) | Reports, analytics |
| Serializable | Prevented | Prevented | Prevented | Strong correctness, slower |

### Q6. Define each anomaly:

- **Dirty read:** Transaction reads data that another uncommitted transaction wrote
- **Non-repeatable read:** Same SELECT in the same transaction returns different values because another transaction committed in between
- **Phantom read:** Same SELECT returns different rows because another transaction inserted/deleted matching rows
- **Lost update:** Two transactions read the same row, both update — second overwrites the first

---

### Q7. What isolation level should I use for a money transfer?

**Default (Read Committed)** is usually enough if you use:
- `SELECT ... FOR UPDATE` (pessimistic lock) on accounts
- Or atomic UPDATE with conditional WHERE
- Or version-based optimistic locking

**Serializable** is safest but has higher abort rate. Use when:
- Complex multi-row business rules
- Reports that need a consistent snapshot
- Critical correctness > throughput

---

### Q8. Show me a safe money transfer in SQL.

**Pattern A — pessimistic locking:**

```sql
BEGIN;

  -- Lock both rows in deterministic order to avoid deadlock
  SELECT * FROM accounts WHERE id IN ('A', 'B') ORDER BY id FOR UPDATE;

  -- Verify A has balance
  -- (in app code; check balance >= amount)

  UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
  UPDATE accounts SET balance = balance + 100 WHERE id = 'B';

  INSERT INTO transfers (from_id, to_id, amount, created_at)
  VALUES ('A', 'B', 100, now());

COMMIT;
```

**Pattern B — optimistic with check:**

```sql
BEGIN;

  UPDATE accounts SET balance = balance - 100 
  WHERE id = 'A' AND balance >= 100;
  -- Check rows affected = 1, otherwise insufficient funds → ROLLBACK

  UPDATE accounts SET balance = balance + 100 WHERE id = 'B';

  INSERT INTO transfers (...) VALUES (...);

COMMIT;
```

Pattern B is faster (no SELECT FOR UPDATE) but the WHERE clause is the safety check.

---

## Idempotency in Financial Systems

### Q9. Why is idempotency mandatory in payment systems?

Networks fail. Clients retry. Without idempotency, retry = double charge.

**The contract:**
- Client generates a unique ID for each operation (UUID)
- Server stores the result keyed by that ID
- If the same ID is sent again, server returns the original result without re-executing

```http
POST /api/payments
Idempotency-Key: 7f8e1d2c-3b4a-5c6d-7e8f-9a0b1c2d3e4f
{ "amount": 5000, "currency": "USD", "to": "merchant_123" }
```

```js
async function charge(req) {
  const key = req.headers['idempotency-key'];
  
  const existing = await db.idempotency.findOne({ key });
  if (existing) return existing.response;
  
  // ⚠️ Race window here — use unique constraint on key
  
  const result = await paymentProvider.charge(req.body);
  await db.idempotency.insert({ key, response: result });
  
  return result;
}
```

### Q10. How do you handle idempotency under high concurrency?

The naive check-then-insert has a race. Solutions:

**Option 1 — Unique constraint:**
```sql
CREATE UNIQUE INDEX uq_idempotency_key ON idempotency_keys (key);
```
Insert first; on conflict, return existing.

**Option 2 — Advisory lock:**
```sql
SELECT pg_advisory_xact_lock(hashtext($1));
```
Hold a lock per key inside the transaction.

**Option 3 — Reserve slot, then process:**
1. Insert with status = 'pending'
2. Process
3. Update with result
4. Subsequent requests: if pending, return "in progress"; if complete, return result

---

### Q11. What if the payment provider is non-idempotent?

Wrap them with your own idempotency layer:

```js
async function chargeWithIdempotency(amount, key) {
  const existing = await db.charges.findOne({ idempotency_key: key });
  if (existing?.provider_id) return existing;
  
  // Reserve the slot
  const reservation = await db.charges.upsert({
    idempotency_key: key,
    status: 'in_progress'
  });
  
  try {
    // Pass the same key to provider if they support it
    const providerResult = await provider.charge({ amount, ref: key });
    
    await db.charges.update({
      idempotency_key: key,
      status: 'succeeded',
      provider_id: providerResult.id
    });
    
    return providerResult;
  } catch (e) {
    // Mark failed but keep the record so retries don't re-attempt
    await db.charges.update({ idempotency_key: key, status: 'failed' });
    throw e;
  }
}
```

---

## Double-Entry Bookkeeping

### Q12. What is double-entry bookkeeping?

Every financial transaction has two equal and opposite entries: a debit on one account and a credit on another. The sum is always zero.

**Example: User pays $100:**
- Credit user's account: -$100
- Debit cash account: +$100
- Net: $0

This is a centuries-old accounting principle, and it's still the gold standard for software.

---

### Q13. Why do we use double-entry instead of just updating balances?

| Single-entry | Double-entry |
|--------------|--------------|
| Update balance directly | Append journal entries |
| No history | Full audit trail |
| Can't reconcile | Self-balancing |
| Bugs cause silent loss | Bugs detected by sum check |
| Hard to undo | Easy to reverse |

**Senior insight:** balance is a derived value, not a stored value. It's `SUM(amount) WHERE account = ?`.

---

### Q14. Show me a double-entry schema.

```sql
CREATE TABLE accounts (
  id UUID PRIMARY KEY,
  type VARCHAR(50) NOT NULL,  -- 'user_wallet', 'cash', 'fee_revenue', etc.
  user_id UUID,               -- nullable, system accounts have no user
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
```

**Constraint:** for every `transaction_id`, `SUM(amount_minor) = 0`. Enforced by code or trigger.

**Balance query:**
```sql
SELECT SUM(amount_minor) FROM entries WHERE account_id = ?;
```

For performance, materialize balances and update on every entry insert (within the same transaction).

---

### Q15. Walk me through a payment in a double-entry system.

**Scenario:** User A pays User B $100, with $5 fee taken by the platform.

**Entries (one transaction):**

| Account | Amount |
|---------|--------|
| User A wallet | -$100 |
| User B wallet | +$95 |
| Platform fees | +$5 |
| **Sum** | **$0** ✓ |

```sql
BEGIN;
  INSERT INTO transactions (id, reference_id, description) 
  VALUES (uuid_generate_v4(), 'pmt_123', 'User payment');
  
  -- Capture transaction_id
  
  INSERT INTO entries (transaction_id, account_id, amount_minor, currency) VALUES
    ($txn, $userA_wallet, -10000, 'USD'),
    ($txn, $userB_wallet,   9500, 'USD'),
    ($txn, $platform_fees,   500, 'USD');

COMMIT;
```

If sum doesn't equal zero, the transaction would be rejected by validation/trigger.

---

## Saga Pattern and Distributed Transactions

### Q16. What is a saga?

A saga is a sequence of local transactions across multiple services. Each step has a compensating action that undoes its effect if a later step fails.

**Why we need it:** in a microservice architecture, you can't have an ACID transaction across services. A saga gives you eventual consistency with a defined recovery path.

---

### Q17. Walk me through an order saga.

**Steps:**
1. Create Order (Order Service)
2. Reserve Inventory (Inventory Service)
3. Charge Payment (Payment Service)
4. Schedule Shipping (Shipping Service)

**Compensations (if a later step fails):**
1. Cancel Order
2. Release Inventory
3. Refund Payment
4. Cancel Shipping

If step 3 fails, run compensations 2 and 1 in reverse.

```
Step 1 ✓ → Step 2 ✓ → Step 3 ✗
                      ↓
                      Compensate 2 → Compensate 1
```

---

### Q18. Choreography vs Orchestration in sagas?

**Choreography:** services emit events, others react. Decentralized.
- Pro: no single point of failure
- Con: hard to track end-to-end flow, hard to debug

**Orchestration:** a central orchestrator calls each step explicitly.
- Pro: clear flow, easier to monitor
- Con: orchestrator becomes critical infra

**Senior take:** start with orchestration if you can — it's simpler to reason about. Choreography fits when teams are highly autonomous.

---

### Q19. What is the outbox pattern?

A pattern to atomically commit a DB change AND publish an event.

**Problem:** if you save an order and then publish "order.created", a crash between the two leaves them inconsistent.

**Solution:**
```sql
BEGIN;
  INSERT INTO orders (...) VALUES (...);
  INSERT INTO outbox (event_type, payload) VALUES ('order.created', '{...}');
COMMIT;
```

Both inserts happen atomically. A separate worker polls `outbox`, publishes to message bus, marks as published. If crash, replay safely.

This decouples DB from messaging without needing distributed transactions.

---

## Eventual Consistency in Money Systems

### Q20. Can financial systems use eventual consistency?

**Yes, with care.**

Hard-real-time consistency:
- Bank account balance for the user (their UI must show the right number after a transfer)
- Available credit limit before charging

Eventually consistent OK:
- Reporting dashboards (slight delay tolerable)
- Statement generation (batched daily)
- Analytics (aggregated)

**Trade-off:** strong consistency limits scale, eventual consistency requires reconciliation.

---

### Q21. How do you show a user's balance immediately after a transaction?

**Option 1 — Read your own writes:** in the same DB session/transaction, read after write. Easy if same DB.

**Option 2 — Optimistic UI:** show the new balance based on the operation, even before backend confirms.

**Option 3 — Sticky read:** route the user's reads to the primary (not replica) for X seconds after a write.

---

## Reconciliation

### Q22. What is reconciliation in financial systems?

A periodic verification that internal records match an external source of truth.

**Examples:**
- Bank statement reconciliation: daily check that bank balance matches DB balance
- Payment provider reconciliation: monthly check of all charges in our DB vs Stripe's records
- Inter-service reconciliation: account balance derived from journal entries should match the cached balance

If discrepancies found → investigate, fix, alert.

---

### Q23. Show me a basic reconciliation query.

```sql
-- Reconcile cached balance vs computed balance
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

Run nightly. If results return any rows → alert.

---

### Q24. How do you reconcile against a third-party (e.g., payment provider)?

1. Pull the provider's transaction list (CSV export, API)
2. Match against your DB by reference ID
3. Categorize:
   - **Matched** — counts and amounts equal
   - **In our DB but not provider** — investigate
   - **In provider but not our DB** — investigate (could be webhook missed)
   - **Mismatched amount** — investigate

4. Generate a report of unmatched items
5. Resolve: each unmatched item has a story (canceled, refunded, missed event)
6. Audit trail of resolution

Tools: usually built in-house or with reconciliation platforms (Modern Treasury, Beam).

---

## Common Financial Bug Patterns

### Bug 1: Off-by-one penny rounding accumulates

If you split $10 across 3 users with `Math.floor`, each gets $3.33, total $9.99. The penny is missing.

**Fix:** assign rounding remainders explicitly. The last entry gets the residue:
```js
const total = 1000;  // $10.00 in cents
const shares = [Math.floor(total / 3), Math.floor(total / 3), 0];
shares[2] = total - shares[0] - shares[1];  // 333, 333, 334
```

### Bug 2: Time zone drift in financial reports

Daily totals computed in UTC vs user's local time. Off-by-one-day depending on user.

**Fix:** explicitly state and document the time zone. Use the business's home time zone for accounting.

### Bug 3: Currency conversion at wrong time

Transaction recorded in USD, but at report time you convert at today's rate. Reports change every day.

**Fix:** store the rate at the time of the transaction. Reports use stored rate.

### Bug 4: Missing transaction integrity check

Multi-step financial operation without a transaction. One step succeeds, another fails. Books are inconsistent.

**Fix:** wrap in a DB transaction. Verify all-or-nothing.

### Bug 5: External API call inside DB transaction

DB transaction holds a row lock for the duration of an HTTP call. Slow API → DB lock contention → timeouts.

**Fix:** restructure. Make the DB change quickly, then queue the external call.

### Bug 6: Replay attack on payment intent

Same payment request signed and replayed. Without idempotency, double-charge.

**Fix:** idempotency key + signature timestamp + replay protection.

### Bug 7: Negative inventory / overdraft

User can withdraw more than they have because the check happens before the actual decrement.

**Fix:** atomic decrement with WHERE clause, or pessimistic lock.

### Bug 8: "Soft delete" of a transaction

Marking a transaction as deleted but the journal entry stays. Balance becomes wrong.

**Fix:** never soft-delete transactions. Add a reversing transaction instead.

---

## Real Interview Scenarios

### Scenario 1: "Design a money transfer between users"

**What to mention:**
1. Schema with double-entry
2. Idempotency key
3. Atomic transaction with FOR UPDATE on accounts
4. Currency handling
5. Audit log
6. Insufficient funds case
7. Reconciliation strategy

**Sample design out loud:**
> "I'd design accounts and entries tables with double-entry bookkeeping. Each transfer is one transaction with two entries summing to zero. The API takes an idempotency key. The transaction locks both accounts in deterministic ID order to avoid deadlock. I'd verify sufficient funds inside the transaction. If anything fails, the whole thing rolls back. For monitoring, I'd reconcile balances against the entries table nightly."

---

### Scenario 2: "Design a wallet with bonus rewards"

**Senior considerations:**
- Reward credits are still money — same rules apply
- But: rewards may have expiration, restrictions, withdrawal limits
- Sub-ledgers: separate "cash balance" and "reward balance" accounts per user
- Spending order: reward first, then cash (or vice versa, business choice)
- Expiration runs as a scheduled job, debits expired rewards

```sql
-- accounts table extended
account_subtype VARCHAR(50)  -- 'cash', 'reward', 'pending'
restriction VARCHAR(100)      -- 'expires_2025-12-31', 'withdraw_blocked'
```

---

### Scenario 3: "Handle a refund correctly"

**Wrong:** subtract from the original transaction.

**Right:** create a new transaction with the opposite entries.

```
Original payment:
  User A wallet: -$100
  Platform cash: +$100

Refund:
  Platform cash: -$100
  User A wallet: +$100
```

The original transaction stays untouched. The refund is a new transaction with reference to the original.

Audit trail is preserved. Easy to handle partial refunds (just smaller amounts).

---

### Scenario 4: "How do you detect fraud in your system?"

Senior answer:

1. **Real-time signals:**
   - Velocity (transactions per minute exceeds baseline)
   - Geographic impossibility (login NYC, transaction Tokyo 5 min later)
   - Device fingerprint mismatch
   - Amount anomaly vs user history
2. **Batch signals:**
   - Network analysis (multiple accounts, same device)
   - Pattern matching against known fraud signatures
3. **Action:**
   - Score-based: block, challenge (MFA), allow with delay, allow
4. **Feedback loop:**
   - Confirmed fraud → train model
   - False positive → tune threshold

Tools: Sift, Stripe Radar, custom rules engine.

---

### Scenario 5: "What if the database fails during a transfer?"

**Walk through:**

- If failure happens **before commit** → DB rolls back, no harm done
- If failure happens **after commit but before response sent** → client sees timeout, retries with same idempotency key → second request returns the cached result
- If client doesn't have idempotency → DOUBLE-CHARGE risk → this is why idempotency is mandatory

**Senior point:** Network failures and crashes are not edge cases — they're routine. Design assuming requests will fail mid-flight.

---

## Memorize This Senior Mantra

When asked about money or transactions:

1. **Double-entry. Always.**
2. **Decimal/integer storage. Never float.**
3. **Idempotency. Mandatory.**
4. **Atomic transactions for state changes.**
5. **Reconcile periodically. Trust nothing.**
6. **Audit trail forever. Never delete.**

Seven words: never float, double-entry, idempotency, reconcile.
