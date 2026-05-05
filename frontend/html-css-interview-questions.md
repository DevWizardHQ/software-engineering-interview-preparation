# HTML and CSS Interview Questions

**Level:** Mid to Senior
**Topics:** HTML5, Semantics, Accessibility, CSS3, Layout, Modern CSS, Performance, Architecture

---

## Table of Contents

1. [HTML Fundamentals](#html-fundamentals)
2. [Semantics and Accessibility](#semantics-and-accessibility)
3. [Forms and Inputs](#forms-and-inputs)
4. [Web Components](#web-components)
5. [CSS Fundamentals](#css-fundamentals)
6. [Layout (Flexbox and Grid)](#layout-flexbox-and-grid)
7. [Positioning and Stacking](#positioning-and-stacking)
8. [Responsive Design](#responsive-design)
9. [Selectors, Specificity, Cascade](#selectors-specificity-cascade)
10. [Modern CSS](#modern-css)
11. [Animations and Effects](#animations-and-effects)
12. [Architecture and Methodologies](#architecture-and-methodologies)
13. [Performance](#performance)

---

## HTML Fundamentals

### Q1. What changed in HTML5 vs HTML4?

**Answer:**
HTML5 introduced semantic elements (`<header>`, `<nav>`, `<article>`, `<section>`, `<aside>`, `<footer>`, `<main>`, `<figure>`), native multimedia (`<audio>`, `<video>`), the `<canvas>` element, new form input types (`email`, `date`, `number`, `range`), the `<datalist>`, local storage, geolocation, web workers, and a simplified doctype `<!DOCTYPE html>`.

It removed presentation-only elements (`<font>`, `<center>`) in favor of CSS.

---

### Q2. What is the difference between `<section>`, `<article>`, and `<div>`?

**Answer:**

| Element | Purpose |
|--------|---------|
| `<article>` | Self-contained, independently distributable content (blog post, news article, comment) |
| `<section>` | Thematic grouping of content, typically with a heading |
| `<div>` | Generic container with no semantic meaning, used for styling/layout |

Rule: if the content could stand alone (RSS feed item), use `<article>`. If it groups related content within a page, use `<section>`. Otherwise, `<div>`.

---

### Q3. What does the `lang` attribute do?

**Answer:**
`<html lang="en">` declares the document language. It improves screen reader pronunciation, helps search engines, enables correct hyphenation rules, and affects spell-check behavior. Always set it.

---

### Q4. Difference between `<b>` and `<strong>`, `<i>` and `<em>`?

**Answer:**
- `<b>` and `<i>` are presentational (bold/italic visual style only).
- `<strong>` indicates strong importance (semantic, screen readers may emphasize).
- `<em>` indicates stress emphasis (changes meaning of a sentence).

Use the semantic versions unless purely visual styling is needed.

---

### Q5. What is the purpose of the `<meta charset>` and viewport tags?

**Answer:**

```html
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
```

- `charset` defines character encoding (always UTF-8). Must appear in the first 1024 bytes.
- `viewport` controls layout on mobile. Without it, mobile browsers render at 980px desktop width and zoom out.

---

### Q6. What meta tags are critical for SEO?

**Answer:**

```html
<title>Page Title | Brand</title>
<meta name="description" content="Concise summary under 160 chars.">
<link rel="canonical" href="https://example.com/page">
<meta name="robots" content="index, follow">

<!-- Open Graph -->
<meta property="og:title" content="...">
<meta property="og:description" content="...">
<meta property="og:image" content="...">
<meta property="og:url" content="...">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
```

`title` and `description` drive search snippets. `canonical` prevents duplicate content penalties. Open Graph tags control how links appear when shared.

---

### Q7. What's the difference between `defer` and `async` on `<script>`?

**Answer:**

| Attribute | Download | Execution |
|-----------|----------|-----------|
| (none) | Blocks parser | Inline, blocks rendering |
| `async` | Parallel | As soon as ready, may interrupt parsing |
| `defer` | Parallel | After HTML parse, in document order |
| `type="module"` | Parallel | Deferred by default |

Use `defer` for scripts that depend on DOM. Use `async` for independent scripts (analytics).

---

### Q8. What is the difference between `localStorage`, `sessionStorage`, and cookies?

**Answer:**

| Feature | localStorage | sessionStorage | Cookies |
|---------|-------------|----------------|---------|
| Capacity | ~5-10MB | ~5-10MB | ~4KB |
| Lifetime | Until cleared | Tab close | Configurable |
| Sent with HTTP | No | No | Yes (per-request overhead) |
| Accessible from JS | Yes | Yes | Yes (unless `HttpOnly`) |

For auth tokens, prefer `HttpOnly` cookies to mitigate XSS exfiltration.

---

### Q9. What are data attributes used for?

**Answer:**
`data-*` attributes store custom data in HTML accessible via `dataset` in JS:

```html
<button data-user-id="42" data-action="delete">X</button>
```

```js
const btn = document.querySelector('button');
btn.dataset.userId; // "42"
btn.dataset.action; // "delete"
```

Useful for hooking JS behavior without polluting the global namespace.

---

## Semantics and Accessibility

### Q10. What is semantic HTML and why does it matter?

**Answer:**
Semantic HTML uses elements that convey meaning (`<nav>`, `<button>`, `<article>`) over generic ones (`<div>`, `<span>`).

Benefits:
- screen readers announce roles correctly
- keyboard navigation works without extra code (e.g. `<button>` is focusable, `<div>` is not)
- search engines understand structure
- maintainable code

A `<div onclick>` is not a button; it lacks role, focus, and Enter/Space handling.

---

### Q11. What is ARIA and when should you use it?

**Answer:**
ARIA (Accessible Rich Internet Applications) adds semantics where native HTML can't express them. It includes:
- **Roles**: `role="dialog"`, `role="tab"`, `role="alert"`
- **States**: `aria-expanded`, `aria-checked`, `aria-disabled`
- **Properties**: `aria-label`, `aria-labelledby`, `aria-describedby`

**First rule of ARIA: don't use ARIA.** If a native element does the job (e.g. `<button>`), use it. ARIA is for custom widgets like comboboxes or tabs that have no native equivalent.

```html
<!-- Bad -->
<div class="btn" onclick="...">Save</div>

<!-- Good -->
<button>Save</button>

<!-- ARIA only when needed -->
<div role="tab" aria-selected="true" tabindex="0">Tab 1</div>
```

---

### Q12. How do you make an element keyboard-accessible?

**Answer:**

1. Use native focusable elements (`<button>`, `<a href>`, form inputs).
2. For custom widgets, add `tabindex="0"` to make focusable in normal order.
3. Handle keyboard events (Enter/Space for buttons, Arrow keys for menus/tabs).
4. Provide visible focus styles (`:focus-visible`).
5. Manage focus on dynamic content (modals trap focus, return focus on close).

```css
:focus-visible {
  outline: 2px solid #0066cc;
  outline-offset: 2px;
}
```

Avoid `outline: none` without replacement.

---

### Q13. What is the accessibility tree?

**Answer:**
A parallel tree to the DOM that browsers expose to assistive tech. Each node has a role, name, state, and value. Tools like Chrome DevTools "Accessibility" pane visualize it.

`aria-hidden="true"` removes a node from this tree but keeps it visible in DOM. `display: none` removes from both.

---

### Q14. What's the difference between `aria-label`, `aria-labelledby`, and `aria-describedby`?

**Answer:**

| Attribute | Purpose |
|-----------|---------|
| `aria-label` | Provides accessible name via string |
| `aria-labelledby` | References ID(s) of element(s) that label it |
| `aria-describedby` | References ID(s) for additional descriptive text |

```html
<button aria-label="Close dialog">X</button>

<input aria-labelledby="email-label" aria-describedby="email-hint">
<span id="email-label">Email</span>
<span id="email-hint">We'll never share it.</span>
```

`labelledby` overrides `aria-label`, which overrides inner text.

---

### Q15. How do you make images accessible?

**Answer:**
- Meaningful images: use `alt="descriptive text"`.
- Decorative images: use `alt=""` (empty) so screen readers skip them.
- Complex images (charts): provide long description nearby or via `aria-describedby`.
- Don't use `alt="image of..."`; screen readers already announce "image".
- For SVGs, add `<title>` inside the SVG or `role="img"` with `aria-label`.

---

### Q16. What is WCAG and what are the key principles?

**Answer:**
Web Content Accessibility Guidelines, organized as POUR:
- **Perceivable**: alt text, captions, sufficient contrast
- **Operable**: keyboard accessible, no seizure-inducing flashes, enough time
- **Understandable**: readable, predictable, helpful errors
- **Robust**: works with assistive tech, valid markup

WCAG levels: A (minimum), AA (legal standard most aim for), AAA (highest). Contrast ratio for AA is 4.5:1 (normal text), 3:1 (large text).

---

### Q17. What's a skip link?

**Answer:**
A link at the top of the page that jumps past navigation to main content for keyboard users. Hidden until focused.

```html
<a href="#main" class="skip-link">Skip to main content</a>
...
<main id="main">...</main>
```

```css
.skip-link {
  position: absolute;
  left: -9999px;
}
.skip-link:focus {
  left: 0;
  top: 0;
}
```

---

## Forms and Inputs

### Q18. What input types does HTML5 provide?

**Answer:**
`text`, `password`, `email`, `tel`, `url`, `number`, `range`, `date`, `datetime-local`, `month`, `week`, `time`, `color`, `search`, `file`, `checkbox`, `radio`, `hidden`, `submit`, `button`, `reset`.

Mobile keyboards adapt to type (`tel` shows numeric pad, `email` shows `@` key). Browsers provide built-in pickers for `date` and `color`.

---

### Q19. How does HTML5 form validation work?

**Answer:**
Built-in validation via attributes:

```html
<form>
  <input type="email" required>
  <input type="text" pattern="[A-Za-z]{3,10}" minlength="3" maxlength="10">
  <input type="number" min="1" max="100" step="1">
  <button>Submit</button>
</form>
```

Browser blocks submission and shows native UI on invalid input. Customize with the Constraint Validation API:

```js
input.setCustomValidity('Username must be unique');
input.checkValidity();
input.reportValidity();
```

CSS hooks: `:valid`, `:invalid`, `:required`, `:user-invalid` (only after interaction).

Disable native UI with `novalidate` if you handle validation yourself.

---

### Q20. What does `autocomplete` do and why is it important?

**Answer:**
`autocomplete` tells the browser/password manager what kind of data goes in a field (`email`, `name`, `current-password`, `new-password`, `one-time-code`, `cc-number`, `street-address`, etc.).

Correct autocomplete values:
- enable password manager auto-fill
- enable address auto-fill
- improve form completion rates dramatically
- aid accessibility (some screen readers use these hints)

```html
<input type="password" autocomplete="current-password">
<input type="password" autocomplete="new-password">
<input name="otp" autocomplete="one-time-code">
```

---

### Q21. How do you associate a label with an input?

**Answer:**

```html
<!-- Explicit (preferred) -->
<label for="email">Email</label>
<input id="email" type="email">

<!-- Implicit (wrapping) -->
<label>
  Email
  <input type="email">
</label>
```

Avoid `placeholder` as a label (disappears on input, low contrast, fails WCAG). Use a real `<label>` plus `placeholder` for example text.

---

### Q22. How do you build accessible custom form controls?

**Answer:**
Prefer native first. If you must build custom (e.g. styled select):
- maintain a native hidden input for form submission
- assign appropriate `role` (`combobox`, `listbox`, `option`)
- manage `aria-expanded`, `aria-activedescendant`, `aria-selected`
- handle keyboard (Arrow keys, Enter, Escape, Home/End, type-ahead)
- ensure focus visibility and trapping

Use established libraries (Headless UI, Radix, React Aria) — accessible widgets are deceptively complex.

---

## Web Components

### Q23. What are web components?

**Answer:**
A set of standards for reusable, encapsulated custom HTML elements:
- **Custom Elements**: define new tags via `customElements.define()`
- **Shadow DOM**: encapsulated DOM and styles
- **HTML Templates**: `<template>` and `<slot>` for reusable markup
- **ES Modules**: standardized JS imports

Framework-agnostic — usable in React, Vue, plain HTML alike.

---

### Q24. How do you define a custom element?

**Answer:**

```js
class MyButton extends HTMLElement {
  static observedAttributes = ['disabled'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  connectedCallback() {
    const tpl = document.getElementById('my-button-tpl');
    this.shadowRoot.append(tpl.content.cloneNode(true));
  }

  attributeChangedCallback(name, oldVal, newVal) {
    if (name === 'disabled') {
      this.shadowRoot.querySelector('button').disabled = newVal !== null;
    }
  }

  disconnectedCallback() { /* cleanup */ }
}
customElements.define('my-button', MyButton);
```

```html
<template id="my-button-tpl">
  <style>button { padding: 8px 16px; }</style>
  <button><slot></slot></button>
</template>

<my-button disabled>Click</my-button>
```

Custom element names must contain a hyphen. Using `<template>` plus `cloneNode` is preferred over building markup as strings — it's safer and lets the browser parse once.

---

### Q25. What is Shadow DOM and why use it?

**Answer:**
Shadow DOM creates an isolated DOM subtree. Styles inside don't leak out, and outside CSS doesn't bleed in (except inherited properties and CSS custom properties).

```js
this.attachShadow({ mode: 'open' });
const style = document.createElement('style');
style.textContent = 'p { color: red; }';
const p = document.createElement('p');
p.textContent = 'Hi';
this.shadowRoot.append(style, p);
```

`mode: 'open'` allows external `el.shadowRoot` access; `closed` doesn't.

Use for: design-system primitives, third-party widgets that must not collide with host styles. Trade-off: harder to theme; styles must opt-in via CSS variables or `::part()`.

---

### Q26. How do you style Shadow DOM from outside?

**Answer:**
- **CSS custom properties** pierce the shadow boundary:
  ```css
  my-button { --btn-bg: red; }
  /* inside shadow */
  button { background: var(--btn-bg); }
  ```
- **`::part()`** lets the component expose stylable parts:
  ```html
  <!-- inside -->
  <button part="trigger">...</button>
  ```
  ```css
  my-button::part(trigger) { color: blue; }
  ```
- **`::slotted()`** styles content projected via `<slot>`.

---

## CSS Fundamentals

### Q27. Explain the CSS box model.

**Answer:**
Every element is a rectangular box made of:
- **Content** (width by height)
- **Padding** (inside, between content and border)
- **Border**
- **Margin** (outside, between this box and others)

`box-sizing: content-box` (default): `width` = content. Total width = content + padding + border.

`box-sizing: border-box`: `width` = content + padding + border. More predictable; almost universally preferred.

```css
*, *::before, *::after { box-sizing: border-box; }
```

---

### Q28. What is margin collapsing?

**Answer:**
Adjacent vertical margins of block-level elements collapse into a single margin equal to the larger of the two (not the sum). Happens between siblings, parent and first/last child (without padding/border between), and empty blocks.

Prevents: padding, border, `display: flex`/`grid`, `overflow` other than visible, floats, absolute positioning.

Horizontal margins never collapse. Flex and grid item margins never collapse.

---

### Q29. What's the difference between `display` values?

**Answer:**

| Value | Behavior |
|-------|----------|
| `block` | Full-width line, respects width/height |
| `inline` | Flows in line, ignores width/height/vertical margin |
| `inline-block` | Inline flow, respects width/height |
| `flex` | Flex container; children become flex items |
| `inline-flex` | Inline-level flex container |
| `grid` | Grid container |
| `contents` | Element disappears from layout; children promoted to its parent's box |
| `none` | Removed from layout entirely |
| `flow-root` | Establishes new block formatting context (e.g. clears floats) |

`display: contents` is useful for unwrapping a wrapper (e.g. component root) without losing semantics, but it has accessibility bugs in older browsers — verify before relying on it.

---

### Q30. What units exist in CSS and when should you use each?

**Answer:**

| Unit | Description | Use case |
|------|-------------|----------|
| `px` | Absolute pixel | Borders, fine details |
| `em` | Relative to parent font-size | Component-relative spacing |
| `rem` | Relative to root font-size | Most sizing (typography, spacing) |
| `%` | Relative to parent's same property | Fluid widths |
| `vw`/`vh` | 1% of viewport | Hero sections, full-screen |
| `vmin`/`vmax` | 1% of smaller/larger viewport dim | Square layouts |
| `svh`/`lvh`/`dvh` | Small/large/dynamic viewport height | Mobile (handles browser chrome) |
| `ch` | Width of `0` glyph | Reading-line length |
| `ex` | x-height | Rare typography |
| `fr` | Fractional grid space | Grid tracks |

Prefer `rem` for sizes that should scale with user preference; `em` for component-internal scaling.

---

### Q31. What's the difference between `em` and `rem`?

**Answer:**
- `em` is relative to the **current element's** font-size (or parent's if setting `font-size` itself).
- `rem` is relative to the **root** (`<html>`) font-size.

`em` compounds: nesting elements with `font-size: 1.2em` gets exponentially bigger. `rem` is predictable.

```css
html { font-size: 16px; }   /* 1rem = 16px */
.card { font-size: 1.2em; } /* 19.2px */
.card .title { font-size: 1.2em; } /* 23.04px (compounds!) */
.card .title { font-size: 1.2rem; } /* 19.2px (consistent) */
```

User accessibility: don't set `html { font-size: ... }` in `px`; lock to default `100%` so users can change browser zoom/font size.

---

### Q32. What are CSS custom properties (variables)?

**Answer:**

```css
:root {
  --primary: #0066cc;
  --space: 1rem;
}

.button {
  background: var(--primary);
  padding: var(--space);
}
```

Differences from preprocessor variables (Sass):
- live in cascade — can be overridden per selector
- accessible at runtime via JS (`getPropertyValue`/`setProperty`)
- can change in media queries, attributes, hover

```css
[data-theme="dark"] { --primary: #4488ff; }
@media (prefers-color-scheme: dark) { :root { --bg: #111; } }
```

Crucial for: theming, dark mode, design tokens, dynamic values from JS.

Fallback: `var(--missing, blue)`.

---

### Q33. What is the difference between inheritance, the cascade, and specificity?

**Answer:**

- **Inheritance**: some properties (color, font, line-height) pass from parent to child by default. Others (margin, border) don't.
- **Cascade**: the algorithm that picks one declaration when multiple apply, based on origin, layer, specificity, source order, and `!important`.
- **Specificity**: a weight (a, b, c) — inline styles (1,0,0,0) > IDs (0,1,0,0) > classes/attributes/pseudo-classes (0,0,1,0) > elements/pseudo-elements (0,0,0,1).

`*`, `:where()` have specificity 0. `:is()` takes the highest specificity of its argument list.

---

## Layout (Flexbox and Grid)

### Q34. Explain `flex-grow`, `flex-shrink`, `flex-basis`.

**Answer:**

`flex` shorthand: `flex-grow flex-shrink flex-basis`.

- **flex-basis**: the initial size before free space is distributed. `auto` = use `width`/content size.
- **flex-grow**: how much of remaining free space this item takes. Items with grow=2 take 2x what grow=1 items take.
- **flex-shrink**: how much an item shrinks when there isn't enough space. shrink=0 prevents shrinking.

```css
.item { flex: 1 1 0; }     /* equal columns, growing/shrinking */
.item { flex: 0 0 200px; } /* fixed 200px, no flex */
.item { flex: 1; }         /* shorthand for 1 1 0% */
.item { flex: auto; }      /* 1 1 auto — grows from content size */
```

Common gotcha: `flex: 1` differs from `flex: auto` — the first ignores content size, the second considers it.

---

### Q35. How do you center an element vertically and horizontally?

**Answer:**

Flex (most common):
```css
.parent { display: flex; align-items: center; justify-content: center; }
```

Grid:
```css
.parent { display: grid; place-items: center; }
```

Absolute positioning (legacy fallback):
```css
.child { position: absolute; inset: 0; margin: auto; }
/* or */
.child { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); }
```

---

### Q36. What's the difference between `justify-content`, `align-items`, `align-content`?

**Answer:**
In flexbox (default `flex-direction: row`):
- `justify-content`: alignment along the **main axis** (horizontal)
- `align-items`: alignment along the **cross axis** (vertical) for a single line
- `align-content`: alignment of multiple lines (only when wrapping)

`align-self` overrides `align-items` for a single item.

In grid, axes are independent of direction; `place-items` is shorthand for `align-items justify-items`.

---

### Q37. Explain CSS Grid `fr` units, `auto`, and `minmax`.

**Answer:**

```css
.grid {
  display: grid;
  grid-template-columns: 200px 1fr 2fr minmax(100px, 300px) auto;
}
```

- `200px`: fixed
- `1fr`: takes 1 part of remaining space
- `2fr`: takes 2 parts
- `minmax(100px, 300px)`: between 100 and 300px
- `auto`: sized to content

`fr` distributes leftover space *after* fixed and content-sized tracks are accounted for.

---

### Q38. What are grid template areas?

**Answer:**
Named layouts using string syntax:

```css
.layout {
  display: grid;
  grid-template-columns: 200px 1fr;
  grid-template-rows: auto 1fr auto;
  grid-template-areas:
    "header header"
    "sidebar main"
    "footer footer";
}
header { grid-area: header; }
aside { grid-area: sidebar; }
main { grid-area: main; }
footer { grid-area: footer; }
```

Easy to reflow with media queries by re-defining `grid-template-areas`.

---

### Q39. What is auto-placement in CSS Grid?

**Answer:**
Items without explicit position are auto-placed by the grid algorithm.

```css
.gallery {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  grid-auto-rows: 200px;
  grid-auto-flow: dense;
}
```

- `auto-fill`: creates as many tracks as fit, possibly empty
- `auto-fit`: same, but collapses empty tracks (children stretch)
- `grid-auto-flow: dense`: backfills holes, may reorder visually (caution: changes reading order)

`grid-auto-rows`/`grid-auto-columns` size implicitly created tracks.

---

### Q40. What is subgrid?

**Answer:**
A grid item with `display: grid` can opt into the parent's track sizes for either axis:

```css
.parent { display: grid; grid-template-columns: 1fr 1fr 1fr; }
.child {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: subgrid;
}
```

Useful for aligning nested content (e.g. card titles and footers across rows). Supported in all modern browsers as of 2023+.

---

### Q41. When should you use Flexbox vs Grid?

**Answer:**

| Flexbox | Grid |
|---------|------|
| One-dimensional (row OR column) | Two-dimensional (row AND column) |
| Content-driven sizing | Layout-driven sizing |
| Navigation bars, button groups | Page layouts, photo galleries |
| Distributing items in a line | Aligning items in two axes |

You can and should combine them — Grid for the page, Flex within cells.

---

## Positioning and Stacking

### Q42. Explain CSS `position` values.

**Answer:**

| Value | Behavior |
|-------|----------|
| `static` | Default; in normal flow, ignores `top/left/...` |
| `relative` | In flow, but offsetable; creates positioning context |
| `absolute` | Removed from flow, positioned relative to nearest positioned ancestor |
| `fixed` | Removed from flow, positioned relative to viewport (or transformed ancestor!) |
| `sticky` | In flow until scroll threshold, then sticks |

```css
.header { position: sticky; top: 0; }
```

Sticky requires a scrollable ancestor without `overflow: hidden` and a defined inset (`top`, `bottom`, etc.).

Gotcha: `position: fixed` is positioned relative to the nearest ancestor with a `transform`, `filter`, `perspective`, `will-change`, or `contain: paint/layout` — not always the viewport.

---

### Q43. What is a stacking context and how is it created?

**Answer:**
A stacking context is a self-contained 3D layer where `z-index` is compared. Children's `z-index` only competes within their parent's context.

Triggers:
- root element
- `position: relative/absolute` with `z-index` other than `auto`
- `position: fixed` or `sticky`
- `opacity` < 1
- `transform`, `filter`, `mask`, `perspective`, `clip-path` other than none
- `will-change` of any of the above
- `isolation: isolate`
- `mix-blend-mode` other than normal

Common gotcha: a `z-index: 9999` child inside a parent with `opacity: 0.99` can never escape that parent. Solution: `isolation: isolate` on the right ancestor.

---

### Q44. What does `isolation: isolate` do?

**Answer:**
Forces a new stacking context without other side effects. Useful to scope `z-index` or `mix-blend-mode` without resorting to `transform` or `opacity` hacks.

---

## Responsive Design

### Q45. What are media queries?

**Answer:**
Conditional CSS based on viewport or device features:

```css
@media (min-width: 768px) { ... }
@media (max-width: 767.98px) { ... }
@media (orientation: landscape) { ... }
@media (prefers-color-scheme: dark) { ... }
@media (prefers-reduced-motion: reduce) { ... }
@media (hover: hover) and (pointer: fine) { ... }
@media print { ... }
```

Mobile-first preferred: write base styles for small screens, layer larger breakpoints with `min-width`.

Range syntax (newer): `@media (width >= 768px)`.

---

### Q46. What are container queries and how do they differ from media queries?

**Answer:**
Container queries respond to a parent's size, not the viewport.

```css
.card-container {
  container-type: inline-size;
  container-name: card;
}
@container card (min-width: 400px) {
  .card { display: grid; grid-template-columns: 200px 1fr; }
}
```

A card placed in a sidebar (narrow) and main content (wide) renders differently based on its container. Solves the longstanding problem that components couldn't be truly responsive without knowing layout context.

Container query units: `cqw`, `cqh`, `cqi`, `cqb`, `cqmin`, `cqmax`.

---

### Q47. What's the difference between `vw/vh`, `svh/lvh/dvh`?

**Answer:**

- `vh`: 1% of viewport height. On mobile, often based on the largest possible viewport (excluding URL bar collapse), causing layouts to clip.
- `svh`: small viewport height — assumes UI chrome is shown
- `lvh`: large viewport height — assumes UI chrome is hidden
- `dvh`: dynamic viewport height — updates as chrome shows/hides

For full-screen mobile sections, prefer `100dvh` (with `100vh` fallback).

---

### Q48. How do you build responsive images?

**Answer:**

```html
<!-- different sizes -->
<img
  srcset="img-400.jpg 400w, img-800.jpg 800w, img-1600.jpg 1600w"
  sizes="(max-width: 600px) 100vw, 50vw"
  src="img-800.jpg"
  alt="...">

<!-- different formats / art direction -->
<picture>
  <source type="image/avif" srcset="hero.avif">
  <source type="image/webp" srcset="hero.webp">
  <img src="hero.jpg" alt="...">
</picture>
```

Always include `width`/`height` attributes to reserve space and prevent layout shift.

---

## Selectors, Specificity, Cascade

### Q49. What are CSS combinators?

**Answer:**

| Combinator | Selects |
|-----------|---------|
| `A B` (descendant) | Any B inside A |
| `A > B` (child) | B that is a direct child of A |
| `A + B` (adjacent sibling) | B immediately following A |
| `A ~ B` (general sibling) | Any B following A with same parent |

---

### Q50. Explain attribute selectors.

**Answer:**

```css
[type="email"]       /* exact match */
[href^="https://"]   /* starts with */
[href$=".pdf"]       /* ends with */
[class*="btn-"]      /* contains substring */
[lang|="en"]         /* equals or starts with `en-` */
[title~="hello"]     /* contains word */
[type="text" i]      /* case-insensitive */
```

Useful for state-based styling without classes (`[aria-expanded="true"]`).

---

### Q51. What do `:is()`, `:where()`, `:not()`, and `:has()` do?

**Answer:**

```css
:is(h1, h2, h3) a { color: red; }      /* matches any heading; specificity = highest in list */
:where(h1, h2, h3) a { color: red; }   /* same matching, specificity = 0 (low) */
input:not([type="hidden"]) { ... }
.card:has(img) { ... }                  /* parent selector — card containing an img */
form:has(input:invalid) { border: 1px solid red; }
```

`:has()` is the long-awaited "parent selector". Universally supported as of 2024.

`:where()` is great for resets/defaults to avoid specificity wars.

---

### Q52. How is specificity calculated?

**Answer:**
Three components (a, b, c):
- **a**: number of ID selectors
- **b**: number of class, attribute, pseudo-class selectors
- **c**: number of element and pseudo-element selectors

Compare left-to-right; first non-tie wins.

```
#nav .item a:hover    -> 1, 2, 1
ul li a               -> 0, 0, 3
.btn.btn-primary      -> 0, 2, 0
```

Inline styles add (1,0,0,0). `!important` overrides specificity entirely; use sparingly. `:where()` contributes 0; `:is()`/`:not()`/`:has()` contribute the highest specificity inside.

---

### Q53. What is `@layer` (cascade layers)?

**Answer:**
Cascade layers let you order groups of styles independent of source order or specificity:

```css
@layer reset, base, components, utilities;

@layer reset { * { margin: 0; } }
@layer components { .btn { padding: 1rem; } }
@layer utilities { .p-0 { padding: 0; } }
```

Later layers win over earlier ones, regardless of specificity. Unlayered styles win over all layered styles.

Solves the "third-party CSS keeps overriding mine" problem without `!important` wars.

---

## Modern CSS

### Q54. What are scroll-driven animations?

**Answer:**
CSS animations driven by scroll position, no JS needed:

```css
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

.reveal {
  animation: fade-in linear;
  animation-timeline: view();
  animation-range: entry 0% cover 30%;
}
```

`view()` triggers when the element enters the viewport; `scroll()` follows scroll progress of an ancestor. Replaces IntersectionObserver-based reveal patterns. Limited browser support — provide fallback.

---

### Q55. What is the View Transitions API?

**Answer:**
Native API for animating between DOM states or pages.

```js
document.startViewTransition(() => {
  // mutate DOM
  list.append(newItem);
});
```

```css
::view-transition-old(root), ::view-transition-new(root) {
  animation-duration: 300ms;
}
```

For multi-page (MPA) transitions:
```css
@view-transition { navigation: auto; }
```

Used heavily in Astro, Next.js for SPA-like page transitions without a SPA.

---

### Q56. What do `aspect-ratio`, `gap`, and `inset` do?

**Answer:**

```css
.thumb { aspect-ratio: 16 / 9; width: 100%; }     /* maintains ratio */
.grid { display: grid; gap: 1rem; }               /* row + column gap */
.modal { position: fixed; inset: 0; }             /* shorthand for top/right/bottom/left */
.modal { position: fixed; inset: 1rem 2rem; }     /* vertical horizontal */
```

`gap` works in flex too (modern browsers), replacing margin-based spacing.

---

### Q57. What are logical properties?

**Answer:**
Direction-aware properties for internationalization:

```css
margin-inline-start: 1rem;  /* left in LTR, right in RTL */
margin-inline: 1rem;        /* left + right */
margin-block: 1rem;         /* top + bottom */
padding-inline-end: 1rem;
border-block-end: 1px solid;
inset-inline-start: 0;
```

Critical for sites supporting both LTR (English) and RTL (Arabic, Hebrew) — write once, layout flips automatically.

---

## Animations and Effects

### Q58. What's the difference between transitions and animations?

**Answer:**

| Transition | Animation |
|-----------|-----------|
| State changes (hover, class toggle) | Standalone keyframe sequences |
| Two states: from current to new | Multiple keyframes possible |
| No looping or playback control | Iteration count, direction, fill mode, play state |

```css
/* Transition */
.btn { transition: background 200ms ease; }
.btn:hover { background: #333; }

/* Animation */
@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}
.icon { animation: pulse 1s ease-in-out infinite; }
```

---

### Q59. Which CSS properties are cheap to animate?

**Answer:**
Only `transform` and `opacity` can be composited on the GPU without triggering layout or paint. Animating `width`, `height`, `top`, `left`, `margin` causes layout recalculation on every frame and tanks performance.

```css
/* Bad */
.move { transition: left 300ms; left: 200px; }

/* Good */
.move { transition: transform 300ms; transform: translateX(200px); }
```

Use `will-change: transform` sparingly to hint compositor promotion (overuse hogs memory).

---

### Q60. What are CSS filters and blend modes?

**Answer:**

```css
.img { filter: blur(4px) grayscale(50%) brightness(1.1); }
.overlay { mix-blend-mode: multiply; }
.bg { background-blend-mode: overlay; }
.backdrop { backdrop-filter: blur(20px); }
```

Filters apply to the element. Blend modes combine the element with what's behind it. `backdrop-filter` blurs/affects the area behind a translucent element (frosted glass effect).

Both create stacking contexts.

---

### Q61. How do you respect user motion preferences?

**Answer:**

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

Vestibular disorders cause real harm from unwanted animation. WCAG requires this.

---

## Architecture and Methodologies

### Q62. What is BEM?

**Answer:**
Block Element Modifier — a naming convention.

```html
<div class="card card--featured">
  <h2 class="card__title">Title</h2>
  <button class="card__btn card__btn--primary">Buy</button>
</div>
```

- `block`: standalone component (`card`)
- `block__element`: child of block (`card__title`)
- `block--modifier` or `element--modifier`: variant (`card--featured`)

Pros: flat specificity, predictable, no nesting wars. Cons: verbose class names. Often paired with utility classes.

---

### Q63. What is OOCSS and ITCSS?

**Answer:**

**OOCSS** (Object-Oriented CSS, Nicole Sullivan):
- Separate structure from skin (layout vs visual style)
- Separate container from content (don't tie objects to a place)

**ITCSS** (Inverted Triangle CSS, Harry Roberts):
Layered architecture from generic to specific:
1. Settings (variables)
2. Tools (mixins)
3. Generic (resets)
4. Elements (bare HTML)
5. Objects (layout patterns, e.g. `.media`)
6. Components (UI parts, e.g. `.card`)
7. Utilities (overrides, e.g. `.mt-1`)

Specificity grows down the triangle. Maps cleanly to `@layer`.

---

### Q64. CSS-in-JS vs traditional CSS — trade-offs?

**Answer:**

| Approach | Pros | Cons |
|----------|------|------|
| Traditional / SCSS | Cacheable, minimal runtime, designer-friendly | Naming conventions, dead code |
| CSS Modules | Scoped by build tool, type-safe | Build setup, no theming primitives |
| Utility-first (Tailwind) | Speed, consistency, no naming | Verbose markup, learning curve |
| Runtime CSS-in-JS (styled-components, Emotion) | Dynamic styles, JS interop | Runtime cost, larger bundles, RSC issues |
| Compile-time CSS-in-JS (vanilla-extract, Linaria, Panda) | Type-safe + no runtime | Build complexity |

Modern trend favors zero-runtime: Tailwind, vanilla-extract, Panda, or CSS Modules. React Server Components especially penalize runtime CSS-in-JS.

---

### Q65. What is critical CSS?

**Answer:**
The minimal subset of CSS needed to render above-the-fold content. Inlined into `<head>` so the first render isn't blocked on the full stylesheet.

```html
<head>
  <style>/* critical CSS */</style>
  <link rel="preload" href="full.css" as="style" onload="this.rel='stylesheet'">
</head>
```

Tools: `critters`, `critical`, frameworks like Next.js handle this automatically. Improves Largest Contentful Paint.

---

## Performance

### Q66. What are paint, layout, and composite?

**Answer:**
Rendering pipeline:
1. **Style**: compute styles
2. **Layout (reflow)**: compute geometry (width, position)
3. **Paint**: fill pixels (color, text, shadows)
4. **Composite**: combine layers on GPU

Property changes trigger different stages:
- `width`, `height`, `top` -> layout -> paint -> composite (expensive)
- `color`, `background` -> paint -> composite (medium)
- `transform`, `opacity` -> composite only (cheap)

Aim for composite-only animations. Reference: csstriggers.com.

---

### Q67. What is `contain` and `content-visibility`?

**Answer:**

```css
.widget { contain: layout paint; }
.section { content-visibility: auto; contain-intrinsic-size: 0 500px; }
```

- `contain` tells the browser an element's effects don't escape — enables optimizations.
- `content-visibility: auto` skips rendering off-screen content entirely until near viewport.

Major perf win for long pages with many independent sections.

---

### Q68. How do you reduce layout shift (CLS)?

**Answer:**
- Always set explicit `width`/`height` (or `aspect-ratio`) on images, videos, iframes
- Reserve space for ads, embeds with placeholders
- Use `font-display: optional` or self-host with `size-adjust` to prevent FOUT shift
- Don't insert content above existing content (notifications, banners)
- Use `transform` for animations instead of properties that cause layout

---

### Q69. How do you optimize CSS for production?

**Answer:**
- **Minify** (cssnano, lightningcss)
- **Tree-shake unused CSS** (PurgeCSS, Tailwind JIT, Lightning CSS)
- **Split** non-critical CSS, load async
- **Inline** critical CSS
- **HTTP/2 + caching** for shared stylesheets
- **Avoid `@import` in CSS** (serial requests)
- **Use system fonts or self-hosted webfonts** with `font-display`
- **Compress** with Brotli/gzip
- **Audit** with Lighthouse, Coverage tab in DevTools

---

### Q70. How do you handle dark mode?

**Answer:**
Two strategies:

**System preference only:**
```css
:root { --bg: white; --text: black; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #111; --text: #eee; }
}
```

**User toggle (preferred for control):**
```css
:root { --bg: white; --text: black; }
[data-theme="dark"] { --bg: #111; --text: #eee; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --bg: #111; --text: #eee; }
}
```

Persist choice in `localStorage`, apply class/attribute before first paint to avoid flash.

Use `color-scheme` to opt into native dark UI (form controls, scrollbars):
```css
:root { color-scheme: light dark; }
```

---

### Q71. What's the difference between `visibility: hidden`, `display: none`, and `opacity: 0`?

**Answer:**

| Property | Visible | Takes space | Focusable / clickable | Animatable |
|----------|---------|-------------|-----------------------|------------|
| `display: none` | No | No | No | No |
| `visibility: hidden` | No | Yes | No | No (but new `display` transitions help) |
| `opacity: 0` | No | Yes | Yes (dangerous!) | Yes |

For accessible hide-but-reachable links, use a "visually hidden" pattern:

```css
.sr-only {
  position: absolute;
  width: 1px; height: 1px;
  padding: 0; margin: -1px;
  overflow: hidden;
  clip: rect(0,0,0,0);
  white-space: nowrap;
  border: 0;
}
```

---

### Q72. How do you debug CSS specificity issues?

**Answer:**
- DevTools "Computed" tab shows winning declarations and crossed-out losers
- "Styles" tab shows all matching rules in cascade order
- Specificity calculator (specificity.keegan.st)
- Audit with `:where()` to neutralize specificity for resets/utilities
- Refactor toward flat selectors (BEM, utility classes, cascade layers)

Avoid `!important` except for utility classes designed to override (e.g. accessibility helpers).
