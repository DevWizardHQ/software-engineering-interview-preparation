# JavaScript & Frontend Optimization — Senior Engineer Guide

**Purpose:** Master frontend performance for senior interviews. Covers JavaScript bundles, the critical rendering path, images, fonts, React, Vue, network protocols, web vitals, and the Lighthouse / WebPageTest workflow.

---

## Table of Contents

1. [Web Vitals — What and Why](#web-vitals--what-and-why)
2. [JavaScript Bundle Optimization](#javascript-bundle-optimization)
3. [Code Splitting and Lazy Loading](#code-splitting-and-lazy-loading)
4. [Tree Shaking and Dead Code](#tree-shaking-and-dead-code)
5. [Critical Rendering Path](#critical-rendering-path)
6. [Image Optimization](#image-optimization)
7. [Font Optimization](#font-optimization)
8. [React Performance](#react-performance)
9. [Vue Performance](#vue-performance)
10. [Network and Caching](#network-and-caching)
11. [Service Workers and Offline](#service-workers-and-offline)
12. [Measurement Tools](#measurement-tools)
13. [Real Production Patterns](#real-production-patterns)

---

## Web Vitals — What and Why

### Q1. What are the Core Web Vitals (2024+)?

| Metric | Measures | Good | Needs work | Poor |
|--------|----------|------|------------|------|
| LCP (Largest Contentful Paint) | When main content is visible | ≤ 2.5s | 2.5–4s | > 4s |
| INP (Interaction to Next Paint) | Responsiveness across all interactions | ≤ 200ms | 200–500ms | > 500ms |
| CLS (Cumulative Layout Shift) | Visual stability | ≤ 0.1 | 0.1–0.25 | > 0.25 |
| TTFB (Time to First Byte) | Server response time | ≤ 0.8s | 0.8–1.8s | > 1.8s |
| FCP (First Contentful Paint) | First visual element | ≤ 1.8s | 1.8–3s | > 3s |

INP replaced FID in March 2024. Measured at p75 across users.

---

### Q2. How do you actually improve LCP?

LCP is usually a hero image, large heading, or video poster.

**Wins:**
1. Preload the LCP resource: `<link rel="preload" as="image" href="hero.jpg">`
2. Serve in modern format (WebP, AVIF) — 30–70% smaller
3. Add `fetchpriority="high"` on the LCP image
4. Don't lazy-load the LCP image (`loading="eager"`)
5. Reduce server response (TTFB) — see backend optimization
6. Inline critical CSS so paint isn't blocked
7. Use a CDN with edge caching
8. Remove render-blocking resources before LCP element

---

### Q3. What causes high INP?

INP measures the worst interaction across the page session. Caused by long JS tasks blocking the main thread.

**Top causes:**
- Heavy synchronous handlers (`onClick` does 500ms of work)
- Hydration of huge component trees
- Third-party scripts (analytics, A/B test, chat widget)
- Animation work synchronous with state updates
- Re-renders triggered by global context changes

**Fixes:**
- Break tasks under 50 ms (`scheduler.yield()`, `requestIdleCallback`)
- `useDeferredValue` / `useTransition` (React 18+)
- Move non-critical work to web workers
- Defer or self-host third parties
- Avoid synchronous reads of layout (`offsetWidth` in handler)

---

### Q4. CLS — common causes.

- Images without `width`/`height` attributes (or aspect-ratio CSS)
- Ads / iframes inserted dynamically
- Web fonts causing FOUT/FOIT swap
- Above-the-fold content shifting when JS loads
- Animations using `top`/`left` instead of `transform`

**Fixes:**
- Always set explicit dimensions or `aspect-ratio: 16/9`
- Reserve space with placeholders (`min-height`)
- `font-display: optional` or preload font files to avoid late layout shift
- Use `transform` for animations (GPU layer)

---

### Q5. RUM vs synthetic measurement.

| | RUM (Real User Monitoring) | Synthetic (Lighthouse / WebPageTest) |
|--|----------------------------|-------------------------------------|
| Source | Real user devices | Controlled lab environment |
| Variability | High | Low |
| Coverage | All scenarios | Configured ones |
| Use | Production health | Pre-deploy regression check |

You need both. RUM via `web-vitals` JS library or APM (Datadog, Sentry, SpeedCurve). Synthetic in CI for regressions.

---

## JavaScript Bundle Optimization

### Q6. How big should your JS bundle be?

Rough budgets for the initial bundle (compressed):
- **< 100 KB:** great
- **100–250 KB:** acceptable
- **250–500 KB:** likely too much — split
- **> 500 KB:** problematic, especially on mobile 4G

A 1 MB bundle takes ~3–5 seconds just to parse/execute on a mid-range Android.

---

### Q7. Bundle analysis tools.

- **webpack-bundle-analyzer** — interactive treemap of webpack output
- **rollup-plugin-visualizer** — same for Rollup/Vite
- **source-map-explorer** — works on any source-mapped output
- **Vite's `--mode analyze` plus `vite-bundle-visualizer`**
- **Next.js `@next/bundle-analyzer`**

Run after each build. Look for:
- Duplicate libraries (lodash and lodash-es both pulled)
- Heavy dependencies (moment ~250 KB; replace with date-fns or dayjs)
- Source maps shipped to production
- Polyfills you don't need

---

### Q8. Common bundle bloat culprits.

| Library | Size (min+gz) | Replace with |
|---------|---------------|--------------|
| moment | ~70 KB | date-fns (~20 KB tree-shaken), dayjs (~7 KB) |
| lodash (full) | ~25 KB | per-method imports or es-toolkit |
| chartjs (full) | ~80 KB | tree-shaken charts or lightweight (visx, uplot) |
| framer-motion | ~50 KB | CSS animations or motion-one |
| @fortawesome/* (full) | ~150 KB | tree-shake or use lucide / heroicons |
| draft.js / quill | 100+ KB | tiptap (composable) |

---

### Q9. lodash specifically.

Bad:
```js
import _ from 'lodash';
_.debounce(...);
```

Good:
```js
import debounce from 'lodash/debounce';
```

Better with ES build:
```js
import { debounce } from 'lodash-es';   // tree-shakeable
```

---

## Code Splitting and Lazy Loading

### Q10. Route-based code splitting.

React + React Router:
```jsx
const Dashboard = lazy(() => import('./pages/Dashboard'));

<Suspense fallback={<Spinner />}>
  <Routes>
    <Route path="/dashboard" element={<Dashboard />} />
  </Routes>
</Suspense>
```

Vue Router:
```js
const routes = [
  { path: '/dashboard', component: () => import('./pages/Dashboard.vue') },
];
```

Each route becomes its own chunk. Only loads when navigated.

---

### Q11. Component-level code splitting.

```jsx
const HeavyChart = lazy(() => import('./HeavyChart'));

function Page() {
  const [show, setShow] = useState(false);
  return (
    <>
      <button onClick={() => setShow(true)}>Show chart</button>
      {show && <Suspense fallback={<Loader />}><HeavyChart /></Suspense>}
    </>
  );
}
```

Useful for charts, modals, rich text editors, video players.

---

### Q12. Dynamic imports with prefetch / preload.

Webpack magic comments:
```js
const Modal = lazy(() => import(/* webpackPrefetch: true */ './Modal'));
```

- **prefetch:** load when browser is idle (`<link rel="prefetch">`)
- **preload:** load now, in parallel (`<link rel="preload">`)

Vite uses native ES modules — preloading is automatic for routed chunks via `<link rel="modulepreload">`.

---

### Q13. Where to draw the split lines.

| Split point | Why | When |
|-------------|-----|------|
| Per route | Most users hit only some routes | Always |
| Authenticated vs public | Big difference in features | If significant |
| Per heavy widget | Charts, editors used by some users | When > 30 KB |
| Vendor split | Stable code can cache long | Default in most bundlers |
| Per locale | Don't ship all translations | i18n apps |

Don't over-split: each chunk = HTTP overhead. Aim for 20–100 KB per chunk on HTTP/2+.

---

## Tree Shaking and Dead Code

### Q14. What is tree shaking and what breaks it?

Tree shaking = removing unused exports during bundling. Requires:
- ES modules (`import`/`export`, not CommonJS `require`)
- `"sideEffects": false` in package.json (or array of files with side effects)
- Production mode with minifier (Terser, esbuild)

**Breaks tree shaking:**
- CommonJS modules
- Dynamic property access (`Object.keys(lib).forEach(...)`)
- Side-effect imports (`import 'polyfill';`)
- Re-exports through barrel files (`index.js` exporting everything)
- TypeScript `enum` (use const enum or as const objects)

---

### Q15. Barrel files (`index.ts`) — performance trap.

```ts
// components/index.ts
export * from './Button';
export * from './Modal';
export * from './HeavyChart';
```

```ts
import { Button } from './components';   // pulls everything!
```

In some bundler/library combos, even tree-shaking can't fully eliminate side effects from barrel files. Result: importing `Button` may pull `HeavyChart`'s 200 KB.

Fix: import directly:
```ts
import { Button } from './components/Button';
```

Or mark `"sideEffects": false` and ensure barrel re-exports are pure.

---

### Q16. Polyfill strategy.

Don't ship polyfills to modern browsers.

**Best approach:**
- Build differential bundles (modern + legacy) using `@vitejs/plugin-legacy` or `babel-preset-env` with `useBuiltIns: 'usage'`
- Serve modern (`<script type="module">`) and legacy (`<script nomodule>`) via the same HTML
- Most sites only need ESnext output today; legacy share is < 1%

Check `caniuse.com` and your analytics — you may not need any polyfills.

---

## Critical Rendering Path

### Q17. The critical rendering path — what is it?

1. HTML parsed → DOM tree
2. CSS parsed → CSSOM tree
3. DOM + CSSOM → Render tree
4. Layout (geometry)
5. Paint (pixels)
6. Composite (layers)

**Render-blocking resources:** CSS by default, JS in `<head>` without `defer`/`async`.

---

### Q18. defer vs async vs module scripts.

```html
<script src="x.js"></script>          <!-- blocks parsing -->
<script async src="x.js"></script>    <!-- downloads in parallel, runs ASAP, may block -->
<script defer src="x.js"></script>    <!-- downloads in parallel, runs after parse, in order -->
<script type="module" src="x.js"></script>  <!-- defers by default -->
```

Use `defer` for app scripts, `async` for analytics that can run anytime.

---

### Q19. Critical CSS — what and how?

Inline the CSS needed for above-the-fold content; load the rest async.

```html
<style>/* critical above-the-fold styles */</style>
<link rel="preload" href="/css/main.css" as="style" onload="this.rel='stylesheet'">
<noscript><link rel="stylesheet" href="/css/main.css"></noscript>
```

Tools: `critters` (used by Next.js), `critical` npm package, `penthouse`.

For Tailwind, the JIT mode + content scan already produces minimal CSS. Critical extraction less needed.

---

### Q20. Avoiding layout shifts during load.

```html
<!-- Reserve space -->
<img src="hero.webp" width="1200" height="600" alt="" />
<div style="aspect-ratio: 16/9;"></div>
```

```css
@font-face {
  font-family: 'Inter';
  src: url('/inter.woff2') format('woff2');
  font-display: swap;        /* or 'optional' for stricter CLS */
  size-adjust: 100%;
}
```

`font-display: optional` skips the swap if the font isn't ready in 100ms — eliminates layout shift but may show fallback for first visit.

---

## Image Optimization

### Q21. Modern image formats.

| Format | Compression | Browser support | Use |
|--------|-------------|-----------------|-----|
| JPEG | Old-school lossy | Universal | Fallback |
| PNG | Lossless | Universal | UI graphics, transparency |
| WebP | 25–35% smaller than JPEG | All modern browsers | Default |
| AVIF | 50% smaller than JPEG | 95%+ modern | Future default |
| SVG | Vector | Universal | Icons, logos |

Serve via `<picture>`:
```html
<picture>
  <source srcset="hero.avif" type="image/avif">
  <source srcset="hero.webp" type="image/webp">
  <img src="hero.jpg" width="1200" height="600" alt="...">
</picture>
```

---

### Q22. Responsive images with srcset.

```html
<img
  src="hero-800.jpg"
  srcset="hero-400.jpg 400w, hero-800.jpg 800w, hero-1600.jpg 1600w"
  sizes="(max-width: 600px) 100vw, 800px"
  alt="..."
  width="800" height="600"
  loading="lazy"
  decoding="async">
```

The browser picks the right size — saves 50–80% bytes on small screens.

---

### Q23. Lazy loading.

Native:
```html
<img src="..." loading="lazy" />
<iframe loading="lazy" />
```

Browsers load when image is near the viewport. Don't lazy-load the LCP image.

For more control, use IntersectionObserver:
```js
const obs = new IntersectionObserver(entries => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      const img = e.target;
      img.src = img.dataset.src;
      obs.unobserve(img);
    }
  });
}, { rootMargin: '200px' });
document.querySelectorAll('img[data-src]').forEach(img => obs.observe(img));
```

---

### Q24. Image CDN.

Cloudflare Images, Cloudinary, imgix, Vercel/Next.js Image, Bunny Optimizer.

Benefits:
- On-the-fly resize, format conversion, quality
- Auto WebP/AVIF based on Accept header
- Edge caching globally

Workflow: upload original → reference with transforms in URL:
```
https://cdn.example.com/img/hero.jpg?w=800&fm=avif&q=75
```

---

### Q25. Blur placeholder.

Show a tiny blurred preview while the full image loads.

```jsx
// Next.js
<Image src="/hero.jpg" placeholder="blur" blurDataURL={base64Preview} />
```

The placeholder is a 10–20 byte data URI of a tiny version, base64-encoded. Tools: `plaiceholder`, `sharp`.

---

## Font Optimization

### Q26. Font loading strategy.

```html
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>
```

```css
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter.woff2') format('woff2');
  font-display: swap;
  font-weight: 100 900;       /* variable font: one file, all weights */
}
```

- **Self-host** rather than Google Fonts (faster, no third-party request, GDPR friendly)
- **Preload** critical fonts (those used above the fold)
- **woff2** is always smallest; ignore woff/ttf for modern web
- **Variable fonts** ship one file for all weights (Inter, Roboto Flex)
- **Subset** to only the chars you use (latin only for English-only sites)

---

### Q27. font-display values.

| Value | Behavior |
|-------|----------|
| auto | Browser default (usually `block`) |
| block | Hide text up to 3s waiting for font, then swap |
| swap | Show fallback immediately, swap when ready (FOUT) |
| fallback | Brief block, then fallback, swap if loaded < 3s |
| optional | Show fallback, never swap if not in 100ms — best for CLS |

Most sites: `swap`. For premium typography where wrong font is worse than late: `optional` with preload.

---

### Q28. Font subsetting.

A typical Inter font is ~150 KB; the latin subset is ~20 KB.

Tools: `pyftsubset` (fonttools), `glyphhanger`, online tools.

```bash
pyftsubset Inter.ttf --unicodes="U+0020-007F" --output-file=Inter-subset.woff2 --flavor=woff2
```

---

## React Performance

### Q29. When does React.memo actually help?

`React.memo` skips re-render if props are shallowly equal.

**Helps when:**
- Component is expensive to render
- Parent re-renders frequently with stable props
- Props are primitives or stable references

**Doesn't help when:**
- Component is cheap (the comparison costs more than the render)
- Props change every render (object literals, inline functions)
- Children change

**Profile first.** Indiscriminate memoization slows things down.

---

### Q30. useMemo and useCallback — when?

```jsx
const value = useMemo(() => expensiveCompute(a, b), [a, b]);
const handle = useCallback(() => doThing(x), [x]);
```

**Use:**
- For genuinely expensive computations (sorting, filtering huge lists)
- To stabilize references passed to memoized children
- To stabilize dependencies of useEffect

**Don't use:**
- For trivial computations — they cost more than they save
- "Just in case" — every hook adds overhead

The React docs explicitly say "skip this section" for many cases. They aren't free.

---

### Q31. Lifting state too high.

```jsx
function App() {
  const [search, setSearch] = useState('');   // re-renders ALL children
  return <><SearchInput value={search} onChange={setSearch} /><HugeTree /></>;
}
```

Every keystroke re-renders `HugeTree`. Move state down:
```jsx
function App() { return <><Search /><HugeTree /></>; }
function Search() {
  const [search, setSearch] = useState('');
  return <input value={search} onChange={e => setSearch(e.target.value)} />;
}
```

If state must be shared, use context, but split contexts so unrelated changes don't trigger re-renders.

---

### Q32. Context splitting.

```jsx
// Bad: one context with everything
const AppContext = createContext({ user: null, theme: null, settings: {}, ... });

// Good: split by update frequency
const UserContext = createContext(null);     // changes on login
const ThemeContext = createContext('light'); // changes rarely
const SettingsContext = createContext({});   // ditto
```

Or use external state (Zustand, Jotai, Redux Toolkit) which only re-renders subscribers to changed slices.

---

### Q33. Virtualization for long lists.

Rendering 10k DOM nodes is expensive. Render only visible:

- **react-window** — small (5 KB), simple
- **TanStack Virtual** — modern, framework-agnostic
- **react-virtuoso** — supports variable heights, infinite loading

```jsx
import { useVirtualizer } from '@tanstack/react-virtual';
const rowVirtualizer = useVirtualizer({ count: items.length, estimateSize: () => 50, ... });
```

Reduces 10k rows to ~30 visible — go from 5s render to 50 ms.

---

### Q34. useTransition and useDeferredValue (React 18).

```jsx
const [isPending, startTransition] = useTransition();
startTransition(() => setHugeFilter(value));   // marks as non-urgent
```

The urgent input update happens immediately; the expensive list re-render runs in a transition that can be interrupted by further input.

```jsx
const deferred = useDeferredValue(value);   // lags the value, similar effect
```

Massive INP improvements on filter / search UIs.

---

### Q35. Suspense for data fetching.

With server components or libraries like react-query (`suspense: true`), Suspense provides declarative loading states and enables streaming.

```jsx
<Suspense fallback={<Spinner />}>
  <UserProfile id={id} />
</Suspense>
```

Combine with `startTransition` for non-blocking updates.

---

### Q36. React Server Components.

Render on server, no JS shipped. Only the interactive Client Components are hydrated.

```jsx
// page.tsx (server component)
async function Page() {
  const user = await fetchUser();
  return <UserProfile user={user} />;
}
```

Big wins for pages with mostly static content + small interactive bits. Used by Next.js App Router, Remix.

---

### Q37. why-did-you-render.

```js
import whyDidYouRender from '@welldone-software/why-did-you-render';
if (process.env.NODE_ENV === 'development') {
  whyDidYouRender(React, { trackAllPureComponents: true });
}
```

Logs the props that changed, helping you find unnecessary re-renders.

---

### Q38. Avoiding inline functions and objects.

```jsx
// Bad: new object every render
<Component config={{ a: 1, b: 2 }} />

// Good: stable reference
const config = useMemo(() => ({ a: 1, b: 2 }), []);
<Component config={config} />
```

Only matters if `Component` is memoized. Don't go on a hunting spree without a reason.

---

## Vue Performance

### Q39. shallowRef vs ref.

```js
const big = ref(hugeObject);          // deep reactivity, slow
const big = shallowRef(hugeObject);   // only reacts on assignment
```

Use `shallowRef`/`shallowReactive` for large data structures or third-party objects you don't mutate (chart instances, maps, etc).

---

### Q40. v-once and v-memo.

```vue
<!-- Render once and never update -->
<header v-once>{{ siteTitle }}</header>

<!-- Re-render only if items[i] changed -->
<div v-for="item in items" :key="item.id" v-memo="[item.id, item.updatedAt]">
  ...
</div>
```

`v-memo` is great for huge lists where most items don't change between updates.

---

### Q41. computed for memoization.

```js
const filtered = computed(() => items.value.filter(...));
```

Re-evaluates only when reactive deps change. Cached otherwise. Strongly preferred over methods for derived state.

---

### Q42. Async components.

```js
import { defineAsyncComponent } from 'vue';

const HeavyChart = defineAsyncComponent(() => import('./HeavyChart.vue'));
```

With loading/error/timeout:
```js
const Comp = defineAsyncComponent({
  loader: () => import('./HeavyChart.vue'),
  loadingComponent: Loader,
  errorComponent: ErrorView,
  delay: 200,
  timeout: 10000,
});
```

---

### Q43. KeepAlive.

```vue
<router-view v-slot="{ Component }">
  <KeepAlive :max="10">
    <component :is="Component" />
  </KeepAlive>
</router-view>
```

Caches inactive components instead of unmounting. Great for tabbed UIs and back navigation. Watch memory with `:max`.

---

### Q44. List rendering: key strategy.

```vue
<div v-for="item in items" :key="item.id">{{ item.name }}</div>
```

Always provide a stable key. Index as key (`:key="i"`) breaks reconciliation when list reorders. Vue may reuse wrong DOM nodes, causing visual bugs and unnecessary work.

---

### Q45. Vue 3 reactivity gotchas.

- `reactive()` wraps with Proxy — destructuring loses reactivity:
  ```js
  const state = reactive({ count: 0 });
  let { count } = state;  // count is no longer reactive
  ```
- Fix: `toRefs(state)`
- For collections with hundreds of thousands of items, use `markRaw()` or `shallowReactive()` to skip deep tracking

---

## Network and Caching

### Q46. HTTP/1.1 vs HTTP/2 vs HTTP/3.

| Feature | HTTP/1.1 | HTTP/2 | HTTP/3 (QUIC) |
|---------|----------|--------|----------------|
| Multiplexing | No (head-of-line blocking) | Yes | Yes |
| Header compression | No | HPACK | QPACK |
| Server push | No | Yes (deprecated) | No |
| Transport | TCP | TCP | UDP (no TCP head-of-line) |
| TLS | Optional | Required in browsers | Built-in |
| Connection setup | 2-3 RTT | 2-3 RTT | 0-1 RTT |

HTTP/2 makes domain sharding harmful (was a workaround for HTTP/1 connection limits).

HTTP/3 helps lossy connections (mobile) — losing a packet doesn't stall the whole connection.

---

### Q47. Compression: gzip vs Brotli.

| Method | Compression ratio | CPU cost | Browser support |
|--------|-------------------|----------|-----------------|
| gzip | Baseline | Low | Universal |
| Brotli | 15–25% better than gzip | Higher | All modern browsers |
| Zstd | Similar to Brotli, faster | Low | Limited |

Pre-compress static assets at build:
```bash
brotli -k -11 dist/**/*.{js,css,html,svg}
gzip -9 dist/**/*.{js,css,html,svg}
```

Nginx serves precompressed automatically with `gzip_static` and `brotli_static`.

---

### Q48. Cache-Control headers.

```
Cache-Control: public, max-age=31536000, immutable        # hashed assets
Cache-Control: public, max-age=300, s-maxage=3600         # HTML, frequently updated
Cache-Control: private, no-cache                           # personalized
Cache-Control: no-store                                    # secrets
```

- `max-age` — browser cache
- `s-maxage` — CDN / shared cache
- `immutable` — promises content never changes (skip revalidation)
- `stale-while-revalidate=N` — serve stale up to N seconds while revalidating in background

---

### Q49. preconnect, dns-prefetch, preload, prefetch.

```html
<!-- Resolve DNS early -->
<link rel="dns-prefetch" href="https://api.example.com">

<!-- Open TCP+TLS connection early -->
<link rel="preconnect" href="https://api.example.com" crossorigin>

<!-- Fetch resource now (high priority) -->
<link rel="preload" href="/hero.jpg" as="image">

<!-- Hint browser may need this later -->
<link rel="prefetch" href="/next-page.js">

<!-- Module preload (ES modules) -->
<link rel="modulepreload" href="/app.js">
```

Use `preconnect` for cross-origin assets you'll definitely fetch.

---

### Q50. CDN strategy.

Static assets (JS, CSS, images, fonts):
- Long cache (`max-age=31536000, immutable`) on hashed filenames
- CDN with global PoPs (Cloudflare, Fastly, CloudFront, Vercel)
- HTTP/3 enabled
- Origin shield to reduce origin load

HTML pages:
- Short CDN cache + `stale-while-revalidate`
- Or edge SSR (Vercel Edge Functions, Cloudflare Workers) for personalization

---

## Service Workers and Offline

### Q51. Service worker basics.

A worker that intercepts network requests, can cache and serve offline.

```js
// sw.js
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open('v1').then(c => c.addAll(['/','/app.js','/style.css'])));
});

self.addEventListener('fetch', (e) => {
  e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
});
```

Tools: **Workbox** (Google) abstracts strategies (cache-first, network-first, stale-while-revalidate, network-only).

---

### Q52. Service worker pitfalls.

- Stuck on old version — clients keep the SW alive; deploys may take days to propagate. Handle with `skipWaiting` + `clientsClaim`.
- Caching `index.html` aggressively breaks deploys
- Cache size limits (varies by browser, ~50MB safe)
- Difficult to debug — chrome://inspect/#service-workers

For most apps, just CDN + HTTP cache is simpler.

---

## Measurement Tools

### Q53. Lighthouse — how to use it well.

```bash
npx lighthouse https://example.com --view --preset=desktop
```

Or in CI:
```bash
npx lhci autorun --upload.target=temporary-public-storage
```

Lighthouse runs synthetic tests with a simulated 4G mobile or fast desktop. **Throttled CPU 4x** by default — closer to real users.

Interpret with care:
- Performance score is a weighted blend of LCP, INP (Total Blocking Time as proxy), CLS
- Budget your metrics in `lighthouserc.js`
- Fail PRs that regress

---

### Q54. WebPageTest.

More detail than Lighthouse: filmstrip, waterfall per location, multiple runs, real Chrome on real devices.

Free tier at webpagetest.org. Run from multiple geographies to see regional variance.

---

### Q55. Chrome DevTools Performance panel.

Record a session, look for:
- Long tasks (red triangles) — anything > 50ms blocks INP
- Forced reflows / layout thrashing
- Layer compositing issues
- JS profiling — which functions ate time
- Coverage tab — find unused JS/CSS

---

### Q56. Web Vitals JS library.

```js
import { onLCP, onINP, onCLS } from 'web-vitals';

onLCP(metric => sendToAnalytics(metric));
onINP(metric => sendToAnalytics(metric));
onCLS(metric => sendToAnalytics(metric));
```

Sends real measurements to your analytics. Combine with attribution build for diagnostic info.

---

### Q57. Performance budgets.

In `lighthouserc.js`:
```js
{
  assertions: {
    'categories:performance': ['error', { minScore: 0.9 }],
    'first-contentful-paint': ['warn', { maxNumericValue: 1800 }],
    'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
    'total-blocking-time': ['warn', { maxNumericValue: 300 }],
    'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
  },
}
```

Or budget bundle sizes in webpack/vite config.

---

## Real Production Patterns

### Q58. Slow first-page case study.

E-commerce product page TTFB 2.5s, LCP 5s.

Investigation:
- Server: queries fast (200 ms total), framework boot 100 ms — TTFB shouldn't be 2.5s
- Found: TLS handshake + Cold start on serverless. Plus origin in different region from CDN.
- Bundle: 800 KB main chunk, included unused i18n translations for 30 languages
- LCP element: hero carousel image, lazy-loaded by JS framework after hydration

Fixes:
1. Move serverless to user's region (Edge functions)
2. Code-split i18n by locale → 800 KB → 180 KB initial
3. Render hero image as static `<img>` with preload, not via JS — LCP element loads in HTML

Result: TTFB 400 ms, LCP 1.6 s.

---

### Q59. Heavy interaction case study.

Search input with 10k results filter — typing feels laggy.

Profiling: each keystroke triggers full filter + render of 10k items, blocking main thread for 600 ms.

Fixes:
1. Debounce input by 150 ms — reduces work
2. Wrap filter in `useTransition` — keystroke stays responsive
3. Virtualize results list (react-window)
4. Move filter to web worker for very heavy datasets

Result: INP from 600 ms to 80 ms.

---

### Q60. Layout shift case study.

Banner appearing 1s into load shifts everything down. CLS 0.4.

Cause: banner element not in DOM until React mounts.

Fixes:
1. Reserve space with `min-height: 60px`
2. Render banner in HTML SSR
3. If genuinely conditional, position fixed at top, not in flow

Result: CLS 0.05.

---

### Q61. Third-party script case study.

Site adds chat widget, analytics, A/B test — bundle stays the same but TBT goes from 100 ms to 1.2 s.

Fixes:
1. Self-host analytics (e.g., Plausible, Umami, or self-hosted GA proxy)
2. Lazy-load chat widget on user interaction
3. Defer A/B test (not blocking initial render)
4. Use `<script async>` with `fetchpriority="low"`
5. Move some to a web worker via Partytown

---

### Q62. Common pitfalls list.

- Forgetting `width`/`height` on images
- Lazy-loading the LCP image
- Ship sourcemaps to production
- Bundle moment.js with all locales
- Use Google Fonts CDN instead of self-host
- Synchronous third-party scripts in `<head>`
- Inline base64 huge images
- 50 KB SVG icons inline in HTML
- Memory leaks from unsubscribed observers
- Using `localStorage` synchronously on every render
- IIFEs that aren't tree-shakeable

---

### Q63. Mobile-specific considerations.

- Mid-range Android = 5–10x slower CPU than your laptop
- Slow flash storage — 50ms file reads
- 4G real-world: 50–200 ms RTT
- Limited memory — bundles > 1 MB cause GC pauses
- Battery-aware throttling
- Touch latency matters more

Always test on a real mid-range device with throttled network. Synthetic CPU 4x is realistic.

---

### Q64. SSR vs SSG vs CSR.

| Approach | TTFB | LCP | Interactivity | Use |
|----------|------|-----|---------------|-----|
| SSG (static) | Fastest (CDN) | Fast | After hydration | Marketing, docs |
| SSR | Slower (compute) | Fast | After hydration | Personalized pages |
| CSR (SPA) | Fast empty shell | Slow (waits for JS) | After bundle + fetch | App-like UIs |
| Streaming SSR | Fast first byte | Fast progressive | Earlier | Modern frameworks |
| RSC | Best of both | Fast | Selective hydration | Next.js App Router |

---

### Q65. Hydration is expensive.

For SSR/SSG, the initial HTML is fast, but React/Vue then "hydrates" — re-runs on client to attach handlers. On a heavy page, hydration is a long task that hurts INP.

Mitigations:
- **Selective hydration** (React 18): Suspense boundaries hydrate independently
- **Islands architecture** (Astro, Fresh, Qwik): only interactive parts hydrate
- **Server Components**: don't hydrate at all
- **Resumability** (Qwik): no hydration; pick up where server left off

---

### Q66. Reducing JS execution time.

- Avoid synchronous loops over huge arrays — break with `setTimeout` or `requestIdleCallback`
- Move heavy computation to Web Workers
- Use `comlink` for ergonomic Worker APIs
- Use Wasm for CPU-bound algorithms (image processing, parsing)
- Avoid re-computing in render — memoize or precompute

---

### Q67. requestIdleCallback / scheduler.yield.

```js
function processQueue() {
  while (queue.length && performance.now() - start < 5) {
    process(queue.pop());
  }
  if (queue.length) requestIdleCallback(processQueue);
}
```

`scheduler.yield()` (Chrome 129+) is the modern primitive: "let other tasks run, continue when ready."

---

### Q68. Long task observer.

```js
new PerformanceObserver(list => {
  list.getEntries().forEach(entry => {
    console.warn('Long task:', entry.duration, 'ms', entry.attribution);
  });
}).observe({ type: 'longtask', buffered: true });
```

Capture in production via `web-vitals` attribution build to identify the culprit script.

---

### Q69. Memory leaks in SPAs.

Common causes:
- Event listeners not removed (resize, scroll, message)
- setInterval / setTimeout not cleared
- WebSocket / EventSource not closed
- IntersectionObserver / MutationObserver not disconnected
- Detached DOM held by closures
- Massive Redux state never garbage-collected

**Detection:** Chrome DevTools → Memory → Heap snapshot, take two snapshots after navigation, compare. Look for "Detached" nodes or growing collections.

---

### Q70. Real production checklist.

- [ ] Bundle < 200 KB initial (gzipped)
- [ ] Code-split by route
- [ ] Tree shaking working (verified with bundle analyzer)
- [ ] Modern image formats (AVIF / WebP) with fallback
- [ ] All images have width/height or aspect-ratio
- [ ] LCP image preloaded with fetchpriority
- [ ] Fonts self-hosted, woff2, font-display: swap
- [ ] Critical CSS inlined; rest deferred
- [ ] HTTP/2 or HTTP/3 enabled
- [ ] Brotli on the server
- [ ] CDN with long cache on hashed assets
- [ ] Service worker only if needed
- [ ] Web Vitals tracked in RUM
- [ ] Lighthouse CI on PRs
- [ ] No moment.js
- [ ] No `console.log` in production builds
- [ ] Sourcemaps for error tracking only (not public)
- [ ] Third parties audited (size, blocking)
- [ ] Long tasks under 50 ms target

---

### Q71. Senior signal: "Make this slow site fast in 2 weeks."

Walk through:

1. **Measure first** — Lighthouse, RUM data. Don't guess.
2. **Identify the worst metric** (LCP / INP / CLS / TTFB) and worst page
3. **Quick wins** (1–2 days): preload LCP image, image dimensions, font-display
4. **Bundle audit** (2 days): split by route, remove moment, dedupe libs
5. **Critical CSS + defer JS** (2 days)
6. **Image format pipeline** (2 days): WebP/AVIF, srcset
7. **Caching headers + CDN tuning** (1 day)
8. **Re-measure**, ship, monitor RUM
9. **Long tail** — INP fixes (transitions, code splitting), virtualization

Communicate trade-offs: tree shaking might break a vendor library; SSR adds infra complexity. Senior is about prioritization with constraints.
