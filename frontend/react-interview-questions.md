# React Interview Questions — Complete Q&A Guide

**Focus:** React 18+, Hooks, performance, patterns, testing, and advanced features.

This guide is written to teach. Read each answer, understand the idea, then look at the code to see how the concept works in real code. Each question is self-contained so you can revise quickly.

---

## 1. Core Concepts

## Q1. What is React?

**Answer:**

React is a JavaScript library for building user interfaces. Instead of manually updating the DOM when data changes, you describe what the UI should look like for a given state, and React figures out the minimum changes needed to update the real DOM.

The core idea is that the UI is a function of state: `UI = f(state)`. When the state changes, React re-runs the function and updates the screen.

```jsx
function Greeting({ name }) {
  return <h1>Hello, {name}!</h1>;
}

// Render once
<Greeting name="Iqbal" />
// React updates the DOM whenever the prop changes
```

## Q2. What is the virtual DOM?

**Answer:**

The virtual DOM is a lightweight JavaScript object that represents the real DOM. When state changes, React builds a new virtual DOM tree, compares it with the previous one (a process called diffing), and only applies the differences to the real DOM. This is faster than touching the real DOM directly.

```jsx
// You write JSX
const element = <h1>Hello</h1>;

// React converts it into a virtual DOM node like:
// { type: 'h1', props: { children: 'Hello' } }
```

## Q3. What is JSX?

**Answer:**

JSX is a syntax extension for JavaScript that looks like HTML. It is not understood by the browser directly. Babel transpiles it into `React.createElement()` calls.

```jsx
// You write
const el = <h1 className="title">Hello</h1>;

// Babel converts to
const el = React.createElement('h1', { className: 'title' }, 'Hello');
```

JSX uses `className` instead of `class` and `htmlFor` instead of `for` because `class` and `for` are reserved words in JavaScript.

## Q4. Functional vs class components?

**Answer:**

A functional component is a plain JavaScript function that returns JSX. A class component is an ES6 class extending `React.Component`. Modern React strongly prefers functional components with hooks because they are shorter, easier to reuse logic with, and avoid the confusion of `this`.

```jsx
// Functional
function Hello({ name }) {
  return <h1>Hello {name}</h1>;
}

// Class (older style)
class Hello extends React.Component {
  render() {
    return <h1>Hello {this.props.name}</h1>;
  }
}
```

## Q5. What are props?

**Answer:**

Props (short for properties) are inputs passed from a parent component to a child. They are read-only inside the child — never mutate them.

```jsx
function Button({ label, onClick }) {
  return <button onClick={onClick}>{label}</button>;
}

<Button label="Save" onClick={() => alert('Saved')} />
```

## Q6. What is state?

**Answer:**

State is data owned and managed by a component. When state changes, the component re-renders. Use the `useState` hook to declare state.

```jsx
import { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(count + 1)}>{count}</button>;
}
```

## Q7. What causes a React component to re-render?

**Answer:**

A component re-renders when:

1. Its state changes (via a setter function).
2. Its props change.
3. Its parent re-renders.
4. A context value it consumes changes.

A re-render does not always mean the DOM is updated; React still diffs and only changes what is different.

```jsx
function Parent() {
  const [n, setN] = useState(0);
  // Every click re-renders Parent and Child
  return (
    <>
      <button onClick={() => setN(n + 1)}>{n}</button>
      <Child />
    </>
  );
}
```

## Q8. What is reconciliation?

**Answer:**

Reconciliation is React's algorithm for diffing the new virtual DOM with the previous one to figure out what changed. It compares element types and `key` props to decide whether to update, replace, or remove a DOM node.

If the type matches, React updates the existing node. If the type differs, React unmounts the old subtree and mounts a new one.

## Q9. What is a fragment?

**Answer:**

A fragment lets you return multiple elements from a component without adding an extra wrapper element to the DOM.

```jsx
function Row() {
  return (
    <>
      <td>Name</td>
      <td>Email</td>
    </>
  );
}
```

The shorthand `<>...</>` is the most common form. Use `<React.Fragment key={id}>` when you need a key.

## Q10. Difference between controlled and uncontrolled components?

**Answer:**

A controlled component stores form input value in React state — React is the single source of truth. An uncontrolled component lets the DOM keep the value, and you read it via a ref when needed.

```jsx
// Controlled
function Controlled() {
  const [name, setName] = useState('');
  return <input value={name} onChange={e => setName(e.target.value)} />;
}

// Uncontrolled
function Uncontrolled() {
  const ref = useRef();
  return (
    <>
      <input ref={ref} defaultValue="John" />
      <button onClick={() => alert(ref.current.value)}>Show</button>
    </>
  );
}
```

Controlled is preferred for validation and dynamic UI. Uncontrolled is fine for simple forms or integrating with non-React code.

---

## 2. Hooks

## Q11. What are the rules of hooks?

**Answer:**

1. Only call hooks at the top level of a component or another hook. Never inside loops, conditions, or nested functions.
2. Only call hooks from React functions (components or custom hooks), not regular functions.

These rules exist because React relies on the call order of hooks to associate state with the right component instance.

```jsx
// Wrong
function Bad({ show }) {
  if (show) {
    const [x, setX] = useState(0); // breaks call order
  }
}

// Correct
function Good({ show }) {
  const [x, setX] = useState(0);
  if (!show) return null;
  return <div>{x}</div>;
}
```

## Q12. Explain `useState`.

**Answer:**

`useState` declares a piece of state. It returns the current value and a setter function. Calling the setter triggers a re-render.

```jsx
const [count, setCount] = useState(0);

// Use functional updates when the new value depends on the previous one
setCount(prev => prev + 1);
```

The functional form (`prev => prev + 1`) avoids stale-closure bugs in async code.

## Q13. Explain `useEffect`.

**Answer:**

`useEffect` runs side effects after the component renders. Side effects are things like data fetching, subscriptions, timers, or manually changing the DOM.

The second argument is a dependency array. The effect re-runs when any dependency changes. If the array is empty `[]`, it runs only once on mount.

```jsx
useEffect(() => {
  const id = setInterval(() => console.log('tick'), 1000);
  return () => clearInterval(id); // cleanup on unmount or before re-running
}, []);
```

## Q14. Explain `useRef`.

**Answer:**

`useRef` creates a mutable container whose `.current` value persists across renders without causing a re-render when changed. It is used for two main things:

1. Holding a reference to a DOM element.
2. Storing a mutable value that you do not want to trigger a render (like an interval ID).

```jsx
function FocusInput() {
  const inputRef = useRef(null);
  useEffect(() => inputRef.current.focus(), []);
  return <input ref={inputRef} />;
}
```

## Q15. Explain `useMemo`.

**Answer:**

`useMemo` memoizes the result of an expensive calculation. The function only re-runs when one of its dependencies changes.

Use it when a computation is genuinely expensive, not for every value.

```jsx
const expensiveValue = useMemo(() => {
  return items.filter(i => i.active).map(i => i.price).reduce((a, b) => a + b, 0);
}, [items]);
```

## Q16. Explain `useCallback`.

**Answer:**

`useCallback` returns a memoized version of a callback that only changes when its dependencies change. It is useful when passing callbacks to child components wrapped in `React.memo`, so that the child does not re-render unnecessarily.

```jsx
const handleClick = useCallback(() => {
  console.log('clicked', id);
}, [id]);

<MemoChild onClick={handleClick} />
```

## Q17. What is `useContext`?

**Answer:**

`useContext` reads a value from a context. Context lets you share data across many components without passing props at every level.

```jsx
const ThemeContext = createContext('light');

function App() {
  return (
    <ThemeContext.Provider value="dark">
      <Toolbar />
    </ThemeContext.Provider>
  );
}

function Toolbar() {
  const theme = useContext(ThemeContext);
  return <div className={theme}>Toolbar</div>;
}
```

## Q18. What is `useReducer`?

**Answer:**

`useReducer` is an alternative to `useState` for managing complex state. You define a reducer function that takes the current state and an action, and returns the next state. It is similar to Redux but local to a component.

```jsx
function reducer(state, action) {
  switch (action.type) {
    case 'inc': return { count: state.count + 1 };
    case 'dec': return { count: state.count - 1 };
    default: return state;
  }
}

function Counter() {
  const [state, dispatch] = useReducer(reducer, { count: 0 });
  return (
    <>
      <button onClick={() => dispatch({ type: 'dec' })}>-</button>
      <span>{state.count}</span>
      <button onClick={() => dispatch({ type: 'inc' })}>+</button>
    </>
  );
}
```

## Q19. How do you create a custom hook?

**Answer:**

A custom hook is a JavaScript function whose name starts with `use` and which can call other hooks. It lets you extract reusable logic.

```jsx
function useLocalStorage(key, initial) {
  const [value, setValue] = useState(() => {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : initial;
  });

  useEffect(() => {
    localStorage.setItem(key, JSON.stringify(value));
  }, [key, value]);

  return [value, setValue];
}

// Usage
const [name, setName] = useLocalStorage('name', '');
```

## Q20. What is `useLayoutEffect`?

**Answer:**

`useLayoutEffect` runs synchronously after the DOM is updated but before the browser paints. Use it when you need to read layout from the DOM and synchronously re-render to avoid a visual flicker. For most side effects, `useEffect` is better because it does not block painting.

```jsx
useLayoutEffect(() => {
  const { height } = ref.current.getBoundingClientRect();
  setHeight(height);
}, []);
```

---

## 3. State Management

## Q21. What is prop drilling and how do you solve it?

**Answer:**

Prop drilling means passing props through many intermediate components that do not need them, only to reach a deeply nested child. It clutters code and makes refactoring harder.

Solutions: Context API, state libraries (Zustand, Redux), or component composition.

```jsx
// Drilling: A → B → C → D just to give "user" to D
// Better: provide it via context
const UserContext = createContext(null);

function App({ user }) {
  return (
    <UserContext.Provider value={user}>
      <Layout />
    </UserContext.Provider>
  );
}

function DeepChild() {
  const user = useContext(UserContext);
  return <p>{user.name}</p>;
}
```

## Q22. What is the Context API?

**Answer:**

Context API is React's built-in way to share data globally with a subtree of components. Create a context, wrap children in a Provider, then read with `useContext`.

Be careful: every consumer re-renders whenever the context value changes. Split contexts by concern, and memoize the value object.

```jsx
const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const value = useMemo(() => ({ user, setUser }), [user]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
```

## Q23. When to use Redux vs Context API?

**Answer:**

Use Context for low-frequency global data like theme, locale, or current user. Use Redux (or Zustand, Jotai) for complex state with many updates, async flows, time-travel debugging, and middleware. Redux Toolkit is the modern recommended way.

```jsx
// Redux Toolkit slice
import { createSlice } from '@reduxjs/toolkit';

const counter = createSlice({
  name: 'counter',
  initialState: { value: 0 },
  reducers: {
    inc: state => { state.value += 1; },
    dec: state => { state.value -= 1; },
  },
});

export const { inc, dec } = counter.actions;
export default counter.reducer;
```

## Q24. What is Zustand?

**Answer:**

Zustand is a small, hook-based state library. It avoids the boilerplate of Redux and is easier to learn. State is created in a store, and components subscribe via a hook.

```jsx
import { create } from 'zustand';

const useCounter = create(set => ({
  count: 0,
  inc: () => set(s => ({ count: s.count + 1 })),
}));

function Counter() {
  const { count, inc } = useCounter();
  return <button onClick={inc}>{count}</button>;
}
```

---

## 4. Performance Optimization

## Q25. What is `React.memo`?

**Answer:**

`React.memo` wraps a component and skips re-rendering if its props have not changed (shallow comparison). Use it for pure functional components that receive the same props often.

```jsx
const Row = React.memo(function Row({ item }) {
  return <li>{item.name}</li>;
});

// Re-renders only when "item" changes by reference
```

## Q26. How do you prevent unnecessary re-renders?

**Answer:**

- Wrap pure children in `React.memo`.
- Memoize callbacks with `useCallback` and values with `useMemo` when passing to memoized children.
- Move state down to the smallest component that needs it.
- Split context by concern so unrelated consumers do not re-render together.

```jsx
const Parent = () => {
  const [count, setCount] = useState(0);
  const handleSave = useCallback(() => save(), []);
  return (
    <>
      <button onClick={() => setCount(count + 1)}>{count}</button>
      <ExpensiveChild onSave={handleSave} />
    </>
  );
};
```

## Q27. What is code splitting?

**Answer:**

Code splitting breaks the JavaScript bundle into smaller chunks loaded on demand. React supports this with `React.lazy` and `Suspense`.

```jsx
const Settings = React.lazy(() => import('./Settings'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <Settings />
    </Suspense>
  );
}
```

## Q28. What is virtualization for long lists?

**Answer:**

Virtualization renders only the rows visible in the viewport, even if the list has thousands of items. Libraries like `react-window` or `@tanstack/react-virtual` handle this.

```jsx
import { FixedSizeList } from 'react-window';

<FixedSizeList height={400} itemCount={10000} itemSize={35} width={300}>
  {({ index, style }) => <div style={style}>Row {index}</div>}
</FixedSizeList>
```

---

## 5. Patterns and Architecture

## Q29. What is the compound components pattern?

**Answer:**

Compound components are a group of components that work together to form a coherent UI, sharing implicit state via context. The user composes them flexibly.

```jsx
const TabsContext = createContext();

function Tabs({ children, defaultIndex = 0 }) {
  const [active, setActive] = useState(defaultIndex);
  return (
    <TabsContext.Provider value={{ active, setActive }}>
      <div>{children}</div>
    </TabsContext.Provider>
  );
}

Tabs.Tab = function Tab({ index, children }) {
  const { active, setActive } = useContext(TabsContext);
  return (
    <button onClick={() => setActive(index)} aria-selected={active === index}>
      {children}
    </button>
  );
};

// Usage
<Tabs>
  <Tabs.Tab index={0}>One</Tabs.Tab>
  <Tabs.Tab index={1}>Two</Tabs.Tab>
</Tabs>
```

## Q30. What is the render prop pattern?

**Answer:**

A render prop is a function passed as a prop that returns JSX. The parent decides what to render using data the child provides. Today, custom hooks usually replace render props.

```jsx
function MouseTracker({ render }) {
  const [pos, setPos] = useState({ x: 0, y: 0 });
  useEffect(() => {
    const move = e => setPos({ x: e.clientX, y: e.clientY });
    window.addEventListener('mousemove', move);
    return () => window.removeEventListener('mousemove', move);
  }, []);
  return render(pos);
}

<MouseTracker render={({ x, y }) => <p>{x}, {y}</p>} />
```

## Q31. What is lifting state up?

**Answer:**

When two sibling components need to share state, move the state to their nearest common parent and pass it down via props.

```jsx
function Parent() {
  const [text, setText] = useState('');
  return (
    <>
      <Input value={text} onChange={setText} />
      <Display value={text} />
    </>
  );
}
```

## Q32. What is the children prop?

**Answer:**

`children` is a special prop holding whatever JSX you put between a component's opening and closing tags. It enables flexible composition.

```jsx
function Card({ children }) {
  return <div className="card">{children}</div>;
}

<Card>
  <h2>Title</h2>
  <p>Body</p>
</Card>
```

---

## 6. Forms

## Q33. How do you handle forms in React?

**Answer:**

Bind input values to state with `value` and `onChange`. For larger forms, use a library like React Hook Form to reduce boilerplate and improve performance.

```jsx
function LoginForm() {
  const [form, setForm] = useState({ email: '', password: '' });

  const handleChange = e => {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = e => {
    e.preventDefault();
    console.log(form);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="email" value={form.email} onChange={handleChange} />
      <input name="password" type="password" value={form.password} onChange={handleChange} />
      <button type="submit">Login</button>
    </form>
  );
}
```

## Q34. How do you validate forms?

**Answer:**

For simple forms, validate manually on submit. For complex forms, use React Hook Form with a schema validator like Zod or Yup.

```jsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

function Form() {
  const { register, handleSubmit, formState: { errors } } = useForm({
    resolver: zodResolver(schema),
  });

  return (
    <form onSubmit={handleSubmit(data => console.log(data))}>
      <input {...register('email')} />
      {errors.email && <span>{errors.email.message}</span>}
      <input type="password" {...register('password')} />
      <button>Submit</button>
    </form>
  );
}
```

---

## 7. Testing

## Q35. How do you test React components?

**Answer:**

Use React Testing Library + Jest (or Vitest). The philosophy is to test behavior the user sees, not implementation details.

```jsx
import { render, screen, fireEvent } from '@testing-library/react';
import Counter from './Counter';

test('increments when clicked', () => {
  render(<Counter />);
  const button = screen.getByRole('button');
  fireEvent.click(button);
  expect(button).toHaveTextContent('1');
});
```

## Q36. What is mocking in React tests?

**Answer:**

Mocking replaces a real dependency (like `fetch` or a module) with a stub during tests so you can control its behavior and avoid network calls.

```jsx
import { vi } from 'vitest';

global.fetch = vi.fn(() =>
  Promise.resolve({ json: () => Promise.resolve({ user: 'Iqbal' }) })
);
```

---

## 8. Advanced Topics

## Q37. What are React Server Components?

**Answer:**

Server Components run on the server, never ship JavaScript to the client, and can directly access databases or the filesystem. Client Components run in the browser and can use state, effects, and event handlers. Server Components are async-friendly.

```jsx
// Server Component (no "use client" directive)
export default async function Posts() {
  const posts = await db.posts.findMany();
  return posts.map(p => <article key={p.id}>{p.title}</article>);
}
```

## Q38. What is Concurrent Mode?

**Answer:**

Concurrent rendering lets React prepare multiple versions of the UI at once and interrupt low-priority work to keep the app responsive. Features like `startTransition`, `useDeferredValue`, and Suspense are part of this model.

```jsx
import { startTransition, useState } from 'react';

function Search() {
  const [query, setQuery] = useState('');
  const [list, setList] = useState([]);

  const handleChange = e => {
    setQuery(e.target.value); // urgent
    startTransition(() => {
      setList(filterBigList(e.target.value)); // non-urgent
    });
  };

  return <input value={query} onChange={handleChange} />;
}
```

## Q39. What is Suspense?

**Answer:**

Suspense lets you declaratively wait for something (a code chunk, async data) and show a fallback while waiting.

```jsx
const Profile = lazy(() => import('./Profile'));

<Suspense fallback={<p>Loading...</p>}>
  <Profile />
</Suspense>
```

## Q40. What are error boundaries?

**Answer:**

An error boundary is a class component that catches JavaScript errors in its child tree, logs them, and shows a fallback UI. Hooks cannot create error boundaries yet.

```jsx
class ErrorBoundary extends React.Component {
  state = { hasError: false };
  static getDerivedStateFromError() {
    return { hasError: true };
  }
  componentDidCatch(error, info) {
    console.error(error, info);
  }
  render() {
    if (this.state.hasError) return <p>Something went wrong.</p>;
    return this.props.children;
  }
}

<ErrorBoundary><Dashboard /></ErrorBoundary>
```

## Q41. What is `key` and why does it matter?

**Answer:**

`key` is a special prop React uses to identify items in a list during reconciliation. Without stable keys, React may reuse the wrong DOM node, causing bugs in inputs and animations.

Use a unique stable ID (like a database ID), not array index, when items can be reordered, added, or deleted.

```jsx
{users.map(u => <li key={u.id}>{u.name}</li>)}
```

## Q42. Difference between `useEffect` and `useLayoutEffect`?

**Answer:**

`useEffect` runs after the browser paints. `useLayoutEffect` runs synchronously after DOM updates but before paint, blocking the screen until it finishes. Use `useLayoutEffect` only when you must read layout and immediately re-render to avoid flicker.

## Q43. What is React Strict Mode?

**Answer:**

`<StrictMode>` is a development-only wrapper that intentionally double-invokes certain functions (renders, effects, state initializers) to surface bugs like impure renders or missing cleanup.

```jsx
import { StrictMode } from 'react';

<StrictMode>
  <App />
</StrictMode>
```

It does not affect production behavior.

## Q44. Difference between `React.memo` and `useMemo`?

**Answer:**

`React.memo` memoizes a component (skips re-render if props are the same). `useMemo` memoizes a value inside a component (avoids recomputing).

```jsx
const Heavy = React.memo(Component);          // memoize component
const total = useMemo(() => compute(x), [x]); // memoize value
```

## Q45. How would you handle global error handling?

**Answer:**

Wrap the app in an error boundary for render-time errors, and add a global handler for async errors and unhandled rejections.

```jsx
window.addEventListener('error', e => report(e.error));
window.addEventListener('unhandledrejection', e => report(e.reason));

<ErrorBoundary><App /></ErrorBoundary>
```

## Q46. What is `forwardRef`?

**Answer:**

`forwardRef` lets a component receive a ref from its parent and pass it to a child DOM element. This is useful for libraries that wrap inputs or buttons.

```jsx
const Input = React.forwardRef(function Input(props, ref) {
  return <input ref={ref} {...props} />;
});

function App() {
  const inputRef = useRef();
  return <Input ref={inputRef} />;
}
```

## Q47. What is `useImperativeHandle`?

**Answer:**

`useImperativeHandle` customizes the value exposed when a parent uses a ref on a `forwardRef` component. Use it to expose only specific methods.

```jsx
const Modal = forwardRef(function Modal(_, ref) {
  const [open, setOpen] = useState(false);
  useImperativeHandle(ref, () => ({
    show: () => setOpen(true),
    hide: () => setOpen(false),
  }));
  return open ? <div>Modal</div> : null;
});

const ref = useRef();
ref.current.show();
```

## Q48. What is `useTransition`?

**Answer:**

`useTransition` lets you mark state updates as non-urgent. It returns `[isPending, startTransition]`. Urgent updates (like typing) stay snappy while heavy work happens in the transition.

```jsx
const [isPending, startTransition] = useTransition();

const handleChange = e => {
  setQuery(e.target.value);
  startTransition(() => setResults(slowFilter(e.target.value)));
};
```

## Q49. What is `useDeferredValue`?

**Answer:**

`useDeferredValue` returns a deferred copy of a value that lags behind during fast updates. Use it to keep one part of the UI snappy while a downstream component renders slow content.

```jsx
const deferredQuery = useDeferredValue(query);
return <SlowList query={deferredQuery} />;
```

## Q50. What is the `key` prop trick to reset state?

**Answer:**

Changing the `key` of a component unmounts the old one and mounts a new one with fresh state. This is a clean way to reset.

```jsx
<UserForm key={userId} userId={userId} />
// changing userId remounts the form with new initial state
```

## Q51. Why should setState updates be functional when based on previous state?

**Answer:**

Because React batches updates and the closure may capture a stale value.

```jsx
// Wrong: increments by 1 even with three calls
setCount(count + 1);
setCount(count + 1);
setCount(count + 1);

// Correct: increments by 3
setCount(c => c + 1);
setCount(c => c + 1);
setCount(c => c + 1);
```

## Q52. How do you fetch data in a component?

**Answer:**

For client-side fetching, use `useEffect` plus state for loading and error. For real apps, prefer TanStack Query (React Query) which handles caching, retries, and deduping.

```jsx
function useUser(id) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    let ignore = false;
    fetch(`/api/users/${id}`)
      .then(r => r.json())
      .then(d => { if (!ignore) { setData(d); setLoading(false); } });
    return () => { ignore = true; };
  }, [id]);
  return { data, loading };
}
```

## Q53. What is TanStack Query (React Query)?

**Answer:**

TanStack Query handles server state with caching, background refetching, deduplication, and stale-while-revalidate semantics.

```jsx
import { useQuery } from '@tanstack/react-query';

function User({ id }) {
  const { data, isLoading } = useQuery({
    queryKey: ['user', id],
    queryFn: () => fetch(`/api/users/${id}`).then(r => r.json()),
  });
  if (isLoading) return <p>Loading...</p>;
  return <p>{data.name}</p>;
}
```

## Q54. What is the difference between event handlers in React vs vanilla JS?

**Answer:**

React uses synthetic events — wrappers around the native event for cross-browser consistency. Handlers are camelCased (`onClick` not `onclick`) and pass functions, not strings.

```jsx
<button onClick={e => console.log(e.target)}>Click</button>
```

## Q55. How do you conditionally render in JSX?

**Answer:**

Use ternary, `&&`, or early return.

```jsx
{loading ? <Spinner /> : <Data />}
{error && <Alert>{error}</Alert>}

if (!user) return <Login />;
return <Dashboard />;
```

## Q56. What is the difference between `null`, `undefined`, and `false` in JSX?

**Answer:**

React renders nothing for `null`, `undefined`, `false`, and `true`. Use this to skip rendering.

```jsx
{shouldShow && <Banner />}
```

But beware of numbers: `0 && <X />` renders `0`. Use `Boolean(x) && ...` or `x ? <X /> : null`.

## Q57. How do portals work?

**Answer:**

`createPortal` renders a child into a different DOM node outside the parent's hierarchy. Useful for modals, tooltips, dropdowns.

```jsx
import { createPortal } from 'react-dom';

function Modal({ children }) {
  return createPortal(
    <div className="modal">{children}</div>,
    document.getElementById('modal-root')
  );
}
```

## Q58. How do you handle authentication in a React app?

**Answer:**

Store the auth state (user, token) in context or a state library. Protect routes by redirecting unauthenticated users.

```jsx
function ProtectedRoute({ children }) {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" />;
  return children;
}
```

Tokens are usually stored in `httpOnly` cookies (safer) or in memory. Avoid `localStorage` for sensitive tokens because of XSS risk.

## Q59. How does React Router work?

**Answer:**

React Router maps URLs to components. Define routes, then use `<Link>` for navigation and hooks like `useParams`, `useNavigate` to interact with the router.

```jsx
import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';

<BrowserRouter>
  <Link to="/about">About</Link>
  <Routes>
    <Route path="/" element={<Home />} />
    <Route path="/about" element={<About />} />
    <Route path="/users/:id" element={<User />} />
  </Routes>
</BrowserRouter>
```

## Q60. What are higher-order components (HOCs)?

**Answer:**

A HOC is a function that takes a component and returns a new component with extra behavior. Today most HOC patterns are replaced by hooks, but they still appear in older code.

```jsx
function withLogger(Component) {
  return function Wrapped(props) {
    useEffect(() => console.log('mounted'), []);
    return <Component {...props} />;
  };
}

const LoggedButton = withLogger(Button);
```

## Q61. How do you handle environment variables in React?

**Answer:**

Variables prefixed with `REACT_APP_` (CRA) or `VITE_` (Vite) are exposed to the bundle.

```jsx
// .env
VITE_API_URL=https://api.example.com

// usage
fetch(import.meta.env.VITE_API_URL + '/users');
```

Never store secrets in client env vars — they ship to the browser.

## Q62. How do you debounce input in React?

**Answer:**

Use a custom hook with `setTimeout` and cleanup.

```jsx
function useDebounce(value, delay = 300) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);
  return debounced;
}

function Search() {
  const [q, setQ] = useState('');
  const debounced = useDebounce(q, 400);
  useEffect(() => { if (debounced) fetchResults(debounced); }, [debounced]);
  return <input value={q} onChange={e => setQ(e.target.value)} />;
}
```

## Q63. What is the difference between `key` and `ref`?

**Answer:**

`key` helps React identify list items during reconciliation. `ref` gives you imperative access to a DOM node or stores a mutable value across renders. They serve different purposes.

## Q64. How do you handle file uploads?

**Answer:**

Use a controlled `<input type="file" />` and send the file via `FormData`.

```jsx
function Upload() {
  const handleChange = async e => {
    const file = e.target.files[0];
    const fd = new FormData();
    fd.append('file', file);
    await fetch('/api/upload', { method: 'POST', body: fd });
  };
  return <input type="file" onChange={handleChange} />;
}
```

## Q65. How do you handle accessibility in React?

**Answer:**

- Use semantic HTML (`<button>`, `<nav>`, `<main>`).
- Add labels with `htmlFor` linking to input `id`.
- Manage focus when routes change or modals open.
- Use ARIA only when no semantic element fits.

```jsx
<label htmlFor="email">Email</label>
<input id="email" type="email" />
```

## Q66. How do you optimize images in a React app?

**Answer:**

Use modern formats (WebP, AVIF), lazy loading, and responsive images. In Next.js, use `next/image`. In a plain React app, use the native `loading="lazy"` and `srcSet`.

```jsx
<img
  src="/photo.jpg"
  srcSet="/photo-400.jpg 400w, /photo-800.jpg 800w"
  sizes="(max-width: 600px) 400px, 800px"
  loading="lazy"
  alt="Photo"
/>
```

## Q67. What is the difference between unmounting and conditional rendering?

**Answer:**

When a component is conditionally rendered as `null`, React unmounts it — its state and effects are destroyed. When the same component re-renders with a different prop, its state persists. Mounting is heavier than re-rendering.

## Q68. How do you handle local state vs server state?

**Answer:**

Local state (UI toggles, form inputs) belongs in `useState` or `useReducer`. Server state (data fetched from APIs) is best handled with TanStack Query or SWR — they handle caching, refetching, and synchronization.

## Q69. How do you avoid memory leaks?

**Answer:**

- Clean up subscriptions, timers, and event listeners in `useEffect` return functions.
- Cancel fetch requests with `AbortController` or an `ignore` flag.

```jsx
useEffect(() => {
  const controller = new AbortController();
  fetch('/api/data', { signal: controller.signal });
  return () => controller.abort();
}, []);
```

## Q70. What are React 18's automatic batching changes?

**Answer:**

React 18 batches state updates from any source — event handlers, Promises, timeouts, native callbacks — into a single re-render. In React 17, batching only happened inside React event handlers.

```jsx
// React 18: one re-render
setTimeout(() => {
  setA(1);
  setB(2);
}, 0);
```

If you need to opt out, use `flushSync` from `react-dom`.

---

## 9. Quick Reference

| Hook | Purpose |
| ---- | ------- |
| `useState` | Local state |
| `useEffect` | Side effects after render |
| `useLayoutEffect` | Side effects before paint |
| `useRef` | DOM ref or mutable value |
| `useMemo` | Memoize a value |
| `useCallback` | Memoize a callback |
| `useContext` | Read context |
| `useReducer` | Complex state with a reducer |
| `useTransition` | Mark updates as non-urgent |
| `useDeferredValue` | Lag a value behind |

| Concept | Tool |
| ------- | ---- |
| Server state | TanStack Query, SWR |
| Client state | useState, Zustand, Redux Toolkit |
| Forms | React Hook Form + Zod |
| Routing | React Router, TanStack Router |
| Testing | React Testing Library + Vitest |
