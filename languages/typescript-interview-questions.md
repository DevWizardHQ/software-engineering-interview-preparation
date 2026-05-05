# TypeScript Interview Questions and Answers

A pedagogical Q&A guide for full-stack interviews. Each question has a plain-language explanation and a concrete code example. Read it once to understand, read it twice to recall in the room.

---

## 1. Fundamentals

## Q1. What is TypeScript and what does it give you?

**Answer:**

TypeScript is a superset of JavaScript that adds a static type system. The compiler (`tsc`) checks your types at build time and then strips them out, producing plain JavaScript. You get earlier error detection, better editor autocomplete, safer refactoring, and self-documenting code.

```ts
function add(a: number, b: number): number {
  return a + b;
}

add(1, 2);       // 3
// add("1", 2);  // Compile error: string is not assignable to number
```

## Q2. `any` vs `unknown` vs `never`?

**Answer:**

`any` opts out of type checking — assigned to and from anything. Avoid it. `unknown` is the safe alternative: you can store any value, but you must narrow before using it. `never` is the type of values that never occur (functions that throw or loop forever, exhaustive switches).

```ts
let a: any = 5;
a.foo.bar;            // no error, but crashes at runtime

let u: unknown = 5;
// u.toFixed(2);      // Error — narrow first
if (typeof u === "number") u.toFixed(2);   // OK

function fail(msg: string): never { throw new Error(msg); }
```

## Q3. `void` vs `undefined`?

**Answer:**

`void` is for functions that don't return a useful value (like a logger). `undefined` is the actual value. A `void` return type lets the caller ignore whatever the function returns; an `undefined` return type means you must explicitly return `undefined`.

```ts
function log(msg: string): void { console.log(msg); }
function maybe(): undefined { return undefined; }

const fn: () => void = () => 42;   // OK, return value ignored
```

## Q4. Structural vs nominal typing.

**Answer:**

TypeScript uses structural typing: two types are compatible if their shapes match, regardless of name. Nominal typing (Java, C#) requires the type names to match. To force nominal-like checks in TS, use branded types.

```ts
interface Point { x: number; y: number; }
interface Coord { x: number; y: number; }

const p: Point = { x: 1, y: 2 };
const c: Coord = p;    // OK — same shape, even though names differ
```

## Q5. What does `readonly` do?

**Answer:**

`readonly` prevents reassigning a property. It does NOT make the underlying object deeply immutable — nested objects are still mutable. Use `ReadonlyArray<T>` or `readonly T[]` for arrays.

```ts
interface User {
  readonly id: number;
  name: string;
}

const u: User = { id: 1, name: "Iqbal" };
u.name = "Bob";      // OK
// u.id = 2;         // Error — readonly

const nums: readonly number[] = [1, 2, 3];
// nums.push(4);     // Error
```

---

## 2. Types vs Interfaces

## Q6. `type` vs `interface` — when to use which?

**Answer:**

`interface` describes the shape of an object or class and supports declaration merging and `extends`. `type` is more flexible — it can also be a union, intersection, primitive alias, or tuple. Use `interface` for public object contracts, `type` for unions and complex compositions.

```ts
interface User { id: number; name: string; }
interface User { email: string; }   // merges into one
// final: { id, name, email }

type Status = "open" | "closed";   // union — only type can do this
type Pair = [number, string];      // tuple
```

## Q7. Declaration merging.

**Answer:**

When two `interface` declarations share a name, TypeScript merges them into one. Useful for extending third-party library types. `type` aliases cannot merge.

```ts
interface Window {
  appVersion: string;
}

window.appVersion = "1.0";   // typed
```

## Q8. Intersection vs union.

**Answer:**

A union (`A | B`) means a value is one of `A` or `B`. An intersection (`A & B`) means a value is both `A` and `B` — it has all properties of both.

```ts
type A = { name: string };
type B = { age: number };

type AB = A & B;        // { name: string; age: number }
type AorB = A | B;      // either shape

const both: AB = { name: "Iqbal", age: 25 };
const either: AorB = { name: "Iqbal" };   // OK, just A
```

---

## 3. Generics

## Q9. What are generics?

**Answer:**

Generics let you write functions, classes, and types that work over many types while preserving the type information. Instead of `any`, you use a placeholder like `T` that gets bound to the actual type at the call site.

```ts
function identity<T>(value: T): T { return value; }

identity<string>("hi");   // string
identity(42);             // T inferred as number
```

## Q10. Generic constraints.

**Answer:**

`<T extends X>` means "T must be assignable to X." This lets you use properties of `X` inside the generic body while still being polymorphic.

```ts
function lengthOf<T extends { length: number }>(x: T): number {
  return x.length;
}

lengthOf("hello");     // 5
lengthOf([1, 2, 3]);   // 3
// lengthOf(42);       // Error — number has no length
```

## Q11. Default generic parameters.

**Answer:**

You can give a generic parameter a default type, used when the caller doesn't supply one.

```ts
interface ApiResponse<T = unknown> {
  data: T;
  status: number;
}

const r1: ApiResponse = { data: "anything", status: 200 };           // T = unknown
const r2: ApiResponse<{ id: number }> = { data: { id: 1 }, status: 200 };
```

## Q12. What does `T extends U ? X : Y` mean?

**Answer:**

This is a conditional type. If `T` is assignable to `U`, the result is `X`, otherwise `Y`. It enables type-level branching and is the basis of many utility types.

```ts
type IsString<T> = T extends string ? "yes" : "no";

type A = IsString<"hello">;   // "yes"
type B = IsString<42>;        // "no"
```

## Q13. The `infer` keyword.

**Answer:**

`infer` lets you extract a type inside a conditional. It introduces a new type variable bound to whatever fits in that position.

```ts
type ReturnTypeOf<F> = F extends (...args: any[]) => infer R ? R : never;

type R = ReturnTypeOf<() => number>;             // number
type S = ReturnTypeOf<(x: string) => string[]>;  // string[]
```

## Q14. Generics in classes vs functions vs types.

**Answer:**

All three accept generics. The key difference is when the type is bound: function generics are bound at call time; class generics are bound at instantiation; type/interface generics are bound when referenced.

```ts
class Box<T> {
  constructor(public value: T) {}
}

function unwrap<T>(b: Box<T>): T { return b.value; }
type Pair<A, B> = { first: A; second: B };

const b = new Box<number>(42);
unwrap(b);          // number (inferred)
```

---

## 4. Utility Types

## Q15. What are the most-used utility types?

**Answer:**

`Partial<T>` makes all properties optional. `Required<T>` makes all required. `Pick<T, K>` takes a subset of keys. `Omit<T, K>` removes keys. `Readonly<T>` makes all properties readonly. `Record<K, V>` builds an object type with given keys.

```ts
interface User { id: number; name: string; email: string; }

type Draft = Partial<User>;       // all optional
type Public = Pick<User, "id" | "name">;
type NoEmail = Omit<User, "email">;
type Locked = Readonly<User>;
type Map = Record<"a" | "b", number>;   // { a: number; b: number }
```

## Q16. Implement `Partial<T>` from scratch.

**Answer:**

`Partial` uses a mapped type with the optional modifier `?` to make every key optional.

```ts
type MyPartial<T> = { [K in keyof T]?: T[K] };

interface User { id: number; name: string; }
type DraftUser = MyPartial<User>;
// { id?: number; name?: string; }
```

## Q17. Implement `Pick` and `Omit`.

**Answer:**

`Pick` selects a subset of keys, `Omit` removes them. `Omit` is built on top of `Pick` and `Exclude`.

```ts
type MyPick<T, K extends keyof T> = { [P in K]: T[P] };
type MyOmit<T, K extends keyof T> = MyPick<T, Exclude<keyof T, K>>;

interface User { id: number; name: string; email: string; }
type Public = MyPick<User, "id" | "name">;
type NoEmail = MyOmit<User, "email">;
```

## Q18. `Record<K, V>` — what is it?

**Answer:**

`Record<K, V>` constructs an object type whose keys are `K` and whose values are `V`. Useful for lookup tables and dictionaries.

```ts
type Role = "admin" | "user" | "guest";
const permissions: Record<Role, string[]> = {
  admin: ["read", "write", "delete"],
  user:  ["read", "write"],
  guest: ["read"],
};
```

## Q19. `ReturnType` and `Parameters`.

**Answer:**

`ReturnType<T>` extracts the return type of a function type. `Parameters<T>` extracts the tuple of parameter types. Both use `infer` internally.

```ts
function getUser(id: number) {
  return { id, name: "Iqbal" };
}

type User = ReturnType<typeof getUser>;
// { id: number; name: string }

type Params = Parameters<typeof getUser>;
// [id: number]
```

## Q20. `Awaited<T>`.

**Answer:**

`Awaited<T>` unwraps a Promise to its resolved value. It recursively unwraps nested Promises (Promise of Promise of T).

```ts
type A = Awaited<Promise<string>>;            // string
type B = Awaited<Promise<Promise<number>>>;   // number
type C = Awaited<number>;                     // number — passes through
```

---

## 5. Conditional and Mapped Types

## Q21. Mapped types.

**Answer:**

Mapped types iterate over a union of keys and produce a new object type. Modifiers `+?`, `-?`, `+readonly`, `-readonly` add or remove the modifier.

```ts
type Mutable<T> = { -readonly [K in keyof T]: T[K] };

interface Locked { readonly id: number; readonly name: string; }
type Open = Mutable<Locked>;
// { id: number; name: string }
```

## Q22. Key remapping with `as`.

**Answer:**

Inside a mapped type, you can transform each key with `as`. Useful for renaming, filtering, or building getter signatures.

```ts
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
};

interface User { id: number; name: string; }
type UserGetters = Getters<User>;
// { getId: () => number; getName: () => string }
```

## Q23. Template literal types.

**Answer:**

Template literal types build new string literal types from existing ones. Combined with `Uppercase`, `Lowercase`, `Capitalize`, etc., they enable type-safe string transformations.

```ts
type Greeting = `Hello, ${string}!`;
const a: Greeting = "Hello, world!";   // OK
// const b: Greeting = "Hi";           // Error

type Event = "click" | "hover";
type Handler = `on${Capitalize<Event>}`;   // "onClick" | "onHover"
```

## Q24. Distributive conditionals — what are they good for?

**Answer:**

When a conditional type is applied to a union via a naked type parameter, it distributes over each member. This lets you transform every variant of a union.

```ts
type ToArray<T> = T extends any ? T[] : never;

type A = ToArray<string | number>;
// string[] | number[]   (distributed)

// Disable distribution by wrapping in tuple:
type ToArrayND<T> = [T] extends [any] ? T[] : never;
type B = ToArrayND<string | number>;
// (string | number)[]
```

## Q25. Recursive types.

**Answer:**

Types can refer to themselves, useful for trees, JSON, and deep transformations.

```ts
type Json =
  | string
  | number
  | boolean
  | null
  | Json[]
  | { [key: string]: Json };

type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K]
};
```

---

## 6. Type Narrowing and Guards

## Q26. What is type narrowing?

**Answer:**

Narrowing is when TypeScript reduces the type within a code branch based on a runtime check. Common narrowing tools: `typeof`, `instanceof`, `in`, equality, and user-defined guards.

```ts
function format(x: string | number): string {
  if (typeof x === "number") {
    return x.toFixed(2);   // x is number here
  }
  return x.toUpperCase();   // x is string here
}
```

## Q27. User-defined type guards.

**Answer:**

A user-defined guard is a function returning `param is Type`. When it returns true, TypeScript narrows the variable.

```ts
interface Cat { meow(): void; }
interface Dog { bark(): void; }

function isCat(a: Cat | Dog): a is Cat {
  return (a as Cat).meow !== undefined;
}

function speak(animal: Cat | Dog) {
  if (isCat(animal)) animal.meow();
  else animal.bark();
}
```

## Q28. Discriminated unions.

**Answer:**

A discriminated union is a union of object types that share a common literal property (the "tag"). Switch on the tag to narrow.

```ts
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "square"; side: number };

function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.radius ** 2;
    case "square": return s.side ** 2;
  }
}
```

## Q29. Exhaustiveness checking.

**Answer:**

To force the compiler to verify you handled every case, assign the "remaining" value to `never`. If you add a new variant later, the compiler errors at the assignment.

```ts
type Shape = { kind: "circle" } | { kind: "square" };

function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return 1;
    case "square": return 2;
    default:
      const _exhaustive: never = s;   // errors if a case is missed
      throw new Error("unreachable");
  }
}
```

## Q30. `unknown` requires narrowing.

**Answer:**

You cannot call methods or access properties on `unknown` until you prove its type. This makes it the safe replacement for `any`.

```ts
function parse(input: unknown): string {
  if (typeof input === "string") return input.trim();
  if (typeof input === "number") return String(input);
  throw new TypeError("not parseable");
}
```

## Q31. The `catch` clause type.

**Answer:**

By default, the variable in `catch` is `unknown` (with `useUnknownInCatchVariables` enabled — the modern default). You must check before using it.

```ts
try {
  doStuff();
} catch (e) {
  if (e instanceof Error) console.error(e.message);
  else console.error(String(e));
}
```

---

## 7. Advanced Patterns

## Q32. `satisfies` operator.

**Answer:**

`satisfies` checks that an expression matches a type without widening or narrowing the inferred literal types. You keep the precise inferred type while still validating shape.

```ts
type Colors = Record<string, [number, number, number]>;

const palette = {
  red:   [255, 0, 0],
  green: [0, 255, 0],
} satisfies Colors;

palette.red[0];   // number — narrowest tuple type retained
```

## Q33. `as const`.

**Answer:**

`as const` makes literal types narrow and arrays/objects deeply readonly. Useful for fixed config and union literal extraction.

```ts
const roles = ["admin", "user", "guest"] as const;
type Role = typeof roles[number];   // "admin" | "user" | "guest"

const config = { env: "prod" } as const;
config.env;   // type is "prod", not string
```

## Q34. `keyof`, `typeof`, and lookup types.

**Answer:**

`keyof T` is the union of `T`'s keys. `typeof x` (in type position) gets the type of a value. `T[K]` looks up a property's type.

```ts
const user = { id: 1, name: "Iqbal" };
type User = typeof user;          // { id: number; name: string }
type Keys = keyof User;           // "id" | "name"
type IdType = User["id"];         // number
```

## Q35. Function overloads.

**Answer:**

Function overloads let one function accept different combinations of arguments and return types. Define multiple signatures, then implement once with a wider type.

```ts
function fetchData(id: number): Promise<User>;
function fetchData(ids: number[]): Promise<User[]>;
function fetchData(input: number | number[]): Promise<User | User[]> {
  return Array.isArray(input)
    ? Promise.all(input.map(getOne))
    : getOne(input);
}
```

## Q36. Decorators.

**Answer:**

Decorators are functions that modify classes, methods, or properties. The modern Stage-3 decorator syntax (TS 5.0+) is supported natively without flags.

```ts
function logged<T extends Function>(value: T, ctx: ClassMethodDecoratorContext): T {
  return function (this: any, ...args: any[]) {
    console.log(`call ${String(ctx.name)}`);
    return (value as any).apply(this, args);
  } as any;
}

class Service {
  @logged
  greet(name: string) { return `Hi ${name}`; }
}
```

## Q37. Declaration files (`.d.ts`).

**Answer:**

A `.d.ts` file contains only type declarations, no runtime code. They describe the shape of a JS library, ambient globals, or module augmentations.

```ts
// global.d.ts
declare global {
  interface Window { appVersion: string; }
}
export {};

// vendor.d.ts
declare module "untyped-lib" {
  export function compute(n: number): number;
}
```

## Q38. Namespaces.

**Answer:**

Namespaces are an older way to group code. Modern TypeScript prefers ES modules. You may still see them in legacy code or for ambient declarations.

```ts
namespace Math2 {
  export function double(n: number) { return n * 2; }
}
Math2.double(3);   // 6
```

## Q39. Function `this` typing.

**Answer:**

Declare a fake first parameter named `this` to type the calling context. The parameter does not appear at runtime.

```ts
interface User { name: string; }
function greet(this: User) {
  return `Hi ${this.name}`;
}

greet.call({ name: "Iqbal" });   // OK
// greet();                       // Error — this would be undefined
```

## Q40. Variadic tuple types.

**Answer:**

Variadic tuples spread other tuples inside a tuple type. Used to type functions like `concat` and `bind` precisely.

```ts
type Concat<A extends any[], B extends any[]> = [...A, ...B];

type R = Concat<[1, 2], [3, 4]>;
// [1, 2, 3, 4]
```

## Q41. Readonly arrays and tuples.

**Answer:**

`readonly T[]` and `readonly [A, B]` prevent mutation methods like `push`. Tuple types can also be marked readonly.

```ts
function sum(nums: readonly number[]): number {
  // nums.push(1);   // Error
  return nums.reduce((a, b) => a + b, 0);
}

const t: readonly [string, number] = ["x", 1];
// t[0] = "y";   // Error
```

## Q42. Branded / nominal types.

**Answer:**

To force structural-equal types to be treated differently, attach a unique brand. Common for IDs, currency, and validated strings.

```ts
type UserId  = string & { readonly __brand: "UserId" };
type OrderId = string & { readonly __brand: "OrderId" };

function fetchUser(id: UserId) { /* ... */ }

const id = "abc" as UserId;
fetchUser(id);                       // OK
// fetchUser("abc");                 // Error — plain string not assignable
```

---

## 8. Tooling and tsconfig

## Q43. Most important `tsconfig.json` flags.

**Answer:**

`strict` enables all strict checks (recommended). `noImplicitAny` errors on missing types. `strictNullChecks` separates `null`/`undefined` from other types. `noUncheckedIndexedAccess` adds `undefined` to indexed access. `target` and `module` control output.

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

## Q44. `noUncheckedIndexedAccess` — what changes?

**Answer:**

With this flag on, accessing an array or object by index returns `T | undefined` instead of `T`. This forces you to handle the missing case.

```ts
const arr: number[] = [1, 2, 3];
const x = arr[10];   // type: number | undefined (with the flag)
if (x !== undefined) console.log(x.toFixed(2));
```

## Q45. `verbatimModuleSyntax`.

**Answer:**

This flag enforces explicit `import type` for type-only imports, ensuring the emitted JavaScript matches your imports exactly. Improves tree-shaking and avoids ambiguity in mixed JS/TS projects.

```ts
import type { User } from "./user";   // erased at runtime
import { fetchUser } from "./user";   // kept at runtime
```

## Q46. Project references.

**Answer:**

Project references split a large codebase into multiple `tsconfig.json` files that depend on each other. Each can be built and type-checked independently for faster compiles.

```json
// root tsconfig.json
{
  "references": [
    { "path": "./packages/server" },
    { "path": "./packages/client" }
  ]
}
```

## Q47. `tsc` vs Babel/swc/esbuild.

**Answer:**

`tsc` both type-checks and emits JS. Babel/swc/esbuild only strip types — they're much faster but never catch type errors. A common setup is to type-check with `tsc --noEmit` and bundle with esbuild/swc.

```bash
tsc --noEmit          # type-check only
esbuild src/index.ts --bundle --outfile=dist/index.js
```

---

## 9. Pitfalls and Real-World

## Q48. The "types are erased" gap.

**Answer:**

Types disappear at runtime. You cannot check `if (x instanceof MyInterface)` because the interface no longer exists. You need runtime checks (libraries like Zod) for data crossing your boundaries.

```ts
import { z } from "zod";
const UserSchema = z.object({ id: z.number(), name: z.string() });
type User = z.infer<typeof UserSchema>;

const data = UserSchema.parse(JSON.parse(input));   // runtime + type
```

## Q49. Why does this assignment fail?

**Answer:**

Object literals have "excess property checks" — TS rejects unknown properties even if structurally compatible. Either remove the extra property, use a variable, or widen the target type.

```ts
interface User { id: number; name: string; }

// Error — extra prop
// const u: User = { id: 1, name: "Iqbal", role: "admin" };

const data = { id: 1, name: "Iqbal", role: "admin" };
const u: User = data;   // OK — assigned via variable
```

## Q50. `interface Foo { (x: number): string }` — what is this?

**Answer:**

This is a callable interface. It describes an object that can be called like a function. Useful for libraries that mix function calls with extra properties.

```ts
interface Counter {
  (n: number): number;
  count: number;
}

const c: Counter = ((n: number) => (c.count += n)) as Counter;
c.count = 0;
c(5);          // 5
c.count;       // 5
```

## Q51. React + TS — typing children and props.

**Answer:**

Use `ReactNode` for children. Define props as an interface with optional fields. Avoid `React.FC` (some teams) because it implicitly adds children.

```tsx
import { ReactNode } from "react";

interface CardProps {
  title: string;
  children?: ReactNode;
  onClick?: () => void;
}

function Card({ title, children, onClick }: CardProps) {
  return <div onClick={onClick}><h3>{title}</h3>{children}</div>;
}
```

## Q52. Node + TS pitfalls.

**Answer:**

Always install `@types/node`. Be careful with `process.env` — values are `string | undefined` so narrow before use. ESM with `"type": "module"` requires `.js` extensions in imports even for TS files.

```ts
const port = process.env.PORT;
const num = port ? parseInt(port, 10) : 3000;
```

## Q53. Why use `as` cautiously?

**Answer:**

`as` is a type assertion — you're telling the compiler "trust me." It does not change the runtime value. Wrong assertions lead to silent bugs.

```ts
const x = "5" as unknown as number;   // compiles, but x is still a string
x.toFixed(2);                          // crashes at runtime
```

## Q54. Why does this object have unexpected extra properties allowed?

**Answer:**

When you assign through an intermediate variable, TypeScript drops the excess property check. To enforce it, define the target type on the variable directly.

```ts
interface User { id: number; }

const data = { id: 1, name: "extra" };
const u: User = data;     // allowed (no excess prop check)

// const u2: User = { id: 1, name: "extra" };   // Error — direct literal
```

## Q55. Type a function that returns the type of another's input.

**Answer:**

Use `Parameters` to extract the parameter tuple, then index into it.

```ts
function send(req: { url: string; body: object }) { /* ... */ }
type SendInput = Parameters<typeof send>[0];
// { url: string; body: object }
```

## Q56. `Required<T>` vs `NonNullable<T[K]>`.

**Answer:**

`Required<T>` removes optional modifiers from all properties. `NonNullable<T>` removes `null` and `undefined` from a single type. Different shapes, different jobs.

```ts
interface User { name?: string | null; }

type R = Required<User>;
// { name: string | null }   — required, but still nullable

type N = NonNullable<User["name"]>;
// string                     — null/undefined removed
```

---

## 10. More Advanced Type Tricks

## Q57. What is `Extract` and `Exclude`?

**Answer:**

`Extract<T, U>` keeps members of union `T` that are assignable to `U`. `Exclude<T, U>` removes them.

```ts
type Action = "create" | "read" | "update" | "delete";
type Mutating = Extract<Action, "create" | "update" | "delete">;
type Safe = Exclude<Action, "delete">;
// "create" | "read" | "update"
```

## Q58. What is `InstanceType<T>`?

**Answer:**

`InstanceType<T>` extracts the instance type of a class constructor.

```ts
class User { constructor(public id: number) {} }
type U = InstanceType<typeof User>;   // User
```

## Q59. What is index signatures?

**Answer:**

An index signature lets an object accept arbitrary keys of a given type. Useful for dictionaries.

```ts
interface Dict {
  [key: string]: number;
}

const counts: Dict = { apples: 3, oranges: 5 };
counts.bananas = 7;   // OK
```

## Q60. Tuple types vs arrays.

**Answer:**

Arrays are homogeneous and have variable length. Tuples have a fixed length and per-position types.

```ts
const arr: number[] = [1, 2, 3];
const tup: [string, number] = ["age", 25];

// tup[2];   // Error — out of bounds
```

## Q61. Optional and rest in tuple types.

**Answer:**

Tuples can have optional elements (`?`) and rest (`...`). Useful for typing functions like `setTimeout`.

```ts
type Args = [string, number?, ...boolean[]];

const a: Args = ["x"];
const b: Args = ["x", 1];
const c: Args = ["x", 1, true, false];
```

## Q62. What is `NoInfer` (TS 5.4+)?

**Answer:**

`NoInfer<T>` blocks inference for that position, forcing TS to infer the generic from another argument.

```ts
function defaulted<T>(value: T, fallback: NoInfer<T>): T {
  return value ?? fallback;
}

defaulted<number>(undefined as any, 5);   // T must come from explicit arg
```

## Q63. `Pick` a single key vs whole object access.

**Answer:**

`T[K]` gives the value type for one key. `Pick<T, K>` gives an object containing only that key.

```ts
interface User { id: number; name: string; }

type Id = User["id"];           // number
type Just = Pick<User, "id">;   // { id: number }
```

## Q64. Type-safe object iteration.

**Answer:**

`Object.keys` returns `string[]` even when you know the shape. Cast or use a typed helper to preserve key types.

```ts
function keysOf<T extends object>(obj: T): (keyof T)[] {
  return Object.keys(obj) as (keyof T)[];
}

const u = { id: 1, name: "Iqbal" };
keysOf(u).forEach(k => console.log(u[k]));
```

## Q65. `enum` vs union of literals.

**Answer:**

Enums create a runtime object and a type. Union literals exist only at the type level — lighter, tree-shakable, and JSON-friendly. Most modern TS codebases prefer literal unions.

```ts
// Enum
enum Status { Active, Inactive }
const s: Status = Status.Active;

// Literal union — preferred
type Status2 = "active" | "inactive";
const s2: Status2 = "active";
```

## Q66. `const` enums vs regular enums.

**Answer:**

`const enum` is inlined at compile time — no runtime object. Saves bundle size but breaks isolated module compilation, so it's disabled in many setups.

```ts
const enum Direction { Up, Down }
const d = Direction.Up;
// Compiled: const d = 0;
```

## Q67. What is `Symbol` typing?

**Answer:**

`symbol` is a primitive type. `unique symbol` is a special type for individual symbol values, used as keys.

```ts
const KEY: unique symbol = Symbol("k");
interface Box { [KEY]: number; }

const b: Box = { [KEY]: 42 };
```

## Q68. How do you type async functions?

**Answer:**

The return type of an `async` function is always `Promise<T>`. You can omit and let inference do the work.

```ts
async function load(): Promise<User> {
  const res = await fetch("/api/me");
  return res.json();
}

type R = ReturnType<typeof load>;   // Promise<User>
```

## Q69. Type narrowing with the `in` operator.

**Answer:**

`"prop" in obj` narrows the object's type to the variants that contain that property.

```ts
type Cat = { meow: () => void };
type Dog = { bark: () => void };

function speak(a: Cat | Dog) {
  if ("meow" in a) a.meow();
  else a.bark();
}
```

## Q70. Type narrowing with `typeof`.

**Answer:**

The `typeof` runtime operator narrows primitives. It can return one of a fixed set of strings.

```ts
function parse(x: string | number | boolean) {
  if (typeof x === "string") return x.length;
  if (typeof x === "number") return x.toFixed();
  return x ? 1 : 0;
}
```

## Q71. What is `assertNever` for?

**Answer:**

A helper function that takes `never` to enforce exhaustive switches at compile time. If a future case is added but unhandled, the line errors.

```ts
function assertNever(x: never): never {
  throw new Error(`Unexpected: ${x}`);
}

type Shape = "circle" | "square";
function f(s: Shape) {
  switch (s) {
    case "circle": return 1;
    case "square": return 2;
    default: return assertNever(s);
  }
}
```

## Q72. Mapping over a union to an object type.

**Answer:**

You can use a mapped type with the union as keys. Each becomes a property of the resulting object type.

```ts
type Status = "loading" | "success" | "error";
type Handlers = { [K in Status]: () => void };
// { loading: ()=>void; success: ()=>void; error: ()=>void }
```

## Q73. The difference between `T | null` and `T | undefined`.

**Answer:**

Both represent absence, but APIs differ. JSON treats `null` as a distinct value; `undefined` is dropped. Optional properties (`?`) include `undefined` automatically. Treat them as semantically different.

```ts
interface A { x?: number; }              // x is number | undefined
interface B { x: number | null; }        // x must be present, can be null

JSON.stringify({ a: undefined, b: null }); // '{"b":null}' — undefined dropped
```

## Q74. How do you express a non-empty array?

**Answer:**

Use a tuple with a head element followed by the rest type.

```ts
type NonEmpty<T> = [T, ...T[]];

const a: NonEmpty<number> = [1];
const b: NonEmpty<number> = [1, 2, 3];
// const c: NonEmpty<number> = [];   // Error
```

## Q75. What is `ConstructorParameters<T>`?

**Answer:**

`ConstructorParameters<T>` extracts the parameter tuple of a class constructor — useful when wrapping or proxying class instantiation.

```ts
class User { constructor(public id: number, public name: string) {} }
type Args = ConstructorParameters<typeof User>;
// [id: number, name: string]
```

## Q76. Type a deeply partial object.

**Answer:**

Recurse through nested object types using a conditional inside a mapped type.

```ts
type DeepPartial<T> = {
  [K in keyof T]?: T[K] extends object ? DeepPartial<T[K]> : T[K]
};

interface Config { db: { host: string; port: number; }; debug: boolean; }
const c: DeepPartial<Config> = { db: { host: "localhost" } };
```

## Q77. `Function` type — why avoid it?

**Answer:**

`Function` is too loose — it accepts any callable but loses the signature. Prefer a specific function type or `(...args: any[]) => any`.

```ts
// Bad
let f: Function;
// Good
let g: (n: number) => string;
```

## Q78. `object` vs `Object` vs `{}`.

**Answer:**

`object` is "any non-primitive value." `Object` and `{}` are essentially "any value with non-null prototype" — too permissive. Prefer `Record<string, unknown>` for generic dictionaries.

```ts
let a: object = { x: 1 };          // OK
// a = "hi";                        // Error — primitive
let b: {} = "hi";                  // OK — almost anything
let c: Record<string, unknown> = { x: 1 };
```

## Q79. How do you make a property required only when another is set?

**Answer:**

Use a discriminated union. Each shape covers one valid combination.

```ts
type Form =
  | { mode: "create"; data: { name: string } }
  | { mode: "edit"; id: number; data: { name?: string } };
```

## Q80. `unknown[]` vs `any[]` for generic arrays.

**Answer:**

`unknown[]` is safer — you must narrow before using elements. `any[]` allows anything silently. Default to `unknown[]` for input boundaries.

```ts
function logFirst(items: unknown[]) {
  const first = items[0];
  if (typeof first === "string") console.log(first.toUpperCase());
}
```

## Q81. Generic factory pattern.

**Answer:**

A factory that takes a class and returns instances, preserving the type.

```ts
function create<T extends new (...args: any[]) => any>(
  Ctor: T,
  ...args: ConstructorParameters<T>
): InstanceType<T> {
  return new Ctor(...args);
}

class User { constructor(public name: string) {} }
const u = create(User, "Iqbal");   // type: User
```

## Q82. How to type a polymorphic event emitter?

**Answer:**

Map event names to payload types, then narrow on the name.

```ts
type Events = {
  click: { x: number; y: number };
  submit: { value: string };
};

function on<K extends keyof Events>(
  event: K,
  handler: (payload: Events[K]) => void
): void { /* ... */ }

on("click", (e) => console.log(e.x, e.y));
on("submit", (e) => console.log(e.value));
```
