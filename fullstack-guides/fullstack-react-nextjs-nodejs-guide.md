# Full Stack Developer (Mid-Level) Interview Preparation

## Focus: React.js, Next.js, Node.js, PostgreSQL, API Design, Security, UI/UX, Git, System Design, Debugging

---

# Table of Contents

1. Introduction and HR Questions
2. JavaScript Fundamentals
3. React.js
4. Next.js
5. HTML and CSS
6. UI/UX and Responsive Design
7. Node.js and Express.js
8. REST API Design
9. Authentication and Security
10. PostgreSQL and SQL
11. Git and GitHub
12. Testing and Debugging
13. Performance and Scalability
14. Android and Mobile Integration Basics
15. Cloud and Deployment Basics
16. Full Stack Project Questions
17. Critical System Design
18. Behavioral Questions
19. Rapid Fire Questions
20. Final Revision Checklist

---

# 1. Introduction and HR Questions

## Q1. Tell me about yourself.

**Answer:**
I am a software engineer with strong backend development experience and growing full stack expertise. My core strengths are API development, database design, debugging, authentication, and building maintainable systems. I enjoy solving practical business problems and making sure software is secure, scalable, and easy to maintain. I have also been improving my frontend knowledge, especially around React, responsive UI, and integrating backend services cleanly. What interests me about this role is that it combines product thinking, full stack engineering, and real user impact through HRIS and job platform solutions.

---

## Q2. Why do you want to join this company?

**Answer:**
I want to join because the company is building practical platforms like HRIS, job platforms, and networking tools, which solve real-world problems. I like working on systems that directly affect users and business operations. The technology stack also matches the direction I want to grow in, especially full stack development involving modern frontend frameworks, APIs, databases, and scalable product development.

---

## Q3. Why are you a good fit for this role?

**Answer:**
I am a good fit because I think beyond only frontend or backend. I focus on how the entire system works together: UI, API, database, security, performance, and maintainability. I am comfortable with backend logic, debugging, and data modeling, and I can also work on frontend integration and responsive design. I also value communication, ownership, and writing clean code, which are important in a collaborative product team.

---

## Q4. What are your strengths?

**Answer:**
My strengths are problem solving, debugging complex issues, designing backend logic, and thinking structurally about software. I am also strong at learning new technologies quickly and turning business requirements into working systems. I care about code quality and long-term maintainability.

---

## Q5. What is your weakness?

**Answer:**
One weakness I have worked on is spending too much time trying to perfect an implementation early. Over time, I have become better at balancing quality with delivery speed by first shipping a clean working solution and then improving it iteratively.

---

## Q6. Where do you see yourself in 3 to 5 years?

**Answer:**
I see myself becoming a strong full stack engineer who can design and build complete systems, contribute to architecture decisions, mentor junior developers, and take ownership of important product modules.

---

# 2. JavaScript Fundamentals

## Q1. What is the difference between `var`, `let`, and `const`?

**Answer:**

- `var` is function-scoped and can be redeclared and updated.
- `let` is block-scoped and can be updated but not redeclared in the same scope.
- `const` is block-scoped and cannot be reassigned after declaration.

**Best practice:** use `const` by default, and `let` only when the value needs to change.

---

## Q2. What is hoisting?

**Answer:**
Hoisting is JavaScript's behavior of moving declarations to the top of their scope before execution.

- `var` is hoisted and initialized with `undefined`
- `let` and `const` are hoisted too, but they stay in the temporal dead zone until declared
- Function declarations are hoisted completely

---

## Q3. What is a closure?

**Answer:**
A closure happens when a function remembers variables from its outer scope even after the outer function has finished execution.

```js
function outer() {
  let count = 0;
  return function inner() {
    count++;
    return count;
  };
}
const counter = outer();
```

**Use cases:** private state, callbacks, function factories, memoization.

---

## Q4. What is the event loop?

**Answer:**
JavaScript is single-threaded, but it handles asynchronous operations using the event loop.

- Synchronous code goes to the call stack
- Async operations like timers and I/O are handled outside the stack
- Completed callbacks go to queues
- The event loop moves them into the stack when it becomes free

**Important detail:**

- Promise callbacks go into the microtask queue
- `setTimeout` callbacks go into the macrotask queue
- Microtasks execute before macrotasks

---

## Q5. What is the difference between `==` and `===`?

**Answer:**

- `==` compares values after type coercion
- `===` compares value and type without coercion

**Best practice:** always prefer `===`

---

## Q6. What are primitive types in JavaScript?

**Answer:**
The primitive types are:

- string
- number
- bigint
- boolean
- undefined
- symbol
- null

---

## Q7. What is the difference between `null` and `undefined`?

**Answer:**

- `undefined` means a variable has been declared but not assigned a value
- `null` is an intentional assignment meaning "no value"

---

## Q8. What is the difference between `map`, `filter`, and `reduce`?

**Answer:**

- `map()` transforms every item and returns a new array
- `filter()` returns items that match a condition
- `reduce()` combines array items into a single value

```js
const nums = [1, 2, 3];
nums.map((x) => x * 2); // [2,4,6]
nums.filter((x) => x > 1); // [2,3]
nums.reduce((a, b) => a + b, 0); // 6
```

---

## Q9. What is destructuring?

**Answer:**
Destructuring is a shorter way to extract values from arrays or objects.

```js
const user = { name: "Asif", age: 25 };
const { name, age } = user;
```

---

## Q10. What is the spread operator?

**Answer:**
The spread operator `...` expands arrays or objects.

```js
const a = [1, 2];
const b = [...a, 3];
```

It is useful for copying arrays and objects and merging data immutably.

---

## Q11. What is debounce?

**Answer:**
Debounce delays a function call until the user stops triggering it for a certain time.

**Use cases:** search input, resize events, autocomplete.

---

## Q12. What is throttle?

**Answer:**
Throttle limits how often a function can run within a certain time window.

**Use cases:** scroll events, mouse movement, resize handlers.

---

## Q13. Difference between debounce and throttle?

**Answer:**

- Debounce waits until activity stops
- Throttle runs at controlled intervals during activity

---

# 3. React.js

## Q1. What is React?

**Answer:**
React is a JavaScript library for building user interfaces using reusable components and a virtual DOM.

---

## Q2. What is the virtual DOM?

**Answer:**
The virtual DOM is a lightweight JavaScript representation of the real DOM. React updates the virtual DOM first, compares changes, and then updates only the necessary parts of the real DOM. This improves performance.

---

## Q3. What are components?

**Answer:**
Components are reusable pieces of UI. They can be functional or class-based, though modern React mainly uses functional components with hooks.

---

## Q4. What is JSX?

**Answer:**
JSX is syntax that looks like HTML inside JavaScript. It allows developers to describe UI structure more clearly.

```jsx
const element = <h1>Hello</h1>;
```

---

## Q5. What is state in React?

**Answer:**
State is data managed inside a component that can change over time and trigger re-renders.

---

## Q6. What are props?

**Answer:**
Props are inputs passed from a parent component to a child component. Props are read-only.

---

## Q7. What causes a React component to re-render?

**Answer:**
A component re-renders when:

- its state changes
- its props change
- its parent re-renders
- context changes

---

## Q8. What is `useState`?

**Answer:**
`useState` is a hook used to manage local component state.

```jsx
const [count, setCount] = useState(0);
```

---

## Q9. What is `useEffect`?

**Answer:**
`useEffect` is used for side effects such as API calls, subscriptions, timers, and DOM updates.

```jsx
useEffect(() => {
  fetchData();
}, []);
```

- No dependency array: runs after every render
- Empty dependency array: runs once after mount
- With dependencies: runs when dependencies change

---

## Q10. What is cleanup in `useEffect`?

**Answer:**
Cleanup is used to remove subscriptions, clear timers, or prevent memory leaks.

```jsx
useEffect(() => {
  const timer = setInterval(() => {}, 1000);
  return () => clearInterval(timer);
}, []);
```

---

## Q11. What is `useRef`?

**Answer:**
`useRef` stores a mutable value that does not trigger a re-render. It is also used to access DOM elements directly.

---

## Q12. What is `useMemo`?

**Answer:**
`useMemo` memoizes a calculated value so it is only recomputed when dependencies change.

**Use case:** expensive calculations.

---

## Q13. What is `useCallback`?

**Answer:**
`useCallback` memoizes a function so its reference stays stable unless dependencies change.

**Use case:** preventing unnecessary child re-renders when passing callbacks.

---

## Q14. What is React.memo?

**Answer:**
`React.memo` prevents a functional component from re-rendering if its props have not changed.

---

## Q15. How do you optimize React performance?

**Answer:**

- Use `React.memo`
- Use `useMemo` and `useCallback` carefully
- Avoid unnecessary state
- Split components properly
- Lazy load large components
- Virtualize long lists
- Reduce expensive computations during render

---

## Q16. Controlled vs uncontrolled components?

**Answer:**

- Controlled components use React state to manage form values
- Uncontrolled components rely on the DOM directly

**Best practice:** controlled components are usually preferred in React forms.

---

## Q17. What is lifting state up?

**Answer:**
Lifting state up means moving state to the nearest common parent so multiple child components can share and update it.

---

## Q18. What is prop drilling?

**Answer:**
Prop drilling happens when props are passed through many layers of components just to reach a deep child. This can make code hard to maintain.

**Solution:** context API, state management libraries.

---

## Q19. What is Context API?

**Answer:**
Context API allows data to be shared globally across components without passing props manually at every level.

---

## Q20. What is key in React lists?

**Answer:**
A key helps React identify which items changed, were added, or removed.

**Best practice:** use unique stable IDs, not array index if the list can change.

---

# 4. Next.js

## Q1. Why use Next.js instead of plain React?

**Answer:**
Next.js provides:

- file-based routing
- server-side rendering
- static site generation
- API routes
- image optimization
- better SEO
- improved performance out of the box

---

## Q2. What is SSR?

**Answer:**
SSR stands for Server Side Rendering. The page is rendered on the server for every request.

**Use case:** dynamic content, SEO-sensitive pages.

---

## Q3. What is SSG?

**Answer:**
SSG stands for Static Site Generation. Pages are generated at build time.

**Use case:** blog posts, documentation, mostly static pages.

---

## Q4. What is CSR?

**Answer:**
CSR stands for Client Side Rendering. The browser loads a basic page and then JavaScript renders the rest on the client side.

---

## Q5. Difference between SSR, SSG, and CSR?

**Answer:**

- SSR: generated on each request
- SSG: generated at build time
- CSR: rendered in the browser

---

## Q6. What is hydration?

**Answer:**
Hydration is the process where React attaches event listeners and makes server-rendered HTML interactive on the client.

---

## Q7. What are API routes in Next.js?

**Answer:**
Next.js lets you build backend endpoints inside the same project using API routes.

---

## Q8. What is dynamic routing in Next.js?

**Answer:**
Dynamic routing allows pages like `/jobs/[id]` where the page content depends on route parameters.

---

## Q9. What is `getServerSideProps`?

**Answer:**
It fetches data on the server for each request before rendering the page.

---

## Q10. What is `getStaticProps`?

**Answer:**
It fetches data at build time for static generation.

---

# 5. HTML and CSS

## Q1. Difference between block and inline elements?

**Answer:**

- Block elements take full width and start on a new line
- Inline elements only take the space they need

---

## Q2. What is semantic HTML?

**Answer:**
Semantic HTML uses meaningful tags like `header`, `footer`, `article`, `section`, `nav`, `main` to improve accessibility and readability.

---

## Q3. What is the difference between `id` and `class`?

**Answer:**

- `id` should be unique in the document
- `class` can be reused across multiple elements

---

## Q4. Difference between `display: none` and `visibility: hidden`?

**Answer:**

- `display: none` removes the element from the layout
- `visibility: hidden` hides the element but keeps its space

---

## Q5. What is the CSS box model?

**Answer:**
The box model includes:

- content
- padding
- border
- margin

---

## Q6. What is the difference between absolute, relative, fixed, and sticky positioning?

**Answer:**

- `relative`: positioned relative to its normal position
- `absolute`: positioned relative to nearest positioned ancestor
- `fixed`: positioned relative to viewport
- `sticky`: behaves like relative until a threshold, then fixed-like

---

## Q7. Difference between Flexbox and Grid?

**Answer:**

- Flexbox is one-dimensional, good for rows or columns
- Grid is two-dimensional, good for layout with rows and columns

---

## Q8. What is z-index?

**Answer:**
`z-index` controls stacking order of overlapping elements. It works on positioned elements.

---

# 6. UI/UX and Responsive Design

## Q1. What is responsive design?

**Answer:**
Responsive design means the UI adapts to different screen sizes and devices such as mobile, tablet, and desktop.

---

## Q2. What is mobile-first design?

**Answer:**
Mobile-first means designing for small screens first, then progressively enhancing for larger screens.

---

## Q3. Why is responsive design important?

**Answer:**
Because users access applications from many devices. A poor mobile experience can reduce usability, engagement, and conversions.

---

## Q4. What are breakpoints?

**Answer:**
Breakpoints are screen width thresholds used in media queries to adjust layout and styles.

---

## Q5. What is good UI/UX?

**Answer:**
Good UI/UX means the system is:

- easy to understand
- visually clear
- accessible
- consistent
- fast
- intuitive for users

---

## Q6. What are common UI mistakes developers make?

**Answer:**

- Too much clutter
- Poor spacing
- Weak contrast
- Not mobile-friendly
- Inconsistent buttons and forms
- No loading or error states
- Ignoring accessibility

---

## Q7. How do you make forms user-friendly?

**Answer:**

- clear labels
- inline validation
- helpful error messages
- proper spacing
- keyboard accessibility
- good default values when appropriate

---

## Q8. What is accessibility?

**Answer:**
Accessibility means designing software so people with disabilities can use it. This includes keyboard navigation, screen reader support, proper semantic HTML, and sufficient contrast.

---

## Q9. How would you use Material UI or Ant Design well?

**Answer:**
I would use the component system for speed and consistency, but I would still customize spacing, states, validation, responsiveness, and branding so the UI matches product needs instead of feeling generic.

---

# 7. Node.js and Express.js

## Q1. What is Node.js?

**Answer:**
Node.js is a JavaScript runtime built on Chrome's V8 engine. It lets us run JavaScript on the server.

---

## Q2. Why is Node.js good for backend development?

**Answer:**
It is good for:

- event-driven systems
- I/O-heavy applications
- real-time applications
- fast API development
- using one language on both frontend and backend

---

## Q3. What is non-blocking I/O?

**Answer:**
Non-blocking I/O means Node.js can continue handling other tasks while waiting for I/O operations like database queries or file reads to complete.

---

## Q4. How does Node.js handle concurrency if it is single-threaded?

**Answer:**
The main JavaScript execution is single-threaded, but Node.js uses an event loop and underlying system threads for I/O operations. This lets it handle many concurrent connections efficiently.

---

## Q5. What is Express.js?

**Answer:**
Express.js is a lightweight web framework for Node.js used to build APIs and web applications.

---

## Q6. What is middleware?

**Answer:**
Middleware is a function that runs during the request-response cycle before the final route handler.

**Examples:**

- logging
- authentication
- validation
- error handling

---

## Q7. What is the difference between synchronous and asynchronous code?

**Answer:**

- Synchronous code runs line by line and blocks until done
- Asynchronous code allows other operations to continue while waiting for slow tasks like I/O

---

## Q8. What is callback hell?

**Answer:**
Callback hell happens when multiple nested callbacks make code hard to read and maintain.

**Solution:** promises and async/await.

---

## Q9. What is a Promise?

**Answer:**
A Promise represents the result of an asynchronous operation that may complete in the future.

It has 3 states:

- pending
- fulfilled
- rejected

---

## Q10. Why use `async/await`?

**Answer:**
`async/await` makes asynchronous code look cleaner and more readable than chained `.then()` calls.

---

## Q11. What is error handling in Express?

**Answer:**
Error handling is usually done with middleware that catches thrown errors and sends a consistent response format.

```js
app.use((err, req, res, next) => {
  res.status(500).json({ message: err.message });
});
```

---

## Q12. How do you structure a Node.js project?

**Answer:**
A clean structure may include:

- routes
- controllers
- services
- repositories or data access layer
- middleware
- models
- utils
- config

This separation improves maintainability and testing.

---

# 8. REST API Design

## Q1. What is REST?

**Answer:**
REST is an architectural style for designing web APIs using resources, HTTP methods, statelessness, and standard response codes.

---

## Q2. Common HTTP methods?

**Answer:**

- GET: fetch data
- POST: create data
- PUT: replace full resource
- PATCH: partial update
- DELETE: remove data

---

## Q3. Difference between PUT and PATCH?

**Answer:**

- PUT replaces the full resource
- PATCH updates part of the resource

---

## Q4. What are common HTTP status codes?

**Answer:**

- 200 OK
- 201 Created
- 204 No Content
- 400 Bad Request
- 401 Unauthorized
- 403 Forbidden
- 404 Not Found
- 409 Conflict
- 422 Unprocessable Entity
- 500 Internal Server Error

---

## Q5. Difference between 401 and 403?

**Answer:**

- 401 means the user is not authenticated
- 403 means the user is authenticated but not allowed to access the resource

---

## Q6. How would you design an API for a job platform?

**Answer:**
Example endpoints:

- `POST /auth/register`
- `POST /auth/login`
- `GET /jobs`
- `GET /jobs/:id`
- `POST /jobs`
- `PUT /jobs/:id`
- `DELETE /jobs/:id`
- `POST /jobs/:id/apply`
- `GET /applications/me`

---

## Q7. How do you handle validation in APIs?

**Answer:**
I validate:

- required fields
- field format
- length constraints
- business rules
- duplicate checks
- authorization rules

Validation should happen before the business logic executes.

---

## Q8. What makes a good API?

**Answer:**
A good API is:

- consistent
- predictable
- well-named
- secure
- properly validated
- easy to document
- uses clear error responses

---

## Q9. How do you version APIs?

**Answer:**
Commonly by URL path such as:

- `/api/v1/jobs`

This helps preserve backward compatibility when the API changes.

---

## Q10. What is pagination and why is it important?

**Answer:**
Pagination limits how much data is returned per request.

It improves:

- performance
- response time
- frontend usability
- database efficiency

---

## Q11. What are query parameters used for?

**Answer:**
They are used for:

- filtering
- sorting
- pagination
- search

Example:
`GET /jobs?page=1&size=10&sort=createdAt,desc`

---

# 9. Authentication and Security

## Q1. What is authentication?

**Answer:**
Authentication is the process of verifying who the user is.

---

## Q2. What is authorization?

**Answer:**
Authorization is the process of deciding what an authenticated user is allowed to do.

---

## Q3. What is JWT?

**Answer:**
JWT stands for JSON Web Token. It is used to securely transmit user identity and claims between client and server.

It has:

- header
- payload
- signature

---

## Q4. How does JWT authentication work?

**Answer:**

1. User logs in with credentials
2. Server verifies credentials
3. Server issues a JWT
4. Client stores token
5. Client sends token in Authorization header
6. Server validates token on protected requests

---

## Q5. Where should JWT be stored?

**Answer:**
Safer options usually involve secure HTTP-only cookies. Storing tokens in localStorage is simpler but more exposed to XSS risks.

---

## Q6. What is hashing?

**Answer:**
Hashing is converting plaintext into a fixed-length string using a one-way algorithm.

Passwords should be hashed, never stored in plain text.

---

## Q7. Why should passwords be salted?

**Answer:**
Salting adds randomness before hashing so identical passwords do not produce identical hashes. It helps protect against rainbow table attacks.

---

## Q8. What is SQL Injection?

**Answer:**
SQL Injection happens when malicious input changes the intended SQL query.

**Prevention:**

- prepared statements
- ORM parameter binding
- input validation
- least privilege DB access

---

## Q9. What is XSS?

**Answer:**
Cross-Site Scripting happens when malicious scripts are injected into a page and run in another user's browser.

**Prevention:**

- sanitize input
- escape output
- content security policy
- avoid unsafe HTML rendering

---

## Q10. What is CSRF?

**Answer:**
Cross-Site Request Forgery tricks a logged-in user into making unwanted actions.

**Prevention:**

- CSRF tokens
- same-site cookies
- origin checks

---

## Q11. What is CORS?

**Answer:**
CORS controls which domains are allowed to access backend resources from browsers.

---

## Q12. How do you secure an API?

**Answer:**

- authentication
- authorization
- validation
- rate limiting
- HTTPS
- proper error handling
- logging and monitoring
- secure headers
- input sanitization
- secrets management

---

## Q13. What is rate limiting?

**Answer:**
Rate limiting restricts how many requests a client can make in a time period. It helps prevent abuse, brute force, and denial of service.

---

# 10. PostgreSQL and SQL

## Q1. What is PostgreSQL?

**Answer:**
PostgreSQL is a powerful open-source relational database known for reliability, standards compliance, and advanced SQL features.

---

## Q2. What is normalization?

**Answer:**
Normalization is organizing data to reduce redundancy and improve consistency.

---

## Q3. What is denormalization?

**Answer:**
Denormalization intentionally adds redundancy to improve read performance in some cases.

---

## Q4. What is a primary key?

**Answer:**
A primary key uniquely identifies each row in a table.

---

## Q5. What is a foreign key?

**Answer:**
A foreign key creates a relationship between tables and enforces referential integrity.

---

## Q6. Difference between INNER JOIN and LEFT JOIN?

**Answer:**

- INNER JOIN returns matching records from both tables
- LEFT JOIN returns all records from the left table and matching records from the right table

---

## Q7. What is an index?

**Answer:**
An index is a database structure that speeds up data retrieval.

**Tradeoff:** faster reads, slower writes, more storage.

---

## Q8. When should you add an index?

**Answer:**
Add indexes on:

- columns used in WHERE
- JOIN columns
- ORDER BY columns
- frequently searched columns

But avoid indexing everything because writes become more expensive.

---

## Q9. What is the difference between `WHERE` and `HAVING`?

**Answer:**

- `WHERE` filters rows before grouping
- `HAVING` filters grouped results after aggregation

---

## Q10. What is a transaction?

**Answer:**
A transaction is a group of database operations treated as one unit.

It follows ACID principles:

- Atomicity
- Consistency
- Isolation
- Durability

---

## Q11. What is `GROUP BY`?

**Answer:**
`GROUP BY` groups rows by one or more columns so aggregate functions can be applied.

---

## Q12. What is the difference between `DELETE`, `TRUNCATE`, and `DROP`?

**Answer:**

- `DELETE` removes selected rows
- `TRUNCATE` removes all rows quickly
- `DROP` removes the table itself

---

## Q13. Write a query to find the top 5 users who applied to the most jobs.

**Answer:**

```sql
SELECT user_id, COUNT(*) AS total_applications
FROM applications
GROUP BY user_id
ORDER BY total_applications DESC
LIMIT 5;
```

---

## Q14. Write a query to fetch all jobs with company name.

**Answer:**

```sql
SELECT j.id, j.title, c.name AS company_name
FROM jobs j
INNER JOIN companies c ON j.company_id = c.id;
```

---

## Q15. How would you design database tables for a job platform?

**Answer:**
Main tables:

- users
- companies
- jobs
- applications
- skills
- user_skills
- saved_jobs
- notifications

This supports users, employers, job posts, applications, and future expansion.

---

## Q16. How do you optimize slow queries?

**Answer:**

- inspect query plan
- add proper indexes
- avoid SELECT \*
- reduce joins if unnecessary
- paginate large queries
- normalize or denormalize where appropriate
- cache repeated data
- optimize filtering and sorting columns

---

# 11. Git and GitHub

## Q1. What is Git?

**Answer:**
Git is a distributed version control system used to track changes in code.

---

## Q2. What is GitHub?

**Answer:**
GitHub is a platform for hosting Git repositories, collaboration, pull requests, and code review.

---

## Q3. What is the difference between `git pull` and `git fetch`?

**Answer:**

- `git fetch` downloads changes but does not merge them
- `git pull` downloads and merges changes

---

## Q4. What is a branch?

**Answer:**
A branch is an isolated line of development for working on features or fixes without affecting the main codebase.

---

## Q5. What is a pull request?

**Answer:**
A pull request is a request to merge code changes into another branch after review.

---

## Q6. What is merge conflict?

**Answer:**
A merge conflict happens when Git cannot automatically resolve differences between branches.

---

## Q7. What is rebase?

**Answer:**
Rebase moves one branch on top of another to create a cleaner linear history.

---

## Q8. What is the difference between merge and rebase?

**Answer:**

- Merge preserves full history with a merge commit
- Rebase rewrites history for a cleaner sequence

---

## Q9. Why is commit message quality important?

**Answer:**
Good commit messages improve traceability, debugging, code reviews, and team understanding.

---

# 12. Testing and Debugging

## Q1. How do you debug a backend API issue?

**Answer:**
I usually:

1. reproduce the issue
2. inspect logs
3. check request input
4. verify service logic
5. inspect database query results
6. test edge cases
7. isolate the failing layer
8. fix and retest

---

## Q2. How do you debug a frontend issue?

**Answer:**
I inspect:

- browser console
- network tab
- component state
- props flow
- rendering conditions
- event handlers
- API response data

---

## Q3. Why might a React UI not update?

**Answer:**

- direct mutation of state
- wrong dependency array
- stale props
- memoization issue
- async state misunderstanding

---

## Q4. How do you debug a slow application?

**Answer:**
I check:

- frontend bundle size
- unnecessary re-renders
- API response times
- slow DB queries
- missing indexes
- large payloads
- cache misses
- network latency

---

## Q5. How would you handle a production bug?

**Answer:**

- assess severity
- reproduce if possible
- reduce user impact
- inspect logs and monitoring
- identify root cause
- patch safely
- verify fix
- write preventive tests
- document findings

---

## Q6. What is unit testing?

**Answer:**
Unit testing verifies small isolated pieces of code like functions or methods.

---

## Q7. What is integration testing?

**Answer:**
Integration testing checks whether multiple components work together correctly, such as API and database interaction.

---

## Q8. Why are tests important?

**Answer:**
Tests improve confidence, catch regressions, and support refactoring.

---

# 13. Performance and Scalability

## Q1. What is caching?

**Answer:**
Caching stores frequently accessed data temporarily so future requests can be served faster.

---

## Q2. Where can caching be used?

**Answer:**

- browser cache
- CDN
- server memory
- Redis
- database query caching in some architectures

---

## Q3. What is lazy loading?

**Answer:**
Lazy loading delays loading non-critical resources until needed.

**Examples:**

- images
- routes
- heavy components

---

## Q4. What is code splitting?

**Answer:**
Code splitting breaks JavaScript bundles into smaller chunks so only required code is loaded.

---

## Q5. What is CDN?

**Answer:**
A CDN is a distributed network of servers that delivers static content faster by serving it from locations closer to users.

---

## Q6. How do you scale a backend system?

**Answer:**

- make services stateless
- add load balancer
- scale horizontally
- use caching
- optimize queries
- offload background jobs
- use message queues if needed

---

## Q7. How do you scale a database?

**Answer:**

- indexing
- query optimization
- read replicas
- connection pooling
- partitioning or sharding at higher scale
- caching repeated reads

---

## Q8. What is connection pooling?

**Answer:**
Connection pooling reuses database connections instead of creating a new one for every request, improving performance.

---

## Q9. What is horizontal scaling vs vertical scaling?

**Answer:**

- Vertical scaling: making one server stronger
- Horizontal scaling: adding more servers

---

## Q10. What is a load balancer?

**Answer:**
A load balancer distributes incoming traffic across multiple servers to improve availability and performance.

---

# 14. Android and Mobile Integration Basics

## Q1. Why would Android experience matter help in a full stack role?

**Answer:**
Because many systems now serve both web and mobile users. Understanding mobile constraints helps in API design, performance, authentication, payload structure, offline support, and responsive UX decisions.

---

## Q2. What should backend APIs consider for mobile clients?

**Answer:**

- smaller payloads
- stable contracts
- pagination
- proper authentication
- offline retry behavior
- network efficiency
- version compatibility

---

## Q3. What is responsive web vs native mobile app?

**Answer:**

- Responsive web adapts the browser-based UI to device size
- Native mobile app is built specifically for the mobile platform and has deeper hardware integration

---

# 15. Cloud and Deployment Basics

## Q1. What is cloud computing?

**Answer:**
Cloud computing means using remote infrastructure and services over the internet instead of managing everything on local servers.

---

## Q2. What is the difference between IaaS, PaaS, and SaaS?

**Answer:**

- IaaS: infrastructure like virtual machines
- PaaS: platform to deploy apps
- SaaS: ready-to-use software over the web

---

## Q3. What is Docker?

**Answer:**
Docker packages an application and its dependencies into containers so it runs consistently across environments.

---

## Q4. What is CI/CD?

**Answer:**
CI/CD stands for Continuous Integration and Continuous Delivery or Deployment.

- CI: automatically build and test code
- CD: automatically deliver or deploy code

---

## Q5. What is environment configuration?

**Answer:**
Different environments like development, staging, and production have different configs such as database URLs, secrets, and service endpoints.

---

## Q6. Why should secrets not be hardcoded?

**Answer:**
Hardcoding secrets is insecure and makes rotation and environment management difficult.

---

## Q7. What is HTTPS?

**Answer:**
HTTPS encrypts communication between client and server using TLS, protecting data in transit.

---

# 16. Full Stack Project Questions

## Q1. How would you build a full stack job portal from scratch?

**Answer:**
I would break it into modules:

### Frontend

- authentication pages
- job list page
- job details page
- application form
- user dashboard
- admin or recruiter dashboard

### Backend

- user management
- job management
- application management
- notifications
- role-based access control

### Database

- users
- companies
- jobs
- applications
- saved jobs
- audit logs

Then I would define API contracts, validations, authorization rules, and scalable architecture.

---

## Q2. How do frontend and backend communicate?

**Answer:**
Usually through REST APIs over HTTP, where the frontend sends requests and receives JSON responses.

---

## Q3. What are common mistakes in full stack projects?

**Answer:**

- weak validation
- inconsistent API responses
- poor state management
- no loading or error handling
- insecure authentication
- bad DB indexing
- poor folder structure
- unclear ownership of business logic

---

## Q4. How do you keep full stack code maintainable?

**Answer:**

- modular structure
- clear naming
- separation of concerns
- reusable components
- consistent response format
- tests
- proper documentation
- reviewable pull requests

---

# 17. Critical System Design

# Design a Scalable Job Platform / HRIS-like System

## 17.1 Problem Statement

Design a platform where:

- users can register and log in
- recruiters can post jobs
- job seekers can browse and apply
- users can save jobs
- admins can manage users and content
- the system should scale to many users
- the system should remain secure and maintainable

---

## 17.2 Functional Requirements

### Core Features

1. User registration and login
2. Profile management
3. Recruiter creates and updates jobs
4. Job seeker browses jobs
5. Job seeker applies for jobs
6. Recruiter sees applicants
7. Search and filter jobs
8. Admin dashboard
9. Notifications
10. Role-based access

---

## 17.3 Non-Functional Requirements

1. Fast response time
2. High availability
3. Secure authentication
4. Scalable backend
5. Efficient database queries
6. Good user experience on mobile and desktop
7. Observability with logs and monitoring
8. Maintainable architecture

---

## 17.4 High-Level Architecture

```text
[ Client: Web / Mobile ]
          |
          v
[ Load Balancer / Reverse Proxy ]
          |
          v
[ App Servers: Next.js + Node.js API ]
          |
    -------------------------
    |           |           |
    v           v           v
[PostgreSQL] [Redis] [Object Storage]
    |
    v
[Read Replicas / Analytics / Search]
```

---

## 17.5 Frontend Architecture

### Stack

- React.js / Next.js
- UI library: Material UI or Ant Design
- Client-side state for UI
- API service layer for backend communication

### Frontend Modules

- auth
- jobs
- profile
- applications
- dashboard
- notifications
- admin panel

### Frontend Best Practices

- reusable components
- route-level code splitting
- lazy loading
- loading and error states
- form validation
- accessibility
- responsive layouts

---

## 17.6 Backend Architecture

### Core Modules

- Auth Service
- User Service
- Job Service
- Application Service
- Notification Service
- Admin Service

### Layered Structure

- routes
- controllers
- services
- repositories
- models
- middleware

### Why this structure?

It separates HTTP handling, business logic, and data access, which improves testability and maintainability.

---

## 17.7 Database Design

## Users Table

- id
- full_name
- email
- password_hash
- role
- phone
- created_at
- updated_at

## Companies Table

- id
- name
- website
- industry
- description

## Jobs Table

- id
- company_id
- title
- description
- location
- employment_type
- salary_min
- salary_max
- status
- created_by
- created_at
- updated_at

## Applications Table

- id
- job_id
- user_id
- resume_url
- cover_letter
- status
- applied_at

## Saved_Jobs Table

- id
- user_id
- job_id
- created_at

## Notifications Table

- id
- user_id
- type
- message
- is_read
- created_at

---

## 17.8 Database Relationships

- One company can have many jobs
- One user can apply to many jobs
- One job can have many applications
- One user can save many jobs
- One user can receive many notifications

---

## 17.9 Key API Endpoints

### Authentication

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/refresh`

### Users

- `GET /api/v1/users/me`
- `PUT /api/v1/users/me`

### Jobs

- `GET /api/v1/jobs`
- `GET /api/v1/jobs/:id`
- `POST /api/v1/jobs`
- `PUT /api/v1/jobs/:id`
- `DELETE /api/v1/jobs/:id`

### Applications

- `POST /api/v1/jobs/:id/apply`
- `GET /api/v1/applications/me`
- `GET /api/v1/jobs/:id/applications`

### Saved Jobs

- `POST /api/v1/jobs/:id/save`
- `DELETE /api/v1/jobs/:id/save`

---

## 17.10 Search and Filtering Design

### Filters

- keyword
- location
- job type
- salary range
- company
- experience level

### Approach

Start with PostgreSQL filtering and indexes.
If search becomes heavy and complex, move advanced search to Elasticsearch or OpenSearch.

---

## 17.11 Authentication Design

### Option

JWT-based auth with refresh token

### Flow

1. User logs in
2. Server validates credentials
3. Issue access token and refresh token
4. Client sends access token on requests
5. Refresh token used to obtain a new access token when expired

### Security Notes

- short-lived access token
- refresh token rotation
- secure cookie if web
- password hashing with bcrypt or Argon2
- role-based access control

---

## 17.12 Authorization Design

### Roles

- job seeker
- recruiter
- admin

### Examples

- only recruiter can create jobs
- only applicant can view own applications
- only admin can ban users or moderate platform data

---

## 17.13 Caching Strategy

Use Redis for:

- frequently accessed job lists
- company profile snapshots
- session or token blacklist if needed
- rate limiting counters

### Why?

It reduces database load and improves response time.

---

## 17.14 File Upload Strategy

For resumes or profile images:

- frontend uploads file
- backend validates file type and size
- store file in object storage
- save file URL or metadata in DB

### Why not store large files in database?

Because databases are not ideal for serving large binary objects at scale.

---

## 17.15 Performance Strategy

### Backend

- pagination on all large list endpoints
- indexed search columns
- connection pooling
- caching repeated queries
- avoid N+1 query problems

### Frontend

- code splitting
- image optimization
- lazy loading
- avoid unnecessary re-renders
- debounced search input

---

## 17.16 Handling High Traffic

### Suppose 10,000 concurrent users

Approach:

1. put app behind load balancer
2. run multiple stateless backend instances
3. use Redis cache
4. optimize DB indexes
5. separate read-heavy workloads
6. use read replicas if needed
7. move emails and notifications to background jobs

---

## 17.17 Background Jobs

Use background workers for:

- sending email
- generating reports
- processing large imports
- cleanup tasks
- notification dispatch

### Benefit

Prevents slow operations from blocking user-facing requests.

---

## 17.18 Observability and Monitoring

Track:

- request latency
- error rates
- CPU and memory usage
- DB query performance
- cache hit ratio

Use:

- structured logging
- metrics dashboard
- alerts
- trace IDs if possible

---

## 17.19 Failure Scenarios

## If database becomes slow

- inspect slow queries
- add indexes
- optimize joins
- cache repeated reads
- scale vertically first if needed
- add read replicas later

## If app server crashes

- use multiple instances
- auto restart
- health checks
- logs and alerts

## If file storage fails

- retry mechanism
- proper error feedback
- queue uploads if appropriate

---

## 17.20 Trade-Off Discussion

### Why PostgreSQL first?

Because it is reliable, relational, supports strong queries, and fits HR/job data very well.

### Why not microservices immediately?

For a mid-level product or startup stage, a well-structured modular monolith is usually simpler, faster to build, and easier to maintain. Microservices add operational complexity too early if scale does not yet demand them.

### When to move to microservices?

When clear domain boundaries, team scale, deployment needs, or traffic patterns justify the complexity.

---

## 17.21 Monolith vs Microservices

### Start with modular monolith

Because:

- easier deployment
- easier debugging
- fewer network boundaries
- faster development

### Move gradually if needed

Split services only when:

- team grows
- modules scale independently
- deployments need separation
- one module becomes bottleneck

---

## 17.22 Security Risks in This Platform

1. unauthorized access to applicant data
2. weak password storage
3. insecure file uploads
4. brute force login attempts
5. XSS in job descriptions or profiles
6. SQL injection in filters
7. broken access control on recruiter endpoints

### Mitigation

- hashing and salting
- secure auth tokens
- strict authorization
- sanitization
- rate limiting
- audit logs
- file validation

---

## 17.23 Interview-Ready System Design Summary

**Short version to say in interview:**

I would design the system as a modular monolith using Next.js on the frontend, Node.js with Express on the backend, PostgreSQL as the primary relational database, and Redis for caching and rate limiting. I would define separate modules for authentication, users, jobs, applications, and notifications. The system would use JWT-based authentication with role-based authorization for job seekers, recruiters, and admins. For scale, I would keep backend instances stateless so they can scale horizontally behind a load balancer. I would add pagination, indexing, caching, and background jobs for emails and notifications. For search, I would start with PostgreSQL and introduce Elasticsearch only if advanced search requirements or heavy scale demand it. I would also prioritize observability, secure file upload, and a responsive frontend experience.

---

# 18. Behavioral Questions

## Q1. Tell me about a challenging bug you solved.

**Answer Structure:**

- explain the issue
- mention impact
- describe how you investigated
- explain the root cause
- describe the fix
- mention the result

**Sample Answer:**
I faced a bug where data returned from an endpoint was inconsistent for some users. I first reproduced the issue and checked logs, request flow, and database records. After isolating the behavior, I found that the issue was caused by a mismatch between backend filtering logic and the expected UI state. I fixed the service logic, added validation for the edge case, and verified it with tests. After deployment, the issue was resolved and the data became consistent.

---

## Q2. How do you handle deadlines?

**Answer:**
I handle deadlines by breaking work into smaller parts, estimating carefully, identifying risks early, and communicating clearly if tradeoffs are needed. I focus on shipping the most important and correct version first, then improving incrementally if time allows.

---

## Q3. How do you handle team conflict?

**Answer:**
I try to understand the technical and communication sides of the disagreement first. Then I focus the discussion on facts, requirements, tradeoffs, and what is best for the product. I try not to make it personal and prefer collaboration over ego.

---

## Q4. Have you worked independently?

**Answer:**
Yes. I am comfortable taking ownership of a module, understanding requirements, designing the implementation, debugging issues, and delivering it. At the same time, I know when to ask questions or align with the team so I do not make isolated decisions that affect others.

---

## Q5. How do you learn a new technology quickly?

**Answer:**
I start from fundamentals, build a small working example, read official documentation, and connect the new technology to what I already know. I learn fastest by applying it to a practical problem instead of only reading theory.

---

# 19. Rapid Fire Questions

## Q1. What is DOM?

**Answer:** The Document Object Model is the browser representation of HTML as objects.

## Q2. What is immutability?

**Answer:** Not changing the original data directly; instead creating new copies with updates.

## Q3. What is a RESTful API?

**Answer:** An API following REST principles using resources and standard HTTP methods.

## Q4. What is JSON?

**Answer:** A lightweight format for exchanging structured data.

## Q5. What is `npm`?

**Answer:** Node Package Manager, used to install and manage JavaScript packages.

## Q6. What is CORS?

**Answer:** A browser security mechanism controlling cross-origin requests.

## Q7. What is ORM?

**Answer:** Object Relational Mapping, which helps interact with the database using objects instead of raw SQL.

## Q8. What is normalization?

**Answer:** Organizing database data to reduce redundancy.

## Q9. What is pagination?

**Answer:** Dividing data into smaller pages instead of returning everything at once.

## Q10. What is rate limiting?

**Answer:** Restricting request count over time to prevent abuse.

## Q11. What is a token refresh flow?

**Answer:** Using a refresh token to obtain a new access token after the old one expires.

## Q12. What is responsive layout?

**Answer:** A layout that adapts to different screen sizes.

## Q13. What is SEO?

**Answer:** Search Engine Optimization, improving visibility in search engines.

## Q14. What is lazy loading?

**Answer:** Loading resources only when needed.

## Q15. What is a middleware chain?

**Answer:** A sequence of middleware functions processing a request before final handling.

---

# 20. Final Revision Checklist

## JavaScript

- scopes
- closures
- hoisting
- promises
- async/await
- event loop
- array methods
- debounce/throttle

## React

- props and state
- hooks
- re-renders
- optimization
- forms
- context
- keys
- lifecycle with `useEffect`

## Next.js

- SSR
- SSG
- CSR
- API routes
- routing
- hydration
- SEO benefits

## Backend

- Node.js basics
- Express middleware
- error handling
- API structure
- validation
- pagination
- logging

## Security

- authentication vs authorization
- JWT
- password hashing
- SQL injection
- XSS
- CSRF
- CORS
- rate limiting

## Database

- joins
- indexes
- transactions
- normalization
- query optimization
- schema design

## UI/UX

- responsive design
- mobile first
- accessibility
- form UX
- component libraries

## System Design

- architecture
- modules
- DB schema
- scaling
- caching
- search
- observability
- tradeoffs

---

# Final Interview Tips

1. Do not memorize word by word. Understand and speak naturally.
2. In technical questions, explain both concept and practical use.
3. In system design, always mention:
   - requirements
   - architecture
   - database
   - scaling
   - security
   - tradeoffs

4. If you do not know something fully, say what you know clearly instead of guessing wildly.
5. Think like an engineer, not just like an exam candidate.

---

# 30 Most Important Questions to Practice Out Loud

1. Tell me about yourself.
2. Why this company?
3. What is closure?
4. Explain event loop.
5. Difference between `let` and `const`.
6. What causes React re-render?
7. Explain `useEffect`.
8. Difference between `useMemo` and `useCallback`.
9. SSR vs SSG vs CSR.
10. Why Next.js?
11. How does Node.js handle concurrency?
12. What is middleware?
13. How do you design a REST API?
14. PUT vs PATCH.
15. 401 vs 403.
16. How does JWT work?
17. How do you secure an API?
18. What is SQL injection?
19. INNER JOIN vs LEFT JOIN.
20. What is indexing?
21. How do you optimize a slow query?
22. What is responsive design?
23. Flexbox vs Grid.
24. How do you debug a production issue?
25. What is caching?
26. How do you scale backend services?
27. How do you scale a database?
28. Design a job platform.
29. Why are you fit for this role?
30. Tell me about a bug you solved.

---

# Short Mock Closing Answer

## Why should we hire you?

**Answer:**
You should hire me because I bring structured problem solving, strong backend fundamentals, and a growing full stack mindset. I care about clean code, secure systems, and user-focused implementation. I can contribute technically from day one, learn fast where needed, and work responsibly with both product and engineering teams. I am not just interested in writing code, I am interested in building reliable products that create real value.

---
