# Tailwind CSS Interview Questions — Complete Q&A Guide

**Focus:** Tailwind v3 and v4, utility-first workflow, configuration, theming, plugins, performance, and design systems.

Each question explains the concept and shows a real example you can copy into a project.

---

## 1. Fundamentals

## Q1. What is Tailwind CSS?

**Answer:**

Tailwind is a utility-first CSS framework. Instead of writing custom CSS classes, you compose small utility classes (`p-4`, `text-lg`, `bg-blue-500`) directly in your markup. The build step extracts only the classes you actually use, producing a small CSS file.

```html
<button class="bg-blue-500 hover:bg-blue-600 text-white font-medium px-4 py-2 rounded">
  Save
</button>
```

## Q2. What is utility-first and why use it?

**Answer:**

Utility-first means using single-purpose classes (`mt-4`, `flex`, `text-center`) instead of writing component-level CSS (`.card`, `.btn-primary`). Benefits:

- No naming gymnastics — class names already describe their effect.
- No unused CSS in production thanks to scanning.
- Consistent design tokens (spacing, colors).
- Faster iteration — no jumping between HTML and CSS files.

```html
<!-- Traditional CSS approach -->
<div class="card">
  <h2 class="card-title">Title</h2>
</div>

<!-- Utility-first -->
<div class="bg-white rounded-lg shadow p-4">
  <h2 class="text-lg font-semibold">Title</h2>
</div>
```

## Q3. How is Tailwind different from Bootstrap?

**Answer:**

| | Bootstrap | Tailwind |
| --- | --- | --- |
| Approach | Pre-built components (`.btn`, `.card`) | Utility classes |
| Customization | Override SCSS variables | Configure design tokens, compose utilities |
| Output size | All components shipped | Only used classes shipped |
| Look | Recognizable Bootstrap default | Generic, requires design choices |

Bootstrap gives you components quickly. Tailwind gives you primitives to build any design.

## Q4. How do you install Tailwind in a project?

**Answer:**

For Vite/Next/Vue (v3 example):

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

```js
// tailwind.config.js
module.exports = {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx,vue}'],
  theme: { extend: {} },
  plugins: [],
};
```

```css
/* src/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

In v4 the install is simpler — see Q30.

## Q5. What does each `@tailwind` directive do (v3)?

**Answer:**

- `@tailwind base` — resets and base typography (Preflight + element styles).
- `@tailwind components` — Tailwind's component-level classes and any custom ones.
- `@tailwind utilities` — all utility classes.

You can also place custom rules inside `@layer base | components | utilities` so they participate in the cascade correctly.

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  .btn-primary { @apply bg-blue-500 text-white px-4 py-2 rounded; }
}
```

## Q6. What is Preflight?

**Answer:**

Preflight is Tailwind's built-in CSS reset. It removes default browser styling (margins, list bullets, heading sizes), normalizes box-sizing, and gives you a clean canvas. You can disable it via the config if you need.

```js
// tailwind.config.js
module.exports = {
  corePlugins: { preflight: false },
};
```

## Q7. What are arbitrary values?

**Answer:**

Arbitrary values let you use any value inline without adding to the config, using square-bracket syntax.

```html
<div class="top-[117px] grid-cols-[1fr_2fr_auto] text-[#1da1f2]">
  Custom
</div>
```

Use sparingly — repeated arbitrary values should become design tokens.

---

## 2. Configuration and Theming

## Q8. How do you customize the theme?

**Answer:**

Edit `tailwind.config.js`. Use `extend` to add to defaults; replace top-level keys to override completely.

```js
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eff6ff',
          500: '#3b82f6',
          900: '#1e3a8a',
        },
      },
      spacing: { '128': '32rem' },
      fontFamily: { display: ['Inter', 'sans-serif'] },
    },
  },
};
```

```html
<div class="bg-brand-500 text-brand-50 font-display">Hello</div>
```

## Q9. How do you define design tokens?

**Answer:**

Design tokens are reusable values for colors, spacing, typography, shadows, and radii. Define them in `theme.extend` and reference by name.

```js
theme: {
  extend: {
    colors: { primary: '#4f46e5', surface: '#fafafa' },
    borderRadius: { card: '0.75rem' },
    boxShadow: { card: '0 1px 3px rgba(0,0,0,0.1)' },
  },
}
```

```html
<div class="bg-surface rounded-card shadow-card p-4">Card</div>
```

## Q10. What's the difference between `theme.extend` and replacing `theme`?

**Answer:**

`theme.extend` keeps all defaults and adds yours. Replacing a key (e.g. `theme.colors`) wipes the defaults — only your colors remain.

```js
// Adds, keeps all default colors
theme: { extend: { colors: { brand: '#000' } } }

// Replaces — only `brand` exists, no `red`, `blue`, etc.
theme: { colors: { brand: '#000' } }
```

## Q11. How do you customize breakpoints?

**Answer:**

```js
theme: {
  screens: {
    sm: '640px',
    md: '768px',
    lg: '1024px',
    xl: '1280px',
    '2xl': '1536px',
    'tablet': '900px', // custom
  },
}
```

```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
  Responsive grid
</div>
```

---

## 3. Responsive Design and Modifiers

## Q12. What modifiers does Tailwind support?

**Answer:**

Modifiers are prefixes that conditionally apply utilities. Examples:

| Modifier | Meaning |
| --- | --- |
| `sm:` `md:` `lg:` | Min-width breakpoint |
| `hover:` `focus:` `active:` | Interaction states |
| `dark:` | Dark mode |
| `first:` `last:` `odd:` `even:` | Position in a list |
| `disabled:` `checked:` | Form states |
| `group-hover:` `peer-focus:` | Parent or sibling state |

```html
<button class="bg-blue-500 hover:bg-blue-600 disabled:opacity-50 dark:bg-blue-700">
  Submit
</button>
```

## Q13. How do `group` and `peer` modifiers work?

**Answer:**

Add `group` to a parent, then style children with `group-hover:`, `group-focus:`, etc. Add `peer` to a sibling and use `peer-*:` on a following sibling.

```html
<div class="group p-4 hover:bg-gray-100">
  <h3 class="text-gray-900">Title</h3>
  <p class="text-gray-500 group-hover:text-gray-900">
    Highlights when parent is hovered
  </p>
</div>

<input type="checkbox" class="peer" />
<span class="peer-checked:text-green-600">Checked!</span>
```

## Q14. How do you target child elements without classes?

**Answer:**

Use `[&>*]:` arbitrary variants.

```html
<ul class="[&>li]:py-2 [&>li]:border-b">
  <li>One</li>
  <li>Two</li>
</ul>
```

This applies `py-2` and `border-b` to every direct `<li>` child without adding classes to each.

## Q15. What does `:has()` enable in Tailwind?

**Answer:**

The `has-[...]` modifier lets a parent style itself based on its descendants.

```html
<label class="block p-4 has-[:checked]:bg-blue-50 has-[:checked]:border-blue-500 border">
  <input type="checkbox" /> Accept
</label>
```

When the inner checkbox is checked, the label gets the highlighted styles.

---

## 4. Dark Mode

## Q16. What dark mode strategies does Tailwind support?

**Answer:**

- `media` (default in v3) — uses `prefers-color-scheme`.
- `class` — toggles based on a `dark` class higher in the tree.
- `selector` (v3.4+) — like `class` but customizable selector.

```js
// tailwind.config.js
module.exports = {
  darkMode: 'class', // toggle via class="dark"
};
```

```html
<html class="dark">
  <body class="bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
    Hello
  </body>
</html>
```

## Q17. How do you implement a dark mode toggle without flash?

**Answer:**

Apply the saved theme synchronously before hydration to avoid a flash of light content.

```html
<!-- Inline script in <head>, runs before render -->
<script>
  const saved = localStorage.theme;
  const prefers = window.matchMedia('(prefers-color-scheme: dark)').matches;
  if (saved === 'dark' || (!saved && prefers)) {
    document.documentElement.classList.add('dark');
  }
</script>
```

```js
// Toggle button
function toggleTheme() {
  const html = document.documentElement;
  html.classList.toggle('dark');
  localStorage.theme = html.classList.contains('dark') ? 'dark' : 'light';
}
```

---

## 5. Components and @apply

## Q18. What is `@apply` and when should you use it?

**Answer:**

`@apply` lets you compose utilities into a custom class.

```css
@layer components {
  .btn {
    @apply px-4 py-2 rounded font-medium;
  }
  .btn-primary {
    @apply btn bg-blue-500 text-white hover:bg-blue-600;
  }
}
```

Use it sparingly — only when you have a real reason like a third-party library expecting a class. Heavy `@apply` use defeats the purpose of utility-first.

## Q19. Components versus utilities — when to make a component?

**Answer:**

Make a component (Vue/React/Svelte) when the same combination of utilities appears in many places. Components let you change the design once and update everywhere. Avoid creating CSS classes for repeated patterns — use components or template loops instead.

```jsx
// Better than .btn-primary CSS class
function Button({ children, variant = 'primary' }) {
  const styles = {
    primary: 'bg-blue-500 hover:bg-blue-600 text-white',
    secondary: 'bg-gray-200 hover:bg-gray-300 text-gray-900',
  };
  return (
    <button className={`px-4 py-2 rounded font-medium ${styles[variant]}`}>
      {children}
    </button>
  );
}
```

## Q20. What is `tailwind-merge` and why use it?

**Answer:**

`tailwind-merge` resolves conflicts between Tailwind classes when you concatenate them. Without it, both classes are emitted and the later one in CSS source wins (which may be unpredictable).

```js
import { twMerge } from 'tailwind-merge';

twMerge('p-2 p-4');                  // → 'p-4'
twMerge('text-red-500', 'text-blue-500'); // → 'text-blue-500'
```

```jsx
function Button({ className, ...props }) {
  return (
    <button
      className={twMerge('px-4 py-2 bg-blue-500 text-white', className)}
      {...props}
    />
  );
}

<Button className="bg-red-500" /> // red, not blue
```

## Q21. What is CVA (class-variance-authority)?

**Answer:**

CVA helps build typed variant APIs for components — replacing manual ternary class logic.

```js
import { cva } from 'class-variance-authority';

const button = cva('px-4 py-2 rounded font-medium', {
  variants: {
    intent: {
      primary: 'bg-blue-500 text-white hover:bg-blue-600',
      danger: 'bg-red-500 text-white hover:bg-red-600',
    },
    size: {
      sm: 'text-sm py-1',
      md: 'text-base',
    },
  },
  defaultVariants: { intent: 'primary', size: 'md' },
});

<button className={button({ intent: 'danger', size: 'sm' })}>Delete</button>
```

---

## 6. JIT, Content, Production Build

## Q22. What is JIT mode?

**Answer:**

Just-In-Time compilation generates CSS on demand based on the classes it finds in your source files. It enables arbitrary values (`top-[37px]`), faster rebuilds, and small output. JIT is the default since Tailwind v3.

## Q23. How does content scanning work?

**Answer:**

Tailwind scans the files listed in `content` for class names and only emits CSS for what it finds. Patterns must include all template files.

```js
module.exports = {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx,vue,svelte}',
    './pages/**/*.{html,php}',
  ],
};
```

A common pitfall: if your file extension isn't included, classes are stripped from the build.

## Q24. What is the safelist?

**Answer:**

`safelist` forces Tailwind to keep specified classes even if it cannot find them in source — useful for classes built dynamically (e.g., `bg-${color}-500`).

```js
module.exports = {
  safelist: [
    'bg-red-500',
    { pattern: /bg-(red|green|blue)-(100|500|900)/ },
  ],
};
```

But prefer building full class names in JS so the scanner can find them:

```jsx
const colors = { red: 'bg-red-500', green: 'bg-green-500' };
<div className={colors[color]} />
```

## Q25. How do you optimize Tailwind for production?

**Answer:**

- Make sure `content` covers all template files (the scanner removes unused classes).
- Minify CSS via your bundler (Vite, Next.js do this automatically).
- Avoid arbitrary values for repeating patterns — use design tokens.
- Combine with gzip/brotli at the server.

A typical Tailwind production CSS file is 5-15 KB gzipped.

---

## 7. Plugins and Ecosystem

## Q26. What is the typography plugin?

**Answer:**

`@tailwindcss/typography` styles raw HTML content (like Markdown output) with a single `prose` class.

```bash
npm install -D @tailwindcss/typography
```

```js
plugins: [require('@tailwindcss/typography')]
```

```html
<article class="prose dark:prose-invert max-w-none">
  <h1>Title</h1>
  <p>Markdown content...</p>
</article>
```

## Q27. What does the forms plugin do?

**Answer:**

`@tailwindcss/forms` resets browser form controls to a consistent look that is easier to style with utilities.

```js
plugins: [require('@tailwindcss/forms')]
```

```html
<input
  type="text"
  class="rounded-md border-gray-300 focus:border-blue-500 focus:ring-blue-500"
/>
```

## Q28. What is Headless UI and how does it pair with Tailwind?

**Answer:**

Headless UI provides unstyled, accessible component primitives (Dialog, Menu, Listbox, Combobox) that you style with Tailwind. It handles keyboard interactions, focus traps, and ARIA correctly.

```jsx
import { Dialog } from '@headlessui/react';

<Dialog open={open} onClose={setOpen} className="relative z-50">
  <div className="fixed inset-0 bg-black/50" />
  <Dialog.Panel className="bg-white rounded-lg p-6">
    <Dialog.Title className="font-bold text-lg">Confirm</Dialog.Title>
  </Dialog.Panel>
</Dialog>
```

## Q29. How do you write a custom Tailwind plugin?

**Answer:**

```js
const plugin = require('tailwindcss/plugin');

module.exports = {
  plugins: [
    plugin(function ({ addUtilities, theme }) {
      addUtilities({
        '.text-shadow': {
          'text-shadow': '1px 1px 2px rgba(0,0,0,0.4)',
        },
      });
    }),
  ],
};
```

```html
<h1 class="text-shadow">Shadowed</h1>
```

---

## 8. Tailwind v4

## Q30. What's new in Tailwind v4?

**Answer:**

Tailwind v4 (released 2024) brings:

- CSS-first configuration with `@theme` (less reliance on JS config).
- A new high-performance Oxide engine.
- Native CSS variables for design tokens, available at runtime.
- Container queries built in.
- Simpler install — no PostCSS config needed for many projects.

## Q31. How does the v4 CSS-first config work?

**Answer:**

```css
/* app.css (v4) */
@import "tailwindcss";

@theme {
  --color-brand-500: #3b82f6;
  --font-display: "Inter", sans-serif;
  --spacing-128: 32rem;
}
```

```html
<div class="bg-brand-500 font-display p-128">Hello</div>
```

Tokens are real CSS custom properties, so you can read them at runtime.

## Q32. Are there migration concerns from v3 to v4?

**Answer:**

Yes — some classes were renamed or removed (e.g. `decoration-clone` → `box-decoration-clone`), some defaults changed (default border color became `currentColor`), and the configuration format moved to CSS. There is an official upgrade tool (`npx @tailwindcss/upgrade`) that automates most changes.

---

## 9. Patterns and Design Systems

## Q33. How do you build a component library on Tailwind?

**Answer:**

- Define design tokens in the config.
- Build framework components (React/Vue) that compose utilities internally.
- Use `tailwind-merge` + `cva` for variant APIs.
- Document each component with examples.

```jsx
import { cva } from 'class-variance-authority';
import { twMerge } from 'tailwind-merge';

const card = cva('rounded-lg border bg-white shadow-sm', {
  variants: { padding: { sm: 'p-3', md: 'p-6', lg: 'p-8' } },
});

export function Card({ padding, className, ...props }) {
  return <div className={twMerge(card({ padding }), className)} {...props} />;
}
```

## Q34. How do you handle responsive grid patterns?

**Answer:**

```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
  <div class="bg-white rounded-lg p-4">Item</div>
  <div class="bg-white rounded-lg p-4">Item</div>
  <div class="bg-white rounded-lg p-4">Item</div>
</div>
```

For an "auto-fit" responsive grid without breakpoints:

```html
<div class="grid grid-cols-[repeat(auto-fit,minmax(250px,1fr))] gap-4">
  ...
</div>
```

## Q35. How do you build a card component?

**Answer:**

```html
<article class="overflow-hidden rounded-lg bg-white shadow-md transition hover:shadow-lg">
  <img src="cover.jpg" class="aspect-video w-full object-cover" alt="" />
  <div class="p-4">
    <h3 class="text-lg font-semibold">Card title</h3>
    <p class="mt-2 text-sm text-gray-600">A short description...</p>
    <a href="#" class="mt-4 inline-block text-blue-600 hover:underline">Read more</a>
  </div>
</article>
```

## Q36. How do you build a navbar with mobile menu?

**Answer:**

```jsx
function Nav() {
  const [open, setOpen] = useState(false);
  return (
    <nav className="bg-white shadow">
      <div className="mx-auto max-w-6xl flex items-center justify-between p-4">
        <a className="font-bold">Logo</a>
        <button
          className="md:hidden"
          onClick={() => setOpen(!open)}
        >
          ☰
        </button>
        <ul className="hidden md:flex gap-6">
          <li><a href="/">Home</a></li>
          <li><a href="/about">About</a></li>
        </ul>
      </div>
      {open && (
        <ul className="md:hidden border-t p-4 space-y-2">
          <li><a href="/">Home</a></li>
          <li><a href="/about">About</a></li>
        </ul>
      )}
    </nav>
  );
}
```

## Q37. How do you create gradients?

**Answer:**

```html
<div class="bg-gradient-to-r from-purple-500 via-pink-500 to-red-500 p-8 text-white">
  Gradient
</div>

<h1 class="bg-gradient-to-r from-blue-500 to-emerald-500 bg-clip-text text-transparent text-5xl font-bold">
  Gradient text
</h1>
```

## Q38. How do you do animations beyond transitions?

**Answer:**

Tailwind ships with `animate-spin`, `animate-ping`, `animate-pulse`, `animate-bounce`. For custom animations, register in config.

```js
theme: {
  extend: {
    keyframes: {
      'fade-up': {
        '0%': { opacity: 0, transform: 'translateY(10px)' },
        '100%': { opacity: 1, transform: 'translateY(0)' },
      },
    },
    animation: {
      'fade-up': 'fade-up 0.3s ease-out',
    },
  },
}
```

```html
<div class="animate-fade-up">Hello</div>
```

---

## 10. Comparisons and Trade-offs

## Q39. Tailwind vs CSS Modules — when to choose what?

**Answer:**

- **Tailwind** — utility classes in markup, fast iteration, small bundle, design system built-in.
- **CSS Modules** — scoped CSS files per component, traditional class-based, easier when porting existing CSS.

Both can coexist. Many teams use Tailwind for layout and CSS Modules for component-specific complex styles.

## Q40. Tailwind vs styled-components / Emotion?

**Answer:**

- **Tailwind** — zero runtime, smaller bundle, works with any framework.
- **styled-components / Emotion** — dynamic styles via JS props, but adds runtime cost and React Server Component compatibility issues.

For modern React (App Router, RSC), Tailwind is usually safer.

## Q41. Common Tailwind anti-patterns?

**Answer:**

- Repeating the same long class string everywhere instead of making a component.
- Heavy `@apply` use — defeats the utility-first model.
- Building class names dynamically with template strings (the scanner does not see partial class names).
- Adding arbitrary values when a design token would do.

```jsx
// Bad — scanner can't see the class name
<div className={`bg-${color}-500`} />

// Good
const map = { red: 'bg-red-500', green: 'bg-green-500' };
<div className={map[color]} />
```

## Q42. How do you debug missing or unexpected styles?

**Answer:**

- Inspect the element in DevTools and check whether the class is in the generated CSS.
- Confirm the file is in the `content` glob.
- Check for class-name string interpolation that hides class names.
- Look for conflicting classes — use `tailwind-merge`.

## Q43. How does Tailwind handle right-to-left (RTL)?

**Answer:**

Use logical properties (`ms-`, `me-` for margin-start/end, `ps-`, `pe-` for padding-start/end, `start-` and `end-` for positioning).

```html
<div class="ms-4 ps-2 border-s">RTL-friendly</div>
```

For pages with `dir="rtl"`, layout flips automatically.

## Q44. How do you handle print styles?

**Answer:**

Use the `print:` modifier.

```html
<button class="print:hidden">Save PDF</button>
<article class="print:text-black print:bg-white">Content</article>
```

## Q45. How do you integrate Tailwind in a monorepo?

**Answer:**

Each app gets its own Tailwind config but can share the theme via a package.

```js
// packages/ui/tailwind.preset.js
module.exports = {
  theme: {
    extend: {
      colors: { brand: { 500: '#3b82f6' } },
    },
  },
};

// apps/web/tailwind.config.js
module.exports = {
  presets: [require('ui/tailwind.preset')],
  content: [
    './src/**/*.{js,ts,jsx,tsx}',
    '../../packages/ui/src/**/*.{js,ts,jsx,tsx}', // include shared package
  ],
};
```

---

## 11. More Practical Topics

## Q46. How do you build a responsive button group?

**Answer:**

```html
<div class="flex flex-col sm:flex-row gap-2 sm:gap-0 sm:divide-x rounded-md shadow-sm">
  <button class="px-4 py-2 bg-white sm:rounded-l-md">Day</button>
  <button class="px-4 py-2 bg-white">Week</button>
  <button class="px-4 py-2 bg-white sm:rounded-r-md">Month</button>
</div>
```

## Q47. How do you make a sticky header with shadow on scroll?

**Answer:**

```html
<header class="sticky top-0 z-40 bg-white/80 backdrop-blur shadow-sm">
  <div class="max-w-6xl mx-auto p-4">Header</div>
</header>
```

The `backdrop-blur` plus translucent background gives a modern frosted-glass effect.

## Q48. How do you build a form with validation states?

**Answer:**

```html
<form class="space-y-4">
  <div>
    <label class="block text-sm font-medium">Email</label>
    <input
      type="email"
      class="mt-1 w-full rounded border-gray-300
             focus:border-blue-500 focus:ring-blue-500
             invalid:border-red-500 invalid:focus:border-red-500"
    />
  </div>
  <button class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded">
    Submit
  </button>
</form>
```

## Q49. How do you implement an aspect-ratio container?

**Answer:**

```html
<div class="aspect-video bg-gray-200">
  <iframe src="..." class="w-full h-full" />
</div>

<div class="aspect-square bg-gray-200">Square</div>
<div class="aspect-[4/3] bg-gray-200">Custom</div>
```

## Q50. How do you build a skeleton loader?

**Answer:**

```html
<div class="animate-pulse space-y-3">
  <div class="h-4 bg-gray-200 rounded w-3/4"></div>
  <div class="h-4 bg-gray-200 rounded"></div>
  <div class="h-4 bg-gray-200 rounded w-5/6"></div>
</div>
```

## Q51. How do you use `space-x` and `space-y`?

**Answer:**

`space-x-*` and `space-y-*` add margin between adjacent children, replacing the need for individual margins.

```html
<div class="flex space-x-4">
  <button>One</button>
  <button>Two</button>
  <button>Three</button>
</div>

<div class="space-y-2">
  <p>Para 1</p>
  <p>Para 2</p>
</div>
```

In modern Tailwind, `gap-*` on flex/grid containers is generally preferred.

## Q52. How do you build a tooltip?

**Answer:**

```html
<div class="group relative inline-block">
  <button>Hover me</button>
  <div class="invisible group-hover:visible absolute bottom-full mb-1 left-1/2 -translate-x-1/2 whitespace-nowrap rounded bg-gray-900 px-2 py-1 text-xs text-white">
    Tooltip text
  </div>
</div>
```

## Q53. How do you center a modal?

**Answer:**

```html
<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
  <div class="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
    <h2 class="text-lg font-semibold">Modal</h2>
    <p class="mt-2 text-sm text-gray-600">Content</p>
  </div>
</div>
```

## Q54. What is the difference between `min-w-0` and overflow?

**Answer:**

By default, flex items have a minimum content size that prevents them from shrinking. `min-w-0` allows them to shrink so child overflow rules (like text truncation) work.

```html
<div class="flex">
  <div class="min-w-0 truncate">Very long text that needs to truncate properly</div>
</div>
```

## Q55. How do you handle container width and centering?

**Answer:**

```html
<div class="max-w-6xl mx-auto px-4">Centered content</div>
```

Or use Tailwind's `container` class plus `mx-auto`:

```html
<div class="container mx-auto px-4">Container</div>
```

## Q56. How do you create a divider with text?

**Answer:**

```html
<div class="flex items-center gap-4">
  <hr class="flex-1 border-gray-300" />
  <span class="text-sm text-gray-500">OR</span>
  <hr class="flex-1 border-gray-300" />
</div>
```

## Q57. What are utility classes for accessibility?

**Answer:**

- `sr-only` — visually hidden but accessible to screen readers.
- `not-sr-only` — undo `sr-only` (for visible-on-focus links).
- `focus:outline-none` — be careful, always pair with a visible focus style.
- `focus-visible:` — apply focus styles only with keyboard.

```html
<a href="#main" class="sr-only focus:not-sr-only focus:absolute focus:top-2 focus:left-2 bg-white px-4 py-2">
  Skip to content
</a>

<button class="focus-visible:outline focus-visible:outline-2 focus-visible:outline-blue-500">
  Click
</button>
```

## Q58. How do you compose conditional classes in React?

**Answer:**

Use template literals or libraries like `clsx` / `classnames`.

```jsx
import clsx from 'clsx';

<button
  className={clsx(
    'px-4 py-2 rounded font-medium',
    isPrimary ? 'bg-blue-500 text-white' : 'bg-gray-200',
    disabled && 'opacity-50 pointer-events-none'
  )}
>
  Click
</button>
```

For deduplication, use `clsx` + `tailwind-merge`:

```jsx
import { twMerge } from 'tailwind-merge';
twMerge(clsx('p-2', condition && 'p-4'));
```

## Q59. How do you handle mobile-first design in Tailwind?

**Answer:**

Tailwind is mobile-first by default. Unprefixed utilities apply at all sizes; breakpoint prefixes (`md:`, `lg:`) add styles at that size and above.

```html
<!-- Mobile: stacked, Desktop: row -->
<div class="flex flex-col md:flex-row">...</div>

<!-- Mobile: smaller text, Desktop: larger -->
<h1 class="text-2xl md:text-4xl lg:text-6xl">Heading</h1>
```

## Q60. How do you preview Tailwind classes during development?

**Answer:**

Install the official "Tailwind CSS IntelliSense" VS Code extension. It autocompletes class names, shows hover previews of the CSS, and highlights conflicts.

---

## 12. Quick Reference

| Layout | Class |
| ------ | ----- |
| Flex container | `flex` |
| Grid container | `grid grid-cols-3` |
| Center children | `flex items-center justify-center` |
| Gap | `gap-4` |
| Padding/margin | `p-4` `m-4` `px-4` `mx-auto` |

| Responsiveness | Modifier |
| -------------- | -------- |
| Tablet+ | `md:` |
| Desktop+ | `lg:` |
| Hover | `hover:` |
| Focus | `focus:` |
| Dark mode | `dark:` |
| Group state | `group-hover:` |
| Sibling state | `peer-checked:` |
| Has child | `has-[:checked]:` |

| Theming | Where |
| ------- | ----- |
| v3 | `tailwind.config.js → theme.extend` |
| v4 | CSS `@theme { --color-brand-500: ... }` |
| Tokens | `colors`, `spacing`, `boxShadow`, `borderRadius` |

| Tools | Purpose |
| ----- | ------- |
| `tailwind-merge` | Resolve class conflicts |
| `clsx` / `classnames` | Build conditional classes |
| `class-variance-authority` | Variant API |
| `@tailwindcss/typography` | Style raw HTML content |
| `@tailwindcss/forms` | Reset form controls |
| `Headless UI` | Accessible primitives |
