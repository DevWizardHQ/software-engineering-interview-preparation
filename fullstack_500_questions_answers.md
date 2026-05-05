# Full-Stack Developer Interview Preparation

## 500 Questions & Answers

**Role:** Full-Stack Developer — Laravel & Vue.js

**Focus areas:** Raw PHP, Laravel, Vue 2/Vue 3, JavaScript, TypeScript, MySQL/SQL, REST API, Git, Linux, deployment, security, performance, scenario questions, and HR questions.

**Study method:** Practice 30–50 questions daily. For each answer, add one example from your own project.

---

## Raw PHP & Core PHP

### 1. What is PHP?

**Answer:** PHP is a server-side scripting language used to build dynamic web apps and APIs. In this role, PHP is the base language behind Laravel.

### 2. Why is PHP popular for web development?

**Answer:** It is easy to deploy, has huge hosting support, strong frameworks like Laravel, and integrates well with MySQL.

### 3. What is the difference between echo and print?

**Answer:** echo outputs one or more strings and has no return value. print outputs one string and returns 1.

### 4. What is the difference between include and require?

**Answer:** include gives a warning if the file is missing and continues. require gives a fatal error and stops.

### 5. What is include_once?

**Answer:** It includes a file only once to avoid duplicate class/function definitions.

### 6. What is require_once?

**Answer:** It requires a file once and stops execution if the file is missing.

### 7. What are PHP variables?

**Answer:** Variables start with $ and store dynamic values, for example $name = 'User';.

### 8. What are PHP scalar types?

**Answer:** String, integer, float, and boolean.

### 9. What are compound types in PHP?

**Answer:** Array, object, callable, and iterable.

### 10. What is null in PHP?

**Answer:** null means a variable has no value.

### 11. What is type juggling?

**Answer:** PHP automatically converts types in some operations, especially loose comparison.

### 12. What is strict comparison?

**Answer:** Using === checks both value and type.

### 13. Why prefer === over ==?

**Answer:** It avoids unexpected bugs from automatic type conversion.

### 14. What is an indexed array?

**Answer:** An array with numeric keys, such as ['a', 'b'].

### 15. What is an associative array?

**Answer:** An array with named keys, such as ['name' => 'Rahim'].

### 16. What is a multidimensional array?

**Answer:** An array containing other arrays.

### 17. What is isset()?

**Answer:** It checks whether a variable exists and is not null.

### 18. What is empty()?

**Answer:** It checks whether a variable is empty, such as '', 0, null, false, or [].

### 19. What is unset()?

**Answer:** It removes a variable or array element.

### 20. What is a function?

**Answer:** A reusable block of code that can take parameters and return a value.

### 21. What is pass by value?

**Answer:** A copy of the variable is passed, so the original is not changed.

### 22. What is pass by reference?

**Answer:** The original variable is passed using &, so it can be changed.

### 23. What is a closure?

**Answer:** An anonymous function that can be assigned or passed around.

### 24. What is namespace?

**Answer:** A way to organize classes and avoid name conflicts.

### 25. What is Composer?

**Answer:** Composer is PHP's dependency manager.

### 26. What is composer.json?

**Answer:** It defines dependencies, autoloading, scripts, and project metadata.

### 27. What is PSR-4?

**Answer:** A PHP autoloading standard mapping namespaces to directories.

### 28. What is OOP?

**Answer:** Object-oriented programming organizes code into classes and objects.

### 29. What is a class?

**Answer:** A blueprint containing properties and methods.

### 30. What is an object?

**Answer:** An instance of a class.

### 31. What is encapsulation?

**Answer:** Hiding internal state and exposing controlled methods.

### 32. What is inheritance?

**Answer:** A child class reuses or extends a parent class.

### 33. What is polymorphism?

**Answer:** Different classes can be used through the same interface but behave differently.

### 34. What is abstraction?

**Answer:** Hiding implementation details and exposing essential behavior.

### 35. What is an interface?

**Answer:** A contract that defines methods a class must implement.

### 36. What is an abstract class?

**Answer:** A class that cannot be instantiated and may contain abstract methods.

### 37. Interface vs abstract class?

**Answer:** Interface defines a contract; abstract class can also share common code.

### 38. What is a trait?

**Answer:** A reusable group of methods inserted into classes.

### 39. What is constructor?

**Answer:** \_\_construct() runs when an object is created.

### 40. What is static method?

**Answer:** A method called on the class itself using ClassName::method().

### 41. What are magic methods?

**Answer:** Special methods like **construct, **get, **set, **call, and \_\_toString.

### 42. What is exception handling?

**Answer:** Using try/catch/finally to handle runtime errors safely.

### 43. What is Throwable?

**Answer:** The base interface for Exception and Error in modern PHP.

### 44. What is PDO?

**Answer:** PHP Data Objects, a database abstraction layer with prepared statement support.

### 45. Why use prepared statements?

**Answer:** They prevent SQL injection by separating SQL from user input.

### 46. What is SQL injection?

**Answer:** An attack where malicious input changes SQL query behavior.

### 47. How prevent SQL injection in raw PHP?

**Answer:** Use prepared statements, bound parameters, and validation.

### 48. What is XSS?

**Answer:** Cross-site scripting, where malicious script executes in the browser.

### 49. How prevent XSS?

**Answer:** Escape output and avoid rendering unsafe user HTML.

### 50. What is CSRF?

**Answer:** An attack that tricks a logged-in user into submitting unwanted requests.

### 51. How prevent CSRF?

**Answer:** Use CSRF tokens and SameSite cookies.

### 52. What is a session?

**Answer:** Server-side storage for user-specific data across requests.

### 53. What is a cookie?

**Answer:** Small client-side data sent with requests.

### 54. Session vs cookie?

**Answer:** Session data is server-side; cookie data is client-side.

### 55. How store passwords safely?

**Answer:** Use password_hash() and password_verify(); never store plain passwords.

### 56. What is json_encode()?

**Answer:** It converts PHP data to JSON.

### 57. What is json_decode()?

**Answer:** It converts JSON to PHP data.

### 58. What is header()?

**Answer:** It sends HTTP headers before output.

### 59. What causes headers already sent?

**Answer:** Output was sent before header/session operations.

### 60. What is output buffering?

**Answer:** Temporarily storing output before sending it to the browser.

### 61. What is dependency injection?

**Answer:** Passing dependencies from outside instead of creating them inside a class.

### 62. What is MVC?

**Answer:** Model handles data, View handles UI, Controller handles request flow.

### 63. What is SOLID?

**Answer:** Five design principles for maintainable OOP code.

### 64. What is SRP?

**Answer:** Single Responsibility Principle: one class should have one main reason to change.

### 65. What is file upload validation?

**Answer:** Checking size, MIME type, extension, and safe storage path.

### 66. What is $\_GET?

**Answer:** Query string/request URL parameters.

### 67. What is $\_POST?

**Answer:** POST form/request body parameters.

### 68. What is $\_FILES?

**Answer:** Uploaded file metadata.

### 69. What is $\_SERVER?

**Answer:** Server and request environment information.

### 70. What is OPcache?

**Answer:** A PHP bytecode cache that improves performance.

### 71. What is PHP-FPM?

**Answer:** A FastCGI process manager for running PHP with servers like Nginx.

### 72. What is nullable type?

**Answer:** A type that allows null, like ?string.

### 73. What is union type?

**Answer:** A type that allows multiple types, like string|int.

### 74. What is enum in PHP?

**Answer:** A fixed set of named values, useful for statuses.

### 75. How debug PHP?

**Answer:** Use logs, var_dump, Xdebug, error reporting, and step-by-step isolation.

## Laravel

### 76. What is Laravel?

**Answer:** A PHP framework for building web apps and APIs with routing, ORM, validation, auth, queues, and more.

### 77. Why use Laravel?

**Answer:** It gives structure, security helpers, Eloquent ORM, migrations, validation, and faster development.

### 78. What is MVC in Laravel?

**Answer:** Models handle data, views handle UI, and controllers handle request flow.

### 79. Where are web routes defined?

**Answer:** routes/web.php.

### 80. Where are API routes defined?

**Answer:** routes/api.php.

### 81. What is a route?

**Answer:** A mapping between an HTTP request and controller/closure logic.

### 82. What is a controller?

**Answer:** A class that handles request logic and returns responses.

### 83. What is resource controller?

**Answer:** A controller with standard CRUD methods.

### 84. What is middleware?

**Answer:** A request filter used for auth, CSRF, throttling, or custom checks.

### 85. What is auth middleware?

**Answer:** It restricts routes to authenticated users.

### 86. What is CSRF middleware?

**Answer:** It verifies CSRF token for state-changing web requests.

### 87. What is Eloquent?

**Answer:** Laravel's ORM for interacting with database tables through models.

### 88. What is a model?

**Answer:** A class representing a database table and its relationships.

### 89. What is migration?

**Answer:** A version-controlled database schema change.

### 90. What is seeder?

**Answer:** A class that inserts initial/sample data.

### 91. What is factory?

**Answer:** A class/helper to generate fake model data for tests/seeding.

### 92. What is mass assignment?

**Answer:** Filling model attributes from an array.

### 93. What is $fillable?

**Answer:** A whitelist of fields allowed for mass assignment.

### 94. What is $guarded?

**Answer:** A blacklist of fields blocked from mass assignment.

### 95. What is Form Request?

**Answer:** A custom request class for validation and authorization.

### 96. Why use Form Request?

**Answer:** It keeps controllers clean and validation reusable.

### 97. What is route model binding?

**Answer:** Laravel automatically resolves route parameters into model instances.

### 98. What is Blade?

**Answer:** Laravel's templating engine.

### 99. What is {{ }} in Blade?

**Answer:** Escaped output to prevent XSS.

### 100. What is {!! !!} in Blade?

**Answer:** Raw unescaped output; use carefully.

### 101. What is hasOne?

**Answer:** One-to-one relationship from current model to one related model.

### 102. What is belongsTo?

**Answer:** The inverse relationship where current model has a foreign key.

### 103. What is hasMany?

**Answer:** One-to-many relationship.

### 104. What is belongsToMany?

**Answer:** Many-to-many relationship using a pivot table.

### 105. What is a pivot table?

**Answer:** A table connecting two many-to-many models.

### 106. What is eager loading?

**Answer:** Loading relationships upfront using with() to avoid N+1 queries.

### 107. What is lazy loading?

**Answer:** Loading relationships when accessed.

### 108. What is N+1 query problem?

**Answer:** One query loads parents, then many extra queries load children.

### 109. How fix N+1?

**Answer:** Use with(), load(), or withCount().

### 110. What is withCount()?

**Answer:** It loads related record count without loading full relation.

### 111. What is accessor?

**Answer:** A method that transforms an attribute when reading.

### 112. What is mutator?

**Answer:** A method that transforms an attribute before saving.

### 113. What are casts?

**Answer:** Automatic conversion of model attributes to types.

### 114. What is soft delete?

**Answer:** Marking records deleted using deleted_at instead of removing.

### 115. How enable soft deletes?

**Answer:** Use SoftDeletes trait and add deleted_at column.

### 116. What is query scope?

**Answer:** Reusable query logic in a model.

### 117. Local scope vs global scope?

**Answer:** Local is called manually; global applies automatically.

### 118. What is service container?

**Answer:** Laravel's dependency injection container.

### 119. What is service provider?

**Answer:** A bootstrap class that registers services/configuration.

### 120. What is dependency injection in Laravel?

**Answer:** Laravel automatically resolves type-hinted dependencies.

### 121. What is facade?

**Answer:** A static-looking interface to a service in the container.

### 122. Facade vs DI?

**Answer:** Facades are convenient; DI is more explicit and testable.

### 123. What is artisan?

**Answer:** Laravel command-line tool.

### 124. Common artisan commands?

**Answer:** serve, migrate, make:model, make:controller, route:list, cache:clear.

### 125. What is .env?

**Answer:** Environment-specific configuration file.

### 126. Why not commit .env?

**Answer:** It can contain secrets and environment-specific values.

### 127. What is config cache?

**Answer:** Cached config for faster production loading.

### 128. What is route cache?

**Answer:** Cached route definitions for performance.

### 129. What is queue?

**Answer:** Background processing system for slow tasks.

### 130. What is a job?

**Answer:** A task class that can be queued.

### 131. What is event/listener?

**Answer:** Event announces something happened; listener reacts.

### 132. What is notification?

**Answer:** A message sent through mail, database, SMS, etc.

### 133. What is scheduler?

**Answer:** Laravel feature for defining recurring tasks in code.

### 134. What is cache?

**Answer:** Temporary storage for frequently used data.

### 135. What is Redis used for?

**Answer:** Cache, queues, sessions, and rate limiting.

### 136. What is authentication?

**Answer:** Verifying who the user is.

### 137. What is authorization?

**Answer:** Checking what the user can do.

### 138. What is policy?

**Answer:** Authorization logic for a model.

### 139. What is gate?

**Answer:** Closure-based authorization rule.

### 140. What is Sanctum?

**Answer:** Simple API token/SPAs authentication package.

### 141. What is Passport?

**Answer:** OAuth2 server package for Laravel.

### 142. Sanctum vs Passport?

**Answer:** Sanctum is simpler; Passport is for full OAuth2 flows.

### 143. What is API Resource?

**Answer:** A class that transforms models into JSON responses.

### 144. Why use API Resource?

**Answer:** To control response shape and hide internal fields.

### 145. What is pagination?

**Answer:** Splitting large results into pages using paginate().

### 146. paginate vs simplePaginate?

**Answer:** paginate includes total count; simplePaginate avoids count and can be faster.

### 147. What is transaction?

**Answer:** A group of DB operations that commit or rollback together.

### 148. How use transaction?

**Answer:** DB::transaction(function () { ... });

### 149. When use transaction?

**Answer:** When multiple writes must stay consistent.

### 150. What is firstOrCreate?

**Answer:** Find first matching record or create it.

### 151. What is updateOrCreate?

**Answer:** Update matching record or create it.

### 152. What is findOrFail?

**Answer:** Find by ID or throw 404 exception.

### 153. What is abort()?

**Answer:** Stops request and returns an HTTP error.

### 154. What is Laravel logging?

**Answer:** Laravel uses Monolog channels to write application logs.

### 155. What is dd()?

**Answer:** Dump and die, for development debugging.

### 156. What is dump()?

**Answer:** Dump data without stopping execution.

### 157. What is Telescope?

**Answer:** Laravel debugging/monitoring tool for development.

### 158. What is rate limiting?

**Answer:** Restricting number of requests in a time window.

### 159. What is CORS?

**Answer:** Browser policy controlling cross-origin API access.

### 160. How handle CORS?

**Answer:** Configure allowed origins, methods, and headers.

### 161. What is storage disk?

**Answer:** Filesystem abstraction for local/public/cloud storage.

### 162. What is storage:link?

**Answer:** Creates public link to storage/app/public.

### 163. How upload file?

**Answer:** Validate file, store it, save path in DB.

### 164. How secure upload?

**Answer:** Validate size/type, rename safely, avoid executable public files.

### 165. What is Collection?

**Answer:** Fluent wrapper around arrays/data.

### 166. map vs each?

**Answer:** map returns transformed collection; each is for side effects.

### 167. filter vs reject?

**Answer:** filter keeps matching items; reject removes matching items.

### 168. What is pluck?

**Answer:** Extracts one column/key from results.

### 169. What is chunk?

**Answer:** Processes records in batches to save memory.

### 170. What is cursor?

**Answer:** Streams records one at a time.

### 171. What is repository pattern?

**Answer:** Separates data access from business logic.

### 172. What is service layer?

**Answer:** A layer for business logic outside controllers.

### 173. What is thin controller?

**Answer:** A controller that validates/co-ordinates but avoids heavy business logic.

### 174. Laravel 8 vs 9?

**Answer:** Laravel 9 moved to newer PHP/Symfony versions and modernized features.

### 175. Laravel 9 vs 10?

**Answer:** Laravel 10 removed deprecated behavior and modernized skeleton typing.

### 176. Laravel 10 vs 11?

**Answer:** Laravel 11 introduced a slimmer app skeleton and bootstrap/app.php configuration style.

### 177. What is bootstrap/app.php in Laravel 11?

**Answer:** Central place for routing, middleware, and exception configuration in new skeleton.

### 178. What is Vite in Laravel?

**Answer:** Modern frontend build tool used for assets.

### 179. Vite vs Mix?

**Answer:** Vite is faster and modern; Mix is Webpack-based and older.

### 180. How connect Vue with Laravel?

**Answer:** Use Laravel API + Vue SPA, or Blade with Vue components.

### 181. How return JSON?

**Answer:** return response()->json([...]);

### 182. How handle API errors?

**Answer:** Use proper status codes and consistent JSON error format.

### 183. How optimize Laravel?

**Answer:** Eager load, add indexes, cache, queue slow tasks, paginate, and use config/route cache.

### 184. How secure Laravel?

**Answer:** Validate input, use auth/policies, CSRF, escaped output, HTTPS, rate limits, safe uploads.

### 185. What is migrate:fresh?

**Answer:** Drops all tables and reruns migrations; dangerous in production.

### 186. What is migrate:rollback?

**Answer:** Rolls back the last migration batch.

### 187. What is observer?

**Answer:** Class that listens to model events.

### 188. What are model events?

**Answer:** creating, created, updating, updated, deleting, deleted, etc.

### 189. What is hidden property?

**Answer:** Fields hidden from JSON output.

### 190. What is appends property?

**Answer:** Accessor values appended to model JSON.

### 191. What is 422 response?

**Answer:** Validation error response.

### 192. What is 401?

**Answer:** Unauthenticated.

### 193. What is 403?

**Answer:** Authenticated but forbidden.

### 194. What is 404?

**Answer:** Resource not found.

### 195. What is 201?

**Answer:** Resource created.

## Vue.js

### 196. What is Vue.js?

**Answer:** A progressive JavaScript framework for reactive user interfaces.

### 197. What is Vue 2 vs Vue 3?

**Answer:** Vue 3 has Proxy reactivity, Composition API, better TypeScript, fragments, Teleport, Suspense, and better performance.

### 198. What is Options API?

**Answer:** Component logic organized by data, methods, computed, watch, lifecycle hooks.

### 199. What is Composition API?

**Answer:** Logic organized by feature using setup(), ref(), reactive(), computed(), and composables.

### 200. Options API vs Composition API?

**Answer:** Options is simple; Composition is better for large reusable logic and TypeScript.

### 201. What is script setup?

**Answer:** A concise Vue 3 syntax for Composition API components.

### 202. What is component?

**Answer:** Reusable UI block with template, logic, props, and events.

### 203. What is SFC?

**Answer:** Single File Component: .vue file with template, script, and style.

### 204. What is reactivity?

**Answer:** State changes automatically update the UI.

### 205. What is ref()?

**Answer:** Creates reactive value accessed with .value in script.

### 206. What is reactive()?

**Answer:** Creates a reactive object.

### 207. ref vs reactive?

**Answer:** ref works for any value; reactive is best for objects.

### 208. What is computed?

**Answer:** Cached derived reactive value.

### 209. Computed vs method?

**Answer:** Computed is cached; method runs when called.

### 210. What is watch?

**Answer:** Runs side effects when reactive data changes.

### 211. watch vs computed?

**Answer:** Computed derives values; watch handles side effects.

### 212. What is v-model?

**Answer:** Two-way binding between input and state.

### 213. What is v-if?

**Answer:** Conditionally renders/removes DOM.

### 214. What is v-show?

**Answer:** Toggles display CSS while keeping DOM.

### 215. v-if vs v-show?

**Answer:** v-if for rare toggles; v-show for frequent toggles.

### 216. What is v-for?

**Answer:** Renders lists.

### 217. Why key in v-for?

**Answer:** Helps Vue track list items correctly.

### 218. Why avoid index as key?

**Answer:** It can cause wrong DOM reuse after reorder/delete.

### 219. What are props?

**Answer:** Parent-to-child data inputs.

### 220. What are emits?

**Answer:** Child-to-parent event communication.

### 221. Props down events up?

**Answer:** Parent sends props; child emits events.

### 222. What is slot?

**Answer:** Parent-provided content inside child component.

### 223. What is named slot?

**Answer:** Slot with a specific name.

### 224. What is scoped slot?

**Answer:** Slot that receives data from child component.

### 225. What is lifecycle hook?

**Answer:** Function called during component lifecycle.

### 226. Common Vue 3 hooks?

**Answer:** onMounted, onUpdated, onUnmounted.

### 227. When use onMounted?

**Answer:** For initial API calls or DOM-dependent logic.

### 228. What is Vue Router?

**Answer:** Official SPA routing library.

### 229. What are route params?

**Answer:** Dynamic URL parts like /users/:id.

### 230. What are query params?

**Answer:** URL values like ?page=1.

### 231. How protect routes?

**Answer:** Use navigation guards.

### 232. What is Pinia?

**Answer:** Modern recommended Vue state management library.

### 233. Pinia vs Vuex?

**Answer:** Pinia is simpler and more TypeScript-friendly; Vuex is older.

### 234. What is Vuex?

**Answer:** Centralized state management with state, getters, mutations, actions.

### 235. What is store?

**Answer:** Shared application state container.

### 236. What is action?

**Answer:** Store method for async/business logic.

### 237. What is getter?

**Answer:** Derived store state.

### 238. What is mutation?

**Answer:** Vuex method to synchronously change state.

### 239. What is composable?

**Answer:** Reusable Composition API function like useAuth().

### 240. What is provide/inject?

**Answer:** Pass data from ancestor to descendant without prop drilling.

### 241. What is prop drilling?

**Answer:** Passing props through many levels unnecessarily.

### 242. What is Teleport?

**Answer:** Render component content elsewhere in DOM.

### 243. What is Fragment?

**Answer:** Multiple root elements in Vue 3 component.

### 244. What is Suspense?

**Answer:** Fallback UI for async dependencies.

### 245. What is dynamic component?

**Answer:** Rendering component with <component :is='...'>.

### 246. What is async component?

**Answer:** Component loaded lazily.

### 247. What is lazy route loading?

**Answer:** Loading route component only when visited.

### 248. What is Vite?

**Answer:** Fast frontend build tool.

### 249. Vite vs Vue CLI?

**Answer:** Vite is modern/faster; Vue CLI is Webpack-based.

### 250. What is template ref?

**Answer:** Reference to DOM element or child component.

### 251. What is directive?

**Answer:** Special template attribute like v-if or v-model.

### 252. What is custom directive?

**Answer:** Reusable low-level DOM behavior.

### 253. What happened to filters in Vue 3?

**Answer:** Filters were removed; use computed or methods.

### 254. What happened to event bus in Vue 3?

**Answer:** It is not recommended; use props/emits, Pinia, provide/inject.

### 255. What is $attrs?

**Answer:** Non-prop attributes passed to a component.

### 256. What is defineProps?

**Answer:** Declares props in script setup.

### 257. What is defineEmits?

**Answer:** Declares emitted events in script setup.

### 258. What is defineExpose?

**Answer:** Exposes selected internals to parent refs.

### 259. What is nextTick?

**Answer:** Waits for DOM update after state change.

### 260. Why use nextTick?

**Answer:** To safely access updated DOM.

### 261. How call API in Vue?

**Answer:** Use fetch/Axios in composables, stores, or lifecycle hooks.

### 262. How handle loading state?

**Answer:** Use reactive loading/error/data states.

### 263. How prevent duplicate submit?

**Answer:** Disable button while loading and guard handler.

### 264. How handle auth in Vue?

**Answer:** Store token/session, attach token, protect routes, clear state on logout.

### 265. Where store token?

**Answer:** HttpOnly cookie is safer; localStorage is convenient but XSS-exposed.

### 266. What is Axios interceptor?

**Answer:** Global request/response hook for token/error handling.

### 267. How handle Laravel 422 in Vue?

**Answer:** Map response errors to form fields.

### 268. What is debounce?

**Answer:** Delay action until user stops triggering.

### 269. What is throttle?

**Answer:** Limit action to once per interval.

### 270. How optimize Vue?

**Answer:** Lazy-load, use computed, stable keys, pagination, smaller components.

### 271. What is virtual DOM?

**Answer:** In-memory representation for efficient DOM updates.

### 272. What is SPA?

**Answer:** Single-page app with client-side routing.

### 273. What is SSR?

**Answer:** Server-side rendering for initial HTML.

### 274. What is Nuxt?

**Answer:** Vue framework for SSR/SSG/full-stack features.

### 275. What is TypeScript in Vue?

**Answer:** Static typing for props, emits, stores, API models.

### 276. How structure Vue project?

**Answer:** components, views, router, stores, services, composables, assets, types.

### 277. What is reusable table?

**Answer:** Component accepting columns/data/loading and emitting actions.

### 278. How sibling components communicate?

**Answer:** Lift state to parent or use store/provide-inject.

### 279. Vue anti-patterns?

**Answer:** Mutating props, huge components, index keys, too many watchers, direct DOM manipulation.

### 280. What is data() in Options API?

**Answer:** Function returning local reactive state.

### 281. Why data must be function?

**Answer:** Each component instance needs separate state.

### 282. What is this in Options API?

**Answer:** Component instance reference.

### 283. Why no this in script setup?

**Answer:** Variables are directly available from setup scope.

### 284. What is shallowRef?

**Answer:** Tracks only .value changes, not deep nested changes.

### 285. What is readonly?

**Answer:** Creates read-only reactive object.

### 286. What is toRefs?

**Answer:** Converts reactive object properties into refs.

### 287. Why destructuring can break reactivity?

**Answer:** It extracts plain values unless using toRefs/storeToRefs.

### 288. What is storeToRefs?

**Answer:** Pinia helper preserving reactivity when destructuring store state.

## JavaScript, TypeScript, HTML & CSS

### 289. What is JavaScript?

**Answer:** A language used to build interactive web behavior and frontend apps.

### 290. What is TypeScript?

**Answer:** JavaScript with static types.

### 291. JS vs TS?

**Answer:** TS adds compile-time type checking and compiles to JS.

### 292. What is var?

**Answer:** Function-scoped older variable declaration.

### 293. What is let?

**Answer:** Block-scoped variable that can be reassigned.

### 294. What is const?

**Answer:** Block-scoped variable that cannot be reassigned.

### 295. var vs let vs const?

**Answer:** var is function-scoped; let/const are block-scoped. Prefer const, then let.

### 296. What is hoisting?

**Answer:** Declarations are processed before execution.

### 297. What is temporal dead zone?

**Answer:** Period before let/const initialization where access throws error.

### 298. What is closure?

**Answer:** Function remembers outer scope variables.

### 299. What is callback?

**Answer:** Function passed to another function.

### 300. What is Promise?

**Answer:** Object representing future async result.

### 301. What is async/await?

**Answer:** Cleaner syntax for Promise-based async code.

### 302. Promise vs async/await?

**Answer:** Same async model; async/await improves readability.

### 303. What is event loop?

**Answer:** Mechanism handling call stack and async queues.

### 304. What is microtask?

**Answer:** Promise callbacks and similar high-priority async tasks.

### 305. What is macrotask?

**Answer:** setTimeout, events, I/O tasks.

### 306. What is DOM?

**Answer:** Object representation of HTML document.

### 307. What is event bubbling?

**Answer:** Event moves from target to ancestors.

### 308. What is event capturing?

**Answer:** Event moves from ancestors to target.

### 309. What is event delegation?

**Answer:** Handling child events at parent level.

### 310. What is this?

**Answer:** Execution context depending on call site.

### 311. Arrow vs normal function?

**Answer:** Arrow has lexical this; normal function has dynamic this.

### 312. What is destructuring?

**Answer:** Extracting values from arrays/objects.

### 313. What is spread?

**Answer:** Expanding arrays/objects using ...

### 314. What is rest?

**Answer:** Collecting remaining values using ...

### 315. What is template literal?

**Answer:** Backtick string with interpolation.

### 316. What is module?

**Answer:** File exporting/importing code.

### 317. Default vs named export?

**Answer:** Default exports one main value; named exports multiple named values.

### 318. What is optional chaining?

**Answer:** Safe access with ?..

### 319. What is nullish coalescing?

**Answer:** Fallback only for null/undefined using ??.

### 320. What are falsy values?

**Answer:** false, 0, '', null, undefined, NaN.

### 321. What is shallow copy?

**Answer:** Top-level copy with shared nested references.

### 322. What is deep copy?

**Answer:** Copy including nested values.

### 323. What is map()?

**Answer:** Transforms array and returns new array.

### 324. What is filter()?

**Answer:** Returns items matching condition.

### 325. What is reduce()?

**Answer:** Accumulates array into one result.

### 326. What is forEach()?

**Answer:** Iterates for side effects.

### 327. map vs forEach?

**Answer:** map returns array; forEach returns undefined.

### 328. What is find()?

**Answer:** Returns first matching item.

### 329. What is some()?

**Answer:** True if any item matches.

### 330. What is every()?

**Answer:** True if all items match.

### 331. What is sort() caveat?

**Answer:** It mutates array and sorts as string by default.

### 332. What is JSON?

**Answer:** Text format for structured data.

### 333. What is fetch?

**Answer:** Browser API for HTTP requests.

### 334. Fetch vs Axios?

**Answer:** Fetch is built-in; Axios has interceptors and easier error handling.

### 335. What is CORS?

**Answer:** Browser cross-origin request security.

### 336. What is localStorage?

**Answer:** Persistent browser key-value storage.

### 337. What is sessionStorage?

**Answer:** Tab/session-limited browser storage.

### 338. localStorage vs cookie?

**Answer:** localStorage is JS-accessible; cookies can be HttpOnly and auto-sent.

### 339. What is debounce?

**Answer:** Delay function until events stop.

### 340. What is throttle?

**Answer:** Limit function execution frequency.

### 341. What is immutability?

**Answer:** Avoid mutating existing data directly.

### 342. What is prototype?

**Answer:** JavaScript inheritance mechanism.

### 343. What is class in JS?

**Answer:** Syntax for constructor/prototype-based objects.

### 344. What is try/catch?

**Answer:** Error handling block.

### 345. How handle API errors?

**Answer:** Use try/catch, status checks, user messages, and logs.

### 346. What is form validation?

**Answer:** Checking user input before and after submit.

### 347. What is responsive design?

**Answer:** UI adapts to screen sizes.

### 348. What is Flexbox?

**Answer:** One-dimensional CSS layout system.

### 349. What is Grid?

**Answer:** Two-dimensional CSS layout system.

### 350. Flexbox vs Grid?

**Answer:** Flexbox for row/column flow; Grid for rows and columns.

### 351. What is specificity?

**Answer:** CSS rule priority calculation.

### 352. What is semantic HTML?

**Answer:** Meaningful tags like header, nav, main, section.

### 353. What is accessibility?

**Answer:** Making UI usable by everyone, including disabled users.

### 354. What is ARIA?

**Answer:** Accessibility attributes for complex UI.

### 355. What is npm?

**Answer:** JavaScript package manager.

### 356. What is package.json?

**Answer:** Project dependency and script metadata.

### 357. dependencies vs devDependencies?

**Answer:** Runtime/build needs vs development tools.

### 358. What is ESLint?

**Answer:** Code quality/linting tool.

### 359. What is Prettier?

**Answer:** Code formatting tool.

### 360. What is bundling?

**Answer:** Combining/transpiling assets for browser delivery.

### 361. What is tree shaking?

**Answer:** Removing unused code from bundle.

### 362. What is source map?

**Answer:** Maps built code back to source for debugging.

### 363. What is TS interface?

**Answer:** Defines object shape.

### 364. Interface vs type?

**Answer:** Interface is extendable/mergeable; type is flexible for unions/intersections.

### 365. What is generic?

**Answer:** Reusable type parameter.

### 366. What is union type?

**Answer:** A value can be one of several types.

### 367. What is any?

**Answer:** Disables type checking.

### 368. What is unknown?

**Answer:** Safer type requiring narrowing.

### 369. What is type narrowing?

**Answer:** Refining type using checks.

## SQL & MySQL

### 370. What is SQL?

**Answer:** Language for relational database queries.

### 371. What is MySQL?

**Answer:** A relational database commonly used with PHP/Laravel.

### 372. What is table?

**Answer:** Rows and columns storing one entity type.

### 373. What is row?

**Answer:** One record.

### 374. What is column?

**Answer:** One field/attribute.

### 375. What is primary key?

**Answer:** Unique row identifier.

### 376. What is foreign key?

**Answer:** Column referencing another table.

### 377. What is unique key?

**Answer:** Constraint preventing duplicate values.

### 378. Primary vs unique key?

**Answer:** Primary identifies row and is not null; unique prevents duplicates.

### 379. What is index?

**Answer:** Data structure improving query speed.

### 380. What is composite index?

**Answer:** Index on multiple columns.

### 381. What is normalization?

**Answer:** Reducing duplication and improving consistency.

### 382. What is denormalization?

**Answer:** Adding duplication/precomputed data for read performance.

### 383. What is SELECT?

**Answer:** Retrieves data.

### 384. What is WHERE?

**Answer:** Filters rows.

### 385. What is ORDER BY?

**Answer:** Sorts rows.

### 386. What is GROUP BY?

**Answer:** Groups rows for aggregation.

### 387. What is HAVING?

**Answer:** Filters grouped results.

### 388. WHERE vs HAVING?

**Answer:** WHERE before grouping; HAVING after grouping.

### 389. What is LIMIT?

**Answer:** Restricts returned rows.

### 390. What is OFFSET?

**Answer:** Skips rows.

### 391. What is INNER JOIN?

**Answer:** Returns matching rows from both tables.

### 392. What is LEFT JOIN?

**Answer:** Returns all left rows and matching right rows.

### 393. INNER vs LEFT JOIN?

**Answer:** INNER only matched; LEFT keeps left rows.

### 394. What is self join?

**Answer:** A table joined with itself.

### 395. What is subquery?

**Answer:** Query inside another query.

### 396. What is correlated subquery?

**Answer:** Subquery depending on outer query row.

### 397. What is aggregate function?

**Answer:** COUNT, SUM, AVG, MIN, MAX.

### 398. COUNT(\*) vs COUNT(column)?

**Answer:** COUNT(\*) counts rows; COUNT(column) counts non-null values.

### 399. What is DISTINCT?

**Answer:** Removes duplicates.

### 400. What is alias?

**Answer:** Temporary name for table/column.

### 401. What is transaction?

**Answer:** Atomic group of operations.

### 402. What is ACID?

**Answer:** Atomicity, Consistency, Isolation, Durability.

### 403. What is COMMIT?

**Answer:** Save transaction changes.

### 404. What is ROLLBACK?

**Answer:** Cancel transaction changes.

### 405. What is deadlock?

**Answer:** Transactions wait on each other's locks.

### 406. How reduce deadlocks?

**Answer:** Short transactions, consistent order, proper indexes.

### 407. What is lock?

**Answer:** Control for concurrent data access.

### 408. What is row lock?

**Answer:** Lock on selected rows.

### 409. What is optimistic locking?

**Answer:** Detect conflict using version/timestamp.

### 410. What is pessimistic locking?

**Answer:** Lock before update.

### 411. What is isolation level?

**Answer:** Controls transaction visibility.

### 412. What is dirty read?

**Answer:** Reading uncommitted data.

### 413. What is non-repeatable read?

**Answer:** Same row gives different values in one transaction.

### 414. What is phantom read?

**Answer:** Repeated query sees new/deleted rows.

### 415. What is EXPLAIN?

**Answer:** Shows query execution plan.

### 416. What is slow query?

**Answer:** Query taking too long due to scans/bad indexes/etc.

### 417. How optimize email search?

**Answer:** Index email and use exact match.

### 418. Why LIKE '%x%' is slow?

**Answer:** Leading wildcard prevents normal index use.

### 419. What is NULL?

**Answer:** Missing/unknown value.

### 420. How compare NULL?

**Answer:** Use IS NULL or IS NOT NULL.

### 421. What is COALESCE?

**Answer:** Returns first non-null value.

### 422. What is CASE?

**Answer:** Conditional expression in SQL.

### 423. What is UNION?

**Answer:** Combines SELECT results and removes duplicates.

### 424. UNION vs UNION ALL?

**Answer:** UNION removes duplicates; UNION ALL keeps them and is faster.

### 425. What is view?

**Answer:** Saved query used like virtual table.

### 426. What is trigger?

**Answer:** Auto-run logic on insert/update/delete.

### 427. What is stored procedure?

**Answer:** Database-side reusable procedure.

### 428. What is cascade delete?

**Answer:** Child rows delete automatically when parent deletes.

### 429. What is restrict delete?

**Answer:** Prevents deleting parent with children.

### 430. What is soft delete?

**Answer:** Mark deleted instead of removing row.

### 431. What are timestamps?

**Answer:** created_at and updated_at fields.

### 432. What is many-to-many?

**Answer:** Relationship through pivot table.

### 433. What is one-to-many?

**Answer:** One parent has many children.

### 434. What is one-to-one?

**Answer:** One row maps to one related row.

### 435. What is ERD?

**Answer:** Diagram of entities and relationships.

### 436. What is migration?

**Answer:** Versioned schema change.

### 437. What is seeding?

**Answer:** Inserting initial/sample data.

### 438. What is backup?

**Answer:** Data copy for recovery.

### 439. What is replication?

**Answer:** Copying data to replica servers.

### 440. What is read replica?

**Answer:** Database replica for read traffic.

### 441. What is connection pool?

**Answer:** Reusable DB connections.

### 442. What is decimal vs float for money?

**Answer:** Use DECIMAL for exact money values.

### 443. What is check constraint?

**Answer:** Rule like amount >= 0.

### 444. What is upsert?

**Answer:** Insert or update if conflict exists.

### 445. What is selectivity?

**Answer:** How well an index filters rows.

### 446. When not to index?

**Answer:** Rarely queried/low-selectivity columns or too many write-heavy indexes.

### 447. How design order tables?

**Answer:** orders for header, order_items for item lines.

### 448. Why store price snapshot?

**Answer:** Historical orders remain correct after price changes.

### 449. How filter by payment method?

**Answer:** Add validated payment_method filter in query and index if needed.

### 450. How prevent duplicate records?

**Answer:** Use unique constraints and handle duplicate errors.

## REST API & Web Backend

### 451. What is REST API?

**Answer:** Resource-based API using HTTP methods, status codes, and JSON.

### 452. What is resource?

**Answer:** An entity exposed by URL, like users or products.

### 453. What is GET?

**Answer:** Retrieve data.

### 454. What is POST?

**Answer:** Create resource or trigger action.

### 455. What is PUT?

**Answer:** Replace/update resource idempotently.

### 456. What is PATCH?

**Answer:** Partially update resource.

### 457. What is DELETE?

**Answer:** Delete or mark resource deleted.

### 458. PUT vs PATCH?

**Answer:** PUT full replacement; PATCH partial update.

### 459. What is idempotency?

**Answer:** Repeated same request has same final effect.

### 460. What is 200?

**Answer:** OK success.

### 461. What is 201?

**Answer:** Created.

### 462. What is 204?

**Answer:** Success with no body.

### 463. What is 400?

**Answer:** Bad request.

### 464. What is 401?

**Answer:** Unauthenticated.

### 465. What is 403?

**Answer:** Forbidden.

### 466. What is 404?

**Answer:** Not found.

### 467. What is 409?

**Answer:** Conflict.

### 468. What is 422?

**Answer:** Validation error.

### 469. What is 500?

**Answer:** Internal server error.

### 470. What is JSON response?

**Answer:** Structured API output in JSON format.

### 471. What is API versioning?

**Answer:** Maintaining versions like /api/v1.

### 472. What is pagination?

**Answer:** Returning data in pages.

### 473. What is sorting?

**Answer:** Ordering results using query parameters.

### 474. What is filtering?

**Answer:** Narrowing results with parameters.

### 475. What is JWT?

**Answer:** Signed token containing claims for auth.

### 476. What is Bearer token?

**Answer:** Token sent in Authorization: Bearer header.

### 477. What is refresh token?

**Answer:** Token used to get new access token.

### 478. What is rate limiting?

**Answer:** Restricting request frequency.

### 479. What is CORS preflight?

**Answer:** Browser OPTIONS check before cross-origin request.

### 480. What is OpenAPI/Swagger?

**Answer:** API documentation/testing specification.

### 481. What is Postman?

**Answer:** Tool to test APIs.

### 482. What is request validation?

**Answer:** Checking incoming data correctness.

### 483. What is response transformation?

**Answer:** Converting internal model to API-safe output.

### 484. Why not expose DB directly?

**Answer:** It leaks internals and breaks clients when schema changes.

### 485. What is consistent error format?

**Answer:** Standard message/errors/code structure.

### 486. What is correlation ID?

**Answer:** Unique request ID for tracing logs.

### 487. What should not be logged?

**Answer:** Passwords, tokens, secrets, and sensitive data.

### 488. What is timeout?

**Answer:** Maximum wait time for response.

### 489. What is retry?

**Answer:** Repeating failed request safely.

### 490. What is idempotency key?

**Answer:** Client key preventing duplicate processing.

### 491. What is webhook?

**Answer:** HTTP callback from external system.

### 492. How secure webhook?

**Answer:** Verify signature, timestamp, source, and idempotency.

### 493. How handle slow task?

**Answer:** Move to queue/background job.

### 494. What is API caching?

**Answer:** Store frequent responses/data temporarily.

### 495. What is ETag?

**Answer:** HTTP cache validator.

### 496. What is 304?

**Answer:** Not Modified.

### 497. What is API contract?

**Answer:** Agreed request/response behavior.

### 498. Why backward compatibility?

**Answer:** Avoid breaking frontend/mobile clients.

## Git, Linux & Deployment

### 499. What is Git?

**Answer:** Distributed version control system.

### 500. What is repository?

**Answer:** A project tracked by Git.

---

## Final Must-Revise Topics Before Interview

- Laravel routing, controllers, middleware, validation, Eloquent relationships, migrations, API Resources, queues, caching, authentication, and authorization.
- Vue 2 vs Vue 3, Options API vs Composition API, props/emits, Pinia/Vuex, router guards, Axios, validation errors, and reusable components.
- Raw PHP OOP, Composer, PDO, sessions/cookies, prepared statements, password hashing, file uploads, and security basics.
- SQL joins, indexes, transactions, normalization, pagination, slow query debugging, and order/order_items schema design.
- REST status codes, API filtering/sorting/pagination, JWT/Bearer auth, CORS, rate limiting, and consistent error responses.
- Practical debugging: Laravel 500, Vue blank page, 401/422, CORS, slow query, duplicate submit, and deployment issues.

## Suggested Self Introduction

> I am a full-stack developer focused on PHP/Laravel backend development and Vue.js frontend development. I have experience building REST APIs, working with MySQL databases, handling CRUD flows, validation, authentication, and debugging backend/frontend integration issues. I enjoy building scalable systems and smooth user experiences, and I am comfortable working independently as well as with a team.
