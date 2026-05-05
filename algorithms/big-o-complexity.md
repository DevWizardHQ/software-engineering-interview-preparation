# Big-O Complexity — Senior Reference

**Purpose:** Master Big-O notation for senior interviews. Covers definitions, how to analyse code, common growth rates, space complexity, amortised analysis, and a cheat sheet of every operation you will be asked about.

---

## Table of Contents

1. [What Big-O Actually Means](#what-big-o-actually-means)
2. [Big-O, Big-Theta, Big-Omega](#big-o-big-theta-big-omega)
3. [Common Growth Rates](#common-growth-rates)
4. [Calculating Big-O — Step by Step](#calculating-big-o--step-by-step)
5. [Space Complexity](#space-complexity)
6. [Amortised Analysis](#amortised-analysis)
7. [Best, Average, Worst Case](#best-average-worst-case)
8. [Recursion and Master Theorem](#recursion-and-master-theorem)
9. [Worked Examples](#worked-examples)
10. [Cheat Sheet — Every Common Operation](#cheat-sheet--every-common-operation)

---

## What Big-O Actually Means

Big-O describes the **upper bound on the growth rate** of a function as input size n approaches infinity. It abstracts away constant factors and lower-order terms.

Formal definition: `f(n) = O(g(n))` if there exist positive constants c and n₀ such that `f(n) ≤ c · g(n)` for all `n ≥ n₀`.

**What it ignores:**
- Constant factors: `O(2n) = O(n)` — `O(100n)` and `O(n)` are the same
- Lower-order terms: `O(n² + n) = O(n²)`
- Different bases of logarithms: `log₂(n)` and `log₁₀(n)` differ by a constant → both `O(log n)`

**Why we care:** the difference between O(n) and O(n²) becomes catastrophic at scale. At n = 1,000,000:
- O(log n) ≈ 20 ops
- O(n) = 1,000,000 ops
- O(n log n) ≈ 20,000,000 ops
- O(n²) = 1,000,000,000,000 ops (a million times slower than O(n))

---

## Big-O, Big-Theta, Big-Omega

| Notation | Meaning | Bound |
|----------|---------|-------|
| O(g(n)) | Upper bound | f grows **no faster** than g |
| Ω(g(n)) | Lower bound | f grows **at least as fast** as g |
| Θ(g(n)) | Tight bound | f grows **exactly** as g (both O and Ω) |
| o(g(n)) | Strict upper | f grows strictly slower than g |
| ω(g(n)) | Strict lower | f grows strictly faster than g |

In interviews, **Big-O usually means tight (Θ)** unless someone explicitly asks for the loosest upper bound. Don't say a linear scan is "O(2ⁿ)" just because it's technically true.

---

## Common Growth Rates

Ordered fastest → slowest:

| Notation | Name | Example |
|----------|------|---------|
| O(1) | Constant | Hash map lookup, array index |
| O(log n) | Logarithmic | Binary search, balanced BST operation |
| O(√n) | Square root | Trial division for primes |
| O(n) | Linear | Single loop, linked list scan |
| O(n log n) | Linearithmic | Merge sort, heap sort, FFT |
| O(n²) | Quadratic | Nested loops over array, bubble sort |
| O(n³) | Cubic | Naive matrix multiply, Floyd–Warshall |
| O(2ⁿ) | Exponential | Power set, naive recursive Fibonacci |
| O(n!) | Factorial | Brute-force permutations, travelling salesman |

### Visualising at n = 100

| Complexity | Approximate ops |
|------------|-----------------|
| O(1) | 1 |
| O(log n) | 7 |
| O(n) | 100 |
| O(n log n) | 700 |
| O(n²) | 10,000 |
| O(n³) | 1,000,000 |
| O(2ⁿ) | 1.27 × 10³⁰ |
| O(n!) | 9.33 × 10¹⁵⁷ |

### Practical input limits (1-second budget at ~10⁸ ops)

| Complexity | Max n |
|------------|-------|
| O(n!) | ~11 |
| O(2ⁿ) | ~25 |
| O(n³) | ~500 |
| O(n²) | ~10,000 |
| O(n log n) | ~10⁶ |
| O(n) | ~10⁸ |
| O(log n) | virtually unlimited |

If a problem mentions n ≤ 10⁵, you almost certainly need O(n log n) or better.

---

## Calculating Big-O — Step by Step

### Rules

1. **Drop constants**: `O(3n) = O(n)`.
2. **Drop lower-order terms**: `O(n² + n + 100) = O(n²)`.
3. **Add for sequential code**: `O(a) + O(b) = O(a + b)`.
4. **Multiply for nested loops**: outer × inner.
5. **Different inputs = different variables**: don't conflate two arrays of sizes a and b — use `O(a + b)` or `O(a · b)`.

### Example 1 — Sequential

```javascript
for (let i = 0; i < n; i++) console.log(i);  // O(n)
for (let i = 0; i < n; i++) console.log(i);  // O(n)
// Total: O(n) + O(n) = O(2n) = O(n)
```

### Example 2 — Nested

```javascript
for (let i = 0; i < n; i++) {
  for (let j = 0; j < n; j++) {
    console.log(i, j);                       // executed n² times
  }
}
// O(n²)
```

### Example 3 — Different inputs

```javascript
function intersect(a, b) {
  const set = new Set(a);                    // O(a)
  return b.filter(x => set.has(x));          // O(b)
}
// O(a + b), not O(n²)
```

### Example 4 — Halving each iteration

```javascript
let i = n;
while (i > 1) i = i / 2;                     // log₂(n) iterations
// O(log n)
```

### Example 5 — Recursive doubling

```javascript
function f(n) {
  if (n <= 1) return;
  f(n - 1);
  f(n - 1);
}
// T(n) = 2 T(n-1) + 1 → O(2ⁿ)
```

---

## Space Complexity

Same notation, but counts memory rather than time. Includes:

- Auxiliary data structures
- Recursion call stack (each frame counts)
- Output size — sometimes excluded ("excluding output" caveat)

### Example

```javascript
function sum(nums) {
  let total = 0;                             // O(1)
  for (const n of nums) total += n;
  return total;
}
// Space: O(1)
```

```javascript
function reverse(s) {
  return s.split('').reverse().join('');     // O(n) intermediate array
}
// Space: O(n)
```

### Recursion stack

```javascript
function fact(n) {
  if (n <= 1) return 1;
  return n * fact(n - 1);                    // n call frames live at once
}
// Time: O(n), Space: O(n) due to call stack
```

Tail-call-optimising languages can reduce this to O(1), but JavaScript engines mostly do not implement TCO in practice. Convert to a loop if stack depth matters.

---

## Amortised Analysis

The **average cost per operation over a sequence**, even when individual ops vary.

### Dynamic array (push)

A push is usually O(1). When the array fills up, it doubles in capacity, copying all elements: O(n).

Sequence of n pushes:
- Most pushes: 1 op
- Resizes happen at sizes 1, 2, 4, 8, ..., n → total resize cost = 1 + 2 + 4 + ... + n ≈ 2n
- Total: ~3n ops over n pushes → O(1) amortised per push

### Hash map (insert)

Same logic — occasional rehashing keeps the load factor bounded, costs O(n) once but only every doubling.

### Why "amortised" matters

A real-time system might still care about the worst-case spike. Amortised guarantees average behaviour — they don't bound any single operation.

---

## Best, Average, Worst Case

| Algorithm | Best | Average | Worst |
|-----------|------|---------|-------|
| Linear search | O(1) (first element) | O(n) | O(n) |
| Binary search | O(1) (middle) | O(log n) | O(log n) |
| Bubble sort | O(n) (sorted, with early exit) | O(n²) | O(n²) |
| Insertion sort | O(n) | O(n²) | O(n²) |
| Quick sort | O(n log n) | O(n log n) | O(n²) (bad pivots) |
| Merge sort | O(n log n) | O(n log n) | O(n log n) |
| Heap sort | O(n log n) | O(n log n) | O(n log n) |
| Hash map lookup | O(1) | O(1) | O(n) (all keys collide) |

In interviews, when complexity is not qualified, **assume worst case**. Senior candidates state which case they're discussing.

---

## Recursion and Master Theorem

For divide-and-conquer recurrences of the form:

`T(n) = a · T(n/b) + f(n)`

where:
- a = number of subproblems
- b = factor by which input shrinks
- f(n) = work done outside recursion (combine step)

| Comparison | Result |
|------------|--------|
| f(n) = O(n^c) where c < log_b(a) | T(n) = Θ(n^(log_b a)) |
| f(n) = Θ(n^c) where c = log_b(a) | T(n) = Θ(n^c · log n) |
| f(n) = Ω(n^c) where c > log_b(a) | T(n) = Θ(f(n)) |

### Examples

**Merge sort:** `T(n) = 2T(n/2) + O(n)` → a = 2, b = 2, log₂2 = 1, f(n) = n¹. Case 2 → **O(n log n)**.

**Binary search:** `T(n) = T(n/2) + O(1)` → a = 1, b = 2, log₂1 = 0, f(n) = 1 = n⁰. Case 2 → **O(log n)**.

**Strassen's matrix mult:** `T(n) = 7T(n/2) + O(n²)` → log₂7 ≈ 2.807, f(n) = n². Case 1 → **O(n^2.807)**.

**Karatsuba multiplication:** `T(n) = 3T(n/2) + O(n)` → log₂3 ≈ 1.585. Case 1 → **O(n^1.585)**.

---

## Worked Examples

### Q1. Two nested loops over half each.

```javascript
for (let i = 0; i < n / 2; i++) {
  for (let j = 0; j < n / 2; j++) { /* O(1) */ }
}
```

(n/2) × (n/2) = n²/4 = **O(n²)**.

### Q2. Loop where i doubles.

```javascript
for (let i = 1; i < n; i *= 2) { /* O(1) */ }
```

i takes values 1, 2, 4, ..., n → log₂n iterations → **O(log n)**.

### Q3. Outer linear, inner logarithmic.

```javascript
for (let i = 0; i < n; i++) {
  let j = 1;
  while (j < n) { j *= 2; }
}
```

n × log n = **O(n log n)**.

### Q4. Outer divides, inner linear.

```javascript
for (let i = n; i > 0; i = Math.floor(i / 2)) {
  for (let j = 0; j < n; j++) { /* O(1) */ }
}
```

(log n) × n = **O(n log n)**.

### Q5. Triangular nested loop.

```javascript
for (let i = 0; i < n; i++) {
  for (let j = i; j < n; j++) { /* O(1) */ }
}
```

Sum: n + (n−1) + (n−2) + ... + 1 = n(n+1)/2 → **O(n²)**.

### Q6. Recursive Fibonacci.

```javascript
function fib(n) {
  if (n < 2) return n;
  return fib(n - 1) + fib(n - 2);
}
```

T(n) = T(n−1) + T(n−2) + O(1) → **O(2ⁿ)** time, **O(n)** stack space.

### Q7. Power set generation.

```javascript
function subsets(nums) {
  const res = [[]];
  for (const n of nums) {
    const len = res.length;
    for (let i = 0; i < len; i++) res.push([...res[i], n]);
  }
  return res;
}
```

Each iteration doubles the result size. Final size is 2ⁿ, and producing each set takes O(n) for the spread. → **O(n · 2ⁿ)** time and space.

### Q8. String matching via substring.

```javascript
text.includes(pattern);
```

Naive impl: **O(n · m)** where n = |text|, m = |pattern|.
KMP / Boyer–Moore: **O(n + m)**.

---

## Cheat Sheet — Every Common Operation

### Array

| Operation | Time |
|-----------|------|
| Access by index | O(1) |
| Search unsorted | O(n) |
| Search sorted (binary) | O(log n) |
| Append | O(1) amortised |
| Prepend | O(n) |
| Insert middle | O(n) |
| Delete middle | O(n) |
| Iterate | O(n) |

### Linked List (singly)

| Operation | Time |
|-----------|------|
| Access | O(n) |
| Insert head | O(1) |
| Insert tail | O(1) with tail pointer, else O(n) |
| Delete head | O(1) |
| Delete tail | O(n) |
| Search | O(n) |

### Hash Map

| Operation | Average | Worst |
|-----------|---------|-------|
| Insert | O(1) | O(n) |
| Lookup | O(1) | O(n) |
| Delete | O(1) | O(n) |
| Iterate | O(n) | O(n) |

### Balanced BST (AVL, Red-Black)

| Operation | Time |
|-----------|------|
| Insert | O(log n) |
| Search | O(log n) |
| Delete | O(log n) |
| Min / Max | O(log n) |
| In-order traversal | O(n) |

### Heap (binary)

| Operation | Time |
|-----------|------|
| Insert | O(log n) |
| Peek | O(1) |
| Extract min/max | O(log n) |
| Build heap | O(n) |
| Search | O(n) |

### Trie

| Operation | Time |
|-----------|------|
| Insert key (length k) | O(k) |
| Search key | O(k) |
| Prefix lookup | O(k) |

### Graph (V vertices, E edges)

| Algorithm | Time |
|-----------|------|
| BFS / DFS | O(V + E) |
| Dijkstra (binary heap) | O((V + E) log V) |
| Bellman–Ford | O(V · E) |
| Floyd–Warshall | O(V³) |
| Topological sort | O(V + E) |
| Prim / Kruskal MST | O(E log V) |

### Sorting

| Algorithm | Best | Avg | Worst | Space | Stable |
|-----------|------|-----|-------|-------|--------|
| Bubble | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Insertion | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Selection | O(n²) | O(n²) | O(n²) | O(1) | No |
| Merge | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes |
| Quick | O(n log n) | O(n log n) | O(n²) | O(log n) | No |
| Heap | O(n log n) | O(n log n) | O(n log n) | O(1) | No |
| Counting | O(n + k) | O(n + k) | O(n + k) | O(k) | Yes |
| Radix | O(nk) | O(nk) | O(nk) | O(n + k) | Yes |
| TimSort (JS / Python default) | O(n) | O(n log n) | O(n log n) | O(n) | Yes |

### Searching

| Algorithm | Time |
|-----------|------|
| Linear | O(n) |
| Binary (sorted) | O(log n) |
| Hash lookup | O(1) avg |
| BST | O(log n) avg, O(n) worst |
| Trie prefix | O(k) |

---

## Senior-Level Discussion Points

1. **Big-O ignores constants but production doesn't.** A "slow" O(n log n) sort with good cache behaviour can beat a "fast" O(n) algorithm with random memory access.
2. **Amortised vs worst case** matters for real-time systems. Java's `ArrayList.add` is amortised O(1) but a single resize can stall the request.
3. **Memory hierarchy effects** — RAM access ≈ 100 ns, L1 cache ≈ 1 ns. Algorithms with sequential memory access can run 10–100× faster than their Big-O peers.
4. **I/O dominates** — disk seek ≈ 10 ms, network round-trip ≈ 1–100 ms. A query that does 10 random disk reads beats one that does 1,000 sequential reads, despite worse Big-O.
5. **Big-O of n where n is large vs small** — many algorithms have a small-n regime where the "slower" choice wins (insertion sort within quick sort partitions, for instance).
6. **Lower bounds** — comparison sorts cannot beat O(n log n); you need to exploit structure (counting/radix) to do better.
7. **Probabilistic data structures** (Bloom filter, HyperLogLog, Count-Min Sketch) trade exactness for sublinear space — answer "approximately yes/no" with bounded error.
8. **Online vs offline algorithms** — knowing the full input ahead of time may enable faster offline algorithms; streaming algorithms must process data in one pass with limited memory.

---

## Quick-Reference: How to Spot Complexity Hints in Problem Statements

| Hint | Likely required complexity |
|------|----------------------------|
| n ≤ 10 | O(n!), O(2ⁿ) — backtracking |
| n ≤ 20 | O(2ⁿ) bitmask DP |
| n ≤ 500 | O(n³) — DP with three loops |
| n ≤ 5,000 | O(n²) |
| n ≤ 10⁶ | O(n log n) or O(n) |
| n ≤ 10⁹ | O(log n), O(√n) |
| n ≤ 10¹⁸ | O(1), O(log n), or math formula |

When the constraint suggests a complexity, your algorithm should match — significantly worse and you will TLE; significantly better is fine but rarely necessary.
