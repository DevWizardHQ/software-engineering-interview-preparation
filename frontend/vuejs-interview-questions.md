# Vue.js Interview Questions — Complete Q&A Guide

**Focus:** Vue 3, Composition API, reactivity, Vue Router, Pinia, performance, and testing.

Each question gives a clear plain-English explanation followed by a working code example you can run. Read, understand, then practice the code.

---

## 1. Core Concepts

## Q1. What is Vue.js?

**Answer:**

Vue.js is a progressive JavaScript framework for building user interfaces. Unlike React, Vue uses a template-based approach with HTML-like syntax and a reactivity system that automatically tracks dependencies. Vue 3 is the current major version, with the Composition API as the recommended way to build components.

```vue
<script setup>
import { ref } from 'vue';
const name = ref('Iqbal');
</script>

<template>
  <h1>Hello, {{ name }}!</h1>
</template>
```

## Q2. What is the Vue instance lifecycle?

**Answer:**

A Vue component goes through several phases: created, mounted (in DOM), updated (when reactive data changes), and unmounted. You hook into these phases with lifecycle hooks.

```vue
<script setup>
import { onMounted, onUnmounted, onUpdated } from 'vue';

onMounted(() => console.log('component is in the DOM'));
onUpdated(() => console.log('reactive data changed'));
onUnmounted(() => console.log('component removed'));
</script>
```

In Options API the equivalents are `mounted()`, `updated()`, `unmounted()`.

## Q3. What is the virtual DOM in Vue?

**Answer:**

Vue keeps a virtual representation of the DOM as a JavaScript object tree. When state changes, Vue builds a new tree, diffs it with the old one, and patches only the parts of the real DOM that changed. Vue 3's compiler also produces optimization hints to skip large static parts of templates.

---

## 2. Options API vs Composition API

## Q4. What is the Options API?

**Answer:**

The Options API organizes a component into named options: `data`, `methods`, `computed`, `watch`, lifecycle hooks. It is the original Vue style.

```vue
<script>
export default {
  data() {
    return { count: 0 };
  },
  computed: {
    double() { return this.count * 2; },
  },
  methods: {
    increment() { this.count++; },
  },
};
</script>

<template>
  <button @click="increment">{{ count }} ({{ double }})</button>
</template>
```

## Q5. What is the Composition API?

**Answer:**

The Composition API lets you write component logic as plain JavaScript functions using `setup()` (or `<script setup>`). Reactive state and side-effects live together by feature, not by option type. It scales better in larger components and makes logic reuse straightforward via composables.

```vue
<script setup>
import { ref, computed } from 'vue';

const count = ref(0);
const double = computed(() => count.value * 2);
const increment = () => count.value++;
</script>

<template>
  <button @click="increment">{{ count }} ({{ double }})</button>
</template>
```

## Q6. When would you use Options API vs Composition API?

**Answer:**

Use Composition API for new projects, especially when components grow large or you want to reuse logic across components (composables). Use Options API in legacy Vue 2 codebases, simple demo components, or when working with developers used to that style. Both can coexist in the same project.

## Q7. What is `<script setup>`?

**Answer:**

`<script setup>` is syntactic sugar for the Composition API. Variables, functions, and imports declared in it are automatically exposed to the template, with less boilerplate.

```vue
<script setup>
import { ref } from 'vue';
const message = ref('Hello');
</script>

<template>
  <p>{{ message }}</p>
</template>
```

Compare to without setup — you would have to `return { message }` from `setup()`.

---

## 3. Reactivity System

## Q8. What is `ref`?

**Answer:**

`ref()` creates a reactive reference around a value. Access or change the value via `.value` in script. In templates, the `.value` is unwrapped automatically.

```vue
<script setup>
import { ref } from 'vue';

const count = ref(0);
const increment = () => count.value++;
</script>

<template>
  <button @click="increment">{{ count }}</button>
</template>
```

Use `ref` for primitives (numbers, strings, booleans) and when you need to reassign the whole value.

## Q9. What is `reactive`?

**Answer:**

`reactive()` makes an object deeply reactive. You access properties directly without `.value`. It only works on objects and arrays, and you cannot reassign the whole reactive variable.

```vue
<script setup>
import { reactive } from 'vue';

const state = reactive({ count: 0, user: { name: 'Iqbal' } });

state.count++;
state.user.name = 'New Name';
</script>

<template>
  <p>{{ state.count }} {{ state.user.name }}</p>
</template>
```

## Q10. What is `computed`?

**Answer:**

`computed()` creates a derived reactive value that caches its result and only recomputes when its dependencies change.

```vue
<script setup>
import { ref, computed } from 'vue';

const firstName = ref('Iqbal');
const lastName = ref('Hasan');
const fullName = computed(() => `${firstName.value} ${lastName.value}`);
</script>

<template>
  <p>{{ fullName }}</p>
</template>
```

You can also create a writable computed with `get` and `set`.

## Q11. What is `watch` vs `watchEffect`?

**Answer:**

`watch` watches one or more specific reactive sources and runs a callback when they change, giving you both old and new values. `watchEffect` runs once immediately and re-runs whenever any reactive value used inside it changes — no explicit source list.

```vue
<script setup>
import { ref, watch, watchEffect } from 'vue';

const count = ref(0);

watch(count, (newVal, oldVal) => {
  console.log(`count went from ${oldVal} to ${newVal}`);
});

watchEffect(() => {
  console.log(`count is now ${count.value}`);
});
</script>
```

Use `watch` when you need explicit control. Use `watchEffect` when you want auto-tracking.

## Q12. What is a composable?

**Answer:**

A composable is a JavaScript function that uses Vue's Composition API to encapsulate reusable stateful logic. Naming convention: prefix with `use`.

```js
// composables/useCounter.js
import { ref } from 'vue';

export function useCounter(initial = 0) {
  const count = ref(initial);
  const increment = () => count.value++;
  const decrement = () => count.value--;
  return { count, increment, decrement };
}
```

```vue
<script setup>
import { useCounter } from '@/composables/useCounter';
const { count, increment } = useCounter(5);
</script>

<template>
  <button @click="increment">{{ count }}</button>
</template>
```

---

## 4. Directives

## Q13. What are Vue directives?

**Answer:**

Directives are special template attributes prefixed with `v-` that apply reactive behavior to the DOM. Common ones: `v-if`, `v-else`, `v-for`, `v-bind`, `v-on`, `v-model`, `v-show`.

```vue
<template>
  <input v-model="text" />
  <button :disabled="!text" @click="submit">Send</button>
  <p v-if="text">Length: {{ text.length }}</p>
</template>
```

## Q14. Difference between `v-if` and `v-show`?

**Answer:**

`v-if` adds or removes the element from the DOM. `v-show` keeps it in the DOM and toggles `display: none`. Use `v-if` for content rarely shown and `v-show` for content toggled often.

```vue
<template>
  <div v-if="loggedIn">Dashboard</div>
  <div v-show="hasNotifications">Bell</div>
</template>
```

## Q15. How does `v-model` work?

**Answer:**

`v-model` is two-way binding: it sets `value` and listens for `input` events on form elements. Under the hood it is `:value="x"` plus `@input="x = $event.target.value"`.

```vue
<script setup>
import { ref } from 'vue';
const name = ref('');
</script>

<template>
  <input v-model="name" />
  <p>Hello {{ name }}</p>
</template>
```

For custom components, define a prop named `modelValue` and emit `update:modelValue`.

```vue
<!-- CustomInput.vue -->
<script setup>
defineProps(['modelValue']);
defineEmits(['update:modelValue']);
</script>

<template>
  <input :value="modelValue" @input="$emit('update:modelValue', $event.target.value)" />
</template>
```

## Q16. What is `v-for` and why does it need a key?

**Answer:**

`v-for` iterates over arrays or objects to render lists. The `key` attribute helps Vue track items between renders, so it can reuse and reorder DOM nodes correctly instead of recreating them.

```vue
<template>
  <ul>
    <li v-for="user in users" :key="user.id">{{ user.name }}</li>
  </ul>
</template>
```

Use a stable unique ID (not array index) when items can be added, removed, or reordered.

## Q17. How do you create a custom directive?

**Answer:**

Define an object with hooks like `mounted` and `updated`, then register it globally or locally.

```js
// main.js
import { createApp } from 'vue';
import App from './App.vue';

const app = createApp(App);
app.directive('focus', {
  mounted(el) { el.focus(); },
});
app.mount('#app');
```

```vue
<template>
  <input v-focus />
</template>
```

---

## 5. Components

## Q18. How do props work in Vue?

**Answer:**

Props are declared with `defineProps` (in `<script setup>`) or the `props` option (Options API). They flow from parent to child and should not be mutated directly.

```vue
<!-- Child.vue -->
<script setup>
const props = defineProps({
  title: { type: String, required: true },
  count: { type: Number, default: 0 },
});
</script>

<template>
  <h2>{{ props.title }} — {{ count }}</h2>
</template>
```

```vue
<!-- Parent.vue -->
<Child title="Hello" :count="5" />
```

## Q19. How do emits work?

**Answer:**

Emits are events a child sends to its parent. Declare them with `defineEmits`, then call the returned function.

```vue
<!-- Child.vue -->
<script setup>
const emit = defineEmits(['save']);
const onClick = () => emit('save', { id: 1 });
</script>

<template>
  <button @click="onClick">Save</button>
</template>
```

```vue
<!-- Parent.vue -->
<Child @save="payload => console.log(payload)" />
```

## Q20. What are slots?

**Answer:**

Slots let a parent inject markup into a child component. The child decides where it appears.

```vue
<!-- Card.vue -->
<template>
  <div class="card">
    <slot name="header">Default header</slot>
    <slot></slot>
    <slot name="footer" />
  </div>
</template>
```

```vue
<!-- Usage -->
<Card>
  <template #header><h3>Title</h3></template>
  <p>Body content</p>
  <template #footer><button>OK</button></template>
</Card>
```

Scoped slots let the child pass data back to the slot:

```vue
<!-- List.vue -->
<template>
  <ul>
    <li v-for="item in items" :key="item.id">
      <slot :item="item" />
    </li>
  </ul>
</template>

<!-- Usage -->
<List :items="users">
  <template #default="{ item }">
    {{ item.name }}
  </template>
</List>
```

## Q21. What is `provide` and `inject`?

**Answer:**

`provide`/`inject` lets a parent component share data with descendants without passing props at every level — Vue's equivalent of React's Context API.

```vue
<!-- Parent.vue -->
<script setup>
import { provide, ref } from 'vue';
const theme = ref('dark');
provide('theme', theme);
</script>
```

```vue
<!-- DeepChild.vue -->
<script setup>
import { inject } from 'vue';
const theme = inject('theme', 'light'); // default if not provided
</script>

<template>
  <p>Theme: {{ theme }}</p>
</template>
```

---

## 6. Vue Router

## Q22. How do you set up Vue Router?

**Answer:**

Install `vue-router`, define routes, and `app.use(router)`.

```js
// router.js
import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  { path: '/', component: () => import('./views/Home.vue') },
  { path: '/users/:id', component: () => import('./views/User.vue') },
];

export default createRouter({
  history: createWebHistory(),
  routes,
});
```

```js
// main.js
import router from './router';
app.use(router);
```

```vue
<!-- App.vue -->
<template>
  <router-link to="/">Home</router-link>
  <router-view />
</template>
```

## Q23. How do you navigate programmatically?

**Answer:**

Use `useRouter` (Composition API) or `this.$router` (Options API).

```vue
<script setup>
import { useRouter, useRoute } from 'vue-router';
const router = useRouter();
const route = useRoute();

const goToProfile = () => router.push(`/users/${route.params.id}`);
</script>
```

## Q24. What are navigation guards?

**Answer:**

Guards are hooks that run before navigation completes — used for auth, redirects, or data loading.

```js
router.beforeEach((to, from, next) => {
  if (to.meta.requiresAuth && !isLoggedIn()) {
    next('/login');
  } else {
    next();
  }
});
```

In a route record:

```js
{ path: '/dashboard', component: Dashboard, meta: { requiresAuth: true } }
```

---

## 7. State Management

## Q25. What is Pinia and why prefer it over Vuex?

**Answer:**

Pinia is the official Vue state management library. It is simpler than Vuex, provides full TypeScript inference, no mutations boilerplate, and feels like writing composables. Vuex 4 still works but is in maintenance mode.

## Q26. How do you create and use a Pinia store?

**Answer:**

```js
// stores/counter.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export const useCounterStore = defineStore('counter', () => {
  const count = ref(0);
  const double = computed(() => count.value * 2);
  function increment() { count.value++; }
  return { count, double, increment };
});
```

```vue
<!-- usage -->
<script setup>
import { useCounterStore } from '@/stores/counter';
import { storeToRefs } from 'pinia';

const counter = useCounterStore();
const { count, double } = storeToRefs(counter); // keep reactivity
</script>

<template>
  <button @click="counter.increment">{{ count }} ({{ double }})</button>
</template>
```

## Q27. How does Vuex work?

**Answer:**

Vuex centralizes state in a single store, modified through synchronous mutations and asynchronous actions. Components read state via getters.

```js
import { createStore } from 'vuex';

const store = createStore({
  state: () => ({ count: 0 }),
  mutations: {
    increment(state) { state.count++; },
  },
  actions: {
    asyncIncrement({ commit }) {
      setTimeout(() => commit('increment'), 1000);
    },
  },
  getters: {
    double: state => state.count * 2,
  },
});
```

```vue
<script setup>
import { useStore } from 'vuex';
const store = useStore();
</script>

<template>
  <button @click="store.commit('increment')">{{ store.state.count }}</button>
</template>
```

---

## 8. Performance Optimization

## Q28. How do you optimize Vue component rendering?

**Answer:**

- Use `v-show` instead of `v-if` for frequently toggled elements.
- Use `key` correctly with `v-for`.
- Use `defineAsyncComponent` for code splitting.
- Use `shallowRef` or `markRaw` for large non-reactive structures.
- Avoid unnecessary nested components and watchers.

```vue
<script setup>
import { defineAsyncComponent } from 'vue';
const Heavy = defineAsyncComponent(() => import('./Heavy.vue'));
</script>

<template>
  <Heavy />
</template>
```

## Q29. What is `shallowRef` vs `ref`?

**Answer:**

`ref` makes the value deeply reactive (Vue tracks every nested property). `shallowRef` only tracks the top-level reference — changes to nested properties do not trigger updates. Use it for large objects (charts, maps) where deep reactivity is wasteful.

```js
import { shallowRef, triggerRef } from 'vue';

const data = shallowRef({ items: [...largeArray] });
data.value.items.push(newItem); // does NOT trigger update
triggerRef(data); // manually trigger
```

---

## 9. Testing

## Q30. How do you test Vue components?

**Answer:**

Use Vitest (or Jest) with Vue Test Utils. Mount the component, interact with it, and assert on the DOM.

```js
import { mount } from '@vue/test-utils';
import Counter from './Counter.vue';

test('increments on click', async () => {
  const wrapper = mount(Counter);
  await wrapper.find('button').trigger('click');
  expect(wrapper.text()).toContain('1');
});
```

## Q31. How do you test Pinia stores?

**Answer:**

Create a fresh Pinia instance in each test and call store methods directly.

```js
import { setActivePinia, createPinia } from 'pinia';
import { useCounterStore } from '@/stores/counter';
import { beforeEach, test, expect } from 'vitest';

beforeEach(() => setActivePinia(createPinia()));

test('increments count', () => {
  const counter = useCounterStore();
  counter.increment();
  expect(counter.count).toBe(1);
});
```

---

## 10. Vue 3 Advanced Features

## Q32. What is Teleport?

**Answer:**

`<Teleport>` renders its content into a different part of the DOM, useful for modals, tooltips, and dropdowns that need to break out of overflow contexts.

```vue
<template>
  <Teleport to="body">
    <div class="modal">
      <p>I'm rendered at the end of body</p>
    </div>
  </Teleport>
</template>
```

## Q33. What is Suspense in Vue?

**Answer:**

`<Suspense>` (still experimental but stable in practice) waits for nested async components or async `setup()` to resolve, showing a fallback meanwhile.

```vue
<template>
  <Suspense>
    <template #default>
      <AsyncDashboard />
    </template>
    <template #fallback>
      <p>Loading...</p>
    </template>
  </Suspense>
</template>
```

## Q34. What is `defineExpose`?

**Answer:**

In `<script setup>`, nothing inside is exposed to a parent ref by default. `defineExpose` lets you opt-in specific bindings.

```vue
<!-- Child.vue -->
<script setup>
import { ref } from 'vue';
const open = ref(false);
const show = () => open.value = true;
defineExpose({ show });
</script>
```

```vue
<!-- Parent.vue -->
<script setup>
import { ref } from 'vue';
const childRef = ref();
const trigger = () => childRef.value.show();
</script>

<template>
  <Child ref="childRef" />
  <button @click="trigger">Open</button>
</template>
```

## Q35. What is the difference between `toRef` and `toRefs`?

**Answer:**

When you destructure a `reactive` object you lose reactivity. `toRefs` converts each property of a reactive object into a `ref`, preserving reactivity. `toRef` does the same for one specific property.

```js
import { reactive, toRefs, toRef } from 'vue';

const state = reactive({ name: 'Iqbal', age: 28 });

// Wrong — destructuring breaks reactivity
const { name } = state;

// Correct
const { name: nameRef, age: ageRef } = toRefs(state);
const nameOnly = toRef(state, 'name');
```

---

## 11. More Practical Topics

## Q36. How do you fetch data in a Vue component?

**Answer:**

Trigger the fetch in `onMounted` (or in the route guard) and store the response in `ref`s.

```vue
<script setup>
import { ref, onMounted } from 'vue';

const users = ref([]);
const loading = ref(true);

onMounted(async () => {
  const res = await fetch('/api/users');
  users.value = await res.json();
  loading.value = false;
});
</script>

<template>
  <p v-if="loading">Loading...</p>
  <ul v-else>
    <li v-for="u in users" :key="u.id">{{ u.name }}</li>
  </ul>
</template>
```

For real apps, use a library like VueQuery (`@tanstack/vue-query`).

## Q37. How do you handle forms in Vue?

**Answer:**

Bind inputs with `v-model`, validate on submit. For complex forms, use VeeValidate or FormKit.

```vue
<script setup>
import { ref } from 'vue';

const form = ref({ email: '', password: '' });
const errors = ref({});

function submit() {
  errors.value = {};
  if (!form.value.email.includes('@')) errors.value.email = 'Invalid email';
  if (form.value.password.length < 8) errors.value.password = 'Min 8 chars';
  if (Object.keys(errors.value).length === 0) {
    console.log('submit', form.value);
  }
}
</script>

<template>
  <form @submit.prevent="submit">
    <input v-model="form.email" />
    <span v-if="errors.email">{{ errors.email }}</span>
    <input v-model="form.password" type="password" />
    <span v-if="errors.password">{{ errors.password }}</span>
    <button>Submit</button>
  </form>
</template>
```

## Q38. What are event modifiers?

**Answer:**

Event modifiers are suffixes on `v-on` that handle common patterns: `.prevent`, `.stop`, `.once`, `.capture`, `.self`.

```vue
<template>
  <form @submit.prevent="onSubmit">
    <button @click.stop="something">Inner</button>
  </form>
</template>
```

`.prevent` calls `event.preventDefault()`. `.stop` calls `event.stopPropagation()`.

## Q39. What are key modifiers?

**Answer:**

Key modifiers fire only on specific keys.

```vue
<template>
  <input @keyup.enter="submit" @keyup.esc="cancel" />
</template>
```

## Q40. What is the difference between `attribute` and `property` binding in Vue?

**Answer:**

`v-bind` (or `:`) binds to a JavaScript property when one exists; otherwise it sets an HTML attribute. Use `.prop` modifier to force property binding, `.attr` to force attribute binding.

```vue
<template>
  <progress :value="50" max="100" />
  <input :value="text" />
</template>
```

## Q41. How do you bind dynamic class and style?

**Answer:**

```vue
<template>
  <div :class="{ active: isActive, error: hasError }">Object syntax</div>
  <div :class="['base', isActive ? 'active' : '']">Array syntax</div>
  <div :style="{ color: textColor, fontSize: size + 'px' }">Style</div>
</template>
```

## Q42. What are async components?

**Answer:**

`defineAsyncComponent` lazily loads a component when it is needed.

```vue
<script setup>
import { defineAsyncComponent } from 'vue';

const Modal = defineAsyncComponent({
  loader: () => import('./Modal.vue'),
  loadingComponent: () => 'Loading...',
  errorComponent: () => 'Failed',
  delay: 200,
  timeout: 5000,
});
</script>
```

## Q43. What is `KeepAlive`?

**Answer:**

`<KeepAlive>` caches inactive component instances instead of destroying them, so their state is preserved when they are toggled back. Useful for tabs.

```vue
<template>
  <KeepAlive>
    <component :is="currentTab" />
  </KeepAlive>
</template>
```

## Q44. What is `Transition`?

**Answer:**

`<Transition>` adds enter/leave CSS classes around the toggle of an element, enabling animations.

```vue
<template>
  <Transition name="fade">
    <p v-if="show">Hello</p>
  </Transition>
</template>

<style>
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.3s;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>
```

## Q45. What is `TransitionGroup`?

**Answer:**

`<TransitionGroup>` animates entering, leaving, and reordering of list items. Always provide a `key` and a `tag`.

```vue
<template>
  <TransitionGroup tag="ul" name="list">
    <li v-for="item in items" :key="item.id">{{ item.text }}</li>
  </TransitionGroup>
</template>
```

## Q46. How do you create a global plugin?

**Answer:**

A plugin is an object with an `install` method that gets `app` and options.

```js
const myPlugin = {
  install(app, options) {
    app.config.globalProperties.$translate = key => translations[key] ?? key;
    app.provide('config', options);
  },
};

app.use(myPlugin, { locale: 'en' });
```

## Q47. What is the difference between `v-bind` and `v-on`?

**Answer:**

`v-bind` (`:`) binds an attribute or prop to a JavaScript expression. `v-on` (`@`) binds an event listener.

```vue
<template>
  <button :disabled="loading" @click="save">Save</button>
</template>
```

## Q48. How do you handle errors globally?

**Answer:**

Use `app.config.errorHandler` for component errors and `window.onerror` for everything else.

```js
app.config.errorHandler = (err, instance, info) => {
  console.error(err);
  reportToService(err);
};
```

## Q49. What are template refs?

**Answer:**

Template refs let you access a DOM element or child component instance.

```vue
<script setup>
import { ref, onMounted } from 'vue';
const inputRef = ref();
onMounted(() => inputRef.value.focus());
</script>

<template>
  <input ref="inputRef" />
</template>
```

## Q50. What is `nextTick`?

**Answer:**

`nextTick` waits until Vue has applied DOM updates after a state change. Useful when you need to read or focus a freshly rendered element.

```vue
<script setup>
import { ref, nextTick } from 'vue';

const visible = ref(false);
const inputRef = ref();

async function open() {
  visible.value = true;
  await nextTick();
  inputRef.value.focus();
}
</script>
```

## Q51. What is the difference between `defineProps` with type vs runtime declarations?

**Answer:**

You can declare props with type-only syntax (TypeScript) or runtime objects with validation.

```vue
<!-- Type-only -->
<script setup lang="ts">
defineProps<{ id: number; title?: string }>();
</script>

<!-- Runtime with defaults and validation -->
<script setup>
defineProps({
  id: { type: Number, required: true },
  title: { type: String, default: 'Untitled' },
});
</script>
```

## Q52. How do you create a two-way binding for a custom component (multiple v-models)?

**Answer:**

Vue 3 supports multiple `v-model` on the same component using arguments.

```vue
<!-- Form.vue -->
<script setup>
defineProps(['title', 'body']);
defineEmits(['update:title', 'update:body']);
</script>

<template>
  <input :value="title" @input="$emit('update:title', $event.target.value)" />
  <textarea :value="body" @input="$emit('update:body', $event.target.value)" />
</template>
```

```vue
<!-- Parent -->
<Form v-model:title="title" v-model:body="body" />
```

## Q53. What is the difference between `v-once` and `v-memo`?

**Answer:**

`v-once` renders an element only once and never updates it. `v-memo` re-renders only when its dependency array changes — useful inside `v-for` for very long lists.

```vue
<template>
  <h1 v-once>Static title</h1>
  <li v-for="item in list" :key="item.id" v-memo="[item.id, item.selected]">
    {{ item.label }}
  </li>
</template>
```

## Q54. How do you handle SSR with Vue?

**Answer:**

For SSR, use Nuxt or Vite SSR. Manually, you can use `vue/server-renderer` to render to a string.

```js
import { renderToString } from 'vue/server-renderer';
import { createSSRApp } from 'vue';

const app = createSSRApp({ data: () => ({ msg: 'Hi' }), template: '<h1>{{ msg }}</h1>' });
const html = await renderToString(app);
```

## Q55. How do you debounce input in Vue?

**Answer:**

Wrap a function with debounce and call it from `@input`.

```vue
<script setup>
import { ref } from 'vue';

const query = ref('');
let timer;

function onInput(e) {
  clearTimeout(timer);
  timer = setTimeout(() => {
    query.value = e.target.value;
  }, 300);
}
</script>

<template>
  <input @input="onInput" />
  <p>{{ query }}</p>
</template>
```

Or use a composable like `useDebounceFn` from VueUse.

## Q56. What is VueUse?

**Answer:**

VueUse is a popular collection of essential composables: `useLocalStorage`, `useFetch`, `useMouse`, `useDebounceFn`, and many more.

```vue
<script setup>
import { useLocalStorage, useMouse } from '@vueuse/core';
const name = useLocalStorage('name', '');
const { x, y } = useMouse();
</script>
```

## Q57. How does reactivity work under the hood?

**Answer:**

Vue 3 uses ES6 `Proxy` to intercept property reads and writes on reactive objects. When a getter runs during component setup, Vue tracks which effect (component render) is reading the property; on a setter, it triggers all tracked effects.

```js
import { ref, effect } from 'vue';

const a = ref(1);
effect(() => console.log('a is', a.value));
a.value = 2; // logs "a is 2"
```

## Q58. How do you prevent re-rendering in Vue?

**Answer:**

- Use `v-once` for static content.
- Use `v-memo` for memoized list items.
- Avoid creating new object/array literals as props in templates.
- Use `shallowRef` for large objects.

## Q59. How do you handle slots with default content?

**Answer:**

Anything inside `<slot>...</slot>` is the fallback content if no slot content is provided.

```vue
<!-- Button.vue -->
<template>
  <button><slot>Click me</slot></button>
</template>

<!-- Usage -->
<Button />              <!-- Click me -->
<Button>Save</Button>   <!-- Save -->
```

## Q60. What is the difference between `setup()` function and `<script setup>`?

**Answer:**

`setup()` is the underlying API. `<script setup>` is a compiler-time syntactic sugar that:
- Auto-exposes top-level bindings to the template.
- Auto-imports macros like `defineProps`, `defineEmits`.
- Eliminates the need to `return` an object.

```vue
<!-- Without setup -->
<script>
import { ref } from 'vue';
export default {
  setup() {
    const count = ref(0);
    return { count };
  },
};
</script>

<!-- With setup -->
<script setup>
import { ref } from 'vue';
const count = ref(0);
</script>
```

---

## 12. Quick Reference

| API | Purpose |
| --- | ------- |
| `ref` | Reactive primitive |
| `reactive` | Reactive object |
| `computed` | Cached derived value |
| `watch` | React to source changes |
| `watchEffect` | Auto-tracked side effect |
| `provide`/`inject` | Pass values down the tree |
| `defineProps` | Declare props |
| `defineEmits` | Declare events |
| `defineExpose` | Expose to parent ref |
| `onMounted` | Lifecycle hook |
| `nextTick` | Wait for DOM update |

| Tool | Use |
| ---- | --- |
| Pinia | Global store |
| Vue Router | Routing |
| VueUse | Composables collection |
| Vitest + Vue Test Utils | Testing |
| VeeValidate / FormKit | Form validation |
