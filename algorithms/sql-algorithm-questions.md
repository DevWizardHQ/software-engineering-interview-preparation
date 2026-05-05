# SQL Algorithm and Puzzle Questions

**Purpose:** Senior-level SQL puzzles asked in nearly every backend, full-stack, and data-engineering interview. Each question includes multiple solution approaches, trade-offs, and explanation of edge cases.

---

## Table of Contents

1. [Ranking and Top-N Problems](#ranking-and-top-n-problems)
2. [Duplicate Detection and Removal](#duplicate-detection-and-removal)
3. [Cumulative and Running Calculations](#cumulative-and-running-calculations)
4. [Anti-Join Patterns](#anti-join-patterns)
5. [Gaps and Islands](#gaps-and-islands)
6. [Pivoting and Unpivoting](#pivoting-and-unpivoting)
7. [Self-Joins and Hierarchies](#self-joins-and-hierarchies)
8. [Statistics: Median, Mode, Percentiles](#statistics-median-mode-percentiles)
9. [Date Math and Trends](#date-math-and-trends)
10. [Window Function Patterns](#window-function-patterns)
11. [LeetCode-Style Hard Patterns](#leetcode-style-hard-patterns)

---

## Ranking and Top-N Problems

### Q1. Find the Nth highest salary — three different methods.

**Schema:** `employees(id, name, salary)`

**Method 1 — Window function (preferred):**
```sql
SELECT DISTINCT salary
FROM (
  SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
  FROM employees
) t
WHERE rnk = N;
```

`DENSE_RANK()` handles ties correctly: if two people share the highest salary, the next one is rank 2, not 3.

**Method 2 — Correlated subquery:**
```sql
SELECT DISTINCT salary
FROM employees e1
WHERE N - 1 = (
  SELECT COUNT(DISTINCT salary)
  FROM employees e2
  WHERE e2.salary > e1.salary
);
```
Reads: "find the salary where exactly N-1 distinct salaries are higher."

**Method 3 — LIMIT / OFFSET:**
```sql
SELECT DISTINCT salary
FROM employees
ORDER BY salary DESC
LIMIT 1 OFFSET N - 1;
```
Simple and fast on small data, but `OFFSET` ignores ties (returns one row even if duplicates exist at that rank).

**Trade-offs:**

| Method | Handles ties | Performance | Portability |
|--------|--------------|-------------|-------------|
| DENSE_RANK | Yes | O(n log n) | Postgres, MySQL 8+, SQL Server, Oracle |
| Correlated | Yes | O(n²) — bad on large tables | All dialects |
| LIMIT/OFFSET | No | Fast | Postgres, MySQL; SQL Server uses OFFSET FETCH |

---

### Q2. Find the 2nd highest salary (special case).

```sql
-- Returns NULL if only one distinct salary exists
SELECT MAX(salary) AS second_highest
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);
```

The classic LeetCode answer. The outer `MAX` returns `NULL` when no row qualifies — a common requirement.

---

### Q3. Find the Nth highest salary in each department.

**Schema:** `employees(id, name, salary, department_id)`

```sql
WITH ranked AS (
  SELECT
    department_id,
    name,
    salary,
    DENSE_RANK() OVER (
      PARTITION BY department_id
      ORDER BY salary DESC
    ) AS rnk
  FROM employees
)
SELECT department_id, name, salary
FROM ranked
WHERE rnk = N;
```

`PARTITION BY` resets the rank for each department.

---

### Q4. Top 3 highest-paid employees per department.

```sql
SELECT department_id, name, salary
FROM (
  SELECT
    department_id, name, salary,
    DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rnk
  FROM employees
) t
WHERE rnk <= 3;
```

Use `RANK()` if you want strict positional ranking (skipping after ties). Use `ROW_NUMBER()` if you must return exactly 3 even when ties exist.

---

### Q5. Department with the highest average salary.

```sql
SELECT department_id, AVG(salary) AS avg_salary
FROM employees
GROUP BY department_id
ORDER BY avg_salary DESC
LIMIT 1;
```

For ties, use a window:
```sql
WITH dept AS (
  SELECT department_id, AVG(salary) AS avg_salary
  FROM employees
  GROUP BY department_id
)
SELECT department_id, avg_salary
FROM dept
WHERE avg_salary = (SELECT MAX(avg_salary) FROM dept);
```

---

## Duplicate Detection and Removal

### Q6. Find duplicate emails in a users table.

```sql
SELECT email, COUNT(*) AS cnt
FROM users
GROUP BY email
HAVING COUNT(*) > 1;
```

To list every duplicate row (not just the email):
```sql
SELECT *
FROM users
WHERE email IN (
  SELECT email FROM users GROUP BY email HAVING COUNT(*) > 1
);
```

---

### Q7. Delete duplicate rows but keep one (lowest id).

**Postgres / SQL Server (CTE + ROW_NUMBER):**
```sql
WITH dups AS (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
  FROM users
)
DELETE FROM users
WHERE id IN (SELECT id FROM dups WHERE rn > 1);
```

**MySQL (self-join):**
```sql
DELETE u1 FROM users u1
INNER JOIN users u2
  ON u1.email = u2.email AND u1.id > u2.id;
```

---

### Q8. Find rows that appear exactly N times.

```sql
SELECT product_id
FROM orders
GROUP BY product_id
HAVING COUNT(*) = 3;
```

---

### Q9. Find duplicates considering multiple columns.

```sql
SELECT first_name, last_name, dob, COUNT(*)
FROM people
GROUP BY first_name, last_name, dob
HAVING COUNT(*) > 1;
```

---

## Cumulative and Running Calculations

### Q10. Running total of orders per day.

**Schema:** `orders(id, user_id, order_date, amount)`

```sql
SELECT
  order_date,
  SUM(amount) AS daily_total,
  SUM(SUM(amount)) OVER (ORDER BY order_date) AS running_total
FROM orders
GROUP BY order_date
ORDER BY order_date;
```

**Why nested SUM works:** `SUM(amount)` aggregates per day; the outer `SUM` is a window function over those daily totals.

---

### Q11. Running total per user.

```sql
SELECT
  user_id,
  order_date,
  amount,
  SUM(amount) OVER (
    PARTITION BY user_id
    ORDER BY order_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS user_running_total
FROM orders;
```

The explicit `ROWS BETWEEN ...` frame avoids ambiguity. Without it, `ORDER BY` defaults to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, which can give surprising results with duplicate dates.

---

### Q12. 7-day moving average.

```sql
SELECT
  order_date,
  AVG(amount) OVER (
    ORDER BY order_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS moving_avg_7d
FROM daily_orders;
```

Note: this uses *row-based* window. If gaps in dates exist, use `RANGE BETWEEN INTERVAL '6 day' PRECEDING AND CURRENT ROW` (Postgres) for date-based windows.

---

### Q13. Cumulative percentage of total.

```sql
SELECT
  product_id,
  revenue,
  100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
        / SUM(revenue) OVER () AS cumulative_pct
FROM products
ORDER BY revenue DESC;
```

Useful for Pareto / 80-20 analysis.

---

## Anti-Join Patterns

### Q14. Find customers who never placed an order.

**Schema:** `customers(id)`, `orders(id, customer_id)`

**Method 1 — LEFT JOIN with NULL filter:**
```sql
SELECT c.*
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.id IS NULL;
```

**Method 2 — NOT EXISTS (handles NULLs safely):**
```sql
SELECT c.*
FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM orders o WHERE o.customer_id = c.id
);
```

**Method 3 — NOT IN (avoid if column may be NULL):**
```sql
SELECT *
FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders WHERE customer_id IS NOT NULL);
```

`NOT IN` returns zero rows when a NULL is in the list — always guard against it.

---

### Q15. Find products never ordered (anti-join with date filter).

```sql
SELECT p.*
FROM products p
WHERE NOT EXISTS (
  SELECT 1 FROM order_items oi
  WHERE oi.product_id = p.id
    AND oi.created_at > NOW() - INTERVAL '30 day'
);
```

---

### Q16. Find users active in March but not in April.

```sql
SELECT DISTINCT user_id
FROM activity
WHERE DATE_TRUNC('month', activity_date) = '2025-03-01'
  AND user_id NOT IN (
    SELECT user_id FROM activity
    WHERE DATE_TRUNC('month', activity_date) = '2025-04-01'
  );
```

---

## Gaps and Islands

### Q17. Find users active for at least 3 consecutive days.

**Schema:** `activity(user_id, activity_date)`, one row per user per day.

```sql
WITH grouped AS (
  SELECT
    user_id,
    activity_date,
    activity_date - INTERVAL '1 day' *
      ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY activity_date) AS grp
  FROM activity
)
SELECT user_id, MIN(activity_date) AS streak_start, COUNT(*) AS streak_len
FROM grouped
GROUP BY user_id, grp
HAVING COUNT(*) >= 3;
```

**Trick explained:** subtracting `ROW_NUMBER()` from the date produces the same value for all rows in a consecutive run. Group by that value to get islands.

---

### Q18. Find gaps in a sequence of IDs.

```sql
SELECT id + 1 AS gap_start,
       next_id - 1 AS gap_end
FROM (
  SELECT id, LEAD(id) OVER (ORDER BY id) AS next_id
  FROM tickets
) t
WHERE next_id - id > 1;
```

---

### Q19. Find longest consecutive login streak per user.

```sql
WITH grp AS (
  SELECT user_id, login_date,
         login_date - INTERVAL '1 day' *
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) AS island
  FROM logins
),
streaks AS (
  SELECT user_id, COUNT(*) AS streak
  FROM grp
  GROUP BY user_id, island
)
SELECT user_id, MAX(streak) AS longest_streak
FROM streaks
GROUP BY user_id;
```

---

## Pivoting and Unpivoting

### Q20. Pivot rows into columns (sales by quarter).

**Schema:** `sales(year, quarter, amount)`

**Standard SQL using CASE + SUM:**
```sql
SELECT
  year,
  SUM(CASE WHEN quarter = 'Q1' THEN amount ELSE 0 END) AS q1,
  SUM(CASE WHEN quarter = 'Q2' THEN amount ELSE 0 END) AS q2,
  SUM(CASE WHEN quarter = 'Q3' THEN amount ELSE 0 END) AS q3,
  SUM(CASE WHEN quarter = 'Q4' THEN amount ELSE 0 END) AS q4
FROM sales
GROUP BY year;
```

**Postgres tablefunc:**
```sql
SELECT * FROM crosstab(
  'SELECT year, quarter, amount FROM sales ORDER BY 1, 2',
  'VALUES (''Q1''), (''Q2''), (''Q3''), (''Q4'')'
) AS ct(year INT, q1 NUMERIC, q2 NUMERIC, q3 NUMERIC, q4 NUMERIC);
```

**SQL Server / Oracle:**
```sql
SELECT * FROM sales
PIVOT (SUM(amount) FOR quarter IN ([Q1], [Q2], [Q3], [Q4])) p;
```

---

### Q21. Unpivot columns into rows.

```sql
SELECT year, 'Q1' AS quarter, q1 AS amount FROM sales_wide
UNION ALL
SELECT year, 'Q2', q2 FROM sales_wide
UNION ALL
SELECT year, 'Q3', q3 FROM sales_wide
UNION ALL
SELECT year, 'Q4', q4 FROM sales_wide;
```

Postgres also supports `unnest()` with arrays, and SQL Server has `UNPIVOT`.

---

## Self-Joins and Hierarchies

### Q22. Show employees with their manager's name.

**Schema:** `employees(id, name, manager_id)`

```sql
SELECT e.name AS employee, m.name AS manager
FROM employees e
LEFT JOIN employees m ON m.id = e.manager_id;
```

LEFT JOIN ensures the CEO (no manager) still appears.

---

### Q23. Find employees who earn more than their manager.

```sql
SELECT e.name
FROM employees e
JOIN employees m ON m.id = e.manager_id
WHERE e.salary > m.salary;
```

---

### Q24. Find all subordinates of a manager (recursive CTE).

```sql
WITH RECURSIVE subordinates AS (
  SELECT id, name, manager_id
  FROM employees
  WHERE id = 100  -- root manager

  UNION ALL

  SELECT e.id, e.name, e.manager_id
  FROM employees e
  JOIN subordinates s ON e.manager_id = s.id
)
SELECT * FROM subordinates;
```

The recursive part keeps adding employees whose manager is already in the result.

---

### Q25. Find depth of each employee in the org tree.

```sql
WITH RECURSIVE org AS (
  SELECT id, name, manager_id, 0 AS depth
  FROM employees
  WHERE manager_id IS NULL

  UNION ALL

  SELECT e.id, e.name, e.manager_id, o.depth + 1
  FROM employees e
  JOIN org o ON e.manager_id = o.id
)
SELECT * FROM org ORDER BY depth, id;
```

---

### Q26. Find pairs of friends (avoid duplicates).

**Schema:** `friendships(user_a, user_b)` — assume no self-pairs.

```sql
SELECT LEAST(user_a, user_b) AS u1, GREATEST(user_a, user_b) AS u2
FROM friendships
GROUP BY 1, 2;
```

This canonicalises every pair so `(1, 2)` and `(2, 1)` collapse into one.

---

## Statistics: Median, Mode, Percentiles

### Q27. Median salary — three methods.

**Method 1 — PERCENTILE_CONT (Postgres, Oracle, SQL Server):**
```sql
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary) AS median
FROM employees;
```

**Method 2 — Window function with average of middle rows:**
```sql
WITH ranked AS (
  SELECT salary,
         ROW_NUMBER() OVER (ORDER BY salary) AS rn,
         COUNT(*) OVER () AS cnt
  FROM employees
)
SELECT AVG(salary) AS median
FROM ranked
WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2);
```
Handles even and odd row counts uniformly.

**Method 3 — MySQL (no PERCENTILE_CONT before 8.0):**
```sql
SELECT AVG(salary) FROM (
  SELECT salary FROM employees
  ORDER BY salary
  LIMIT 2 - (SELECT COUNT(*) FROM employees) % 2
  OFFSET (SELECT (COUNT(*) - 1) / 2 FROM employees)
) t;
```

---

### Q28. Mode (most common value).

```sql
SELECT category, COUNT(*) AS cnt
FROM products
GROUP BY category
ORDER BY cnt DESC
LIMIT 1;
```

If ties matter:
```sql
WITH counts AS (
  SELECT category, COUNT(*) AS cnt FROM products GROUP BY category
)
SELECT category FROM counts
WHERE cnt = (SELECT MAX(cnt) FROM counts);
```

---

### Q29. Percentile breakdown (e.g., quartiles).

```sql
SELECT
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary) AS q1,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary) AS median,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) AS q3
FROM employees;
```

---

## Date Math and Trends

### Q30. Month-over-month revenue growth.

```sql
WITH monthly AS (
  SELECT
    DATE_TRUNC('month', order_date) AS month,
    SUM(amount) AS revenue
  FROM orders
  GROUP BY 1
)
SELECT
  month,
  revenue,
  LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
  100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) AS mom_growth_pct
FROM monthly
ORDER BY month;
```

`NULLIF` prevents divide-by-zero when the previous month is 0.

---

### Q31. Year-over-year comparison for the same week.

```sql
SELECT
  EXTRACT(WEEK FROM order_date) AS wk,
  SUM(CASE WHEN EXTRACT(YEAR FROM order_date) = 2024 THEN amount END) AS rev_2024,
  SUM(CASE WHEN EXTRACT(YEAR FROM order_date) = 2025 THEN amount END) AS rev_2025
FROM orders
GROUP BY 1
ORDER BY wk;
```

---

### Q32. Find rows where current value > previous value (LAG).

```sql
SELECT id, value, prev_value
FROM (
  SELECT
    id,
    value,
    LAG(value) OVER (ORDER BY id) AS prev_value
  FROM measurements
) t
WHERE value > prev_value;
```

---

### Q33. Days since the last order per user.

```sql
SELECT
  user_id,
  order_date,
  order_date - LAG(order_date) OVER (PARTITION BY user_id ORDER BY order_date) AS days_since_prev
FROM orders;
```

---

### Q34. Find first and last order date per customer.

```sql
SELECT customer_id,
       MIN(order_date) AS first_order,
       MAX(order_date) AS last_order
FROM orders
GROUP BY customer_id;
```

To get the full row, use `FIRST_VALUE` / `LAST_VALUE` window functions or a join back.

---

## Window Function Patterns

### Q35. Difference between ROW_NUMBER, RANK, DENSE_RANK.

| Function | Salary 100 | Salary 100 | Salary 90 | Salary 80 |
|----------|-----------|-----------|-----------|-----------|
| ROW_NUMBER | 1 | 2 | 3 | 4 |
| RANK | 1 | 1 | 3 | 4 |
| DENSE_RANK | 1 | 1 | 2 | 3 |

- **ROW_NUMBER**: unique sequential ids, breaks ties arbitrarily.
- **RANK**: ties share rank, leaves gaps.
- **DENSE_RANK**: ties share rank, no gaps.

---

### Q36. Max value in a window (rolling max).

```sql
SELECT
  reading_time,
  reading,
  MAX(reading) OVER (ORDER BY reading_time
                     ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS rolling_max_10
FROM sensor;
```

---

### Q37. First and last value within partition.

```sql
SELECT
  user_id,
  order_date,
  amount,
  FIRST_VALUE(amount) OVER (PARTITION BY user_id ORDER BY order_date) AS first_amt,
  LAST_VALUE(amount) OVER (
    PARTITION BY user_id ORDER BY order_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS last_amt
FROM orders;
```

`LAST_VALUE` requires the explicit unbounded frame — without it, "last" means "current row" in default frame.

---

### Q38. NTILE — split rows into N buckets.

```sql
SELECT
  user_id,
  total_spend,
  NTILE(4) OVER (ORDER BY total_spend) AS quartile
FROM customer_spend;
```

Useful for cohorting customers into spending tiers.

---

## LeetCode-Style Hard Patterns

### Q39. Trips and users — cancellation rate per day.

**Schema:** `trips(id, client_id, driver_id, status, request_at)`, `users(users_id, banned)`

```sql
SELECT
  request_at AS day,
  ROUND(
    SUM(CASE WHEN status <> 'completed' THEN 1 ELSE 0 END)::numeric
    / COUNT(*), 2
  ) AS cancellation_rate
FROM trips t
JOIN users c ON c.users_id = t.client_id AND c.banned = 'No'
JOIN users d ON d.users_id = t.driver_id AND d.banned = 'No'
WHERE request_at BETWEEN '2025-01-01' AND '2025-01-31'
GROUP BY request_at;
```

---

### Q40. Department highest-paid employees (with ties).

```sql
WITH ranked AS (
  SELECT
    department_id, name, salary,
    DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rnk
  FROM employees
)
SELECT department_id, name, salary
FROM ranked
WHERE rnk = 1;
```

---

### Q41. Human Traffic of Stadium — three or more consecutive days with attendance ≥ 100.

**Schema:** `stadium(id, visit_date, people)`

```sql
WITH qualifying AS (
  SELECT id, visit_date, people,
         id - ROW_NUMBER() OVER (ORDER BY id) AS grp
  FROM stadium
  WHERE people >= 100
)
SELECT id, visit_date, people
FROM qualifying
WHERE grp IN (
  SELECT grp FROM qualifying GROUP BY grp HAVING COUNT(*) >= 3
)
ORDER BY visit_date;
```

---

### Q42. Customers who bought all products.

**Schema:** `customer(customer_id, product_key)`, `product(product_key)`

```sql
SELECT customer_id
FROM customer
GROUP BY customer_id
HAVING COUNT(DISTINCT product_key) = (SELECT COUNT(*) FROM product);
```

Classic relational division pattern.

---

### Q43. Tree node type (root / inner / leaf).

**Schema:** `tree(id, p_id)`

```sql
SELECT id,
  CASE
    WHEN p_id IS NULL THEN 'Root'
    WHEN id IN (SELECT DISTINCT p_id FROM tree WHERE p_id IS NOT NULL) THEN 'Inner'
    ELSE 'Leaf'
  END AS type
FROM tree;
```

---

### Q44. Exchange seats (swap pairs).

**Schema:** `seat(id, student)`

```sql
SELECT
  CASE
    WHEN id % 2 = 1 AND id = (SELECT MAX(id) FROM seat) THEN id
    WHEN id % 2 = 1 THEN id + 1
    ELSE id - 1
  END AS id,
  student
FROM seat
ORDER BY id;
```

---

### Q45. Last person who can fit in the elevator (cumulative weight).

**Schema:** `queue(person_id, person_name, weight, turn)`, weight limit 1000.

```sql
WITH cum AS (
  SELECT person_name, weight, turn,
         SUM(weight) OVER (ORDER BY turn) AS running
  FROM queue
)
SELECT person_name
FROM cum
WHERE running <= 1000
ORDER BY running DESC
LIMIT 1;
```

---

### Q46. Active users for at least 5 consecutive days.

```sql
WITH grp AS (
  SELECT user_id, login_date,
         login_date - INTERVAL '1 day' *
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) AS island
  FROM logins
)
SELECT DISTINCT user_id
FROM grp
GROUP BY user_id, island
HAVING COUNT(*) >= 5;
```

---

### Q47. Customer placed an order both yesterday and today.

```sql
SELECT customer_id
FROM orders
WHERE order_date IN (CURRENT_DATE, CURRENT_DATE - 1)
GROUP BY customer_id
HAVING COUNT(DISTINCT order_date) = 2;
```

---

### Q48. Reverse a string in SQL (Postgres).

```sql
SELECT REVERSE('hello');  -- 'olleh'
```

In dialects without `REVERSE`, use a recursive CTE iterating characters.

---

### Q49. Find the second-most-recent order per user.

```sql
SELECT user_id, order_id, order_date
FROM (
  SELECT user_id, order_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY order_date DESC) AS rn
  FROM orders
) t
WHERE rn = 2;
```

---

### Q50. Detect when a value changes (sessionisation).

```sql
SELECT user_id, event_time, status,
       SUM(CASE WHEN status <> prev_status OR prev_status IS NULL THEN 1 ELSE 0 END)
         OVER (PARTITION BY user_id ORDER BY event_time) AS session_id
FROM (
  SELECT user_id, event_time, status,
         LAG(status) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_status
  FROM events
) t;
```

Each new session starts when status differs from the previous row.

---

## Performance Tips for SQL Puzzles

1. **Prefer window functions over correlated subqueries** — O(n log n) versus O(n²).
2. **Indexes on PARTITION BY + ORDER BY columns** speed up windowed queries.
3. **Avoid SELECT \*** when ranking — wide rows balloon temp storage.
4. **`EXISTS` over `IN`** for subqueries with NULLable columns.
5. **`UNION ALL` over `UNION`** if duplicates aren't an issue — saves a sort.
6. **Beware row multiplication** when joining one-to-many before aggregation; aggregate first or use window functions.
7. **Use `EXPLAIN ANALYZE`** to verify the planner picks expected indexes.

---

## Practice Checklist

- [ ] Nth highest salary, three ways
- [ ] Top-N per group with ties handled
- [ ] Find and delete duplicates
- [ ] Running total / moving average
- [ ] Median via window function
- [ ] Customers with no orders (anti-join)
- [ ] Consecutive-day streaks (gaps and islands)
- [ ] Pivot quarterly sales
- [ ] Recursive CTE for org hierarchy
- [ ] Month-over-month growth %
- [ ] LAG/LEAD comparisons
- [ ] PERCENTILE_CONT for quartiles
- [ ] Sessionisation by status change
