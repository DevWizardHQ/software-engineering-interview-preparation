# Coding Algorithm Questions — Senior Interview Prep

**Purpose:** The 40+ algorithm problems most often asked in coding interviews. Each problem includes JavaScript and Python solutions where helpful, complexity analysis, and explanation of trade-offs.

---

## Table of Contents

1. [Arrays and Hashing](#arrays-and-hashing)
2. [Two Pointers](#two-pointers)
3. [Sliding Window](#sliding-window)
4. [Strings](#strings)
5. [Searching and Sorting](#searching-and-sorting)
6. [Linked Lists](#linked-lists)
7. [Stacks and Queues](#stacks-and-queues)
8. [Trees](#trees)
9. [Recursion and Backtracking](#recursion-and-backtracking)
10. [Dynamic Programming](#dynamic-programming)
11. [Big-O Complexity Reference](#big-o-complexity-reference)

---

## Arrays and Hashing

### Q1. Two Sum.

**Problem:** Given an array of integers and a target, return indices of the two numbers that add to the target.

**JavaScript:**
```javascript
function twoSum(nums, target) {
  const seen = new Map();
  for (let i = 0; i < nums.length; i++) {
    const complement = target - nums[i];
    if (seen.has(complement)) return [seen.get(complement), i];
    seen.set(nums[i], i);
  }
  return [];
}
```

**Python:**
```python
def two_sum(nums, target):
    seen = {}
    for i, n in enumerate(nums):
        if target - n in seen:
            return [seen[target - n], i]
        seen[n] = i
```

| Approach | Time | Space |
|----------|------|-------|
| Brute force (nested loop) | O(n²) | O(1) |
| Hash map (single pass) | O(n) | O(n) |

---

### Q2. Three Sum.

**Problem:** Find all unique triplets that sum to zero.

```javascript
function threeSum(nums) {
  nums.sort((a, b) => a - b);
  const res = [];
  for (let i = 0; i < nums.length - 2; i++) {
    if (i > 0 && nums[i] === nums[i - 1]) continue;
    let l = i + 1, r = nums.length - 1;
    while (l < r) {
      const sum = nums[i] + nums[l] + nums[r];
      if (sum === 0) {
        res.push([nums[i], nums[l], nums[r]]);
        while (l < r && nums[l] === nums[l + 1]) l++;
        while (l < r && nums[r] === nums[r - 1]) r--;
        l++; r--;
      } else if (sum < 0) l++;
      else r--;
    }
  }
  return res;
}
```

**Time:** O(n²). **Space:** O(1) excluding output.

---

### Q3. Find duplicates in an array.

**Return whether any duplicate exists:**
```javascript
function hasDuplicate(nums) {
  return new Set(nums).size !== nums.length;
}
```

**Find all duplicates (values appearing twice):**
```javascript
function findDuplicates(nums) {
  const seen = new Set(), dups = new Set();
  for (const n of nums) seen.has(n) ? dups.add(n) : seen.add(n);
  return [...dups];
}
```

**O(1) space (when array values are 1..n):**
```javascript
function findDuplicates(nums) {
  const res = [];
  for (const n of nums) {
    const idx = Math.abs(n) - 1;
    if (nums[idx] < 0) res.push(Math.abs(n));
    else nums[idx] = -nums[idx];
  }
  return res;
}
```

Mark-as-negative trick: each value flips the sign at its target index. Second visit finds it already negative.

---

### Q4. Find the missing number from 1..N.

**Sum formula (cleanest):**
```javascript
function missingNumber(nums) {
  const n = nums.length;
  return (n * (n + 1)) / 2 - nums.reduce((a, b) => a + b, 0);
}
```

**XOR (avoids overflow):**
```javascript
function missingNumber(nums) {
  let x = nums.length;
  for (let i = 0; i < nums.length; i++) x ^= i ^ nums[i];
  return x;
}
```

**Time:** O(n). **Space:** O(1).

---

### Q5. Maximum subarray sum (Kadane's algorithm).

```javascript
function maxSubArray(nums) {
  let best = nums[0], cur = nums[0];
  for (let i = 1; i < nums.length; i++) {
    cur = Math.max(nums[i], cur + nums[i]);
    best = Math.max(best, cur);
  }
  return best;
}
```

**Insight:** at each index decide — extend the previous subarray, or start fresh. **O(n) time, O(1) space.**

---

### Q6. Group anagrams.

```javascript
function groupAnagrams(strs) {
  const groups = new Map();
  for (const s of strs) {
    const key = [...s].sort().join('');
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(s);
  }
  return [...groups.values()];
}
```

**Time:** O(n · k log k) where k is max string length. **Space:** O(nk).

Faster key: count of 26 letters (no sort) → O(n · k).

---

### Q7. Top K frequent elements.

```javascript
function topKFrequent(nums, k) {
  const freq = new Map();
  for (const n of nums) freq.set(n, (freq.get(n) || 0) + 1);

  // Bucket sort: index = frequency
  const buckets = Array.from({ length: nums.length + 1 }, () => []);
  for (const [n, f] of freq) buckets[f].push(n);

  const res = [];
  for (let i = buckets.length - 1; i >= 0 && res.length < k; i--) {
    res.push(...buckets[i]);
  }
  return res.slice(0, k);
}
```

**Time:** O(n) with bucket sort, O(n log k) with min-heap. **Space:** O(n).

---

## Two Pointers

### Q8. Reverse a string in place.

```javascript
function reverseString(s) {
  let l = 0, r = s.length - 1;
  while (l < r) {
    [s[l], s[r]] = [s[r], s[l]];
    l++; r--;
  }
  return s;
}
```

**Time:** O(n). **Space:** O(1).

---

### Q9. Palindrome check (alphanumeric only).

```javascript
function isPalindrome(s) {
  s = s.toLowerCase();
  let l = 0, r = s.length - 1;
  const isAlnum = c => /[a-z0-9]/.test(c);
  while (l < r) {
    while (l < r && !isAlnum(s[l])) l++;
    while (l < r && !isAlnum(s[r])) r--;
    if (s[l] !== s[r]) return false;
    l++; r--;
  }
  return true;
}
```

---

### Q10. Container with most water.

```javascript
function maxArea(height) {
  let l = 0, r = height.length - 1, best = 0;
  while (l < r) {
    const h = Math.min(height[l], height[r]);
    best = Math.max(best, h * (r - l));
    height[l] < height[r] ? l++ : r--;
  }
  return best;
}
```

Greedy: always move the shorter side; only it can possibly improve the area. **O(n)**.

---

### Q11. Merge two sorted arrays.

```javascript
function merge(a, b) {
  const out = [];
  let i = 0, j = 0;
  while (i < a.length && j < b.length) {
    out.push(a[i] <= b[j] ? a[i++] : b[j++]);
  }
  while (i < a.length) out.push(a[i++]);
  while (j < b.length) out.push(b[j++]);
  return out;
}
```

**In-place** (when `a` has trailing space of size `b.length`):
```javascript
function mergeInPlace(a, m, b, n) {
  let i = m - 1, j = n - 1, k = m + n - 1;
  while (j >= 0) {
    a[k--] = (i >= 0 && a[i] > b[j]) ? a[i--] : b[j--];
  }
}
```

---

## Sliding Window

### Q12. Longest substring without repeating characters.

```javascript
function lengthOfLongestSubstring(s) {
  const seen = new Map();
  let l = 0, best = 0;
  for (let r = 0; r < s.length; r++) {
    if (seen.has(s[r]) && seen.get(s[r]) >= l) {
      l = seen.get(s[r]) + 1;
    }
    seen.set(s[r], r);
    best = Math.max(best, r - l + 1);
  }
  return best;
}
```

**Time:** O(n). **Space:** O(min(n, alphabet)).

---

### Q13. Maximum sum subarray of size K.

```javascript
function maxSumK(nums, k) {
  let sum = 0;
  for (let i = 0; i < k; i++) sum += nums[i];
  let best = sum;
  for (let i = k; i < nums.length; i++) {
    sum += nums[i] - nums[i - k];
    best = Math.max(best, sum);
  }
  return best;
}
```

**O(n)** vs the naive O(n·k) recomputation.

---

### Q14. Minimum window substring.

```javascript
function minWindow(s, t) {
  const need = new Map();
  for (const c of t) need.set(c, (need.get(c) || 0) + 1);
  let have = 0, required = need.size;
  const window = new Map();
  let l = 0, bestLen = Infinity, bestL = 0;

  for (let r = 0; r < s.length; r++) {
    const c = s[r];
    window.set(c, (window.get(c) || 0) + 1);
    if (need.has(c) && window.get(c) === need.get(c)) have++;

    while (have === required) {
      if (r - l + 1 < bestLen) { bestLen = r - l + 1; bestL = l; }
      const lc = s[l];
      window.set(lc, window.get(lc) - 1);
      if (need.has(lc) && window.get(lc) < need.get(lc)) have--;
      l++;
    }
  }
  return bestLen === Infinity ? '' : s.substring(bestL, bestL + bestLen);
}
```

**O(|s| + |t|)**.

---

## Strings

### Q15. Check if two strings are anagrams.

```javascript
function isAnagram(a, b) {
  if (a.length !== b.length) return false;
  const counts = new Array(26).fill(0);
  for (let i = 0; i < a.length; i++) {
    counts[a.charCodeAt(i) - 97]++;
    counts[b.charCodeAt(i) - 97]--;
  }
  return counts.every(c => c === 0);
}
```

**O(n)** time, **O(1)** space (fixed 26-letter alphabet).

---

### Q16. Reverse words in a string.

```javascript
const reverseWords = s => s.trim().split(/\s+/).reverse().join(' ');
```

In-place version (O(1) extra space) reverses the entire string then reverses each word.

---

### Q17. Valid palindrome — allow one deletion.

```javascript
function validPalindrome(s) {
  const isPal = (l, r) => {
    while (l < r) if (s[l++] !== s[r--]) return false;
    return true;
  };
  let l = 0, r = s.length - 1;
  while (l < r) {
    if (s[l] !== s[r]) return isPal(l + 1, r) || isPal(l, r - 1);
    l++; r--;
  }
  return true;
}
```

---

## Searching and Sorting

### Q18. Binary search.

```javascript
function binarySearch(nums, target) {
  let l = 0, r = nums.length - 1;
  while (l <= r) {
    const m = (l + r) >>> 1;  // unsigned shift avoids overflow
    if (nums[m] === target) return m;
    if (nums[m] < target) l = m + 1;
    else r = m - 1;
  }
  return -1;
}
```

**O(log n)** time, **O(1)** space.

**Pitfalls:**
- Use `(l + r) >>> 1` or `l + ((r - l) >> 1)` for safe midpoint
- Off-by-one in `l <= r` versus `l < r`

---

### Q19. Search in rotated sorted array.

```javascript
function search(nums, target) {
  let l = 0, r = nums.length - 1;
  while (l <= r) {
    const m = (l + r) >>> 1;
    if (nums[m] === target) return m;
    if (nums[l] <= nums[m]) {                         // left half sorted
      if (nums[l] <= target && target < nums[m]) r = m - 1;
      else l = m + 1;
    } else {                                          // right half sorted
      if (nums[m] < target && target <= nums[r]) l = m + 1;
      else r = m - 1;
    }
  }
  return -1;
}
```

---

### Q20. Quick sort.

```javascript
function quickSort(arr, lo = 0, hi = arr.length - 1) {
  if (lo < hi) {
    const p = partition(arr, lo, hi);
    quickSort(arr, lo, p - 1);
    quickSort(arr, p + 1, hi);
  }
  return arr;
}
function partition(arr, lo, hi) {
  const pivot = arr[hi];
  let i = lo - 1;
  for (let j = lo; j < hi; j++) {
    if (arr[j] <= pivot) [arr[++i], arr[j]] = [arr[j], arr[i]];
  }
  [arr[i + 1], arr[hi]] = [arr[hi], arr[i + 1]];
  return i + 1;
}
```

| Case | Time | Space |
|------|------|-------|
| Best/Average | O(n log n) | O(log n) recursion |
| Worst (already sorted, naive pivot) | O(n²) | O(n) |

Mitigations: random pivot, median-of-three, fall back to heapsort (introsort).

---

### Q21. Merge sort.

```javascript
function mergeSort(arr) {
  if (arr.length <= 1) return arr;
  const mid = arr.length >> 1;
  const left = mergeSort(arr.slice(0, mid));
  const right = mergeSort(arr.slice(mid));
  return merge(left, right);
}
function merge(a, b) {
  const out = [];
  let i = 0, j = 0;
  while (i < a.length && j < b.length) out.push(a[i] <= b[j] ? a[i++] : b[j++]);
  return out.concat(a.slice(i)).concat(b.slice(j));
}
```

**Time:** O(n log n). **Space:** O(n). Stable, predictable — good for linked lists and external sort.

---

### Q22. Bubble sort.

```javascript
function bubbleSort(arr) {
  for (let i = 0; i < arr.length; i++) {
    let swapped = false;
    for (let j = 0; j < arr.length - i - 1; j++) {
      if (arr[j] > arr[j + 1]) {
        [arr[j], arr[j + 1]] = [arr[j + 1], arr[j]];
        swapped = true;
      }
    }
    if (!swapped) break;  // already sorted
  }
  return arr;
}
```

**Time:** O(n²) average and worst, O(n) best (sorted input + early exit). Useful only for teaching.

---

### Q23. Sort comparison table.

| Algorithm | Best | Average | Worst | Space | Stable | Notes |
|-----------|------|---------|-------|-------|--------|-------|
| Bubble | O(n) | O(n²) | O(n²) | O(1) | Yes | Educational only |
| Insertion | O(n) | O(n²) | O(n²) | O(1) | Yes | Fast on small/nearly-sorted |
| Selection | O(n²) | O(n²) | O(n²) | O(1) | No | Fewest swaps |
| Merge | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes | Predictable, parallel-friendly |
| Quick | O(n log n) | O(n log n) | O(n²) | O(log n) | No | Fastest in practice |
| Heap | O(n log n) | O(n log n) | O(n log n) | O(1) | No | In-place worst-case guarantee |
| Counting | O(n + k) | O(n + k) | O(n + k) | O(k) | Yes | Integer keys, small range |
| Radix | O(nk) | O(nk) | O(nk) | O(n + k) | Yes | Fixed-width keys |

JS `Array.prototype.sort` and Python `sorted` use **TimSort** — a hybrid of merge and insertion sort, stable, O(n log n).

---

## Linked Lists

### Q24. Reverse a singly linked list.

```javascript
function reverseList(head) {
  let prev = null, curr = head;
  while (curr) {
    const next = curr.next;
    curr.next = prev;
    prev = curr;
    curr = next;
  }
  return prev;
}
```

**Recursive:**
```javascript
function reverseList(head) {
  if (!head || !head.next) return head;
  const newHead = reverseList(head.next);
  head.next.next = head;
  head.next = null;
  return newHead;
}
```

**Time:** O(n). Iterative space O(1); recursive O(n) call stack.

---

### Q25. Detect a cycle (Floyd's tortoise & hare).

```javascript
function hasCycle(head) {
  let slow = head, fast = head;
  while (fast && fast.next) {
    slow = slow.next;
    fast = fast.next.next;
    if (slow === fast) return true;
  }
  return false;
}
```

**Find cycle start:**
```javascript
function detectCycle(head) {
  let slow = head, fast = head;
  while (fast && fast.next) {
    slow = slow.next;
    fast = fast.next.next;
    if (slow === fast) {
      let p = head;
      while (p !== slow) { p = p.next; slow = slow.next; }
      return p;
    }
  }
  return null;
}
```

**O(n)** time, **O(1)** space.

---

### Q26. Find middle of a linked list.

```javascript
function middleNode(head) {
  let slow = head, fast = head;
  while (fast && fast.next) {
    slow = slow.next;
    fast = fast.next.next;
  }
  return slow;
}
```

For even length, returns the second middle node. Adjust with `fast.next.next` checks if the first is needed.

---

### Q27. Merge two sorted linked lists.

```javascript
function mergeTwoLists(a, b) {
  const dummy = { next: null };
  let tail = dummy;
  while (a && b) {
    if (a.val <= b.val) { tail.next = a; a = a.next; }
    else { tail.next = b; b = b.next; }
    tail = tail.next;
  }
  tail.next = a || b;
  return dummy.next;
}
```

---

## Stacks and Queues

### Q28. Valid parentheses.

```javascript
function isValid(s) {
  const stack = [];
  const pairs = { ')': '(', ']': '[', '}': '{' };
  for (const c of s) {
    if (c in pairs) {
      if (stack.pop() !== pairs[c]) return false;
    } else {
      stack.push(c);
    }
  }
  return stack.length === 0;
}
```

**O(n)** time and space.

---

### Q29. Daily temperatures (monotonic stack).

```javascript
function dailyTemperatures(t) {
  const res = new Array(t.length).fill(0);
  const stack = []; // indices, decreasing temperatures
  for (let i = 0; i < t.length; i++) {
    while (stack.length && t[i] > t[stack[stack.length - 1]]) {
      const j = stack.pop();
      res[j] = i - j;
    }
    stack.push(i);
  }
  return res;
}
```

Classic monotonic stack — every index is pushed and popped at most once, **O(n)**.

---

### Q30. Implement queue using two stacks.

```javascript
class Queue {
  constructor() { this.in = []; this.out = []; }
  enqueue(x) { this.in.push(x); }
  dequeue() {
    if (!this.out.length) while (this.in.length) this.out.push(this.in.pop());
    return this.out.pop();
  }
  peek() {
    if (!this.out.length) while (this.in.length) this.out.push(this.in.pop());
    return this.out[this.out.length - 1];
  }
}
```

Amortised **O(1)** per operation: each element is moved at most once.

---

### Q31. Min stack — push/pop/top/getMin all O(1).

```javascript
class MinStack {
  constructor() { this.s = []; this.m = []; }
  push(x) {
    this.s.push(x);
    this.m.push(this.m.length === 0 ? x : Math.min(x, this.m[this.m.length - 1]));
  }
  pop() { this.m.pop(); return this.s.pop(); }
  top() { return this.s[this.s.length - 1]; }
  getMin() { return this.m[this.m.length - 1]; }
}
```

---

## Trees

### Q32. Tree traversals (DFS in / pre / post).

```javascript
function inorder(root, out = []) {
  if (!root) return out;
  inorder(root.left, out);
  out.push(root.val);
  inorder(root.right, out);
  return out;
}
function preorder(root, out = []) {
  if (!root) return out;
  out.push(root.val);
  preorder(root.left, out);
  preorder(root.right, out);
  return out;
}
function postorder(root, out = []) {
  if (!root) return out;
  postorder(root.left, out);
  postorder(root.right, out);
  out.push(root.val);
  return out;
}
```

**Iterative inorder using a stack:**
```javascript
function inorderIterative(root) {
  const stack = [], out = [];
  let node = root;
  while (node || stack.length) {
    while (node) { stack.push(node); node = node.left; }
    node = stack.pop();
    out.push(node.val);
    node = node.right;
  }
  return out;
}
```

---

### Q33. BFS / level-order traversal.

```javascript
function levelOrder(root) {
  if (!root) return [];
  const out = [], q = [root];
  while (q.length) {
    const level = [], next = [];
    for (const node of q) {
      level.push(node.val);
      if (node.left) next.push(node.left);
      if (node.right) next.push(node.right);
    }
    out.push(level);
    q.length = 0; q.push(...next);
  }
  return out;
}
```

**Time:** O(n). **Space:** O(width of tree).

---

### Q34. Validate a Binary Search Tree.

```javascript
function isValidBST(root, min = -Infinity, max = Infinity) {
  if (!root) return true;
  if (root.val <= min || root.val >= max) return false;
  return isValidBST(root.left, min, root.val) &&
         isValidBST(root.right, root.val, max);
}
```

Pass down running min/max bounds — checking just immediate children fails for cases like a right-grandchild smaller than the root.

---

### Q35. Lowest Common Ancestor (binary tree).

```javascript
function lowestCommonAncestor(root, p, q) {
  if (!root || root === p || root === q) return root;
  const left = lowestCommonAncestor(root.left, p, q);
  const right = lowestCommonAncestor(root.right, p, q);
  if (left && right) return root;
  return left || right;
}
```

**For a BST**, exploit ordering:
```javascript
function lcaBST(root, p, q) {
  while (root) {
    if (p.val < root.val && q.val < root.val) root = root.left;
    else if (p.val > root.val && q.val > root.val) root = root.right;
    else return root;
  }
}
```

---

### Q36. Maximum depth of binary tree.

```javascript
function maxDepth(root) {
  if (!root) return 0;
  return 1 + Math.max(maxDepth(root.left), maxDepth(root.right));
}
```

---

### Q37. Diameter of a binary tree.

```javascript
function diameterOfBinaryTree(root) {
  let best = 0;
  function depth(node) {
    if (!node) return 0;
    const l = depth(node.left), r = depth(node.right);
    best = Math.max(best, l + r);
    return 1 + Math.max(l, r);
  }
  depth(root);
  return best;
}
```

---

## Recursion and Backtracking

### Q38. Factorial.

```javascript
const factIter = n => { let r = 1; for (let i = 2; i <= n; i++) r *= i; return r; };
const factRec = n => n <= 1 ? 1 : n * factRec(n - 1);
```

Iterative is preferred (no stack growth). For very large n, use BigInt.

---

### Q39. Fibonacci — four ways.

```javascript
// 1. Naive recursion: O(2^n)
const fibR = n => n < 2 ? n : fibR(n - 1) + fibR(n - 2);

// 2. Memoised: O(n) time, O(n) space
function fibM(n, memo = {}) {
  if (n < 2) return n;
  if (memo[n] !== undefined) return memo[n];
  return memo[n] = fibM(n - 1, memo) + fibM(n - 2, memo);
}

// 3. Bottom-up DP: O(n) time, O(n) space
function fibDP(n) {
  const dp = [0, 1];
  for (let i = 2; i <= n; i++) dp[i] = dp[i - 1] + dp[i - 2];
  return dp[n];
}

// 4. Iterative two variables: O(n) time, O(1) space
function fibI(n) {
  let a = 0, b = 1;
  for (let i = 0; i < n; i++) [a, b] = [b, a + b];
  return a;
}
```

| Approach | Time | Space |
|----------|------|-------|
| Naive recursion | O(2ⁿ) | O(n) |
| Memoised | O(n) | O(n) |
| Bottom-up DP | O(n) | O(n) |
| Iterative O(1) | O(n) | O(1) |
| Matrix exponentiation | O(log n) | O(log n) |

---

### Q40. Generate all permutations.

```javascript
function permute(nums) {
  const res = [];
  function bt(path, used) {
    if (path.length === nums.length) { res.push([...path]); return; }
    for (let i = 0; i < nums.length; i++) {
      if (used[i]) continue;
      used[i] = true; path.push(nums[i]);
      bt(path, used);
      path.pop(); used[i] = false;
    }
  }
  bt([], []);
  return res;
}
```

**Time:** O(n · n!). Backtracking template — choose, recurse, un-choose.

---

### Q41. Subsets (power set).

```javascript
function subsets(nums) {
  const res = [];
  function bt(start, path) {
    res.push([...path]);
    for (let i = start; i < nums.length; i++) {
      path.push(nums[i]);
      bt(i + 1, path);
      path.pop();
    }
  }
  bt(0, []);
  return res;
}
```

**Time:** O(n · 2ⁿ).

---

## Dynamic Programming

### Q42. Climbing stairs.

```javascript
function climbStairs(n) {
  let a = 1, b = 1;
  for (let i = 2; i <= n; i++) [a, b] = [b, a + b];
  return b;
}
```

This is just Fibonacci. **O(n)** time, **O(1)** space.

---

### Q43. Coin change (minimum coins).

```javascript
function coinChange(coins, amount) {
  const dp = new Array(amount + 1).fill(Infinity);
  dp[0] = 0;
  for (let i = 1; i <= amount; i++) {
    for (const c of coins) {
      if (c <= i) dp[i] = Math.min(dp[i], dp[i - c] + 1);
    }
  }
  return dp[amount] === Infinity ? -1 : dp[amount];
}
```

**Time:** O(amount · coins.length). **Space:** O(amount).

---

### Q44. Longest Increasing Subsequence.

**O(n²) DP:**
```javascript
function lengthOfLIS(nums) {
  const dp = new Array(nums.length).fill(1);
  for (let i = 1; i < nums.length; i++) {
    for (let j = 0; j < i; j++) {
      if (nums[j] < nums[i]) dp[i] = Math.max(dp[i], dp[j] + 1);
    }
  }
  return Math.max(...dp);
}
```

**O(n log n) — patience sorting / binary search:**
```javascript
function lengthOfLIS(nums) {
  const tails = [];
  for (const n of nums) {
    let l = 0, r = tails.length;
    while (l < r) {
      const m = (l + r) >> 1;
      tails[m] < n ? l = m + 1 : r = m;
    }
    tails[l] = n;
  }
  return tails.length;
}
```

`tails[i]` = smallest possible tail value of an increasing subsequence of length i+1.

---

### Q45. House robber.

```javascript
function rob(nums) {
  let prev = 0, curr = 0;
  for (const n of nums) [prev, curr] = [curr, Math.max(curr, prev + n)];
  return curr;
}
```

State: at each house decide rob (and skip previous) or skip.

---

### Q46. Longest common subsequence.

```javascript
function lcs(a, b) {
  const dp = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      dp[i][j] = a[i - 1] === b[j - 1]
        ? dp[i - 1][j - 1] + 1
        : Math.max(dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return dp[a.length][b.length];
}
```

**Time:** O(m·n). Space can be optimised to O(min(m, n)).

---

### Q47. Edit distance (Levenshtein).

```javascript
function minDistance(a, b) {
  const dp = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
  for (let i = 0; i <= a.length; i++) dp[i][0] = i;
  for (let j = 0; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      dp[i][j] = a[i - 1] === b[j - 1]
        ? dp[i - 1][j - 1]
        : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
    }
  }
  return dp[a.length][b.length];
}
```

---

## Big-O Complexity Reference

### Common Operations

| Data structure | Access | Search | Insert | Delete |
|----------------|--------|--------|--------|--------|
| Array | O(1) | O(n) | O(n) | O(n) |
| Dynamic array (push/pop end) | O(1) | O(n) | O(1) amortised | O(1) end |
| Singly linked list | O(n) | O(n) | O(1) head | O(1) head |
| Doubly linked list | O(n) | O(n) | O(1) ends | O(1) ends |
| Hash map | — | O(1) avg | O(1) avg | O(1) avg |
| Binary search tree (balanced) | O(log n) | O(log n) | O(log n) | O(log n) |
| Heap | O(1) min/max | O(n) | O(log n) | O(log n) |
| Trie | — | O(k) | O(k) | O(k) |

### Common Algorithm Complexities

| Algorithm | Time | Space |
|-----------|------|-------|
| Linear scan | O(n) | O(1) |
| Binary search | O(log n) | O(1) |
| Merge / quick / heap sort | O(n log n) | varies |
| BFS / DFS | O(V + E) | O(V) |
| Dijkstra (binary heap) | O((V + E) log V) | O(V) |
| Floyd–Warshall | O(V³) | O(V²) |
| 0/1 Knapsack | O(n·W) | O(n·W) |
| Subsets generation | O(n · 2ⁿ) | O(2ⁿ) |
| Permutations | O(n · n!) | O(n!) |

### Space Complexity Tips

- Recursion adds O(depth) call stack space.
- Memoisation = trade space for time.
- Bottom-up DP often allows rolling arrays (O(1) or O(min dim)).
- In-place modification is the cleanest way to hit O(1) space.

---

## Senior Interview Tips

1. **Clarify before coding** — input range, types, allowed mutations, return shape.
2. **State complexity upfront** — both time and space.
3. **Walk through a small example** — catches off-by-one bugs early.
4. **Discuss trade-offs** — hash map (faster) vs sort (less memory), iterative vs recursive.
5. **Test edge cases**: empty input, single element, all duplicates, sorted/reverse, negatives.
6. **Don't memorise — pattern-match** — most problems reduce to: hashing, two pointers, sliding window, BFS/DFS, DP, or greedy.
