# TypeScript Interview Questions

**Level:** Mid to Senior
**Topics:** Type System, Generics, Utility Types, Conditional/Mapped Types, Inference, Narrowing, Tooling

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Types vs Interfaces](#types-vs-interfaces)
3. [Generics](#generics)
4. [Utility Types](#utility-types)
5. [Conditional and Mapped Types](#conditional-and-mapped-types)
6. [Type Narrowing and Guards](#type-narrowing-and-guards)
7. [Advanced Patterns](#advanced-patterns)
8. [Tooling and tsconfig](#tooling-and-tsconfig)
9. [Pitfalls and Real-World](#pitfalls-and-real-world)

---

## Fundamentals

### Q1. What is TypeScript and what does it give you?

**Answer:**
A typed superset of JavaScript that compiles to plain JavaScript. Benefits:

- Catches type errors at compile time, not runtime.
- Better IDE: autocompletion, inline docs, safe refactoring.
- Self-documenting APIs.
- Encodes intent (e.g., "this string is a UUID").

Costs: build step, learning curve, occasional fights with `@types` packages.

---

### Q2. `any` vs `unknown` vs `never`?

**Answer:**

| Type      | Meaning                            | Behavior |
|-----------|------------------------------------|----------|
| `any`     | opt-out of type checking           | assignable to/from anything; no safety |
| `unknown` | safe top type                      | must narrow before use |
| `never`   | bottom type — value never occurs   | useful for exhaustiveness |

```ts
function parse(x: unknown) {
  // x.toUpperCase(); // error
  if (typeof x === 'string') x.toUpperCase(); // ok after narrowing
}

function fail(msg: string): never { throw new Error(msg); }
```

`any` should be a code smell — every `any` removes the typechecker's protection from that variable.

---

### Q3. `void` vs `undefined`?

**Answer:**
- `void` is a return type meaning "the caller should not use this value." A function typed `() => void` may return `undefined`, but its return type is treated as ignored.
- `undefined` is the actual value/type.

Subtle: a callback `() => void` accepts a function returning anything (the return value is just ignored), which is why `arr.forEach(item => list.push(item))` works.

---

### Q4. Structural vs nominal typing.

**Answer:**
TypeScript uses **structural** typing — compatibility is based on shape:

```ts
interface Named { name: string; }
class User { name = ''; age = 0; }
const n: Named = new User(); // ok — User has the shape
```

Nominal typing (Java, C#) requires explicit declared inheritance. To simulate nominal types in TS, use **branded types** (Q42).

---

### Q5. What does `readonly` do?

**Answer:**
Marks properties as immutable from a TypeScript perspective. It is a compile-time guarantee — at runtime, the property is still writable.

```ts
interface Config { readonly port: number; }
const c: Config = { port: 80 };
c.port = 81; // error

const arr: readonly number[] = [1, 2, 3];
arr.push(4); // error — push doesn't exist on readonly array
```

---

## Types vs Interfaces

### Q6. `type` vs `interface` — when to use which?

**Answer:**

| Feature                    | `interface`        | `type`               |
|----------------------------|--------------------|----------------------|
| Extends                    | `extends`          | `&` intersection     |
| Declaration merging        | yes                | no                   |
| Unions                     | no                 | yes                  |
| Tuples / primitives / mapped | no              | yes                  |
| Performance for objects    | slightly better    | comparable           |

Convention: use `interface` for public object/class shapes (especially in libraries), `type` for unions, tuples, mapped types, function signatures, and aliases.

---

### Q7. Declaration merging.

**Answer:**
Multiple `interface` declarations with the same name combine:

```ts
interface Window { myApp: { version: string } }
// later, in another file
interface Window { myApp: { build: number } }
// merged: window.myApp must have both
```

Used to augment third-party types (`declare module 'express' { interface Request { user?: User } }`).

---

### Q8. Intersection vs union.

**Answer:**

```ts
type Admin = { role: 'admin'; canDelete: true };
type User  = { role: 'user'; canEdit: true };

type Either = Admin | User;     // is one OR the other
type Both   = Admin & User;     // must satisfy BOTH (rarely useful for discriminated unions)
```

Intersections of conflicting primitives produce `never`.

---

## Generics

### Q9. What are generics?

**Answer:**
Type parameters — placeholders that let a function/class/type work over a range of types while preserving the relationship.

```ts
function identity<T>(x: T): T { return x; }
identity('hi'); // T inferred as 'hi' (literal) or string
identity<number>(42);
```

Without generics you'd lose type info: `(x: any) => any` returns `any`.

---

### Q10. Generic constraints.

**Answer:**
`extends` narrows what types are allowed:

```ts
function pluck<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}
pluck({ a: 1, b: 'x' }, 'a'); // number
pluck({ a: 1 }, 'b' as any);  // would be type error without 'as any'
```

---

### Q11. Default generic parameters.

**Answer:**

```ts
interface ApiResponse<T = unknown> { data: T; status: number }
const r: ApiResponse = { data: 'anything', status: 200 };
```

Common in React: `useState<string>('')` vs `useState<string | null>(null)`.

---

### Q12. What does `T extends U ? X : Y` mean?

**Answer:**
A **conditional type**. Picks `X` if `T` is assignable to `U`, otherwise `Y`.

```ts
type IsString<T> = T extends string ? true : false;
type A = IsString<'hi'>; // true
type B = IsString<42>;   // false
```

When `T` is a union, conditionals **distribute** over the union members:

```ts
type ToArray<T> = T extends any ? T[] : never;
type X = ToArray<string | number>; // string[] | number[]
```

Wrap in `[T]` to disable distribution: `[T] extends [any] ? ...`.

---

### Q13. The `infer` keyword.

**Answer:**
Lets you extract a type from a position inside a conditional:

```ts
type ReturnT<F> = F extends (...a: any) => infer R ? R : never;
type R = ReturnT<() => string>; // string

type First<T> = T extends [infer F, ...any[]] ? F : never;
type F = First<[1, 2, 3]>; // 1

type Awaited2<T> = T extends Promise<infer U> ? U : T;
```

Powers most utility types.

---

### Q14. Generics in classes vs functions vs types.

**Answer:**

```ts
class Box<T> { constructor(public value: T) {} }
function wrap<T>(v: T): Box<T> { return new Box(v); }
type Pair<A, B> = [A, B];
```

Class generics persist for the instance lifetime; function generics are inferred per call.

---

## Utility Types

### Q15. What are the most-used utility types?

**Answer:**

| Utility            | Purpose                                  |
|--------------------|------------------------------------------|
| `Partial<T>`       | all properties optional                  |
| `Required<T>`      | all properties required                  |
| `Readonly<T>`      | all properties readonly                  |
| `Pick<T, K>`       | keep only keys K                         |
| `Omit<T, K>`       | remove keys K                            |
| `Record<K, V>`     | dict type with keys K and values V       |
| `Exclude<T, U>`    | remove from union T anything assignable to U |
| `Extract<T, U>`    | keep only union members assignable to U  |
| `NonNullable<T>`   | remove null and undefined                |
| `ReturnType<F>`    | return type of function F                |
| `Parameters<F>`    | parameter tuple of F                     |
| `ConstructorParameters<C>` | parameter tuple of constructor   |
| `InstanceType<C>`  | instance type produced by constructor    |
| `Awaited<T>`       | recursively unwrap Promise               |
| `ThisParameterType<F>` / `OmitThisParameter<F>` | `this` introspection |

---

### Q16. Implement `Partial<T>` from scratch.

**Answer:**

```ts
type MyPartial<T> = { [K in keyof T]?: T[K] };
```

Mapped type with `?` modifier.

---

### Q17. Implement `Pick` and `Omit`.

**Answer:**

```ts
type MyPick<T, K extends keyof T> = { [P in K]: T[P] };
type MyOmit<T, K extends keyof any> = MyPick<T, Exclude<keyof T, K>>;
```

Note `K extends keyof any` (i.e., `string | number | symbol`) on `Omit` so you can pass keys that may not exist — the official `Omit` is intentionally lax.

---

### Q18. `Record<K, V>` — what is it?

**Answer:**

```ts
type Roles = Record<'admin' | 'user', { perms: string[] }>;
// equivalent to: { admin: {...}; user: {...} }

type Dict = Record<string, number>; // string-indexed
```

For dictionary types, prefer `Record<string, V>` over `{ [k: string]: V }` — they are similar but `Record` reads more clearly.

---

### Q19. `ReturnType` and `Parameters`.

**Answer:**

```ts
function getUser(id: string, opts?: Options) { return { name: 'Ada' }; }
type User = ReturnType<typeof getUser>;     // { name: string }
type Args = Parameters<typeof getUser>;     // [id: string, opts?: Options]
```

`typeof` lifts a runtime value into a type. Combined with these utilities, you avoid duplicating signatures.

---

### Q20. `Awaited<T>`.

**Answer:**
Recursively unwraps promises:

```ts
type A = Awaited<Promise<Promise<string>>>; // string
async function load() { return 1; }
type R = Awaited<ReturnType<typeof load>>;   // number
```

Use it instead of hand-rolling `T extends Promise<infer U> ? U : T` since deeper nesting is now common.

---

## Conditional and Mapped Types

### Q21. Mapped types.

**Answer:**
Iterate over keys of a type to produce a new type:

```ts
type Stringify<T> = { [K in keyof T]: string };
type Optional<T> = { [K in keyof T]?: T[K] };
type Mutable<T>  = { -readonly [K in keyof T]: T[K] };
```

Modifiers `?` and `readonly` can be added or removed (`-?`, `-readonly`).

---

### Q22. Key remapping with `as`.

**Answer:**

```ts
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K]
};

type G = Getters<{ name: string; age: number }>;
// { getName: () => string; getAge: () => number }
```

Combines mapped types with template literal types — extremely powerful for API code generation.

---

### Q23. Template literal types.

**Answer:**

```ts
type Greeting = `hello ${string}`;
const g: Greeting = 'hello world'; // ok
const g2: Greeting = 'hi';         // error

type HttpRoute = `/${string}`;
type EventName<T extends string> = `on${Capitalize<T>}`;
type E = EventName<'click'>; // 'onClick'
```

Built-in helpers: `Uppercase`, `Lowercase`, `Capitalize`, `Uncapitalize`.

---

### Q24. Distributive conditionals — what are they good for?

**Answer:**

```ts
type NonString<T> = T extends string ? never : T;
type R = NonString<string | number | boolean>; // number | boolean
```

When `T` is a generic union, `T extends X ? A : B` distributes over each member. To stop distribution wrap in a tuple:

```ts
type IsUnion<T, U = T> = T extends any ? ([U] extends [T] ? false : true) : never;
```

---

### Q25. Recursive types.

**Answer:**

```ts
type Json = string | number | boolean | null | Json[] | { [k: string]: Json };

type DeepReadonly<T> = {
  readonly [K in keyof T]: T[K] extends object ? DeepReadonly<T[K]> : T[K]
};
```

TypeScript supports tail recursion in conditionals up to a depth limit (~50 deep, more with the recursive instantiation tricks).

---

## Type Narrowing and Guards

### Q26. What is type narrowing?

**Answer:**
The compiler refines a variable's type based on control flow. Methods:

- `typeof x === 'string'`
- `x instanceof Klass`
- `'prop' in obj`
- equality with literal: `x === 'a'`
- truthiness: `if (x)`
- discriminated union check
- user-defined type guards
- `Array.isArray`

```ts
function f(x: string | number) {
  if (typeof x === 'string') x.toUpperCase(); // narrowed to string
  else x.toFixed(2);                          // narrowed to number
}
```

---

### Q27. User-defined type guards.

**Answer:**

```ts
interface Cat { meow(): void; }
interface Dog { bark(): void; }

function isCat(a: Cat | Dog): a is Cat {
  return (a as Cat).meow !== undefined;
}

function speak(a: Cat | Dog) {
  if (isCat(a)) a.meow();
  else a.bark();
}
```

`a is Cat` is the **predicate**. Beware: TS trusts you — a wrong implementation creates a runtime hazard.

---

### Q28. Discriminated unions.

**Answer:**

```ts
type Shape =
  | { kind: 'circle'; radius: number }
  | { kind: 'square'; size: number }
  | { kind: 'rect'; w: number; h: number };

function area(s: Shape) {
  switch (s.kind) {
    case 'circle': return Math.PI * s.radius ** 2;
    case 'square': return s.size ** 2;
    case 'rect':   return s.w * s.h;
  }
}
```

The `kind` discriminator lets the compiler narrow each branch. The most reliable pattern in TS for modeling sum types.

---

### Q29. Exhaustiveness checking.

**Answer:**
Use `never` to assert all cases are handled:

```ts
function area(s: Shape) {
  switch (s.kind) {
    case 'circle': return ...;
    case 'square': return ...;
    case 'rect':   return ...;
    default: const _: never = s; throw new Error('unhandled');
  }
}
```

If a new `Shape` variant is added, the assignment to `never` fails — the compiler tells you exactly where to add a case.

---

### Q30. `unknown` requires narrowing.

**Answer:**

```ts
function load(input: unknown) {
  // input.toString();           // error
  if (typeof input === 'string') input.length; // ok
}
```

Always prefer `unknown` over `any` for I/O boundaries (JSON, query params, errors in `catch`).

---

### Q31. The `catch` clause type.

**Answer:**
Errors are typed `unknown` (with `useUnknownInCatchVariables`, default in strict). Narrow before using:

```ts
try { ... } catch (e) {
  if (e instanceof Error) console.log(e.message);
  else console.log('unknown error', e);
}
```

---

## Advanced Patterns

### Q32. `satisfies` operator.

**Answer:**
Validates a value matches a type without widening it.

```ts
type Colors = Record<string, [number, number, number]>;

const palette = {
  red: [255, 0, 0],
  green: [0, 255, 0],
} satisfies Colors;

palette.red[0];  // number — preserves the literal tuple type
// const palette: Colors = {...};   // would lose tuple-ness
```

Use when you want **type-checking** but **don't want widening** to the declared type.

---

### Q33. `as const`.

**Answer:**
Tells TS to treat a literal as deeply readonly with literal types:

```ts
const colors = ['red', 'green'] as const;
type Color = typeof colors[number]; // 'red' | 'green'
```

Foundational technique for deriving literal unions from runtime data.

---

### Q34. `keyof`, `typeof`, and lookup types.

**Answer:**

```ts
const config = { host: 'x', port: 1 };
type Config = typeof config;            // { host: string; port: number }
type Key = keyof Config;                // 'host' | 'port'
type V = Config['port'];                // number
type Vs = Config[keyof Config];         // string | number
```

---

### Q35. Function overloads.

**Answer:**

```ts
function parse(input: string): object;
function parse(input: object): string;
function parse(input: any): any {
  return typeof input === 'string' ? JSON.parse(input) : JSON.stringify(input);
}
```

Overload signatures appear before the implementation. Callers see only the overloads. Modern TS often prefers conditional types over overloads:

```ts
type ParseResult<T> = T extends string ? object : string;
function parse<T extends string | object>(input: T): ParseResult<T> { ... }
```

---

### Q36. Decorators.

**Answer:**
TS 5+ ships **stage-3 decorators** by default; legacy `experimentalDecorators` is what most NestJS / TypeORM code still requires.

```ts
function logged<T extends Function>(fn: T, ctx: ClassMethodDecoratorContext) {
  return function (this: any, ...args: any[]) {
    console.log('call', ctx.name);
    return (fn as any).apply(this, args);
  };
}

class Service {
  @logged
  doThing() {}
}
```

When working with frameworks, match their flavor — mixing legacy and stage-3 won't work.

---

### Q37. Declaration files (`.d.ts`).

**Answer:**
Pure type information, no runtime code. Used to:

- ship types alongside JS libraries.
- describe ambient globals (`declare const __VERSION__: string;`).
- augment third-party modules.

```ts
// types/express.d.ts
declare module 'express' {
  interface Request { user?: { id: string } }
}
```

---

### Q38. Namespaces.

**Answer:**
Older module-like construct. Largely deprecated for application code in favor of ES modules. Still seen in `.d.ts` files (e.g., `declare namespace NodeJS`).

---

### Q39. Function `this` typing.

**Answer:**

```ts
interface Account { balance: number; }
function deposit(this: Account, amt: number) { this.balance += amt; }
```

The `this` parameter is purely for typing — it disappears at runtime. Useful for typing event handlers and methods detached from objects.

---

### Q40. Variadic tuple types.

**Answer:**

```ts
type Concat<A extends any[], B extends any[]> = [...A, ...B];
type C = Concat<[1, 2], [3, 4]>; // [1, 2, 3, 4]

function curry<A extends any[], B extends any[], R>(
  fn: (...args: [...A, ...B]) => R,
  ...partial: A
): (...rest: B) => R {
  return (...rest) => fn(...partial, ...rest);
}
```

Powerful for typing function composition, currying, and middleware pipelines.

---

### Q41. Readonly arrays and tuples.

**Answer:**

```ts
function sum(nums: readonly number[]) { return nums.reduce((a, b) => a + b, 0); }
const xs = [1, 2, 3] as const;       // readonly [1, 2, 3]
sum(xs);                              // ok — readonly array assignable
```

Prefer `readonly T[]` for parameter types — the function won't mutate, callers can pass either.

---

### Q42. Branded / nominal types.

**Answer:**
Simulate nominal typing for stricter IDs/units:

```ts
type Brand<T, B> = T & { readonly __brand: B };
type UserId = Brand<string, 'UserId'>;
type OrderId = Brand<string, 'OrderId'>;

function getUser(id: UserId) {}
const raw: string = '123';
// getUser(raw);                  // error
const id = raw as UserId;
getUser(id);                      // ok

const o: OrderId = '99' as OrderId;
// getUser(o);                    // error — different brand
```

No runtime cost — purely compile-time guard against mixing semantically different strings.

---

## Tooling and tsconfig

### Q43. Most important `tsconfig.json` flags.

**Answer:**

| Flag                              | Purpose |
|-----------------------------------|---------|
| `strict`                          | enables all strict checks |
| `noImplicitAny`                   | error on implicit any |
| `strictNullChecks`                | null/undefined separated from base types |
| `strictFunctionTypes`             | contravariant param checks |
| `strictPropertyInitialization`    | class fields must be initialized |
| `noUncheckedIndexedAccess`        | `arr[i]` is `T \| undefined` |
| `exactOptionalPropertyTypes`      | distinguishes `x?: number` from `x: number \| undefined` |
| `noImplicitOverride`              | require `override` keyword |
| `noFallthroughCasesInSwitch`      | catch missing breaks |
| `isolatedModules`                 | each file independently transpilable (Babel/swc) |
| `target` / `module`               | output JS version and module format |
| `moduleResolution`                | `bundler` for modern projects |
| `paths` / `baseUrl`               | path aliases |
| `incremental` / `composite`       | project references for monorepos |

`strict: true` is non-negotiable on new projects.

---

### Q44. `noUncheckedIndexedAccess` — what changes?

**Answer:**

```ts
const arr = [1, 2, 3];
const x = arr[0];   // without flag: number
                    // with flag:    number | undefined
```

A massive runtime bug preventer. Especially valuable when iterating optional config maps, but adds friction (you must narrow). Worth turning on incrementally.

---

### Q45. `verbatimModuleSyntax`.

**Answer:**
Forces explicit `import type` for types, simplifying the relationship between TS imports and emitted JS — important for ESM, bundlers, and libraries shipping `.js` files.

```ts
import type { User } from './types';   // erased at compile time
import { fetchUser } from './api';
```

---

### Q46. Project references.

**Answer:**
For monorepos and large codebases. `composite: true` plus `references` lets TS build subprojects independently and incrementally:

```json
{ "references": [{ "path": "../shared" }] }
```

Build with `tsc -b`. Improves cold and incremental build times significantly.

---

### Q47. `tsc` vs Babel/swc/esbuild.

**Answer:**
- `tsc` — type-checks AND transpiles. Slowest, most accurate.
- Babel / swc / esbuild — strip types only (no checking). Fast.

Common pattern: bundler strips types for speed; `tsc --noEmit` runs in CI for type checking. Requires `isolatedModules: true`.

---

## Pitfalls and Real-World

### Q48. The "types are erased" gap.

**Answer:**
Types disappear at runtime. You cannot:

- `if (x instanceof MyType)` for an `interface` (no runtime form).
- inspect type arguments at runtime.
- runtime-validate JSON against a TS type.

Solutions: schema validators (`zod`, `valibot`, `typebox`) that produce both a TS type and a runtime validator from one source.

```ts
const User = z.object({ name: z.string(), age: z.number() });
type User = z.infer<typeof User>;
const u = User.parse(json); // runtime check, typed
```

---

### Q49. Why does this assignment fail?

```ts
let nums: number[] = [];
let things: (number | string)[] = nums; // error
```

**Answer:**
Arrays are mutably **invariant** — assigning would let someone push a string into your number array via the alias. Use `readonly` for covariant safety:

```ts
let things: readonly (number | string)[] = nums; // ok
```

---

### Q50. `interface Foo { (x: number): string }` — what is this?

**Answer:**
A callable interface — describes a function:

```ts
interface Greeter { (name: string): string; lang: string; }
const g: Greeter = Object.assign((n: string) => `hi ${n}`, { lang: 'en' });
g('Ada'); g.lang;
```

Useful when a function value also has properties.

---

### Q51. React + TS — typing children and props.

**Answer:**

```ts
import { PropsWithChildren, ReactNode, FC } from 'react';

type Props = { title: string };
const Card: FC<PropsWithChildren<Props>> = ({ title, children }) => ...;

// or explicitly:
function Card({ title, children }: Props & { children?: ReactNode }) { ... }
```

Avoid `React.FC` if you don't need its implicit `children` (modern guidance is mixed; team consistency wins).

Event handlers:

```ts
const onChange = (e: React.ChangeEvent<HTMLInputElement>) => e.target.value;
```

---

### Q52. Node + TS pitfalls.

**Answer:**
- `@types/node` mismatched with the runtime version → missing globals or wrong APIs.
- Mixing CJS and ESM — set `"type": "module"`, use `.mjs`/`.cjs` strategically, or use a bundler.
- `__dirname` and `__filename` are absent in ESM — use `import.meta.url` and `fileURLToPath`.
- `process.env.X` is `string | undefined` (with `noUncheckedIndexedAccess`); validate at startup.

---

### Q53. Why use `as` cautiously?

**Answer:**
Type assertions tell TS "trust me." They suppress checking and can desync types from reality:

```ts
const u = JSON.parse(s) as User; // no runtime check — User-shaped lie possible
```

Prefer:
- type guards
- `satisfies` where possible
- runtime schemas (zod) at I/O boundaries

`as unknown as X` is the "double cast" smell — always investigate.

---

### Q54. Why does this object have unexpected extra properties allowed?

```ts
interface Point { x: number; y: number }
function move(p: Point) {}
const obj = { x: 1, y: 2, z: 3 };
move(obj); // ok — excess property check only on object literals
```

**Answer:**
Excess property checking applies only to **fresh object literals** at the call site. Aliasing the literal first bypasses it. This is intentional — TS uses structural compatibility once you're past the literal boundary.

---

### Q55. How to type a function that returns the type of another's input?

**Answer:**

```ts
function passthrough<T>(value: T): T { return value; }

// Identity-like patterns are common in middleware libraries:
type Middleware<Req> = (req: Req) => Req;
```

`typeof someFn` plus `Parameters` / `ReturnType` covers most introspection needs.

---

### Q56. `Required<T>` vs `NonNullable<T[K]>`.

**Answer:**
- `Required<T>` removes `?` modifier from all keys.
- `NonNullable<T>` removes `null | undefined` from a type.

```ts
interface U { name?: string | null }
type R1 = Required<U>;            // { name: string | null }
type R2 = { name: NonNullable<U['name']> }; // { name: string }
```

Easy to confuse — pick the right one based on whether you're attacking optional-ness or nullability.

---
