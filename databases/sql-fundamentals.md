# SQL Fundamentals — Basic to Advanced

**Purpose:** Master the SQL knowledge required for senior backend interviews. Covers from basics to complex query patterns, indexing, transactions, and database internals.

---

## Table of Contents

1. [SQL Basics](#sql-basics)
2. [Joins — Deep Dive](#joins--deep-dive)
3. [Aggregations and Grouping](#aggregations-and-grouping)
4. [Subqueries and CTEs](#subqueries-and-ctes)
5. [Window Functions](#window-functions)
6. [Indexes — How They Work](#indexes--how-they-work)
7. [Transactions and Concurrency](#transactions-and-concurrency)
8. [Normalization and Denormalization](#normalization-and-denormalization)
9. [Query Optimization](#query-optimization)
10. [Common Interview Query Patterns](#common-interview-query-patterns)
11. [Advanced Topics](#advanced-topics)

---

## SQL Basics

### Q1. What is SQL?

**Answer:** Structured Query Language. A declarative language for querying and managing relational databases. You describe *what* you want, the database engine figures out *how* to get it.

---

### Q2. What are the SQL command categories?

| Category | Commands | Purpose |
|----------|----------|---------|
| DDL | CREATE, ALTER, DROP, TRUNCATE | Define schema |
| DML | INSERT, UPDATE, DELETE | Modify data |
| DQL | SELECT | Query data |
| DCL | GRANT, REVOKE | Permissions |
| TCL | BEGIN, COMMIT, ROLLBACK, SAVEPOINT | Transaction control |

---

### Q3. Basic SELECT structure?

```sql
SELECT column1, column2
FROM table_name
WHERE condition
GROUP BY column
HAVING group_condition
ORDER BY column ASC|DESC
LIMIT 10 OFFSET 0;
```

**Execution order (logical):**
1. FROM (and JOINs)
2. WHERE
3. GROUP BY
4. HAVING
5. SELECT
6. DISTINCT
7. ORDER BY
8. LIMIT / OFFSET

This is why you can use a column in WHERE but not an alias from SELECT — SELECT runs after WHERE.

---

### Q4. Difference between WHERE and HAVING?

- **WHERE** filters rows before grouping
- **HAVING** filters after grouping (works on aggregate results)

```sql
SELECT department, COUNT(*) AS emp_count
FROM employees
WHERE active = true        -- per-row filter
GROUP BY department
HAVING COUNT(*) > 5;       -- per-group filter
```

---

### Q5. Difference between DELETE, TRUNCATE, DROP?

| Command | What it does | Reversible? | Resets identity? |
|---------|--------------|-------------|------------------|
| DELETE | Removes rows matching WHERE | Yes (with rollback in transaction) | No |
| TRUNCATE | Removes all rows fast | No (usually no rollback) | Yes |
| DROP | Removes the table | No | N/A |

DELETE fires triggers; TRUNCATE typically doesn't.

---

### Q6. Difference between UNION and UNION ALL?

- **UNION** removes duplicates (slower)
- **UNION ALL** keeps duplicates (faster)

Use UNION ALL unless you specifically need duplicates removed.

---

### Q7. Difference between IN and EXISTS?

```sql
-- IN: checks if value is in a list
SELECT * FROM users WHERE id IN (1, 2, 3);
SELECT * FROM users WHERE id IN (SELECT user_id FROM orders);

-- EXISTS: checks if subquery returns any row
SELECT * FROM users u WHERE EXISTS (
  SELECT 1 FROM orders o WHERE o.user_id = u.id
);
```

**Performance:** EXISTS often faster on large subqueries because it short-circuits on first match. Modern optimizers may execute them similarly.

**Functional difference:** IN with NULL behaves unexpectedly:
```sql
WHERE id NOT IN (1, 2, NULL)  -- always returns 0 rows!
```
Use NOT EXISTS instead when nulls are possible.

---

## Joins — Deep Dive

### Q8. Explain all the join types.

| Join | Returns |
|------|---------|
| INNER JOIN | Only matching rows from both tables |
| LEFT JOIN | All rows from left, matching from right (NULL if no match) |
| RIGHT JOIN | All rows from right, matching from left |
| FULL OUTER JOIN | All rows from both, NULL where no match |
| CROSS JOIN | Cartesian product — every row × every row |
| SELF JOIN | Table joined to itself (employees → manager hierarchy) |

```sql
-- INNER
SELECT u.name, o.total
FROM users u INNER JOIN orders o ON o.user_id = u.id;

-- LEFT (find users with no orders)
SELECT u.name
FROM users u LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;

-- SELF
SELECT e.name AS employee, m.name AS manager
FROM employees e LEFT JOIN employees m ON e.manager_id = m.id;
```

---

### Q9. Is there a difference between LEFT JOIN and LEFT OUTER JOIN?

No. "OUTER" is optional. `LEFT JOIN` and `LEFT OUTER JOIN` are identical.

---

### Q10. What happens with multiple LEFT JOINs?

```sql
SELECT u.name, o.total, p.name
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
LEFT JOIN order_items oi ON oi.order_id = o.id
LEFT JOIN products p ON p.id = oi.product_id;
```

Each LEFT JOIN preserves all rows from the previous result. A user with no orders still appears (with NULLs for o, oi, p columns). Watch for **row multiplication** when joining one-to-many → counts get distorted.

---

### Q11. What's the row multiplication problem?

When you join a table with multiple matches per row, you multiply rows.

```sql
-- 1 user has 3 orders, joining gives 3 rows for that user
SELECT u.name, COUNT(o.id) AS order_count
FROM users u JOIN orders o ON o.user_id = u.id
GROUP BY u.id, u.name;
```

If you JOIN both orders AND comments per user, COUNT becomes wrong (3 orders × 5 comments = 15 instead of 3 + 5).

**Fix:** subqueries or COUNT(DISTINCT).

```sql
SELECT u.name,
       COUNT(DISTINCT o.id) AS order_count,
       COUNT(DISTINCT c.id) AS comment_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
LEFT JOIN comments c ON c.user_id = u.id
GROUP BY u.id, u.name;
```

---

## Aggregations and Grouping

### Q12. What are aggregate functions?

`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `STDDEV`, `VARIANCE`.

```sql
SELECT 
  COUNT(*) AS total_rows,
  COUNT(DISTINCT user_id) AS unique_users,
  SUM(amount) AS total_revenue,
  AVG(amount) AS avg_order,
  MAX(created_at) AS latest_order
FROM orders;
```

`COUNT(*)` counts all rows. `COUNT(column)` skips NULLs. `COUNT(DISTINCT column)` counts unique non-null values.

---

### Q13. How does GROUP BY work?

Buckets rows by the GROUP BY columns, then applies aggregates per bucket.

```sql
SELECT category, COUNT(*) AS product_count, AVG(price) AS avg_price
FROM products
GROUP BY category;
```

**Rule:** every column in SELECT must be in GROUP BY OR be inside an aggregate.

---

### Q14. What is GROUP BY with multiple columns?

```sql
SELECT category, brand, SUM(stock)
FROM products
GROUP BY category, brand;
```

Buckets are formed by unique combinations of (category, brand).

---

### Q15. What is GROUPING SETS / ROLLUP / CUBE?

Advanced grouping for multi-level aggregates in one query.

```sql
-- ROLLUP — hierarchical totals
SELECT category, brand, SUM(stock)
FROM products
GROUP BY ROLLUP(category, brand);
-- Returns: per (category, brand), per category, grand total

-- CUBE — all combinations of dimensions
GROUP BY CUBE(category, brand);
-- Returns: per (cat, brand), per cat, per brand, grand total

-- GROUPING SETS — explicit
GROUP BY GROUPING SETS ((category), (brand), ());
```

---

## Subqueries and CTEs

### Q16. What is a subquery?

A query nested inside another query.

```sql
-- In WHERE
SELECT * FROM users
WHERE id IN (SELECT user_id FROM orders WHERE total > 1000);

-- In SELECT (correlated)
SELECT u.name, (SELECT COUNT(*) FROM orders WHERE user_id = u.id) AS orders
FROM users u;

-- In FROM (derived table)
SELECT category, max_price
FROM (SELECT category, MAX(price) AS max_price FROM products GROUP BY category) AS x;
```

---

### Q17. What is a CTE (Common Table Expression)?

Named temporary result, defined with `WITH`. More readable than nested subqueries.

```sql
WITH active_users AS (
  SELECT id, name FROM users WHERE active = true
),
recent_orders AS (
  SELECT user_id, total FROM orders WHERE created_at > NOW() - INTERVAL '7 days'
)
SELECT u.name, SUM(o.total) AS spent
FROM active_users u
JOIN recent_orders o ON o.user_id = u.id
GROUP BY u.name;
```

---

### Q18. What is a recursive CTE?

A CTE that references itself. Used for tree/graph traversal.

```sql
-- Find all descendants of category id 1
WITH RECURSIVE category_tree AS (
  SELECT id, name, parent_id
  FROM categories
  WHERE id = 1                              -- base case
  
  UNION ALL
  
  SELECT c.id, c.name, c.parent_id
  FROM categories c
  JOIN category_tree ct ON c.parent_id = ct.id  -- recursive case
)
SELECT * FROM category_tree;
```

Uses: org charts, comment threads, dependency graphs, file systems.

---

### Q19. CTE vs subquery — which to use?

- **CTE:** more readable, can be referenced multiple times in same query, supports recursion
- **Subquery:** simpler for single use

Modern databases optimize both similarly. Choose by readability.

---

## Window Functions

### Q20. What is a window function?

Like aggregates, but they don't collapse rows. Each row gets a value computed over a "window" of related rows.

```sql
SELECT 
  name,
  department,
  salary,
  AVG(salary) OVER (PARTITION BY department) AS dept_avg,
  RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
FROM employees;
```

| name | department | salary | dept_avg | rank_in_dept |
|------|-----------|--------|----------|--------------|
| Alice | Eng | 90K | 80K | 1 |
| Bob | Eng | 80K | 80K | 2 |
| Carol | Eng | 70K | 80K | 3 |

---

### Q21. Common window functions?

- `ROW_NUMBER()` — sequential number within partition
- `RANK()` — rank with gaps for ties (1, 2, 2, 4)
- `DENSE_RANK()` — rank without gaps (1, 2, 2, 3)
- `LAG(col, n)` — previous row value
- `LEAD(col, n)` — next row value
- `FIRST_VALUE(col)`, `LAST_VALUE(col)` — first/last in window
- `SUM/AVG/COUNT(...) OVER (...)` — running aggregates

```sql
-- Running total of orders per user
SELECT 
  user_id, created_at, total,
  SUM(total) OVER (PARTITION BY user_id ORDER BY created_at) AS running_total
FROM orders;

-- Compare each row to previous
SELECT 
  date, revenue,
  LAG(revenue) OVER (ORDER BY date) AS prev_day,
  revenue - LAG(revenue) OVER (ORDER BY date) AS day_change
FROM daily_revenue;
```

---

### Q22. Solve "find the second highest salary"

```sql
-- Method 1: window function
SELECT salary FROM (
  SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
  FROM employees
) t WHERE rnk = 2;

-- Method 2: subquery
SELECT MAX(salary) FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);

-- Method 3: LIMIT/OFFSET
SELECT DISTINCT salary FROM employees
ORDER BY salary DESC
LIMIT 1 OFFSET 1;
```

---

## Indexes — How They Work

### Q23. What is an index?

A data structure (usually a B-tree) that speeds up data retrieval at the cost of slower writes and extra storage.

Without an index, finding a row in a 10M-row table requires a full table scan. With an index on the search column, the database walks a tree (~log N steps).

---

### Q24. When should you add an index?

- Columns used in WHERE clauses
- Columns used in JOIN conditions
- Columns used in ORDER BY (if sorting expensively)
- Columns used in GROUP BY for very large tables
- Foreign key columns (most DBs don't auto-index these — MySQL does, Postgres doesn't)

**Don't add indexes on:**
- Columns rarely queried
- Tables with very few rows (full scan is fast anyway)
- Columns with low cardinality (boolean) — usually not helpful unless combined with another column
- Tables that are mostly written, rarely read

---

### Q25. What is a composite (multi-column) index?

An index on multiple columns. Order matters!

```sql
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
```

This index helps:
- `WHERE user_id = ?`
- `WHERE user_id = ? AND status = ?`

Does NOT help (or only partially):
- `WHERE status = ?` (without user_id)

**Rule of thumb:** put high-cardinality and equality-filtered columns first.

---

### Q26. What is index selectivity?

Selectivity = (distinct values) / (total rows). Higher selectivity = more useful index.

- Email column on users: usually unique → high selectivity → great index
- `is_active` boolean: 2 values → low selectivity → poor solo index, useful as part of composite

---

### Q27. What are the different types of indexes?

| Type | Use case |
|------|----------|
| B-tree | Default, equality and range queries |
| Hash | Equality only (PostgreSQL) |
| GIN / GiST | Full-text, JSON, geometry (PostgreSQL) |
| Bitmap | Low cardinality (Oracle) |
| Clustered | Physical order of table data (MySQL InnoDB primary key) |
| Covering | Index includes all columns needed by query — no table lookup needed |
| Partial | Index over a subset (`WHERE active = true`) |
| Unique | Enforces uniqueness, also serves as index |
| Full-text | Tokenized text search |

---

### Q28. What is a covering index?

An index that includes all columns the query needs, so the database doesn't have to look up the actual table row.

```sql
-- Query
SELECT user_id, status, total FROM orders WHERE user_id = 123;

-- Covering index
CREATE INDEX idx_covering ON orders (user_id) INCLUDE (status, total);
```

The query is served entirely from the index — fastest possible read.

---

### Q29. What's an index-only scan?

A scan that reads only the index, not the table. Possible when:
- All requested columns are in the index (or via INCLUDE)
- Postgres: visibility map indicates the page is all-visible

Major performance win for read-heavy queries.

---

### Q30. Why don't indexes always help?

- Optimizer chooses based on statistics — if it thinks a full scan is cheaper, it'll do that
- Functions on indexed columns: `WHERE LOWER(email) = ?` won't use index on `email` (use a functional index)
- LIKE patterns: `WHERE name LIKE '%john%'` won't use B-tree index (leading wildcard)
- Many predicates filtered: planner may pick a different index
- Stats are stale (run `ANALYZE`)

---

## Transactions and Concurrency

### Q31. What is a transaction?

A unit of work that is atomic — all operations succeed or none do.

```sql
BEGIN;
  UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
  UPDATE accounts SET balance = balance + 100 WHERE id = 'B';
  INSERT INTO transfers (from_id, to_id, amount) VALUES ('A', 'B', 100);
COMMIT;
-- ROLLBACK; on failure
```

---

### Q32. ACID properties?

| Letter | Meaning |
|--------|---------|
| Atomicity | All or nothing |
| Consistency | DB transitions from valid state to valid state |
| Isolation | Concurrent transactions don't interfere |
| Durability | Committed changes survive crashes |

---

### Q33. What are isolation levels?

| Level | Dirty Read | Non-Repeatable Read | Phantom Read |
|-------|-----------|---------------------|---------------|
| Read Uncommitted | Possible | Possible | Possible |
| Read Committed | Prevented | Possible | Possible |
| Repeatable Read | Prevented | Prevented | Possible (PG also prevents via MVCC) |
| Serializable | Prevented | Prevented | Prevented |

Postgres default: Read Committed. MySQL InnoDB default: Repeatable Read.

---

### Q34. What is `SELECT ... FOR UPDATE`?

Acquires a row-level lock so other transactions can't modify those rows until you commit.

```sql
BEGIN;
  SELECT * FROM accounts WHERE id = 'A' FOR UPDATE;
  -- Other transactions trying to update A will wait
  UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
COMMIT;
```

Essential for safe read-then-modify patterns.

---

### Q35. What is a deadlock?

Two transactions each hold a lock the other needs.

```
TX1: lock row A → wait for row B
TX2: lock row B → wait for row A
```

Database detects and aborts one. Application must retry.

**Prevention:** always acquire locks in same order (e.g., by ID ascending).

---

### Q36. What is MVCC?

Multi-Version Concurrency Control. Used by Postgres and others. Instead of locking rows for reads, keeps multiple versions. Each transaction sees a snapshot.

Benefit: readers don't block writers, writers don't block readers.

Cost: must clean up old versions (vacuum in Postgres).

---

## Normalization and Denormalization

### Q37. What is normalization?

Organizing data to reduce redundancy and improve integrity. Forms:

- **1NF:** atomic values (no lists in cells)
- **2NF:** 1NF + no partial dependency on a composite key
- **3NF:** 2NF + no transitive dependencies (non-key columns don't depend on other non-key columns)
- **BCNF:** stricter 3NF
- **4NF, 5NF:** further refinements

In practice, aim for 3NF for OLTP. Denormalize only when measured.

---

### Q38. When to denormalize?

- Read-heavy reports where joins are expensive
- Reporting tables / materialized views
- Caching aggregates (running totals, counts)
- Performance is verified to be a problem

Trade-off: faster reads, harder writes (you must keep duplicates in sync).

---

### Q39. Show a normalization example.

**Before (denormalized):**
```
orders: id | customer_name | customer_email | product_name | price
```

**After (normalized):**
```
customers: id | name | email
products: id | name | price
orders: id | customer_id | product_id
```

If the customer email changes, you change one row, not many.

---

## Query Optimization

### Q40. How do you optimize a slow query?

1. **EXPLAIN / EXPLAIN ANALYZE** — see the plan
2. Look for: full table scans, nested loops on big tables, missing indexes
3. Add appropriate index
4. Rewrite query — sometimes a JOIN is faster than a subquery (or vice versa)
5. Reduce returned columns (no `SELECT *`)
6. Reduce returned rows (`LIMIT`, pagination)
7. Update statistics (`ANALYZE`)
8. Consider denormalization, materialized views

---

### Q41. What does EXPLAIN show?

The query plan — how the database will execute the query.

```
Seq Scan on orders (cost=0.00..1500.00 rows=10000 width=64)
  Filter: (status = 'pending')
```

Key things to look at:
- **Seq Scan** — full table scan. Bad on large tables with selective filters.
- **Index Scan** — using an index. Usually good.
- **Index Only Scan** — best, no table lookup.
- **Nested Loop / Hash Join / Merge Join** — join algorithm
- **Rows estimate** — if very wrong, stats are stale
- **Cost** — relative cost units, lower = faster

---

### Q42. Common slow query patterns?

| Pattern | Fix |
|---------|-----|
| `SELECT *` | Select only needed columns |
| Missing WHERE | Add filter |
| `LIKE '%...'` | Full-text or trigram index |
| `OR` on different columns | Use UNION |
| Implicit type cast (`WHERE id = '123'`) | Match types |
| Function on column (`WHERE LOWER(email) = ?`) | Functional index or normalize |
| N+1 queries | Eager loading / single query |
| Unbounded result | Pagination |

---

### Q43. What is N+1 query problem?

A query that fetches a list, then runs additional queries for each item.

```js
const users = await db.query('SELECT * FROM users');     // 1 query
for (const user of users) {
  user.orders = await db.query(                            // N queries
    'SELECT * FROM orders WHERE user_id = $1', [user.id]
  );
}
// Total: 1 + N queries
```

**Fix:**
```js
// Option 1: single JOIN
const data = await db.query(`
  SELECT u.*, o.id AS order_id, o.total
  FROM users u LEFT JOIN orders o ON o.user_id = u.id
`);
// Then group in code

// Option 2: two queries
const users = await db.query('SELECT * FROM users');
const orders = await db.query(
  'SELECT * FROM orders WHERE user_id = ANY($1)',
  [users.map(u => u.id)]
);
// Then assemble in code
```

ORMs: use `eager loading` / `with` / `includes`.

---

## Common Interview Query Patterns

### Q44. Find duplicates

```sql
SELECT email, COUNT(*) AS count
FROM users
GROUP BY email
HAVING COUNT(*) > 1;
```

---

### Q45. Delete duplicates, keep one

```sql
-- Postgres
DELETE FROM users
WHERE id NOT IN (
  SELECT MIN(id)
  FROM users
  GROUP BY email
);

-- Or with row_number
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
  FROM users
)
DELETE FROM users WHERE id IN (SELECT id FROM ranked WHERE rn > 1);
```

---

### Q46. Top N per group

Find top 3 highest-paid employees per department:

```sql
WITH ranked AS (
  SELECT 
    e.*,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
  FROM employees e
)
SELECT * FROM ranked WHERE rn <= 3;
```

---

### Q47. Running total

```sql
SELECT 
  date, revenue,
  SUM(revenue) OVER (ORDER BY date) AS running_total
FROM daily_revenue;
```

---

### Q48. Pivot rows to columns

```sql
-- Postgres
SELECT
  product_id,
  SUM(CASE WHEN month = 1 THEN amount ELSE 0 END) AS jan,
  SUM(CASE WHEN month = 2 THEN amount ELSE 0 END) AS feb
FROM sales
GROUP BY product_id;

-- Postgres has crosstab() in tablefunc extension
```

---

### Q49. Find users with no orders

```sql
SELECT u.* FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;

-- Or
SELECT * FROM users
WHERE id NOT IN (SELECT user_id FROM orders WHERE user_id IS NOT NULL);

-- NOT EXISTS (safest with NULLs)
SELECT * FROM users u
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

---

### Q50. Date arithmetic

```sql
-- Orders in last 7 days
WHERE created_at >= NOW() - INTERVAL '7 days';

-- Group by day
SELECT DATE(created_at), COUNT(*) FROM orders GROUP BY DATE(created_at);

-- Group by month
SELECT DATE_TRUNC('month', created_at), SUM(total) FROM orders 
GROUP BY DATE_TRUNC('month', created_at);

-- Days between dates
SELECT created_at, completed_at, completed_at - created_at AS duration
FROM tasks;
```

---

### Q51. Self-join example — find pairs

Find all pairs of employees in same department:

```sql
SELECT e1.name, e2.name, e1.department
FROM employees e1
JOIN employees e2 ON e1.department = e2.department AND e1.id < e2.id;
```

The `e1.id < e2.id` avoids duplicate pairs and self-matches.

---

### Q52. Find consecutive records (gaps and islands)

Find date ranges of consecutive active days:

```sql
WITH grouped AS (
  SELECT date, 
    date - INTERVAL '1 day' * ROW_NUMBER() OVER (ORDER BY date) AS grp
  FROM activity
)
SELECT MIN(date) AS start_date, MAX(date) AS end_date
FROM grouped
GROUP BY grp;
```

---

## Advanced Topics

### Q53. What is a materialized view?

A view whose result is stored on disk. Faster reads, must be refreshed when underlying data changes.

```sql
CREATE MATERIALIZED VIEW daily_sales AS
SELECT DATE(created_at) AS day, SUM(total) AS revenue
FROM orders
GROUP BY DATE(created_at);

REFRESH MATERIALIZED VIEW daily_sales;
```

Use for: expensive aggregates that don't need to be real-time.

---

### Q54. What is a stored procedure?

A function-like object stored in the database. Can be called from app code.

```sql
CREATE OR REPLACE FUNCTION transfer_funds(
  p_from_id INT, p_to_id INT, p_amount NUMERIC
) RETURNS VOID AS $$
BEGIN
  UPDATE accounts SET balance = balance - p_amount WHERE id = p_from_id;
  UPDATE accounts SET balance = balance + p_amount WHERE id = p_to_id;
  INSERT INTO transfers (from_id, to_id, amount) VALUES (p_from_id, p_to_id, p_amount);
END;
$$ LANGUAGE plpgsql;
```

**Modern view:** keep business logic in application code where possible. Stored procedures hide logic from tests and version control. Use them for performance-critical or DB-only operations.

---

### Q55. What is a trigger?

Code that runs automatically on INSERT/UPDATE/DELETE.

```sql
CREATE TRIGGER update_modified_time
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();
```

Uses: timestamps, audit logs, denormalization sync.

**Caution:** triggers are invisible. Add complexity. Prefer explicit application logic when possible.

---

### Q56. What is a database transaction log (WAL/binlog)?

Sequential record of every change. Used for:
- Crash recovery
- Replication (streaming changes to replicas)
- Point-in-time recovery
- Change data capture (CDC)

Postgres: WAL (Write-Ahead Log). MySQL: binlog. Both can be tailed by tools like Debezium for streaming.

---

### Q57. What is sharding?

Splitting a table across multiple databases by some key (user_id, region). Used when one DB can't handle the load.

```
shard_key = hash(user_id) % 4
shard_0 → DB1
shard_1 → DB2
shard_2 → DB3
shard_3 → DB4
```

Trade-offs: scales writes/storage, complicates queries (cross-shard joins), rebalancing is hard.

---

### Q58. What is replication?

Copying data from a primary database to one or more replicas.

| Type | Description |
|------|-------------|
| Synchronous | Primary waits for replica acknowledgment before commit. Strong consistency, slower writes. |
| Asynchronous | Primary commits, replica catches up later. Lower latency, replica may lag. |
| Streaming (Postgres) | Primary streams WAL, replica replays. |
| Logical (Postgres) | Replicate specific tables, supports schema differences. |

---

### Q59. What is a database connection pool?

A pool of pre-opened DB connections. Application borrows, returns. Avoids the cost of opening a connection per request.

Settings: pool size, idle timeout, max lifetime, max waiting time.

Senior insight: pool size > worker count = wasted connections; pool size < worker count = queueing.

---

### Q60. What is OLTP vs OLAP?

- **OLTP (Online Transaction Processing):** many small reads/writes, low latency. PostgreSQL, MySQL.
- **OLAP (Online Analytical Processing):** complex aggregations over large datasets. Snowflake, BigQuery, Redshift, ClickHouse.

Different optimization strategies. OLTP normalizes; OLAP denormalizes (star schema, columnar storage).

---

## Common Interview Closing Questions

### Q61. How would you design a table for [user reviews / job applications / messages]?

**General checklist for any table design question:**
1. Identify entities and relationships
2. Choose primary keys (UUID or BIGSERIAL)
3. Add foreign keys with ON DELETE behavior
4. Add timestamps (`created_at`, `updated_at`)
5. Add soft delete if needed (`deleted_at`)
6. Add indexes on FK and frequently queried columns
7. Consider unique constraints
8. Think about scale — partition key if huge

---

### Q62. How do you handle SOFT DELETE?

```sql
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;

-- Queries must filter
SELECT * FROM users WHERE deleted_at IS NULL;

-- "Delete"
UPDATE users SET deleted_at = NOW() WHERE id = ?;

-- Restore
UPDATE users SET deleted_at = NULL WHERE id = ?;
```

Use partial index to speed up queries:
```sql
CREATE INDEX idx_users_active ON users (id) WHERE deleted_at IS NULL;
```

---

## Memorize This Senior SQL Mantra

When asked about queries:

1. **EXPLAIN before optimizing.**
2. **Index columns used in WHERE/JOIN/ORDER BY.**
3. **Don't `SELECT *`.**
4. **Always have pagination on list endpoints.**
5. **Beware of N+1.**
6. **Use transactions for multi-step changes.**
7. **Lock in deterministic order.**
8. **Test on production-sized data.**
