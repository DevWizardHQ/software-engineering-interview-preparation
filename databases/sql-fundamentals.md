# SQL Fundamentals — Interview Q&A Guide

**Purpose:** Learn SQL from basics to advanced topics through clear questions, plain-language answers, and runnable examples. Useful for backend interviews and day-to-day work.

---

## Table of Contents

1. SQL Basics
2. SELECT, WHERE, ORDER BY, LIMIT
3. INSERT, UPDATE, DELETE
4. Joins
5. Aggregations and GROUP BY
6. Subqueries and CTEs
7. Window Functions
8. Indexes
9. Transactions and Concurrency
10. Normalization
11. Query Optimization
12. Common Query Patterns
13. Advanced Topics

---

## 1. SQL Basics

## Q1. What is SQL?

**Answer:**

SQL stands for Structured Query Language. It is a declarative language used to query and manage relational databases. You describe *what* you want, and the database engine figures out *how* to fetch it.

```sql
SELECT name, email FROM users WHERE active = TRUE;
```

You did not tell the database to scan the table or use an index — you just described the result you wanted.

## Q2. What are the SQL command categories?

**Answer:**

SQL commands are grouped by purpose. Knowing the category helps you understand what each command does.

| Category | Commands | Purpose |
|----------|----------|---------|
| DDL | CREATE, ALTER, DROP, TRUNCATE | Define schema |
| DML | INSERT, UPDATE, DELETE | Modify data |
| DQL | SELECT | Query data |
| DCL | GRANT, REVOKE | Permissions |
| TCL | BEGIN, COMMIT, ROLLBACK, SAVEPOINT | Transaction control |

```sql
-- DDL
CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100));

-- DML
INSERT INTO users (id, name) VALUES (1, 'Alice');

-- DQL
SELECT * FROM users;

-- TCL
BEGIN;
UPDATE users SET name = 'Bob' WHERE id = 1;
COMMIT;
```

## Q3. What is the structure of a SELECT statement?

**Answer:**

A full SELECT query has several optional clauses. They must appear in this order:

```sql
SELECT column1, column2
FROM table_name
WHERE condition
GROUP BY column
HAVING group_condition
ORDER BY column ASC
LIMIT 10 OFFSET 0;
```

The database executes the clauses in this *logical* order:

1. FROM (and JOINs)
2. WHERE
3. GROUP BY
4. HAVING
5. SELECT
6. DISTINCT
7. ORDER BY
8. LIMIT / OFFSET

This is why a column alias defined in SELECT cannot be used in WHERE — WHERE runs first.

```sql
-- This fails on most databases
SELECT price * 1.1 AS final_price
FROM products
WHERE final_price > 100;   -- Error: final_price not known yet

-- Use the expression directly, or use a subquery / CTE
SELECT price * 1.1 AS final_price
FROM products
WHERE price * 1.1 > 100;
```

## Q4. What is the difference between WHERE and HAVING?

**Answer:**

WHERE filters individual rows *before* grouping. HAVING filters groups *after* grouping. Use WHERE whenever you can — it reduces the data the GROUP BY has to process.

```sql
SELECT department, COUNT(*) AS emp_count
FROM employees
WHERE active = TRUE          -- per-row filter, runs first
GROUP BY department
HAVING COUNT(*) > 5;         -- per-group filter, runs after grouping
```

## Q5. What is the difference between DELETE, TRUNCATE, and DROP?

**Answer:**

All three remove data, but they work differently.

| Command | What it does | Reversible | Resets identity |
|---------|--------------|------------|-----------------|
| DELETE | Removes rows matching WHERE | Yes (inside transaction) | No |
| TRUNCATE | Removes all rows quickly | Usually no | Yes |
| DROP | Removes the entire table | No | N/A |

```sql
-- Remove only inactive users
DELETE FROM users WHERE active = FALSE;

-- Empty the table fast
TRUNCATE TABLE sessions;

-- Remove the table itself
DROP TABLE old_logs;
```

DELETE fires triggers and writes to the transaction log. TRUNCATE typically does not.

## Q6. What is the difference between UNION and UNION ALL?

**Answer:**

UNION combines results from two queries and removes duplicates. UNION ALL combines results and keeps duplicates. UNION ALL is faster because it skips the duplicate-removal step.

```sql
-- Combine, remove duplicates
SELECT email FROM customers
UNION
SELECT email FROM newsletter_subscribers;

-- Combine, keep duplicates (faster)
SELECT 'order' AS source, total FROM orders
UNION ALL
SELECT 'refund', amount FROM refunds;
```

Use UNION ALL unless you specifically need duplicates removed.

## Q7. What is the difference between IN and EXISTS?

**Answer:**

IN checks whether a value matches any in a list or subquery result. EXISTS checks whether a subquery returns at least one row. EXISTS often performs better on large subqueries because it stops at the first match.

```sql
-- IN with a list
SELECT * FROM users WHERE id IN (1, 2, 3);

-- IN with a subquery
SELECT * FROM users
WHERE id IN (SELECT user_id FROM orders);

-- EXISTS — same logic, different style
SELECT * FROM users u
WHERE EXISTS (
  SELECT 1 FROM orders o WHERE o.user_id = u.id
);
```

Be careful with NULL in NOT IN — a single NULL in the subquery makes the whole expression return zero rows. Use NOT EXISTS instead.

```sql
-- Risky if user_id can be NULL
SELECT * FROM users WHERE id NOT IN (SELECT user_id FROM orders);

-- Safer
SELECT * FROM users u
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

## Q8. What is the difference between NULL and an empty string?

**Answer:**

NULL means "unknown" or "no value". An empty string `''` is a known value of length zero. They are not equal.

```sql
-- Setup
CREATE TABLE customers (id INT, nickname VARCHAR(50));
INSERT INTO customers VALUES (1, NULL), (2, ''), (3, 'Alex');

-- This returns id 2 only, not id 1
SELECT * FROM customers WHERE nickname = '';

-- To check NULL, use IS NULL
SELECT * FROM customers WHERE nickname IS NULL;
```

Comparisons with NULL always return NULL (not TRUE or FALSE), which is treated as not matching.

---

## 2. SELECT, WHERE, ORDER BY, LIMIT

## Q9. How do you filter rows with WHERE?

**Answer:**

WHERE accepts boolean expressions. You can combine conditions with AND, OR, and NOT.

```sql
SELECT *
FROM products
WHERE category = 'electronics'
  AND price BETWEEN 100 AND 500
  AND stock > 0
  AND name LIKE '%phone%';
```

`BETWEEN a AND b` is inclusive on both sides. `LIKE '%x%'` matches any string containing x; `_` matches a single character.

## Q10. How do you sort results?

**Answer:**

Use ORDER BY with one or more columns. ASC is ascending (default); DESC is descending.

```sql
SELECT name, price
FROM products
ORDER BY price DESC, name ASC;
```

NULL sort order varies by database. PostgreSQL puts NULL last by default for ASC; MySQL puts NULL first. Use `NULLS FIRST` or `NULLS LAST` (PostgreSQL) when it matters.

```sql
SELECT name FROM products ORDER BY discount DESC NULLS LAST;
```

## Q11. How do you paginate results?

**Answer:**

Use LIMIT and OFFSET. LIMIT caps the number of rows returned; OFFSET skips rows.

```sql
-- Page 3 with 20 per page (skip 40, take 20)
SELECT * FROM products
ORDER BY id
LIMIT 20 OFFSET 40;
```

OFFSET becomes slow on deep pages because the database still scans skipped rows. For deep pagination, use *keyset pagination*:

```sql
-- Fetch products after the last seen id
SELECT * FROM products
WHERE id > 1000
ORDER BY id
LIMIT 20;
```

## Q12. What does DISTINCT do?

**Answer:**

DISTINCT removes duplicate rows from the result. It applies to the entire row, not just one column.

```sql
-- All distinct cities
SELECT DISTINCT city FROM customers;

-- Distinct combinations of (city, state)
SELECT DISTINCT city, state FROM customers;
```

DISTINCT is sometimes a sign your JOIN multiplied rows accidentally. If so, fix the JOIN rather than masking the issue.

## Q13. What is CASE WHEN?

**Answer:**

CASE is SQL's conditional expression. It works like an if/else and can appear in SELECT, WHERE, ORDER BY, and elsewhere.

```sql
SELECT
  name,
  price,
  CASE
    WHEN price < 50  THEN 'cheap'
    WHEN price < 200 THEN 'mid'
    ELSE 'premium'
  END AS price_tier
FROM products;
```

A common pattern is using CASE inside an aggregate to count conditional rows:

```sql
SELECT
  SUM(CASE WHEN status = 'paid'    THEN 1 ELSE 0 END) AS paid_count,
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_count
FROM orders;
```

---

## 3. INSERT, UPDATE, DELETE

## Q14. How do you insert rows?

**Answer:**

Use INSERT INTO with column names and values. You can insert one row, many rows at once, or rows from a SELECT.

```sql
-- One row
INSERT INTO users (name, email)
VALUES ('Alice', 'alice@example.com');

-- Many rows in one statement (much faster than many INSERTs)
INSERT INTO users (name, email) VALUES
  ('Bob',   'bob@example.com'),
  ('Carol', 'carol@example.com'),
  ('Dan',   'dan@example.com');

-- Insert from another table
INSERT INTO archived_users (id, name, email)
SELECT id, name, email FROM users WHERE active = FALSE;
```

## Q15. How do you update rows?

**Answer:**

Use UPDATE with SET and WHERE. Always include WHERE — without it, you update every row.

```sql
UPDATE products
SET price = price * 1.10,
    updated_at = NOW()
WHERE category = 'electronics';
```

To update one table from another, most databases support UPDATE ... FROM (Postgres) or UPDATE ... JOIN (MySQL).

```sql
-- Postgres
UPDATE orders o
SET customer_name = c.name
FROM customers c
WHERE o.customer_id = c.id;

-- MySQL
UPDATE orders o
JOIN customers c ON c.id = o.customer_id
SET o.customer_name = c.name;
```

## Q16. How do you delete rows?

**Answer:**

Use DELETE with a WHERE clause. Without WHERE, all rows are deleted.

```sql
DELETE FROM sessions
WHERE expires_at < NOW();
```

Wrap risky deletes in a transaction so you can roll back:

```sql
BEGIN;
DELETE FROM users WHERE last_login_at < NOW() - INTERVAL '5 years';
-- Check the count, verify, then:
COMMIT;
-- or ROLLBACK;
```

## Q17. What is UPSERT (INSERT ... ON CONFLICT)?

**Answer:**

An upsert inserts a new row, but if a unique constraint is violated, it updates the existing row instead. Different databases use different syntax.

```sql
-- PostgreSQL
INSERT INTO products (sku, name, price)
VALUES ('ABC-1', 'Widget', 9.99)
ON CONFLICT (sku) DO UPDATE
SET name  = EXCLUDED.name,
    price = EXCLUDED.price;

-- MySQL
INSERT INTO products (sku, name, price)
VALUES ('ABC-1', 'Widget', 9.99)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  price = VALUES(price);

-- SQLite
INSERT INTO products (sku, name, price)
VALUES ('ABC-1', 'Widget', 9.99)
ON CONFLICT (sku) DO UPDATE
SET name  = excluded.name,
    price = excluded.price;
```

---

## 4. Joins

## Q18. What are the join types?

**Answer:**

Joins combine rows from two tables based on a relationship.

| Join | Returns |
|------|---------|
| INNER JOIN | Only matching rows from both tables |
| LEFT JOIN | All rows from left, matched rows from right (NULL where no match) |
| RIGHT JOIN | All rows from right, matched rows from left |
| FULL OUTER JOIN | All rows from both, NULL where no match |
| CROSS JOIN | Cartesian product — every row × every row |
| SELF JOIN | Table joined to itself |

Setup:

```sql
CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(50));
CREATE TABLE orders (id INT PRIMARY KEY, user_id INT, total DECIMAL(10,2));

INSERT INTO users VALUES (1,'Alice'), (2,'Bob'), (3,'Carol');
INSERT INTO orders VALUES (10,1,99), (11,1,150), (12,2,40);
```

```sql
-- INNER JOIN — only users who placed orders
SELECT u.name, o.total
FROM users u
INNER JOIN orders o ON o.user_id = u.id;
-- Alice 99, Alice 150, Bob 40

-- LEFT JOIN — all users; Carol shows NULL
SELECT u.name, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id;
-- Alice 99, Alice 150, Bob 40, Carol NULL

-- Find users with no orders
SELECT u.name
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;
-- Carol
```

## Q19. Is LEFT JOIN the same as LEFT OUTER JOIN?

**Answer:**

Yes. The word OUTER is optional. `LEFT JOIN` and `LEFT OUTER JOIN` mean exactly the same thing.

## Q20. What is a self join?

**Answer:**

A self join is a table joined to itself, usually using aliases. It is useful for hierarchical data or pair comparisons.

```sql
CREATE TABLE employees (
  id          INT PRIMARY KEY,
  name        VARCHAR(50),
  manager_id  INT
);

INSERT INTO employees VALUES
  (1,'CEO',NULL), (2,'VP',1), (3,'Engineer',2);

-- Each employee with their manager's name
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
```

## Q21. What is the row multiplication problem in joins?

**Answer:**

When you join a table that has multiple matching rows per parent, the parent row appears once per match. This makes counts and sums incorrect if you are not careful.

```sql
-- 1 user, 3 orders, 5 comments
-- Wrong: this gives 15 rows per user (3 × 5)
SELECT u.id, COUNT(o.id), COUNT(c.id)
FROM users u
LEFT JOIN orders   o ON o.user_id = u.id
LEFT JOIN comments c ON c.user_id = u.id
GROUP BY u.id;

-- Fix with COUNT(DISTINCT ...)
SELECT u.id,
       COUNT(DISTINCT o.id) AS order_count,
       COUNT(DISTINCT c.id) AS comment_count
FROM users u
LEFT JOIN orders   o ON o.user_id = u.id
LEFT JOIN comments c ON c.user_id = u.id
GROUP BY u.id;
```

A cleaner fix is to aggregate in subqueries first.

```sql
SELECT u.id,
       COALESCE(o.cnt, 0) AS order_count,
       COALESCE(c.cnt, 0) AS comment_count
FROM users u
LEFT JOIN (SELECT user_id, COUNT(*) AS cnt FROM orders   GROUP BY user_id) o ON o.user_id = u.id
LEFT JOIN (SELECT user_id, COUNT(*) AS cnt FROM comments GROUP BY user_id) c ON c.user_id = u.id;
```

---

## 5. Aggregations and GROUP BY

## Q22. What are aggregate functions?

**Answer:**

Aggregate functions reduce many rows to a single value: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `STDDEV`, `VARIANCE`.

```sql
SELECT
  COUNT(*)                 AS total_orders,
  COUNT(DISTINCT user_id)  AS unique_buyers,
  SUM(total)               AS revenue,
  AVG(total)               AS avg_order,
  MIN(created_at)          AS first_order,
  MAX(created_at)          AS last_order
FROM orders;
```

`COUNT(*)` counts all rows. `COUNT(column)` counts non-NULL values. `COUNT(DISTINCT column)` counts unique non-NULL values.

## Q23. How does GROUP BY work?

**Answer:**

GROUP BY collapses rows into buckets based on column values, then aggregate functions run per bucket. Every column in SELECT must either appear in GROUP BY or be inside an aggregate.

```sql
SELECT category,
       COUNT(*)    AS product_count,
       AVG(price)  AS avg_price
FROM products
GROUP BY category;
```

Group by multiple columns to bucket by combinations:

```sql
SELECT category, brand, SUM(stock) AS total_stock
FROM products
GROUP BY category, brand;
```

## Q24. What are GROUPING SETS, ROLLUP, and CUBE?

**Answer:**

These extensions of GROUP BY produce multi-level totals in one query.

- ROLLUP — hierarchical totals (subtotals + grand total).
- CUBE — every combination of grouping columns.
- GROUPING SETS — explicit list of group combinations.

```sql
-- Per (category, brand), per category, and grand total
SELECT category, brand, SUM(stock)
FROM products
GROUP BY ROLLUP(category, brand);

-- All combinations
SELECT category, brand, SUM(stock)
FROM products
GROUP BY CUBE(category, brand);
```

---

## 6. Subqueries and CTEs

## Q25. What is a subquery?

**Answer:**

A subquery is a SELECT inside another query. It can appear in WHERE, FROM, or SELECT.

```sql
-- In WHERE
SELECT *
FROM users
WHERE id IN (SELECT user_id FROM orders WHERE total > 1000);

-- In FROM (a derived table)
SELECT category, max_price
FROM (
  SELECT category, MAX(price) AS max_price
  FROM products
  GROUP BY category
) AS p;

-- Correlated subquery in SELECT
SELECT u.name,
       (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) AS order_count
FROM users u;
```

A correlated subquery refers to the outer query's row and re-runs for each outer row.

## Q26. What is a CTE (Common Table Expression)?

**Answer:**

A CTE is a named temporary result defined with WITH. CTEs make complex queries readable and can reference each other.

```sql
WITH active_users AS (
  SELECT id, name FROM users WHERE active = TRUE
),
recent_orders AS (
  SELECT user_id, total
  FROM orders
  WHERE created_at > NOW() - INTERVAL '7 days'
)
SELECT u.name, SUM(o.total) AS spent_last_week
FROM active_users u
JOIN recent_orders o ON o.user_id = u.id
GROUP BY u.name;
```

## Q27. What is a recursive CTE?

**Answer:**

A recursive CTE references itself. It is the standard way to walk hierarchical data such as trees and graphs.

```sql
CREATE TABLE categories (
  id        INT PRIMARY KEY,
  name      VARCHAR(50),
  parent_id INT
);

INSERT INTO categories VALUES
  (1,'Electronics',NULL),
  (2,'Computers',1),
  (3,'Laptops',2),
  (4,'Gaming Laptops',3);

-- All descendants of Electronics (id 1)
WITH RECURSIVE category_tree AS (
  SELECT id, name, parent_id
  FROM categories
  WHERE id = 1                                    -- base case

  UNION ALL

  SELECT c.id, c.name, c.parent_id
  FROM categories c
  JOIN category_tree ct ON c.parent_id = ct.id    -- recursive case
)
SELECT * FROM category_tree;
```

Use cases include category trees, comment threads, organization charts, and dependency graphs.

## Q28. CTE vs subquery — which should I use?

**Answer:**

Use a CTE when the query is complex, when you reuse a result several times, or when you need recursion. Use a subquery for short, single-use cases. Modern optimizers handle both efficiently in most cases — choose by readability.

---

## 7. Window Functions

## Q29. What is a window function?

**Answer:**

Window functions compute values across a set of rows related to the current row, *without collapsing those rows*. Unlike GROUP BY, every input row remains in the output.

```sql
SELECT name,
       department,
       salary,
       AVG(salary) OVER (PARTITION BY department)              AS dept_avg,
       RANK()      OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_dept
FROM employees;
```

Each row keeps its own data and gains the department average and rank.

## Q30. What are common window functions?

**Answer:**

| Function | Use |
|----------|-----|
| `ROW_NUMBER()` | Sequential number within partition |
| `RANK()` | Rank with gaps for ties (1, 2, 2, 4) |
| `DENSE_RANK()` | Rank without gaps (1, 2, 2, 3) |
| `LAG(col, n)` | Value from previous row |
| `LEAD(col, n)` | Value from next row |
| `FIRST_VALUE(col)` / `LAST_VALUE(col)` | First/last in window |
| `SUM/AVG/COUNT(...) OVER (...)` | Running aggregates |

```sql
-- Running total per user, ordered by date
SELECT user_id, created_at, total,
       SUM(total) OVER (PARTITION BY user_id ORDER BY created_at) AS running_total
FROM orders;

-- Day-over-day revenue change
SELECT date, revenue,
       LAG(revenue) OVER (ORDER BY date)              AS prev_day,
       revenue - LAG(revenue) OVER (ORDER BY date)    AS change_amount
FROM daily_revenue;
```

## Q31. How do you find the second-highest salary?

**Answer:**

There are several ways. DENSE_RANK is the cleanest if you want all employees tied for second place.

```sql
-- Method 1: window function
SELECT salary
FROM (
  SELECT salary,
         DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
  FROM employees
) t
WHERE rnk = 2;

-- Method 2: subquery
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);

-- Method 3: LIMIT/OFFSET
SELECT DISTINCT salary
FROM employees
ORDER BY salary DESC
LIMIT 1 OFFSET 1;
```

## Q32. How do you get the top N rows per group?

**Answer:**

Use ROW_NUMBER over a partition. This is one of the most common interview questions.

```sql
-- Top 3 highest-paid employees per department
WITH ranked AS (
  SELECT e.*,
         ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
  FROM employees e
)
SELECT id, name, department, salary
FROM ranked
WHERE rn <= 3;
```

---

## 8. Indexes

## Q33. What is an index?

**Answer:**

An index is a separate data structure (most often a B-tree) that lets the database find rows by a column without scanning the whole table. It speeds up reads but slows down writes (the index must be updated) and uses extra disk space.

```sql
CREATE INDEX idx_users_email ON users(email);

-- Now this query is fast even on millions of rows
SELECT * FROM users WHERE email = 'alice@example.com';
```

## Q34. When should I add an index?

**Answer:**

Add indexes on columns frequently used in:

- WHERE clauses
- JOIN conditions
- ORDER BY (for large sorts)
- GROUP BY (for very large tables)
- Foreign keys (MySQL auto-indexes them; PostgreSQL does not)

Avoid indexes on:

- Tables with very few rows
- Columns rarely used in queries
- Boolean / very low-cardinality columns (usually only useful as part of a composite)
- Tables that are written far more than they are read

## Q35. What is a composite index?

**Answer:**

An index on multiple columns. Column order matters — the index helps queries that filter by the leading columns.

```sql
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
```

This index helps:

```sql
WHERE user_id = 5;
WHERE user_id = 5 AND status = 'paid';
WHERE user_id = 5 ORDER BY status;
```

It does *not* help (or only barely):

```sql
WHERE status = 'paid';   -- can't use index, status isn't first
```

Rule of thumb: put equality-filtered columns first, then range-filtered columns.

## Q36. What is index selectivity?

**Answer:**

Selectivity = distinct values / total rows. A high-selectivity index narrows results sharply and is very useful. A low-selectivity index returns many rows and may be ignored by the optimizer.

- `email` on users (mostly unique) — high selectivity, great index.
- `is_active` boolean — low selectivity, weak alone, useful in a composite index.

## Q37. What is a covering index?

**Answer:**

A covering index includes every column needed by the query, so the database does not have to read the underlying table at all.

```sql
-- Query
SELECT user_id, status, total FROM orders WHERE user_id = 123;

-- Covering index (PostgreSQL syntax)
CREATE INDEX idx_orders_covering
ON orders(user_id) INCLUDE (status, total);
```

The query is served entirely from the index. This is one of the fastest read patterns possible.

## Q38. Why doesn't an index always help?

**Answer:**

Several common reasons:

- The optimizer estimates a full scan is cheaper (small table or many matching rows).
- A function on the column hides it from the index: `WHERE LOWER(email) = ?` doesn't use an index on `email`. Use a functional index or normalize stored values.
- A leading wildcard prevents B-tree use: `WHERE name LIKE '%john%'`.
- Implicit type casts: `WHERE id = '123'` when id is INT may skip the index.
- Statistics are stale — run ANALYZE.

```sql
-- Bad
SELECT * FROM users WHERE LOWER(email) = 'alice@x.com';

-- Better: store emails lowercased, or create a functional index (Postgres)
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
```

---

## 9. Transactions and Concurrency

## Q39. What is a transaction?

**Answer:**

A transaction is a unit of work that either fully completes or has no effect. Use one when several statements must succeed or fail together.

```sql
BEGIN;
  UPDATE accounts SET balance = balance - 100 WHERE id = 1;
  UPDATE accounts SET balance = balance + 100 WHERE id = 2;
  INSERT INTO transfers (from_id, to_id, amount) VALUES (1, 2, 100);
COMMIT;
-- ROLLBACK; on error
```

## Q40. What are the ACID properties?

**Answer:**

| Letter | Meaning |
|--------|---------|
| Atomicity | All steps succeed, or none do |
| Consistency | Database moves from one valid state to another |
| Isolation | Concurrent transactions don't see each other's intermediate state |
| Durability | After COMMIT, changes survive crashes |

## Q41. What are isolation levels?

**Answer:**

Isolation levels control which concurrency anomalies are possible. Stronger levels are safer but slower.

| Level | Dirty Read | Non-Repeatable Read | Phantom Read |
|-------|------------|---------------------|---------------|
| Read Uncommitted | Possible | Possible | Possible |
| Read Committed | No | Possible | Possible |
| Repeatable Read | No | No | Possible (PG prevents via MVCC) |
| Serializable | No | No | No |

```sql
-- Set isolation level for a transaction
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT ...;
COMMIT;
```

PostgreSQL default: Read Committed. MySQL InnoDB default: Repeatable Read.

## Q42. What is `SELECT ... FOR UPDATE`?

**Answer:**

It locks the matching rows so other transactions cannot update or delete them until your transaction ends. Use it for safe read-modify-write patterns.

```sql
BEGIN;
  SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
  -- Other transactions trying to update id=1 must wait
  UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

## Q43. What is a deadlock?

**Answer:**

A deadlock happens when two transactions each hold a lock the other needs and neither can proceed.

```
TX1: locks row A → wants row B
TX2: locks row B → wants row A
```

The database detects the cycle and aborts one transaction. The application must retry. Prevent deadlocks by always acquiring locks in the same order (for example, always by primary key ascending).

## Q44. What is MVCC?

**Answer:**

MVCC (Multi-Version Concurrency Control) keeps multiple versions of each row so readers do not block writers and writers do not block readers. PostgreSQL is a classic MVCC system, and InnoDB uses MVCC for its snapshot reads. The cost is that old row versions must be cleaned up later (VACUUM in Postgres, purge in InnoDB).

---

## 10. Normalization

## Q45. What is normalization?

**Answer:**

Normalization is the process of organizing tables to reduce duplication and improve data integrity. The common normal forms are:

- 1NF: atomic values; no lists in cells.
- 2NF: 1NF plus no partial dependency on a composite key.
- 3NF: 2NF plus no transitive dependencies (non-key columns depend only on the primary key).

For most OLTP applications, target 3NF.

## Q46. Show a normalization example.

**Answer:**

Before — orders mix customer and product data:

```sql
-- Denormalized
CREATE TABLE orders (
  id              INT PRIMARY KEY,
  customer_name   VARCHAR(100),
  customer_email  VARCHAR(100),
  product_name    VARCHAR(100),
  price           DECIMAL(10,2)
);
```

After — separate entities:

```sql
CREATE TABLE customers (
  id    INT PRIMARY KEY,
  name  VARCHAR(100),
  email VARCHAR(100)
);

CREATE TABLE products (
  id    INT PRIMARY KEY,
  name  VARCHAR(100),
  price DECIMAL(10,2)
);

CREATE TABLE orders (
  id          INT PRIMARY KEY,
  customer_id INT REFERENCES customers(id),
  product_id  INT REFERENCES products(id)
);
```

If a customer's email changes, you update one row instead of many.

## Q47. When should you denormalize?

**Answer:**

Denormalize when joins are expensive, when reports need precomputed aggregates, or when you have measured a real performance problem. The trade-off is that you must keep the duplicated data in sync.

```sql
-- Cache order count on the user row to avoid scanning orders
ALTER TABLE users ADD COLUMN order_count INT DEFAULT 0;

-- Maintain it from a trigger or application logic on every order insert/delete
```

---

## 11. Query Optimization

## Q48. How do you optimize a slow query?

**Answer:**

A practical workflow:

1. Run EXPLAIN (or EXPLAIN ANALYZE) to see the plan.
2. Look for full table scans on large tables, missing indexes, or wildly wrong row estimates.
3. Add or fix indexes.
4. Avoid `SELECT *`; return only needed columns.
5. Add LIMIT / pagination.
6. Update statistics with ANALYZE.
7. Consider rewriting (a JOIN may beat a subquery, or vice versa).
8. As a last resort, denormalize or use a materialized view.

```sql
EXPLAIN ANALYZE
SELECT u.name, COUNT(o.id)
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id, u.name;
```

## Q49. What does EXPLAIN show?

**Answer:**

EXPLAIN displays the query plan — the steps the database will use to execute the query. Look for:

- Seq Scan / Full Table Scan — a full pass over the table; bad on large tables when only a few rows are wanted.
- Index Scan — the database used an index. Usually good.
- Index Only Scan — even better, no table lookup.
- Nested Loop / Hash Join / Merge Join — join algorithm choice.
- Rows estimate vs actual — large differences suggest stale statistics.

```text
Seq Scan on orders  (cost=0.00..1500.00 rows=10000 width=64)
  Filter: (status = 'pending')
```

## Q50. What are common slow query patterns?

**Answer:**

| Pattern | Fix |
|---------|-----|
| `SELECT *` | Select only needed columns |
| Missing WHERE | Add a filter |
| `LIKE '%term%'` | Full-text or trigram index |
| Function on column | Functional index or normalize stored data |
| Mismatched types | Compare same types |
| OR across columns | Rewrite as UNION |
| N+1 queries | Eager loading / single query |
| Unbounded result | Pagination |

## Q51. What is the N+1 query problem?

**Answer:**

It happens when one query fetches a list, then a separate query is fired for each item. With N parents you end up with 1 + N queries.

```js
const users = await db.query('SELECT * FROM users');         // 1
for (const u of users) {
  u.orders = await db.query(                                  // N
    'SELECT * FROM orders WHERE user_id = $1', [u.id]
  );
}
```

Fix it with a single JOIN or two batched queries:

```sql
-- Single query
SELECT u.*, o.id AS order_id, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id;
```

```js
// Two-query pattern
const users  = await db.query('SELECT * FROM users');
const orders = await db.query(
  'SELECT * FROM orders WHERE user_id = ANY($1)',
  [users.map(u => u.id)]
);
// then group orders by user_id in code
```

ORM users: enable eager loading (`with`, `includes`, `populate`).

---

## 12. Common Query Patterns

## Q52. Find duplicates.

**Answer:**

Group by the column that should be unique and filter groups with more than one row.

```sql
SELECT email, COUNT(*) AS cnt
FROM users
GROUP BY email
HAVING COUNT(*) > 1;
```

## Q53. Delete duplicates, keeping one.

**Answer:**

Keep the row with the smallest id; delete the others.

```sql
-- Using a CTE with ROW_NUMBER
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
  FROM users
)
DELETE FROM users
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- Alternative
DELETE FROM users
WHERE id NOT IN (
  SELECT MIN(id) FROM users GROUP BY email
);
```

## Q54. Running total.

**Answer:**

Use SUM as a window function with ORDER BY.

```sql
SELECT date,
       revenue,
       SUM(revenue) OVER (ORDER BY date) AS running_total
FROM daily_revenue;
```

## Q55. Pivot rows to columns.

**Answer:**

Use CASE inside aggregates.

```sql
SELECT
  product_id,
  SUM(CASE WHEN month = 1 THEN amount ELSE 0 END) AS jan,
  SUM(CASE WHEN month = 2 THEN amount ELSE 0 END) AS feb,
  SUM(CASE WHEN month = 3 THEN amount ELSE 0 END) AS mar
FROM sales
GROUP BY product_id;
```

## Q56. Find users with no orders.

**Answer:**

Three common ways:

```sql
-- LEFT JOIN with NULL filter
SELECT u.*
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;

-- NOT EXISTS (handles NULL safely)
SELECT u.*
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

-- NOT IN (be careful with NULL in subquery)
SELECT *
FROM users
WHERE id NOT IN (SELECT user_id FROM orders WHERE user_id IS NOT NULL);
```

## Q57. Date arithmetic.

**Answer:**

Most databases support date arithmetic with INTERVAL.

```sql
-- Orders in last 7 days (Postgres)
SELECT * FROM orders
WHERE created_at >= NOW() - INTERVAL '7 days';

-- Orders per day
SELECT DATE(created_at) AS day, COUNT(*)
FROM orders
GROUP BY DATE(created_at);

-- Orders per month
SELECT DATE_TRUNC('month', created_at) AS month, SUM(total)
FROM orders
GROUP BY DATE_TRUNC('month', created_at);

-- Duration between two timestamps
SELECT created_at, completed_at,
       completed_at - created_at AS duration
FROM tasks;
```

## Q58. Find pairs with self join.

**Answer:**

Find all unique pairs of employees in the same department:

```sql
SELECT e1.name AS emp1, e2.name AS emp2, e1.department
FROM employees e1
JOIN employees e2
  ON e1.department = e2.department
 AND e1.id < e2.id;
```

The condition `e1.id < e2.id` removes duplicate pairs and self-matches.

## Q59. Gaps and islands — find consecutive date ranges.

**Answer:**

Subtract a row number from the date. Consecutive dates produce the same group key.

```sql
WITH grouped AS (
  SELECT date,
         date - INTERVAL '1 day' * ROW_NUMBER() OVER (ORDER BY date) AS grp
  FROM activity
)
SELECT MIN(date) AS start_date, MAX(date) AS end_date
FROM grouped
GROUP BY grp
ORDER BY start_date;
```

---

## 13. Advanced Topics

## Q60. What is a view?

**Answer:**

A view is a saved query that you can query like a table. It does not store data; it runs the underlying query each time.

```sql
CREATE VIEW active_customers AS
SELECT id, name, email
FROM customers
WHERE active = TRUE;

SELECT * FROM active_customers WHERE name LIKE 'A%';
```

## Q61. What is a materialized view?

**Answer:**

A materialized view stores its result on disk. Reads are fast, but the data is only as fresh as the last refresh.

```sql
CREATE MATERIALIZED VIEW daily_sales AS
SELECT DATE(created_at) AS day, SUM(total) AS revenue
FROM orders
GROUP BY DATE(created_at);

-- Refresh when underlying data changes
REFRESH MATERIALIZED VIEW daily_sales;
```

Use materialized views for expensive aggregations that do not need to be real-time.

## Q62. What is a stored procedure?

**Answer:**

A stored procedure is a function-like object stored inside the database. It can take parameters and run multiple statements.

```sql
CREATE OR REPLACE FUNCTION transfer_funds(
  p_from INT, p_to INT, p_amount NUMERIC
) RETURNS VOID AS $$
BEGIN
  UPDATE accounts SET balance = balance - p_amount WHERE id = p_from;
  UPDATE accounts SET balance = balance + p_amount WHERE id = p_to;
  INSERT INTO transfers (from_id, to_id, amount)
  VALUES (p_from, p_to, p_amount);
END;
$$ LANGUAGE plpgsql;

SELECT transfer_funds(1, 2, 100);
```

## Q63. What is a trigger?

**Answer:**

A trigger is code that runs automatically on INSERT, UPDATE, or DELETE. Triggers are useful for audit logs and timestamp maintenance, but they hide logic — use them carefully.

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
```

## Q64. What is a transaction log (WAL / binlog)?

**Answer:**

A sequential record of every change made to the database. Used for crash recovery, replication, and point-in-time recovery.

- PostgreSQL: WAL (Write-Ahead Log)
- MySQL: binlog
- Tools like Debezium tail these logs to stream change events to other systems.

## Q65. What is sharding?

**Answer:**

Sharding splits a large table or database across multiple servers based on a shard key (often a hash of user_id or region). It scales writes and storage but complicates queries that span shards.

```text
shard = hash(user_id) mod 4
shard_0 → DB1
shard_1 → DB2
shard_2 → DB3
shard_3 → DB4
```

## Q66. What is replication?

**Answer:**

Replication copies data from a primary to one or more replicas.

| Type | Behavior |
|------|----------|
| Synchronous | Primary waits for replica acknowledgment before commit. Strong consistency, slower writes. |
| Asynchronous | Primary commits, replica catches up later. Lower latency, replica may lag. |
| Streaming (Postgres) | Primary streams WAL; replica replays it. |
| Logical (Postgres) | Replicates specific tables; supports schema differences. |

## Q67. What is a connection pool?

**Answer:**

A connection pool maintains a small number of long-lived database connections that the application borrows and returns. This avoids the cost of opening a new TCP/auth handshake on every request.

Typical settings:

- pool size — number of connections held
- idle timeout — close unused connections after N seconds
- max lifetime — recycle connections occasionally
- acquire timeout — give up waiting after N seconds

## Q68. What is OLTP vs OLAP?

**Answer:**

- OLTP (Online Transaction Processing): many short reads and writes with low latency. PostgreSQL, MySQL, MariaDB, SQLite.
- OLAP (Online Analytical Processing): complex aggregations over large datasets. ClickHouse, BigQuery, Snowflake, Redshift.

OLTP databases are typically normalized; OLAP systems use star schemas and columnar storage.

## Q69. How do you handle soft delete?

**Answer:**

Add a `deleted_at` timestamp column. Filter active rows in queries; set the column instead of deleting.

```sql
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP NULL;

-- Active users only
SELECT * FROM users WHERE deleted_at IS NULL;

-- Soft delete
UPDATE users SET deleted_at = NOW() WHERE id = 1;

-- Restore
UPDATE users SET deleted_at = NULL WHERE id = 1;

-- Partial index speeds up active-row queries (Postgres)
CREATE INDEX idx_users_active ON users(id) WHERE deleted_at IS NULL;
```

## Q70. How would you design a user reviews table?

**Answer:**

A practical checklist:

1. Identify entities and relationships (user, product, review).
2. Choose a primary key (BIGSERIAL or UUID).
3. Add foreign keys with sensible ON DELETE behavior.
4. Add `created_at` and `updated_at`.
5. Add `deleted_at` if soft delete is needed.
6. Add indexes on foreign keys and frequently queried columns.
7. Add unique constraints (one review per user per product).

```sql
CREATE TABLE reviews (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ NULL,
  UNIQUE (user_id, product_id)
);

CREATE INDEX idx_reviews_product ON reviews(product_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_reviews_user    ON reviews(user_id)    WHERE deleted_at IS NULL;
```
