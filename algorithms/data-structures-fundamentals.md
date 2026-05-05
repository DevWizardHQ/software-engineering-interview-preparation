# Data Structures Fundamentals

**Purpose:** Senior-level reference for the data structures every full-stack engineer must know cold. Each section covers internals, operation complexities, when to use it, and a working JavaScript implementation.

---

## Table of Contents

1. [Arrays](#arrays)
2. [Linked Lists](#linked-lists)
3. [Stacks](#stacks)
4. [Queues](#queues)
5. [Hash Maps and Hash Sets](#hash-maps-and-hash-sets)
6. [Trees](#trees)
7. [Heaps and Priority Queues](#heaps-and-priority-queues)
8. [Tries](#tries)
9. [Graphs](#graphs)
10. [Choosing the Right Structure](#choosing-the-right-structure)

---

## Arrays

### How they work

A contiguous block of memory holding fixed-size elements. Indexing is O(1) because address = base + index × element_size.

**Static arrays** (C, Java's `int[]`) have a fixed size at allocation. **Dynamic arrays** (JS `Array`, Python `list`, Java `ArrayList`, Go `slice`) automatically resize — typically doubling capacity when full.

### Complexity

| Operation | Time | Notes |
|-----------|------|-------|
| Index access | O(1) | Random access by position |
| Search (unsorted) | O(n) | Linear scan |
| Search (sorted) | O(log n) | Binary search |
| Append (end) | O(1) amortised | Occasional resize is O(n) |
| Insert (middle) | O(n) | Shifts all later elements |
| Insert (front) | O(n) | Shifts everything |
| Delete (middle) | O(n) | Same shift problem |
| Pop (end) | O(1) | |

**Why amortised O(1) on append:** doubling means n appends cost n + n/2 + n/4 + ... ≤ 2n total work, averaged out to O(1) each.

### When to use

- Random access by index
- Cache-friendly iteration (contiguous memory)
- Stack operations (push/pop end)
- Default choice unless you need fast middle-insert

### Avoid when

- Frequent inserts/deletes in the middle → use linked list
- Unknown growth pattern with very large size → rope / skip list / chunked

---

## Linked Lists

A linked list is a sequence of nodes; each node holds a value and a pointer to the next (and optionally previous) node.

### Singly Linked List

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

  *[Symbol.iterator]() {
    for (let n = this.head; n; n = n.next) yield n.val;
  }
}
```

### Doubly Linked List

Each node has `prev` and `next` pointers. Used by LRU caches, the DOM, and most language `Deque` implementations.

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

### Circular Linked List

Tail's `next` points back to head (singly), or to head and head's `prev` to tail (doubly). Useful for round-robin scheduling and ring buffers.

### Complexity Summary

| Operation | Singly | Doubly |
|-----------|--------|--------|
| Access by index | O(n) | O(n) |
| Insert at head | O(1) | O(1) |
| Insert at tail | O(n) without tail pointer; O(1) with | O(1) |
| Delete at head | O(1) | O(1) |
| Delete at tail | O(n) | O(1) |
| Delete given node | O(n) | O(1) |
| Search by value | O(n) | O(n) |

### When to use

- Frequent inserts/deletes at known positions
- LRU cache (doubly + hash map)
- Implementing queues, stacks, deques
- Building blocks for adjacency lists, hash chains

### Avoid when

- Index access is needed → array
- Memory overhead matters: each node has pointer overhead
- Cache locality matters: nodes scatter across heap → cache-unfriendly

---

## Stacks

LIFO (last in, first out). Operations: push, pop, peek, isEmpty.

### Implementation (array-backed)

```javascript
class Stack {
  constructor() { this.items = []; }
  push(x)   { this.items.push(x); }           // O(1)
  pop()     { return this.items.pop(); }       // O(1)
  peek()    { return this.items[this.items.length - 1]; }
  size()    { return this.items.length; }
  isEmpty() { return this.items.length === 0; }
}
```

### Complexity

All operations O(1).

### Use cases

- Function call stack (every recursive program)
- Expression evaluation, balanced parentheses
- Undo/redo
- DFS traversal
- Browser back-button
- Monotonic stack patterns (next greater/smaller element)

---

## Queues

FIFO (first in, first out). Operations: enqueue, dequeue, peek.

### Naive array implementation (slow)

```javascript
class SlowQueue {
  constructor() { this.items = []; }
  enqueue(x) { this.items.push(x); }            // O(1)
  dequeue() { return this.items.shift(); }      // O(n) — shifts everything
}
```

### Linked-list backed (proper O(1))

```javascript
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

### Variants

- **Deque** — double-ended queue (push/pop both ends in O(1)). Use a doubly linked list or circular buffer.
- **Circular queue** — fixed-size array with head/tail indices, ideal for ring buffers.
- **Priority queue** — see [Heaps](#heaps-and-priority-queues).

### Use cases

- BFS traversal
- Task scheduling, message queues
- Producer–consumer patterns
- Print spoolers
- Asynchronous event loops (microtask queue, macrotask queue)

---

## Hash Maps and Hash Sets

A hash map stores key→value pairs with average O(1) operations by hashing the key into bucket indices.

### How it works

1. `hash(key)` → integer
2. `index = hash mod capacity`
3. Bucket holds entries; on collision, use **chaining** (linked list or tree per bucket) or **open addressing** (probe to next slot).
4. **Resize** (rehash everything) when load factor (size / capacity) exceeds a threshold (e.g. 0.75).

### Complexity

| Operation | Average | Worst |
|-----------|---------|-------|
| Insert | O(1) | O(n) (all keys collide) |
| Lookup | O(1) | O(n) |
| Delete | O(1) | O(n) |

Worst case: bad hash function or adversarial input. Java's `HashMap` switches to a balanced tree per bucket once chains exceed 8 entries → worst case O(log n).

### Custom implementation (chaining)

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

### Use cases

- Caching, deduplication, frequency counters
- Object property storage in dynamic languages
- Indexed lookup by id
- Constant-time membership tests (Set)

### Hash collisions and mitigation

- Use a high-quality hash (FNV, MurmurHash, SipHash for security)
- Resize when load factor crosses threshold
- Use **open addressing** for cache-friendly lookups (Robin Hood hashing in Rust's `HashMap`, Swiss tables in Abseil)

---

## Trees

A tree is a hierarchical structure: nodes with a single parent (except root) and zero or more children.

### Binary Tree

Each node has at most two children: `left`, `right`.

```javascript
class TreeNode {
  constructor(val, left = null, right = null) {
    this.val = val; this.left = left; this.right = right;
  }
}
```

### Binary Search Tree (BST)

Invariant: for every node, all left descendants ≤ node ≤ all right descendants.

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

### Self-Balancing BSTs

| Tree | Balance rule | Use case |
|------|--------------|----------|
| **AVL** | height(L) − height(R) ∈ {−1, 0, 1} | Lookup-heavy workloads, tighter balance |
| **Red-Black** | Each path has the same number of black nodes | General-purpose; Java TreeMap, C++ map, Linux kernel scheduler |
| **Splay** | Most-recently-accessed node moves to root | Caching, locality benefits |
| **Treap** | BST on key, heap on random priority | Simple to implement, expected O(log n) |

All offer O(log n) insert/delete/lookup.

### B-Tree / B+Tree

Used by databases (Postgres, MySQL InnoDB) and filesystems (NTFS, HFS+, ext4). Each node holds many keys (matching disk-block size, typically 4–16 KB). Reduces tree height → fewer disk reads.

- **B-tree**: keys and values in every node.
- **B+tree**: values in leaves only; leaves form a linked list → range scans are sequential.

Operations: O(log_b n) where b is the branching factor (often hundreds).

### Tree Traversals

| Traversal | Order | Use |
|-----------|-------|-----|
| Preorder (root → L → R) | root first | Copy / serialise tree |
| Inorder (L → root → R) | sorted (in BST) | Sorted output of BST |
| Postorder (L → R → root) | children first | Delete tree, evaluate expression tree |
| Level-order (BFS) | level by level | Shortest path in unweighted tree |

### When to use trees

- Sorted data with frequent inserts → balanced BST
- Range queries → B+tree
- Hierarchical data (filesystems, DOM, org charts)
- Prefix lookup → trie
- Priority extraction → heap

---

## Heaps and Priority Queues

A heap is a complete binary tree (filled left-to-right) satisfying the heap property:

- **Min-heap:** parent ≤ children (root is minimum)
- **Max-heap:** parent ≥ children (root is maximum)

Stored as an array — for index `i`:
- left child  → `2i + 1`
- right child → `2i + 2`
- parent     → `(i − 1) / 2` (floor)

### Min-heap implementation

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

### Complexity

| Operation | Time |
|-----------|------|
| Insert (push) | O(log n) |
| Extract min/max | O(log n) |
| Peek | O(1) |
| Build heap from array | O(n) (heapify bottom-up) |
| Search arbitrary value | O(n) |

### Use cases

- Priority queues (Dijkstra, A* pathfinding)
- Heap sort
- Top-K problems (use min-heap of size K)
- Median maintenance (two heaps)
- Job schedulers, OS task priority

---

## Tries

A trie ("retrieval tree") stores strings node by character, with shared prefixes collapsed.

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

### Complexity

For a key of length k:
- Insert: O(k)
- Search: O(k)
- Prefix lookup: O(k)
- Space: O(total chars) — improved with radix/Patricia trie

### Use cases

- Autocomplete / typeahead
- Spell checkers
- IP routing tables (longest prefix match)
- Word games (Boggle, Scrabble)
- T9 / predictive text

---

## Graphs

A graph is a set of vertices V and edges E. Edges may be directed or undirected, weighted or unweighted.

### Representations

#### Adjacency List

```javascript
class Graph {
  constructor() { this.adj = new Map(); }

  addNode(v) { if (!this.adj.has(v)) this.adj.set(v, []); }

  addEdge(u, v, weight = 1) {
    this.addNode(u); this.addNode(v);
    this.adj.get(u).push({ node: v, weight });
    this.adj.get(v).push({ node: u, weight });   // omit for directed
  }

  neighbors(v) { return this.adj.get(v) || []; }
}
```

**Space:** O(V + E). Best for sparse graphs.

#### Adjacency Matrix

```javascript
function makeMatrix(n) {
  return Array.from({ length: n }, () => new Array(n).fill(0));
}
// matrix[u][v] = weight (or 1) if edge u→v exists, else 0
```

**Space:** O(V²). Best for dense graphs or when constant-time edge lookup matters.

#### Edge List

`[[u1, v1, w1], [u2, v2, w2], ...]` — useful as input format and for Kruskal's MST.

### Comparison

| Representation | Space | Edge exists? | Iterate neighbours | Best for |
|----------------|-------|--------------|--------------------|----------|
| Adjacency list | O(V + E) | O(deg(v)) | O(deg(v)) | Sparse graphs (most real-world) |
| Adjacency matrix | O(V²) | O(1) | O(V) | Dense graphs, Floyd–Warshall |
| Edge list | O(E) | O(E) | O(E) | Kruskal, simple input |

### Traversals

```javascript
// BFS — shortest path in unweighted graph
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

### Common Graph Algorithms

| Algorithm | Use | Time |
|-----------|-----|------|
| BFS | Shortest path (unweighted) | O(V + E) |
| DFS | Connectivity, cycle detection, topological sort | O(V + E) |
| Dijkstra | Shortest path, non-negative weights | O((V + E) log V) with binary heap |
| Bellman–Ford | Shortest path, negative weights allowed | O(V·E) |
| Floyd–Warshall | All-pairs shortest paths | O(V³) |
| Kruskal | Minimum spanning tree | O(E log E) |
| Prim | Minimum spanning tree | O((V + E) log V) |
| Topological sort | DAG ordering | O(V + E) |
| Tarjan / Kosaraju | Strongly connected components | O(V + E) |
| Union–Find | Disjoint sets / Kruskal helper | nearly O(α(n)) per op |

---

## Choosing the Right Structure

### Decision matrix

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

### Quick complexity reference

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

---

## Senior-Level Talking Points

- **Cache locality matters**: arrays beat linked lists in practice for small sizes despite identical Big-O. Modern CPUs prefetch contiguous memory.
- **Hash map worst case is rarely Big-O**: in production, a poor hash + adversarial input can cause O(n) lookups (HashDoS attacks). Use SipHash or randomised seeds.
- **Trees vs hash maps**: hash maps win on average lookup; trees win when you need ordered iteration, range queries, or predictable worst-case latency.
- **B+trees over BSTs for databases**: disk seeks dominate; wide nodes minimise tree height. RAM is fast → fan-out matters more than rebalancing cost.
- **Persistent / immutable structures** (Clojure, Immutable.js) trade O(1) for O(log n) but enable structural sharing — important in functional codebases and React state.
- **Concurrency**: lock-free queues (Michael–Scott), concurrent hash maps (Java's `ConcurrentHashMap`), and skip lists (Redis sorted sets, LevelDB) deserve familiarity.
