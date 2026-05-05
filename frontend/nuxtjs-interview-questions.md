# Nuxt.js Interview Questions

**Level:** Mid to Senior
**Topics:** Nuxt 3, Routing, Data Fetching, Nitro, SSR/SSG/ISR, Modules, Performance, Deployment

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Routing and Pages](#routing-and-pages)
3. [Layouts and Components](#layouts-and-components)
4. [Composables and Auto-imports](#composables-and-auto-imports)
5. [Data Fetching](#data-fetching)
6. [State Management](#state-management)
7. [Rendering Modes](#rendering-modes)
8. [Server Engine (Nitro)](#server-engine-nitro)
9. [Middleware](#middleware)
10. [Modules and Ecosystem](#modules-and-ecosystem)
11. [Plugins and Runtime](#plugins-and-runtime)
12. [SEO and Meta](#seo-and-meta)
13. [Deployment](#deployment)
14. [Migration and Comparisons](#migration-and-comparisons)

---

## Fundamentals

### Q1. What is Nuxt?

**Answer:**
Nuxt is a meta-framework for Vue.js that provides full-stack capabilities: file-based routing, server-side rendering, static site generation, API routes, auto-imports, and a module ecosystem. It's the Vue analogue of Next.js for React.

Nuxt 3 is built on Vue 3, Vite, and Nitro (the universal server engine). It supports SSR, SSG, hybrid rendering, edge deployment, and SPA mode.

---

### Q2. What problems does Nuxt solve over plain Vue?

**Answer:**
- File-based **routing** (no manual router config)
- **SSR/SSG** out of the box (SEO, fast first paint)
- **Auto-imports** of components, composables, and utilities
- **Server-side API routes** without a separate Express/Fastify project
- **Module system** for cross-cutting concerns (auth, image, content)
- **Production conventions**: layouts, error pages, middleware, plugins
- **Universal data fetching** that works on server and client without duplication

Plain Vue is unopinionated; Nuxt is "framework that includes the framework" — fewer choices, faster delivery.

---

### Q3. What is the directory structure of a Nuxt app?

**Answer:**

```
my-app/
├── app.vue              # Root component
├── error.vue            # Error page
├── nuxt.config.ts
├── pages/               # File-based routes
├── layouts/             # Page layouts
├── components/          # Auto-imported components
├── composables/         # Auto-imported composables
├── middleware/          # Route middleware
├── plugins/             # Vue plugins
├── server/              # API routes, server middleware
│   ├── api/
│   ├── routes/
│   └── middleware/
├── public/              # Static assets served from /
├── assets/              # Build-processed assets
├── utils/               # Auto-imported utilities
├── stores/              # Pinia stores (if @pinia/nuxt installed)
└── types/               # TypeScript types
```

Conventions over configuration — most folders work automatically.

---

### Q4. How do you create a Nuxt 3 app?

**Answer:**

```bash
npx nuxi@latest init my-app
cd my-app
npm install
npm run dev      # localhost:3000
```

Common nuxi commands:

| Command | Purpose |
|---------|---------|
| `nuxi dev` | Development server |
| `nuxi build` | Production build (server + client) |
| `nuxi generate` | Static site generation |
| `nuxi preview` | Preview production build locally |
| `nuxi typecheck` | Run vue-tsc type check |
| `nuxi prepare` | Generate `.nuxt` types (post-install) |
| `nuxi add page <name>` | Scaffold a page |
| `nuxi module add <name>` | Install a Nuxt module |
| `nuxi cleanup` | Remove generated files |

---

## Routing and Pages

### Q5. How does file-based routing work?

**Answer:**
Files in `pages/` map to routes:

```
pages/
├── index.vue              → /
├── about.vue              → /about
├── blog/
│   ├── index.vue          → /blog
│   └── [slug].vue         → /blog/:slug
├── users/
│   └── [...path].vue      → /users/* (catch-all)
└── (admin)/               → group, doesn't affect URL
    └── dashboard.vue      → /dashboard
```

Pages must export a single root component. Nuxt builds the Vue Router config from this tree.

To enable, ensure `<NuxtPage />` is in `app.vue`:

```vue
<template>
  <div>
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>
```

---

### Q6. How do you access route parameters?

**Answer:**

```vue
<!-- pages/blog/[slug].vue -->
<script setup>
const route = useRoute();
const slug = route.params.slug;

// Or with useFetch
const { data } = await useFetch(`/api/posts/${route.params.slug}`);
</script>
```

For multiple params: `[year]-[month]/[slug].vue` → `route.params.year`, `route.params.month`, `route.params.slug`.

For optional/catch-all: `[...slug].vue` → `route.params.slug` is an array of segments.

---

### Q7. How do you navigate programmatically?

**Answer:**

```ts
// Composable
const router = useRouter();
await router.push('/dashboard');
await router.replace({ path: '/login', query: { from: route.fullPath } });

// Helper (preferred in Nuxt 3 — handles SSR redirects)
await navigateTo('/dashboard');
await navigateTo({ name: 'user-id', params: { id: 5 } });

// External
await navigateTo('https://example.com', { external: true });

// In route middleware — return the navigation
export default defineNuxtRouteMiddleware((to) => {
  if (!isAuthed()) return navigateTo('/login');
});
```

In `<template>`:
```vue
<NuxtLink to="/about" prefetch>About</NuxtLink>
```

`<NuxtLink>` prefetches in viewport by default (configurable).

---

### Q8. What are route validation and route metadata?

**Answer:**

```vue
<script setup>
definePageMeta({
  layout: 'admin',
  middleware: ['auth'],
  validate: (route) => /^\d+$/.test(route.params.id),
  pageTransition: { name: 'fade', mode: 'out-in' },
  alias: ['/legacy-path'],
});
</script>
```

`validate` returning false produces a 404. Useful for type-safe params before data fetching.

---

## Layouts and Components

### Q9. How do layouts work?

**Answer:**

```vue
<!-- layouts/default.vue -->
<template>
  <div>
    <SiteHeader />
    <slot />
    <SiteFooter />
  </div>
</template>
```

```vue
<!-- pages/admin.vue -->
<script setup>
definePageMeta({ layout: 'admin' });
</script>
```

Switch dynamically:
```vue
<script setup>
setPageLayout('custom');
</script>
```

`layouts/default.vue` is used unless overridden. Set `layout: false` to skip layouts.

In `app.vue`:
```vue
<NuxtLayout :name="layoutName">
  <NuxtPage />
</NuxtLayout>
```

---

### Q10. How does component auto-import work?

**Answer:**
Files in `components/` are globally available without import:

```vue
<!-- components/AppButton.vue or components/app-button.vue -->
<template><button><slot /></button></template>
```

```vue
<template>
  <AppButton>Click</AppButton>  <!-- no import -->
</template>
```

Nested folders prefix names: `components/forms/Input.vue` → `<FormsInput>`.

To opt out: `<MyComponent.client>` or use `defineNuxtConfig({ components: { dirs: [] } })`.

---

### Q11. What are `.client` and `.server` component suffixes?

**Answer:**

```
components/
├── Chart.client.vue   # Only rendered on client (skips SSR)
├── Heavy.server.vue   # Only rendered on server, streamed to client
```

Use cases:
- `.client` — components needing `window`, third-party JS, or that shouldn't SSR (like maps, drag-drop, charts).
- `.server` — heavy components that don't need interactivity, rendered server-side and inserted into the page.

`<ClientOnly>` wrapper alternative:
```vue
<ClientOnly fallback-tag="span" fallback="Loading...">
  <ChartComponent />
</ClientOnly>
```

---

### Q12. What is `<NuxtLayout>` vs `<NuxtPage>`?

**Answer:**
- `<NuxtPage>` is where the matched page component renders. Place inside `app.vue` (and inside layouts).
- `<NuxtLayout>` wraps `<NuxtPage>` with the active layout from `layouts/`.

If you need pure page rendering without layout, use just `<NuxtPage />` in `app.vue` and skip layouts.

---

## Composables and Auto-imports

### Q13. What are composables in Nuxt?

**Answer:**
Functions starting with `use` exported from `composables/` are auto-imported:

```ts
// composables/useCounter.ts
export const useCounter = () => {
  const count = ref(0);
  const increment = () => count.value++;
  return { count, increment };
};
```

```vue
<script setup>
const { count, increment } = useCounter();
</script>
```

Built-in composables: `useFetch`, `useAsyncData`, `useState`, `useRoute`, `useRouter`, `useRuntimeConfig`, `useCookie`, `useHead`, `useNuxtApp`, `useError`, `useRequestHeaders`, etc.

---

### Q14. What does Nuxt auto-import?

**Answer:**

| Folder/File | Imported as |
|-------------|-------------|
| `components/**` | Tags in templates |
| `composables/*.ts` | Named exports |
| `composables/index.ts` | All exports from default `index` |
| `utils/**` | All exports |
| Vue APIs | `ref`, `computed`, `watch`, `onMounted`, etc. |
| Nuxt APIs | `useFetch`, `useState`, `navigateTo`, etc. |

Disable globally or per-directory in `nuxt.config.ts`. Generated types live in `.nuxt/imports.d.ts`.

---

### Q15. How do you create a composable that works on both server and client?

**Answer:**

```ts
export const useTheme = () => {
  // useState is SSR-safe shared state
  const theme = useState<'light' | 'dark'>('theme', () => 'light');

  if (process.client) {
    onMounted(() => {
      theme.value = localStorage.getItem('theme') as any || 'light';
    });
  }

  const toggle = () => {
    theme.value = theme.value === 'light' ? 'dark' : 'light';
    if (process.client) localStorage.setItem('theme', theme.value);
  };

  return { theme, toggle };
};
```

Guards: `process.server` / `process.client` (and in newer Nuxt, `import.meta.server` / `import.meta.client`).

---

## Data Fetching

### Q16. What's the difference between `useFetch`, `useAsyncData`, and `$fetch`?

**Answer:**

| API | Purpose | SSR-aware | Auto-deduped | Reactivity |
|-----|---------|-----------|--------------|------------|
| `$fetch` | Bare HTTP client (ofetch) | No | No | No |
| `useAsyncData` | Universal data wrapper around any async function | Yes | Yes (by key) | Yes |
| `useFetch` | Convenience wrapper: `useAsyncData` + `$fetch` | Yes | Yes (by URL) | Yes |

```vue
<script setup>
// Quick GET
const { data, pending, error, refresh } = await useFetch('/api/users');

// Custom fetcher
const { data } = await useAsyncData('user-stats', () =>
  Promise.all([$fetch('/api/users'), $fetch('/api/orders')])
);

// Imperative — no SSR coordination, no caching
async function deleteUser(id) {
  await $fetch(`/api/users/${id}`, { method: 'DELETE' });
}
</script>
```

Rule of thumb: `useFetch` for declarative GETs in `<script setup>`. `$fetch` for imperative actions (POST/PUT/DELETE in handlers). `useAsyncData` when wrapping non-HTTP async work or composing multiple fetches.

---

### Q17. How does `useFetch` avoid double-fetching during hydration?

**Answer:**
On the server, Nuxt fetches the data and serializes it into the rendered HTML payload. On hydration, the client deserializes the payload and reuses it — the network request is **not** repeated.

The keying mechanism (URL by default) ensures the client knows which payload corresponds to which `useFetch` call. You can override with the `key` option.

```ts
const { data } = await useFetch('/api/posts', { key: 'posts' });
```

If you call `$fetch` directly in `<script setup>` without `useAsyncData`, the request will execute on both server and client — wasted work.

---

### Q18. How do you do client-only fetches?

**Answer:**

```ts
const { data } = await useFetch('/api/dashboard', {
  server: false,                // skip SSR
  lazy: true,                   // don't block navigation
  default: () => ({ items: [] }),
});
```

`lazy: true` returns immediately with `pending: true`, then resolves. Useful for non-critical data.

`server: false` is appropriate for authenticated dashboards where SSR can't access user-specific tokens, or for data that's fine to load post-paint.

---

### Q19. How do you handle reactive query parameters in `useFetch`?

**Answer:**

```ts
const search = ref('');
const page = ref(1);

const { data } = await useFetch('/api/posts', {
  query: { search, page },          // reactive — refetches when changed
  watch: [search, page],            // explicit dependencies
});
```

Reactive `query`, `params`, `body` automatically re-trigger fetches. To debounce or transform, wrap in computed or use `refresh` manually.

---

### Q20. How do you transform or pick fields from `useFetch` data?

**Answer:**

```ts
const { data } = await useFetch('/api/user', {
  transform: (raw) => ({ name: raw.fullName, email: raw.emailAddress }),
  pick: ['id', 'name', 'email'], // serialize only these from server payload
});
```

`pick` reduces SSR payload size — only listed fields are serialized to the client.
`transform` shapes the data at fetch time, runs both on server and client.

---

### Q21. How do you implement optimistic updates?

**Answer:**

```ts
const { data, refresh } = await useFetch<Todo[]>('/api/todos');

async function toggleTodo(id: number) {
  if (!data.value) return;
  // optimistic update
  data.value = data.value.map(t => t.id === id ? { ...t, done: !t.done } : t);
  try {
    await $fetch(`/api/todos/${id}/toggle`, { method: 'POST' });
  } catch (e) {
    // revert
    await refresh();
  }
}
```

For complex apps, consider Pinia or TanStack Query (`@tanstack/vue-query`).

---

## State Management

### Q22. What is `useState` in Nuxt?

**Answer:**
SSR-safe shared reactive state, scoped by key:

```ts
const counter = useState('counter', () => 0);
counter.value++;
```

- Hydrates from server payload, so SSR + client see the same value
- Shared across components by key (avoid name collisions)
- Resets on full page reload (use `useCookie` for persistence)

For complex state, prefer Pinia.

---

### Q23. How does Pinia integrate with Nuxt?

**Answer:**

```bash
npx nuxi module add pinia
```

```ts
// stores/counter.ts
export const useCounterStore = defineStore('counter', () => {
  const count = ref(0);
  const double = computed(() => count.value * 2);
  function increment() { count.value++; }
  return { count, double, increment };
});
```

```vue
<script setup>
const counter = useCounterStore();
counter.increment();
</script>
```

`@pinia/nuxt` handles SSR hydration automatically. Stores are auto-imported. Composition API or Options API style both supported.

For server-side state initialization:
```ts
const store = useCounterStore();
await store.fetchInitialData();  // before render, hydrates client
```

---

### Q24. What is the difference between `useState` and Pinia?

**Answer:**

| | `useState` | Pinia |
|---|-----------|-------|
| API | Single ref-like value | Full store with state, getters, actions |
| Devtools | Limited | Full Vue Devtools integration |
| Modularity | Flat keys | Namespaced stores |
| Side effects | Manual | Designed for actions |
| Persistence | Manual | Plugins (e.g. `pinia-plugin-persistedstate`) |
| Best for | Simple cross-component values | App-level state, complex flows |

---

## Rendering Modes

### Q25. What rendering modes does Nuxt support?

**Answer:**

| Mode | Description | Command |
|------|-------------|---------|
| **SSR** (universal) | Render per-request on the server, hydrate on client. Default. | `nuxi build` |
| **SSG** | Pre-render every route at build time | `nuxi generate` |
| **SPA** | Client-side only, no server rendering | `ssr: false` |
| **Hybrid** | Per-route rules: some prerendered, some SSR, some SPA | `routeRules` in config |
| **ISR** | Periodically revalidate prerendered pages | `routeRules: { '/path': { isr: 60 } }` |
| **SWR** | Stale-while-revalidate at the edge | `routeRules: { '/path': { swr: 60 } }` |

---

### Q26. How do `routeRules` work?

**Answer:**

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  routeRules: {
    '/': { prerender: true },
    '/blog/**': { isr: 3600 },           // revalidate every hour
    '/api/**': { cors: true, headers: { 'cache-control': 's-maxage=60' } },
    '/admin/**': { ssr: false, robots: false },
    '/old-path': { redirect: '/new-path' },
    '/products/**': { swr: 600 },        // stale-while-revalidate
    '/draft/**': { index: false },        // no SEO indexing
  },
});
```

`routeRules` is the unified API for hybrid rendering, redirects, headers, CORS, prerendering — replaces multiple older configs.

---

### Q27. What is ISR and how does Nuxt support it?

**Answer:**
Incremental Static Regeneration: a page is statically generated, served from cache, and regenerated on the server when it expires (or on demand).

```ts
routeRules: {
  '/blog/**': { isr: 60 },     // revalidate after 60s
  '/products/**': { isr: true } // permanent cache, on-demand revalidation
}
```

First request after expiry triggers regeneration in the background; cache continues serving stale content until the new page is ready (SWR-style).

Requires a deployment target with cache support (Vercel, Netlify, Cloudflare with KV, or self-hosted with appropriate cache).

---

### Q28. What is `nuxi generate` and what limitations does it have?

**Answer:**
`nuxi generate` crawls all routes (starting from `/` and following `<NuxtLink>` references) and outputs static HTML/JSON for each.

Limitations:
- Pages requiring per-request server logic don't fit (e.g. user dashboards)
- Dynamic routes need explicit listing or crawling
- Can't access HTTP-only cookies/headers at build time
- Total build time scales with route count

For dynamic routes:
```ts
export default defineNuxtConfig({
  nitro: {
    prerender: {
      routes: ['/sitemap.xml', '/blog/post-1', '/blog/post-2'],
      crawlLinks: true,
    },
  },
});
```

For thousands of pages, hybrid rendering with ISR or on-demand revalidation usually beats full prerendering.

---

### Q29. What is hydration and what are common hydration mismatches?

**Answer:**
Hydration: making the static SSR HTML interactive by mounting Vue on top of it. Vue diffs the SSR markup with what it would have rendered and warns on mismatches.

Common causes:
- `Date.now()`, `Math.random()` differing on server and client
- Browser-only globals (`window`, `localStorage`) accessed during SSR
- Different timezone formatting between server and client
- Conditional rendering based on `process.client`/`process.server` without `<ClientOnly>`

Fixes:
- Defer to `onMounted` or use `<ClientOnly>`
- Use `useState` to keep server and client in sync
- For dates, format on the server only and pass strings down

---

## Server Engine (Nitro)

### Q30. What is Nitro?

**Answer:**
Nitro is Nuxt's universal server engine. It powers SSR, API routes, server middleware, and adapts the build output to many deployment targets (Node.js, Vercel, Netlify, Cloudflare Workers, Deno, AWS Lambda, etc.).

It's a separate framework that ships with Nuxt and can be used standalone (`nitropack`).

Features:
- File-based API and middleware routing
- Auto-imported server utilities
- Storage layer (KV-style)
- Cache layer
- Plugin system
- Multi-target builds via `preset`

---

### Q31. How do you create API routes?

**Answer:**

```ts
// server/api/users.get.ts
export default defineEventHandler(async (event) => {
  const users = await db.user.findMany();
  return users;
});
```

```ts
// server/api/users/[id].ts
export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id');
  const method = getMethod(event);
  if (method === 'GET') return await db.user.findUnique({ where: { id } });
  if (method === 'DELETE') return await db.user.delete({ where: { id } });
});
```

Routing:
- `server/api/foo.ts` → `/api/foo`
- `server/api/foo.get.ts` → `GET /api/foo` only
- `server/api/foo.post.ts` → `POST /api/foo` only
- `server/api/users/[id].ts` → `/api/users/:id`
- `server/routes/feed.xml.ts` → `/feed.xml` (no `/api` prefix)

Helpers: `getQuery`, `readBody`, `getHeader`, `setCookie`, `sendRedirect`, `createError`.

---

### Q32. How do you handle errors in API routes?

**Answer:**

```ts
export default defineEventHandler((event) => {
  if (!isAllowed(event)) {
    throw createError({
      statusCode: 403,
      statusMessage: 'Forbidden',
      data: { reason: 'Insufficient permissions' },
    });
  }
});
```

`createError` produces a structured response. With `useFetch`, the client receives `error.value` populated. Use `data` for payload, hide internals with `fatal: false`.

---

### Q33. What is server middleware vs route middleware?

**Answer:**

| | Route middleware (`middleware/`) | Server middleware (`server/middleware/`) |
|---|---|---|
| Runs in | Vue/page lifecycle | Nitro server (every request) |
| Affects | Page navigation | All HTTP responses (incl. assets) |
| Used for | Auth gates, redirects in client | Headers, logging, request mutation |

```ts
// middleware/auth.ts
export default defineNuxtRouteMiddleware((to) => {
  const user = useUser();
  if (!user.value) return navigateTo('/login');
});
```

```ts
// server/middleware/log.ts
export default defineEventHandler((event) => {
  console.log(`[${event.node.req.method}] ${event.node.req.url}`);
});
```

Server middleware always runs; route middleware runs only when a page is being navigated to.

---

### Q34. How does Nitro storage work?

**Answer:**

```ts
// nuxt.config.ts
nitro: {
  storage: {
    cache: { driver: 'redis', host: 'localhost' },
    db: { driver: 'fs', base: './.data' },
  },
}
```

```ts
// server/api/cache-test.ts
export default defineEventHandler(async () => {
  const storage = useStorage('cache');
  let data = await storage.getItem<User[]>('users');
  if (!data) {
    data = await fetchUsers();
    await storage.setItem('users', data);
  }
  return data;
});
```

Drivers: memory (default), fs, redis, cloudflare-kv, vercel-kv, github, http, etc. Unifies caching/persistence across deployment targets.

---

### Q35. What is `cachedEventHandler` and `defineCachedFunction`?

**Answer:**

```ts
export default cachedEventHandler(
  async (event) => {
    return await expensiveQuery();
  },
  {
    maxAge: 60 * 5,
    swr: true,
    name: 'product-list',
    getKey: (event) => getQuery(event).category as string,
  }
);
```

Built-in caching with stale-while-revalidate. Persists in the Nitro storage layer. Combine with `routeRules` for HTTP-level caching plus function-level memoization.

---

## Middleware

### Q36. How do you build authentication middleware?

**Answer:**

```ts
// middleware/auth.global.ts (runs on every route)
export default defineNuxtRouteMiddleware(async (to) => {
  const { user, fetchUser } = useAuth();
  if (!user.value) await fetchUser();
  if (!user.value && to.path !== '/login') {
    return navigateTo(`/login?redirect=${to.fullPath}`);
  }
  if (to.meta.requiresAdmin && user.value?.role !== 'admin') {
    abortNavigation(createError({ statusCode: 403, message: 'Forbidden' }));
  }
});
```

Naming:
- `*.global.ts` — runs for every route
- `auth.ts` — opt-in via `definePageMeta({ middleware: ['auth'] })`

Use server middleware to attach the user to the event context, then read it in API routes.

For full auth, use modules: `nuxt-auth-utils`, `@sidebase/nuxt-auth`, or integrate Auth.js / Clerk / Supabase.

---

### Q37. Can middleware call APIs?

**Answer:**
Yes, but consider where it runs:

```ts
export default defineNuxtRouteMiddleware(async (to) => {
  // Runs on server during SSR and on client during navigation
  const { data: profile } = await useFetch('/api/profile');
  if (!profile.value) return navigateTo('/login');
});
```

`useFetch` works in middleware. Be aware of latency — every navigation pays this cost. Cache via `useState` if appropriate.

---

## Modules and Ecosystem

### Q38. What are Nuxt modules?

**Answer:**
Modules extend Nuxt at the framework level: registering plugins, components, composables, server routes, middleware, build hooks. Installed via `modules` in config.

```ts
export default defineNuxtConfig({
  modules: [
    '@nuxtjs/tailwindcss',
    '@pinia/nuxt',
    '@nuxt/image',
    '@nuxt/content',
    'nuxt-auth-utils',
  ],
});
```

Popular modules:

| Module | Purpose |
|--------|---------|
| `@nuxt/image` | Optimized `<NuxtImg>`, `<NuxtPicture>` with providers |
| `@nuxt/content` | File-based CMS (Markdown, YAML, JSON) |
| `@nuxtjs/tailwindcss` | Tailwind integration |
| `@pinia/nuxt` | Pinia state management |
| `@nuxtjs/i18n` | Internationalization |
| `@vueuse/nuxt` | VueUse composables auto-import |
| `@nuxt/eslint` | ESLint integration |
| `@nuxt/test-utils` | Testing helpers |
| `nuxt-security` | Security headers |
| `@nuxtjs/seo` | SEO bundle (sitemap, robots, og-image) |

---

### Q39. What is `@nuxt/image`?

**Answer:**

```vue
<NuxtImg
  src="/hero.jpg"
  width="1200" height="600"
  sizes="sm:100vw md:50vw lg:1200px"
  format="webp"
  loading="lazy"
  placeholder
/>

<NuxtPicture
  src="/photo.jpg"
  formats="avif,webp"
  sizes="sm:100vw md:1024px"
/>
```

Generates responsive `srcset`, modern formats (AVIF, WebP), placeholders. Providers include local, Cloudinary, Vercel, Netlify, IPX (default), imgix, Cloudflare. Integrates with the chosen platform's image optimization service.

---

### Q40. What is `@nuxt/content`?

**Answer:**
File-based content management — write Markdown/MDC in `content/`, query like a database.

```
content/
├── 1.index.md
└── blog/
    ├── 1.first-post.md
    └── 2.second-post.md
```

```vue
<script setup>
const { data: post } = await useAsyncData('post', () =>
  queryContent('blog', 'first-post').findOne()
);

const { data: posts } = await useAsyncData('posts', () =>
  queryContent('blog').sort({ date: -1 }).limit(10).find()
);
</script>

<template>
  <ContentRenderer :value="post" />
</template>
```

Supports MDC (Markdown Components) — inline Vue components in Markdown. Great for blogs and documentation.

---

## Plugins and Runtime

### Q41. What are Nuxt plugins?

**Answer:**
Files in `plugins/` that run during app initialization. Use to register Vue plugins, inject helpers, or set up libraries.

```ts
// plugins/posthog.client.ts
export default defineNuxtPlugin((nuxtApp) => {
  const { public: { posthogKey } } = useRuntimeConfig();
  const posthog = posthogJs.init(posthogKey);
  return { provide: { posthog } };
});
```

```vue
<script setup>
const { $posthog } = useNuxtApp();
$posthog.capture('page_view');
</script>
```

Filename suffixes:
- `*.client.ts` — client only
- `*.server.ts` — server only
- (no suffix) — both

Order: alphabetical, or set explicitly via `parallel`/`enforce`.

---

### Q42. What's the difference between runtime config and app config?

**Answer:**

| | `runtimeConfig` | `appConfig` |
|---|---|---|
| Where | `nuxt.config.ts` | `app.config.ts` |
| Source | Env vars | Code |
| Mutable at runtime | Yes (server side) | No (compile-time, hydrated to client) |
| Use for | Secrets, API URLs, env-specific values | Theme, UI defaults, feature flags |
| Access | `useRuntimeConfig()` | `useAppConfig()` |
| Public/private split | `public` exposed to client; rest server-only | All public |

```ts
// nuxt.config.ts
runtimeConfig: {
  apiSecret: '',                           // server only
  public: { apiBase: '/api' },             // exposed to client
}
// override via NUXT_API_SECRET, NUXT_PUBLIC_API_BASE env vars

// app.config.ts
export default defineAppConfig({
  theme: { primary: '#3b82f6' },
});
```

Never put secrets in `app.config.ts` or in `public.*` — they're shipped to the client.

---

### Q43. How do you provide global helpers?

**Answer:**

```ts
// plugins/dayjs.ts
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
dayjs.extend(relativeTime);

export default defineNuxtPlugin(() => ({
  provide: { dayjs },
}));
```

```vue
<script setup>
const { $dayjs } = useNuxtApp();
const formatted = $dayjs(post.publishedAt).fromNow();
</script>
```

Type augmentation:
```ts
// types/nuxt.d.ts
declare module '#app' {
  interface NuxtApp { $dayjs: typeof dayjs }
}
```

---

## SEO and Meta

### Q44. How do you set page titles and meta tags?

**Answer:**

```vue
<script setup>
useSeoMeta({
  title: 'Blog Post Title',
  description: 'Concise summary',
  ogTitle: 'Blog Post Title',
  ogDescription: 'Concise summary',
  ogImage: 'https://example.com/og.jpg',
  ogUrl: 'https://example.com/post',
  twitterCard: 'summary_large_image',
  robots: 'index, follow',
});

useHead({
  link: [{ rel: 'canonical', href: 'https://example.com/post' }],
  script: [{ type: 'application/ld+json', innerHTML: JSON.stringify(jsonLd) }],
});
</script>
```

`useSeoMeta` is type-safe and handles flat camelCase keys. `useHead` is more flexible for arbitrary tags.

For dynamic titles based on data:
```ts
const { data: post } = await useFetch(`/api/posts/${slug}`);
useSeoMeta({
  title: () => post.value?.title,
  description: () => post.value?.excerpt,
});
```

---

### Q45. How do you generate a sitemap and robots.txt?

**Answer:**
Use the `@nuxtjs/sitemap` and `@nuxtjs/robots` modules (or the bundle `@nuxtjs/seo`):

```bash
npx nuxi module add @nuxtjs/seo
```

```ts
export default defineNuxtConfig({
  site: {
    url: 'https://example.com',
    name: 'My Site',
  },
});
```

Auto-generates `/sitemap.xml` (crawling routes + adding dynamic ones) and `/robots.txt`. Supports per-route exclusion via `routeRules: { '/admin/**': { robots: false } }`.

---

## Deployment

### Q46. How do you deploy a Nuxt app?

**Answer:**
Choose a Nitro preset matching the platform. Often auto-detected:

| Platform | Preset | Notes |
|----------|--------|-------|
| Node | `node-server` (default) | `node .output/server/index.mjs` |
| Vercel | `vercel` | ISR, edge runtime supported |
| Netlify | `netlify` | Edge functions + ISR |
| Cloudflare Workers | `cloudflare` | Edge runtime, no Node APIs |
| Cloudflare Pages | `cloudflare-pages` | Pages + Functions |
| AWS Lambda | `aws-lambda` | Cold starts apply |
| Deno Deploy | `deno-deploy` | Edge runtime |
| Static | (use `nuxi generate`) | Any static host |

```bash
# Force a preset
NITRO_PRESET=cloudflare npm run build
```

The build output (`.output/`) is self-contained. Generated `nitro.json` describes the deployment target.

---

### Q47. How do you reduce cold starts on serverless?

**Answer:**
- Choose edge runtimes (Cloudflare Workers, Vercel Edge) — no cold starts
- Minimize dependencies in `server/` — every import increases bundle size
- Use `routeRules` to prerender or cache pages so handlers run less often
- Externalize heavy SDKs and lazy-load
- Profile with `nuxt build --analyze`

---

### Q48. How do you implement environment-specific config?

**Answer:**

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  $production: {
    routeRules: { '/**': { isr: 3600 } },
  },
  $development: {
    routeRules: { '/**': { isr: false } },
  },
  runtimeConfig: {
    apiSecret: '',
    public: { apiBase: '' },
  },
});
```

`$production` / `$development` / `$test` blocks merge environment-specific overrides into the base config.

Env vars override `runtimeConfig`:
```
NUXT_API_SECRET=xxx
NUXT_PUBLIC_API_BASE=https://api.example.com
```

Use `.env` files for local development.

---

## Migration and Comparisons

### Q49. Nuxt 2 vs Nuxt 3 — what changed?

**Answer:**

| | Nuxt 2 | Nuxt 3 |
|---|---|---|
| Vue version | Vue 2 | Vue 3 |
| Composition API | Plugin (`@nuxtjs/composition-api`) | Native |
| Bundler | Webpack | Vite (Webpack optional) |
| Server | Connect/Express | Nitro |
| TypeScript | Opt-in | First-class |
| `asyncData`/`fetch` | Page-level options | `useFetch`/`useAsyncData` composables |
| Module ecosystem | Modules v2 | Modules v3 (rewritten) |
| Performance | Slower builds | Significantly faster (Vite + Nitro) |
| Auto-imports | Components only | Components, composables, utils, Vue/Nuxt APIs |
| File-based API routes | Via `serverMiddleware` | First-class `server/` directory |

Migration via `Nuxt Bridge` (intermediate step) or direct rewrite. Most apps need substantial rework.

---

### Q50. Nuxt vs Next.js — comparison?

**Answer:**

| | Nuxt 3 | Next.js (App Router) |
|---|---|---|
| Framework | Vue 3 | React |
| Bundler | Vite | Turbopack/Webpack |
| Server | Nitro (multi-target) | Custom (Vercel-optimized, Node) |
| Server Components | Server-only `.server.vue` (different model) | RSC (full graph distinction) |
| Streaming | Yes | Yes (Suspense) |
| Data fetching | `useFetch`/`useAsyncData` | RSC + `fetch`, `cache`, `server actions` |
| API routes | `server/api/*` | `app/api/*/route.ts` |
| Hybrid rendering | `routeRules` | Page configs (`dynamic`, `revalidate`) |
| Edge support | All major platforms | Vercel-first, others via adapters |
| Image | `@nuxt/image` | `next/image` |
| State | `useState`, Pinia | Context, Zustand, etc. |

Both support SSR, SSG, ISR, hybrid, edge. Nuxt is more deployment-agnostic; Next is tightly coupled to Vercel patterns. RSC and Server Actions in Next have no exact parity in Nuxt 3 — Nuxt favors universal components plus typed RPC via Nitro.

---

### Q51. When would you choose Nuxt over plain Vue + Vite?

**Answer:**
Choose Nuxt when you need:
- SSR / SSG / hybrid rendering
- SEO-critical content
- Server-side API routes within the same project
- Authentication-aware page rendering
- A shared full-stack codebase (TypeScript types from `server/` to client)
- File-based routing conventions
- A robust deployment story across providers

Choose plain Vue + Vite when:
- Building a heavy SPA (admin panels, dashboards behind auth)
- SEO is not relevant
- You want minimum framework opinions
- You already have a backend API and don't need server-side rendering or BFF logic

---

### Q52. How do you test a Nuxt app?

**Answer:**

```bash
npm install -D @nuxt/test-utils vitest @vue/test-utils happy-dom
```

```ts
// my.test.ts
import { describe, it, expect } from 'vitest';
import { mountSuspended } from '@nuxt/test-utils/runtime';
import MyComponent from '~/components/MyComponent.vue';

describe('MyComponent', () => {
  it('renders', async () => {
    const wrapper = await mountSuspended(MyComponent);
    expect(wrapper.text()).toContain('Hello');
  });
});
```

End-to-end:
```ts
import { setup, $fetch } from '@nuxt/test-utils/e2e';

await setup({ host: 'http://localhost:3000' });
const html = await $fetch('/');
expect(html).toContain('Welcome');
```

For full E2E flows, use Playwright or Cypress alongside.

---

### Q53. How do you handle errors and 404s?

**Answer:**

Custom error page:
```vue
<!-- error.vue -->
<script setup>
const props = defineProps<{ error: { statusCode: number; message: string } }>();
const handleError = () => clearError({ redirect: '/' });
</script>

<template>
  <div>
    <h1>{{ error.statusCode }}</h1>
    <p>{{ error.message }}</p>
    <button @click="handleError">Go home</button>
  </div>
</template>
```

Throw structured errors:
```ts
throw createError({
  statusCode: 404,
  statusMessage: 'Page Not Found',
  fatal: true,  // shows error page instead of inline
});
```

In components, errors during `<script setup>` `await` propagate. Use `try/catch` for handled errors, `showError()` to trigger the error page.

---

### Q54. What performance tools and tips for Nuxt?

**Answer:**

- **Bundle analysis**: `nuxi analyze`
- **Lazy components**: prefix with `Lazy`: `<LazyHeavyChart />` — splits into separate chunk
- **Lazy-load images**: `<NuxtImg loading="lazy" />`
- **`<NuxtLink>` prefetching** — disable for less-likely-clicked links: `<NuxtLink no-prefetch>`
- **`payloadExtraction: true`** for SSG sites — separate JSON payloads from HTML
- **`experimental.payloadExtraction`**, **`experimental.viewTransition`**, **`experimental.componentIslands`** — opt-in modern features
- **`useAsyncData`'s `getCachedData`** — reuse previously fetched data on navigation
- **Edge runtime** — pick `cloudflare` or similar preset to remove cold starts
- **`nitro.compressPublicAssets`** — Brotli/gzip pre-compress for static files
- **Avoid global middleware where possible** — every navigation pays cost
- **Cache server endpoints** with `cachedEventHandler` and Nitro storage drivers

---

### Q55. What is `<ClientOnly>` and when do you need it?

**Answer:**

```vue
<ClientOnly>
  <BrowserOnlyChart :data="data" />
  <template #fallback>
    <div class="skeleton" />
  </template>
</ClientOnly>
```

Renders children only on the client. Required when:
- Component depends on `window` / `localStorage`
- Third-party widgets that mutate the DOM independently
- Avoiding hydration mismatches for client-derived UI (e.g. responsive class based on `window.innerWidth`)

Prefer `.client.vue` suffix for whole components. Use `<ClientOnly>` for inline portions inside otherwise-SSR templates.

---

### Q56. How do you implement a basic auth flow end-to-end in Nuxt?

**Answer:**

Server endpoint:
```ts
// server/api/login.post.ts
export default defineEventHandler(async (event) => {
  const { email, password } = await readBody(event);
  const user = await verifyCredentials(email, password);
  if (!user) throw createError({ statusCode: 401 });
  await setUserSession(event, { user });
  return { ok: true };
});
```

Composable:
```ts
// composables/useAuth.ts
export const useAuth = () => {
  const { data: user, refresh } = useFetch('/api/me', { key: 'me' });
  async function login(email: string, password: string) {
    await $fetch('/api/login', { method: 'POST', body: { email, password } });
    await refresh();
    await navigateTo('/dashboard');
  }
  async function logout() {
    await $fetch('/api/logout', { method: 'POST' });
    await refresh();
    await navigateTo('/');
  }
  return { user, login, logout };
};
```

Middleware:
```ts
// middleware/auth.ts
export default defineNuxtRouteMiddleware(() => {
  const { user } = useAuth();
  if (!user.value) return navigateTo('/login');
});
```

For production, use battle-tested modules like `nuxt-auth-utils` (cookie sessions) or `@sidebase/nuxt-auth` (Auth.js).
