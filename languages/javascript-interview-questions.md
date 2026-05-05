# JavaScript Interview Questions

**Level:** Mid to Senior
**Topics:** ES6+, Closures, Prototypes, Async, Event Loop, Browser APIs, Performance, Security

---

## Table of Contents

1. [Fundamentals and Types](#fundamentals-and-types)
2. [Scopes, Hoisting, and Closures](#scopes-hoisting-and-closures)
3. [`this`, Call/Apply/Bind, Arrow Functions](#this-callapplybind-arrow-functions)
4. [Prototypes and Classes](#prototypes-and-classes)
5. [Promises and Async/Await](#promises-and-asyncawait)
6. [Event Loop](#event-loop)
7. [Iterators, Generators, Symbols](#iterators-generators-symbols)
8. [Collections and Data Structures](#collections-and-data-structures)
9. [Modules](#modules)
10. [Functional Patterns](#functional-patterns)
11. [Browser APIs and DOM](#browser-apis-and-dom)
12. [Security](#security)
13. [Performance and Memory](#performance-and-memory)
14. [Modern ES2020-2024](#modern-es2020-2024)

---

## Fundamentals and Types

### Q1. What are the primitive types in JavaScript?

**Answer:**
Seven primitives: `string`, `number`, `bigint`, `boolean`, `undefined`, `null`, `symbol`. Everything else is an `object` (including arrays, functions, dates).

`typeof null === 'object'` is a historical bug preserved for compatibility.

---

### Q2. Difference between `undefined` and `null`?

**Answer:**
- `undefined` — variable declared but no value assigned, or missing function arg, or missing property.
- `null` — explicitly assigned "no value" by the developer.

```js
let a;            // undefined
let b = null;     // null
typeof a;         // 'undefined'
typeof b;         // 'object'
a == b;           // true (loose)
a === b;          // false (strict)
```

---

### Q3. `==` vs `===`?

**Answer:**
- `==` performs type coercion before comparing.
- `===` checks type and value.

Always prefer `===` to avoid surprises:

```js
0 == '';          // true
0 == '0';         // true
'' == '0';        // false
null == undefined;// true
NaN == NaN;       // false (use Number.isNaN)
[] == false;      // true
```

Rule of thumb: only use `==` for `value == null` (catches both null and undefined).

---

### Q4. Explain type coercion.

**Answer:**
JavaScript automatically converts types in operations. Two kinds:

- **Implicit:** `1 + '2' === '12'` (number → string), `'5' - 2 === 3`.
- **Explicit:** `Number('5')`, `String(5)`, `Boolean(0)`.

Falsy values: `false`, `0`, `-0`, `0n`, `''`, `null`, `undefined`, `NaN`. Everything else is truthy (including `'0'`, `'false'`, `[]`, `{}`).

---

### Q5. What is `NaN` and how to test for it?

**Answer:**
"Not a Number," but `typeof NaN === 'number'`. `NaN !== NaN`. Use:

```js
Number.isNaN(value);   // strict, no coercion
isNaN('foo');          // true (coerces first — avoid)
```

---

### Q6. Difference between `var`, `let`, `const`?

**Answer:**

| Feature       | `var`            | `let`        | `const`      |
|---------------|------------------|--------------|--------------|
| Scope         | function         | block        | block        |
| Hoisted       | yes (initialized as undefined) | yes (TDZ) | yes (TDZ) |
| Redeclarable  | yes              | no           | no           |
| Reassignable  | yes              | yes          | no           |
| Global object property | yes      | no           | no           |

`const` prevents reassignment of the binding, not mutation of the value:

```js
const arr = [1, 2];
arr.push(3);     // works
arr = [];        // TypeError
```

---

### Q7. What is the Temporal Dead Zone (TDZ)?

**Answer:**
The period between entering a scope and the actual declaration of a `let`/`const`. Accessing the variable in the TDZ throws `ReferenceError`.

```js
console.log(x); // ReferenceError
let x = 5;
```

This makes errors louder and more predictable than `var`'s `undefined`.

---

### Q8. Pass by value or pass by reference?

**Answer:**
JavaScript is **pass by value**, but for objects the value is a reference.

```js
function mutate(obj) { obj.a = 99; }       // mutates caller's object
function reassign(obj) { obj = { a: 0 }; } // local rebinding only

const x = { a: 1 };
mutate(x);    // x.a === 99
reassign(x);  // x.a === 99 (unchanged)
```

---

## Scopes, Hoisting, and Closures

### Q9. What is hoisting?

**Answer:**
Declarations are conceptually moved to the top of their scope at compile time.

- `var` declarations are hoisted and initialized as `undefined`.
- `let`/`const` are hoisted but uninitialized (TDZ).
- Function **declarations** are fully hoisted (you can call them before they appear).
- Function **expressions** and arrow functions are not hoisted as functions.

```js
foo();            // works
function foo() {}

bar();            // TypeError: bar is not a function
var bar = () => {};
```

---

### Q10. Function scope vs block scope?

**Answer:**
- `var` is function-scoped — leaks out of `if`/`for` blocks.
- `let`/`const` are block-scoped — confined to the nearest `{}`.

```js
for (var i = 0; i < 3; i++) {}
console.log(i);  // 3 (leaked)

for (let j = 0; j < 3; j++) {}
console.log(j);  // ReferenceError
```

This is the classic loop-closure bug fix:

```js
for (var i = 0; i < 3; i++) setTimeout(() => console.log(i)); // 3,3,3
for (let i = 0; i < 3; i++) setTimeout(() => console.log(i)); // 0,1,2
```

---

### Q11. What is a closure?

**Answer:**
A closure is a function bundled with the lexical environment it was declared in. The function "remembers" variables from its creation scope, even after that scope has exited.

```js
function makeCounter() {
  let count = 0;
  return () => ++count;
}
const c = makeCounter();
c(); // 1
c(); // 2
```

Uses: data privacy, partial application, memoization, event handlers, module pattern.

---

### Q12. Common closure pitfall — capturing in loops.

**Answer:**

```js
const handlers = [];
for (var i = 0; i < 3; i++) {
  handlers.push(() => i); // all return 3
}
```

All callbacks share the same `i`. Fix with `let` (creates new binding per iteration) or an IIFE:

```js
for (let i = 0; i < 3; i++) handlers.push(() => i); // 0,1,2
```

---

### Q13. What is lexical scoping?

**Answer:**
Scope is determined by where a function is **written**, not where it is **called**. JavaScript uses lexical (static) scoping, which is why closures work.

```js
const x = 1;
function outer() {
  const x = 2;
  function inner() { return x; } // resolves to outer's x = 2
  return inner;
}
outer()(); // 2
```

---

### Q14. IIFE — what and why?

**Answer:**
Immediately Invoked Function Expression. Used historically to create a private scope before block scoping existed.

```js
(function () {
  const secret = 42;
})();
```

Today, ES modules and `let`/`const` make IIFEs largely obsolete except for one-off async-await contexts at top level in CommonJS.

---

## `this`, Call/Apply/Bind, Arrow Functions

### Q15. How is `this` determined?

**Answer:**
Determined at **call time** (except for arrow functions) by these rules in order:

1. `new fn()` → `this` is the new instance.
2. `fn.call(obj)` / `fn.apply(obj)` / bound function → explicitly set.
3. `obj.fn()` → `this` is `obj`.
4. Plain `fn()` → `undefined` in strict mode, `globalThis` otherwise.
5. Arrow function → inherits `this` from enclosing lexical scope.

---

### Q16. `call`, `apply`, `bind`?

**Answer:**

```js
function greet(greeting, punct) { return `${greeting}, ${this.name}${punct}`; }
const user = { name: 'Ada' };

greet.call(user, 'Hi', '!');           // "Hi, Ada!"
greet.apply(user, ['Hi', '!']);        // same; args as array
const bound = greet.bind(user, 'Hi');  // returns new function with this and partial args
bound('!');                             // "Hi, Ada!"
```

`bind` returns a new function; `call`/`apply` invoke immediately.

---

### Q17. Arrow functions vs regular functions?

**Answer:**

| Feature         | Regular        | Arrow         |
|-----------------|----------------|---------------|
| `this`          | dynamic        | lexical       |
| `arguments`     | available      | not available |
| `new`           | constructible  | not           |
| `prototype`     | yes            | no            |
| `yield`         | inside generator | not allowed |
| Hoisted (decl)  | yes            | no            |

Use arrows for callbacks where you want to keep outer `this`. Use regular functions for methods on objects/classes (so they get the right `this`) and constructors.

---

### Q18. Why does this fail?

```js
const user = {
  name: 'Ada',
  greet() { return `Hi, ${this.name}`; }
};
const fn = user.greet;
fn(); // 'Hi, undefined'
```

**Answer:**
Detached method. `fn()` is called without a receiver, so `this` is `undefined` in strict mode. Fix with `bind`, an arrow wrapping it, or call as `user.greet()`.

---

## Prototypes and Classes

### Q19. What is the prototype chain?

**Answer:**
Every object has an internal `[[Prototype]]` (accessible via `Object.getPrototypeOf` or `__proto__`). Property lookups walk the chain until found or until reaching `null`.

```js
const arr = [];
arr.__proto__ === Array.prototype;            // true
Array.prototype.__proto__ === Object.prototype; // true
Object.prototype.__proto__ === null;          // true
```

---

### Q20. Difference between `__proto__` and `prototype`?

**Answer:**
- `prototype` is a property on **constructor functions**, used as the prototype for instances created with `new`.
- `__proto__` is the actual link on **instances** to their prototype.

```js
function Dog() {}
const d = new Dog();
d.__proto__ === Dog.prototype; // true
```

---

### Q21. Inheritance with ES6 classes.

**Answer:**

```js
class Animal {
  constructor(name) { this.name = name; }
  speak() { return `${this.name} speaks`; }
}

class Dog extends Animal {
  speak() { return `${super.speak()} (woof)`; }
}

new Dog('Rex').speak(); // "Rex speaks (woof)"
```

Under the hood it is still prototypal — `Dog.prototype.__proto__ === Animal.prototype`.

---

### Q22. Static methods and private fields.

**Answer:**

```js
class Counter {
  static #instances = 0;       // private static
  #count = 0;                  // private instance
  constructor() { Counter.#instances++; }
  inc() { return ++this.#count; }
  static total() { return Counter.#instances; }
}
```

`#` makes fields truly private (enforced by the engine), unlike the older `_underscore` convention.

---

### Q23. `Object.create` vs `new`?

**Answer:**

```js
const proto = { greet() { return 'hi'; } };
const a = Object.create(proto);     // a.__proto__ === proto
a.greet();                           // 'hi'
```

`Object.create(p)` creates an object with `p` as its prototype, no constructor invoked. `new F()` creates an object with `F.prototype` as prototype and runs `F`.

---

### Q24. How does `new` work?

**Answer:**
`new F(...args)` does:

1. Create a new empty object.
2. Set its `[[Prototype]]` to `F.prototype`.
3. Call `F` with `this` bound to the new object.
4. If `F` returns an object, return that; otherwise return the new object.

---

## Promises and Async/Await

### Q25. What is a Promise?

**Answer:**
A placeholder for an eventual value. Has three states: `pending`, `fulfilled`, `rejected`. Once settled, state is immutable.

```js
const p = new Promise((resolve, reject) => {
  setTimeout(() => resolve(42), 100);
});
p.then(v => console.log(v));
```

---

### Q26. Why is this an antipattern?

```js
return new Promise((resolve, reject) => {
  fetchUser().then(resolve).catch(reject);
});
```

**Answer:**
The "explicit promise construction antipattern." `fetchUser()` already returns a promise — wrapping it adds nothing and loses error context. Just `return fetchUser();`.

---

### Q27. `Promise.all`, `allSettled`, `race`, `any`?

**Answer:**

| Method      | Resolves with | Fails when |
|-------------|---------------|------------|
| `all`       | array of all results | any rejects (fast-fail) |
| `allSettled`| array of `{status, value/reason}` | never (always resolves) |
| `race`      | first settled (resolve or reject) | first rejection wins if first |
| `any`       | first fulfilled | all reject (`AggregateError`) |

```js
const [users, posts] = await Promise.all([fetchUsers(), fetchPosts()]);
```

---

### Q28. What does async/await actually do?

**Answer:**
Syntactic sugar over promises and generators. An `async` function always returns a promise. `await x` unwraps a promise (or wraps a non-promise) and pauses the function until it settles, without blocking the thread.

```js
async function load() {
  try {
    const user = await fetchUser();
    return user;
  } catch (e) {
    // catches both sync throws and promise rejections
  }
}
```

---

### Q29. Sequential vs parallel async.

**Answer:**

```js
// Sequential — total = a + b
const r1 = await fetchA();
const r2 = await fetchB();

// Parallel — total = max(a, b)
const [r1, r2] = await Promise.all([fetchA(), fetchB()]);
```

A common senior interview gotcha — running independent awaits sequentially wastes time.

---

### Q30. How to limit concurrency?

**Answer:**

```js
async function pool(items, limit, fn) {
  const results = [];
  const executing = new Set();
  for (const item of items) {
    const p = Promise.resolve().then(() => fn(item));
    results.push(p);
    executing.add(p);
    p.finally(() => executing.delete(p));
    if (executing.size >= limit) await Promise.race(executing);
  }
  return Promise.all(results);
}
```

Or use a library (`p-limit`). Useful when fanning out HTTP/DB calls without overwhelming the target.

---

### Q31. Unhandled promise rejection — what happens?

**Answer:**
Browsers fire `unhandledrejection` event; Node.js logs a warning and (in newer versions) terminates the process. Always attach `.catch` or wrap awaits in `try/catch`. Add a global handler as a safety net:

```js
window.addEventListener('unhandledrejection', e => log(e.reason));
process.on('unhandledRejection', err => log(err));
```

---

### Q32. Implement a `sleep` and a timeout wrapper.

**Answer:**

```js
const sleep = ms => new Promise(r => setTimeout(r, ms));

function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), ms)),
  ]);
}
```

Note the original promise still runs to completion; you only stop awaiting it. Use `AbortController` to actually cancel `fetch`.

---

### Q33. AbortController — cancel async work.

**Answer:**

```js
const ctrl = new AbortController();
fetch('/data', { signal: ctrl.signal }).catch(e => {
  if (e.name === 'AbortError') console.log('cancelled');
});
ctrl.abort();
```

Used widely in React effect cleanup. Modern APIs (`fetch`, timers in Node, streams) accept `AbortSignal`.

---

## Event Loop

### Q34. Explain the event loop.

**Answer:**
JavaScript is single-threaded. The runtime uses a loop that continually:

1. Pops a task from the **macrotask queue** and runs it to completion.
2. Drains the **microtask queue** entirely (any microtask scheduling another microtask runs in the same tick).
3. Renders (in browsers) if needed.
4. Repeats.

**Macrotasks:** `setTimeout`, `setInterval`, `setImmediate` (Node), I/O, UI events.
**Microtasks:** promise callbacks (`.then`, `await` continuations), `queueMicrotask`, `MutationObserver`.

---

### Q35. Predict the output.

```js
console.log('1');
setTimeout(() => console.log('2'), 0);
Promise.resolve().then(() => console.log('3'));
console.log('4');
```

**Answer:** `1, 4, 3, 2`. Synchronous first, then microtasks (promise) before macrotasks (setTimeout).

---

### Q36. Microtask starvation.

**Answer:**
A long chain of microtasks blocks rendering and macrotasks because the queue is drained completely before the next macrotask runs.

```js
function loop() { Promise.resolve().then(loop); } // freezes UI
```

Yield via `setTimeout(fn, 0)` or `scheduler.yield()` (modern) to allow rendering.

---

### Q37. `process.nextTick` vs `setImmediate` vs `setTimeout` in Node.

**Answer:**
- `process.nextTick(cb)` — fires before any other I/O event, even before microtasks in some cases. Highest priority.
- `queueMicrotask(cb)` — promise queue.
- `setImmediate(cb)` — fires on the check phase, after I/O callbacks.
- `setTimeout(cb, 0)` — fires on the timers phase, ~1 ms minimum.

Recursive `nextTick` can starve I/O — prefer `setImmediate` for "later" semantics.

---

## Iterators, Generators, Symbols

### Q38. What is an iterator?

**Answer:**
An object with a `next()` method returning `{ value, done }`. An iterable has a `[Symbol.iterator]()` method returning an iterator. `for...of`, spread, and destructuring use this protocol.

```js
const range = {
  *[Symbol.iterator]() {
    for (let i = 1; i <= 3; i++) yield i;
  }
};
[...range]; // [1, 2, 3]
```

---

### Q39. Generators.

**Answer:**
Functions declared with `function*` that yield values lazily and can be paused/resumed.

```js
function* ids() {
  let i = 1;
  while (true) yield i++;
}
const g = ids();
g.next().value; // 1
g.next().value; // 2
```

Useful for lazy sequences, async coroutines (pre-async/await), and state machines.

---

### Q40. What is `Symbol`?

**Answer:**
A unique, immutable primitive used as an object key without collision. Often used for protocols (`Symbol.iterator`, `Symbol.asyncIterator`, `Symbol.toPrimitive`).

```js
const id = Symbol('id');
const obj = { [id]: 1 };
obj[id]; // 1; not enumerable in for...in or JSON.stringify
```

`Symbol.for('key')` shares symbols across realms (global registry).

---

### Q41. Async iterators.

**Answer:**

```js
async function* lines(stream) {
  for await (const chunk of stream) yield chunk.toString();
}
for await (const line of lines(fileStream)) console.log(line);
```

Used heavily for streams, paginated APIs, and cancellable producer/consumer patterns.

---

## Collections and Data Structures

### Q42. `Map` vs object for key/value storage?

**Answer:**

| Aspect            | `Object`           | `Map`                |
|-------------------|--------------------|----------------------|
| Key types         | string/symbol only | any (incl. objects)  |
| Iteration order   | mostly insertion   | insertion (guaranteed) |
| Size              | manual             | `.size`              |
| Performance       | optimized for fixed shapes | better for frequent add/remove |
| Inherited keys    | risk of pollution  | none                 |
| JSON              | native             | needs custom         |

Prefer `Map` for dynamic dictionaries. Prefer plain objects for fixed-shape records.

---

### Q43. `Set` vs array.

**Answer:**
`Set` enforces unique values with O(1) `has`/`add`/`delete`. Use `[...new Set(arr)]` to dedupe.

---

### Q44. `WeakMap` and `WeakSet`?

**Answer:**
Keys must be objects, and they are held weakly — garbage collection can reclaim a key even while it sits in the map. Useful for tagging objects without preventing their cleanup (e.g., private data, caches keyed by DOM nodes).

```js
const cache = new WeakMap();
function compute(node) {
  if (cache.has(node)) return cache.get(node);
  const v = expensive(node);
  cache.set(node, v);
  return v;
}
```

Not iterable (no enumeration of weak keys).

---

### Q45. Array methods you should know cold.

**Answer:**
Mutators: `push`, `pop`, `shift`, `unshift`, `splice`, `sort`, `reverse`, `fill`, `copyWithin`.
Non-mutators: `slice`, `concat`, `map`, `filter`, `reduce`, `flat`, `flatMap`, `find`, `findIndex`, `findLast`, `some`, `every`, `includes`, `indexOf`.
Newer immutable variants (ES2023): `toSorted`, `toReversed`, `toSpliced`, `with`.

---

### Q46. Destructuring tricks.

**Answer:**

```js
const { a = 10, b: renamed } = { a: undefined, b: 2 };
// a = 10 (default applied), renamed = 2

const [first, , third] = [1, 2, 3];

function f({ x, y } = {}) {}  // safe default

const [a, b, ...rest] = [1, 2, 3, 4]; // rest = [3,4]
```

---

### Q47. Spread vs rest.

**Answer:**
Same syntax (`...`), opposite roles:
- **Spread** — expands an iterable into elements/properties: `[...arr]`, `{...obj}`, `f(...args)`.
- **Rest** — collects the remainder into an array: `function f(...args)`, `const [a, ...rest] = arr`.

Spread on objects is shallow.

---

### Q48. Shallow vs deep copy.

**Answer:**

```js
const shallow1 = { ...obj };
const shallow2 = Object.assign({}, obj);
const shallow3 = obj.slice();             // arrays

const deep1 = structuredClone(obj);       // ES2022, handles cycles, Maps, Sets, Dates
const deep2 = JSON.parse(JSON.stringify(obj)); // loses Date, undefined, functions, BigInt
```

`structuredClone` is the modern correct answer.

---

## Modules

### Q49. ESM vs CommonJS.

**Answer:**

| Feature           | CommonJS              | ESM                       |
|-------------------|-----------------------|---------------------------|
| Syntax            | `require`/`module.exports` | `import`/`export`     |
| Loading           | synchronous           | async, statically analyzed|
| Bindings          | value copies          | live read-only bindings   |
| Top-level await   | no                    | yes                       |
| Tree-shaking      | hard                  | yes (static)              |
| `__dirname`       | available             | use `import.meta.url`     |
| Mixing            | can `require` ESM via dynamic `import()` only | can import CJS but only default |

---

### Q50. Live bindings — what does it mean?

**Answer:**
ESM imports reflect the current value in the exporting module, not a snapshot:

```js
// counter.mjs
export let count = 0;
export const inc = () => count++;

// main.mjs
import { count, inc } from './counter.mjs';
console.log(count); // 0
inc();
console.log(count); // 1
```

You cannot reassign an import — bindings are read-only on the import side.

---

### Q51. Dynamic imports.

**Answer:**

```js
const mod = await import('./feature.js');
mod.doThing();
```

Returns a promise, useful for code splitting, conditional loading, and avoiding circular issues.

---

## Functional Patterns

### Q52. What is currying?

**Answer:**
Transforming `f(a, b, c)` into `f(a)(b)(c)` so each call fixes one argument.

```js
const curry = fn => function curried(...args) {
  return args.length >= fn.length
    ? fn(...args)
    : (...more) => curried(...args, ...more);
};

const add = curry((a, b, c) => a + b + c);
add(1)(2)(3); // 6
add(1, 2)(3); // 6
```

Useful for partial application and point-free composition.

---

### Q53. Debounce vs throttle.

**Answer:**
- **Debounce** — wait until activity has stopped for X ms, then run once. Good for search-as-you-type.
- **Throttle** — run at most once every X ms. Good for scroll/resize handlers.

```js
function debounce(fn, ms) {
  let t;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

function throttle(fn, ms) {
  let last = 0, t;
  return (...args) => {
    const now = Date.now();
    const remaining = ms - (now - last);
    if (remaining <= 0) { last = now; fn(...args); }
    else { clearTimeout(t); t = setTimeout(() => { last = Date.now(); fn(...args); }, remaining); }
  };
}
```

---

### Q54. Memoization.

**Answer:**

```js
function memo(fn) {
  const cache = new Map();
  return (...args) => {
    const key = JSON.stringify(args);
    if (!cache.has(key)) cache.set(key, fn(...args));
    return cache.get(key);
  };
}
```

Watch out: JSON keys lose precision; use a Map of Maps or a `WeakMap` for object args. Be aware of unbounded cache growth.

---

### Q55. Immutability and `Object.freeze`.

**Answer:**
`Object.freeze(obj)` makes the object's own properties non-writable and non-configurable. Shallow only — nested objects remain mutable. Use `Object.isFrozen` to check. For deep freeze, recurse manually.

Practical immutability often uses non-mutating patterns (`{ ...obj, x: 1 }`) or libraries like Immer rather than freezing.

---

### Q56. Getters and setters.

**Answer:**

```js
const user = {
  first: 'Ada', last: 'Lovelace',
  get full() { return `${this.first} ${this.last}`; },
  set full(v) { [this.first, this.last] = v.split(' '); }
};
user.full;          // 'Ada Lovelace'
user.full = 'Alan Turing';
```

Use sparingly; they can hide expensive operations behind innocent property reads.

---

### Q57. `Proxy` and `Reflect`.

**Answer:**
`Proxy` intercepts operations on a target. Useful for validation, observation, virtualization (Vue 3 reactivity is built on Proxy).

```js
const target = { a: 1 };
const handler = {
  get(t, p) { console.log('get', p); return Reflect.get(t, p); },
  set(t, p, v) { if (typeof v !== 'number') throw 'numbers only'; return Reflect.set(t, p, v); }
};
const p = new Proxy(target, handler);
```

`Reflect` provides default operations matching proxy traps; preferred over manual `target[p] = v`.

---

## Browser APIs and DOM

### Q58. Event delegation.

**Answer:**
Attach one listener to a common ancestor and use `event.target` to dispatch. Reduces memory and works for dynamically added elements.

```js
document.querySelector('ul').addEventListener('click', e => {
  const li = e.target.closest('li');
  if (li) handle(li.dataset.id);
});
```

---

### Q59. Event capturing vs bubbling.

**Answer:**
The browser dispatches an event in three phases: capture (top → target), target, bubble (target → top). `addEventListener(type, fn, { capture: true })` listens in the capture phase. Default is bubble. `event.stopPropagation()` halts both directions; `stopImmediatePropagation` also stops other listeners on the same element.

---

### Q60. `localStorage` vs `sessionStorage` vs cookies vs IndexedDB.

**Answer:**

| Storage        | Capacity | Lifetime              | Sent with requests | API     |
|----------------|----------|-----------------------|--------------------|---------|
| Cookie         | ~4KB     | configurable          | yes                | sync    |
| sessionStorage | ~5MB     | tab session           | no                 | sync    |
| localStorage   | ~5–10MB  | until cleared         | no                 | sync    |
| IndexedDB      | hundreds of MB | until cleared    | no                 | async, transactions |

`localStorage` is synchronous — heavy use blocks the main thread. IndexedDB is preferred for structured/large data; consider wrappers like `idb`.

---

### Q61. `fetch` vs `XMLHttpRequest`.

**Answer:**
`fetch` is the modern promise-based API. Supports streaming via `Response.body`, request cancellation via `AbortController`, and clean syntax. Caveats:

- A 4xx/5xx is not a rejection — only network errors reject. Always check `res.ok`.
- Cookies require `credentials: 'include'` for cross-origin.
- No native upload progress (`XMLHttpRequest` still wins there); use streams or libraries.

---

### Q62. Web Workers.

**Answer:**
Workers run JS on a separate thread, communicating via `postMessage`. They have no DOM access. Use for CPU-heavy work.

```js
const w = new Worker('./worker.js');
w.postMessage({ task: 'parse', data });
w.onmessage = e => console.log(e.data);
```

`SharedArrayBuffer` plus `Atomics` enables shared memory (requires cross-origin isolation). `postMessage` uses structured clone; transfer ownership of `ArrayBuffer`s for zero-copy.

---

### Q63. Service Workers.

**Answer:**
A proxy between the browser and the network. Lifecycle: install → activate → fetch. Used for offline support, asset caching, push notifications, background sync. Must be served over HTTPS (except localhost).

```js
self.addEventListener('fetch', e => {
  e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
});
```

---

### Q64. `requestAnimationFrame`.

**Answer:**
Schedules a callback before the next paint, synced to the display refresh rate (typically 60Hz). Use for animations rather than `setTimeout(fn, 16)` — the browser pauses rAF when the tab is hidden, saving battery and CPU.

---

### Q65. `IntersectionObserver`.

**Answer:**
Async API to detect when elements enter/leave a viewport (or a scroll container). Used for lazy loading, infinite scroll, "viewability" tracking. Far cheaper than scroll-event polling.

---

## Security

### Q66. What is XSS and how do you prevent it?

**Answer:**
Cross-Site Scripting injects attacker JS into your page. Three flavors: stored, reflected, DOM-based.

Defenses:
- Encode/escape on output (frameworks like React escape by default).
- Avoid `innerHTML` with untrusted strings; prefer `textContent`.
- Sanitize HTML you must render (DOMPurify).
- Set a strict Content Security Policy (CSP) — blocks inline scripts, restricts sources.
- Use `httpOnly` cookies so XSS cannot exfiltrate them.

---

### Q67. CSP basics.

**Answer:**
A response header declaring allowed sources. Example:

```
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-abc123'; img-src https:; object-src 'none'
```

Blocks inline scripts unless they have a matching nonce/hash. Pair with `Trusted Types` for DOM-XSS protection.

---

### Q68. CSRF.

**Answer:**
An attacker site triggers an authenticated request to your site (browsers attach cookies). Defenses:
- `SameSite=Lax` (default) or `Strict` cookies.
- CSRF token (synchronizer token) for state-changing forms.
- Require custom header on AJAX (browsers won't add it cross-site without preflight).

---

### Q69. Prototype pollution.

**Answer:**
Modifying `Object.prototype` from a malicious payload alters every object.

```js
({})['__proto__']['polluted'] = true; // every object now has .polluted
```

Defenses: avoid recursive merge of untrusted JSON, use `Object.create(null)` for dictionaries, use `Map`, validate keys (reject `__proto__`, `constructor`, `prototype`).

---

## Performance and Memory

### Q70. Common causes of memory leaks.

**Answer:**
- Forgotten timers/intervals holding closures over large objects.
- DOM nodes detached but still referenced from JS.
- Event listeners not removed when components unmount.
- Global variables (accidental `x = 1` without declaration in non-strict).
- Closures capturing huge scopes unnecessarily.
- Caches that grow unbounded — use `WeakMap` or LRU.

DevTools "Memory" → heap snapshot diff is your tool.

---

### Q71. Reducing main-thread jank.

**Answer:**
- Break long tasks (>50ms) with `setTimeout` / `scheduler.yield()`.
- Move CPU work to Web Workers.
- Batch DOM reads then writes (avoid layout thrashing).
- Use `content-visibility: auto` and `IntersectionObserver` for offscreen content.
- Virtualize long lists.
- Use `requestIdleCallback` for non-urgent work.

---

### Q72. Layout thrashing.

**Answer:**
Repeatedly reading layout properties (`offsetTop`, `getBoundingClientRect`) interleaved with writes forces synchronous reflows. Batch reads first, then writes. `requestAnimationFrame` is the natural place for write phases.

---

## Modern ES2020-2024

### Q73. Optional chaining and nullish coalescing.

**Answer:**

```js
user?.address?.city          // undefined if any link is null/undefined
user?.greet?.()              // safe call
arr?.[0]                     // safe index

const port = config.port ?? 3000; // only falls through on null/undefined (NOT 0 or '')
```

Difference from `||`: `0 ?? 3000 === 0`, but `0 || 3000 === 3000`.

---

### Q74. Logical assignment operators.

**Answer:**

```js
a ||= b;   // a = a || b
a &&= b;   // a = a && b
a ??= b;   // a = a ?? b   — assign only if a is null/undefined
```

Useful for setting defaults without overwriting valid falsy values.

---

### Q75. `BigInt`.

**Answer:**
Arbitrary-precision integers. `123n` literal, or `BigInt(x)`. Cannot mix with `number` in arithmetic.

```js
2n ** 100n;        // 1267650600228229401496703205376n
BigInt(Number.MAX_SAFE_INTEGER) + 1n;
```

---

### Q76. Top-level await.

**Answer:**
In ES modules, `await` is allowed at module top level:

```js
const config = await (await fetch('/config.json')).json();
export default config;
```

Modules that import this one wait until its top-level promise resolves.

---

### Q77. `structuredClone`.

**Answer:**
Built-in deep clone replacing the `JSON.parse(JSON.stringify(...))` hack. Handles `Date`, `Map`, `Set`, `RegExp`, `ArrayBuffer`, cycles. Cannot clone functions, DOM nodes, or class prototypes (returns plain objects).

---

### Q78. Numeric separators.

**Answer:**
`const billion = 1_000_000_000;` — purely cosmetic, easier to read large numbers.

---

### Q79. `Array.prototype.at`.

**Answer:**
Negative indexing without modulo math:

```js
[1, 2, 3].at(-1); // 3
'hello'.at(-1);   // 'o'
```

---

### Q80. `Object.hasOwn` vs `hasOwnProperty`.

**Answer:**
`Object.hasOwn(obj, key)` is the recommended replacement — works on objects without `Object.prototype` (e.g., `Object.create(null)`):

```js
const dict = Object.create(null);
dict.a = 1;
dict.hasOwnProperty('a');     // TypeError
Object.hasOwn(dict, 'a');     // true
```

---

### Q81. Error cause chains.

**Answer:**

```js
try {
  doThing();
} catch (e) {
  throw new Error('Failed to process order', { cause: e });
}
```

Preserves the original error for diagnostics, accessible via `err.cause`.

---

### Q82. WeakRef and FinalizationRegistry.

**Answer:**
`WeakRef` lets you hold a weak reference to an object that GC may reclaim. `FinalizationRegistry` runs a callback when an object is collected. Use cases are narrow (caches, native handle cleanup); avoid in normal application code — non-deterministic.

---

### Q83. `Promise.withResolvers` (ES2024).

**Answer:**

```js
const { promise, resolve, reject } = Promise.withResolvers();
// pass promise to consumers, resolve/reject from elsewhere
```

Cleaner than the deferred pattern of capturing `resolve`/`reject` in a `new Promise` callback.

---

### Q84. Pattern: race-with-cancel for stale results.

**Answer:**

```js
let lastId = 0;
async function search(query) {
  const id = ++lastId;
  const res = await fetch(`/api?q=${query}`);
  if (id !== lastId) return; // newer call started; ignore stale
  render(await res.json());
}
```

A common pattern in autocomplete UIs to avoid out-of-order responses.

---

### Q85. What is `[Symbol.toPrimitive]`?

**Answer:**
Customize how an object converts to a primitive (number, string, default).

```js
const money = {
  amount: 42,
  [Symbol.toPrimitive](hint) {
    if (hint === 'number') return this.amount;
    if (hint === 'string') return `$${this.amount}`;
    return this.amount;
  }
};
+money;       // 42
`${money}`;   // '$42'
money + '';   // '42'
```

---

### Q86. Tagged template literals.

**Answer:**

```js
function html(strings, ...values) {
  return strings.reduce((acc, s, i) =>
    acc + s + (values[i] !== undefined ? escape(values[i]) : ''), '');
}
const safe = html`<p>${userInput}</p>`;
```

Used by libraries like styled-components, GraphQL `gql`, Lit.

---

### Q87. `globalThis`.

**Answer:**
A standardized way to access the global object across environments (`window` in browsers, `global` in Node, `self` in workers). Use instead of environment sniffing.

---

### Q88. Pitfall: comparing dates.

**Answer:**
`new Date('2024-01-01') === new Date('2024-01-01')` is `false` (different references). Compare via `.getTime()` or `+date` (numeric coercion).

---

### Q89. Why is `0.1 + 0.2 !== 0.3`?

**Answer:**
IEEE-754 double precision can't represent 0.1 or 0.2 exactly. Result is ~0.30000000000000004. Compare with epsilon:

```js
Math.abs((0.1 + 0.2) - 0.3) < Number.EPSILON;
```

For money, use integers (cents) or `BigInt`/decimal libraries.

---

### Q90. `for...in` vs `for...of` vs `forEach`.

**Answer:**

| Loop          | Iterates over          | Works on iterables | Skip with `break` |
|---------------|------------------------|--------------------|-------------------|
| `for...in`    | enumerable string keys (incl. inherited) | objects | yes |
| `for...of`    | values from iterator   | yes                | yes               |
| `forEach`     | values                 | arrays only        | no                |

`for...in` on arrays is a footgun — it iterates indices as strings and includes any added enumerable properties.

---
