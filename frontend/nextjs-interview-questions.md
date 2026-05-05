# Next.js Interview Questions

**Level:** Mid to Senior  
**Topics:** App Router, Pages Router, Rendering Strategies, Data Fetching, Performance, Deployment

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Rendering Strategies](#rendering-strategies)
3. [App Router (Next.js 13+)](#app-router-nextjs-13)
4. [Pages Router](#pages-router)
5. [Data Fetching](#data-fetching)
6. [Routing](#routing)
7. [Performance and Optimization](#performance-and-optimization)
8. [API Routes](#api-routes)
9. [Authentication](#authentication)
10. [Deployment](#deployment)

---

## Core Concepts

### Q1. What is Next.js and why use it over plain React?

**Answer:**
Next.js is a React framework with built-in:
- file-based routing
- server-side rendering (SSR)
- static site generation (SSG)
- incremental static regeneration (ISR)
- API routes (backend in same project)
- image and font optimization
- middleware support
- built-in TypeScript support

Plain React requires manual setup for all of these. Next.js is production-ready out of the box and improves SEO, performance, and developer experience.

---

### Q2. What is hydration?

**Answer:**
The process where React takes over server-rendered HTML and attaches event listeners to make it interactive.

Flow:
1. Server renders HTML
2. Browser downloads and displays HTML immediately (fast FCP)
3. JS bundle downloads
4. React "hydrates" the HTML — binds state and event handlers
5. Page becomes interactive (TTI)

Hydration mismatch: if server HTML differs from client render, React logs a warning and re-renders on the client.

---

### Q3. What are the two router systems in Next.js?

**Answer:**

| Feature | Pages Router | App Router |
|---------|-------------|------------|
| Directory | `pages/` | `app/` |
| Default component type | Client | Server |
| Data fetching | `getServerSideProps`, `getStaticProps` | `async` components, `fetch` |
| Layouts | `_app.js` | `layout.tsx` (nested) |
| Streaming | No | Yes |
| Available since | v1 | v13 |

**App Router is the current standard.** Pages Router still supported.

---

## Rendering Strategies

### Q4. Explain SSR (Server-Side Rendering).

**Answer:**
Page HTML is generated on the server for each incoming request.

**When to use:**
- dynamic content that changes per request
- user-specific pages (dashboard, profile)
- SEO-required pages with live data

**Pages Router:**
```jsx
export async function getServerSideProps(context) {
  const data = await fetchUser(context.params.id);
  return { props: { data } };
}
```

**App Router:**
```jsx
// app/users/[id]/page.tsx - Server Component by default
async function UserPage({ params }) {
  const user = await fetchUser(params.id);
  return <UserProfile user={user} />;
}
```

---

### Q5. Explain SSG (Static Site Generation).

**Answer:**
Pages are generated at build time. Same HTML served to all users.

**When to use:**
- blog posts, docs, marketing pages
- data that doesn't change often
- maximum performance

**Pages Router:**
```jsx
export async function getStaticProps() {
  const posts = await fetchPosts();
  return { props: { posts } };
}

export async function getStaticPaths() {
  return { paths: [{ params: { id: '1' } }], fallback: false };
}
```

**App Router:**
```jsx
// Force static generation
export const dynamic = 'force-static';

async function BlogPost({ params }) {
  const post = await fetch(`/api/posts/${params.id}`, {
    cache: 'force-cache'
  }).then(r => r.json());
  return <Article post={post} />;
}
```

---

### Q6. What is ISR (Incremental Static Regeneration)?

**Answer:**
Static pages that can be regenerated in the background after a set time. Combines SSG performance with fresh data.

**Pages Router:**
```jsx
export async function getStaticProps() {
  return {
    props: { data },
    revalidate: 60, // regenerate at most once per minute
  };
}
```

**App Router:**
```jsx
const data = await fetch(url, { next: { revalidate: 60 } }).then(r => r.json());
```

**On-demand revalidation:**
```jsx
import { revalidatePath, revalidateTag } from 'next/cache';
revalidatePath('/blog');
revalidateTag('posts');
```

---

### Q7. Difference between SSR, SSG, ISR, and CSR?

**Answer:**

| Strategy | When rendered | Per request? | Fresh data? | Use case |
|----------|--------------|--------------|-------------|----------|
| SSG | Build time | No | No (at build) | Blogs, docs |
| ISR | Build + background | No | After revalidation | Products, news |
| SSR | Each request | Yes | Always | User dashboards |
| CSR | Client browser | On client | On fetch | Heavy interactive apps |

---

## App Router (Next.js 13+)

### Q8. What are React Server Components (RSC)?

**Answer:**
Components that run exclusively on the server. They:
- do not add to client JS bundle
- can directly access DB, file system, env vars
- cannot use state, effects, or browser APIs
- are the default in App Router

```tsx
// Server Component (default in app/)
async function ProductList() {
  const products = await db.query('SELECT * FROM products');
  return <ul>{products.map(p => <li key={p.id}>{p.name}</li>)}</ul>;
}
```

---

### Q9. What is a Client Component?

**Answer:**
A component with `'use client'` directive at the top. Runs on both server (initial render) and client (hydration).

Required when:
- using hooks (`useState`, `useEffect`)
- browser APIs (`window`, `document`)
- event listeners
- interactive UI

```tsx
'use client';

import { useState } from 'react';

export function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}
```

---

### Q10. How do you use Client Components inside Server Components?

**Answer:**
You can import Client Components into Server Components. The `'use client'` boundary marks where the transition happens.

```tsx
// ServerPage.tsx (Server Component)
import { InteractiveFilter } from './InteractiveFilter'; // Client Component

async function ProductPage() {
  const categories = await fetchCategories(); // server-only fetch
  return (
    <div>
      <InteractiveFilter categories={categories} />
    </div>
  );
}
```

You cannot import Server Components into Client Components.

---

### Q11. What is the `layout.tsx` file?

**Answer:**
Defines UI shared across multiple pages. Layouts persist across navigation (don't re-mount).

```
app/
├── layout.tsx          ← root layout (required)
├── dashboard/
│   ├── layout.tsx      ← dashboard-specific layout
│   └── page.tsx
```

```tsx
// app/layout.tsx
export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

---

### Q12. What is streaming in Next.js?

**Answer:**
Server progressively sends HTML chunks to the browser as they're ready. Users see content faster.

```tsx
import { Suspense } from 'react';

export default function Page() {
  return (
    <div>
      <h1>Dashboard</h1>
      <Suspense fallback={<Skeleton />}>
        <SlowDataComponent />   {/* streams in when ready */}
      </Suspense>
    </div>
  );
}
```

---

### Q13. What is `loading.tsx`?

**Answer:**
Automatically shows a loading UI while the page's async Server Component is fetching data.

```
app/
├── dashboard/
│   ├── loading.tsx   ← shown while page.tsx is loading
│   └── page.tsx
```

Implemented via React Suspense under the hood.

---

### Q14. What is `error.tsx`?

**Answer:**
A Client Component that catches errors within its route segment and displays a fallback.

```tsx
'use client';

export default function Error({ error, reset }) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

---

### Q15. What is Next.js Middleware?

**Answer:**
Runs before a request is completed. Executes at the edge (CDN-level).

Use cases:
- authentication checks
- redirects
- A/B testing
- locale detection

```tsx
// middleware.ts
import { NextResponse } from 'next/server';

export function middleware(request) {
  const token = request.cookies.get('token');
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
}

export const config = {
  matcher: '/dashboard/:path*',
};
```

---

## Pages Router

### Q16. What is `getServerSideProps`?

**Answer:**
Fetches data server-side on every request. Return value becomes page props.

```jsx
export async function getServerSideProps(context) {
  const { params, req, res, query } = context;
  const data = await fetchData(params.id);
  
  if (!data) {
    return { notFound: true };
  }
  
  return { props: { data } };
}
```

---

### Q17. What is `getStaticProps`?

**Answer:**
Fetches data at build time. Used with SSG.

```jsx
export async function getStaticProps() {
  const posts = await fetchPosts();
  return {
    props: { posts },
    revalidate: 3600, // ISR: regenerate every hour
  };
}
```

---

### Q18. What is `getStaticPaths`?

**Answer:**
Required with dynamic routes in `getStaticProps`. Defines which paths to pre-render.

```jsx
export async function getStaticPaths() {
  const posts = await fetchAllPosts();
  return {
    paths: posts.map(p => ({ params: { id: p.id.toString() } })),
    fallback: 'blocking', // or false / true
  };
}
```

`fallback` options:
- `false` — 404 for unknown paths
- `true` — show fallback, then generate in background
- `'blocking'` — wait for generation on first request

---

## Data Fetching

### Q19. How does data fetching work in the App Router?

**Answer:**
Use `async`/`await` directly in Server Components. Next.js extends the native `fetch` API.

```tsx
// Cached (default)
const data = await fetch('/api/data').then(r => r.json());

// No cache
const data = await fetch('/api/data', { cache: 'no-store' }).then(r => r.json());

// Revalidate every 60s
const data = await fetch('/api/data', { next: { revalidate: 60 } }).then(r => r.json());

// Tagged for on-demand revalidation
const data = await fetch('/api/data', { next: { tags: ['products'] } }).then(r => r.json());
```

---

### Q20. What is request memoization in Next.js?

**Answer:**
Next.js automatically deduplicates `fetch` requests with the same URL and options within a single render tree. Multiple components fetching the same data → only one network request.

```tsx
// Component A
const user = await fetch('/api/user'); // fetches

// Component B (same render)
const user = await fetch('/api/user'); // uses memoized result
```

---

### Q21. How do you use TanStack Query (React Query) with Next.js?

**Answer:**
Pair server-side prefetching with client-side hydration:

```tsx
// Server Component
const queryClient = new QueryClient();
await queryClient.prefetchQuery({ queryKey: ['posts'], queryFn: fetchPosts });

return (
  <HydrationBoundary state={dehydrate(queryClient)}>
    <PostList />
  </HydrationBoundary>
);

// Client Component
const { data } = useQuery({ queryKey: ['posts'], queryFn: fetchPosts });
```

---

## Routing

### Q22. How does file-based routing work in App Router?

**Answer:**
The directory structure maps to URL structure.

```
app/
├── page.tsx              → /
├── about/page.tsx        → /about
├── blog/
│   ├── page.tsx          → /blog
│   └── [slug]/page.tsx   → /blog/:slug
├── (marketing)/          → route group (no URL segment)
│   └── landing/page.tsx  → /landing
└── [...slug]/page.tsx    → /catch-all-path
```

---

### Q23. What are route groups?

**Answer:**
Folders wrapped in `()` that organize routes without affecting the URL structure.

```
app/
├── (auth)/
│   ├── login/page.tsx    → /login
│   └── register/page.tsx → /register
└── (dashboard)/
    └── settings/page.tsx → /settings
```

Useful for applying different layouts to different sections.

---

### Q24. How do you handle navigation programmatically?

**Answer:**

```tsx
// App Router
import { useRouter } from 'next/navigation';
const router = useRouter();
router.push('/dashboard');
router.replace('/login');
router.back();

// Link component
import Link from 'next/link';
<Link href="/about">About</Link>
<Link href="/blog" prefetch={false}>Blog</Link>
```

---

## Performance and Optimization

### Q25. How does Next.js optimize images?

**Answer:**
The `next/image` component:
- serves correct size for each device (responsive)
- converts to modern formats (WebP, AVIF)
- lazy loads by default
- prevents layout shift (requires width/height or fill)
- serves via CDN with caching

```tsx
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="Hero image"
  width={1200}
  height={600}
  priority  // preload above-the-fold images
/>
```

---

### Q26. How does Next.js optimize fonts?

**Answer:**
`next/font` downloads fonts at build time, hosts them on your server, and eliminates layout shift with automatic size fallback.

```tsx
import { Inter } from 'next/font/google';

const inter = Inter({ subsets: ['latin'] });

<body className={inter.className}>
```

No requests to Google fonts in production. Zero FOUC.

---

### Q27. What is the `next/script` component?

**Answer:**
Controls loading strategy for third-party scripts.

```tsx
import Script from 'next/script';

<Script src="https://analytics.js" strategy="lazyOnload" />
```

| Strategy | When loaded |
|----------|------------|
| `beforeInteractive` | Before hydration (blocking) |
| `afterInteractive` | After hydration (default) |
| `lazyOnload` | During browser idle time |
| `worker` | In a web worker |

---

### Q28. What is prefetching in Next.js?

**Answer:**
`<Link>` automatically prefetches linked pages when they appear in the viewport. Page data is downloaded in the background so navigation feels instant.

```tsx
<Link href="/dashboard">Dashboard</Link> // prefetches automatically
<Link href="/rare-page" prefetch={false}>Rare</Link> // disable
```

---

## API Routes

### Q29. How do you create API routes in App Router?

**Answer:**
Create a `route.ts` file inside `app/api/`.

```tsx
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET() {
  const users = await fetchUsers();
  return NextResponse.json(users);
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const user = await createUser(body);
  return NextResponse.json(user, { status: 201 });
}
```

---

### Q30. What is a Route Handler?

**Answer:**
The App Router equivalent of API routes. Supports all HTTP methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS.

```tsx
// app/api/posts/[id]/route.ts
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const post = await getPost(params.id);
  if (!post) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  return NextResponse.json(post);
}
```

---

## Authentication

### Q31. How do you implement authentication in Next.js?

**Answer:**
Common approaches:

**NextAuth.js (Auth.js):** OAuth, email, credentials, session management built-in.
```tsx
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth';
const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
```

**Middleware protection:**
```tsx
// middleware.ts
import { getToken } from 'next-auth/jwt';

export async function middleware(request) {
  const token = await getToken({ req: request });
  if (!token) return NextResponse.redirect(new URL('/login', request.url));
}
```

---

### Q32. Where should JWT tokens be stored in Next.js?

**Answer:**
**HTTP-only cookies** — set by the server, not accessible to JavaScript, protected from XSS.

```tsx
// Set cookie in Route Handler
const response = NextResponse.json({ success: true });
response.cookies.set('token', jwt, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax',
  maxAge: 60 * 60 * 24, // 1 day
});
```

Avoid `localStorage` — vulnerable to XSS.

---

## Deployment

### Q33. How do you deploy a Next.js app?

**Answer:**

**Vercel (easiest):** Zero-config. Automatic SSR, edge functions, image optimization.

**Self-hosted (Node.js server):**
```bash
next build
next start -p 3000
```

**Docker:**
```dockerfile
FROM node:20-alpine
COPY . .
RUN npm ci && npm run build
CMD ["npm", "start"]
```

**Static export (SSG only):**
```bash
next build  # with output: 'export' in next.config.js
# Outputs to /out folder, serve with any static host
```

---

### Q34. What is the Next.js output modes?

**Answer:**

| Mode | Config | Use |
|------|--------|-----|
| Default (Node.js) | — | SSR + SSG, requires Node server |
| Standalone | `output: 'standalone'` | Self-contained, good for Docker |
| Static | `output: 'export'` | Pure static files, no server needed |

---

### Q35. What environment variables are available in Next.js?

**Answer:**

```env
# Only available server-side (default)
DATABASE_URL=postgres://...

# Available client-side too (exposed to browser)
NEXT_PUBLIC_API_URL=https://api.example.com
```

- Variables must be in `.env.local` (gitignored)
- `NEXT_PUBLIC_` prefix exposes to browser
- Server-only variables never sent to client

---

## Quick Reference

| Concept | Pages Router | App Router |
|---------|-------------|------------|
| Data fetching | `getServerSideProps` / `getStaticProps` | `async` component + `fetch` |
| Layouts | `_app.js` | `layout.tsx` |
| Loading UI | manual | `loading.tsx` |
| Error UI | custom `_error.js` | `error.tsx` |
| API | `pages/api/` | `app/api/route.ts` |
| Metadata | `<Head>` | `export const metadata` |
| Middleware | `middleware.ts` | `middleware.ts` |
