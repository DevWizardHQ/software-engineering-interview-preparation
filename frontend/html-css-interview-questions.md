# HTML and CSS Interview Questions — Complete Q&A Guide

**Focus:** HTML5, semantics, accessibility, CSS3, modern CSS, layout, performance, architecture.

Read each answer to understand the concept, then study the code to see how it works in real markup or styles.

---

## 1. HTML Fundamentals

## Q1. What changed in HTML5 vs HTML4?

**Answer:**

HTML5 introduced semantic elements (`<header>`, `<nav>`, `<article>`, `<section>`, `<footer>`), native multimedia (`<audio>`, `<video>`, `<canvas>`), new form input types (`email`, `date`, `number`), client-side storage APIs (`localStorage`, `sessionStorage`), and a simpler `<!DOCTYPE html>`.

```html
<!DOCTYPE html>
<html lang="en">
  <head><meta charset="UTF-8" /></head>
  <body>
    <header><h1>Site</h1></header>
    <main>
      <article>
        <video src="demo.mp4" controls></video>
      </article>
    </main>
    <footer>© 2026</footer>
  </body>
</html>
```

## Q2. Difference between `<section>`, `<article>`, and `<div>`?

**Answer:**

- `<article>` is self-contained content that makes sense on its own (a blog post, a product card).
- `<section>` is a thematic grouping with a heading.
- `<div>` is a generic container with no semantic meaning — use only when no semantic element fits.

```html
<article>
  <h2>Blog post title</h2>
  <p>Body...</p>
</article>

<section>
  <h2>Comments</h2>
  <ul>...</ul>
</section>

<div class="grid-wrapper">...</div>
```

## Q3. What does the `lang` attribute do?

**Answer:**

`lang` declares the language of the page or element. Screen readers use it to choose the right pronunciation, search engines use it for indexing, and browsers use it for spell-check and hyphenation.

```html
<html lang="en">
  <p>Hello</p>
  <p lang="bn">হ্যালো</p>
</html>
```

## Q4. Difference between `<b>` and `<strong>`, `<i>` and `<em>`?

**Answer:**

`<b>` and `<i>` are purely visual (bold and italic). `<strong>` carries semantic importance and `<em>` carries semantic emphasis. Screen readers may announce `<strong>` and `<em>` differently.

```html
<p><strong>Warning:</strong> the file will be deleted.</p>
<p>This is <em>really</em> important.</p>
<p>The keyword <b>fetch</b> is highlighted.</p>
```

## Q5. What is the purpose of `<meta charset>` and viewport tags?

**Answer:**

`<meta charset="UTF-8">` tells the browser how to decode bytes into characters (always use UTF-8 today). The viewport tag controls scaling on mobile so your page is not zoomed out by default.

```html
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
</head>
```

## Q6. What meta tags are critical for SEO?

**Answer:**

```html
<title>Page title — Site</title>
<meta name="description" content="Concise summary under 160 chars" />
<link rel="canonical" href="https://example.com/page" />
<meta property="og:title" content="Title" />
<meta property="og:description" content="Description" />
<meta property="og:image" content="https://example.com/og.png" />
<meta name="twitter:card" content="summary_large_image" />
```

## Q7. What's the difference between `defer` and `async` on `<script>`?

**Answer:**

| Attribute | When the script runs |
| --- | --- |
| (none) | Blocks HTML parsing while downloading and executing. |
| `async` | Downloads in parallel; runs as soon as ready, may interrupt parsing. |
| `defer` | Downloads in parallel; runs after HTML is parsed, in document order. |

```html
<script src="analytics.js" async></script>
<script src="app.js" defer></script>
```

Use `defer` for scripts that depend on the DOM. Use `async` for independent scripts like analytics.

## Q8. Difference between `localStorage`, `sessionStorage`, and cookies?

**Answer:**

| | Capacity | Sent to server | Lifetime |
| --- | --- | --- | --- |
| `localStorage` | ~5 MB | No | Until cleared |
| `sessionStorage` | ~5 MB | No | Until tab closes |
| Cookies | ~4 KB | Yes (every request) | Configurable |

```js
localStorage.setItem('theme', 'dark');
sessionStorage.setItem('tabId', '42');
document.cookie = 'token=abc; path=/; max-age=86400';
```

For tokens, prefer `httpOnly` cookies set by the server.

## Q9. What are data attributes used for?

**Answer:**

`data-*` attributes store custom data on elements. Read them via the `dataset` property in JS.

```html
<button data-product-id="42" data-action="add-to-cart">Add</button>
```

```js
const btn = document.querySelector('button');
console.log(btn.dataset.productId); // "42"
```

---

## 2. Semantics and Accessibility

## Q10. What is semantic HTML and why does it matter?

**Answer:**

Semantic HTML uses elements that describe their meaning (`<nav>`, `<button>`, `<article>`) rather than generic ones (`<div>`, `<span>`). It improves accessibility, SEO, and code clarity.

```html
<!-- Bad -->
<div onclick="submit()">Submit</div>

<!-- Good -->
<button type="submit">Submit</button>
```

Buttons get keyboard focus, work with Enter and Space, and are announced by screen readers — for free.

## Q11. What is ARIA and when should you use it?

**Answer:**

ARIA (Accessible Rich Internet Applications) attributes describe roles, states, and properties to assistive tech. **Rule of thumb: prefer native HTML over ARIA.** Use ARIA only when no native element fits.

```html
<!-- Native is better -->
<button>Open menu</button>

<!-- ARIA only when you must build a custom widget -->
<div role="button" tabindex="0" aria-pressed="false">Toggle</div>
```

## Q12. How do you make an element keyboard-accessible?

**Answer:**

- Use native interactive elements (`<button>`, `<a>`, `<input>`).
- For custom elements, add `tabindex="0"` and handle Enter/Space in JS.
- Show a visible focus outline.

```html
<div role="button" tabindex="0" onkeydown="if(event.key==='Enter')this.click()">
  Click me
</div>
```

## Q13. What is the accessibility tree?

**Answer:**

The accessibility tree is a parallel representation of the DOM that browsers expose to assistive technologies. Each node has a role, name, state, and value. Inspect it with DevTools "Accessibility" panel.

## Q14. Difference between `aria-label`, `aria-labelledby`, and `aria-describedby`?

**Answer:**

- `aria-label="..."` provides a string label.
- `aria-labelledby="id"` points to the ID of another element whose text is the label.
- `aria-describedby="id"` points to a description (extra info, like a hint).

```html
<button aria-label="Close dialog">×</button>

<h2 id="dialog-title">Settings</h2>
<div role="dialog" aria-labelledby="dialog-title">...</div>

<input aria-describedby="hint" />
<small id="hint">Use 8 or more characters.</small>
```

## Q15. How do you make images accessible?

**Answer:**

- Provide `alt` text describing the image's purpose.
- Use empty `alt=""` for purely decorative images.
- For complex images (charts), add a longer description nearby.

```html
<img src="cat.jpg" alt="A black cat sitting on a windowsill" />
<img src="divider.svg" alt="" />
```

## Q16. What is WCAG and what are the key principles?

**Answer:**

WCAG (Web Content Accessibility Guidelines) is the standard for web accessibility. Its four principles are POUR:

- **Perceivable** — content can be seen/heard (alt text, captions).
- **Operable** — works via keyboard.
- **Understandable** — readable and predictable.
- **Robust** — works with assistive tech, valid markup.

Levels: A (minimum), AA (target), AAA (rare).

## Q17. What is a skip link?

**Answer:**

A skip link lets keyboard users jump straight to the main content, bypassing repeated navigation.

```html
<body>
  <a class="skip" href="#main">Skip to main content</a>
  <nav>...</nav>
  <main id="main">...</main>
</body>
```

```css
.skip { position: absolute; left: -9999px; }
.skip:focus { left: 1rem; top: 1rem; }
```

---

## 3. Forms and Inputs

## Q18. What input types does HTML5 provide?

**Answer:**

`text`, `email`, `password`, `number`, `tel`, `url`, `search`, `date`, `time`, `datetime-local`, `month`, `week`, `color`, `range`, `file`, `checkbox`, `radio`, `hidden`. They give native validation, mobile keyboards, and pickers.

```html
<input type="email" required />
<input type="number" min="0" max="100" step="1" />
<input type="date" />
<input type="color" />
```

## Q19. How does HTML5 form validation work?

**Answer:**

Attributes like `required`, `minlength`, `maxlength`, `pattern`, `min`, `max` trigger automatic validation. The browser shows an error and prevents submission.

```html
<form>
  <input name="email" type="email" required />
  <input name="age" type="number" min="18" required />
  <input name="zip" pattern="\d{5}" title="5 digits" />
  <button>Submit</button>
</form>
```

Customize the message via JavaScript:

```js
input.setCustomValidity('Please enter a valid email');
```

## Q20. What does `autocomplete` do and why is it important?

**Answer:**

`autocomplete` tells the browser what kind of value the field expects, enabling autofill from saved credentials, addresses, or payment methods.

```html
<input name="email" type="email" autocomplete="email" />
<input name="cc-number" autocomplete="cc-number" />
<input name="address" autocomplete="street-address" />
```

## Q21. How do you associate a label with an input?

**Answer:**

Use `for` matching the input's `id`, or wrap the input inside the `<label>`.

```html
<!-- Method 1 -->
<label for="email">Email</label>
<input id="email" type="email" />

<!-- Method 2 -->
<label>
  Password
  <input type="password" />
</label>
```

## Q22. How do you build accessible custom form controls?

**Answer:**

When wrapping or replacing native inputs:

- Forward `id`, `name`, `value`, validation state.
- Use the right ARIA role (`role="checkbox"`, `aria-checked`).
- Make focusable with `tabindex="0"`.
- Handle keyboard events (Space toggles a checkbox).

```html
<div role="checkbox" tabindex="0" aria-checked="false" id="terms">
  I accept the terms
</div>
```

---

## 4. Web Components

## Q23. What are web components?

**Answer:**

Web components are a set of standards for building reusable, encapsulated custom elements: Custom Elements, Shadow DOM, HTML Templates, and ES Modules. They work in any framework or none.

```html
<my-counter></my-counter>
```

## Q24. How do you define a custom element?

**Answer:**

```html
<my-counter></my-counter>

<script>
class MyCounter extends HTMLElement {
  connectedCallback() {
    this.count = 0;
    this.innerHTML = `<button>0</button>`;
    this.querySelector('button').addEventListener('click', () => {
      this.count++;
      this.querySelector('button').textContent = this.count;
    });
  }
}
customElements.define('my-counter', MyCounter);
</script>
```

## Q25. What is Shadow DOM and why use it?

**Answer:**

Shadow DOM creates an isolated DOM tree inside an element, with scoped CSS. Styles inside do not leak out, and outside styles do not leak in (by default).

```js
class MyCard extends HTMLElement {
  constructor() {
    super();
    const shadow = this.attachShadow({ mode: 'open' });
    shadow.innerHTML = `
      <style>p { color: red; }</style>
      <p><slot></slot></p>
    `;
  }
}
customElements.define('my-card', MyCard);
```

## Q26. How do you style Shadow DOM from outside?

**Answer:**

Use CSS custom properties (they pierce Shadow DOM) or `::part()` selectors.

```html
<my-button class="primary">Click</my-button>

<style>
my-button { --bg: blue; }
my-button::part(label) { font-weight: bold; }
</style>
```

```js
shadow.innerHTML = `
  <style>button { background: var(--bg); }</style>
  <button part="label"><slot></slot></button>
`;
```

---

## 5. CSS Fundamentals

## Q27. Explain the CSS box model.

**Answer:**

Every element is a rectangle made of content, padding, border, and margin. Width and height by default refer to the content box; total visible size includes padding and border.

```css
* { box-sizing: border-box; } /* width includes padding + border */

.box {
  width: 200px;
  padding: 16px;
  border: 2px solid;
  margin: 8px;
}
```

`box-sizing: border-box` is universally preferred — it makes layouts predictable.

## Q28. What is margin collapsing?

**Answer:**

Vertical margins of adjacent block elements collapse into the larger of the two, not the sum. It happens with siblings, parent-child, and empty blocks.

```html
<p style="margin-bottom: 30px">A</p>
<p style="margin-top: 20px">B</p>
<!-- gap is 30px, not 50px -->
```

Prevent collapsing by adding padding/border to the parent, or using flex/grid.

## Q29. What's the difference between `display` values?

**Answer:**

| Value | Behavior |
| --- | --- |
| `block` | Full width, stacks vertically |
| `inline` | Sits in text flow, ignores width/height |
| `inline-block` | Like inline but accepts width/height |
| `flex` | Flex container |
| `grid` | Grid container |
| `none` | Removes from layout and accessibility tree |
| `contents` | Element disappears, children promote up |

```css
.menu { display: flex; }
.card { display: grid; }
```

## Q30. What units exist in CSS?

**Answer:**

- Absolute: `px`, `pt`, `cm`.
- Relative to font: `em`, `rem`, `ch`, `ex`.
- Relative to viewport: `vw`, `vh`, `vmin`, `vmax`, `dvh`, `svh`, `lvh`.
- Percentages: `%` of parent.
- Fractions: `fr` for grid.

```css
.title { font-size: 1.5rem; }
.hero { height: 100dvh; }
.grid { grid-template-columns: 1fr 2fr; }
```

## Q31. Difference between `em` and `rem`?

**Answer:**

`em` is relative to the parent's font-size (compounds in nested elements). `rem` is relative to the root (`<html>`) font-size.

```css
html { font-size: 16px; }
.card { font-size: 1.5em; }       /* 24px */
.card .badge { font-size: 0.9em; } /* 0.9 × 24 = 21.6px */
.btn { font-size: 1.2rem; }       /* always 19.2px */
```

`rem` is preferred for predictable sizing.

## Q32. What are CSS custom properties (variables)?

**Answer:**

Custom properties start with `--` and are read with `var()`. They are dynamic and inherit through the cascade.

```css
:root {
  --primary: #4f46e5;
  --radius: 8px;
}

.btn {
  background: var(--primary);
  border-radius: var(--radius);
}

.theme-dark {
  --primary: #7c3aed; /* override in subtree */
}
```

## Q33. Difference between inheritance, the cascade, and specificity?

**Answer:**

- **Inheritance** — some properties (`color`, `font-family`) inherit from parent to child.
- **Cascade** — when multiple rules apply, the browser picks one based on origin → specificity → source order.
- **Specificity** — a score per selector: inline (1000) > IDs (100) > classes/attrs/pseudo-classes (10) > elements (1).

```css
.button.primary { color: blue; }   /* (0,2,0) wins */
.button { color: red; }             /* (0,1,0) */
button { color: black; }            /* (0,0,1) */
```

---

## 6. Layout — Flexbox and Grid

## Q34. Explain `flex-grow`, `flex-shrink`, `flex-basis`.

**Answer:**

- `flex-basis` is the initial size before free space is distributed.
- `flex-grow` is the share of leftover space the item takes (default 0).
- `flex-shrink` is how much the item shrinks when there is too little space (default 1).

```css
.item {
  flex: 1 1 200px; /* grow shrink basis */
}
```

`flex: 1` is shorthand for `1 1 0` — equal-width items.

## Q35. How do you center an element vertically and horizontally?

**Answer:**

```css
/* Flexbox */
.parent {
  display: flex;
  justify-content: center;
  align-items: center;
}

/* Grid */
.parent {
  display: grid;
  place-items: center;
}

/* Absolute */
.child {
  position: absolute;
  inset: 0;
  margin: auto;
}
```

## Q36. Difference between `justify-content`, `align-items`, `align-content`?

**Answer:**

In flex (default row direction):

- `justify-content` — main axis (horizontal).
- `align-items` — cross axis (vertical) for each line.
- `align-content` — cross axis when there are multiple lines.

```css
.flex {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  align-content: stretch;
}
```

## Q37. Explain CSS Grid `fr` units, `auto`, and `minmax`.

**Answer:**

- `fr` distributes leftover space proportionally.
- `auto` sizes to content.
- `minmax(min, max)` defines a range.

```css
.grid {
  display: grid;
  grid-template-columns: 200px 1fr 2fr;
  grid-template-rows: minmax(100px, auto);
}
```

## Q38. What are grid template areas?

**Answer:**

Visual layout using named areas.

```css
.layout {
  display: grid;
  grid-template-columns: 200px 1fr;
  grid-template-rows: auto 1fr auto;
  grid-template-areas:
    "header header"
    "side   main"
    "footer footer";
}
.header { grid-area: header; }
.side   { grid-area: side; }
.main   { grid-area: main; }
.footer { grid-area: footer; }
```

## Q39. What is auto-placement in CSS Grid?

**Answer:**

When you do not specify positions, Grid auto-places items in available cells. `grid-auto-flow: row` (default) or `column` controls direction. `grid-auto-rows`/`grid-auto-columns` size the implicit tracks.

```css
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-auto-rows: 100px;
  gap: 1rem;
}
```

## Q40. What is subgrid?

**Answer:**

`subgrid` lets a nested grid use the parent's tracks instead of defining its own — keeping items aligned across nesting levels.

```css
.parent {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
}
.child {
  display: grid;
  grid-template-columns: subgrid;
  grid-column: 1 / -1;
}
```

## Q41. When should you use Flexbox vs Grid?

**Answer:**

- Flexbox is one-dimensional — best for navbars, button rows, vertical stacks.
- Grid is two-dimensional — best for page layouts, dashboards, photo galleries.

You can use both together: Grid for the page, Flex inside cards.

---

## 7. Positioning and Stacking

## Q42. Explain CSS `position` values.

**Answer:**

| Value | Behavior |
| --- | --- |
| `static` | Default, normal flow |
| `relative` | In flow, but `top/left/right/bottom` shift it |
| `absolute` | Out of flow, positioned to nearest positioned ancestor |
| `fixed` | Out of flow, positioned to viewport |
| `sticky` | In flow, sticks to a position when scrolling past |

```css
.tooltip {
  position: absolute;
  top: 100%;
  left: 0;
}

.header {
  position: sticky;
  top: 0;
}
```

## Q43. What is a stacking context and how is it created?

**Answer:**

A stacking context is a group of elements whose `z-index` only competes with siblings inside the same context. Created by:

- `position: relative/absolute/fixed/sticky` with `z-index` set
- `opacity` < 1
- `transform`, `filter`, `perspective`
- `isolation: isolate`
- `will-change`

```css
.card {
  position: relative;
  z-index: 1; /* creates a stacking context */
}
```

## Q44. What does `isolation: isolate` do?

**Answer:**

It creates a new stacking context without needing `position` or `z-index`. Useful to keep `mix-blend-mode` or stacked elements from leaking into ancestors.

```css
.section { isolation: isolate; }
```

---

## 8. Responsive Design

## Q45. What are media queries?

**Answer:**

Media queries apply CSS based on viewport size, orientation, color scheme, or other features.

```css
@media (min-width: 768px) {
  .card { padding: 2rem; }
}

@media (prefers-color-scheme: dark) {
  body { background: #111; color: #eee; }
}

@media (orientation: landscape) {
  .hero { height: 60vh; }
}
```

## Q46. What are container queries?

**Answer:**

Container queries style an element based on its container's size, not the viewport. This enables truly reusable components.

```css
.card-wrapper {
  container-type: inline-size;
}

@container (min-width: 400px) {
  .card { display: grid; grid-template-columns: 1fr 2fr; }
}
```

## Q47. Difference between `vw/vh`, `svh/lvh/dvh`?

**Answer:**

- `vh` — 1% of the viewport height (legacy, may include or exclude mobile UI).
- `svh` — small viewport height (UI bars visible).
- `lvh` — large viewport height (UI bars hidden).
- `dvh` — dynamic viewport height (changes as bars appear/disappear).

Use `dvh` for full-screen mobile sections.

```css
.hero { min-height: 100dvh; }
```

## Q48. How do you build responsive images?

**Answer:**

Use `srcset` for resolution and `sizes` to declare layout width. `<picture>` lets you swap formats or art-direct.

```html
<img
  src="photo-800.jpg"
  srcset="photo-400.jpg 400w, photo-800.jpg 800w, photo-1600.jpg 1600w"
  sizes="(max-width: 600px) 100vw, 800px"
  alt="Photo"
/>

<picture>
  <source type="image/avif" srcset="photo.avif" />
  <source type="image/webp" srcset="photo.webp" />
  <img src="photo.jpg" alt="Photo" />
</picture>
```

---

## 9. Selectors, Specificity, Cascade

## Q49. What are CSS combinators?

**Answer:**

| Combinator | Meaning |
| --- | --- |
| `A B` | Descendant |
| `A > B` | Direct child |
| `A + B` | Adjacent sibling |
| `A ~ B` | Subsequent sibling |

```css
nav a { color: blue; }
nav > a { font-weight: bold; }
h2 + p { margin-top: 0; }
.label ~ input { width: 100%; }
```

## Q50. Explain attribute selectors.

**Answer:**

```css
[type="email"] { ... }       /* exact match */
[href^="https"] { ... }      /* starts with */
[href$=".pdf"] { ... }       /* ends with */
[class*="btn"] { ... }       /* contains substring */
[lang|="en"] { ... }         /* matches "en" or "en-US" */
```

## Q51. What do `:is()`, `:where()`, `:not()`, and `:has()` do?

**Answer:**

- `:is(.a, .b, .c)` — matches any of the listed selectors. Specificity is the highest of the list.
- `:where(...)` — same as `:is`, but specificity is always 0.
- `:not(.x)` — matches elements that don't match the inner selector.
- `:has(> img)` — parent that has a matching child.

```css
:is(h1, h2, h3) { font-family: serif; }
:where(p, li) { line-height: 1.5; } /* low specificity */
input:not([type="hidden"]) { ... }
.card:has(img) { padding: 0; }
```

## Q52. How is specificity calculated?

**Answer:**

Score per selector: inline > IDs > classes/attrs/pseudo-classes > elements.

```
#main .btn:hover  →  (0, 1, 2, 1)  →  121
.btn.primary       →  (0, 0, 2, 0)  →  20
button             →  (0, 0, 0, 1)  →  1
```

`!important` beats normal rules but is best avoided.

## Q53. What is `@layer` (cascade layers)?

**Answer:**

Cascade layers let you group rules into named layers. Rules in later layers always beat earlier ones, regardless of specificity.

```css
@layer reset, base, components, utilities;

@layer base {
  button { padding: 0.5rem 1rem; }
}

@layer components {
  .btn-primary { background: blue; } /* always wins over base */
}
```

---

## 10. Modern CSS

## Q54. What are scroll-driven animations?

**Answer:**

Animations driven by scroll position rather than time. Useful for reveal effects without JS.

```css
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

.section {
  animation: fade-in linear;
  animation-timeline: view();
  animation-range: entry 0% cover 30%;
}
```

## Q55. What is the View Transitions API?

**Answer:**

It animates between two DOM states with a single API call.

```js
document.startViewTransition(() => {
  document.body.classList.toggle('dark');
});
```

```css
::view-transition-old(root),
::view-transition-new(root) {
  animation-duration: 0.3s;
}
```

## Q56. What do `aspect-ratio`, `gap`, and `inset` do?

**Answer:**

- `aspect-ratio` reserves space at a given ratio.
- `gap` sets spacing between flex/grid items.
- `inset` is shorthand for `top right bottom left`.

```css
.video { aspect-ratio: 16 / 9; }
.grid { gap: 1rem 2rem; }
.modal { position: fixed; inset: 0; }
```

## Q57. What are logical properties?

**Answer:**

Logical properties adapt to writing direction (LTR/RTL/vertical). Use `margin-inline` instead of `margin-left/right`.

```css
.card {
  margin-inline: 1rem;   /* left and right in LTR; right and left in RTL */
  padding-block: 0.5rem; /* top and bottom */
  border-inline-start: 4px solid blue; /* left in LTR */
}
```

---

## 11. Animations and Effects

## Q58. Difference between transitions and animations?

**Answer:**

Transitions interpolate between two states (start → end) when a property changes. Animations are scripted with keyframes and can run continuously.

```css
.btn {
  background: blue;
  transition: background 0.3s;
}
.btn:hover { background: navy; }

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50%      { transform: scale(1.05); }
}
.live { animation: pulse 1s infinite; }
```

## Q59. Which CSS properties are cheap to animate?

**Answer:**

Animate `transform` and `opacity` — they run on the GPU and skip layout/paint. Animating `width`, `top`, or `margin` triggers layout and is slower.

```css
/* Good */
.box { transform: translateX(0); transition: transform 0.3s; }
.box:hover { transform: translateX(20px); }

/* Avoid */
.box { left: 0; transition: left 0.3s; }
```

## Q60. What are CSS filters and blend modes?

**Answer:**

`filter` applies effects like blur, grayscale, contrast. `mix-blend-mode` blends an element's pixels with what is behind it.

```css
.thumb { filter: grayscale(1) blur(2px); }
.overlay { mix-blend-mode: multiply; }
```

## Q61. How do you respect user motion preferences?

**Answer:**

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## 12. Architecture and Methodologies

## Q62. What is BEM?

**Answer:**

BEM (Block, Element, Modifier) is a naming convention for CSS classes that keeps styles flat and predictable.

```html
<div class="card card--featured">
  <h2 class="card__title">Title</h2>
  <p class="card__body">Body</p>
</div>
```

```css
.card { ... }
.card--featured { border: 2px solid gold; }
.card__title { ... }
```

## Q63. What is OOCSS and ITCSS?

**Answer:**

- **OOCSS (Object-Oriented CSS)** — separate structure from skin (`.btn` + `.btn-primary`).
- **ITCSS (Inverted Triangle CSS)** — organize files in increasing specificity layers: settings → tools → generic → elements → objects → components → utilities.

## Q64. CSS-in-JS vs traditional CSS — trade-offs?

**Answer:**

CSS-in-JS (styled-components, Emotion):
- Scoped styles automatically.
- Dynamic styles based on props.
- Runtime cost; can hurt performance.
- Issues with React Server Components.

Traditional CSS / CSS Modules:
- Better performance, no runtime.
- Static, more predictable.
- Need a naming convention to avoid collisions.

## Q65. What is critical CSS?

**Answer:**

Critical CSS is the minimum CSS needed to render above-the-fold content. Inlining it in `<head>` makes the page paint faster; the rest is loaded asynchronously.

```html
<head>
  <style>/* critical above-the-fold styles */</style>
  <link rel="preload" href="full.css" as="style" onload="this.rel='stylesheet'" />
</head>
```

---

## 13. Performance

## Q66. What are paint, layout, and composite?

**Answer:**

The browser rendering pipeline:

1. **Layout** — calculate positions and sizes (changes to `width`, `top`).
2. **Paint** — fill in pixels (changes to `color`, `background`).
3. **Composite** — combine layers on the GPU (changes to `transform`, `opacity`).

Animating composite-only properties is fastest.

## Q67. What is `contain` and `content-visibility`?

**Answer:**

`contain` tells the browser an element's internals do not affect the outside, allowing layout/paint optimizations.

`content-visibility: auto` skips rendering off-screen elements until needed.

```css
.card {
  contain: layout paint;
}

.section {
  content-visibility: auto;
  contain-intrinsic-size: 500px;
}
```

## Q68. How do you reduce layout shift (CLS)?

**Answer:**

- Always set `width` and `height` on images and videos.
- Reserve space for ads and embeds.
- Avoid inserting content above existing content.
- Use `font-display: optional` or preloaded fonts.

```html
<img src="hero.jpg" width="1600" height="900" alt="" />
```

## Q69. How do you optimize CSS for production?

**Answer:**

- Minify and gzip/brotli.
- Remove unused CSS (PurgeCSS, Tailwind's JIT).
- Inline critical CSS.
- Split large files per route.
- Use `@layer` to avoid specificity arms races.

## Q70. How do you handle dark mode?

**Answer:**

Use CSS variables and a `[data-theme]` attribute or `prefers-color-scheme`.

```css
:root {
  --bg: white;
  --fg: black;
}
[data-theme="dark"], 
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d0d0d;
    --fg: #f5f5f5;
  }
}
body {
  background: var(--bg);
  color: var(--fg);
}
```

```js
document.documentElement.dataset.theme = 'dark';
```

## Q71. Difference between `visibility: hidden`, `display: none`, and `opacity: 0`?

**Answer:**

| | Takes space | Receives clicks | Accessible |
| --- | --- | --- | --- |
| `display: none` | No | No | No |
| `visibility: hidden` | Yes | No | No |
| `opacity: 0` | Yes | Yes | Yes |

```css
.tooltip { opacity: 0; transition: opacity 0.2s; }
.tooltip.show { opacity: 1; }
```

## Q72. How do you debug CSS specificity issues?

**Answer:**

- Inspect the element in DevTools and check the "Computed" tab.
- Look at which rule wins; click to see the file/line.
- If specificity is the issue, raise the winning selector or rewrite using `@layer`.
- Avoid `!important` — fix the root cause.

## Q73. How do you make a CSS-only dropdown menu?

**Answer:**

Use `:hover` and `:focus-within` with a relatively positioned wrapper.

```html
<nav>
  <details class="menu">
    <summary>Menu</summary>
    <ul>
      <li><a href="/a">A</a></li>
      <li><a href="/b">B</a></li>
    </ul>
  </details>
</nav>
```

```css
.menu ul {
  position: absolute;
  display: none;
}
.menu[open] ul { display: block; }
```

## Q74. How do you make a sticky footer with CSS Grid?

**Answer:**

```css
body {
  min-height: 100dvh;
  display: grid;
  grid-template-rows: auto 1fr auto;
}
```

```html
<body>
  <header>...</header>
  <main>...</main>
  <footer>...</footer>
</body>
```

## Q75. What is the difference between `<a>` and `<button>`?

**Answer:**

`<a>` navigates to a URL. `<button>` triggers an action on the current page. Using a button-styled link or link-styled button is fine, but the underlying element should match its purpose for accessibility.

```html
<a href="/about">About</a>          <!-- navigation -->
<button onclick="open()">Open</button> <!-- action -->
```

## Q76. How do you create custom checkboxes and radios?

**Answer:**

Hide the native input visually but keep it accessible, then style a sibling.

```html
<label class="check">
  <input type="checkbox" />
  <span></span>
  Accept terms
</label>
```

```css
.check input { position: absolute; opacity: 0; }
.check span {
  width: 1rem; height: 1rem; border: 1px solid;
  display: inline-block;
}
.check input:checked + span { background: blue; }
.check input:focus + span { outline: 2px solid; }
```

## Q77. How do you make text truncate with ellipsis?

**Answer:**

Single line:

```css
.truncate {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
```

Multi-line:

```css
.clamp {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
```

## Q78. What does `pointer-events` do?

**Answer:**

`pointer-events: none` makes an element unable to receive mouse/touch events — clicks pass through to elements below.

```css
.disabled { pointer-events: none; opacity: 0.5; }
```

## Q79. What is `scroll-snap`?

**Answer:**

Snaps the scroll position to specific points, useful for carousels.

```css
.gallery {
  display: flex;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
}
.gallery img {
  scroll-snap-align: start;
  flex: 0 0 100%;
}
```

## Q80. What are CSS counters?

**Answer:**

CSS counters number elements automatically.

```css
ol.legal {
  counter-reset: section;
  list-style: none;
}
ol.legal > li {
  counter-increment: section;
}
ol.legal > li::before {
  content: counters(section, ".") ". ";
}
```

---

## 14. Quick Reference

| Concept | Tool |
| ------- | ---- |
| Layout | Flexbox + Grid |
| Spacing | `gap`, `margin-inline`, `padding-block` |
| Theming | CSS custom properties |
| Responsiveness | Container queries + media queries |
| Animation | `transform`, `opacity`, `@keyframes` |
| Architecture | BEM, ITCSS, `@layer` |
| Accessibility | Semantic HTML, ARIA when needed |
| Performance | Critical CSS, `content-visibility`, image dimensions |
