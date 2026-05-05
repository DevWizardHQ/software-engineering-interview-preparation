# Nuxt.js Interview Questions — Complete Q&A Guide

**Focus:** Nuxt 3, file-based routing, data fetching, Nitro server, rendering modes, modules, deployment.

Each question explains the concept in plain English then shows the working code. Read top to bottom or jump by section.

---

## 1. Fundamentals

## Q1. What is Nuxt?

**Answer:**

Nuxt is a Vue meta-framework. It builds on Vue and adds production features: file-based routing, server-side rendering, auto-imports, a server engine called Nitro, modules, and conventions for layouts and components. You can think of it as Next.js for Vue.

```vue
<!-- pages/index.vue -- automatically a route at "/" -->
<template>
  <h1>Hello Nuxt</h1>
</template>
```

## Q2. What problems does Nuxt solve over plain Vue?

**Answer:**

- Routing: file-based instead of manual route definitions.
- Server-side rendering for SEO and faster first paint.
- Auto-imports of components, composables, and utilities.
- Built-in API server (Nitro) for full-stack work.
- Sensible defaults for SEO, head management, and performance.

```vue
<!-- No need to import — auto-imported -->
<script setup>
const { data } = await useFetch('/api/users');
</script>
```

## Q3. What is the directory structure of a Nuxt app?

**Answer:**

```
nuxt-app/
├── app.vue              ← root component
├── pages/               ← file-based routing
├── layouts/             ← reusable shells
├── components/          ← auto-imported components
├── composables/         ← auto-imported composables
├── server/              ← API routes, middleware
│   ├── api/
│   └── middleware/
├── middleware/          ← route middleware
├── plugins/             ← runtime plugins
├── public/              ← static assets
├── assets/              ← processed assets
└── nuxt.config.ts       ← configuration
```

## Q4. How do you create a Nuxt 3 app?

**Answer:**

```bash
npx nuxi@latest init my-app
cd my-app
npm install
npm run dev
```

The dev server runs at `http://localhost:3000`.

---

## 2. Routing and Pages

## Q5. How does file-based routing work?

**Answer:**

Each `.vue` file inside `pages/` becomes a route automatically. Folders create nested URL segments. Square brackets create dynamic params.

```
pages/
├── index.vue          → /
├── about.vue          → /about
├── blog/
│   ├── index.vue      → /blog
│   └── [slug].vue     → /blog/anything
└── users/
    └── [...path].vue  → /users/a/b/c (catch-all)
```

```vue
<!-- pages/blog/[slug].vue -->
<script setup>
const route = useRoute();
</script>

<template>
  <h1>Post: {{ route.params.slug }}</h1>
</template>
```

## Q6. How do you access route parameters?

**Answer:**

Use `useRoute()` to read the current route object.

```vue
<script setup>
const route = useRoute();
console.log(route.params.id);
console.log(route.query.search);
</script>
```

## Q7. How do you navigate programmatically?

**Answer:**

Use `navigateTo()` (preferred) or `useRouter()`.

```vue
<script setup>
const router = useRouter();

function goToProfile(id) {
  return navigateTo(`/users/${id}`);
}
</script>
```

For declarative navigation use `<NuxtLink>`:

```vue
<NuxtLink to="/about">About</NuxtLink>
```

## Q8. What are route validation and route metadata?

**Answer:**

`definePageMeta()` lets you set per-page configuration like middleware, layout, or `validate`.

```vue
<script setup>
definePageMeta({
  layout: 'admin',
  middleware: 'auth',
  validate: route => /^\d+$/.test(route.params.id),
});
</script>
```

If `validate` returns false, Nuxt shows a 404.

---

## 3. Layouts and Components

## Q9. How do layouts work?

**Answer:**

Files in `layouts/` define reusable page wrappers. Pages slot into the layout via `<slot />`.

```vue
<!-- layouts/default.vue -->
<template>
  <header><Nav /></header>
  <main><slot /></main>
  <footer>...</footer>
</template>
```

Use a non-default layout per page:

```vue
<script setup>
definePageMeta({ layout: 'admin' });
</script>
```

## Q10. How does component auto-import work?

**Answer:**

Any component in `components/` is auto-imported globally — no manual imports needed.

```
components/
├── BaseButton.vue
└── icons/
    └── ArrowIcon.vue   → <IconsArrowIcon />
```

```vue
<template>
  <BaseButton>Click</BaseButton>
  <IconsArrowIcon />
</template>
```

## Q11. What are `.client` and `.server` component suffixes?

**Answer:**

`MyChart.client.vue` only renders on the client (skipped in SSR). `MyChart.server.vue` only renders on the server.

```vue
<!-- components/Map.client.vue -->
<script setup>
import L from 'leaflet'; // browser-only library
onMounted(() => L.map('map'));
</script>
```

## Q12. What is `<NuxtLayout>` vs `<NuxtPage>`?

**Answer:**

`<NuxtLayout>` renders the chosen layout in `app.vue`. `<NuxtPage>` is where the current route's page renders inside that layout.

```vue
<!-- app.vue -->
<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
```

---

## 4. Composables and Auto-imports

## Q13. What are composables in Nuxt?

**Answer:**

Composables are reusable Vue functions following the `useXxx` naming convention. Files in `composables/` are auto-imported.

```js
// composables/useCounter.js
export function useCounter() {
  const count = ref(0);
  const increment = () => count.value++;
  return { count, increment };
}
```

```vue
<script setup>
const { count, increment } = useCounter();
</script>
```

## Q14. What does Nuxt auto-import?

**Answer:**

- Vue APIs (`ref`, `computed`, `watch`, lifecycle hooks).
- Nuxt composables (`useFetch`, `useState`, `useRoute`, `useRouter`).
- Files in `components/`, `composables/`, and `utils/`.

```vue
<script setup>
// no imports needed
const x = ref(0);
const route = useRoute();
const { data } = await useFetch('/api/users');
</script>
```

## Q15. How do you create a composable that works on both server and client?

**Answer:**

Avoid browser-only globals (`window`, `document`) in the body of the composable, or guard them with `process.client`.

```js
export function useTheme() {
  const theme = ref('light');
  if (import.meta.client) {
    theme.value = localStorage.getItem('theme') ?? 'light';
  }
  return { theme };
}
```

---

## 5. Data Fetching

## Q16. What is the difference between `useFetch`, `useAsyncData`, and `$fetch`?

**Answer:**

| API | Use when |
| --- | --- |
| `useFetch` | Most cases — convenience wrapper for HTTP requests with reactivity and caching. |
| `useAsyncData` | When you need finer control or call non-HTTP code (DB, ORM). |
| `$fetch` | One-off imperative request inside event handlers. |

```vue
<script setup>
// useFetch — reactive, deduplicates, caches
const { data, pending, error } = await useFetch('/api/users');

// useAsyncData — manual key
const { data: posts } = await useAsyncData('posts', () => $fetch('/api/posts'));

// $fetch — fire-and-forget inside a handler
async function save() {
  await $fetch('/api/save', { method: 'POST', body: { x: 1 } });
}
</script>
```

## Q17. How does `useFetch` avoid double-fetching during hydration?

**Answer:**

Nuxt serializes the data fetched on the server into the HTML payload. On the client, `useFetch` reads from this payload instead of refetching.

```vue
<script setup>
// fetched on the server, hydrated on the client without re-request
const { data } = await useFetch('/api/products');
</script>
```

## Q18. How do you do client-only fetches?

**Answer:**

Set `server: false` to skip SSR for that fetch.

```vue
<script setup>
const { data } = useFetch('/api/random', { server: false });
</script>
```

## Q19. How do you handle reactive query parameters in `useFetch`?

**Answer:**

Pass parameters as a function or `computed` so they re-fetch when changed.

```vue
<script setup>
const search = ref('');

const { data } = useFetch('/api/search', {
  query: computed(() => ({ q: search.value })),
});
</script>

<template>
  <input v-model="search" />
  <ul>
    <li v-for="r in data" :key="r.id">{{ r.title }}</li>
  </ul>
</template>
```

## Q20. How do you transform or pick fields from `useFetch` data?

**Answer:**

Use `transform` to reshape and `pick` to select fields from the response.

```vue
<script setup>
const { data } = await useFetch('/api/user', {
  pick: ['id', 'name'],
  transform: u => ({ id: u.id, label: u.name.toUpperCase() }),
});
</script>
```

## Q21. How do you implement optimistic updates?

**Answer:**

Update local state immediately, then call the server. Roll back on error.

```vue
<script setup>
const { data: todos, refresh } = await useFetch('/api/todos');

async function add(text) {
  const tempId = Date.now();
  todos.value.push({ id: tempId, text, pending: true });
  try {
    await $fetch('/api/todos', { method: 'POST', body: { text } });
    await refresh();
  } catch (e) {
    todos.value = todos.value.filter(t => t.id !== tempId);
    alert('Failed');
  }
}
</script>
```

---

## 6. State Management

## Q22. What is `useState` in Nuxt?

**Answer:**

`useState` creates SSR-safe shared reactive state keyed by a string. Same key returns the same state across components.

```vue
<script setup>
const counter = useState('counter', () => 0);
</script>

<template>
  <button @click="counter++">{{ counter }}</button>
</template>
```

It is hydrated correctly between server and client.

## Q23. How does Pinia integrate with Nuxt?

**Answer:**

Install `@pinia/nuxt` module — it auto-registers Pinia and provides SSR-safe stores.

```js
// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@pinia/nuxt'],
});
```

```js
// stores/cart.js
export const useCartStore = defineStore('cart', () => {
  const items = ref([]);
  const add = item => items.value.push(item);
  return { items, add };
});
```

## Q24. What is the difference between `useState` and Pinia?

**Answer:**

`useState` is enough for simple shared values. Pinia is better for complex stores with actions, getters, and devtools support.

---

## 7. Rendering Modes

## Q25. What rendering modes does Nuxt support?

**Answer:**

| Mode | What it does |
| --- | --- |
| Universal (SSR) | Default. HTML rendered on each request, then hydrated. |
| Static (SSG) | `nuxi generate` pre-renders all pages to static HTML. |
| SPA only | `ssr: false` in config. No SSR, fully client-rendered. |
| Hybrid (route rules) | Mix per-route via `routeRules`. |

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  ssr: true, // default
});
```

## Q26. How do `routeRules` work?

**Answer:**

`routeRules` configure caching and rendering per URL pattern.

```ts
export default defineNuxtConfig({
  routeRules: {
    '/': { prerender: true },                  // SSG at build time
    '/admin/**': { ssr: false },               // SPA
    '/api/**': { cors: true },
    '/blog/**': { isr: 60 },                   // ISR — revalidate every 60s
    '/old-page': { redirect: '/new-page' },
  },
});
```

## Q27. What is ISR and how does Nuxt support it?

**Answer:**

ISR (Incremental Static Regeneration) serves a cached static page and re-generates it in the background on a schedule. Configure with `routeRules.isr`.

```ts
routeRules: {
  '/posts/**': { isr: 600 }, // revalidate every 10 minutes
}
```

## Q28. What is `nuxi generate` and what limitations does it have?

**Answer:**

`nuxi generate` pre-renders the whole app into static HTML in `.output/public`. Suitable for fully static sites. Limitations: server routes that need a runtime cannot be pre-rendered, and pages with dynamic params must be discoverable through links or `nitro.prerender.routes`.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  nitro: {
    prerender: { routes: ['/sitemap.xml', '/blog/post-1'] },
  },
});
```

## Q29. What is hydration and what are common hydration mismatches?

**Answer:**

Hydration is the process where the browser attaches Vue's reactivity to the server-rendered HTML. A mismatch happens when the server output differs from the client output (different timestamps, random numbers, browser-only data).

Fix by:
- Wrapping non-deterministic content in `<ClientOnly>`.
- Computing values from props, not `Date.now()`.

```vue
<template>
  <ClientOnly>
    <p>Now: {{ new Date().toLocaleTimeString() }}</p>
  </ClientOnly>
</template>
```

---

## 8. Server Engine (Nitro)

## Q30. What is Nitro?

**Answer:**

Nitro is the server engine Nuxt uses for SSR, API routes, and deployments. It produces lightweight server bundles for many platforms (Node, Vercel, Netlify, Cloudflare Workers, AWS Lambda).

## Q31. How do you create API routes?

**Answer:**

Files in `server/api/` become endpoints automatically.

```js
// server/api/hello.get.js
export default defineEventHandler(event => {
  return { message: 'Hello from server' };
});
```

```js
// server/api/users/[id].get.js
export default defineEventHandler(async event => {
  const id = getRouterParam(event, 'id');
  return await db.user.findById(id);
});
```

```js
// server/api/users.post.js
export default defineEventHandler(async event => {
  const body = await readBody(event);
  return await db.user.create(body);
});
```

## Q32. How do you handle errors in API routes?

**Answer:**

Throw using `createError` to send a structured HTTP error.

```js
export default defineEventHandler(async event => {
  const id = getRouterParam(event, 'id');
  const user = await db.user.find(id);
  if (!user) throw createError({ statusCode: 404, statusMessage: 'User not found' });
  return user;
});
```

## Q33. What is server middleware vs route middleware?

**Answer:**

- **Route middleware** (in `middleware/`) runs before page navigation on the client and during SSR. Use for auth or redirects.
- **Server middleware** (in `server/middleware/`) runs on every server request before handlers. Use for logging, rate limits, or auth.

```js
// middleware/auth.global.js
export default defineNuxtRouteMiddleware(to => {
  const user = useState('user');
  if (!user.value && to.path.startsWith('/dashboard')) {
    return navigateTo('/login');
  }
});
```

```js
// server/middleware/log.js
export default defineEventHandler(event => {
  console.log(event.method, event.path);
});
```

## Q34. How does Nitro storage work?

**Answer:**

Nitro provides `useStorage()` for key-value storage backed by various drivers (memory, fs, Redis, S3, Cloudflare KV).

```js
export default defineEventHandler(async event => {
  const storage = useStorage('redis');
  await storage.setItem('user:1', { name: 'Iqbal' });
  return await storage.getItem('user:1');
});
```

## Q35. What is `cachedEventHandler` and `defineCachedFunction`?

**Answer:**

These wrap an event handler or function with caching, configurable by TTL and group.

```js
import { cachedEventHandler } from '#imports';

export default cachedEventHandler(
  async () => await fetchExpensiveData(),
  { maxAge: 60, name: 'expensive', group: 'api' }
);
```

---

## 9. Middleware

## Q36. How do you build authentication middleware?

**Answer:**

```js
// middleware/auth.js
export default defineNuxtRouteMiddleware(to => {
  const { user } = useAuth();
  if (!user.value) return navigateTo('/login');
});
```

```vue
<script setup>
definePageMeta({ middleware: 'auth' });
</script>
```

## Q37. Can middleware call APIs?

**Answer:**

Yes, but be aware that route middleware runs both on server and client. Use `$fetch` (works on both) and avoid leaking server credentials.

```js
export default defineNuxtRouteMiddleware(async () => {
  const user = await $fetch('/api/me').catch(() => null);
  if (!user) return navigateTo('/login');
});
```

---

## 10. Modules and Ecosystem

## Q38. What are Nuxt modules?

**Answer:**

Modules extend Nuxt with new features (UI libraries, content systems, image optimization). Add them in `nuxt.config.ts`.

```ts
export default defineNuxtConfig({
  modules: [
    '@pinia/nuxt',
    '@nuxt/image',
    '@nuxtjs/tailwindcss',
    '@nuxt/content',
  ],
});
```

## Q39. What is `@nuxt/image`?

**Answer:**

`@nuxt/image` optimizes images with `<NuxtImg>` and `<NuxtPicture>`. Resizes, lazy-loads, modern formats.

```vue
<template>
  <NuxtImg src="/photo.jpg" width="800" height="600" loading="lazy" />
</template>
```

## Q40. What is `@nuxt/content`?

**Answer:**

`@nuxt/content` is a file-based CMS using Markdown, YAML, JSON. Content lives in `content/` and is queryable.

```md
<!-- content/blog/hello.md -->
---
title: Hello
---

# Hello world
```

```vue
<script setup>
const { data: post } = await useAsyncData(() => queryContent('/blog/hello').findOne());
</script>

<template>
  <ContentRenderer :value="post" />
</template>
```

---

## 11. Plugins and Runtime

## Q41. What are Nuxt plugins?

**Answer:**

Files in `plugins/` run on app startup. Use them to register Vue plugins, set up clients (Sentry, analytics), or provide global helpers.

```js
// plugins/dayjs.js
import dayjs from 'dayjs';

export default defineNuxtPlugin(() => {
  return {
    provide: { dayjs },
  };
});
```

```vue
<script setup>
const { $dayjs } = useNuxtApp();
</script>
```

## Q42. What is the difference between runtime config and app config?

**Answer:**

`runtimeConfig` is server-only by default and can be overridden by env vars at runtime. `app.config` is client-side, included in the bundle, used for non-secret values.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    apiSecret: '',                   // server only, override with NUXT_API_SECRET
    public: {
      apiBase: 'https://api.example.com', // exposed to client
    },
  },
  app: {
    config: { theme: 'dark' },
  },
});
```

```vue
<script setup>
const config = useRuntimeConfig();
console.log(config.public.apiBase);
</script>
```

## Q43. How do you provide global helpers?

**Answer:**

In a plugin, return `{ provide: { helper: fn } }`, then access via `useNuxtApp()`.

```js
export default defineNuxtPlugin(() => ({
  provide: {
    formatPrice: n => `$${n.toFixed(2)}`,
  },
}));
```

```vue
<script setup>
const { $formatPrice } = useNuxtApp();
</script>
```

---

## 12. SEO and Meta

## Q44. How do you set page titles and meta tags?

**Answer:**

Use `useHead` or `useSeoMeta`.

```vue
<script setup>
useHead({
  title: 'Home',
  meta: [{ name: 'description', content: 'Welcome to my site' }],
});

// Type-safe alternative
useSeoMeta({
  title: 'Home',
  description: 'Welcome',
  ogImage: '/og.png',
});
</script>
```

## Q45. How do you generate a sitemap and robots.txt?

**Answer:**

Use `@nuxtjs/sitemap` and `@nuxtjs/robots`.

```ts
export default defineNuxtConfig({
  modules: ['@nuxtjs/sitemap', '@nuxtjs/robots'],
  site: { url: 'https://example.com' },
  robots: { rules: { UserAgent: '*', Allow: '/' } },
});
```

---

## 13. Deployment

## Q46. How do you deploy a Nuxt app?

**Answer:**

Choose a Nitro preset for your platform and run `nuxi build`.

```bash
# Vercel, Netlify, Cloudflare auto-detect

# Manual preset
NITRO_PRESET=node-server npm run build
node .output/server/index.mjs
```

## Q47. How do you reduce cold starts on serverless?

**Answer:**

- Pre-render pages that do not need SSR.
- Use ISR (`routeRules: { '/': { isr: 60 } }`).
- Avoid heavy imports at module top level.
- Choose edge runtimes (`cloudflare`) for low-cold-start workloads.

## Q48. How do you implement environment-specific config?

**Answer:**

Use `runtimeConfig` overridden by env vars prefixed with `NUXT_`.

```ts
runtimeConfig: {
  apiSecret: process.env.NUXT_API_SECRET, // implicitly mapped
  public: { apiBase: process.env.NUXT_PUBLIC_API_BASE },
}
```

```bash
# .env
NUXT_API_SECRET=secret
NUXT_PUBLIC_API_BASE=https://api.example.com
```

---

## 14. Migration and Comparisons

## Q49. Nuxt 2 vs Nuxt 3 — what changed?

**Answer:**

- Vue 2 → Vue 3 with Composition API.
- `asyncData` → `useFetch` / `useAsyncData`.
- Vuex → Pinia.
- Manual modules → auto-imports for components, composables, utils.
- New server engine: Nitro.
- TypeScript-first.
- Hybrid rendering with `routeRules`.

## Q50. Nuxt vs Next.js — comparison?

**Answer:**

| | Nuxt | Next.js |
| --- | --- | --- |
| Framework | Vue | React |
| Server | Nitro | Node + Vercel runtime |
| Data fetching | `useFetch`, `useAsyncData` | `fetch` in RSC |
| State | Pinia, `useState` | Various |
| Routing | File-based | File-based |

Both produce similar results — choose by team and ecosystem.

## Q51. When would you choose Nuxt over plain Vue + Vite?

**Answer:**

Choose Nuxt when you need SSR/SSG/SEO, server endpoints in the same project, content-driven pages, or you want a batteries-included setup. Choose plain Vue + Vite when building a small SPA, embedded widget, or admin panel where you do not need SSR.

## Q52. How do you test a Nuxt app?

**Answer:**

Use Vitest plus `@nuxt/test-utils` for integration tests.

```js
import { describe, it, expect } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import HomePage from '@/pages/index.vue';

describe('HomePage', () => {
  it('renders', async () => {
    const wrapper = await mountSuspended(HomePage);
    expect(wrapper.html()).toContain('Hello');
  });
});
```

## Q53. How do you handle errors and 404s?

**Answer:**

Create `error.vue` at the project root. It shows when an unhandled error or 404 happens.

```vue
<!-- error.vue -->
<script setup>
const props = defineProps({ error: Object });
const handleError = () => clearError({ redirect: '/' });
</script>

<template>
  <div>
    <h1>{{ error.statusCode }}</h1>
    <p>{{ error.message }}</p>
    <button @click="handleError">Home</button>
  </div>
</template>
```

Trigger 404 from a page or API:

```js
throw createError({ statusCode: 404, statusMessage: 'Not Found', fatal: true });
```

## Q54. What performance tools and tips for Nuxt?

**Answer:**

- Run `nuxi analyze` to inspect bundle size.
- Lazy-load components with `defineAsyncComponent` or the `Lazy` prefix (`<LazyChart />`).
- Pre-render pages that do not need SSR.
- Use `useFetch` with `key` and `dedupe` for shared requests.
- Use `routeRules` to cache where possible.

```vue
<template>
  <LazyExpensiveChart v-if="visible" />
</template>
```

## Q55. What is `<ClientOnly>` and when do you need it?

**Answer:**

`<ClientOnly>` skips SSR for its children, rendering them only in the browser. Use for components that depend on `window`, `document`, or browser-only libraries.

```vue
<template>
  <ClientOnly fallback-tag="span" fallback="Loading...">
    <ChartLibrary />
  </ClientOnly>
</template>
```

## Q56. How do you implement a basic auth flow end-to-end in Nuxt?

**Answer:**

```js
// server/api/login.post.js
export default defineEventHandler(async event => {
  const { email, password } = await readBody(event);
  const user = await verify(email, password);
  if (!user) throw createError({ statusCode: 401, statusMessage: 'Invalid' });

  setCookie(event, 'session', signSession(user), { httpOnly: true, secure: true });
  return user;
});
```

```js
// composables/useAuth.js
export function useAuth() {
  const user = useState('user', () => null);
  const login = async (email, password) => {
    user.value = await $fetch('/api/login', { method: 'POST', body: { email, password } });
  };
  const logout = () => $fetch('/api/logout', { method: 'POST' }).then(() => user.value = null);
  return { user, login, logout };
}
```

```js
// middleware/auth.js
export default defineNuxtRouteMiddleware(() => {
  const { user } = useAuth();
  if (!user.value) return navigateTo('/login');
});
```

## Q57. What is `nuxtApp` and what does it expose?

**Answer:**

`useNuxtApp()` returns the app instance with helpers, plugin-provided values (`$xxx`), the Vue app, and lifecycle hooks.

```vue
<script setup>
const app = useNuxtApp();
app.hook('page:finish', () => console.log('navigation done'));
</script>
```

## Q58. How do you handle redirects?

**Answer:**

```js
// In page setup or middleware
return navigateTo('/login', { redirectCode: 301 });

// In nuxt.config.ts via routeRules
routeRules: { '/old': { redirect: '/new' } }
```

## Q59. What is the `useCookie` composable?

**Answer:**

`useCookie` is a reactive cookie helper that works on both server and client.

```vue
<script setup>
const token = useCookie('token', { maxAge: 60 * 60 * 24 });

function setToken() {
  token.value = 'abc123';
}
</script>
```

## Q60. How do you handle file uploads in Nuxt?

**Answer:**

Use `FormData` on the client and `readMultipartFormData` on the server.

```vue
<script setup>
async function upload(e) {
  const fd = new FormData();
  fd.append('file', e.target.files[0]);
  await $fetch('/api/upload', { method: 'POST', body: fd });
}
</script>

<template>
  <input type="file" @change="upload" />
</template>
```

```js
// server/api/upload.post.js
export default defineEventHandler(async event => {
  const files = await readMultipartFormData(event);
  // files[0].data is a Buffer
  return { ok: true };
});
```

## Q61. How does Nuxt handle SEO at the route level?

**Answer:**

Combine `useSeoMeta` per page with `definePageMeta` and the sitemap module.

```vue
<script setup>
const { data: post } = await useFetch(`/api/posts/${useRoute().params.slug}`);

useSeoMeta({
  title: () => post.value?.title,
  description: () => post.value?.excerpt,
  ogImage: () => post.value?.cover,
});
</script>
```

## Q62. What is `useRequestHeaders`?

**Answer:**

Reads incoming HTTP headers during SSR — useful for forwarding auth cookies to internal API calls.

```vue
<script setup>
const headers = useRequestHeaders(['cookie']);
const { data } = await useFetch('/api/me', { headers });
</script>
```

## Q63. What is `useRequestEvent` and `useRequestURL`?

**Answer:**

`useRequestEvent` returns the H3 event object on the server (request/response). `useRequestURL` returns a URL object that works on both server and client.

```vue
<script setup>
const url = useRequestURL();
console.log(url.pathname);
</script>
```

---

## 15. Quick Reference

| Composable | Purpose |
| ---------- | ------- |
| `useFetch` | HTTP request with reactivity |
| `useAsyncData` | Generic async data wrapper |
| `useState` | SSR-safe shared state |
| `useRoute` | Current route |
| `useRouter` | Router instance |
| `useHead` | Meta tags |
| `useSeoMeta` | Type-safe SEO |
| `useCookie` | Reactive cookies |
| `useRuntimeConfig` | Runtime config |
| `useNuxtApp` | App instance |
| `navigateTo` | Programmatic navigation |
| `createError` | Throw HTTP error |

| Folder | Purpose |
| ------ | ------- |
| `pages/` | Routes |
| `layouts/` | Layout templates |
| `components/` | Auto-imported UI |
| `composables/` | Auto-imported logic |
| `server/api/` | API endpoints |
| `server/middleware/` | Request middleware |
| `middleware/` | Route middleware |
| `plugins/` | Runtime plugins |
| `public/` | Static assets |
