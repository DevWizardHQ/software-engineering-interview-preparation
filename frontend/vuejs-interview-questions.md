# Vue.js Interview Questions

**Level:** Mid to Senior  
**Topics:** Options API, Composition API, Reactivity, Vue Router, Pinia/Vuex, Performance, Testing

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Options API vs Composition API](#options-api-vs-composition-api)
3. [Reactivity System](#reactivity-system)
4. [Directives](#directives)
5. [Components](#components)
6. [Vue Router](#vue-router)
7. [State Management — Pinia and Vuex](#state-management--pinia-and-vuex)
8. [Performance Optimization](#performance-optimization)
9. [Testing](#testing)
10. [Vue 3 Advanced Features](#vue-3-advanced-features)

---

## Core Concepts

### Q1. What is Vue.js?

**Answer:**
Vue.js is a progressive JavaScript framework for building user interfaces. It is:
- approachable — easy to add to existing projects
- performant — reactive rendering with virtual DOM
- versatile — works for simple widgets to full SPAs

Vue 3 key improvements over Vue 2:
- Composition API
- better TypeScript support
- Proxy-based reactivity (instead of `Object.defineProperty`)
- Fragments (multiple root elements)
- Teleport
- Suspense

---

### Q2. What is the Vue instance lifecycle?

**Answer:**

```
Creation:
  setup() → beforeCreate → created

Mounting:
  beforeMount → mounted

Updating (reactive data changes):
  beforeUpdate → updated

Unmounting:
  beforeUnmount → unmounted
```

**Composition API hooks:**
```js
import { onMounted, onUpdated, onUnmounted, onBeforeMount } from 'vue';

onMounted(() => { /* DOM ready, fetch data */ });
onUnmounted(() => { /* cleanup timers, subscriptions */ });
```

---

### Q3. What is the virtual DOM in Vue?

**Answer:**
Vue maintains a lightweight JavaScript representation of the DOM. When data changes:
1. Vue re-renders to a new virtual DOM tree
2. Diffs with the previous tree (patching)
3. Applies only the minimal real DOM changes

This is more efficient than always re-rendering the entire DOM.

---

## Options API vs Composition API

### Q4. What is the Options API?

**Answer:**
The traditional Vue way. Component logic is organized by option type.

```js
export default {
  name: 'UserProfile',
  components: { Avatar },
  
  props: {
    userId: { type: String, required: true }
  },
  
  data() {
    return {
      user: null,
      loading: true,
    };
  },
  
  computed: {
    fullName() {
      return `${this.user?.firstName} ${this.user?.lastName}`;
    },
  },
  
  watch: {
    userId(newId) {
      this.fetchUser(newId);
    },
  },
  
  async mounted() {
    await this.fetchUser(this.userId);
  },
  
  methods: {
    async fetchUser(id) {
      this.loading = true;
      this.user = await api.getUser(id);
      this.loading = false;
    },
  },
};
```

---

### Q5. What is the Composition API?

**Answer:**
Vue 3's way of organizing logic by feature instead of option type. Enables better logic reuse via composables.

```js
<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useUserStore } from '@/stores/user';

const props = defineProps({ userId: String });

const user = ref(null);
const loading = ref(true);

const fullName = computed(() =>
  `${user.value?.firstName} ${user.value?.lastName}`
);

async function fetchUser(id) {
  loading.value = true;
  user.value = await api.getUser(id);
  loading.value = false;
}

watch(() => props.userId, (newId) => fetchUser(newId));

onMounted(() => fetchUser(props.userId));
</script>
```

---

### Q6. When would you use Options API vs Composition API?

**Answer:**

| Options API | Composition API |
|-------------|-----------------|
| Simpler components | Complex logic |
| Beginners | TypeScript apps |
| Legacy codebases | Logic reuse via composables |
| Fixed option structure | Flexible code organization |

**Vue 3 best practice:** use Composition API with `<script setup>` for new code.

---

### Q7. What is `<script setup>`?

**Answer:**
Syntactic sugar for the Composition API. Code inside runs during component setup.

```vue
<script setup>
// Everything declared here is auto-available in the template
const count = ref(0);
const double = computed(() => count.value * 2);

// Props
const props = defineProps({ name: String });

// Emits
const emit = defineEmits(['update:modelValue', 'close']);

// Expose to parent refs
defineExpose({ reset: () => count.value = 0 });
</script>
```

---

## Reactivity System

### Q8. What is `ref`?

**Answer:**
Creates a reactive reference to a value. Access/modify via `.value`.

```js
const count = ref(0);
count.value++; // triggers reactivity

// In template: automatically unwrapped (no .value needed)
// <p>{{ count }}</p>
```

Works with primitives and objects. Objects are made deeply reactive.

---

### Q9. What is `reactive`?

**Answer:**
Creates a deeply reactive object using Proxy. No `.value` needed.

```js
const state = reactive({
  count: 0,
  user: { name: 'Alice' },
});

state.count++;
state.user.name = 'Bob';
```

Limitations:
- only works with objects (not primitives)
- reactivity is lost when destructuring: `const { count } = state` → NOT reactive

---

### Q10. What is `computed`?

**Answer:**
Creates a reactive value derived from other reactive sources. Cached — only recomputes when dependencies change.

```js
const firstName = ref('John');
const lastName = ref('Doe');

const fullName = computed(() => `${firstName.value} ${lastName.value}`);

// Writable computed
const model = computed({
  get: () => props.value,
  set: (val) => emit('update:modelValue', val),
});
```

---

### Q11. What is `watch` vs `watchEffect`?

**Answer:**

**`watch`** — explicit sources, lazy by default, has old/new values:
```js
watch(count, (newVal, oldVal) => {
  console.log(`${oldVal} → ${newVal}`);
});

// Multiple sources
watch([firstName, lastName], ([newFirst, newLast]) => { ... });
```

**`watchEffect`** — auto-tracks dependencies, runs immediately:
```js
watchEffect(() => {
  // runs immediately and whenever count changes
  console.log('Count is:', count.value);
});
```

---

### Q12. What is a composable?

**Answer:**
A reusable function that encapsulates reactive state and logic. Like a custom hook in React.

```js
// composables/useFetch.js
export function useFetch(url) {
  const data = ref(null);
  const loading = ref(true);
  const error = ref(null);

  async function fetchData() {
    loading.value = true;
    try {
      const res = await fetch(url);
      data.value = await res.json();
    } catch (e) {
      error.value = e;
    } finally {
      loading.value = false;
    }
  }

  onMounted(fetchData);

  return { data, loading, error, refresh: fetchData };
}

// Usage
const { data: posts, loading } = useFetch('/api/posts');
```

---

## Directives

### Q13. What are Vue directives?

**Answer:**
Special HTML attributes starting with `v-` that apply reactive behavior to the DOM.

| Directive | Purpose |
|-----------|---------|
| `v-if` / `v-else` | Conditionally render element |
| `v-show` | Toggle visibility (display:none) |
| `v-for` | Render list |
| `v-bind` / `:` | Bind attribute dynamically |
| `v-on` / `@` | Attach event listener |
| `v-model` | Two-way data binding |
| `v-slot` | Slot content |

---

### Q14. Difference between `v-if` and `v-show`?

**Answer:**

| `v-if` | `v-show` |
|--------|---------|
| Conditionally adds/removes from DOM | Always in DOM, toggles `display` |
| Higher toggle cost | Lower toggle cost |
| Lower initial cost if false | Always renders initially |
| Good for rarely toggled UI | Good for frequently toggled UI |

---

### Q15. How does `v-model` work?

**Answer:**
Two-way data binding. Shorthand for `:value` + `@input`.

```html
<!-- These are equivalent -->
<input v-model="email" />
<input :value="email" @input="email = $event.target.value" />
```

**Custom component `v-model`:**
```vue
<!-- Parent -->
<MyInput v-model="name" />

<!-- Child (MyInput.vue) -->
<script setup>
defineProps(['modelValue']);
defineEmits(['update:modelValue']);
</script>
<template>
  <input :value="modelValue" @input="$emit('update:modelValue', $event.target.value)" />
</template>
```

---

### Q16. What is `v-for` and why does it need a key?

**Answer:**

```html
<ul>
  <li v-for="post in posts" :key="post.id">
    {{ post.title }}
  </li>
</ul>
```

`key` is required to help Vue's diffing algorithm identify which items changed, moved, or were added/removed. Without `key`, Vue reuses elements in place and may produce bugs with stateful items.

Use unique, stable IDs — not array index if the list can reorder.

---

### Q17. How do you create a custom directive?

**Answer:**

```js
// Global
app.directive('focus', {
  mounted(el) {
    el.focus();
  }
});

// Local
const vFocus = {
  mounted: (el) => el.focus()
};

// Template
<input v-focus />
```

---

## Components

### Q18. How do props work in Vue?

**Answer:**

```vue
<script setup>
const props = defineProps({
  title: { type: String, required: true },
  count: { type: Number, default: 0 },
  user: { type: Object },
  tags: { type: Array, default: () => [] },
});
</script>
```

Props are read-only in the child. Mutating them directly causes a Vue warning.

---

### Q19. How do emits work?

**Answer:**
Children communicate upward via emitting events.

```vue
<!-- Child -->
<script setup>
const emit = defineEmits(['submit', 'cancel', 'update:value']);
emit('submit', formData);
</script>

<!-- Parent -->
<MyForm @submit="handleSubmit" @cancel="closeModal" />
```

---

### Q20. What are slots?

**Answer:**
Slots allow a parent to inject content into a child component's template.

```vue
<!-- Child: Card.vue -->
<template>
  <div class="card">
    <div class="header">
      <slot name="header" />  <!-- named slot -->
    </div>
    <slot />                   <!-- default slot -->
    <slot name="footer" :data="localData" /> <!-- scoped slot -->
  </div>
</template>

<!-- Parent -->
<Card>
  <template #header><h2>Title</h2></template>
  <p>Content here</p>
  <template #footer="{ data }">{{ data }}</template>
</Card>
```

---

### Q21. What is `provide` and `inject`?

**Answer:**
Ancestor provides a value; any descendant can inject it. Avoids prop drilling.

```js
// Ancestor
provide('theme', ref('dark'));

// Any descendant (anywhere in tree)
const theme = inject('theme');
```

Use `readonly()` to prevent injection from mutating provided values.

---

## Vue Router

### Q22. How do you set up Vue Router?

**Answer:**

```js
// router/index.js
import { createRouter, createWebHistory } from 'vue-router';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: Home },
    { path: '/users/:id', component: UserProfile, props: true },
    { path: '/dashboard', component: Dashboard, meta: { requiresAuth: true } },
    { path: '/:pathMatch(.*)*', component: NotFound },
  ],
});

// Navigation guard
router.beforeEach((to, from) => {
  if (to.meta.requiresAuth && !isAuthenticated()) {
    return '/login';
  }
});
```

---

### Q23. How do you navigate programmatically?

**Answer:**

```js
import { useRouter, useRoute } from 'vue-router';

const router = useRouter();
const route = useRoute();

// Navigate
router.push('/users/123');
router.push({ name: 'user', params: { id: '123' } });
router.replace('/login');
router.back();

// Current route info
console.log(route.params.id);
console.log(route.query.search);
console.log(route.meta.requiresAuth);
```

---

### Q24. What are navigation guards?

**Answer:**
Hooks that control navigation flow.

```js
// Global guard
router.beforeEach(async (to, from) => {
  const authStore = useAuthStore();
  if (to.meta.requiresAuth && !authStore.isLoggedIn) {
    return { name: 'Login', query: { redirect: to.fullPath } };
  }
});

// Per-route guard
{
  path: '/admin',
  component: AdminPanel,
  beforeEnter: (to, from) => {
    if (!isAdmin()) return '/forbidden';
  }
}

// In-component guard
onBeforeRouteLeave((to, from) => {
  if (unsavedChanges.value) {
    return confirm('Leave without saving?');
  }
});
```

---

## State Management — Pinia and Vuex

### Q25. What is Pinia and why prefer it over Vuex?

**Answer:**
Pinia is the official Vue state management library (replaced Vuex 4 as recommendation).

Advantages over Vuex:
- no mutations (direct state modification)
- TypeScript support out of the box
- no namespacing needed — each store is independent
- simpler API, less boilerplate
- DevTools support
- compatible with Vue 2 and 3

---

### Q26. How do you create and use a Pinia store?

**Answer:**

```js
// stores/auth.js
import { defineStore } from 'pinia';

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    token: null,
  }),
  
  getters: {
    isLoggedIn: (state) => !!state.token,
    displayName: (state) => state.user?.name ?? 'Guest',
  },
  
  actions: {
    async login(credentials) {
      const { user, token } = await api.login(credentials);
      this.user = user;
      this.token = token;
    },
    logout() {
      this.user = null;
      this.token = null;
    },
  },
});

// Usage in component
const authStore = useAuthStore();
authStore.login({ email, password });
console.log(authStore.isLoggedIn);
```

**Composition API style store:**
```js
export const useCounterStore = defineStore('counter', () => {
  const count = ref(0);
  const double = computed(() => count.value * 2);
  function increment() { count.value++; }
  return { count, double, increment };
});
```

---

### Q27. How does Vuex work?

**Answer:**
Vuex state management pattern: state → getters → mutations → actions → state.

```js
const store = createStore({
  state: { count: 0 },
  getters: {
    doubleCount: (state) => state.count * 2,
  },
  mutations: {
    increment(state) { state.count++; },
  },
  actions: {
    async fetchAndIncrement({ commit }) {
      await api.fetch();
      commit('increment');
    },
  },
});

// Usage
store.commit('increment');
store.dispatch('fetchAndIncrement');
this.$store.getters.doubleCount;
```

In Vue 3, prefer Pinia over Vuex.

---

## Performance Optimization

### Q28. How do you optimize Vue component rendering?

**Answer:**

- `v-once` — render once, skip future updates
- `v-memo` — skip re-render if dependencies unchanged
- `shallowRef` / `shallowReactive` — shallow reactivity for large objects
- `computed` — cache derived values
- `defineAsyncComponent` — lazy load heavy components
- `v-show` over `v-if` for frequently toggled elements
- List virtualization for large lists (vue-virtual-scroller)

```js
// Lazy component
const HeavyChart = defineAsyncComponent(() => import('./HeavyChart.vue'));

// v-memo
<div v-memo="[user.id, user.name]">
  <ExpensiveList :user="user" />
</div>
```

---

### Q29. What is `shallowRef` vs `ref`?

**Answer:**

- `ref` — deeply reactive (nested objects also reactive)
- `shallowRef` — only `.value` is reactive, inner object is not

Use `shallowRef` for large objects when you always replace the whole value.

```js
const bigData = shallowRef({ items: [] });
// This triggers reactivity
bigData.value = { items: newItems };
// This does NOT trigger reactivity (inner mutation)
bigData.value.items.push(item);
```

---

## Testing

### Q30. How do you test Vue components?

**Answer:**

**With Vue Test Utils + Vitest:**

```js
import { mount } from '@vue/test-utils';
import { describe, it, expect } from 'vitest';
import Counter from './Counter.vue';

describe('Counter', () => {
  it('increments on button click', async () => {
    const wrapper = mount(Counter);
    
    expect(wrapper.text()).toContain('0');
    await wrapper.find('button').trigger('click');
    expect(wrapper.text()).toContain('1');
  });

  it('emits update event', async () => {
    const wrapper = mount(Counter, { props: { initial: 5 } });
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('update')[0]).toEqual([6]);
  });
});
```

---

### Q31. How do you test Pinia stores?

**Answer:**

```js
import { setActivePinia, createPinia } from 'pinia';
import { useAuthStore } from './auth';

beforeEach(() => {
  setActivePinia(createPinia());
});

it('login sets user and token', async () => {
  vi.spyOn(api, 'login').mockResolvedValue({ user: { name: 'Alice' }, token: 'abc123' });
  
  const store = useAuthStore();
  await store.login({ email: 'a@a.com', password: 'pass' });
  
  expect(store.isLoggedIn).toBe(true);
  expect(store.user.name).toBe('Alice');
});
```

---

## Vue 3 Advanced Features

### Q32. What is Teleport?

**Answer:**
Renders a component's template in a different part of the DOM, outside the component's hierarchy.

```vue
<!-- Modal rendered at document.body, not inside the component tree -->
<Teleport to="body">
  <div class="modal">
    <slot />
  </div>
</Teleport>
```

Use for modals, tooltips, notifications that need to escape CSS stacking contexts.

---

### Q33. What is Suspense in Vue?

**Answer:**
Handles async components with a fallback while they're loading.

```vue
<Suspense>
  <template #default>
    <AsyncUserProfile />  <!-- async setup() component -->
  </template>
  <template #fallback>
    <LoadingSpinner />
  </template>
</Suspense>
```

Works with components that have `async setup()` or use `defineAsyncComponent`.

---

### Q34. What is `defineExpose`?

**Answer:**
Exposes selected properties to parent components accessing the child via template ref.

```vue
<!-- Child -->
<script setup>
const input = ref(null);
defineExpose({ focus: () => input.value.focus() });
</script>

<!-- Parent -->
<MyInput ref="inputRef" />
<button @click="inputRef.focus()">Focus</button>
```

Without `defineExpose`, `<script setup>` components are closed (no public interface).

---

### Q35. What is the difference between `toRef` and `toRefs`?

**Answer:**

```js
const state = reactive({ count: 0, name: 'Alice' });

// toRef — single property ref that stays linked
const count = toRef(state, 'count');
count.value++; // mutates state.count

// toRefs — all properties become refs
const { count, name } = toRefs(state);
// Now safe to destructure while keeping reactivity
count.value++; // mutates state.count
```

Use `toRefs` when you want to destructure a reactive object in composables.

---

## Quick Reference

### Vue 3 Composition API — Key Functions

| Function | Purpose |
|----------|---------|
| `ref()` | Reactive primitive or object |
| `reactive()` | Reactive object (no .value) |
| `computed()` | Cached derived value |
| `watch()` | Watch specific sources |
| `watchEffect()` | Auto-track dependencies |
| `toRef()` | Ref to one reactive property |
| `toRefs()` | All reactive properties as refs |
| `readonly()` | Non-mutable reactive |
| `shallowRef()` | Shallow reactivity |
| `provide/inject` | Ancestor-descendant sharing |
| `onMounted()` | After DOM mount |
| `onUnmounted()` | Before unmount |
| `defineProps()` | Declare props |
| `defineEmits()` | Declare events |
| `defineExpose()` | Expose to parent refs |
