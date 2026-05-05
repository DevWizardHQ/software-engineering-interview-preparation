# Tailwind CSS Interview Questions

**Level:** Mid to Senior
**Topics:** Utility-First, Configuration, Theming, JIT, v3/v4, Plugins, Performance, Design Systems

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Configuration and Theming](#configuration-and-theming)
3. [Responsive Design and Modifiers](#responsive-design-and-modifiers)
4. [Dark Mode](#dark-mode)
5. [Components and @apply](#components-and-apply)
6. [JIT, Content, Production Build](#jit-content-production-build)
7. [Plugins and Ecosystem](#plugins-and-ecosystem)
8. [Tailwind v4](#tailwind-v4)
9. [Patterns and Design Systems](#patterns-and-design-systems)
10. [Comparisons and Trade-offs](#comparisons-and-trade-offs)

---

## Fundamentals

### Q1. What is Tailwind CSS?

**Answer:**
Tailwind is a utility-first CSS framework. Instead of pre-styled components, it provides low-level utility classes (`flex`, `pt-4`, `text-center`) that you compose directly in markup.

```html
<button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
  Save
</button>
```

It scans your source files, generates only the utilities you actually use, and outputs a small CSS bundle.

---

### Q2. What is utility-first and why use it?

**Answer:**
Utility-first means building UIs from many small, single-purpose classes rather than a handful of named component classes.

Benefits:
- **No naming overhead** — no `card-header__title--featured` to invent
- **Constraints by default** — spacing/colors come from a design scale, enforcing consistency
- **No dead CSS** — unused utilities aren't shipped
- **Co-location** — markup and styles live together; no CSS file to hunt
- **Refactor confidently** — deleting markup deletes styles

Trade-offs: HTML is verbose, learning curve for class names, less semantic markup.

---

### Q3. How is Tailwind different from Bootstrap?

**Answer:**

| | Tailwind | Bootstrap |
|---|----------|-----------|
| Approach | Utility-first | Component-first |
| Output | Custom design | "Bootstrap look" out of the box |
| JS dependencies | None (use Headless UI / Radix) | jQuery (v4), bundled JS (v5) |
| Bundle size | Tiny (purged) | Larger by default |
| Customization | Configurable design tokens | Sass overrides |
| Lock-in | Low (just CSS classes) | Medium (component conventions) |

Tailwind targets teams building custom designs. Bootstrap targets faster prototyping with a known visual identity.

---

### Q4. How do you install Tailwind in a project?

**Answer:**

For v3:
```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

```js
// tailwind.config.js
module.exports = {
  content: ['./src/**/*.{html,js,jsx,ts,tsx,vue}'],
  theme: { extend: {} },
  plugins: [],
}
```

```css
/* src/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

For v4 (CSS-first):
```bash
npm install tailwindcss @tailwindcss/vite
```

```css
/* index.css */
@import "tailwindcss";
```

No config file required by default in v4.

---

### Q5. What does each `@tailwind` directive do (v3)?

**Answer:**

```css
@tailwind base;       /* Preflight resets and base styles */
@tailwind components; /* User-defined components and plugins */
@tailwind utilities;  /* Utility classes */
```

Order matters because it determines cascade priority — utilities are last so they win.

In v4, this is replaced with a single `@import "tailwindcss";` (which internally uses `@layer`).

---

### Q6. What is Preflight?

**Answer:**
Tailwind's opinionated CSS reset (built on modern-normalize). It:
- removes default margins
- unstyles headings (`h1`-`h6` look like body text)
- resets border styles to allow `border` utilities to work
- makes images block-level by default
- resets list styles

Disable in v3 via `corePlugins: { preflight: false }` or layer scope it. In v4, scope with `@import "tailwindcss/preflight" layer(base);`.

Common gotcha: `<h1>` looks plain — apply `text-3xl font-bold` explicitly. Or use the typography plugin for prose content.

---

### Q7. What are arbitrary values?

**Answer:**
Bracket syntax for one-off values not in your theme:

```html
<div class="top-[117px] grid-cols-[200px_1fr_auto] bg-[#1da1f2]">
<div class="text-[clamp(1rem,2vw,2rem)]">
<div class="grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))]">
```

Also arbitrary properties:
```html
<div class="[mask-type:luminance] [scrollbar-gutter:stable]">
```

And arbitrary variants:
```html
<div class="[&:nth-child(3)]:bg-red-500 [&_p]:mt-4">
<div class="lg:[&:nth-child(3)]:hidden">
```

Use sparingly — if you reach for arbitrary values often, extend the theme instead.

---

## Configuration and Theming

### Q8. How do you customize the theme?

**Answer:**
v3:
```js
module.exports = {
  theme: {
    // overrides default
    screens: { sm: '640px', md: '768px' },
    // extends default (preferred)
    extend: {
      colors: {
        brand: {
          50: '#eff6ff',
          500: '#3b82f6',
          900: '#1e3a8a',
        },
      },
      spacing: { 18: '4.5rem' },
      fontFamily: { display: ['Inter', 'sans-serif'] },
    },
  },
}
```

v4 (CSS-first):
```css
@import "tailwindcss";

@theme {
  --color-brand-500: #3b82f6;
  --spacing-18: 4.5rem;
  --font-display: "Inter", sans-serif;
}
```

`extend` adds without replacing defaults; top-level keys replace the whole namespace.

---

### Q9. How do you define design tokens?

**Answer:**
Tokens are theme values referenced as utilities. Map design system primitives:

```js
extend: {
  colors: {
    primary: 'var(--color-primary)',
    surface: 'var(--color-surface)',
  },
  fontSize: {
    'display-lg': ['3.5rem', { lineHeight: '1.1', letterSpacing: '-0.02em' }],
  },
  borderRadius: {
    'card': '0.875rem',
  },
}
```

Pairing CSS variables with theme values gives runtime theming (dark mode, brand swaps) plus utility ergonomics.

---

### Q10. What's the difference between `theme.extend` and replacing `theme`?

**Answer:**
- Top-level (`theme.colors = {...}`) — **replaces** the default scale entirely. Lose `red-500`, `blue-100`, etc.
- `theme.extend.colors = {...}` — **merges** with defaults. Both your custom colors and the defaults are available.

Use top-level only when you want to enforce a strictly limited palette.

---

### Q11. How do you customize breakpoints?

**Answer:**

```js
theme: {
  screens: {
    sm: '640px',
    md: '768px',
    lg: '1024px',
    xl: '1280px',
    '2xl': '1536px',
    // Custom
    'tablet': '900px',
    'desktop': { 'min': '1100px', 'max': '1599px' },
    'print': { 'raw': 'print' },
  },
}
```

Tailwind is mobile-first: bare classes apply at all sizes; `md:` applies at >= 768px.

In v4, breakpoints are CSS variables: `--breakpoint-md: 48rem;`.

---

## Responsive Design and Modifiers

### Q12. What modifiers does Tailwind support?

**Answer:**
Categories:
- **Responsive**: `sm:`, `md:`, `lg:`, `xl:`, `2xl:`
- **State**: `hover:`, `focus:`, `focus-visible:`, `active:`, `disabled:`, `checked:`, `required:`, `valid:`, `invalid:`, `placeholder-shown:`
- **Group/peer**: `group-hover:`, `peer-checked:`
- **Theme**: `dark:`, `motion-reduce:`, `motion-safe:`, `contrast-more:`, `print:`, `rtl:`, `ltr:`
- **Pseudo-elements**: `before:`, `after:`, `placeholder:`, `marker:`, `selection:`, `file:`
- **Children**: `first:`, `last:`, `odd:`, `even:`, `only:`, `empty:`
- **Has/not (v3.4+)**: `has-[...]:`, `not-[...]:`
- **Data attributes**: `data-[state=open]:`, `aria-[expanded=true]:`

Stack modifiers: `md:hover:focus-visible:bg-blue-500`. Order doesn't change matching but readability matters.

---

### Q13. How do `group` and `peer` modifiers work?

**Answer:**

**`group`** styles children based on a parent's state:

```html
<a href="#" class="group">
  <h3 class="group-hover:text-blue-600">Title</h3>
  <p class="group-hover:underline">Description</p>
</a>
```

**`peer`** styles a sibling based on a previous sibling's state:

```html
<input type="checkbox" class="peer">
<span class="peer-checked:text-green-600">Active</span>
```

Multiple groups: name them.
```html
<div class="group/card">
  <div class="group/header">
    <h3 class="group-hover/card:text-red group-hover/header:underline">
```

`peer` requires DOM order — the peer must come *before* the styled element.

---

### Q14. How do you target child elements without classes?

**Answer:**

Built-in:
```html
<ul class="divide-y divide-gray-200 [&>li]:py-2">
```

Arbitrary variants:
```html
<div class="[&>p]:mb-2 [&_a]:text-blue-600">
  <p>Para</p>
  <a href="#">Link</a>
</div>
```

`>` direct child, ` ` (or `_` in arbitrary variants) any descendant.

For nested content (e.g. markdown HTML), prefer the `@tailwindcss/typography` plugin's `prose` class.

---

### Q15. What does `:has()` enable in Tailwind?

**Answer:**

```html
<div class="has-[input:checked]:bg-green-50">
  <input type="checkbox" />
</div>
```

Style a parent based on what it contains. Useful for forms, conditionally highlighted cards, navigation indicators based on active children — without JS state syncing to classes.

---

## Dark Mode

### Q16. What dark mode strategies does Tailwind support?

**Answer:**

**Media-based** (system preference, default):
```js
// tailwind.config.js
darkMode: 'media',
```
```html
<div class="bg-white dark:bg-gray-900">
```

**Class-based** (user toggleable):
```js
darkMode: 'class',
```
```html
<html class="dark"><body class="bg-white dark:bg-gray-900">
```

**Selector-based / data attribute** (custom):
```js
darkMode: ['selector', '[data-theme="dark"]'],
```

Class strategy is most flexible — pair with system preference detection plus override toggle. v4 uses `@variant dark (...)`.

---

### Q17. How do you implement a dark mode toggle without flash?

**Answer:**
Inline script before any rendering:

```html
<script>
  const t = localStorage.getItem('theme');
  if (t === 'dark' || (!t && matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.classList.add('dark');
  }
</script>
```

Place in `<head>` synchronously, before stylesheets. Toggle component:

```js
function setTheme(mode) {
  if (mode === 'dark') document.documentElement.classList.add('dark');
  else document.documentElement.classList.remove('dark');
  localStorage.setItem('theme', mode);
}
```

Add `color-scheme: dark` for native control theming:
```css
.dark { color-scheme: dark; }
```

---

## Components and @apply

### Q18. What is `@apply` and when should you use it?

**Answer:**
`@apply` lets you inline utilities into a custom CSS rule:

```css
@layer components {
  .btn-primary {
    @apply px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700;
  }
}
```

Use when:
- you need to expose styles to non-utility consumers (third-party form libraries that take a className)
- a complex selector requires utilities that can't easily be expressed in markup
- abstracting deeply repeated combinations and component extraction (React/Vue) isn't enough

Anti-pattern: don't recreate Bootstrap by `@apply`-ing every utility into named classes — you lose Tailwind's main benefit. Prefer component composition (React/Vue/template partials) instead.

---

### Q19. Components versus utilities — when to make a component?

**Answer:**

Use **utilities directly** for unique, one-off layouts. Use **a component** (template partial, React/Vue component) for repeated, named UI like buttons or cards. Use **`@apply`** sparingly when neither markup-level reuse works.

```jsx
// Better than .btn-primary CSS class
function Button({ variant = 'primary', children }) {
  return (
    <button className={cn(
      'px-4 py-2 rounded font-medium transition',
      variant === 'primary' && 'bg-blue-600 text-white hover:bg-blue-700',
      variant === 'secondary' && 'bg-gray-200 text-gray-900 hover:bg-gray-300',
    )}>
      {children}
    </button>
  );
}
```

Tools: `clsx`, `classnames`, `cva` (class-variance-authority), `tailwind-merge` (deduplicates conflicting classes).

---

### Q20. What is `tailwind-merge` and why use it?

**Answer:**
Naive class merging breaks because Tailwind's last-wins rule depends on source order in CSS, not class string order:

```js
clsx('px-2', 'px-4')  // "px-2 px-4" — both apply, CSS order wins (which?)
```

`tailwind-merge` understands Tailwind semantics:

```js
import { twMerge } from 'tailwind-merge';
twMerge('px-2 px-4')              // "px-4"
twMerge('text-red-500', 'text-blue-500') // "text-blue-500"
```

Combined with `clsx`:
```js
import { cn } from '@/lib/utils';  // wrapper around clsx + twMerge
cn('px-2 py-1', isActive && 'bg-blue-500', className)
```

Essential when allowing components to accept overriding `className` props.

---

### Q21. What is CVA (class-variance-authority)?

**Answer:**
A utility for building typed component variants:

```js
import { cva } from 'class-variance-authority';

const button = cva('rounded font-medium transition', {
  variants: {
    variant: {
      primary: 'bg-blue-600 text-white hover:bg-blue-700',
      secondary: 'bg-gray-200 text-gray-900',
    },
    size: {
      sm: 'px-2 py-1 text-sm',
      md: 'px-4 py-2',
      lg: 'px-6 py-3 text-lg',
    },
  },
  compoundVariants: [
    { variant: 'primary', size: 'lg', class: 'shadow-lg' },
  ],
  defaultVariants: { variant: 'primary', size: 'md' },
});

<button className={button({ variant: 'secondary', size: 'sm' })}>
```

Used heavily in shadcn/ui-style component libraries.

---

## JIT, Content, Production Build

### Q22. What is JIT mode?

**Answer:**
Just-in-Time compilation — Tailwind generates only the utilities found in your source on every change. In v3 it became the default and the only mode; in v4 the engine is rebuilt for even faster JIT.

Benefits:
- arbitrary values work (`top-[117px]`)
- every variant available without bloating output
- tiny CSS in dev and prod
- fast incremental builds

---

### Q23. How does content scanning work?

**Answer:**
Tailwind reads files matching `content` globs and extracts strings that look like classnames via regex:

```js
content: [
  './src/**/*.{html,js,jsx,ts,tsx,vue,svelte}',
  './node_modules/some-ui-lib/**/*.js',
]
```

In v4, scanning is automatic with sensible defaults; configurable via `@source`.

Critical rule: **Tailwind cannot detect dynamically constructed class names**.

```jsx
// Broken — `bg-${color}-500` is not a literal in source
<div className={`bg-${color}-500`}>

// Fix — use full class strings
const colorMap = { red: 'bg-red-500', blue: 'bg-blue-500' };
<div className={colorMap[color]}>
```

For external sources: include them in `content` or use `safelist`.

---

### Q24. What is the safelist?

**Answer:**
Forces Tailwind to include classes regardless of detection:

```js
safelist: [
  'bg-red-500',
  { pattern: /bg-(red|green|blue)-(100|500|900)/, variants: ['hover', 'md'] },
]
```

Use only for classes coming from CMS content, dynamic data, or external libraries. Overuse defeats purging.

---

### Q25. How do you optimize Tailwind for production?

**Answer:**
- Ensure `content` globs are accurate so unused classes are purged
- Use `cssnano` / `lightningcss` for minification (built into v4)
- Enable Brotli/gzip on the server
- Inline critical CSS for above-the-fold (frameworks usually do this)
- Audit final CSS file size; typical apps land under 10–30 KB compressed
- Don't pull entire icon sets via classes — ship as components
- Avoid massive arbitrary variant abuse, which can blow up class count

---

## Plugins and Ecosystem

### Q26. What is the typography plugin?

**Answer:**
`@tailwindcss/typography` provides the `prose` class for styling markdown/CMS HTML:

```html
<article class="prose prose-lg dark:prose-invert prose-blue">
  <!-- raw HTML from markdown -->
</article>
```

Features:
- Sensible defaults for headings, lists, code, blockquotes
- Modifiers: `prose-sm`, `prose-lg`, `prose-xl`
- Color themes: `prose-slate`, `prose-blue`, etc.
- Dark mode: `prose-invert`
- Element overrides: `prose-headings:text-red-500 prose-a:text-blue-600`

Indispensable for blogs, docs, CMS-rendered content.

---

### Q27. What does the forms plugin do?

**Answer:**
`@tailwindcss/forms` resets form-control styling so utilities work consistently across browsers (without it, native styles override Tailwind on `<select>`, `<input type="checkbox">`, etc.).

```js
plugins: [require('@tailwindcss/forms')],
```

Strategies:
- `'base'` — global reset
- `'class'` — opt-in via `form-input`, `form-select`, etc.

Pairs well with `@tailwindcss/typography` (which scopes its resets to `.prose`).

---

### Q28. What is Headless UI and how does it pair with Tailwind?

**Answer:**
Headless UI (Tailwind Labs) provides accessible, unstyled UI primitives — Dialog, Menu, Combobox, Listbox, Disclosure, Transition — for React and Vue. You bring the styling, they bring the accessibility (focus management, ARIA, keyboard nav).

```jsx
import { Menu } from '@headlessui/react';

<Menu>
  <Menu.Button className="px-4 py-2 bg-blue-600 text-white rounded">Options</Menu.Button>
  <Menu.Items className="absolute mt-2 bg-white shadow-lg rounded">
    <Menu.Item>{({ active }) => (
      <a className={`block px-4 py-2 ${active ? 'bg-gray-100' : ''}`} href="#">Edit</a>
    )}</Menu.Item>
  </Menu.Items>
</Menu>
```

Alternatives: Radix UI, React Aria, Ariakit. shadcn/ui combines Radix with Tailwind for copy-paste components.

---

### Q29. How do you write a custom Tailwind plugin?

**Answer:**

```js
// tailwind.config.js
const plugin = require('tailwindcss/plugin');

module.exports = {
  plugins: [
    plugin(function({ addUtilities, addComponents, addVariant, theme, matchUtilities }) {
      // Static utilities
      addUtilities({
        '.text-balance': { 'text-wrap': 'balance' },
      });

      // Dynamic utilities
      matchUtilities(
        { 'tab': (value) => ({ tabSize: value }) },
        { values: theme('tabSize') }
      );

      // Custom variant
      addVariant('hocus', ['&:hover', '&:focus']);

      // Component
      addComponents({
        '.btn': {
          padding: theme('spacing.4'),
          borderRadius: theme('borderRadius.md'),
        },
      });
    }),
  ],
};
```

In v4, plugins are CSS-based: `@plugin "...";` plus `@utility` for custom utilities.

---

## Tailwind v4

### Q30. What's new in Tailwind v4?

**Answer:**

| Feature | v3 | v4 |
|---------|----|----|
| Config | `tailwind.config.js` | CSS-first via `@theme` |
| Engine | PostCSS-based | Oxide (Rust) — much faster |
| Setup | `@tailwind base/components/utilities` | Single `@import "tailwindcss"` |
| CSS variables | Optional | All theme values exposed as CSS vars by default |
| Container queries | Plugin | Built-in |
| `@starting-style`, color-mix, native cascade layers | Limited | First-class |
| Browser target | Wide | Modern (Safari 16.4+, Chrome 111+) |
| Dynamic utility values | Limited | Most utilities accept arbitrary values without brackets in some cases |
| Build speed | Fast | 5–10× faster |

---

### Q31. How does the v4 CSS-first config work?

**Answer:**

```css
@import "tailwindcss";

@theme {
  --color-brand: oklch(64% 0.22 264);
  --color-brand-dark: oklch(54% 0.22 264);
  --font-display: "Inter Variable", sans-serif;
  --spacing: 0.25rem; /* base unit */
  --breakpoint-3xl: 120rem;
}

@layer base {
  html { color-scheme: light dark; }
}

@plugin "@tailwindcss/typography";

@source "../node_modules/some-lib/dist";
```

Each `--color-*`, `--spacing-*`, `--font-*`, `--breakpoint-*` value automatically generates corresponding utilities (`bg-brand`, `font-display`, `3xl:flex`, etc.).

No JS config needed for most projects. JS config still supported via `@config "./tailwind.config.js";`.

---

### Q32. Are there migration concerns from v3 to v4?

**Answer:**
- **Browser support**: v4 requires modern browsers (Safari 16.4, Chrome 111, Firefox 128). Not backward compatible.
- **Removed deprecated utilities** (`bg-opacity-*`, `text-opacity-*` — use `bg-black/50` syntax).
- **Default color palette tweaked** (uses oklch for better gradients).
- **`@tailwind` directives replaced** with `@import "tailwindcss"`.
- **Default border color changed** from gray-200 to currentColor — explicitly add a color or set `--color-border-DEFAULT`.
- **Ring default** changed from blue-500 to currentColor and 3px to 1px.
- **Migration tool**: `npx @tailwindcss/upgrade@next`.

Verify visual diffs in a staging environment before merging.

---

## Patterns and Design Systems

### Q33. How do you build a component library on Tailwind?

**Answer:**
1. Define design tokens in theme (colors, spacing, radii, shadows, fonts).
2. Build atomic components (Button, Input, Card) using utilities + `cva` for variants.
3. Use Headless UI / Radix for behavioral primitives.
4. Wrap with `tailwind-merge` for override-friendly `className` props.
5. Export typed variants and provide Storybook coverage.
6. Include the library's source files in consumers' `content` glob (or distribute compiled CSS).

shadcn/ui's "copy-paste rather than install" model is popular — components live in your repo and you customize freely.

---

### Q34. How do you handle responsive grid patterns?

**Answer:**

```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
```

Auto-fit/fill via arbitrary values:
```html
<div class="grid gap-4 grid-cols-[repeat(auto-fill,minmax(200px,1fr))]">
```

Container queries (v4 built-in / v3 plugin):
```html
<div class="@container">
  <div class="grid grid-cols-1 @md:grid-cols-2 @lg:grid-cols-3">
</div>
```

---

### Q35. How do you build a card component?

**Answer:**

```jsx
function Card({ title, body, footer, className }) {
  return (
    <article className={cn(
      'bg-white dark:bg-gray-800',
      'border border-gray-200 dark:border-gray-700',
      'rounded-lg shadow-sm hover:shadow-md transition',
      'p-6 flex flex-col gap-4',
      className
    )}>
      <h3 className="text-lg font-semibold">{title}</h3>
      <p className="text-gray-600 dark:text-gray-300 text-sm">{body}</p>
      {footer && <div className="mt-auto pt-4 border-t">{footer}</div>}
    </article>
  );
}
```

Pattern: structural utilities first (display/spacing), then color, then state, then layout-affecting modifiers.

---

### Q36. How do you build a navbar with mobile menu?

**Answer:**

```jsx
<nav className="bg-white border-b">
  <div className="max-w-7xl mx-auto px-4 flex items-center justify-between h-16">
    <Logo className="h-8" />
    <div className="hidden md:flex gap-6">
      <a href="/products" className="hover:text-blue-600">Products</a>
      <a href="/pricing" className="hover:text-blue-600">Pricing</a>
    </div>
    <button className="md:hidden" onClick={() => setOpen(!open)} aria-label="Menu">
      <MenuIcon />
    </button>
  </div>
  {open && (
    <div className="md:hidden border-t px-4 py-3 space-y-2">
      <a href="/products" className="block">Products</a>
      <a href="/pricing" className="block">Pricing</a>
    </div>
  )}
</nav>
```

Use `Disclosure` from Headless UI for accessible state management.

---

### Q37. How do you create gradients?

**Answer:**

```html
<div class="bg-gradient-to-r from-pink-500 via-red-500 to-yellow-500">
<div class="bg-gradient-to-br from-slate-900 to-slate-700">
<!-- with stops -->
<div class="bg-gradient-to-r from-blue-500 from-10% via-purple-500 via-30% to-pink-500 to-90%">
<!-- arbitrary -->
<div class="bg-[radial-gradient(circle_at_top_left,_var(--tw-gradient-stops))] from-fuchsia-400 to-rose-500">
```

For text:
```html
<h1 class="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
```

In v4, conic and radial gradients are first-class utilities.

---

### Q38. How do you do animations beyond transitions?

**Answer:**

Built-in: `animate-spin`, `animate-ping`, `animate-pulse`, `animate-bounce`.

Custom keyframes:
```js
theme: {
  extend: {
    keyframes: {
      'fade-in-up': {
        '0%': { opacity: '0', transform: 'translateY(10px)' },
        '100%': { opacity: '1', transform: 'translateY(0)' },
      },
    },
    animation: {
      'fade-in-up': 'fade-in-up 0.3s ease-out',
    },
  },
}
```

```html
<div class="animate-fade-in-up">
```

Pair with `motion-safe:` and `motion-reduce:` to respect user preferences.

---

## Comparisons and Trade-offs

### Q39. Tailwind vs CSS Modules — when to choose what?

**Answer:**

| | Tailwind | CSS Modules |
|---|----------|-------------|
| Speed of development | Faster after learning curve | Slower, more naming |
| HTML readability | Verbose | Clean (`className={s.title}`) |
| Constraint enforcement | Built-in design scale | Requires discipline |
| Refactoring | Delete markup → styles gone | Orphan classes accumulate |
| File count | One stylesheet, all utilities | One per component |
| Type safety | Via plugins | Native (typed CSS modules) |
| RSC compatibility | Perfect | Perfect |

For design-system-driven product UIs, Tailwind wins. For one-off heavily styled marketing pages or when designers own CSS, Modules are cleaner.

---

### Q40. Tailwind vs styled-components / Emotion?

**Answer:**

Tailwind is build-time, zero-runtime; styled-components inject styles at runtime (slower, larger bundle, doesn't play well with React Server Components).

Tailwind constrains you to a design scale; styled-components is unbounded (good and bad).

For new React 19/Next.js App Router projects, Tailwind or zero-runtime CSS-in-JS (vanilla-extract, Panda CSS) are the recommended choices over styled-components.

---

### Q41. Common Tailwind anti-patterns?

**Answer:**

1. **Recreating component classes via `@apply`** — defeats the purpose. Use template/component partials.
2. **String-interpolating utility names** — `bg-${color}-500` won't be detected.
3. **Overusing `safelist`** — bloats output.
4. **Tons of arbitrary values** — sign you should extend the theme.
5. **Ignoring `tailwind-merge`** when accepting `className` props — leads to unpredictable overrides.
6. **No design tokens** — directly using `red-500` instead of `danger`. Hard to rebrand.
7. **Skipping accessibility** — `<div onClick>` styled like a button. Tailwind doesn't make it a button.
8. **Forgetting Preflight implications** — headings look unstyled by default; explicitly style them or use `prose`.

---

### Q42. How do you debug missing or unexpected styles?

**Answer:**
- Check `content` globs cover the file — common cause for "my class doesn't apply".
- Look in DevTools "Computed" pane: is the class even in the stylesheet?
- Confirm class is a literal string in source, not constructed dynamically.
- Restart the dev server after config changes (some setups don't watch the config).
- Check class order conflicts — Tailwind's source order: `width` after `w-1/2` may surprise; use `tailwind-merge`.
- Verify variant gating: `md:flex` only applies above 768px.
- For specificity issues with third-party CSS, raise Tailwind's layer priority or use `!` important variant: `!text-red-500`.

---

### Q43. How does Tailwind handle right-to-left (RTL)?

**Answer:**

```html
<html dir="rtl">
<div class="ml-4">      <!-- still left margin in RTL — wrong -->
<div class="ms-4">      <!-- margin-inline-start — correct -->
```

Use **logical** utilities: `ms-*`, `me-*`, `ps-*`, `pe-*`, `start-*`, `end-*`, `border-s`, `border-e`, etc.

Conditional styles via `rtl:` and `ltr:` modifiers:
```html
<div class="rtl:rotate-180">
```

---

### Q44. How do you handle print styles?

**Answer:**

```html
<button class="print:hidden">Buy now</button>
<div class="hidden print:block">Confidential — Internal Use</div>
<article class="print:text-black print:bg-white">
```

For dedicated print stylesheets, define a `print` screen variant:
```js
screens: { print: { raw: 'print' } }
```

---

### Q45. How do you integrate Tailwind in a monorepo?

**Answer:**
- Each app has its own `tailwind.config.js` and `content` paths
- Shared UI package is included in each app's content glob:
  ```js
  content: ['./src/**/*.{tsx}', '../../packages/ui/src/**/*.{tsx}']
  ```
- Theme tokens shared via a JS module:
  ```js
  // packages/tailwind-config/index.js
  module.exports = { theme: { extend: { colors: { brand: '...' } } } };
  // app config
  presets: [require('@org/tailwind-config')]
  ```
- In v4, share `@theme` via importable CSS files: `@import "@org/tailwind-config/theme.css";`
