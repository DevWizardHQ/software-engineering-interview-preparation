# Big-O Complexity

A pedagogical Q&A guide to Big-O notation, complexity analysis, and the time/space costs of every common operation. Each question explains the concept and includes a code example to make it concrete.

---

## 1. Concepts

## Q1. What does Big-O notation actually mean?

**Answer:**

Big-O describes the **upper bound on the growth rate** of a function as input size n approaches infinity. It abstracts away constant factors and lower-order terms.

Formally: `f(n) = O(g(n))` if there exist positive constants c and n₀ such that `f(n) ≤ c · g(n)` for all `n ≥ n₀`.

What Big-O **ignores**:
- Constant factors: `O(2n) = O(n)`
- Lower-order terms: `O(n² + n) = O(n²)`
- Logarithm bases: `log₂(n)` and `log₁₀(n)` differ by a constant → both `O(log n)`

```javascript
function example(n) {
  let total = 0;
  for (let i = 0; i < n; i++) total += i;     // O(n)
  for (let i = 0; i < n; i++) total += i;     // O(n)
  return total;
}
// 2n simplifies to O(n)
```

## Q2. Why does Big-O matter at scale?

**Answer:**

Differences between complexity classes become catastrophic at large n. At n = 1,000,000:

- O(log n) ≈ 20 ops
- O(n) = 1,000,000 ops
- O(n log n) ≈ 20,000,000 ops
- O(n²) = 1,000,000,000,000 ops (a million times slower than O(n))

That's why an O(n) solution beats an O(n²) one even on inputs in the thousands.

## Q3. What is the difference between Big-O, Big-Theta, and Big-Omega?

**Answer:**

| Notation | Meaning | Bound |
|----------|---------|-------|
| O(g(n)) | Upper bound | f grows **no faster** than g |
| Ω(g(n)) | Lower bound | f grows **at least as fast** as g |
| Θ(g(n)) | Tight bound | f grows **exactly** as g (both O and Ω) |
| o(g(n)) | Strict upper | f grows strictly slower than g |
| ω(g(n)) | Strict lower | f grows strictly faster than g |

In interviews, **Big-O usually means tight (Θ)** unless asked for the loosest upper bound. Don't say a linear scan is "O(2ⁿ)" just because technically true.

## Q4. What are the common growth rates ranked from fastest to slowest?

**Answer:**

| Notation | Name | Example |
|----------|------|---------|
| O(1) | Constant | Hash map lookup, array index |
| O(log n) | Logarithmic | Binary search, balanced BST |
| O(√n) | Square root | Trial division for primes |
| O(n) | Linear | Single loop, linked list scan |
| O(n log n) | Linearithmic | Merge sort, heap sort |
| O(n²) | Quadratic | Nested loops, bubble sort |
| O(n³) | Cubic | Naive matrix multiply, Floyd–Warshall |
| O(2ⁿ) | Exponential | Power set, naive recursive Fibonacci |
| O(n!) | Factorial | Brute-force permutations |

## Q5. What input size can each complexity handle in 1 second?

**Answer:**

Assuming roughly 10⁸ basic operations per second:

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

## 2. Calculating Big-O

## Q6. What are the rules for computing Big-O?

**Answer:**

1. **Drop constants**: `O(3n) = O(n)`.
2. **Drop lower-order terms**: `O(n² + n + 100) = O(n²)`.
3. **Add for sequential code**: `O(a) + O(b) = O(a + b)`.
4. **Multiply for nested loops**: outer × inner.
5. **Different inputs = different variables**: don't conflate two arrays of sizes a and b — use `O(a + b)` or `O(a · b)`.

## Q7. What is the complexity of two sequential loops?

**Answer:**

```javascript
for (let i = 0; i < n; i++) console.log(i);  // O(n)
for (let i = 0; i < n; i++) console.log(i);  // O(n)
// Total: O(n) + O(n) = O(2n) = O(n)
```

Sequential code adds, not multiplies.

## Q8. What is the complexity of a nested loop?

**Answer:**

```javascript
for (let i = 0; i < n; i++) {
  for (let j = 0; j < n; j++) {
    console.log(i, j);    // executed n² times
  }
}
// O(n²)
```

## Q9. How do you analyze a function with two different inputs?

**Answer:**

Use separate variables — don't lump them together as a single n.

```javascript
function intersect(a, b) {
  const set = new Set(a);                   // O(a)
  return b.filter(x => set.has(x));         // O(b)
}
// O(a + b), not O(n²)
```

## Q10. Why is a halving loop O(log n)?

**Answer:**

```javascript
let i = n;
while (i > 1) i = i / 2;                    // log₂(n) iterations
// O(log n)
```

If you halve the input each step, you reach 1 in about log₂(n) steps. The same logic explains why binary search is O(log n).

## Q11. Why is a doubling loop O(log n)?

**Answer:**

```javascript
for (let i = 1; i < n; i *= 2) { /* O(1) */ }
```

i takes values 1, 2, 4, 8, ..., n — that's log₂(n) iterations.

## Q12. What is the complexity of a loop where i doubles inside an outer loop?

**Answer:**

```javascript
for (let i = 0; i < n; i++) {
  let j = 1;
  while (j < n) { j *= 2; }
}
// n × log n = O(n log n)
```

## Q13. What is the complexity of a triangular nested loop?

**Answer:**

```javascript
for (let i = 0; i < n; i++) {
  for (let j = i; j < n; j++) { /* O(1) */ }
}
```

Sum of iterations = n + (n−1) + ... + 1 = n(n+1)/2 → **O(n²)**. The shape is half a square but big-O drops the constant 1/2.

## Q14. What is the complexity of recursive Fibonacci?

**Answer:**

```javascript
function fib(n) {
  if (n < 2) return n;
  return fib(n - 1) + fib(n - 2);
}
```

T(n) = T(n−1) + T(n−2) + O(1) → **O(2ⁿ)** time, **O(n)** stack space. Each call branches into two more calls, building a binary tree of depth n.

## Q15. What is the complexity of generating the power set?

**Answer:**

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

Each iteration doubles the result. Final size is 2ⁿ, and copying each subset takes O(n) → **O(n · 2ⁿ)** time and space.

---

## 3. Space Complexity

## Q16. What is space complexity?

**Answer:**

Same notation as time complexity, but counts memory used. Includes auxiliary data structures, recursion call stack, and (sometimes) output.

```javascript
function sum(nums) {
  let total = 0;                            // O(1) extra
  for (const n of nums) total += n;
  return total;
}
// Space: O(1)
```

```javascript
function reverse(s) {
  return s.split('').reverse().join('');    // O(n) intermediate array
}
// Space: O(n)
```

## Q17. Does recursion add space complexity?

**Answer:**

Yes — each recursive call adds a frame to the call stack until it returns.

```javascript
function fact(n) {
  if (n <= 1) return 1;
  return n * fact(n - 1);                   // n frames live at once
}
// Time: O(n), Space: O(n)
```

JavaScript engines do not implement tail-call optimization in practice, so converting to a loop is the safe way to bound stack depth.

## Q18. How can you reduce space complexity in DP problems?

**Answer:**

Use rolling arrays — keep only the rows or columns the recurrence actually needs.

```javascript
// 2D DP — O(n²) space
function lcs(a, b) {
  const dp = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
  // ...
}

// Rolling — O(n) space if recurrence only needs the previous row
function climbStairs(n) {
  let prev = 1, curr = 1;
  for (let i = 2; i <= n; i++) {
    [prev, curr] = [curr, prev + curr];
  }
  return curr;
}
// Space: O(1)
```

---

## 4. Amortised Analysis

## Q19. What is amortised analysis?

**Answer:**

The **average cost per operation over a sequence**, even when individual operations vary in cost.

```javascript
const arr = [];
for (let i = 0; i < n; i++) arr.push(i);
// Most pushes cost O(1). Some trigger a resize (O(n)). Total cost ≤ ~3n.
// Amortised cost per push: O(1).
```

A push is usually O(1). When the array fills, it doubles capacity — copying all elements is O(n). But resizes happen at sizes 1, 2, 4, 8, …, n, and the total resize cost is at most 2n. So n pushes cost roughly 3n total, which is O(1) amortised per push.

## Q20. Why does "amortised" not always equal "fast in practice"?

**Answer:**

A real-time system might still care about the worst-case spike. Amortised guarantees average behaviour but doesn't bound any single operation. A user request that hits a hash-map resize can stall noticeably even though the average is fast.

---

## 5. Best, Average, Worst Case

## Q21. What is the best, average, and worst case for common algorithms?

**Answer:**

| Algorithm | Best | Average | Worst |
|-----------|------|---------|-------|
| Linear search | O(1) | O(n) | O(n) |
| Binary search | O(1) | O(log n) | O(log n) |
| Bubble sort | O(n) (sorted, with early exit) | O(n²) | O(n²) |
| Insertion sort | O(n) | O(n²) | O(n²) |
| Quick sort | O(n log n) | O(n log n) | O(n²) (bad pivots) |
| Merge sort | O(n log n) | O(n log n) | O(n log n) |
| Heap sort | O(n log n) | O(n log n) | O(n log n) |
| Hash map lookup | O(1) | O(1) | O(n) (all keys collide) |

When unqualified, **assume worst case**. Senior candidates state which case they're discussing.

---

## 6. Master Theorem

## Q22. What is the Master Theorem?

**Answer:**

For divide-and-conquer recurrences of the form `T(n) = a · T(n/b) + f(n)`:

- a = number of subproblems
- b = factor by which input shrinks
- f(n) = work done outside the recursion

| Comparison | Result |
|------------|--------|
| f(n) = O(n^c) where c < log_b(a) | T(n) = Θ(n^(log_b a)) |
| f(n) = Θ(n^c) where c = log_b(a) | T(n) = Θ(n^c · log n) |
| f(n) = Ω(n^c) where c > log_b(a) | T(n) = Θ(f(n)) |

## Q23. Apply the Master Theorem to merge sort.

**Answer:**

`T(n) = 2T(n/2) + O(n)` → a = 2, b = 2, log₂2 = 1, f(n) = n¹. Case 2 applies → **O(n log n)**.

```javascript
function mergeSort(arr) {
  if (arr.length <= 1) return arr;
  const mid = arr.length >> 1;
  const left = mergeSort(arr.slice(0, mid));     // T(n/2)
  const right = mergeSort(arr.slice(mid));        // T(n/2)
  return merge(left, right);                      // O(n)
}
```

## Q24. Apply the Master Theorem to binary search.

**Answer:**

`T(n) = T(n/2) + O(1)` → a = 1, b = 2, log₂1 = 0, f(n) = 1 = n⁰. Case 2 → **O(log n)**.

---

## 7. Cheat Sheet — Operation Costs

## Q25. What are the array operation costs?

**Answer:**

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

```javascript
arr[5];           // O(1)
arr.push(x);      // O(1) amortised
arr.unshift(x);   // O(n)
arr.indexOf(x);   // O(n)
```

## Q26. What are the singly-linked-list operation costs?

**Answer:**

| Operation | Time |
|-----------|------|
| Access | O(n) |
| Insert head | O(1) |
| Insert tail | O(1) with tail pointer, else O(n) |
| Delete head | O(1) |
| Delete tail | O(n) |
| Search | O(n) |

## Q27. What are the hash map operation costs?

**Answer:**

| Operation | Average | Worst |
|-----------|---------|-------|
| Insert | O(1) | O(n) |
| Lookup | O(1) | O(n) |
| Delete | O(1) | O(n) |
| Iterate | O(n) | O(n) |

Worst case is rare in practice but possible with bad hash functions or adversarial input (HashDoS).

## Q28. What are the balanced BST (AVL, Red-Black) operation costs?

**Answer:**

| Operation | Time |
|-----------|------|
| Insert | O(log n) |
| Search | O(log n) |
| Delete | O(log n) |
| Min / Max | O(log n) |
| In-order traversal | O(n) |

## Q29. What are the binary heap operation costs?

**Answer:**

| Operation | Time |
|-----------|------|
| Insert | O(log n) |
| Peek | O(1) |
| Extract min/max | O(log n) |
| Build heap | O(n) |
| Search | O(n) |

`Build heap` is O(n) — surprisingly faster than n inserts of O(log n) — thanks to bottom-up heapify.

## Q30. What are the trie operation costs?

**Answer:**

For a key of length k:

| Operation | Time |
|-----------|------|
| Insert | O(k) |
| Search | O(k) |
| Prefix lookup | O(k) |

Note these costs are independent of n (number of stored keys).

## Q31. What are the graph algorithm costs?

**Answer:**

For V vertices and E edges:

| Algorithm | Time |
|-----------|------|
| BFS / DFS | O(V + E) |
| Dijkstra (binary heap) | O((V + E) log V) |
| Bellman–Ford | O(V · E) |
| Floyd–Warshall | O(V³) |
| Topological sort | O(V + E) |
| Prim / Kruskal MST | O(E log V) |

## Q32. What are the costs of sorting algorithms?

**Answer:**

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

---

## 8. Practical Considerations

## Q33. Why does cache locality matter even when Big-O is identical?

**Answer:**

Modern CPUs read memory in cache lines (typically 64 bytes). Sequential access prefetches the next chunk; random access stalls waiting for RAM. Iterating an array of 1 million ints can run 10–100× faster than iterating an equivalent linked list — same Big-O, very different real-world speed.

```javascript
// Both are O(n), but the array is dramatically faster in practice
const arr = new Array(1_000_000).fill(0);
let sum = 0;
for (let i = 0; i < arr.length; i++) sum += arr[i];
```

## Q34. How do I-O costs change algorithm choice?

**Answer:**

Memory hierarchy approximate latencies:
- L1 cache ≈ 1 ns
- RAM ≈ 100 ns
- SSD ≈ 100 µs
- Disk seek ≈ 10 ms
- Network round-trip ≈ 1–100 ms

A query that does 10 random disk reads beats one that does 1,000 sequential reads, despite worse Big-O on operation count. This is why databases use B+trees (wide, shallow) instead of binary trees.

## Q35. Why is comparison sorting bounded at O(n log n)?

**Answer:**

Any comparison-based sort can be modelled as a decision tree. With n! possible orderings, the tree has at least log₂(n!) levels, which is Θ(n log n). To go faster you must avoid comparisons — counting sort and radix sort exploit numeric structure to achieve O(n + k) and O(nk).

## Q36. What are probabilistic data structures and when do they help?

**Answer:**

Bloom filter, HyperLogLog, and Count-Min Sketch trade exactness for sublinear space — they answer "approximately" with bounded error.

```javascript
// Bloom filter — fast membership test with possible false positives
class BloomFilter {
  constructor(size, hashCount) {
    this.bits = new Array(size).fill(false);
    this.size = size;
    this.k = hashCount;
  }
  _hashes(item) {
    const h = Array.from(String(item)).reduce((a, c) => a * 31 + c.charCodeAt(0), 0);
    return Array.from({ length: this.k }, (_, i) => Math.abs((h + i * 17) % this.size));
  }
  add(item) { for (const h of this._hashes(item)) this.bits[h] = true; }
  has(item) { return this._hashes(item).every(h => this.bits[h]); }
}
```

## Q37. How do you spot the required complexity from the constraints?

**Answer:**

| Constraint | Likely required complexity |
|------------|----------------------------|
| n ≤ 10 | O(n!), O(2ⁿ) — backtracking |
| n ≤ 20 | O(2ⁿ) bitmask DP |
| n ≤ 500 | O(n³) — DP with three loops |
| n ≤ 5,000 | O(n²) |
| n ≤ 10⁶ | O(n log n) or O(n) |
| n ≤ 10⁹ | O(log n), O(√n) |
| n ≤ 10¹⁸ | O(1), O(log n), or math formula |

When the constraint suggests a complexity, your algorithm should match — significantly worse and you will time out; significantly better is fine but rarely necessary.
