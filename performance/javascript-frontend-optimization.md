# JavaScript and Frontend Performance Optimization — Interview Q&A Guide

This guide covers Core Web Vitals, bundle and code-splitting, tree shaking, the critical rendering path, image and font optimization, React and Vue performance, network and HTTP caching, service workers, measurement tools, and real production patterns.

---

## Web Vitals

## Q1. What are the Core Web Vitals (2024+)?

**Answer:**

| Metric | Measures | Good | Needs work | Poor |
| --- | --- | --- | --- | --- |
| LCP (Largest Contentful Paint) | When main content is visible | <= 2.5s | 2.5-4s | > 4s |
| INP (Interaction to Next Paint) | Responsiveness across all interactions | <= 200ms | 200-500ms | > 500ms |
| CLS (Cumulative Layout Shift) | Visual stability | <= 0.1 | 0.1-0.25 | > 0.25 |
| TTFB (Time to First Byte) | Server response time | <= 0.8s | 0.8-1.8s | > 1.8s |
| FCP (First Contentful Paint) | First visual element | <= 1.8s | 1.8-3s | > 3s |

INP replaced FID in March 2024. Vitals are measured at p75 across users.

## Q2. How do you actually improve LCP?

**Answer:**

LCP is usually a hero image, large heading, or video poster. Quick wins:

```html
<!-- 1. Preload the LCP resource -->
<link rel="preload" as="image" href="/hero.avif" fetchpriority="high">

<!-- 2. Serve a modern format and prioritize loading -->
<img src="/hero.avif" fetchpriority="high" loading="eager"
     width="1200" height="600" alt="...">
```

Other wins:
- Inline critical CSS so painting is not blocked
- Use a CDN with edge caching
- Reduce TTFB on the server
- Remove render-blocking resources before the LCP element

Never lazy-load the LCP image.

## Q3. What causes high INP?

**Answer:**

INP measures the worst interaction across the page session. It is caused by long JS tasks blocking the main thread.

Common causes:

```jsx
// BAD: 500ms blocking work in a click handler
function onClick() {
    const result = bigDataset.map(...).filter(...).sort(...);
    setItems(result);
}
```

Fix with React 18 transitions:

```jsx
import { useTransition } from 'react';

function Search() {
    const [isPending, startTransition] = useTransition();
    function onChange(e) {
        startTransition(() => {
            setItems(filterBigList(e.target.value));
        });
    }
    return <input onChange={onChange} />;
}
```

Other causes:
- Hydration of huge component trees
- Third-party scripts (analytics, A/B tests, chat widgets)
- Synchronous reads of layout properties (e.g., `offsetWidth`) inside handlers

## Q4. What are common causes of CLS?

**Answer:**

```html
<!-- BAD: no dimensions, layout shifts when image loads -->
<img src="/hero.jpg" alt="...">

<!-- GOOD: dimensions reserve the space -->
<img src="/hero.jpg" width="1200" height="600" alt="...">

<!-- Or with CSS -->
<div style="aspect-ratio: 16/9;">
    <img src="/hero.jpg" alt="...">
</div>
```

Other CLS culprits:
- Ads or iframes inserted dynamically
- Web fonts swapping in late
- Above-the-fold content shifting when JS hydrates
- Animations using `top`/`left` instead of `transform`

```css
/* Avoid font swap shift */
@font-face {
    font-family: 'Inter';
    src: url('/inter.woff2') format('woff2');
    font-display: optional;
    size-adjust: 100%;
}
```

## Q5. RUM vs synthetic measurement?

**Answer:**

| | RUM (Real User Monitoring) | Synthetic (Lighthouse, WebPageTest) |
| --- | --- | --- |
| Source | Real user devices | Controlled lab |
| Variability | High | Low |
| Coverage | All scenarios | Configured ones |
| Use | Production health | Pre-deploy regression check |

Use both. RUM via the `web-vitals` JS library or APM tools (Datadog, Sentry, SpeedCurve). Synthetic in CI catches regressions before they ship.

---

## Bundle Optimization

## Q6. How big should your JS bundle be?

**Answer:**

Rough budgets for the initial bundle (gzipped):

| Size | Verdict |
| --- | --- |
| < 100 KB | Great |
| 100-250 KB | Acceptable |
| 250-500 KB | Likely too much, split |
| > 500 KB | Problematic on mobile 4G |

A 1 MB bundle takes 3-5 seconds just to parse and execute on a mid-range Android.

## Q7. What tools analyze your bundle?

**Answer:**

```bash
# Webpack
npm install --save-dev webpack-bundle-analyzer

# Rollup / Vite
npm install --save-dev rollup-plugin-visualizer

# Any source-mapped output
npx source-map-explorer dist/assets/*.js

# Next.js
npm install --save-dev @next/bundle-analyzer
```

In Vite:

```js
// vite.config.js
import { visualizer } from 'rollup-plugin-visualizer';

export default {
    plugins: [visualizer({ open: true, filename: 'stats.html' })],
};
```

Look for: duplicate libraries, heavy dependencies, source maps shipped to production, unnecessary polyfills.

## Q8. What are common bundle bloat culprits?

**Answer:**

| Library | Size (min+gz) | Replace with |
| --- | --- | --- |
| moment | ~70 KB | date-fns (~20 KB tree-shaken), dayjs (~7 KB) |
| lodash (full) | ~25 KB | per-method imports or es-toolkit |
| chart.js (full) | ~80 KB | tree-shaken charts or lightweight (visx, uplot) |
| framer-motion | ~50 KB | CSS animations or motion-one |
| @fortawesome (full) | ~150 KB | tree-shake or lucide / heroicons |
| draft.js / quill | 100+ KB | tiptap (composable) |

## Q9. How do you import lodash correctly?

**Answer:**

```js
// BAD: pulls all of lodash
import _ from 'lodash';
_.debounce(fn, 200);

// GOOD: only imports debounce
import debounce from 'lodash/debounce';

// BEST: tree-shakeable ES modules
import { debounce } from 'lodash-es';
```

Even better, use a smaller alternative like `es-toolkit` which has the same API as lodash but ships less code.

---

## Code Splitting

## Q10. How do you do route-based code splitting?

**Answer:**

React with React Router:

```jsx
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));

<Suspense fallback={<Spinner />}>
    <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
    </Routes>
</Suspense>
```

Vue Router:

```js
const routes = [
    { path: '/dashboard', component: () => import('./pages/Dashboard.vue') },
    { path: '/settings', component: () => import('./pages/Settings.vue') },
];
```

Each route becomes its own chunk and only loads when navigated.

## Q11. How do you split heavy components?

**Answer:**

```jsx
import { lazy, Suspense, useState } from 'react';

const HeavyChart = lazy(() => import('./HeavyChart'));

function Page() {
    const [show, setShow] = useState(false);
    return (
        <>
            <button onClick={() => setShow(true)}>Show chart</button>
            {show && (
                <Suspense fallback={<Loader />}>
                    <HeavyChart />
                </Suspense>
            )}
        </>
    );
}
```

Useful for charts, modals, rich text editors, and video players.

## Q12. What are the differences between prefetch and preload for code splitting?

**Answer:**

```js
// Webpack magic comments
const Modal = lazy(() => import(
    /* webpackPrefetch: true */ './Modal'
));

const Editor = lazy(() => import(
    /* webpackPreload: true */ './Editor'
));
```

- `prefetch`: load when the browser is idle, uses `<link rel="prefetch">`
- `preload`: load now in parallel, uses `<link rel="preload">`

Vite uses native ES modules and emits `<link rel="modulepreload">` automatically for routed chunks.

## Q13. Where should you draw the split lines?

**Answer:**

| Split point | Why | When |
| --- | --- | --- |
| Per route | Most users hit only some routes | Always |
| Authenticated vs public | Big difference in features | If significant |
| Per heavy widget | Used by some users | When > 30 KB |
| Vendor split | Stable code caches longer | Default |
| Per locale | Do not ship all translations | i18n apps |

Do not over-split: every chunk is HTTP overhead. Aim for 20-100 KB per chunk on HTTP/2+.

---

## Tree Shaking

## Q14. What is tree shaking and what breaks it?

**Answer:**

Tree shaking removes unused exports during bundling. Requires:

- ES modules (`import`/`export`, not CommonJS `require`)
- `"sideEffects": false` in `package.json` (or an array of files with side effects)
- Production mode with a minifier (Terser, esbuild)

Things that break tree shaking:
- CommonJS modules
- Dynamic property access (`Object.keys(lib).forEach(...)`)
- Side-effect imports (`import 'polyfill'`)
- Re-exports through barrel files
- TypeScript `enum` (use const enum or `as const` objects)

```json
// package.json — declare you have no side effects
{
    "name": "my-lib",
    "sideEffects": false
}
```

## Q15. Why are barrel files (`index.ts`) a performance trap?

**Answer:**

```ts
// components/index.ts
export * from './Button';
export * from './Modal';
export * from './HeavyChart';
```

```ts
// Some bundler/library combos pull everything
import { Button } from './components';   // may include HeavyChart!
```

Even modern bundlers can struggle with barrel files when re-exports have any side effects. The result: importing `Button` may pull `HeavyChart`'s 200 KB.

Fix:

```ts
// Direct import bypasses the barrel
import { Button } from './components/Button';
```

Or mark `"sideEffects": false` in your package and ensure barrel files are pure pass-throughs.

## Q16. What is the right polyfill strategy?

**Answer:**

Do not ship polyfills to modern browsers.

```js
// vite.config.js — emit modern + legacy bundles
import legacy from '@vitejs/plugin-legacy';

export default {
    plugins: [legacy({ targets: ['defaults', 'not IE 11'] })],
};
```

The HTML gets:

```html
<script type="module" src="/assets/index.js"></script>
<script nomodule src="/assets/polyfills.js"></script>
```

Modern browsers ignore `nomodule`; legacy browsers ignore `type="module"`. Most sites only need ESnext output today; legacy share is below 1 percent. Check `caniuse.com` and your analytics — you may not need any polyfills.

---

## Critical Rendering Path

## Q17. What is the critical rendering path?

**Answer:**

The browser steps to render a page:

1. HTML parsed to DOM tree
2. CSS parsed to CSSOM tree
3. DOM + CSSOM combined into the render tree
4. Layout (geometry)
5. Paint (pixels)
6. Composite (layers)

Render-blocking resources: CSS by default, and JS in `<head>` without `defer` or `async`.

## Q18. What is the difference between `defer`, `async`, and module scripts?

**Answer:**

```html
<!-- Blocks HTML parsing -->
<script src="x.js"></script>

<!-- Downloads in parallel, runs ASAP, may block parsing -->
<script async src="analytics.js"></script>

<!-- Downloads in parallel, runs after parse, in document order -->
<script defer src="app.js"></script>

<!-- Module scripts defer by default -->
<script type="module" src="app.js"></script>
```

Use `defer` for app scripts, `async` for analytics that can run any time.

## Q19. What is critical CSS and how do you use it?

**Answer:**

Inline the CSS needed for above-the-fold content; load the rest async.

```html
<style>
    /* Critical above-the-fold styles inline */
    body { font-family: system-ui; margin: 0; }
    header { background: #111; color: white; padding: 1rem; }
</style>

<!-- Load rest async -->
<link rel="preload" href="/css/main.css" as="style"
      onload="this.rel='stylesheet'">
<noscript><link rel="stylesheet" href="/css/main.css"></noscript>
```

Tools: `critters` (used by Next.js), the `critical` npm package, `penthouse`. For Tailwind, the JIT compiler already produces minimal CSS, so critical extraction is less needed.

## Q20. How do you avoid layout shifts during page load?

**Answer:**

```html
<!-- Reserve image space -->
<img src="/hero.webp" width="1200" height="600" alt="">

<!-- Or with aspect-ratio -->
<div style="aspect-ratio: 16/9;"></div>
```

```css
@font-face {
    font-family: 'Inter';
    src: url('/inter.woff2') format('woff2');
    font-display: swap;
    size-adjust: 100%;
}
```

`font-display: optional` skips the swap if the font is not ready in 100ms — eliminates layout shift but may show fallback for first visit.

---

## Image Optimization

## Q21. What are the modern image formats?

**Answer:**

| Format | Compression | Browser support | Use |
| --- | --- | --- | --- |
| JPEG | Old-school lossy | Universal | Fallback |
| PNG | Lossless | Universal | UI graphics, transparency |
| WebP | 25-35% smaller than JPEG | All modern | Default |
| AVIF | 50% smaller than JPEG | 95%+ modern | Future default |
| SVG | Vector | Universal | Icons, logos |

Serve via `<picture>`:

```html
<picture>
    <source srcset="/hero.avif" type="image/avif">
    <source srcset="/hero.webp" type="image/webp">
    <img src="/hero.jpg" width="1200" height="600" alt="...">
</picture>
```

## Q22. How do responsive images work with `srcset`?

**Answer:**

```html
<img
    src="/hero-800.jpg"
    srcset="
        /hero-400.jpg 400w,
        /hero-800.jpg 800w,
        /hero-1600.jpg 1600w"
    sizes="(max-width: 600px) 100vw, 800px"
    alt="..."
    width="800" height="600"
    loading="lazy"
    decoding="async">
```

The browser picks the right size based on viewport and DPR, saving 50-80 percent of bytes on small screens.

## Q23. How do you lazy-load images?

**Answer:**

Native:

```html
<img src="/photo.jpg" loading="lazy" width="800" height="600" alt="...">
<iframe src="..." loading="lazy"></iframe>
```

Browsers load when the image is near the viewport. Never lazy-load the LCP image.

For more control, use `IntersectionObserver`:

```js
const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
        if (entry.isIntersecting) {
            const img = entry.target;
            img.src = img.dataset.src;
            observer.unobserve(img);
        }
    });
}, { rootMargin: '200px' });

document.querySelectorAll('img[data-src]').forEach((img) => {
    observer.observe(img);
});
```

## Q24. What does an image CDN do?

**Answer:**

Examples: Cloudflare Images, Cloudinary, imgix, Vercel/Next.js Image, Bunny Optimizer.

Benefits:
- On-the-fly resize, format conversion, quality
- Auto WebP/AVIF based on the `Accept` header
- Edge caching globally

Workflow: upload an original, then reference with transforms in the URL:

```
https://cdn.example.com/img/hero.jpg?w=800&fm=avif&q=75
```

## Q25. How do you use a blur placeholder?

**Answer:**

Show a tiny blurred preview while the full image loads.

```jsx
// Next.js
<Image
    src="/hero.jpg"
    placeholder="blur"
    blurDataURL={base64Preview}
    alt="..."
    width={1200}
    height={600}
/>
```

The placeholder is a 10-20 byte data URI of a tiny version, base64-encoded. Tools: `plaiceholder`, `sharp`.

---

## Font Optimization

## Q26. What is a good font loading strategy?

**Answer:**

```html
<!-- Preload the critical font -->
<link rel="preload" href="/fonts/inter.woff2"
      as="font" type="font/woff2" crossorigin>
```

```css
@font-face {
    font-family: 'Inter';
    src: url('/fonts/inter.woff2') format('woff2');
    font-display: swap;
    font-weight: 100 900;   /* variable font: one file, all weights */
}
```

- Self-host rather than Google Fonts (faster, no third-party request, GDPR friendly)
- Preload critical fonts (those used above the fold)
- woff2 is always smallest; ignore woff and ttf for modern web
- Variable fonts ship one file for all weights (Inter, Roboto Flex)
- Subset to only the characters you use

## Q27. What do the `font-display` values do?

**Answer:**

| Value | Behavior |
| --- | --- |
| auto | Browser default (usually `block`) |
| block | Hide text up to 3s waiting for font, then swap |
| swap | Show fallback immediately, swap when ready (FOUT) |
| fallback | Brief block, then fallback, swap if loaded under 3s |
| optional | Show fallback, never swap if not in 100ms — best for CLS |

Most sites: `swap`. For premium typography where the wrong font is worse than late, use `optional` with preload.

## Q28. How do you subset a font?

**Answer:**

A typical Inter font is ~150 KB; the Latin subset is ~20 KB.

```bash
# Install fonttools
pip install fonttools brotli

# Subset to Latin range
pyftsubset Inter.ttf \
    --unicodes="U+0020-007F" \
    --output-file=Inter-subset.woff2 \
    --flavor=woff2
```

Other tools: `glyphhanger`, online subsetters.

---

## React Performance

## Q29. When does `React.memo` actually help?

**Answer:**

`React.memo` skips re-render if props are shallowly equal.

```jsx
const ExpensiveList = React.memo(function ExpensiveList({ items }) {
    return items.map((item) => <Row key={item.id} item={item} />);
});
```

Helps when:
- The component is expensive to render
- The parent re-renders frequently with stable props
- Props are primitives or stable references

Does not help when:
- The component is cheap (the comparison costs more than the render)
- Props change every render (object literals, inline functions)
- Children change

Profile first. Indiscriminate memoization actually slows things down.

## Q30. When should you use `useMemo` and `useCallback`?

**Answer:**

```jsx
// Genuinely expensive computation
const sorted = useMemo(
    () => bigList.sort(byPriority),
    [bigList]
);

// Stabilize a reference passed to a memoized child
const onSelect = useCallback(
    (id) => setSelectedId(id),
    []
);
```

Use them for:
- Expensive computations (sorting, filtering huge lists)
- Stabilizing references passed to memoized children
- Stabilizing dependencies of `useEffect`

Do not use them for trivial computations. The hook overhead can cost more than the work.

## Q31. What is the cost of lifting state too high?

**Answer:**

```jsx
// BAD: every keystroke re-renders HugeTree
function App() {
    const [search, setSearch] = useState('');
    return (
        <>
            <SearchInput value={search} onChange={setSearch} />
            <HugeTree />
        </>
    );
}
```

```jsx
// GOOD: state stays close to where it is used
function App() {
    return (
        <>
            <Search />
            <HugeTree />
        </>
    );
}

function Search() {
    const [search, setSearch] = useState('');
    return <input value={search} onChange={(e) => setSearch(e.target.value)} />;
}
```

If state must be shared, use context but split contexts so unrelated changes do not trigger re-renders.

## Q32. How does context splitting help?

**Answer:**

```jsx
// BAD: one context with everything — every consumer re-renders on any change
const AppContext = createContext({ user: null, theme: null, settings: {} });

// GOOD: split by update frequency
const UserContext = createContext(null);       // changes on login
const ThemeContext = createContext('light');   // changes rarely
const SettingsContext = createContext({});     // changes rarely
```

Or use external state libraries (Zustand, Jotai, Redux Toolkit) which only re-render subscribers to changed slices.

## Q33. How do you virtualize a long list?

**Answer:**

Rendering 10k DOM nodes is expensive. Render only the visible rows.

```jsx
import { useVirtualizer } from '@tanstack/react-virtual';

function List({ items }) {
    const parentRef = useRef(null);
    const virtualizer = useVirtualizer({
        count: items.length,
        getScrollElement: () => parentRef.current,
        estimateSize: () => 50,
    });

    return (
        <div ref={parentRef} style={{ height: 600, overflow: 'auto' }}>
            <div style={{ height: virtualizer.getTotalSize() }}>
                {virtualizer.getVirtualItems().map((row) => (
                    <div
                        key={row.key}
                        style={{
                            position: 'absolute',
                            top: row.start,
                            height: row.size,
                        }}
                    >
                        {items[row.index].name}
                    </div>
                ))}
            </div>
        </div>
    );
}
```

Reduces 10k rows to about 30 visible — 5 second render becomes 50 ms.

Other libraries: `react-window` (small, simple), `react-virtuoso` (variable heights, infinite loading).

## Q34. What do `useTransition` and `useDeferredValue` do?

**Answer:**

```jsx
import { useState, useTransition } from 'react';

function Search() {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [isPending, startTransition] = useTransition();

    function onChange(e) {
        setQuery(e.target.value);   // urgent update
        startTransition(() => {
            setResults(filterBigList(e.target.value));   // non-urgent
        });
    }

    return (
        <>
            <input value={query} onChange={onChange} />
            {isPending && <Spinner />}
            <Results items={results} />
        </>
    );
}
```

The urgent input update happens immediately; the expensive filter runs in a transition that can be interrupted by further input. `useDeferredValue` does similar: lags the value, so heavy renders use the older value while a newer one is being computed.

Massive INP improvements on filter and search UIs.

## Q35. How does Suspense for data fetching work?

**Answer:**

With server components or libraries like `@tanstack/react-query` (`suspense: true`), Suspense provides declarative loading states and enables streaming.

```jsx
<Suspense fallback={<Spinner />}>
    <UserProfile id={id} />
</Suspense>
```

Combine with `startTransition` for non-blocking updates. In Next.js App Router, Suspense boundaries enable streaming SSR.

## Q36. What are React Server Components?

**Answer:**

Components that render on the server and ship no JS to the client. Only the interactive client components are hydrated.

```jsx
// page.tsx (server component)
async function Page() {
    const user = await fetchUser();           // runs on server
    return <UserProfile user={user} />;
}

// UserProfile.tsx is a client component if interactive
'use client';
function UserProfile({ user }) {
    const [open, setOpen] = useState(false);
    return <button onClick={() => setOpen(true)}>{user.name}</button>;
}
```

Big wins for pages with mostly static content and small interactive bits. Used by Next.js App Router and Remix.

## Q37. What does `why-did-you-render` do?

**Answer:**

```js
import whyDidYouRender from '@welldone-software/why-did-you-render';
import React from 'react';

if (process.env.NODE_ENV === 'development') {
    whyDidYouRender(React, { trackAllPureComponents: true });
}
```

Logs which props changed, helping you find unnecessary re-renders.

## Q38. How do you avoid inline functions and objects in props?

**Answer:**

```jsx
// BAD: new object every render breaks memoization on Component
<Component config={{ a: 1, b: 2 }} onClick={() => doThing()} />

// GOOD: stable references
const config = useMemo(() => ({ a: 1, b: 2 }), []);
const onClick = useCallback(() => doThing(), []);
<Component config={config} onClick={onClick} />
```

Only matters if `Component` is memoized. Do not chase inline functions without a reason.

---

## Vue Performance

## Q39. When should you use `shallowRef` vs `ref`?

**Answer:**

```js
import { ref, shallowRef } from 'vue';

const big = ref(hugeObject);          // deep reactivity, slow
const big = shallowRef(hugeObject);   // only reacts on assignment
```

Use `shallowRef` or `shallowReactive` for large data structures or third-party objects you do not mutate (chart instances, maps, etc.).

## Q40. What do `v-once` and `v-memo` do?

**Answer:**

```vue
<!-- Render once and never update -->
<header v-once>{{ siteTitle }}</header>

<!-- Re-render only if items[i].updatedAt changes -->
<div v-for="item in items" :key="item.id"
     v-memo="[item.id, item.updatedAt]">
    {{ item.name }}
</div>
```

`v-memo` is great for huge lists where most items do not change between updates.

## Q41. When should you use `computed`?

**Answer:**

```js
import { computed } from 'vue';

const filtered = computed(() => items.value.filter((i) => i.active));
```

`computed` re-evaluates only when its reactive dependencies change. Cached otherwise. Strongly preferred over methods for derived state.

## Q42. How do you use async components in Vue?

**Answer:**

```js
import { defineAsyncComponent } from 'vue';

const HeavyChart = defineAsyncComponent(() => import('./HeavyChart.vue'));

// With loading, error, and timeout
const Comp = defineAsyncComponent({
    loader: () => import('./HeavyChart.vue'),
    loadingComponent: Loader,
    errorComponent: ErrorView,
    delay: 200,
    timeout: 10000,
});
```

## Q43. What does `KeepAlive` do?

**Answer:**

```vue
<router-view v-slot="{ Component }">
    <KeepAlive :max="10">
        <component :is="Component" />
    </KeepAlive>
</router-view>
```

Caches inactive components instead of unmounting them. Great for tabbed UIs and back navigation. Watch memory with the `:max` cap.

## Q44. Why is the list `key` strategy important?

**Answer:**

```vue
<!-- BAD: index as key breaks reconciliation when list reorders -->
<div v-for="(item, i) in items" :key="i">{{ item.name }}</div>

<!-- GOOD: stable id key -->
<div v-for="item in items" :key="item.id">{{ item.name }}</div>
```

When the list reorders, an index-based key makes Vue reuse the wrong DOM nodes, causing visual bugs and unnecessary work.

## Q45. What are common Vue 3 reactivity gotchas?

**Answer:**

```js
import { reactive, toRefs } from 'vue';

const state = reactive({ count: 0 });

// BAD: destructuring loses reactivity
let { count } = state;   // count is no longer reactive

// GOOD: toRefs preserves reactivity
const { count } = toRefs(state);
```

For collections with hundreds of thousands of items, use `markRaw()` or `shallowReactive()` to skip deep tracking.

---

## Network and Caching

## Q46. HTTP/1.1 vs HTTP/2 vs HTTP/3?

**Answer:**

| Feature | HTTP/1.1 | HTTP/2 | HTTP/3 (QUIC) |
| --- | --- | --- | --- |
| Multiplexing | No | Yes | Yes |
| Header compression | No | HPACK | QPACK |
| Transport | TCP | TCP | UDP |
| TLS | Optional | Required in browsers | Built-in |
| Connection setup | 2-3 RTT | 2-3 RTT | 0-1 RTT |

HTTP/2 makes domain sharding harmful (it was a workaround for HTTP/1 connection limits). HTTP/3 helps lossy connections (mobile) — losing a packet does not stall the whole connection.

## Q47. Compression — gzip vs Brotli?

**Answer:**

| Method | Compression | CPU cost | Browser support |
| --- | --- | --- | --- |
| gzip | Baseline | Low | Universal |
| Brotli | 15-25% better than gzip | Higher | All modern browsers |
| Zstd | Similar to Brotli, faster | Low | Limited |

Pre-compress static assets at build time:

```bash
brotli -k -11 dist/**/*.{js,css,html,svg}
gzip -9 dist/**/*.{js,css,html,svg}
```

Nginx serves precompressed files automatically with `gzip_static` and `brotli_static`:

```nginx
gzip_static on;
brotli_static on;
```

## Q48. How should you set Cache-Control headers?

**Answer:**

```
# Hashed assets — cache forever
Cache-Control: public, max-age=31536000, immutable

# HTML, frequently updated
Cache-Control: public, max-age=300, s-maxage=3600

# Personalized
Cache-Control: private, no-cache

# Secrets
Cache-Control: no-store
```

- `max-age` controls browser cache
- `s-maxage` controls CDN or shared cache
- `immutable` promises content never changes (skip revalidation)
- `stale-while-revalidate=N` serves stale up to N seconds while revalidating in background

## Q49. What do `preconnect`, `dns-prefetch`, `preload`, and `prefetch` do?

**Answer:**

```html
<!-- Resolve DNS early -->
<link rel="dns-prefetch" href="https://api.example.com">

<!-- Open TCP+TLS connection early -->
<link rel="preconnect" href="https://api.example.com" crossorigin>

<!-- Fetch resource now (high priority) -->
<link rel="preload" href="/hero.jpg" as="image" fetchpriority="high">

<!-- Hint browser may need this later (low priority) -->
<link rel="prefetch" href="/next-page.js">

<!-- Module preload (ES modules) -->
<link rel="modulepreload" href="/app.js">
```

Use `preconnect` for cross-origin assets you will definitely fetch.

## Q50. What is a good CDN strategy?

**Answer:**

For static assets (JS, CSS, images, fonts):
- Long cache (`max-age=31536000, immutable`) on hashed filenames
- CDN with global PoPs (Cloudflare, Fastly, CloudFront, Vercel)
- HTTP/3 enabled
- Origin shield to reduce origin load

For HTML pages:
- Short CDN cache plus `stale-while-revalidate`
- Or edge SSR (Vercel Edge Functions, Cloudflare Workers) for personalization

---

## Service Workers

## Q51. What does a service worker do?

**Answer:**

A worker that intercepts network requests, can cache and serve offline.

```js
// sw.js
self.addEventListener('install', (e) => {
    e.waitUntil(
        caches.open('v1').then((cache) =>
            cache.addAll(['/', '/app.js', '/style.css'])
        )
    );
});

self.addEventListener('fetch', (e) => {
    e.respondWith(
        caches.match(e.request).then((res) => res || fetch(e.request))
    );
});
```

Tools: Workbox abstracts strategies (cache-first, network-first, stale-while-revalidate, network-only).

## Q52. What are the service worker pitfalls?

**Answer:**

- Stuck on old version: clients keep the SW alive, deploys can take days to propagate. Use `skipWaiting()` plus `clientsClaim()` to force update.
- Caching `index.html` aggressively breaks deploys.
- Cache size limits vary by browser (around 50 MB is safe).
- Difficult to debug; use `chrome://inspect/#service-workers`.

For most apps, just CDN plus HTTP cache is simpler.

---

## Measurement

## Q53. How do you use Lighthouse well?

**Answer:**

```bash
# Local
npx lighthouse https://example.com --view --preset=desktop

# CI
npx lhci autorun --upload.target=temporary-public-storage
```

Lighthouse runs synthetic tests with simulated 4G mobile or fast desktop. CPU is throttled 4x by default, closer to real users. Interpret with care:
- Performance score is a weighted blend of LCP, INP (Total Blocking Time as proxy), and CLS
- Budget your metrics in `lighthouserc.js`
- Fail PRs that regress

## Q54. What is WebPageTest?

**Answer:**

More detail than Lighthouse: filmstrip, waterfall per location, multiple runs, real Chrome on real devices. Free tier at webpagetest.org. Run from multiple geographies to see regional variance.

## Q55. How do you use Chrome DevTools Performance panel?

**Answer:**

Record a session, look for:
- Long tasks (red triangles) — anything over 50 ms blocks INP
- Forced reflows / layout thrashing
- Layer compositing issues
- JS profiling — which functions consumed time
- Coverage tab — find unused JS and CSS

## Q56. How do you use the Web Vitals JS library?

**Answer:**

```js
import { onLCP, onINP, onCLS, onTTFB } from 'web-vitals';

function sendToAnalytics(metric) {
    navigator.sendBeacon('/analytics', JSON.stringify(metric));
}

onLCP(sendToAnalytics);
onINP(sendToAnalytics);
onCLS(sendToAnalytics);
onTTFB(sendToAnalytics);
```

Sends real measurements to your analytics. Combine with the attribution build for diagnostic info on which element or script caused the bad metric.

## Q57. How do you set performance budgets?

**Answer:**

```js
// lighthouserc.js
module.exports = {
    ci: {
        assert: {
            assertions: {
                'categories:performance': ['error', { minScore: 0.9 }],
                'first-contentful-paint': ['warn', { maxNumericValue: 1800 }],
                'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
                'total-blocking-time': ['warn', { maxNumericValue: 300 }],
                'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
            },
        },
    },
};
```

Or budget bundle sizes in the Vite config:

```js
build: {
    chunkSizeWarningLimit: 500,
}
```

---

## Production Patterns

## Q58. How do you fix a slow first page (TTFB 2.5s, LCP 5s)?

**Answer:**

E-commerce product page case study.

Investigation:
- Server: queries fast (200 ms), framework boot 100 ms — TTFB should not be 2.5s
- Found: TLS handshake plus cold start on serverless. Origin in different region from CDN.
- Bundle: 800 KB main chunk, included unused i18n translations for 30 languages
- LCP element: hero carousel image, lazy-loaded by JS framework after hydration

Fixes:

```js
// 1. Code-split i18n by locale
const messages = await import(`./locales/${locale}.json`);
// Bundle: 800 KB -> 180 KB initial
```

```html
<!-- 2. Render hero image as static <img> with preload -->
<link rel="preload" as="image" href="/hero.avif" fetchpriority="high">
<img src="/hero.avif" fetchpriority="high" loading="eager"
     width="1200" height="600" alt="...">
```

3. Move serverless deployment to user's region (Edge Functions).

Result: TTFB 400 ms, LCP 1.6 s.

## Q59. How do you fix a laggy search input?

**Answer:**

Search input with 10k results filter — typing feels laggy. Each keystroke triggers full filter and render of 10k items, blocking the main thread for 600 ms.

```jsx
import { useState, useTransition, useDeferredValue, useMemo } from 'react';

function Search({ items }) {
    const [query, setQuery] = useState('');
    const deferredQuery = useDeferredValue(query);
    const [isPending, startTransition] = useTransition();

    const filtered = useMemo(
        () => items.filter((i) => i.name.includes(deferredQuery)),
        [items, deferredQuery]
    );

    return (
        <>
            <input
                value={query}
                onChange={(e) => startTransition(() => setQuery(e.target.value))}
            />
            <VirtualList items={filtered} />
        </>
    );
}
```

Combined with debouncing the input by 150 ms and virtualizing the list, INP drops from 600 ms to 80 ms.

## Q60. How do you fix CLS on a banner?

**Answer:**

Banner appearing 1 second into load shifts everything down. CLS 0.4.

Cause: banner element is not in the DOM until React mounts.

Fix:

```css
/* Reserve space */
.banner-slot {
    min-height: 60px;
}
```

```jsx
function Layout({ children }) {
    return (
        <>
            <div className="banner-slot">
                {showBanner && <Banner />}
            </div>
            {children}
        </>
    );
}
```

Result: CLS 0.05.

## Q61. How do you optimize third-party scripts?

**Answer:**

A site adds chat widget, analytics, A/B test — bundle stays the same but TBT goes from 100 ms to 1.2 s.

Fixes:

```html
<!-- 1. Self-host analytics -->
<script defer src="/js/plausible.js"></script>

<!-- 2. Load chat widget on user interaction -->
<button onclick="loadChat()">Help</button>
<script>
    function loadChat() {
        const s = document.createElement('script');
        s.src = 'https://chat.example.com/widget.js';
        document.body.appendChild(s);
    }
</script>

<!-- 3. Defer A/B test -->
<script defer src="/ab-test.js"></script>

<!-- 4. Use Partytown to move third-parties to a worker -->
<script type="text/partytown" src="https://www.googletagmanager.com/gtag/js"></script>
```

## Q62. What is a list of common frontend pitfalls?

**Answer:**

- Forgetting `width` and `height` on images
- Lazy-loading the LCP image
- Shipping source maps to production
- Bundling moment.js with all locales
- Using Google Fonts CDN instead of self-host
- Synchronous third-party scripts in `<head>`
- Inlining base64 huge images
- 50 KB SVG icons inline in HTML
- Memory leaks from unsubscribed observers
- Using `localStorage` synchronously on every render
- IIFEs that are not tree-shakeable

## Q63. What are mobile-specific performance considerations?

**Answer:**

- A mid-range Android has CPU 5-10x slower than your laptop
- Slow flash storage means 50 ms file reads
- 4G real-world latency is 50-200 ms RTT
- Limited memory means bundles over 1 MB cause GC pauses
- Battery-aware throttling
- Touch latency matters more than mouse

Always test on a real mid-range device with throttled network. Synthetic CPU 4x is a realistic baseline.

## Q64. SSR vs SSG vs CSR — when to use each?

**Answer:**

| Approach | TTFB | LCP | Interactivity | Use |
| --- | --- | --- | --- | --- |
| SSG (static) | Fastest (CDN) | Fast | After hydration | Marketing, docs |
| SSR | Slower (compute) | Fast | After hydration | Personalized pages |
| CSR (SPA) | Fast empty shell | Slow (waits for JS) | After bundle + fetch | App-like UIs |
| Streaming SSR | Fast first byte | Fast progressive | Earlier | Modern frameworks |
| RSC | Best of both | Fast | Selective hydration | Next.js App Router |

## Q65. Why is hydration expensive?

**Answer:**

For SSR or SSG, the initial HTML is fast, but React or Vue then "hydrates" — re-runs on the client to attach handlers. On a heavy page, hydration is a long task that hurts INP.

Mitigations:
- Selective hydration (React 18): Suspense boundaries hydrate independently
- Islands architecture (Astro, Fresh, Qwik): only interactive parts hydrate
- Server Components: do not hydrate at all
- Resumability (Qwik): no hydration; pick up where the server left off

## Q66. How do you reduce JS execution time?

**Answer:**

```js
// BAD: synchronous loop blocks main thread
for (const item of bigArray) {
    process(item);
}
```

```js
// GOOD: chunk work and yield
async function processInChunks(arr, chunkSize = 100) {
    for (let i = 0; i < arr.length; i += chunkSize) {
        for (let j = 0; j < chunkSize && i + j < arr.length; j++) {
            process(arr[i + j]);
        }
        await new Promise((r) => setTimeout(r, 0));
    }
}
```

```js
// BETTER: move heavy compute to a Web Worker
const worker = new Worker('/processor.js');
worker.postMessage(bigArray);
worker.onmessage = (e) => setResult(e.data);
```

Use Wasm for CPU-bound algorithms (image processing, parsing). Use `comlink` for ergonomic worker APIs.

## Q67. How do you use `requestIdleCallback` or `scheduler.yield()`?

**Answer:**

```js
function processQueue() {
    const start = performance.now();
    while (queue.length && performance.now() - start < 5) {
        process(queue.pop());
    }
    if (queue.length) {
        requestIdleCallback(processQueue);
    }
}
requestIdleCallback(processQueue);
```

`scheduler.yield()` (Chrome 129+) is the modern primitive: "let other tasks run, continue when ready."

```js
async function heavyTask() {
    for (const item of bigList) {
        process(item);
        if (navigator.scheduling?.isInputPending()) {
            await scheduler.yield();
        }
    }
}
```

## Q68. How do you observe long tasks?

**Answer:**

```js
new PerformanceObserver((list) => {
    list.getEntries().forEach((entry) => {
        console.warn('Long task:', entry.duration, 'ms', entry.attribution);
    });
}).observe({ type: 'longtask', buffered: true });
```

Capture in production via the `web-vitals` attribution build to identify the culprit script.

## Q69. What are common SPA memory leaks?

**Answer:**

- Event listeners not removed (resize, scroll, message)
- `setInterval` or `setTimeout` not cleared
- WebSocket or `EventSource` not closed
- `IntersectionObserver` or `MutationObserver` not disconnected
- Detached DOM held by closures
- Massive Redux state never garbage-collected

```jsx
// BAD: listener leaks on unmount
useEffect(() => {
    window.addEventListener('resize', onResize);
});

// GOOD: cleanup
useEffect(() => {
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
}, []);
```

Detection: Chrome DevTools - Memory - Heap snapshot. Take two snapshots after a navigation, then compare. Look for "Detached" nodes or growing collections.

## Q70. What is a complete frontend production checklist?

**Answer:**

- [ ] Bundle under 200 KB initial (gzipped)
- [ ] Code-split by route
- [ ] Tree shaking working (verified with bundle analyzer)
- [ ] Modern image formats (AVIF, WebP) with fallback
- [ ] All images have width/height or aspect-ratio
- [ ] LCP image preloaded with `fetchpriority="high"`
- [ ] Fonts self-hosted, woff2, `font-display: swap`
- [ ] Critical CSS inlined; rest deferred
- [ ] HTTP/2 or HTTP/3 enabled
- [ ] Brotli on the server
- [ ] CDN with long cache on hashed assets
- [ ] Service worker only if needed
- [ ] Web Vitals tracked in RUM
- [ ] Lighthouse CI on PRs
- [ ] No moment.js
- [ ] No `console.log` in production builds
- [ ] Source maps for error tracking only (not public)
- [ ] Third parties audited (size, blocking)
- [ ] Long tasks under 50 ms target

## Q71. How would you make a slow site fast in 2 weeks?

**Answer:**

1. **Measure first** — Lighthouse and RUM data. Do not guess.
2. **Identify the worst metric** (LCP, INP, CLS, or TTFB) and worst page
3. **Quick wins** (1-2 days): preload LCP image, add image dimensions, fix `font-display`
4. **Bundle audit** (2 days): split by route, remove moment, dedupe libraries
5. **Critical CSS plus defer JS** (2 days)
6. **Image format pipeline** (2 days): WebP/AVIF, srcset
7. **Caching headers and CDN tuning** (1 day)
8. **Re-measure**, ship, monitor RUM
9. **Long tail** — INP fixes (transitions, code splitting), virtualization

Communicate trade-offs: tree shaking might break a vendor library; SSR adds infra complexity.
