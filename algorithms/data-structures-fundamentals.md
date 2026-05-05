# Data Structures Fundamentals

A pedagogical Q&A guide to the data structures every full-stack engineer must know. Each question explains how the structure works, its operation complexities, when to use it, and includes a working JavaScript implementation.

---

## 1. Arrays

## Q1. What is an array and how does indexing work in O(1)?

**Answer:**

An array is a contiguous block of memory that holds fixed-size elements. Index access is O(1) because the address of element `i` is computed directly: `base + i × element_size`. No traversal is needed.

```javascript
const arr = [10, 20, 30, 40];
console.log(arr[2]); // O(1) — directly computes the address
```

Static arrays (C, Java's `int[]`) have a fixed size at allocation. Dynamic arrays (JS `Array`, Python `list`, Java `ArrayList`) automatically resize, typically doubling capacity when full.

## Q2. What are the time complexities for array operations?

**Answer:**

| Operation | Time | Notes |
|-----------|------|-------|
| Index access | O(1) | Random access by position |
| Search (unsorted) | O(n) | Linear scan |
| Search (sorted) | O(log n) | Binary search |
| Append (end) | O(1) amortised | Occasional resize is O(n) |
| Insert (middle) | O(n) | Shifts later elements |
| Insert (front) | O(n) | Shifts everything |
| Delete (middle) | O(n) | Same shift problem |
| Pop (end) | O(1) | |

```javascript
const arr = [1, 2, 3, 4, 5];
arr.push(6);          // O(1) amortised
arr.splice(2, 0, 99); // O(n) — shifts later elements
arr[0];               // O(1)
```

## Q3. Why is appending to a dynamic array O(1) amortised?

**Answer:**

Doubling means n appends cost `n + n/2 + n/4 + ...` ≤ 2n total work. Spread across n operations, the average is O(1) per append, even though some individual appends trigger an O(n) resize.

```javascript
// Most pushes are cheap. Occasionally one triggers a resize and copies
// the entire backing array. Long-run average remains O(1).
const arr = [];
for (let i = 0; i < 1_000_000; i++) arr.push(i);
```

## Q4. When should you avoid arrays?

**Answer:**

- **Frequent inserts or deletes in the middle** — every operation shifts elements
- **Unknown growth pattern with very large size** — consider a rope, skip list, or chunked structure
- **Pointer-stable references needed** — array reallocation invalidates pointers

---

## 2. Linked Lists

## Q5. What is a singly linked list?

**Answer:**

A singly linked list is a sequence of nodes where each node holds a value and a pointer to the next node. There is no random access — to reach the kth element, you walk k pointers.

```javascript
class Node {
  constructor(val, next = null) { this.val = val; this.next = next; }
}

class LinkedList {
  constructor() { this.head = null; this.size = 0; }

  prepend(val) {                              // O(1)
    this.head = new Node(val, this.head);
    this.size++;
  }

  append(val) {                               // O(n) — must walk to tail
    if (!this.head) return this.prepend(val);
    let n = this.head;
    while (n.next) n = n.next;
    n.next = new Node(val);
    this.size++;
  }

  removeFirst() {                             // O(1)
    if (!this.head) return null;
    const val = this.head.val;
    this.head = this.head.next;
    this.size--;
    return val;
  }

  remove(val) {                               // O(n)
    if (!this.head) return false;
    if (this.head.val === val) { this.head = this.head.next; this.size--; return true; }
    let n = this.head;
    while (n.next && n.next.val !== val) n = n.next;
    if (!n.next) return false;
    n.next = n.next.next;
    this.size--;
    return true;
  }
}
```

## Q6. What is a doubly linked list and why use one?

**Answer:**

Each node has both `prev` and `next` pointers. This enables O(1) deletion given a node reference and O(1) insertion at both ends. Used by LRU caches, the DOM, and most language `Deque` implementations.

```javascript
class DNode {
  constructor(val) { this.val = val; this.prev = null; this.next = null; }
}

class DoublyLinkedList {
  constructor() { this.head = null; this.tail = null; this.size = 0; }

  append(val) {                               // O(1)
    const node = new DNode(val);
    if (!this.tail) { this.head = this.tail = node; }
    else { node.prev = this.tail; this.tail.next = node; this.tail = node; }
    this.size++;
    return node;
  }

  remove(node) {                              // O(1) given the node reference
    if (node.prev) node.prev.next = node.next; else this.head = node.next;
    if (node.next) node.next.prev = node.prev; else this.tail = node.prev;
    this.size--;
  }
}
```

## Q7. What is a circular linked list?

**Answer:**

In a circular linked list the tail's `next` points back to the head (singly), or to head plus head's `prev` points to tail (doubly). Useful for round-robin scheduling and ring buffers.

```javascript
function makeCircular(values) {
  const head = { val: values[0], next: null };
  let curr = head;
  for (let i = 1; i < values.length; i++) {
    curr.next = { val: values[i], next: null };
    curr = curr.next;
  }
  curr.next = head; // close the ring
  return head;
}
```

## Q8. When should you use a linked list vs an array?

**Answer:**

| Need | Better choice |
|------|----------------|
| Random index access | Array |
| Frequent inserts/deletes at known positions | Linked list |
| Cache-friendly iteration | Array (contiguous memory) |
| LRU cache | Doubly linked list + hash map |
| Implementing a queue or deque | Linked list |

In practice arrays often beat linked lists for small to medium sizes because CPU cache prefetching favors contiguous memory.

---

## 3. Stacks

## Q9. What is a stack and what are its operations?

**Answer:**

A stack is a LIFO (last-in, first-out) collection. All operations are O(1).

```javascript
class Stack {
  constructor() { this.items = []; }
  push(x)   { this.items.push(x); }                    // O(1)
  pop()     { return this.items.pop(); }                // O(1)
  peek()    { return this.items[this.items.length - 1]; }
  size()    { return this.items.length; }
  isEmpty() { return this.items.length === 0; }
}

const s = new Stack();
s.push(1); s.push(2); s.push(3);
s.pop();   // 3
s.peek();  // 2
```

## Q10. What are stacks used for?

**Answer:**

- The function call stack (every recursive program)
- Expression evaluation, balanced parentheses
- Undo/redo history
- Depth-first search (DFS) traversal
- Browser back-button history
- Monotonic stack patterns (next greater/smaller element)

```javascript
// Balanced parentheses
function isBalanced(s) {
  const stack = [];
  const pairs = { ')': '(', ']': '[', '}': '{' };
  for (const c of s) {
    if ('([{'.includes(c)) stack.push(c);
    else if (stack.pop() !== pairs[c]) return false;
  }
  return stack.length === 0;
}
```

---

## 4. Queues

## Q11. What is a queue?

**Answer:**

A queue is a FIFO (first-in, first-out) collection. Operations: `enqueue` (add to back), `dequeue` (remove from front), `peek`.

## Q12. Why is `Array.shift()` a bad way to implement a queue?

**Answer:**

`shift()` is O(n) because it shifts every element left by one. A linked-list-backed queue gives true O(1) for both enqueue and dequeue.

```javascript
// Slow version — O(n) dequeue
class SlowQueue {
  constructor() { this.items = []; }
  enqueue(x) { this.items.push(x); }              // O(1)
  dequeue()  { return this.items.shift(); }        // O(n)
}

// Proper version — O(1) for both ops
class Queue {
  constructor() { this.head = null; this.tail = null; this.size = 0; }
  enqueue(val) {
    const node = { val, next: null };
    if (this.tail) this.tail.next = node;
    else this.head = node;
    this.tail = node;
    this.size++;
  }
  dequeue() {
    if (!this.head) return undefined;
    const val = this.head.val;
    this.head = this.head.next;
    if (!this.head) this.tail = null;
    this.size--;
    return val;
  }
  peek() { return this.head?.val; }
}
```

## Q13. What are queue variants?

**Answer:**

- **Deque** — double-ended queue, O(1) push/pop at both ends. Use a doubly linked list or circular buffer.
- **Circular queue** — fixed-size array with head/tail indices, ideal for ring buffers.
- **Priority queue** — implemented with a heap.

## Q14. Where are queues used?

**Answer:**

- BFS traversal
- Task scheduling, message queues
- Producer–consumer patterns
- Print spoolers
- Async event loops (microtask, macrotask queues)

---

## 5. Hash Maps and Hash Sets

## Q15. How does a hash map work?

**Answer:**

A hash map stores key→value pairs with average O(1) operations.

1. `hash(key)` → integer
2. `index = hash mod capacity`
3. The bucket at that index holds entries; on collision, use **chaining** (linked list or tree per bucket) or **open addressing** (probe to next slot).
4. **Resize** (rehash everything) when load factor (size / capacity) exceeds a threshold (e.g., 0.75).

## Q16. Implement a basic hash map with chaining.

**Answer:**

```javascript
class HashMap {
  constructor(capacity = 16) {
    this.capacity = capacity;
    this.size = 0;
    this.buckets = new Array(capacity).fill(null).map(() => []);
  }

  _hash(key) {
    let h = 0;
    const s = String(key);
    for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
    return Math.abs(h) % this.capacity;
  }

  set(key, val) {
    const idx = this._hash(key);
    const bucket = this.buckets[idx];
    for (const entry of bucket) {
      if (entry[0] === key) { entry[1] = val; return; }
    }
    bucket.push([key, val]);
    this.size++;
    if (this.size / this.capacity > 0.75) this._resize();
  }

  get(key) {
    const bucket = this.buckets[this._hash(key)];
    for (const [k, v] of bucket) if (k === key) return v;
    return undefined;
  }

  delete(key) {
    const bucket = this.buckets[this._hash(key)];
    for (let i = 0; i < bucket.length; i++) {
      if (bucket[i][0] === key) {
        bucket.splice(i, 1);
        this.size--;
        return true;
      }
    }
    return false;
  }

  _resize() {
    const old = this.buckets;
    this.capacity *= 2;
    this.size = 0;
    this.buckets = new Array(this.capacity).fill(null).map(() => []);
    for (const bucket of old) for (const [k, v] of bucket) this.set(k, v);
  }
}
```

## Q17. What is the worst case for a hash map?

**Answer:**

| Operation | Average | Worst |
|-----------|---------|-------|
| Insert | O(1) | O(n) |
| Lookup | O(1) | O(n) |
| Delete | O(1) | O(n) |

Worst case happens when all keys collide into one bucket — usually due to a bad hash function or adversarial input (HashDoS). Java's `HashMap` switches a bucket to a balanced tree once it exceeds 8 entries, giving O(log n) worst case.

## Q18. What are hash maps used for?

**Answer:**

- Caches and deduplication
- Frequency counting
- Object property storage in dynamic languages
- Indexed lookup by id
- Constant-time membership tests (Set)

```javascript
// Frequency counter
function countWords(text) {
  const map = new Map();
  for (const w of text.split(/\s+/)) {
    map.set(w, (map.get(w) || 0) + 1);
  }
  return map;
}
```

---

## 6. Trees

## Q19. What is a binary tree?

**Answer:**

A tree is a hierarchical structure of nodes, each with a single parent (except the root). A **binary tree** has at most two children per node, called `left` and `right`.

```javascript
class TreeNode {
  constructor(val, left = null, right = null) {
    this.val = val; this.left = left; this.right = right;
  }
}
```

## Q20. What is a Binary Search Tree (BST)?

**Answer:**

A BST is a binary tree with the invariant: for every node, all left descendants ≤ node ≤ all right descendants. This enables average O(log n) insert, search, and delete.

```javascript
class BST {
  constructor() { this.root = null; }

  insert(val) {
    const node = new TreeNode(val);
    if (!this.root) { this.root = node; return; }
    let curr = this.root;
    while (true) {
      if (val < curr.val) {
        if (!curr.left) { curr.left = node; return; }
        curr = curr.left;
      } else {
        if (!curr.right) { curr.right = node; return; }
        curr = curr.right;
      }
    }
  }

  search(val) {
    let curr = this.root;
    while (curr) {
      if (val === curr.val) return curr;
      curr = val < curr.val ? curr.left : curr.right;
    }
    return null;
  }
}
```

**Average:** O(log n). **Worst:** O(n) when the tree degenerates to a linked list (sorted insertion).

## Q21. What are self-balancing BSTs?

**Answer:**

| Tree | Balance rule | Use case |
|------|--------------|----------|
| **AVL** | height(L) − height(R) ∈ {−1, 0, 1} | Lookup-heavy workloads |
| **Red-Black** | Each path has the same number of black nodes | General-purpose; Java TreeMap, C++ map, Linux kernel |
| **Splay** | Most-recently-accessed node moves to root | Caching, locality |
| **Treap** | BST on key, heap on random priority | Simple, expected O(log n) |

All offer O(log n) for insert, delete, and lookup.

## Q22. What is a B-Tree / B+Tree and why do databases use them?

**Answer:**

B-Trees are wide trees where each node holds many keys (matching disk-block size, typically 4–16 KB). Wide nodes mean shallow trees, so range queries need few disk seeks.

- **B-tree**: keys and values in every node.
- **B+tree**: values only in leaves; leaves form a linked list, so range scans are sequential.

Used by Postgres, MySQL InnoDB, and filesystems (NTFS, ext4). Operations are O(log_b n) where b is the branching factor (often hundreds).

## Q23. What are the four tree traversals?

**Answer:**

| Traversal | Order | Use |
|-----------|-------|-----|
| Preorder (root → L → R) | root first | Copy / serialize |
| Inorder (L → root → R) | sorted (in BST) | Sorted output of BST |
| Postorder (L → R → root) | children first | Delete tree, evaluate expression tree |
| Level-order (BFS) | level by level | Shortest path in unweighted tree |

```javascript
function inorder(node, out = []) {
  if (!node) return out;
  inorder(node.left, out);
  out.push(node.val);
  inorder(node.right, out);
  return out;
}
```

---

## 7. Heaps and Priority Queues

## Q24. What is a heap?

**Answer:**

A heap is a complete binary tree (filled left-to-right) satisfying the heap property:

- **Min-heap:** parent ≤ children (root is minimum)
- **Max-heap:** parent ≥ children (root is maximum)

Stored as an array — for index `i`:
- left child  → `2i + 1`
- right child → `2i + 2`
- parent     → `(i − 1) / 2` (floor)

## Q25. Implement a min-heap.

**Answer:**

```javascript
class MinHeap {
  constructor() { this.h = []; }

  push(x) {
    this.h.push(x);
    this._bubbleUp(this.h.length - 1);
  }

  pop() {
    if (!this.h.length) return undefined;
    const top = this.h[0];
    const last = this.h.pop();
    if (this.h.length) { this.h[0] = last; this._sinkDown(0); }
    return top;
  }

  peek() { return this.h[0]; }
  size() { return this.h.length; }

  _bubbleUp(i) {
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (this.h[p] <= this.h[i]) break;
      [this.h[p], this.h[i]] = [this.h[i], this.h[p]];
      i = p;
    }
  }

  _sinkDown(i) {
    const n = this.h.length;
    while (true) {
      const l = 2 * i + 1, r = 2 * i + 2;
      let smallest = i;
      if (l < n && this.h[l] < this.h[smallest]) smallest = l;
      if (r < n && this.h[r] < this.h[smallest]) smallest = r;
      if (smallest === i) break;
      [this.h[i], this.h[smallest]] = [this.h[smallest], this.h[i]];
      i = smallest;
    }
  }
}
```

## Q26. What is the time complexity of heap operations?

**Answer:**

| Operation | Time |
|-----------|------|
| Insert (push) | O(log n) |
| Extract min/max | O(log n) |
| Peek | O(1) |
| Build heap from array | O(n) (heapify bottom-up) |
| Search arbitrary value | O(n) |

## Q27. What are heaps used for?

**Answer:**

- Priority queues (Dijkstra, A* pathfinding)
- Heap sort
- Top-K problems (use a min-heap of size K)
- Median maintenance (two heaps — max-heap for lower half, min-heap for upper half)
- Job schedulers, OS task priority

```javascript
// Top-K largest using a min-heap of size K
function topK(nums, k) {
  const heap = new MinHeap();
  for (const n of nums) {
    heap.push(n);
    if (heap.size() > k) heap.pop();
  }
  return heap.h; // K largest values
}
```

---

## 8. Tries

## Q28. What is a trie?

**Answer:**

A trie ("retrieval tree") stores strings node by character, sharing common prefixes. Used wherever prefix lookup matters: autocomplete, spell-check, IP routing.

```javascript
class Trie {
  constructor() { this.root = {}; }

  insert(word) {
    let node = this.root;
    for (const c of word) {
      if (!node[c]) node[c] = {};
      node = node[c];
    }
    node.$ = true;                              // end-of-word marker
  }

  search(word) {
    let node = this.root;
    for (const c of word) {
      if (!node[c]) return false;
      node = node[c];
    }
    return node.$ === true;
  }

  startsWith(prefix) {
    let node = this.root;
    for (const c of prefix) {
      if (!node[c]) return false;
      node = node[c];
    }
    return true;
  }
}
```

## Q29. What is the complexity of trie operations?

**Answer:**

For a key of length k:
- Insert: O(k)
- Search: O(k)
- Prefix lookup: O(k)
- Space: O(total chars). Improved with radix/Patricia trie that compresses single-child chains.

## Q30. What are tries used for?

**Answer:**

- Autocomplete / typeahead
- Spell checkers
- IP routing tables (longest prefix match)
- Word games (Boggle, Scrabble)
- T9 / predictive text

---

## 9. Graphs

## Q31. What is a graph and how do you represent one?

**Answer:**

A graph is a set of vertices V and edges E. Edges may be directed or undirected, weighted or unweighted. Three common representations:

```javascript
// Adjacency List — most common for sparse graphs
class Graph {
  constructor() { this.adj = new Map(); }

  addNode(v) { if (!this.adj.has(v)) this.adj.set(v, []); }

  addEdge(u, v, weight = 1) {
    this.addNode(u); this.addNode(v);
    this.adj.get(u).push({ node: v, weight });
    this.adj.get(v).push({ node: u, weight }); // omit for directed
  }

  neighbors(v) { return this.adj.get(v) || []; }
}
```

```javascript
// Adjacency Matrix — best for dense graphs
function makeMatrix(n) {
  return Array.from({ length: n }, () => new Array(n).fill(0));
}
// matrix[u][v] = weight (or 1) if edge u→v exists, else 0
```

## Q32. Compare graph representations.

**Answer:**

| Representation | Space | Edge exists? | Iterate neighbors | Best for |
|----------------|-------|--------------|--------------------|----------|
| Adjacency list | O(V + E) | O(deg(v)) | O(deg(v)) | Sparse graphs (most real-world) |
| Adjacency matrix | O(V²) | O(1) | O(V) | Dense graphs, Floyd–Warshall |
| Edge list | O(E) | O(E) | O(E) | Kruskal, simple input |

## Q33. Implement BFS and DFS.

**Answer:**

```javascript
// BFS — shortest path in unweighted graphs
function bfs(g, start) {
  const visited = new Set([start]);
  const queue = [start];
  const order = [];
  while (queue.length) {
    const v = queue.shift();
    order.push(v);
    for (const { node } of g.neighbors(v)) {
      if (!visited.has(node)) {
        visited.add(node);
        queue.push(node);
      }
    }
  }
  return order;
}

// DFS — recursive
function dfs(g, start, visited = new Set(), order = []) {
  visited.add(start);
  order.push(start);
  for (const { node } of g.neighbors(start)) {
    if (!visited.has(node)) dfs(g, node, visited, order);
  }
  return order;
}
```

Both run in O(V + E) time.

## Q34. What are common graph algorithms?

**Answer:**

| Algorithm | Use | Time |
|-----------|-----|------|
| BFS | Shortest path (unweighted) | O(V + E) |
| DFS | Connectivity, cycle detection, topo sort | O(V + E) |
| Dijkstra | Shortest path, non-negative weights | O((V + E) log V) |
| Bellman–Ford | Shortest path, allows negatives | O(V·E) |
| Floyd–Warshall | All-pairs shortest paths | O(V³) |
| Kruskal | Minimum spanning tree | O(E log E) |
| Prim | Minimum spanning tree | O((V + E) log V) |
| Topological sort | DAG ordering | O(V + E) |
| Tarjan / Kosaraju | Strongly connected components | O(V + E) |
| Union–Find | Disjoint sets / Kruskal helper | ≈ O(α(n)) per op |

## Q35. Implement Dijkstra's shortest path.

**Answer:**

```javascript
function dijkstra(graph, start) {
  const dist = new Map();
  for (const v of graph.adj.keys()) dist.set(v, Infinity);
  dist.set(start, 0);

  const heap = new MinHeap(); // store [distance, node]
  heap.push([0, start]);

  while (heap.size()) {
    const [d, u] = heap.pop();
    if (d > dist.get(u)) continue;
    for (const { node: v, weight } of graph.neighbors(u)) {
      const nd = d + weight;
      if (nd < dist.get(v)) {
        dist.set(v, nd);
        heap.push([nd, v]);
      }
    }
  }
  return dist;
}
```

(Uses a min-heap that compares by first element of the array.)

---

## 10. Choosing the Right Structure

## Q36. Which data structure should I pick?

**Answer:**

| Need | Structure |
|------|-----------|
| Random access by index | Array |
| Frequent insert/delete in middle | Linked list |
| LIFO operations | Stack |
| FIFO operations | Queue |
| Fast lookup/membership | Hash map / Set |
| Ordered iteration | BST / sorted array |
| Min/max repeatedly | Heap |
| Prefix queries on strings | Trie |
| Relationships between entities | Graph |
| Range queries on disk-resident data | B+tree |
| Top-K elements | Min-heap (size K) |
| LRU cache | Doubly linked list + hash map |

## Q37. Quick complexity reference for all structures.

**Answer:**

| Structure | Access | Search | Insert | Delete |
|-----------|--------|--------|--------|--------|
| Array | O(1) | O(n) | O(n) | O(n) |
| Sorted array | O(1) | O(log n) | O(n) | O(n) |
| Linked list | O(n) | O(n) | O(1) at known pos | O(1) at known pos |
| Stack | O(n) | O(n) | O(1) push | O(1) pop |
| Queue | O(n) | O(n) | O(1) enqueue | O(1) dequeue |
| Hash map | — | O(1) avg | O(1) avg | O(1) avg |
| Balanced BST | O(log n) | O(log n) | O(log n) | O(log n) |
| Heap | O(1) min/max | O(n) | O(log n) | O(log n) |
| Trie | — | O(k) | O(k) | O(k) |
| B+tree | O(log_b n) | O(log_b n) | O(log_b n) | O(log_b n) |

## Q38. Implement an LRU cache.

**Answer:**

LRU = Least Recently Used. Use a hash map for O(1) lookup plus a doubly linked list for O(1) reordering.

```javascript
class LRUCache {
  constructor(capacity) {
    this.capacity = capacity;
    this.map = new Map(); // JS Map preserves insertion order
  }

  get(key) {
    if (!this.map.has(key)) return -1;
    const val = this.map.get(key);
    this.map.delete(key);
    this.map.set(key, val); // move to most-recent end
    return val;
  }

  put(key, val) {
    if (this.map.has(key)) this.map.delete(key);
    else if (this.map.size >= this.capacity) {
      const oldest = this.map.keys().next().value;
      this.map.delete(oldest);
    }
    this.map.set(key, val);
  }
}
```

## Q39. Implement Union-Find (Disjoint Set).

**Answer:**

Used for connected components, Kruskal's MST, and dynamic connectivity. With path compression and union by rank, each operation is nearly O(1) amortised.

```javascript
class UnionFind {
  constructor(n) {
    this.parent = Array.from({ length: n }, (_, i) => i);
    this.rank = new Array(n).fill(0);
  }

  find(x) {
    if (this.parent[x] !== x) {
      this.parent[x] = this.find(this.parent[x]); // path compression
    }
    return this.parent[x];
  }

  union(a, b) {
    const ra = this.find(a), rb = this.find(b);
    if (ra === rb) return false;
    if (this.rank[ra] < this.rank[rb]) this.parent[ra] = rb;
    else if (this.rank[ra] > this.rank[rb]) this.parent[rb] = ra;
    else { this.parent[rb] = ra; this.rank[ra]++; }
    return true;
  }
}
```

## Q40. What are practical considerations for choosing a data structure?

**Answer:**

- **Cache locality matters**: arrays beat linked lists in practice for small sizes despite identical Big-O. Modern CPUs prefetch contiguous memory.
- **Hash maps vs trees**: hash maps win on average lookup; trees win when you need ordered iteration, range queries, or predictable worst-case latency.
- **B+trees over BSTs for databases**: disk seeks dominate; wide nodes minimize tree height.
- **Persistent / immutable structures** (Clojure, Immutable.js) trade O(1) for O(log n) but enable structural sharing — useful in functional code and React state.
- **Concurrency**: lock-free queues, concurrent hash maps (Java's `ConcurrentHashMap`), and skip lists (Redis sorted sets, LevelDB) are worth knowing.
