# Next.js Interview Questions — Complete Q&A Guide

**Focus:** Next.js 13+ (App Router), Pages Router, rendering strategies, data fetching, performance, and deployment.

Read each answer to understand the concept, then study the code to see how it works in a real project.

---

## 1. Core Concepts

## Q1. What is Next.js and why use it over plain React?

**Answer:**

Next.js is a React framework built on top of React that adds production-ready features: server-side rendering, static generation, file-based routing, image optimization, API routes, and bundler-level optimizations. Plain React is a client library; you would have to wire all this yourself.

```jsx
// app/page.tsx — that is it, this is a route at "/"
export default function Home() {
  return <h1>Hello Next.js</h1>;
}
```

## Q2. What is hydration?

**Answer:**

Hydration is the process where the browser takes server-rendered HTML and attaches React's event listeners and state on top, turning a static page into an interactive React app. Without hydration, the page would look right but no clicks or state would work.

```jsx
// Server renders <button>0</button> as static HTML
// Hydration attaches the onClick handler so it becomes interactive
'use client';
import { useState } from 'react';

export default function Counter() {
  const [n, setN] = useState(0);
  return <button onClick={() => setN(n + 1)}>{n}</button>;
}
```

## Q3. What are the two router systems in Next.js?

**Answer:**

Next.js has the older **Pages Router** (files in `pages/`) and the newer **App Router** (files in `app/`). App Router is the recommended approach in modern Next.js. It supports React Server Components, nested layouts, streaming, and co-located data fetching. Pages Router is still supported but receives fewer new features.

| | Pages Router | App Router |
| --- | --- | --- |
| Folder | `pages/` | `app/` |
| Data fetching | `getServerSideProps`, `getStaticProps` | `fetch()` directly in components |
| Layouts | Custom `_app.js` | Nested `layout.tsx` files |
| Server Components | No | Yes |

---

## 2. Rendering Strategies

## Q4. Explain SSR (Server-Side Rendering).

**Answer:**

SSR generates the HTML for a page on every request. The server runs your component, fetches data, and returns full HTML. The browser hydrates and the page becomes interactive. Use SSR when content is personalized or changes frequently.

```jsx
// app/profile/page.tsx — runs on every request
export default async function Profile() {
  const user = await fetch('https://api.example.com/me', { cache: 'no-store' })
    .then(r => r.json());
  return <h1>Hello {user.name}</h1>;
}
```

## Q5. Explain SSG (Static Site Generation).

**Answer:**

SSG generates HTML at build time. Pages are pre-rendered once and served as static files from a CDN, making them extremely fast. Use SSG for content that does not change often (marketing pages, blog posts).

```jsx
// app/about/page.tsx — built once at build time
export default async function About() {
  const data = await fetch('https://cms.example.com/about').then(r => r.json());
  return <article>{data.body}</article>;
}
```

By default in App Router, pages are statically generated unless something forces dynamic rendering (cookies, headers, `cache: 'no-store'`).

## Q6. What is ISR (Incremental Static Regeneration)?

**Answer:**

ISR lets you statically generate pages and revalidate them on a schedule, without rebuilding the whole site. The first request after the revalidation window gets a stale page while a new one regenerates in the background.

```jsx
// app/blog/[slug]/page.tsx
export const revalidate = 60; // re-generate at most every 60 seconds

export default async function Post({ params }) {
  const post = await fetch(`https://cms/api/posts/${params.slug}`).then(r => r.json());
  return <article>{post.body}</article>;
}
```

## Q7. Difference between SSR, SSG, ISR, and CSR?

**Answer:**

| Strategy | When HTML is generated | Best for |
| --- | --- | --- |
| SSR | On every request | Personalized data |
| SSG | At build time | Content that rarely changes |
| ISR | At build, refreshed in background | Content that changes hourly/daily |
| CSR | In the browser after JS loads | Highly interactive apps behind login |

```jsx
// Force SSR
export const dynamic = 'force-dynamic';

// Force SSG
export const dynamic = 'force-static';

// ISR
export const revalidate = 3600;
```

---

## 3. App Router (Next.js 13+)

## Q8. What are React Server Components (RSC)?

**Answer:**

Server Components render only on the server. They never ship JavaScript to the browser, can directly access databases or the file system, and use `async/await`. By default, every component in `app/` is a Server Component.

```jsx
// app/users/page.tsx — Server Component (no "use client")
import { db } from '@/lib/db';

export default async function Users() {
  const users = await db.user.findMany();
  return (
    <ul>
      {users.map(u => <li key={u.id}>{u.name}</li>)}
    </ul>
  );
}
```

## Q9. What is a Client Component?

**Answer:**

A Client Component runs in the browser. It can use hooks (`useState`, `useEffect`), event handlers, and browser-only APIs. Mark it by adding `'use client'` at the top of the file.

```jsx
'use client';
import { useState } from 'react';

export default function Counter() {
  const [n, setN] = useState(0);
  return <button onClick={() => setN(n + 1)}>{n}</button>;
}
```

## Q10. How do you use Client Components inside Server Components?

**Answer:**

Server Components can import and render Client Components. The reverse — passing a Server Component into a Client Component as a regular import — is not allowed. Instead, pass Server Components as `children` props.

```jsx
// Server Component
import ClientWrapper from './ClientWrapper';
import ServerSidebar from './ServerSidebar';

export default function Page() {
  return (
    <ClientWrapper>
      <ServerSidebar />
    </ClientWrapper>
  );
}
```

## Q11. What is the `layout.tsx` file?

**Answer:**

`layout.tsx` defines a UI shell that wraps pages in its folder and all nested folders. Layouts persist across navigations — they do not re-mount, which preserves state in things like sidebars.

```jsx
// app/layout.tsx (root layout)
export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <Header />
        <main>{children}</main>
      </body>
    </html>
  );
}

// app/dashboard/layout.tsx (nested layout)
export default function DashboardLayout({ children }) {
  return (
    <div className="flex">
      <Sidebar />
      <section>{children}</section>
    </div>
  );
}
```

## Q12. What is streaming in Next.js?

**Answer:**

Streaming sends parts of a page to the browser as soon as they are ready, instead of waiting for everything to finish. Combined with React Suspense, slow pieces can show a fallback while fast pieces render immediately.

```jsx
import { Suspense } from 'react';
import SlowList from './SlowList';

export default function Page() {
  return (
    <>
      <h1>Dashboard</h1>
      <Suspense fallback={<p>Loading list...</p>}>
        <SlowList />
      </Suspense>
    </>
  );
}
```

## Q13. What is `loading.tsx`?

**Answer:**

`loading.tsx` is a special file that Next.js automatically wraps in `<Suspense>` for the matching route. It shows while the page's Server Components are loading.

```jsx
// app/dashboard/loading.tsx
export default function Loading() {
  return <div className="skeleton">Loading dashboard...</div>;
}
```

## Q14. What is `error.tsx`?

**Answer:**

`error.tsx` is a special file that handles runtime errors thrown in the matching route. It must be a Client Component and receives `error` and `reset` props.

```jsx
// app/dashboard/error.tsx
'use client';

export default function Error({ error, reset }) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <p>{error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

## Q15. What is Next.js Middleware?

**Answer:**

Middleware runs before a request finishes loading. It runs on the Edge runtime and can rewrite, redirect, or set cookies and headers. Use it for auth checks, A/B testing, or i18n.

```jsx
// middleware.ts
import { NextResponse } from 'next/server';

export function middleware(request) {
  const token = request.cookies.get('token');
  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: '/dashboard/:path*',
};
```

---

## 4. Pages Router

## Q16. What is `getServerSideProps`?

**Answer:**

`getServerSideProps` runs on every request in the Pages Router and passes its returned props to the page. The page is server-rendered with that data.

```jsx
// pages/profile.js
export async function getServerSideProps(context) {
  const user = await fetch('https://api/me').then(r => r.json());
  return { props: { user } };
}

export default function Profile({ user }) {
  return <h1>Hello {user.name}</h1>;
}
```

## Q17. What is `getStaticProps`?

**Answer:**

`getStaticProps` runs at build time. The result becomes a static HTML page. Add `revalidate` for ISR.

```jsx
export async function getStaticProps() {
  const posts = await fetch('https://cms/api/posts').then(r => r.json());
  return {
    props: { posts },
    revalidate: 60, // ISR: regenerate at most every 60s
  };
}
```

## Q18. What is `getStaticPaths`?

**Answer:**

For dynamic routes generated at build time, `getStaticPaths` tells Next.js which paths to pre-render.

```jsx
// pages/blog/[slug].js
export async function getStaticPaths() {
  const posts = await fetch('https://cms/api/posts').then(r => r.json());
  return {
    paths: posts.map(p => ({ params: { slug: p.slug } })),
    fallback: 'blocking', // build new pages on demand
  };
}
```

---

## 5. Data Fetching

## Q19. How does data fetching work in the App Router?

**Answer:**

In App Router, you fetch directly inside async Server Components using `fetch()`. Next.js extends `fetch` with caching options.

```jsx
export default async function Page() {
  // Cached at build time (default)
  const a = await fetch('https://api/static').then(r => r.json());

  // Re-fetched every request
  const b = await fetch('https://api/dynamic', { cache: 'no-store' }).then(r => r.json());

  // Re-fetched at most every 60s
  const c = await fetch('https://api/isr', { next: { revalidate: 60 } }).then(r => r.json());

  return <div>...</div>;
}
```

## Q20. What is request memoization in Next.js?

**Answer:**

If multiple components call `fetch()` with the same URL during the same render, Next.js deduplicates the request automatically. This means you can fetch the same data in a layout and a page without making two network calls.

```jsx
// Both call the same fetch — only one network request happens
async function getUser() {
  return fetch('/api/user').then(r => r.json());
}

// In layout.tsx and page.tsx, both call getUser()
```

## Q21. How do you use TanStack Query (React Query) with Next.js?

**Answer:**

TanStack Query is best for client-side state. Wrap the app in a `QueryClientProvider` from a Client Component.

```jsx
// app/providers.tsx
'use client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';

export function Providers({ children }) {
  const [client] = useState(() => new QueryClient());
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
```

---

## 6. Routing

## Q22. How does file-based routing work in App Router?

**Answer:**

Each folder in `app/` represents a URL segment. A `page.tsx` inside the folder makes that segment routable. Square brackets create dynamic segments.

```
app/
  page.tsx              → /
  about/page.tsx        → /about
  blog/[slug]/page.tsx  → /blog/anything
  users/[...path]/page.tsx → /users/a/b/c (catch-all)
```

```jsx
// app/blog/[slug]/page.tsx
export default function Post({ params }) {
  return <h1>Post: {params.slug}</h1>;
}
```

## Q23. What are route groups?

**Answer:**

A folder wrapped in parentheses like `(marketing)` is a route group. It organizes files without adding to the URL.

```
app/
  (marketing)/
    about/page.tsx   → /about
    contact/page.tsx → /contact
  (app)/
    dashboard/page.tsx → /dashboard
```

Useful when you want different layouts for different sections.

## Q24. How do you handle navigation programmatically?

**Answer:**

Use the `useRouter` hook from `next/navigation` (App Router) or `next/router` (Pages Router).

```jsx
'use client';
import { useRouter } from 'next/navigation';

export default function LoginButton() {
  const router = useRouter();
  return <button onClick={() => router.push('/dashboard')}>Login</button>;
}
```

For declarative navigation, use `<Link>`:

```jsx
import Link from 'next/link';
<Link href="/about">About</Link>
```

---

## 7. Performance and Optimization

## Q25. How does Next.js optimize images?

**Answer:**

The `<Image>` component automatically resizes, lazy-loads, sets dimensions to prevent layout shift, and serves modern formats like WebP/AVIF.

```jsx
import Image from 'next/image';

<Image
  src="/photo.jpg"
  alt="Photo"
  width={800}
  height={600}
  priority // load eagerly for above-the-fold images
/>
```

## Q26. How does Next.js optimize fonts?

**Answer:**

`next/font` self-hosts Google Fonts at build time, eliminates render-blocking requests, and prevents layout shift by reserving space.

```jsx
import { Inter } from 'next/font/google';
const inter = Inter({ subsets: ['latin'] });

export default function Layout({ children }) {
  return <html className={inter.className}>{children}</html>;
}
```

## Q27. What is the `next/script` component?

**Answer:**

`<Script>` is an enhanced `<script>` tag with loading strategies (`beforeInteractive`, `afterInteractive`, `lazyOnload`).

```jsx
import Script from 'next/script';

<Script src="https://www.googletagmanager.com/gtag/js?id=GA_ID" strategy="afterInteractive" />
```

## Q28. What is prefetching in Next.js?

**Answer:**

`<Link>` automatically prefetches the linked route in the background when the link enters the viewport, making navigation feel instant.

```jsx
<Link href="/dashboard" prefetch={true}>Dashboard</Link>
// prefetch={false} disables it
```

---

## 8. API Routes

## Q29. How do you create API routes in App Router?

**Answer:**

Create a `route.ts` file inside `app/api/...`. Export functions named after HTTP methods.

```jsx
// app/api/users/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  const users = await db.user.findMany();
  return NextResponse.json(users);
}

export async function POST(request) {
  const body = await request.json();
  const user = await db.user.create({ data: body });
  return NextResponse.json(user, { status: 201 });
}
```

## Q30. What is a Route Handler?

**Answer:**

Route Handlers are functions exported from `route.ts` files in the App Router. They replace Pages Router's `pages/api/*` and use Web standard `Request`/`Response` objects.

```jsx
// app/api/products/[id]/route.ts
export async function GET(request, { params }) {
  const product = await db.product.findUnique({ where: { id: params.id } });
  return Response.json(product);
}
```

---

## 9. Authentication

## Q31. How do you implement authentication in Next.js?

**Answer:**

Use a library like NextAuth (Auth.js), Clerk, or Lucia. NextAuth is the most popular open-source option.

```jsx
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth';
import GitHub from 'next-auth/providers/github';

const handler = NextAuth({
  providers: [GitHub({ clientId: process.env.GITHUB_ID, clientSecret: process.env.GITHUB_SECRET })],
});

export { handler as GET, handler as POST };
```

```jsx
// In a Server Component
import { getServerSession } from 'next-auth';

export default async function Page() {
  const session = await getServerSession();
  if (!session) return <p>Please log in</p>;
  return <p>Hello {session.user.name}</p>;
}
```

## Q32. Where should JWT tokens be stored in Next.js?

**Answer:**

Use `httpOnly` cookies set by the server. They are not accessible to JavaScript, mitigating XSS. Avoid `localStorage` for tokens — any XSS bug exposes them.

```jsx
// In a Route Handler
import { cookies } from 'next/headers';

cookies().set('token', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  path: '/',
  maxAge: 60 * 60 * 24,
});
```

---

## 10. Server Actions

## Q33. What are Server Actions?

**Answer:**

Server Actions are async functions that run on the server but can be called directly from Client or Server Components. They replace the need for many simple API endpoints.

```jsx
// app/actions.ts
'use server';
import { revalidatePath } from 'next/cache';

export async function addTodo(formData) {
  const text = formData.get('text');
  await db.todo.create({ data: { text } });
  revalidatePath('/todos');
}
```

```jsx
// app/todos/page.tsx
import { addTodo } from '@/app/actions';

export default function Page() {
  return (
    <form action={addTodo}>
      <input name="text" />
      <button type="submit">Add</button>
    </form>
  );
}
```

## Q34. How do you revalidate data in Next.js?

**Answer:**

Use `revalidatePath` (revalidate by route) or `revalidateTag` (revalidate by cache tag).

```jsx
import { revalidatePath, revalidateTag } from 'next/cache';

// After mutating data
revalidatePath('/posts');
revalidateTag('posts');
```

```jsx
// Tag a fetch
fetch('/api/posts', { next: { tags: ['posts'] } });
```

---

## 11. Deployment

## Q35. How do you deploy a Next.js app?

**Answer:**

Vercel is the official platform and supports all features out of the box. You can also deploy:
- Standalone Node server (`output: 'standalone'`)
- Static export (`output: 'export'`) for fully static sites
- Docker containers
- Self-hosted with `next start`

```jsx
// next.config.js
module.exports = {
  output: 'standalone', // builds a minimal server in .next/standalone
};
```

## Q36. What are the Next.js output modes?

**Answer:**

| Mode | Use case |
| --- | --- |
| Default | Hybrid: SSR + SSG + ISR |
| `output: 'export'` | Pure static site, no Node server |
| `output: 'standalone'` | Self-contained server folder for Docker |

## Q37. What environment variables are available in Next.js?

**Answer:**

Variables in `.env.local` are available on the server. Only those prefixed with `NEXT_PUBLIC_` are exposed to the browser bundle.

```bash
DATABASE_URL=postgres://...        # server only
NEXT_PUBLIC_API_URL=https://api... # server + browser
```

```jsx
// Server: works everywhere
console.log(process.env.DATABASE_URL);

// Client: only NEXT_PUBLIC_ vars work
console.log(process.env.NEXT_PUBLIC_API_URL);
```

---

## 12. Caching

## Q38. What caching layers does Next.js have?

**Answer:**

Next.js has multiple cache layers in App Router:

1. **Request memoization** — within one render, `fetch()` deduplicates calls.
2. **Data Cache** — persistent server cache for `fetch()` results.
3. **Full Route Cache** — built static HTML at build time.
4. **Router Cache** — client-side cache of visited routes.

```jsx
// Opt out of Data Cache for this fetch
fetch(url, { cache: 'no-store' });

// Tag-based revalidation
fetch(url, { next: { tags: ['products'] } });
```

## Q39. How do you opt out of caching for a route?

**Answer:**

Add `dynamic = 'force-dynamic'` or use uncached APIs like `cookies()` or `headers()`.

```jsx
// app/dashboard/page.tsx
export const dynamic = 'force-dynamic';

// Or, just by reading cookies:
import { cookies } from 'next/headers';
const c = cookies(); // makes the route dynamic
```

---

## 13. Configuration

## Q40. What does `next.config.js` do?

**Answer:**

`next.config.js` configures the framework: image domains, redirects, rewrites, headers, experimental features, etc.

```jsx
module.exports = {
  images: {
    remotePatterns: [{ protocol: 'https', hostname: 'cdn.example.com' }],
  },
  redirects: async () => [
    { source: '/old', destination: '/new', permanent: true },
  ],
  headers: async () => [
    {
      source: '/(.*)',
      headers: [{ key: 'X-Frame-Options', value: 'DENY' }],
    },
  ],
};
```

## Q41. What are dynamic segments and catch-all routes?

**Answer:**

`[id]` is a dynamic segment, `[...slug]` is catch-all, `[[...slug]]` is optional catch-all.

```
app/users/[id]/page.tsx        → /users/1
app/docs/[...slug]/page.tsx    → /docs/a/b/c
app/shop/[[...slug]]/page.tsx  → /shop and /shop/a/b
```

## Q42. What is `generateStaticParams`?

**Answer:**

Used in dynamic routes to tell Next.js which paths to pre-render at build time. Replaces `getStaticPaths` from the Pages Router.

```jsx
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await fetch('https://cms/posts').then(r => r.json());
  return posts.map(p => ({ slug: p.slug }));
}

export default function Post({ params }) {
  return <h1>{params.slug}</h1>;
}
```

## Q43. What is `generateMetadata`?

**Answer:**

`generateMetadata` returns metadata (title, description, og tags) dynamically per page. The static version is `export const metadata`.

```jsx
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }) {
  const post = await getPost(params.slug);
  return {
    title: post.title,
    description: post.excerpt,
    openGraph: { images: [post.cover] },
  };
}
```

---

## 14. Forms and Mutations

## Q44. How do you handle form submissions in App Router?

**Answer:**

Use Server Actions with the `action` prop on `<form>`. They progressively enhance — work without JavaScript.

```jsx
async function createPost(formData) {
  'use server';
  await db.post.create({ data: { title: formData.get('title') } });
}

export default function NewPost() {
  return (
    <form action={createPost}>
      <input name="title" />
      <button>Save</button>
    </form>
  );
}
```

## Q45. What is `useFormState` (now `useActionState`)?

**Answer:**

`useActionState` (renamed from `useFormState`) lets you read the result of a Server Action in a Client Component, useful for showing validation errors.

```jsx
'use client';
import { useActionState } from 'react';

export default function Form({ action }) {
  const [state, formAction] = useActionState(action, { error: null });
  return (
    <form action={formAction}>
      <input name="email" />
      {state.error && <p>{state.error}</p>}
      <button>Submit</button>
    </form>
  );
}
```

---

## 15. Internationalization

## Q46. How do you implement i18n in Next.js?

**Answer:**

Use middleware to detect locale and route groups for locale-prefixed paths. Libraries like `next-intl` simplify this.

```jsx
// middleware.ts
import createMiddleware from 'next-intl/middleware';

export default createMiddleware({
  locales: ['en', 'bn'],
  defaultLocale: 'en',
});
```

```
app/
  [locale]/
    page.tsx   → /en, /bn
    about/page.tsx
```

---

## 16. Testing

## Q47. How do you test Next.js apps?

**Answer:**

Use Jest or Vitest for unit tests, React Testing Library for components, and Playwright or Cypress for end-to-end tests.

```jsx
// Component test
import { render, screen } from '@testing-library/react';
import Home from '@/app/page';

test('renders heading', () => {
  render(<Home />);
  expect(screen.getByRole('heading')).toBeInTheDocument();
});
```

## Q48. How do you mock Next.js navigation in tests?

**Answer:**

Mock `next/navigation` to return stub functions.

```jsx
import { vi } from 'vitest';

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  usePathname: () => '/',
}));
```

---

## 17. Advanced

## Q49. What is the difference between `not-found.tsx` and `error.tsx`?

**Answer:**

`not-found.tsx` renders when `notFound()` is called or no route matches. `error.tsx` renders when an error is thrown.

```jsx
// app/blog/[slug]/page.tsx
import { notFound } from 'next/navigation';

export default async function Post({ params }) {
  const post = await getPost(params.slug);
  if (!post) notFound();
  return <article>{post.body}</article>;
}
```

```jsx
// app/blog/[slug]/not-found.tsx
export default function NotFound() {
  return <h1>Post not found</h1>;
}
```

## Q50. What are parallel routes and intercepting routes?

**Answer:**

**Parallel routes** (`@folder`) render multiple pages in the same layout simultaneously, useful for dashboards.

```
app/
  layout.tsx (receives @analytics and @team props)
  @analytics/page.tsx
  @team/page.tsx
```

```jsx
export default function Layout({ children, analytics, team }) {
  return <>{children}{analytics}{team}</>;
}
```

**Intercepting routes** (`(..)folder`) intercept a route to show it in a modal while keeping the URL. Used for "view photo in modal without navigating away" patterns.

## Q51. What is `unstable_cache`?

**Answer:**

`unstable_cache` caches the result of a non-`fetch` function (like a database query). It supports tags and revalidation.

```jsx
import { unstable_cache } from 'next/cache';

const getPosts = unstable_cache(
  async () => await db.post.findMany(),
  ['posts'],
  { revalidate: 60, tags: ['posts'] }
);
```

## Q52. How do you use cookies in Next.js?

**Answer:**

Use `cookies()` from `next/headers` in Server Components and Route Handlers.

```jsx
import { cookies } from 'next/headers';

// Read
const token = cookies().get('token')?.value;

// Set (only in Route Handlers / Server Actions)
cookies().set('token', 'abc', { httpOnly: true });

// Delete
cookies().delete('token');
```

## Q53. What is `headers()`?

**Answer:**

`headers()` reads the incoming request headers in a Server Component or Route Handler. Calling it makes the route dynamic.

```jsx
import { headers } from 'next/headers';

export default function Page() {
  const userAgent = headers().get('user-agent');
  return <p>You are using {userAgent}</p>;
}
```

## Q54. How do you redirect in Next.js?

**Answer:**

```jsx
// In a Server Component or Server Action
import { redirect } from 'next/navigation';

if (!user) redirect('/login');

// In Middleware
import { NextResponse } from 'next/server';
return NextResponse.redirect(new URL('/login', request.url));

// In Client Component
'use client';
import { useRouter } from 'next/navigation';
const router = useRouter();
router.push('/login');
```

## Q55. How do you handle dynamic OG images?

**Answer:**

Use `ImageResponse` from `next/og` to generate images at the edge.

```jsx
// app/og/route.tsx
import { ImageResponse } from 'next/og';

export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const title = searchParams.get('title') ?? 'Default';
  return new ImageResponse(
    (<div style={{ fontSize: 80 }}>{title}</div>),
    { width: 1200, height: 630 }
  );
}
```

## Q56. How do you stream UI with Suspense in App Router?

**Answer:**

Wrap async components in `<Suspense>`. The HTML for that boundary streams in once the promise resolves.

```jsx
import { Suspense } from 'react';

export default function Page() {
  return (
    <>
      <Header />
      <Suspense fallback={<Skeleton />}>
        <SlowChart />
      </Suspense>
    </>
  );
}
```

## Q57. What is partial prerendering?

**Answer:**

Partial Prerendering (PPR) renders the static shell at build time and streams in dynamic parts at request time, combining the speed of SSG with the freshness of SSR. It is enabled experimentally.

```jsx
// next.config.js
module.exports = {
  experimental: { ppr: 'incremental' },
};

// app/page.tsx
export const experimental_ppr = true;
```

## Q58. How does Next.js handle CSS?

**Answer:**

You can use:
- Global CSS (imported in `app/layout.tsx`)
- CSS Modules (`Component.module.css`)
- Tailwind CSS
- CSS-in-JS (with caveats for Server Components)

```jsx
// app/page.module.css
.title { color: red; }

// app/page.tsx
import styles from './page.module.css';
<h1 className={styles.title}>Hi</h1>
```

## Q59. How do you handle SEO in Next.js?

**Answer:**

Use the metadata API for titles and meta tags, generate sitemaps and robots dynamically.

```jsx
// app/layout.tsx
export const metadata = {
  title: { default: 'My Site', template: '%s — My Site' },
  description: 'Site description',
};

// app/sitemap.ts
export default async function sitemap() {
  const posts = await getPosts();
  return posts.map(p => ({
    url: `https://site.com/blog/${p.slug}`,
    lastModified: p.updatedAt,
  }));
}

// app/robots.ts
export default function robots() {
  return { rules: [{ userAgent: '*', allow: '/' }] };
}
```

## Q60. How do you debug Next.js performance issues?

**Answer:**

- Use the built-in build report (`next build`) to see bundle sizes per route.
- Use Vercel Analytics or Sentry for production telemetry.
- Use `<Suspense>` boundaries to isolate slow parts.
- Use `cache` and `revalidate` correctly to avoid unnecessary fetches.

```bash
# Analyze bundle
ANALYZE=true next build
```

## Q61. What is `dynamic` import vs `next/dynamic`?

**Answer:**

`next/dynamic` is a wrapper around `React.lazy` plus Suspense, with extra options like disabling SSR.

```jsx
import dynamic from 'next/dynamic';

const Map = dynamic(() => import('./Map'), {
  ssr: false, // Map uses window, only render client-side
  loading: () => <p>Loading map...</p>,
});
```

## Q62. How do you handle CORS in Next.js API routes?

**Answer:**

Set headers manually in the response or globally in `next.config.js`.

```jsx
export async function GET() {
  return new Response(JSON.stringify({ ok: true }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  });
}
```

## Q63. How do you use environment-specific configuration?

**Answer:**

Next.js loads `.env`, `.env.local`, `.env.development`, `.env.production` automatically. Local files override base files.

```bash
.env                  # always loaded
.env.local            # always loaded, gitignored
.env.production       # only in production
.env.development      # only in dev
```

---

## 18. Quick Reference

| File | Purpose |
| ---- | ------- |
| `page.tsx` | Page UI |
| `layout.tsx` | Persistent layout shell |
| `loading.tsx` | Suspense fallback |
| `error.tsx` | Error boundary |
| `not-found.tsx` | 404 UI |
| `route.ts` | API endpoint |
| `middleware.ts` | Request middleware |
| `template.tsx` | Re-mounting layout |

| Hook / API | Use |
| ---------- | --- |
| `useRouter` | Navigate |
| `usePathname` | Get current path |
| `useSearchParams` | Read query string |
| `useParams` | Read route params |
| `cookies()` | Read/write cookies (server) |
| `headers()` | Read headers (server) |
| `redirect()` | Server-side redirect |
| `notFound()` | Trigger 404 |
| `revalidatePath` | Invalidate route cache |
| `revalidateTag` | Invalidate by tag |
