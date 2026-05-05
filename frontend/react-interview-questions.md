# React.js Interview Questions

**Level:** Mid to Senior  
**Topics:** Components, Hooks, State Management, Performance, Patterns, Testing

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Hooks](#hooks)
3. [State Management](#state-management)
4. [Performance Optimization](#performance-optimization)
5. [Patterns and Architecture](#patterns-and-architecture)
6. [Forms](#forms)
7. [Testing](#testing)
8. [Advanced Topics](#advanced-topics)

---

## Core Concepts

### Q1. What is React and why use it?

**Answer:**
React is a JavaScript library for building user interfaces using a component-based architecture and a virtual DOM.

Key benefits:
- reusable components
- efficient DOM updates via virtual DOM diffing
- large ecosystem
- unidirectional data flow
- React Native for mobile

---

### Q2. What is the virtual DOM?

**Answer:**
A lightweight JavaScript copy of the real DOM. React:
1. renders UI to virtual DOM
2. diffs against previous virtual DOM (reconciliation)
3. applies only the minimal real DOM changes

This avoids expensive full DOM re-renders.

---

### Q3. What is JSX?

**Answer:**
JSX is syntax sugar for `React.createElement()`. It lets you write HTML-like syntax in JavaScript.

```jsx
// JSX
const el = <h1 className="title">Hello</h1>;

// Compiles to
const el = React.createElement('h1', { className: 'title' }, 'Hello');
```

JSX requires:
- one root element (or fragment `<>...</>`)
- `className` not `class`
- camelCase event names (`onClick` not `onclick`)

---

### Q4. Functional vs class components?

**Answer:**

| Feature         | Class                   | Functional          |
|----------------|-------------------------|---------------------|
| State           | `this.state`            | `useState`          |
| Lifecycle       | lifecycle methods        | `useEffect`         |
| Code size       | more boilerplate         | concise             |
| `this` context  | required                 | not needed          |

**Modern React:** always use functional components with hooks.

---

### Q5. What are props?

**Answer:**
Props are read-only inputs passed from parent to child. They cannot be modified by the receiving component.

```jsx
function Button({ label, onClick }) {
  return <button onClick={onClick}>{label}</button>;
}
```

---

### Q6. What is state?

**Answer:**
State is mutable data managed inside a component. Changing state triggers a re-render.

```jsx
const [count, setCount] = useState(0);
```

Rules:
- never mutate state directly
- state updates may be batched
- state updates are asynchronous

---

### Q7. What causes a React component to re-render?

**Answer:**
- State change via setter function
- Props change from parent
- Parent component re-renders
- Context value changes
- `forceUpdate` (class components)

---

### Q8. What is reconciliation?

**Answer:**
React's algorithm for comparing the previous virtual DOM tree with the new one and determining the minimal set of real DOM operations needed.

React uses heuristics:
- same component type → update existing instance
- different type → destroy old, create new
- lists use `key` to match items

---

### Q9. What is a fragment?

**Answer:**
A wrapper that lets you group elements without adding an extra DOM node.

```jsx
return (
  <>
    <h1>Title</h1>
    <p>Content</p>
  </>
);
```

---

### Q10. What is the difference between controlled and uncontrolled components?

**Answer:**

**Controlled:** React state drives the input value.
```jsx
<input value={email} onChange={(e) => setEmail(e.target.value)} />
```

**Uncontrolled:** DOM manages the value via `ref`.
```jsx
const inputRef = useRef();
<input ref={inputRef} />
// Access: inputRef.current.value
```

Controlled components are preferred — easier to validate and test.

---

## Hooks

### Q11. What are the rules of hooks?

**Answer:**
1. Only call hooks at the top level (not inside loops, conditions, or nested functions)
2. Only call hooks from React function components or custom hooks

These rules ensure hooks maintain consistent call order across renders.

---

### Q12. Explain `useState`.

**Answer:**
Declares state in a functional component. Returns current value and setter.

```jsx
const [count, setCount] = useState(0);

// Functional update (safe when new state depends on old)
setCount(prev => prev + 1);
```

---

### Q13. Explain `useEffect`.

**Answer:**
Runs side effects after render. Replaces `componentDidMount`, `componentDidUpdate`, `componentWillUnmount`.

```jsx
useEffect(() => {
  // runs after render
  const sub = subscribe(id);
  
  return () => {
    // cleanup on unmount or before next effect
    sub.unsubscribe();
  };
}, [id]); // dependency array
```

| Dependency Array | Behavior |
|-----------------|----------|
| omitted | runs after every render |
| `[]` | runs once after mount |
| `[dep1, dep2]` | runs when deps change |

---

### Q14. Explain `useRef`.

**Answer:**
Returns a mutable ref object whose `.current` property persists across renders without triggering re-renders.

Two main uses:
1. Access DOM nodes directly
2. Store mutable values that don't affect rendering

```jsx
const inputRef = useRef(null);
inputRef.current.focus();

// Storing previous value
const prevCount = useRef(count);
useEffect(() => { prevCount.current = count; });
```

---

### Q15. Explain `useMemo`.

**Answer:**
Memoizes an expensive computed value. Only recalculates when dependencies change.

```jsx
const sortedList = useMemo(() => {
  return [...items].sort((a, b) => a.price - b.price);
}, [items]);
```

Use when computation is expensive (filtering, sorting large arrays). Do not overuse — memoization itself has overhead.

---

### Q16. Explain `useCallback`.

**Answer:**
Memoizes a function reference. Prevents creating a new function on every render.

```jsx
const handleSubmit = useCallback((data) => {
  saveData(data);
}, [saveData]);
```

Use when passing callbacks to optimized child components (`React.memo`) to prevent unnecessary re-renders.

---

### Q17. What is `useContext`?

**Answer:**
Reads and subscribes to a context value. Alternative to prop drilling.

```jsx
const theme = useContext(ThemeContext);
```

The component re-renders when the context value changes.

---

### Q18. What is `useReducer`?

**Answer:**
Alternative to `useState` for complex state logic.

```jsx
function reducer(state, action) {
  switch (action.type) {
    case 'increment': return { count: state.count + 1 };
    default: return state;
  }
}

const [state, dispatch] = useReducer(reducer, { count: 0 });
dispatch({ type: 'increment' });
```

Use when:
- next state depends on complex logic
- multiple sub-values in state
- shared patterns with Redux

---

### Q19. How do you create a custom hook?

**Answer:**
A custom hook is a function that starts with `use` and can call other hooks.

```jsx
function useFetch(url) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(url)
      .then(r => r.json())
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, [url]);

  return { data, loading, error };
}
```

---

### Q20. What is `useLayoutEffect`?

**Answer:**
Like `useEffect` but fires synchronously after all DOM mutations, before the browser paints. Use for reading layout (scroll position, element size) and synchronous DOM updates to prevent visual flicker.

**Prefer `useEffect`** unless you have a measurable reason to block painting.

---

## State Management

### Q21. What is prop drilling and how to solve it?

**Answer:**
Prop drilling is passing props through intermediate components that don't need them just to reach a deeply nested child.

Solutions:
- **Context API** — for global/shared state
- **Zustand / Redux** — for complex app-wide state
- **Component composition** — restructure to avoid deep passing

---

### Q22. What is the Context API?

**Answer:**
Built-in mechanism for sharing data globally without passing props at every level.

```jsx
const UserContext = createContext(null);

// Provider
<UserContext.Provider value={{ user, logout }}>
  <App />
</UserContext.Provider>

// Consumer
const { user } = useContext(UserContext);
```

Limitation: all consumers re-render when context value changes. Split contexts by update frequency to optimize.

---

### Q23. When to use Redux vs Context API?

**Answer:**

| Context API | Redux |
|-------------|-------|
| Simple global state | Complex state with many actions |
| Low update frequency | High update frequency |
| Small apps | Large apps with many features |
| No middleware needed | Middleware (thunk, saga) required |
| Built-in | External dependency |

---

### Q24. What is Zustand?

**Answer:**
Lightweight state management library. Uses hooks. Minimal boilerplate compared to Redux.

```jsx
const useStore = create((set) => ({
  count: 0,
  increment: () => set(state => ({ count: state.count + 1 })),
}));

const count = useStore(state => state.count);
```

---

## Performance Optimization

### Q25. What is `React.memo`?

**Answer:**
Higher-order component that prevents re-rendering if props haven't changed (shallow comparison).

```jsx
const Button = React.memo(({ onClick, label }) => {
  return <button onClick={onClick}>{label}</button>;
});
```

Only useful when:
- parent re-renders frequently
- component renders are expensive
- props are stable (use `useCallback` for function props)

---

### Q26. How do you prevent unnecessary re-renders?

**Answer:**
- `React.memo` for components
- `useMemo` for computed values
- `useCallback` for event handlers
- Avoid inline object/array props (new reference each render)
- Split context into smaller contexts
- Use keys properly in lists
- Lazy load heavy components

---

### Q27. What is code splitting?

**Answer:**
Breaking the JS bundle into smaller chunks that load on demand.

```jsx
const Dashboard = lazy(() => import('./Dashboard'));

<Suspense fallback={<Spinner />}>
  <Dashboard />
</Suspense>
```

Reduces initial bundle size and load time.

---

### Q28. What is virtualization for long lists?

**Answer:**
Only render visible items in a large list. Off-screen items are not in the DOM.

Libraries: `react-window`, `react-virtual`, `TanStack Virtual`

```jsx
import { FixedSizeList } from 'react-window';

<FixedSizeList height={400} itemCount={10000} itemSize={35}>
  {({ index, style }) => <div style={style}>Row {index}</div>}
</FixedSizeList>
```

---

## Patterns and Architecture

### Q29. What is the compound components pattern?

**Answer:**
A pattern where a parent component shares implicit state with child components using context.

```jsx
<Select>
  <Select.Trigger />
  <Select.Options>
    <Select.Option value="1">Option 1</Select.Option>
  </Select.Options>
</Select>
```

Used in component libraries for flexible APIs.

---

### Q30. What is the render prop pattern?

**Answer:**
A component accepts a function as a prop and calls it to render content. Shares stateful logic.

```jsx
<Mouse render={({ x, y }) => <Cursor x={x} y={y} />} />
```

Now largely replaced by custom hooks, which are cleaner.

---

### Q31. What is lifting state up?

**Answer:**
Moving state to the nearest common ancestor of all components that need it, then passing it down as props.

Use when sibling components need to share or sync state.

---

### Q32. What is the children prop?

**Answer:**
Lets components receive and render arbitrary JSX passed between their tags.

```jsx
function Card({ children }) {
  return <div className="card">{children}</div>;
}

<Card>
  <h2>Title</h2>
  <p>Content</p>
</Card>
```

---

## Forms

### Q33. How do you handle forms in React?

**Answer:**

**With controlled inputs:**
```jsx
const [form, setForm] = useState({ email: '', password: '' });

const handleChange = (e) => {
  setForm(prev => ({ ...prev, [e.target.name]: e.target.value }));
};

<input name="email" value={form.email} onChange={handleChange} />
```

**With React Hook Form (recommended for complex forms):**
```jsx
const { register, handleSubmit, formState: { errors } } = useForm();

<input {...register('email', { required: true })} />
```

---

### Q34. How do you validate forms?

**Answer:**

Options:
- Built-in HTML validation (`required`, `minLength`, `pattern`)
- Manual validation in submit handler
- **React Hook Form** + **Zod** or **Yup** for schema-based validation

```jsx
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});
```

---

## Testing

### Q35. How do you test React components?

**Answer:**

Tools: **Vitest** or **Jest** + **React Testing Library**

```jsx
import { render, screen, fireEvent } from '@testing-library/react';

test('button increments count', () => {
  render(<Counter />);
  fireEvent.click(screen.getByRole('button'));
  expect(screen.getByText('Count: 1')).toBeInTheDocument();
});
```

Testing Library philosophy: test behavior, not implementation.

---

### Q36. What is mocking in React tests?

**Answer:**
Replacing real implementations (API calls, modules) with controlled substitutes.

```jsx
jest.mock('../api', () => ({
  fetchUser: jest.fn().mockResolvedValue({ name: 'Test' }),
}));
```

---

## Advanced Topics

### Q37. What are React Server Components?

**Answer:**
Components that render only on the server. They:
- have zero JS bundle contribution
- can directly access databases, file system
- cannot use hooks or browser APIs
- work alongside Client Components

Available in Next.js App Router. Default components are Server Components.

---

### Q38. What is Concurrent Mode?

**Answer:**
React can work on multiple versions of the UI simultaneously. Key features:
- `useTransition` — mark updates as non-urgent
- `useDeferredValue` — defer re-rendering an expensive part
- `Suspense` — declaratively handle async loading states

```jsx
const [isPending, startTransition] = useTransition();

startTransition(() => {
  setSearchQuery(value); // non-urgent update
});
```

---

### Q39. What is Suspense?

**Answer:**
Lets components "wait" for async data before rendering, showing a fallback in the meantime.

```jsx
<Suspense fallback={<Loading />}>
  <DataComponent /> {/* throws a promise while loading */}
</Suspense>
```

Used with `lazy()`, React Server Components, and data fetching libraries (SWR, TanStack Query).

---

### Q40. What are error boundaries?

**Answer:**
Class components that catch JavaScript errors in their child tree, log them, and display a fallback UI.

```jsx
class ErrorBoundary extends Component {
  state = { hasError: false };
  
  static getDerivedStateFromError() {
    return { hasError: true };
  }
  
  render() {
    if (this.state.hasError) return <h1>Something went wrong.</h1>;
    return this.props.children;
  }
}
```

Functional error boundaries via `react-error-boundary` library.

---

### Q41. What is key and why does it matter?

**Answer:**
Key helps React identify which list items changed, were added, or removed.

```jsx
{items.map(item => <Item key={item.id} {...item} />)}
```

Rules:
- Must be unique among siblings
- Use stable, unique IDs (not array index if order can change)
- Changing a key destroys the old instance and creates a new one — useful for resetting component state

---

### Q42. What is the difference between `useEffect` and `useLayoutEffect`?

**Answer:**

| `useEffect` | `useLayoutEffect` |
|-------------|-------------------|
| Async, fires after browser paint | Sync, fires before browser paint |
| Safe for most side effects | Use for DOM reads/writes that affect layout |
| Does not block visual update | Can cause visual delay if misused |

---

### Q43. What is React strict mode?

**Answer:**
Development-only mode that helps find issues by:
- double-invoking render functions, state initializers, and effects
- warning about deprecated APIs
- detecting unexpected side effects

```jsx
<React.StrictMode>
  <App />
</React.StrictMode>
```

Does not affect production builds.

---

### Q44. What is the difference between `React.memo` and `useMemo`?

**Answer:**

| `React.memo` | `useMemo` |
|-------------|-----------|
| Memoizes a component | Memoizes a computed value |
| Prevents re-render if props unchanged | Prevents recomputation if deps unchanged |
| Wraps the component | Used inside a component |

---

### Q45. How would you handle global error handling in React?

**Answer:**
- Use error boundaries at appropriate levels (route level, feature level)
- Combine with `react-error-boundary` library for hooks support
- Log errors to a monitoring service (Sentry, Datadog)
- Show user-friendly fallback UIs
- Use `window.onerror` and `unhandledRejection` for non-component errors

---

## Quick Reference

| Hook | Purpose |
|------|---------|
| `useState` | Local component state |
| `useEffect` | Side effects after render |
| `useRef` | DOM access or mutable value |
| `useMemo` | Memoize expensive computation |
| `useCallback` | Memoize function reference |
| `useContext` | Consume context |
| `useReducer` | Complex state logic |
| `useLayoutEffect` | DOM measurements before paint |
| `useTransition` | Mark non-urgent state updates |
| `useDeferredValue` | Defer expensive re-renders |
