# Worst Case Scenarios — Senior Engineer Playbook

**Purpose:** Be ready for "what would you do if X breaks?" questions. These are common in senior interviews. The interviewer is testing your incident-response thinking, not just your knowledge.

---

## Table of Contents

1. [Production Outage Scenarios](#production-outage-scenarios)
2. [Database Catastrophes](#database-catastrophes)
3. [Security Incidents](#security-incidents)
4. [Performance Collapses](#performance-collapses)
5. [Data Loss and Corruption](#data-loss-and-corruption)
6. [Deployment Disasters](#deployment-disasters)
7. [Third-Party Failures](#third-party-failures)
8. [Concurrency Hell](#concurrency-hell)
9. [Money and Financial System Disasters](#money-and-financial-system-disasters)
10. [The Senior Engineer Incident Playbook](#the-senior-engineer-incident-playbook)

---

## The General Framework for Any Disaster Question

When asked "what would you do if X happens?", structure your answer in five steps:

1. **Stop the bleeding** — reduce immediate user impact
2. **Diagnose** — gather data, do not guess
3. **Mitigate** — short-term fix
4. **Resolve** — actual root cause fix
5. **Prevent** — what changes so this never happens again

Always mention all five. This is the senior signal.

---

## Production Outage Scenarios

### Q1. The site is down. Users cannot log in. What do you do?

**Senior Answer:**

**Step 1 — Stop the bleeding:**
- Check if it's truly down or partial — load balancer, status page, monitoring
- If site is fully down, attempt a rollback to last known good version
- Communicate to users (status page, banner, email)

**Step 2 — Diagnose:**
- Check error logs first — most outages leave a trace
- Check infrastructure metrics — CPU, memory, DB connections
- Check recent deploys — most outages happen within 30 minutes of a deploy
- Check third-party services — auth providers, payment, DNS

**Step 3 — Mitigate:**
- If recent deploy → rollback
- If DB connection saturation → restart pool / reduce workers
- If auth provider → switch to fallback or buy time with a banner

**Step 4 — Resolve:**
- Find the root cause (the bad commit, the missing index, the leaked connection)
- Fix it properly with tests
- Deploy with verification

**Step 5 — Prevent:**
- Post-mortem (blameless)
- Add monitoring alerts that would have caught this earlier
- Add automated tests for the failure mode

**Communication style:** "First I check what users actually experience, then I gather signals, then I act. I do not change things based on guesses while the system is on fire."

---

### Q2. The API is responding slowly. 95th percentile latency is 8 seconds.

**Senior Answer:**

Look at the latency distribution first — is it across all endpoints or just one?

**If one endpoint:**
- Likely a slow query, missing index, N+1, or external API call
- Check the query plan: `EXPLAIN ANALYZE`
- Check application traces (APM tool)

**If all endpoints:**
- Likely infrastructure: DB connection saturation, CPU at 100%, memory pressure causing GC pauses, network issues
- Check if traffic spike → scale horizontally
- Check connection pool — exhausted pool = queueing

**Common culprits in order of frequency:**
1. Missing or stale database index
2. N+1 query introduced by recent code
3. External API call that suddenly got slow (no timeout set)
4. Background job stealing CPU
5. Memory leak causing GC thrashing
6. Network/DNS issue

---

### Q3. CPU is at 100% on production servers. What's your move?

**Senior Answer:**

1. Check what process is using CPU — is it the app or something else?
2. If app, capture a profile or thread dump
3. Common causes:
   - Infinite loop in code (check recent deploy)
   - Cryptography (bcrypt cost too high under load)
   - Regex backtracking (ReDoS)
   - JSON parsing of huge payloads
   - Image/PDF processing without offloading
4. Short-term: scale horizontally (add instances) and rate-limit the trigger
5. Long-term: fix the hot code path, move CPU work to background workers

---

### Q4. The site works but feels slow only for some users. What's happening?

**Senior Answer:**

Likely **regional or user-segment specific**:
- CDN cache miss in their region
- Slow database replica in their region
- Country-specific third-party service blocked
- Their user has a much larger dataset (e.g., 10K saved items vs typical 50)
- Cold start on serverless if their region has low traffic

**Approach:**
- Filter logs by user/region/session ID
- Reproduce with their account if possible
- Check if it's data-volume-related (the "power user" problem)

**Famous case:** A feature works fine for 99% of users but is unusable for the 1% with the most data. Pagination wasn't applied. Add it.

---

## Database Catastrophes

### Q5. The database is at 100% CPU and connections are timing out. What now?

**Senior Answer:**

**Immediate (stop bleeding):**
1. `pg_stat_activity` (Postgres) or `SHOW PROCESSLIST` (MySQL) — identify the slow queries
2. Kill the worst offenders if safe
3. Increase max connections temporarily (only if not memory-constrained)
4. Reject new long-running queries via app-side timeout

**Diagnose:**
- Is one query hammering the DB? (analytics, search, full-table scan)
- Did a query plan change because of stale stats?
- Is a missing index causing seq scans on a big table?
- Did someone deploy a new ORM query that's accidentally an N+1?
- Is it a lock storm? (long-running transaction holding locks)

**Mitigate:**
- Add the missing index (CONCURRENTLY in Postgres so it doesn't lock)
- Refactor the bad query
- Move heavy reads to a replica

**Prevent:**
- Slow query log alerts (>1s = alert)
- pgBadger or similar tools to analyze patterns
- Query budget per request enforced in code

---

### Q6. The database is corrupt. Some rows have wrong data. What do you do?

**Senior Answer:**

1. **STOP writes immediately** if corruption is spreading
2. **Snapshot current state** before any fix attempts
3. **Identify the bug** — corrupt data has a cause (race condition, bad migration, code bug)
4. **Quantify the damage** — how many rows, how much money, how many users
5. **Restore strategy:**
   - Point-in-time restore from backup (if before corruption started)
   - Reconstruct from event log / audit log
   - Manual correction with verification
6. **Communicate** — affected users need to know
7. **Prevent** — add constraint, add test, fix the cause

**Critical rule:** Never edit production data with raw SQL during an incident without:
- A backup
- A second engineer reviewing the SQL
- A `BEGIN;` and explicit `COMMIT;` (so you can `ROLLBACK;`)
- A `SELECT` first to verify the WHERE clause matches expected rows

---

### Q7. Replica lag is now 30 minutes and growing. What's wrong?

**Senior Answer:**

**Possible causes:**
- A massive write on the primary (bulk insert, ALTER TABLE)
- Replica is undersized vs primary
- Network bottleneck between primary and replica
- A long-running query on the replica blocking replay (Postgres)
- Cascading replica chain has a slow link

**Mitigations:**
- If replica is read-routed for users, fail back reads to primary temporarily (knowing it'll add load)
- Identify the slow operation and stop it if possible
- Resize replica or add more replicas

**Senior point:** Lag is not just a number — it's a correctness issue. If users read from a lagged replica, they see stale data. In banking, this is a bug. In feed-style apps, it's tolerable.

---

### Q8. A migration is taking 4 hours on production and locks the table.

**Senior Answer:**

This is a deploy disaster. Common causes:
- `ALTER TABLE ADD COLUMN NOT NULL DEFAULT ...` on a 50M-row table (rewrites the whole table)
- Adding a unique index on a non-unique column
- Foreign key check on a huge table

**Recovery:**
- Cancel the migration if reversible
- Run during low-traffic window if not reversible
- Use online migration tools: `gh-ost`, `pt-online-schema-change` (MySQL), `pg_repack` for some Postgres cases

**The right way (next time):**
- Make migrations small and reversible
- Add columns as NULLable, backfill in batches, then add NOT NULL
- Use `CREATE INDEX CONCURRENTLY` (Postgres) — does not lock writes
- Test migration on a production-sized snapshot before running for real

---

## Security Incidents

### Q9. We're under a credential stuffing attack. Login attempts are flooding.

**Senior Answer:**

**Stop bleeding:**
- Add aggressive rate limiting on `/login` (e.g., 5 attempts per IP per minute)
- Add captcha after 3 failed attempts
- Block known malicious IPs (use IP reputation services)
- Add a delay (200-500ms) on failed login responses to slow attackers

**Diagnose:**
- How many accounts compromised? Check successful logins from new IPs
- Look at password reuse — were these credentials leaked elsewhere?

**Resolve:**
- Force password reset for affected accounts
- Notify users
- Add MFA option / require for admin accounts

**Prevent:**
- Use HaveIBeenPwned API on password creation to reject leaked passwords
- Implement device-based auth (remember-me with device fingerprint)
- Geographic anomaly detection
- WAF rules

---

### Q10. SQL injection found in production. What now?

**Senior Answer:**

**Immediate:**
1. Patch the vulnerable endpoint — replace string concatenation with parameterized queries
2. If the vulnerability is exploitable in seconds, deploy WAF rule blocking the pattern as temporary shield
3. Audit logs to see if it was exploited
4. Check what data the attacker could access

**Damage assessment:**
- What tables could be read?
- What data could be modified?
- Are there backups predating any modification?

**Resolution:**
- Code review every SQL in the codebase for similar issues
- Add static analysis (e.g., `bandit`, `gitleaks`, `semgrep`) to CI
- Train team on parameterized queries

**Communicate:** If user data leaked, comply with breach disclosure laws.

---

### Q11. We discovered passwords are stored in plaintext in our database. Now what?

**Senior Answer:**

This is a critical incident.

1. **Stop further damage:** disable any code paths that can read these passwords
2. **Force password reset for all users** — old passwords cannot be trusted
3. **Migrate to proper hashing:** bcrypt with cost factor 12+ (or Argon2id)
4. **Audit:** who had DB access? Who could have read these passwords?
5. **Disclose:** depending on jurisdiction, this is a reportable breach
6. **Implement:** never store passwords. Hash + salt with bcrypt/Argon2.

**Code pattern (correct way):**

```js
// Store
const hash = await bcrypt.hash(password, 12);

// Verify
const valid = await bcrypt.compare(password, user.passwordHash);
```

---

### Q12. Auth bypass discovered — a user can access another user's data.

**Senior Answer:**

**Immediate:**
- Roll back the affected endpoint or feature
- Audit logs to find affected users
- Reset session tokens / force re-auth

**Diagnose root cause:**
- Most common: trusting client-supplied IDs without verifying ownership
- Second most common: incorrect SQL filter (missing `WHERE user_id = current_user`)
- Third: improperly configured RBAC

**Fix:**
- Server-side ownership check in EVERY endpoint that accesses user data
- Authorization at the data layer (RLS in Postgres, or repository-level filters)
- Add automated tests for cross-tenant access — try to access user B's data as user A and assert 403

**The rule:** Never trust the client. Authenticate the user, then derive what they can access from server-side data.

---

## Performance Collapses

### Q13. After deploying, response time tripled. We need to fix it now.

**Senior Answer:**

1. **Rollback if possible** — restore service first, debug after
2. **If can't rollback** (DB migration, etc.): identify what changed
3. **Use a profiler / APM** — find the slowest endpoint or query
4. **Common deploy regressions:**
   - New ORM query introduced N+1
   - New feature loaded too much data per request
   - New library has higher overhead
   - Caching was removed accidentally
   - Synchronous call to a slow service
5. **Patch fast, deploy fast, monitor**

---

### Q14. Memory usage is growing slowly until the app crashes (memory leak). How do you debug?

**Senior Answer:**

**For Node.js:**
- Use `--inspect` and Chrome DevTools heap snapshot
- Take 3 snapshots over time, compare growing object types
- Common leaks: event listeners not removed, closures holding large objects, caches without TTL, global maps that only grow

**For PHP:**
- Look for static caches not cleared
- ORMs that hold object identity maps (Doctrine, Eloquent collections)
- Long-running CLI scripts (workers) that don't reset state

**For Java/JVM:**
- `jmap` for heap dump
- Eclipse MAT to analyze
- Common: `static List` accumulating, ThreadLocal not cleared

**Mitigation while you debug:**
- Recycle workers periodically (every 1000 requests)
- Increase memory temporarily
- Restart on schedule

---

### Q15. We have an N+1 query and don't know which endpoint.

**Senior Answer:**

**Detect:**
- Use `pg_stat_statements` to find queries called many times
- APM tools (New Relic, Datadog) show this at the request level
- Most ORMs have logging modes that count queries per request — enable in dev

**Pattern to look for:**
- Loop iterating over a collection, fetching related data per item
- Lazy loading on a collection in a template

**Fix:**
- Eager loading: `Model.includes(:relation)` (Rails), `with(['relation'])` (Laravel), `joinedload` (SQLAlchemy)
- Or batch the queries: fetch all IDs, fetch all related in one query, then map in memory

---

## Data Loss and Corruption

### Q16. A developer ran `DELETE FROM users` without a WHERE clause. What now?

**Senior Answer:**

**This is a "stop and don't panic" moment.**

1. **Did they commit?** If still in transaction → `ROLLBACK;` immediately
2. **If committed:** Restore from the most recent backup
   - If point-in-time recovery is enabled, restore to the moment before the DELETE
3. **For the lost data between last backup and DELETE:**
   - Application logs may have user activity
   - Audit tables (if enabled) may have inserts
   - Replicas may not have replayed yet (slim chance)
   - WAL archives (Postgres) have all changes — replay them

**Prevent:**
- Production DB access requires 2-person review for destructive queries
- Use a query tool that requires explicit `LIMIT` or `WHERE` for DELETE/UPDATE
- Always backup before bulk operations
- `DELETE` requires soft-delete by default in app code; raw DELETE is a flag

---

### Q17. Backups exist but have never been tested. Now we need to restore.

**Senior Answer:**

This is the classic "untested backup is no backup" problem.

1. Restore to a non-production environment first
2. Verify the data is consistent and recent
3. Time the restore — know how long it takes
4. **Add to runbook:** monthly restore drills

**Senior insight:** A backup you have never restored is hope, not a strategy. Senior engineers test restores quarterly minimum.

---

### Q18. We deployed a migration that wiped a column. How to recover?

**Senior Answer:**

1. Stop writes to the affected table if recovery is possible
2. Restore from backup to a separate database
3. Copy the column data from backup to production
4. Verify integrity (counts, checksums)
5. Resume writes

**Prevent:**
- Migration code review with another engineer
- Migrations should never use `DROP COLUMN` directly — they should `RENAME` to `_deprecated_<col>` first, then `DROP` in a later migration after verifying no impact
- Same rule for `DROP TABLE`

---

## Deployment Disasters

### Q19. The deploy failed halfway. Some servers have new code, some have old. Behavior is mixed.

**Senior Answer:**

This is a partial deploy state — very dangerous.

1. **Choose a direction:** finish the deploy or rollback. Do not stay in mixed state.
2. **If finishing:** disable the load balancer for old-version servers, deploy them, re-enable
3. **If rolling back:** rollback all servers, including ones that succeeded
4. **Lesson:** deployments should be atomic per environment. Use blue/green, canary, or rolling deploy with health checks that auto-rollback on failure.

**Prevent:**
- Health check endpoint that fails if new version is broken
- Deploy stops automatically on health check failure
- Pre-deploy verification: smoke tests in staging

---

### Q20. We deployed and now the database can't connect. The connection string was wrong.

**Senior Answer:**

1. Rollback the config change
2. If it was a secret rotation, rotate again to the right value
3. **Lesson learned:** secrets and config should be tested in a staging environment first

**Senior Engineer Pattern:**
- Use a config validation step at startup that fails fast with a clear message
- Don't read secrets only when needed — read at boot and crash if missing or unreachable
- This way, deploys fail fast instead of silently breaking later

---

### Q21. The deploy "succeeded" but a feature is broken. Tests pass.

**Senior Answer:**

Tests passed but reality didn't. Why?

- Tests use mocks; real integration broken
- Test data doesn't match production data shape
- Tests run against in-memory DB, but production has different DB version
- Migration that ran in tests was different from production
- Feature flag set differently in production
- Environment variable mismatch

**Fix the feature first** (rollback or hotfix), then **fix the test gap**:
- Add an integration test that reproduces the bug
- Add a smoke test in staging that exercises the feature end-to-end
- Pre-prod environment should mirror prod for critical paths

---

## Third-Party Failures

### Q22. The payment provider is down. We're losing transactions.

**Senior Answer:**

**Architecture must handle this in advance:**
- Queue payment requests when provider is down
- Retry with exponential backoff
- Have a fallback provider for critical paths
- Communicate clearly to users — "Payment processing is delayed, you'll be charged when service resumes"
- Idempotency keys ensure no double-charge on retry

**Right now:**
- Show users a clear message
- Queue intent (with idempotency key)
- Process when provider returns
- Monitor and verify all queued requests eventually complete

---

### Q23. An external API we depend on changed without notice. Things break.

**Senior Answer:**

1. Identify the affected calls quickly
2. Adapt the request/response handling to the new API
3. **Long-term:** never depend on a third party without:
   - A circuit breaker pattern (so their outage doesn't take you down)
   - A timeout (no API call should hang forever)
   - A fallback or graceful degradation
   - A version pin if available

---

### Q24. Email provider is rejecting our emails as spam. Users miss password resets.

**Senior Answer:**

1. Switch to a backup provider for transactional emails
2. Diagnose why current provider flagged us:
   - Sender reputation (IP/domain)
   - Content (links, unusual words, missing unsubscribe)
   - Recipient signals (high bounce rate, complaints)
3. Set up SPF, DKIM, DMARC properly
4. Use a separate sending domain for transactional vs marketing
5. Monitor delivery rate as a metric

---

## Concurrency Hell

### Q25. Two users update the same record at the same time. One overwrites the other.

**Senior Answer:**

This is the classic lost update problem.

**Solutions:**

1. **Optimistic locking:**
```sql
UPDATE orders SET status = 'shipped', version = version + 1
WHERE id = ? AND version = ?
```
If 0 rows affected, the version was stale → return conflict to user

2. **Pessimistic locking:**
```sql
SELECT ... FOR UPDATE
-- modify
UPDATE ...
COMMIT
```

3. **Application-level merge:** show conflict to user (like Google Docs)

**Default: optimistic locking with a `version` column. Use pessimistic only when conflicts are frequent.**

---

### Q26. A background job ran twice on the same record. Side effects happened twice.

**Senior Answer:**

**Idempotency is the answer.**

- Each operation has an idempotency key
- Server checks if key was processed before
- If yes, return cached result, don't re-execute

**Implementation patterns:**

```js
async function processPayment(orderId, idempotencyKey) {
  const existing = await db.idempotency.findOne({ key: idempotencyKey });
  if (existing) return existing.result;
  
  const result = await paymentProvider.charge(...);
  await db.idempotency.insert({ key: idempotencyKey, result });
  return result;
}
```

For background jobs:
- Job queue must guarantee at-least-once delivery (most do)
- Worker must be idempotent
- Use a unique job_id and check before processing

---

### Q27. A race condition causes incorrect inventory counts.

**Senior Answer:**

**Wrong (race condition):**
```js
const item = await db.inventory.findById(id);
if (item.stock > 0) {
  item.stock -= 1;
  await db.inventory.update(item);
}
```

**Right (atomic):**
```js
// Atomic decrement that won't go below zero
const result = await db.query(
  `UPDATE inventory 
   SET stock = stock - 1 
   WHERE id = $1 AND stock > 0`,
  [id]
);
if (result.rowCount === 0) {
  throw new OutOfStockError();
}
```

Or use a database transaction with `SELECT ... FOR UPDATE`.

---

### Q28. A deadlock keeps happening between two transactions.

**Senior Answer:**

**Cause:** Transaction A holds lock on row 1, waits for lock on row 2. Transaction B holds lock on row 2, waits for lock on row 1. Database detects and aborts one.

**Fix:**
1. Always acquire locks in the same order (e.g., always update by ID ascending)
2. Reduce transaction scope — keep transactions short
3. Use lower isolation level if business allows
4. Catch deadlock errors and retry the transaction

```js
async function withDeadlockRetry(fn, maxAttempts = 3) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      return await fn();
    } catch (e) {
      if (e.code === 'DEADLOCK' && i < maxAttempts - 1) continue;
      throw e;
    }
  }
}
```

---

## Money and Financial System Disasters

### Q29. A bug double-charged customers. What now?

**Senior Answer:**

**Critical sequence:**

1. **Stop the bleeding:** disable the buggy code path immediately
2. **Quantify:** how many customers, how much money?
3. **Communicate:** transparency early — "We discovered an issue, we're investigating"
4. **Refund automatically:** don't make customers ask
5. **Audit:** verify refunds completed for all affected
6. **Prevent:**
   - Idempotency key on every charge
   - Audit log of every payment
   - Alerts on duplicate charge patterns
   - Test the duplicate-charge case explicitly

**The rule:** money operations must be idempotent. Always.

---

### Q30. Sum of all account balances doesn't match the ledger total. There's $50K missing.

**Senior Answer:**

This is an integrity violation. Senior approach:

1. **Freeze writes** to affected accounts if the discrepancy is growing
2. **Audit the journal** — every transaction should debit one account and credit another (double-entry)
3. **Find the gap:** which transaction broke the rule?
4. **Restore consistency:** correct the books with a tracked adjustment entry, not by editing balances directly
5. **Prevent:** every financial change must go through a `journal_entries` table with both sides recorded atomically. Never update balances directly — derive them from journal entries.

**Senior pattern (double-entry bookkeeping):**

```sql
CREATE TABLE journal_entries (
  id BIGSERIAL PRIMARY KEY,
  transaction_id UUID NOT NULL,
  account_id INTEGER NOT NULL,
  amount NUMERIC(19, 4) NOT NULL,  -- positive = debit, negative = credit
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Constraint: every transaction_id sums to zero
-- Verified by reconciliation job
```

---

### Q31. Floats were used to store money. Customers are over/undercharged by pennies.

**Senior Answer:**

This is the classic floating-point trap.

**Why it's wrong:**
```js
0.1 + 0.2 === 0.3  // false (it's 0.30000000000000004)
```

**Fix:**
- Store money as integer cents (or smallest unit), or use `decimal/numeric` SQL types
- In Node: `Decimal.js` or `bignumber.js`
- In PHP: `bcmath` or `Brick\Math`
- In Postgres: `NUMERIC(19, 4)` with strict precision

**Migration plan:**
- Add new column `amount_cents BIGINT`
- Backfill from existing floats with rounding rule applied
- Switch reads/writes to new column
- Drop old column
- Reconcile and refund any errors

---

### Q32. We need to refund 1000 customers because of a bug. What's the safest way?

**Senior Answer:**

1. **Identify exact list** with audit trail
2. **Calculate exact refund amount per customer** — verify against original transaction, not your bug calculation
3. **Test the refund process** on 1-2 internal accounts first
4. **Run in batches** — 50 at a time, with verification
5. **Reconcile** — total refunded should equal total over-charged
6. **Communicate** — proactive email to each affected customer
7. **Document** — incident report, timeline, what's being done

Never bulk-refund 1000 customers in a single command without batching and verification.

---

## The Senior Engineer Incident Playbook

When you face a real (or interview) incident, follow this:

### Phase 1: Triage (first 5 minutes)
- Is this user-facing? How many users?
- Is data being lost or corrupted?
- Is money flowing incorrectly?
- Severity: P0 (everyone broken), P1 (some broken), P2 (degraded)

### Phase 2: Communicate (next 5 minutes)
- Internal: tell the team, dedicate an incident commander
- External: status page update if user-facing
- Customer support: brief them so they can answer

### Phase 3: Mitigate (next 30 minutes)
- Reduce immediate impact
- Rollback, feature flag off, throttle, etc.
- Bias toward action that's reversible

### Phase 4: Diagnose (parallel)
- Logs, metrics, traces
- Talk to the engineer who deployed last
- Don't fix anything yet — understand first

### Phase 5: Resolve (after diagnosis)
- Root-cause fix
- Test, deploy, verify
- Monitor for recurrence

### Phase 6: Post-mortem (within a week)
- Blameless write-up
- Timeline
- Root cause + contributing factors
- Action items with owners

**Senior signal:** You don't just say "I'd fix it." You walk through the phases.

---

## Memorization Card

For any "what if X breaks?" question, hit these notes:

1. **Acknowledge the user impact**: "Users can't [X]"
2. **Stop bleeding**: short-term mitigation
3. **Don't guess**: gather data
4. **Communicate**: internal + external
5. **Root cause**: not just symptoms
6. **Prevent**: tests, monitors, process changes

If you say all six, you sound senior.
