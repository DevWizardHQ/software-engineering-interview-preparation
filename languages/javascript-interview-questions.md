# JavaScript Interview Questions and Answers

A pedagogical Q&A guide for full-stack interviews. Each question has a plain-language explanation and a concrete code example. Read it once to understand, read it twice to recall in the room.

---

## 1. Fundamentals and Types

## Q1. What are the primitive types in JavaScript?

**Answer:**

JavaScript has seven primitive types: `string`, `number`, `boolean`, `null`, `undefined`, `symbol`, and `bigint`. Primitives are immutable values stored directly in the variable. Anything that is not a primitive is an object (arrays, functions, plain objects, dates, etc.).

```js
typeof "hello";       // "string"
typeof 42;            // "number"
typeof true;          // "boolean"
typeof undefined;     // "undefined"
typeof Symbol("id");  // "symbol"
typeof 10n;           // "bigint"
typeof null;          // "object"  (historical bug; null IS still a primitive)
typeof {};            // "object"
```

## Q2. Difference between `undefined` and `null`?

**Answer:**

`undefined` means a variable was declared but never assigned, or a function returned nothing. `null` is an explicit assignment that says "no value here on purpose." Treat `undefined` as "JavaScript did this," and `null` as "I did this."

```js
let a;
console.log(a);           // undefined — not assigned
let b = null;
console.log(b);           // null — explicitly empty

a == null;                // true (both null and undefined match loosely)
a === null;               // false (strict — they are different types)
```

## Q3. What is the difference between `==` and `===`?

**Answer:**

`==` compares values after converting them to the same type (loose equality). `===` compares values without converting types (strict equality). Always prefer `===` unless you specifically want to treat `null` and `undefined` as equal.

```js
0 == "0";        // true  — string "0" is coerced to number 0
0 === "0";       // false — different types

null == undefined;   // true
null === undefined;  // false
```

## Q4. Explain type coercion.

**Answer:**

Type coercion is JavaScript automatically converting one type to another. It happens with `+`, `==`, template strings, and conditions. The rules are not always obvious, which is why strict equality is safer.

```js
"5" + 2;       // "52"  — number coerced to string for +
"5" - 2;       // 3     — string coerced to number for -
true + 1;      // 2     — boolean to number
[] + [];       // ""    — both become empty strings
[] + {};       // "[object Object]"
```

## Q5. What is `NaN` and how do you test for it?

**Answer:**

`NaN` means "Not a Number" but is technically of type `number`. It is the result of invalid math like `0/0` or `Number("abc")`. `NaN` is never equal to anything, even itself, so `===` does not work. Use `Number.isNaN()`.

```js
const x = Number("abc");
x === NaN;            // false — NaN is never equal to anything
Number.isNaN(x);      // true  — correct check
isNaN("abc");         // true  but unsafe — coerces first
```

## Q6. Difference between `var`, `let`, and `const`?

**Answer:**

`var` is function-scoped and hoisted with an `undefined` initial value. `let` and `const` are block-scoped and live in the Temporal Dead Zone until declared. `const` cannot be reassigned, but the object it points to can still be mutated.

```js
function demo() {
  if (true) {
    var a = 1;
    let b = 2;
    const c = 3;
  }
  console.log(a);   // 1   — var leaks out of the block
  // console.log(b); // ReferenceError
  // console.log(c); // ReferenceError
}

const list = [1, 2];
list.push(3);       // OK — mutating, not reassigning
// list = [];       // TypeError
```

## Q7. What is the Temporal Dead Zone (TDZ)?

**Answer:**

The Temporal Dead Zone is the period from when a `let` or `const` variable enters scope until its declaration line runs. Accessing it during this window throws a `ReferenceError`. This forces you to declare before use.

```js
// console.log(x); // ReferenceError — TDZ
let x = 5;

console.log(y);   // undefined — var is hoisted with undefined
var y = 5;
```

## Q8. Is JavaScript pass-by-value or pass-by-reference?

**Answer:**

JavaScript is always pass-by-value, but for objects the "value" is a reference to the object. So if you reassign the parameter, the caller does not see it; if you mutate the object, the caller does.

```js
function reassign(obj) { obj = { name: "B" }; }
function mutate(obj)   { obj.name = "B"; }

const user = { name: "A" };
reassign(user);
console.log(user.name);   // "A" — reassignment didn't affect caller
mutate(user);
console.log(user.name);   // "B" — mutation did
```

---

## 2. Scope, Hoisting, Closures

## Q9. What is hoisting?

**Answer:**

Hoisting is JavaScript moving declarations to the top of their scope before execution. Function declarations are hoisted with their body. `var` declarations are hoisted but initialised as `undefined`. `let` and `const` are hoisted but stay uninitialised in the TDZ.

```js
sayHi();                   // "Hi" — function declaration is fully hoisted
function sayHi() { console.log("Hi"); }

console.log(a);            // undefined — var hoisted, value is not
var a = 1;

// sayBye();               // TypeError — function expression not hoisted
var sayBye = function () { console.log("Bye"); };
```

## Q10. What is the difference between function scope and block scope?

**Answer:**

Function scope means a variable is visible inside the entire function. Block scope limits visibility to the nearest `{ }` block. `var` uses function scope; `let` and `const` use block scope.

```js
function test() {
  if (true) {
    var x = 1;     // function-scoped — visible below
    let y = 2;     // block-scoped — only visible in if-block
  }
  console.log(x);  // 1
  // console.log(y); // ReferenceError
}
```

## Q11. What is a closure?

**Answer:**

A closure is a function that remembers variables from the scope where it was created, even after that scope has finished. Closures are used for data privacy, factory functions, and event handlers.

```js
function counter() {
  let count = 0;          // captured by the inner function
  return function () {
    count++;
    return count;
  };
}

const next = counter();
next();   // 1
next();   // 2
next();   // 3 — count survives between calls
```

## Q12. What's a common closure pitfall in loops?

**Answer:**

If you use `var` inside a loop and create functions that reference the loop variable, all functions share the same variable. By the time they run, the loop has finished and the variable holds the final value. Use `let` (block-scoped per iteration) instead.

```js
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0);  // 3, 3, 3
}

for (let j = 0; j < 3; j++) {
  setTimeout(() => console.log(j), 0);  // 0, 1, 2
}
```

## Q13. What is lexical scoping?

**Answer:**

Lexical scoping means a function's scope is determined by where it is written in the source code, not where it is called. A function can always see variables in the file or function it was defined inside.

```js
const name = "outer";
function outer() {
  const name = "inner";
  function inner() { console.log(name); }   // sees "inner"
  return inner;
}
outer()();   // "inner"
```

## Q14. What is an IIFE?

**Answer:**

An Immediately Invoked Function Expression runs the moment it is defined. Before ES6 modules, it was the standard way to create a private scope so variables didn't leak globally.

```js
(function () {
  const secret = 42;
  console.log("runs immediately:", secret);
})();
// secret is not accessible here
```

---

## 3. `this`, Call/Apply/Bind, Arrow Functions

## Q15. How is `this` determined?

**Answer:**

`this` depends on how a function is called, not where it is defined. The rules in priority order: `new` binds `this` to the new instance; explicit `call`/`apply`/`bind` sets it; method calls set `this` to the object before the dot; otherwise it is `undefined` in strict mode or the global object otherwise.

```js
const user = {
  name: "Iqbal",
  greet() { console.log(this.name); }
};

user.greet();              // "Iqbal" — method call
const fn = user.greet;
fn();                      // undefined — plain call (strict mode)

fn.call({ name: "Bob" });  // "Bob" — explicit
```

## Q16. What do `call`, `apply`, and `bind` do?

**Answer:**

All three set `this` for a function. `call(thisArg, a, b)` invokes immediately with separate arguments. `apply(thisArg, [a, b])` invokes immediately with an array of arguments. `bind(thisArg, ...)` returns a new function with `this` permanently set, without invoking it yet.

```js
function greet(greeting, punct) {
  return `${greeting}, ${this.name}${punct}`;
}
const u = { name: "Iqbal" };

greet.call(u, "Hi", "!");          // "Hi, Iqbal!"
greet.apply(u, ["Hi", "!"]);       // "Hi, Iqbal!"
const bound = greet.bind(u, "Hi");
bound("!");                         // "Hi, Iqbal!"
```

## Q17. Arrow functions vs regular functions.

**Answer:**

Arrow functions do not have their own `this`, `arguments`, or `prototype`. They inherit `this` from the surrounding scope. They cannot be used as constructors. Use them for short callbacks; use regular functions for object methods and constructors.

```js
const obj = {
  name: "X",
  arrow:  () => console.log(this.name),  // this is NOT obj
  normal()  { console.log(this.name); }  // this IS obj
};
obj.arrow();   // undefined (or global)
obj.normal();  // "X"
```

## Q18. Why does this fail?

**Answer:**

When a method is passed as a callback, `this` is lost because the function is no longer called as a method. Fix by binding or by using an arrow wrapper.

```js
class Timer {
  constructor() { this.seconds = 0; }
  tick() { this.seconds++; console.log(this.seconds); }
}
const t = new Timer();
setInterval(t.tick, 1000);            // breaks — this is undefined
setInterval(t.tick.bind(t), 1000);    // works
setInterval(() => t.tick(), 1000);    // also works
```

---

## 4. Prototypes and Classes

## Q19. What is the prototype chain?

**Answer:**

Every object has an internal link to another object called its prototype. When you read a property, JavaScript searches the object, then its prototype, then its prototype's prototype, until it reaches `null`. This is how inheritance works.

```js
const animal = { eats: true };
const dog = Object.create(animal);
dog.barks = true;

console.log(dog.barks);   // true  — own property
console.log(dog.eats);    // true  — found via prototype
console.log(dog.flies);   // undefined — end of chain
```

## Q20. Difference between `__proto__` and `prototype`?

**Answer:**

`prototype` is a property on constructor functions. It is the object that will become the prototype of instances created with `new`. `__proto__` (or `Object.getPrototypeOf`) is the actual prototype link on a created object.

```js
function Dog() {}
Dog.prototype.bark = function () { return "woof"; };

const rex = new Dog();
rex.__proto__ === Dog.prototype;   // true
rex.bark();                         // "woof"
```

## Q21. How do you do inheritance with ES6 classes?

**Answer:**

Use `extends` to inherit and `super` to call the parent constructor or methods. Under the hood, classes are still prototype-based.

```js
class Animal {
  constructor(name) { this.name = name; }
  speak() { return `${this.name} makes a sound`; }
}

class Dog extends Animal {
  speak() { return `${super.speak()} — woof`; }
}

new Dog("Rex").speak();   // "Rex makes a sound — woof"
```

## Q22. Static methods and private fields.

**Answer:**

`static` methods belong to the class itself, not instances — call them as `ClassName.method()`. Private fields use a `#` prefix and are inaccessible outside the class.

```js
class Counter {
  #count = 0;
  increment() { this.#count++; }
  get value() { return this.#count; }
  static create() { return new Counter(); }
}

const c = Counter.create();
c.increment();
c.value;        // 1
// c.#count;    // SyntaxError — private
```

## Q23. `Object.create` vs `new`?

**Answer:**

`Object.create(proto)` creates a new object with `proto` as its prototype, without running any constructor. `new Constructor()` creates an object whose prototype is `Constructor.prototype` and runs the constructor function.

```js
const proto = { greet() { return "hi"; } };
const a = Object.create(proto);
a.greet();   // "hi"

function User() { this.name = "Iqbal"; }
const b = new User();
b.name;      // "Iqbal"
```

## Q24. How does `new` work?

**Answer:**

`new` creates an empty object, links its prototype to the constructor's `prototype`, calls the constructor with `this` set to the new object, and returns the object (unless the constructor explicitly returns another object).

```js
function newOperator(Ctor, ...args) {
  const obj = Object.create(Ctor.prototype);
  const result = Ctor.apply(obj, args);
  return (result && typeof result === "object") ? result : obj;
}

function Person(name) { this.name = name; }
const p = newOperator(Person, "Iqbal");
p.name;   // "Iqbal"
```

---

## 5. Promises and Async/Await

## Q25. What is a Promise?

**Answer:**

A Promise represents a value that will exist later. It has three states: pending, fulfilled (resolved with a value), or rejected (with an error). You handle it with `.then`, `.catch`, `.finally`, or with `await`.

```js
const p = new Promise((resolve, reject) => {
  setTimeout(() => resolve("done"), 100);
});

p.then(value => console.log(value))    // "done"
 .catch(err => console.error(err))
 .finally(() => console.log("cleanup"));
```

## Q26. Why is this an antipattern?

**Answer:**

Wrapping an existing Promise in `new Promise` is called the "Promise constructor antipattern." It loses error context and is redundant. Just return the Promise directly.

```js
// Bad
function getUser(id) {
  return new Promise((resolve, reject) => {
    fetch(`/api/users/${id}`).then(resolve, reject);
  });
}

// Good
function getUser(id) {
  return fetch(`/api/users/${id}`);
}
```

## Q27. `Promise.all`, `allSettled`, `race`, `any`?

**Answer:**

`all` waits for all to fulfill, fails fast on first rejection. `allSettled` waits for everyone, never rejects. `race` resolves or rejects with whichever finishes first. `any` resolves with the first fulfilled, ignoring rejections.

```js
const p1 = Promise.resolve(1);
const p2 = Promise.reject("err");
const p3 = Promise.resolve(3);

await Promise.all([p1, p3]);          // [1, 3]
await Promise.allSettled([p1, p2]);   // [{status:"fulfilled",value:1}, {status:"rejected",reason:"err"}]
await Promise.race([p1, p2]);         // 1
await Promise.any([p2, p3]);          // 3
```

## Q28. What does `async/await` actually do?

**Answer:**

`async` makes a function return a Promise. `await` pauses execution inside the function until the Promise settles, then resumes with the resolved value (or throws on rejection). It is just sugar over `.then`.

```js
async function load() {
  try {
    const res = await fetch("/api/data");
    const json = await res.json();
    return json;
  } catch (e) {
    console.error("failed:", e);
  }
}
```

## Q29. Sequential vs parallel async.

**Answer:**

Awaiting one at a time runs them sequentially. To run in parallel, start all the Promises first, then await them — usually with `Promise.all`.

```js
// Sequential — slow
const a = await fetchA();
const b = await fetchB();

// Parallel — faster, independent calls run together
const [a2, b2] = await Promise.all([fetchA(), fetchB()]);
```

## Q30. How do you limit concurrency?

**Answer:**

Run only N tasks at a time so you don't overwhelm a server or hit rate limits. A simple pattern is a worker pool that pulls from a queue.

```js
async function pool(tasks, limit) {
  const results = [];
  const executing = new Set();
  for (const task of tasks) {
    const p = task().then(r => { executing.delete(p); return r; });
    results.push(p);
    executing.add(p);
    if (executing.size >= limit) await Promise.race(executing);
  }
  return Promise.all(results);
}

await pool(urls.map(u => () => fetch(u)), 3);
```

## Q31. What happens with an unhandled promise rejection?

**Answer:**

If a Promise rejects and nobody handles it, Node logs a warning and (in newer versions) exits the process. Browsers fire an `unhandledrejection` event. Always attach `.catch` or wrap `await` in `try/catch`.

```js
process.on("unhandledRejection", (reason) => {
  console.error("Unhandled:", reason);
});

window.addEventListener("unhandledrejection", e => {
  console.error("Unhandled:", e.reason);
});
```

## Q32. Implement `sleep` and a timeout wrapper.

**Answer:**

`sleep` returns a Promise that resolves after a delay. A timeout wrapper races a Promise against a timer that rejects.

```js
const sleep = (ms) => new Promise(res => setTimeout(res, ms));

function withTimeout(promise, ms) {
  const timeout = new Promise((_, reject) =>
    setTimeout(() => reject(new Error("timeout")), ms)
  );
  return Promise.race([promise, timeout]);
}

await sleep(500);
await withTimeout(fetch("/slow"), 2000);
```

## Q33. How do you cancel async work with `AbortController`?

**Answer:**

`AbortController` exposes a `signal` you can pass to cancellable APIs (fetch, timers, custom code). Calling `controller.abort()` triggers cancellation.

```js
const controller = new AbortController();
setTimeout(() => controller.abort(), 1000);

try {
  const res = await fetch("/slow", { signal: controller.signal });
} catch (e) {
  if (e.name === "AbortError") console.log("cancelled");
}
```

---

## 6. Event Loop

## Q34. Explain the event loop.

**Answer:**

JavaScript is single-threaded. The event loop pulls tasks from a queue and runs them on the call stack. Microtasks (Promises, queueMicrotask) run after the current task and before the next macrotask (setTimeout, I/O, UI events). The loop alternates: run one task, drain microtasks, render, repeat.

```js
console.log("1");
setTimeout(() => console.log("2"), 0);
Promise.resolve().then(() => console.log("3"));
console.log("4");
// Order: 1, 4, 3, 2  — microtasks run before the next macrotask
```

## Q35. Predict the output.

**Answer:**

Microtasks (Promise callbacks) run before macrotasks (setTimeout). Within microtasks, they run in queue order.

```js
setTimeout(() => console.log("a"), 0);
Promise.resolve().then(() => console.log("b"));
Promise.resolve().then(() => console.log("c"));
console.log("d");
// d, b, c, a
```

## Q36. What is microtask starvation?

**Answer:**

If microtasks keep scheduling more microtasks, the event loop never reaches macrotasks like timers or rendering. The page can freeze even though no single task is slow.

```js
function starve() {
  Promise.resolve().then(starve);   // schedules itself forever
}
starve();
// setTimeout below never runs
setTimeout(() => console.log("never"), 0);
```

## Q37. `process.nextTick` vs `setImmediate` vs `setTimeout` in Node.

**Answer:**

`process.nextTick` runs before any I/O or timers — even before other microtasks. `setImmediate` runs in the check phase, after I/O. `setTimeout(fn, 0)` runs in the timers phase, with at least 1ms delay.

```js
setTimeout(() => console.log("timeout"), 0);
setImmediate(() => console.log("immediate"));
process.nextTick(() => console.log("nextTick"));
Promise.resolve().then(() => console.log("promise"));
// nextTick, promise, then timeout/immediate (order varies)
```

---

## 7. Iterators, Generators, Symbols

## Q38. What is an iterator?

**Answer:**

An iterator is an object with a `next()` method that returns `{ value, done }`. Anything that implements `[Symbol.iterator]` can be iterated with `for...of` or spread.

```js
const range = {
  from: 1, to: 3,
  [Symbol.iterator]() {
    let i = this.from;
    const last = this.to;
    return {
      next: () => i <= last
        ? { value: i++, done: false }
        : { value: undefined, done: true }
    };
  }
};

for (const n of range) console.log(n);   // 1, 2, 3
```

## Q39. What are generators?

**Answer:**

A generator is a function that can pause and resume. Declared with `function*` and uses `yield`. Calling it returns an iterator. Each `next()` runs until the next `yield`.

```js
function* count() {
  yield 1;
  yield 2;
  yield 3;
}

const g = count();
g.next();   // { value: 1, done: false }
g.next();   // { value: 2, done: false }
g.next();   // { value: 3, done: false }
g.next();   // { value: undefined, done: true }
```

## Q40. What is a `Symbol`?

**Answer:**

A `Symbol` is a unique, immutable primitive. Two symbols created with the same description are still different. They are commonly used as object keys that won't collide and as well-known protocol keys like `Symbol.iterator`.

```js
const a = Symbol("id");
const b = Symbol("id");
a === b;   // false

const user = { [a]: 123 };
user[a];   // 123
```

## Q41. What are async iterators?

**Answer:**

Async iterators yield Promises and are consumed with `for await...of`. They are perfect for streams of asynchronous data.

```js
async function* lines(file) {
  for (const chunk of file) {
    for (const line of chunk.split("\n")) yield line;
  }
}

for await (const line of lines(stream)) {
  console.log(line);
}
```

---

## 8. Collections and Data Structures

## Q42. `Map` vs object for key/value storage?

**Answer:**

A `Map` accepts any key (including objects), preserves insertion order, has a `size` property, and is optimised for frequent additions and lookups. An object only allows string/symbol keys and inherits from `Object.prototype` (which can collide with keys like `toString`).

```js
const m = new Map();
const key = { id: 1 };
m.set(key, "value");
m.get(key);    // "value"
m.size;        // 1

const o = {};
o[key] = "x";  // key becomes "[object Object]"
```

## Q43. `Set` vs array.

**Answer:**

A `Set` stores unique values with O(1) membership checks. Arrays allow duplicates and use O(n) `indexOf`. Use `Set` to deduplicate and to test "have I seen this?"

```js
const seen = new Set();
const items = [1, 2, 2, 3, 1];
for (const x of items) seen.add(x);
[...seen];   // [1, 2, 3]
```

## Q44. What are `WeakMap` and `WeakSet`?

**Answer:**

`WeakMap` and `WeakSet` hold their keys/values weakly — when no other reference exists, the entry can be garbage collected. Keys must be objects. Useful for attaching metadata to objects without preventing cleanup.

```js
const cache = new WeakMap();
function meta(obj) {
  if (!cache.has(obj)) cache.set(obj, { hits: 0 });
  const entry = cache.get(obj);
  entry.hits++;
  return entry;
}
// When obj has no other refs, the cache entry disappears too.
```

## Q45. Array methods you should know cold.

**Answer:**

`map` transforms each item. `filter` keeps items matching a predicate. `reduce` collapses to a single value. `find` returns the first match. `some`/`every` test conditions. None of these mutate the original array.

```js
const nums = [1, 2, 3, 4];
nums.map(n => n * 2);              // [2, 4, 6, 8]
nums.filter(n => n % 2 === 0);     // [2, 4]
nums.reduce((s, n) => s + n, 0);   // 10
nums.find(n => n > 2);             // 3
nums.some(n => n > 3);             // true
nums.every(n => n > 0);            // true
```

## Q46. Destructuring tricks.

**Answer:**

Destructuring extracts properties from objects and elements from arrays into variables. You can rename, default, and nest.

```js
const user = { name: "Iqbal", age: 25, address: { city: "Dhaka" } };
const { name, age: years, address: { city }, role = "guest" } = user;
// name="Iqbal", years=25, city="Dhaka", role="guest"

const [first, , third] = [1, 2, 3];   // skip middle
```

## Q47. Spread vs rest.

**Answer:**

They look the same (`...`) but have opposite jobs. Spread expands an iterable into individual elements. Rest collects multiple elements into one variable.

```js
// Spread — expand
const arr = [1, 2, 3];
console.log(Math.max(...arr));     // 3
const merged = [...arr, 4, 5];

// Rest — collect
function sum(...nums) { return nums.reduce((a, b) => a + b, 0); }
sum(1, 2, 3);                       // 6
```

## Q48. Shallow vs deep copy.

**Answer:**

A shallow copy duplicates the top level but shares nested objects. A deep copy duplicates everything recursively. Modern JavaScript has `structuredClone` for true deep copies.

```js
const original = { a: 1, nested: { b: 2 } };
const shallow = { ...original };
shallow.nested.b = 99;
original.nested.b;   // 99 — same reference

const deep = structuredClone(original);
deep.nested.b = 5;
original.nested.b;   // unchanged
```

---

## 9. Modules

## Q49. ESM vs CommonJS.

**Answer:**

ESM (`import`/`export`) is the modern standard. It is static (analysed at parse time), supports tree-shaking, and runs asynchronously. CommonJS (`require`/`module.exports`) is Node's older system, dynamic, and synchronous. Browsers only support ESM.

```js
// ESM
export const greet = name => `Hi ${name}`;
import { greet } from "./util.js";

// CommonJS
module.exports.greet = name => `Hi ${name}`;
const { greet } = require("./util");
```

## Q50. What is a "live binding" in ESM?

**Answer:**

When you import a value from an ES module, you get a live reference, not a copy. If the source module updates the variable, your import sees the new value. CommonJS exports a snapshot.

```js
// counter.js
export let count = 0;
export const inc = () => count++;

// main.js
import { count, inc } from "./counter.js";
console.log(count);  // 0
inc();
console.log(count);  // 1 — live binding
```

## Q51. What are dynamic imports?

**Answer:**

`import()` is a function-like call that returns a Promise resolving to a module. It enables lazy loading and conditional imports.

```js
button.addEventListener("click", async () => {
  const { renderChart } = await import("./chart.js");
  renderChart();
});
```

---

## 10. Functional Patterns

## Q52. What is currying?

**Answer:**

Currying transforms a function with multiple arguments into a chain of functions, each taking one argument. Useful for partial application.

```js
const add = a => b => c => a + b + c;
add(1)(2)(3);   // 6

const add5 = add(2)(3);
add5(10);       // 15
```

## Q53. Debounce vs throttle.

**Answer:**

Debounce postpones a function until events stop firing for `delay` ms (good for search-as-you-type). Throttle limits a function to run at most once every `delay` ms (good for scroll/resize handlers).

```js
function debounce(fn, delay) {
  let id;
  return (...args) => {
    clearTimeout(id);
    id = setTimeout(() => fn(...args), delay);
  };
}

function throttle(fn, delay) {
  let last = 0;
  return (...args) => {
    const now = Date.now();
    if (now - last >= delay) {
      last = now;
      fn(...args);
    }
  };
}
```

## Q54. What is memoization?

**Answer:**

Memoization caches the result of a function for a given input so repeated calls return instantly. Best for pure, expensive functions.

```js
function memoize(fn) {
  const cache = new Map();
  return (arg) => {
    if (cache.has(arg)) return cache.get(arg);
    const result = fn(arg);
    cache.set(arg, result);
    return result;
  };
}

const square = n => n * n;
const fastSquare = memoize(square);
fastSquare(5);   // computed
fastSquare(5);   // cached
```

## Q55. Immutability and `Object.freeze`.

**Answer:**

`Object.freeze` makes an object's top level immutable — no adding, removing, or changing existing properties. It is shallow; nested objects can still mutate.

```js
const config = Object.freeze({ env: "prod", limits: { rps: 10 } });
config.env = "dev";          // silently ignored (or throws in strict mode)
config.limits.rps = 100;     // works — nested is not frozen
```

## Q56. Getters and setters.

**Answer:**

`get` and `set` define properties that look like fields but run code. Useful for computed values, validation, and lazy loading.

```js
class Temp {
  constructor(c) { this._c = c; }
  get fahrenheit()    { return this._c * 9 / 5 + 32; }
  set fahrenheit(f)   { this._c = (f - 32) * 5 / 9; }
}

const t = new Temp(0);
t.fahrenheit;        // 32
t.fahrenheit = 212;
t._c;                // 100
```

## Q57. What is `Proxy`?

**Answer:**

A `Proxy` wraps an object and intercepts operations like `get`, `set`, `has`, and `deleteProperty`. Useful for validation, observation, and lazy data fetching.

```js
const target = { count: 0 };
const proxy = new Proxy(target, {
  set(obj, key, value) {
    if (typeof value !== "number") throw new TypeError("number only");
    obj[key] = value;
    return true;
  }
});

proxy.count = 5;     // OK
// proxy.count = "x";  // TypeError
```

---

## 11. Browser APIs and DOM

## Q58. What is event delegation?

**Answer:**

Instead of attaching a listener to every child, attach one to a common ancestor and detect the source via `event.target`. Saves memory and works for elements added later.

```js
document.querySelector("#list").addEventListener("click", (e) => {
  const item = e.target.closest("li");
  if (!item) return;
  console.log("clicked:", item.dataset.id);
});
```

## Q59. Event capturing vs bubbling.

**Answer:**

DOM events go through three phases: capturing (top-down to target), target, then bubbling (target back up). Most listeners run on bubble. Pass `{ capture: true }` for capture phase.

```js
parent.addEventListener("click", () => console.log("parent"), true);  // capture
child.addEventListener("click", () => console.log("child"));          // bubble
// Click on child logs: "parent" then "child"
```

## Q60. `localStorage` vs `sessionStorage` vs cookies vs IndexedDB.

**Answer:**

`localStorage` persists per-origin, no expiry, ~5MB, synchronous. `sessionStorage` clears on tab close. Cookies are sent with HTTP requests automatically (~4KB). IndexedDB is a transactional, asynchronous database for large structured data.

```js
localStorage.setItem("token", "abc");
sessionStorage.setItem("nav", "open");
document.cookie = "user=iqbal; max-age=3600; path=/";

// IndexedDB — async
const req = indexedDB.open("appdb", 1);
```

## Q61. `fetch` vs `XMLHttpRequest`.

**Answer:**

`fetch` returns a Promise, supports streams, and has a clean API. `XMLHttpRequest` is the older, callback-based API. `fetch` does NOT reject on HTTP errors — only network failures — so you must check `response.ok`.

```js
const res = await fetch("/api/user");
if (!res.ok) throw new Error(`HTTP ${res.status}`);
const data = await res.json();
```

## Q62. What is a Web Worker?

**Answer:**

A Web Worker runs JavaScript on a background thread, freeing the main thread. Workers cannot touch the DOM. Use them for CPU-heavy work like parsing or image processing.

```js
// main.js
const worker = new Worker("worker.js");
worker.postMessage({ n: 1_000_000 });
worker.onmessage = (e) => console.log("result:", e.data);

// worker.js
onmessage = (e) => {
  let sum = 0;
  for (let i = 0; i < e.data.n; i++) sum += i;
  postMessage(sum);
};
```

## Q63. What is a Service Worker?

**Answer:**

A Service Worker is a proxy between your page and the network. It can cache assets, intercept fetches, and enable offline mode and push notifications.

```js
// register
navigator.serviceWorker.register("/sw.js");

// sw.js
self.addEventListener("fetch", (event) => {
  event.respondWith(
    caches.match(event.request).then(c => c || fetch(event.request))
  );
});
```

## Q64. What is `requestAnimationFrame`?

**Answer:**

`requestAnimationFrame` schedules a callback before the next browser repaint, typically 60 times per second. Use it for smooth animations instead of `setTimeout`.

```js
function animate() {
  ball.style.left = (parseInt(ball.style.left) + 2) + "px";
  requestAnimationFrame(animate);
}
animate();
```

## Q65. What is `IntersectionObserver`?

**Answer:**

`IntersectionObserver` reports when an element enters or leaves the viewport. Used for lazy-loading images, infinite scroll, and analytics impressions.

```js
const obs = new IntersectionObserver((entries) => {
  for (const e of entries) {
    if (e.isIntersecting) {
      e.target.src = e.target.dataset.src;
      obs.unobserve(e.target);
    }
  }
});
document.querySelectorAll("img[data-src]").forEach(img => obs.observe(img));
```

---

## 12. Security

## Q66. What is XSS and how do you prevent it?

**Answer:**

Cross-Site Scripting injects attacker-controlled HTML or JavaScript into your page. Prevention: never insert raw user input as HTML, escape on output, prefer `textContent` for plain text, set a strong CSP, and validate URLs to block `javascript:` schemes. If you must render HTML, run it through a vetted sanitizer.

```js
// BAD — uses raw HTML insertion
div.insertAdjacentHTML("beforeend", userInput);

// GOOD — text-only, no HTML parsing
div.textContent = userInput;
```

## Q67. What is CSP?

**Answer:**

Content Security Policy is an HTTP header that tells the browser which scripts, styles, and resources are allowed. A strict CSP blocks inline scripts and unknown origins, killing most XSS vectors.

```text
Content-Security-Policy:
  default-src 'self';
  script-src 'self';
  img-src 'self' https://cdn.example.com;
  object-src 'none';
```

## Q68. What is CSRF?

**Answer:**

Cross-Site Request Forgery tricks a logged-in user's browser into sending an authenticated request to your site. Defenses: SameSite cookies, anti-CSRF tokens on state-changing forms, and never use cookies for cross-origin POST without proof of intent.

```js
// Server sends a CSRF token in a meta tag
fetch("/transfer", {
  method: "POST",
  headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf]").content }
});
```

## Q69. What is prototype pollution?

**Answer:**

Prototype pollution is when attacker input modifies `Object.prototype` (or another shared prototype), affecting every object in the program. Often happens with unsafe deep-merge of JSON. Defense: validate input keys, use `Object.create(null)`, freeze prototypes.

```js
// Vulnerable merge
function merge(target, src) {
  for (const k in src) {
    if (typeof src[k] === "object") merge(target[k] ??= {}, src[k]);
    else target[k] = src[k];
  }
}
merge({}, JSON.parse('{"__proto__": {"isAdmin": true}}'));
({}).isAdmin;   // true — polluted!
```

---

## 13. Performance and Memory

## Q70. Common causes of memory leaks.

**Answer:**

Detached DOM nodes still referenced by JS, forgotten timers, unremoved event listeners, growing global state, and closures holding large objects. Fix by cleaning up in component teardown and using `WeakMap`/`WeakRef` where appropriate.

```js
// Leak — no way to remove the listener
function bindLeak(el) {
  el.addEventListener("click", () => console.log(el.dataset));
}

// Fix — return a cleanup function
function bind(el) {
  const handler = () => console.log(el.dataset);
  el.addEventListener("click", handler);
  return () => el.removeEventListener("click", handler);
}
```

## Q71. How do you reduce main-thread jank?

**Answer:**

Break long tasks into smaller chunks (yield to the event loop), move heavy work to Web Workers, use `requestIdleCallback` for background tasks, virtualize long lists, and avoid forced synchronous layout.

```js
async function processAll(items) {
  for (let i = 0; i < items.length; i++) {
    process(items[i]);
    if (i % 100 === 0) await new Promise(r => setTimeout(r, 0));
  }
}
```

## Q72. What is layout thrashing?

**Answer:**

Layout thrashing happens when you alternate reads and writes to the DOM in a loop, forcing the browser to recalculate layout each iteration. Batch reads, then batch writes.

```js
// Thrashing
for (const el of elements) {
  el.style.width = el.offsetWidth + 10 + "px";   // read + write
}

// Batched
const widths = elements.map(el => el.offsetWidth);
elements.forEach((el, i) => el.style.width = widths[i] + 10 + "px");
```

---

## 14. Modern ES2020 - 2024

## Q73. Optional chaining and nullish coalescing.

**Answer:**

`?.` short-circuits to `undefined` if the left side is `null` or `undefined`. `??` returns the right side only if the left is `null` or `undefined` (unlike `||`, which also triggers on 0 and "").

```js
const user = { profile: null };
user.profile?.name;        // undefined (no error)

const count = 0;
count || 10;               // 10 — wrong, 0 is valid
count ?? 10;               // 0  — correct
```

## Q74. Logical assignment operators.

**Answer:**

`||=`, `&&=`, and `??=` combine logical operators with assignment. They only assign if the condition holds.

```js
let a = null;
a ??= "default";    // a = "default"

let b = "";
b ||= "fallback";   // b = "fallback"

let c = { name: "X" };
c.name &&= c.name.toUpperCase();   // "X"
```

## Q75. What is `BigInt`?

**Answer:**

`BigInt` is for integers beyond `Number.MAX_SAFE_INTEGER` (2^53 - 1). Append `n` to literals. You cannot mix `BigInt` and `Number` in arithmetic.

```js
const big = 9007199254740993n;
big + 1n;          // 9007199254740994n
// big + 1;        // TypeError — cannot mix
typeof big;        // "bigint"
```

## Q76. What is top-level `await`?

**Answer:**

Top-level `await` lets you use `await` directly in an ES module's top-level code, without wrapping in an async function. Available in ESM only.

```js
// data.mjs
const res = await fetch("/api/init");
export const config = await res.json();
```

## Q77. What is `structuredClone`?

**Answer:**

`structuredClone` deep-copies an object, including nested arrays, Maps, Sets, Dates, and typed arrays. Replaces the old `JSON.parse(JSON.stringify(x))` trick, which loses non-JSON data.

```js
const original = { date: new Date(), set: new Set([1, 2]) };
const copy = structuredClone(original);
copy.date.getTime() === original.date.getTime();   // true
copy.set instanceof Set;                            // true
```

## Q78. What are numeric separators?

**Answer:**

Underscores in numeric literals make them readable. They have no effect on the value.

```js
const billion = 1_000_000_000;
const hex = 0xFF_FF_FF;
const bin = 0b1010_0001;
```

## Q79. What is `Array.prototype.at`?

**Answer:**

`at(i)` returns the element at index `i`, supporting negative indices to count from the end. Cleaner than `arr[arr.length - 1]`.

```js
const arr = [1, 2, 3, 4];
arr.at(0);    // 1
arr.at(-1);   // 4
arr.at(-2);   // 3
```

## Q80. `Object.hasOwn` vs `hasOwnProperty`.

**Answer:**

`Object.hasOwn(obj, key)` is the safe modern replacement. The old `obj.hasOwnProperty(key)` breaks on objects created with `Object.create(null)` or when `hasOwnProperty` is overridden.

```js
const o = Object.create(null);
o.foo = 1;
// o.hasOwnProperty("foo");   // TypeError — no method
Object.hasOwn(o, "foo");      // true
```

## Q81. Error cause chains.

**Answer:**

`new Error(msg, { cause })` lets you wrap a low-level error inside a higher-level one without losing the original. Inspect with `err.cause`.

```js
try {
  await fetch("/api");
} catch (e) {
  throw new Error("Failed to load profile", { cause: e });
}
```

## Q82. What are `WeakRef` and `FinalizationRegistry`?

**Answer:**

`WeakRef` lets you hold a reference that does not prevent garbage collection. `FinalizationRegistry` runs a callback when an object is collected. Useful for caches and observability — but use sparingly.

```js
const ref = new WeakRef(largeObject);
const reg = new FinalizationRegistry((tag) => console.log("GC'd:", tag));
reg.register(largeObject, "largeObject");
```

## Q83. What is `Promise.withResolvers`?

**Answer:**

ES2024's `Promise.withResolvers()` returns a fresh Promise plus its `resolve` and `reject` functions, removing the need to capture them inside a constructor.

```js
const { promise, resolve, reject } = Promise.withResolvers();
setTimeout(() => resolve("done"), 100);
await promise;   // "done"
```

## Q84. Pattern: race-with-cancel for stale results.

**Answer:**

When firing async requests as the user types, you must drop responses from old requests so the latest wins. Use a counter or `AbortController`.

```js
let latest = 0;
async function search(q) {
  const id = ++latest;
  const res = await fetch(`/q?term=${q}`).then(r => r.json());
  if (id !== latest) return;     // stale, ignore
  render(res);
}
```

## Q85. What is `[Symbol.toPrimitive]`?

**Answer:**

`[Symbol.toPrimitive]` is a method JavaScript calls to convert your object to a primitive when used in arithmetic, string templates, or comparisons. Lets you control coercion.

```js
class Money {
  constructor(amount) { this.amount = amount; }
  [Symbol.toPrimitive](hint) {
    if (hint === "number") return this.amount;
    if (hint === "string") return `$${this.amount}`;
    return `${this.amount}`;
  }
}

const m = new Money(50);
+m;          // 50  (number hint)
`${m}`;      // "$50" (string hint)
```

## Q86. What are tagged template literals?

**Answer:**

A tag is a function that receives the literal's static strings and dynamic values separately. Used for safe HTML, SQL escaping, i18n, and styled components.

```js
function html(strings, ...values) {
  return strings.reduce((out, s, i) => {
    const v = values[i] ? String(values[i]).replace(/</g, "&lt;") : "";
    return out + s + v;
  }, "");
}

const name = "<script>";
html`<p>Hello ${name}</p>`;
// "<p>Hello &lt;script></p>"
```

## Q87. What is `globalThis`?

**Answer:**

`globalThis` is the universal way to reach the global object in any environment — `window` in browsers, `global` in Node, `self` in workers.

```js
globalThis.appVersion = "1.0";
console.log(globalThis.appVersion);
```

## Q88. Pitfall: comparing dates.

**Answer:**

`new Date()` objects compare by reference with `===`, not by time. Use `.getTime()` or numeric coercion.

```js
const a = new Date("2024-01-01");
const b = new Date("2024-01-01");
a === b;                       // false
a.getTime() === b.getTime();   // true
+a === +b;                     // true
```

## Q89. Why is `0.1 + 0.2 !== 0.3`?

**Answer:**

JavaScript uses IEEE-754 double-precision floats. `0.1` and `0.2` cannot be represented exactly, so their sum is `0.30000000000000004`. Compare with a tolerance for floating-point math, or use `BigInt`/decimal libraries for money.

```js
0.1 + 0.2;                            // 0.30000000000000004
Math.abs(0.1 + 0.2 - 0.3) < 1e-9;     // true — safe comparison
```

## Q90. `for...in` vs `for...of` vs `forEach`.

**Answer:**

`for...in` iterates enumerable keys including inherited ones (avoid for arrays). `for...of` iterates iterable values (arrays, strings, Maps, Sets). `forEach` is an array method that cannot `break` or use `await` cleanly.

```js
const arr = ["a", "b", "c"];

for (const key in arr) console.log(key);   // "0", "1", "2"
for (const val of arr) console.log(val);   // "a", "b", "c"
arr.forEach(v => console.log(v));          // "a", "b", "c"
```

## Q91. What does `Object.entries` / `Object.fromEntries` do?

**Answer:**

`Object.entries` turns an object into `[key, value]` pairs. `Object.fromEntries` does the reverse. Together they enable easy object transformation.

```js
const user = { name: "Iqbal", age: 25 };
const entries = Object.entries(user);
// [["name","Iqbal"], ["age",25]]

const upper = Object.fromEntries(
  entries.map(([k, v]) => [k.toUpperCase(), v])
);
// { NAME: "Iqbal", AGE: 25 }
```

## Q92. Truthy and falsy values.

**Answer:**

Falsy values: `false`, `0`, `-0`, `0n`, `""`, `null`, `undefined`, `NaN`. Everything else is truthy, including empty arrays and empty objects (which trips up many devs).

```js
Boolean([]);    // true  — empty array is truthy
Boolean({});    // true  — empty object is truthy
Boolean("0");   // true  — non-empty string is truthy
Boolean(0);     // false
Boolean("");    // false
```

## Q93. Difference between `Object.keys`, `Object.values`, and `Object.entries`?

**Answer:**

All three return arrays. `keys` gives property names, `values` gives values, and `entries` gives `[key, value]` pairs. They only return own, enumerable properties.

```js
const o = { a: 1, b: 2 };
Object.keys(o);     // ["a", "b"]
Object.values(o);   // [1, 2]
Object.entries(o);  // [["a",1], ["b",2]]
```

## Q94. What is `JSON.stringify` and its hidden options?

**Answer:**

`JSON.stringify(value, replacer, space)` converts to JSON. The replacer can be a function or an array of allowed keys. The third argument adds indentation. Functions, `undefined`, and symbols are dropped.

```js
const obj = { a: 1, b: 2, secret: "x" };
JSON.stringify(obj, ["a", "b"], 2);
// '{
//   "a": 1,
//   "b": 2
// }'
```

## Q95. What is short-circuit evaluation?

**Answer:**

Logical operators stop evaluating once the result is determined. `a && b` only evaluates `b` if `a` is truthy. `a || b` only evaluates `b` if `a` is falsy. Used for guards and defaults.

```js
user && user.name;           // safe access
name || "Anonymous";         // default value
isLoggedIn && fetchData();   // conditional call
```

## Q96. What is a regular expression and how to use it?

**Answer:**

A RegExp matches patterns in strings. Created with `/pattern/flags` or `new RegExp(...)`. Common flags: `g` (global), `i` (case-insensitive), `m` (multiline). Use `.test`, `.match`, `.replace`, and `String.matchAll`.

```js
const re = /(\w+)@(\w+\.\w+)/;
"hi iqbal@example.com".match(re);
// ["iqbal@example.com", "iqbal", "example.com", index: 3, ...]

"foo bar foo".replace(/foo/g, "baz");   // "baz bar baz"
```

## Q97. What is `instanceof` and when to use it?

**Answer:**

`instanceof` checks whether an object's prototype chain includes a constructor's `prototype`. Useful for class checks but breaks across realms (iframes) and primitives.

```js
class Cat {}
const c = new Cat();
c instanceof Cat;        // true
c instanceof Object;     // true

[] instanceof Array;     // true
"hi" instanceof String;  // false — primitive, not boxed
```

## Q98. What is array `flat` and `flatMap`?

**Answer:**

`flat(depth)` flattens nested arrays. `flatMap` is `map` followed by `flat(1)` — useful for one-to-many transforms.

```js
[1, [2, [3, [4]]]].flat();          // [1, 2, [3, [4]]]
[1, [2, [3, [4]]]].flat(2);         // [1, 2, 3, [4]]
[1, [2, [3, [4]]]].flat(Infinity);  // [1, 2, 3, 4]

["one two", "three four"].flatMap(s => s.split(" "));
// ["one", "two", "three", "four"]
```

## Q99. What is the difference between `slice`, `splice`, and `split`?

**Answer:**

`slice(start, end)` returns a copy of part of an array or string without modifying it. `splice(start, count, ...add)` mutates the array, removing and/or inserting items. `split(sep)` splits a string into an array.

```js
const arr = [1, 2, 3, 4];
arr.slice(1, 3);     // [2, 3]   — arr unchanged
arr.splice(1, 2);    // [2, 3]   — arr is now [1, 4]

"a-b-c".split("-"); // ["a", "b", "c"]
```

## Q100. What is the difference between `Object.assign` and spread?

**Answer:**

Both shallow-copy properties. `Object.assign(target, ...sources)` mutates `target` and returns it. The spread operator creates a new object. Spread is more readable.

```js
const a = { x: 1 };
const b = { y: 2 };

Object.assign({}, a, b);   // { x: 1, y: 2 }  — new object
({ ...a, ...b });          // { x: 1, y: 2 }  — same result, cleaner
Object.assign(a, b);       // mutates a → { x: 1, y: 2 }
```
