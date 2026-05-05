# Microservices Architecture Interview Questions

A complete pedagogical guide to microservices. Each question explains the concept in plain language and pairs it with a concrete code example, schema, or diagram.

---

## How to Use This Guide

Examples use HTTP/REST, gRPC, and message brokers because those are the most common building blocks. Code samples are in Node.js, but every concept maps to any language.

---

## 1. Monolith vs Microservices

## Q1. Define monolith and microservices.

**Answer:**

A **monolith** is one deployable application: one codebase, one process, one database. A **microservices** architecture is many small services, each with its own codebase, process, and database, talking to each other over the network.

```text
Monolith:                       Microservices:
+-------------------+           +--------+   +--------+   +--------+
|  Web + API +      |           | Users  |   | Orders |   | Email  |
|  Business logic + |           +--------+   +--------+   +--------+
|  Background jobs  |               |            |            |
+-------------------+               v            v            v
       |                          users_db   orders_db   email_log
       v
   one_db
```

## Q2. Compare monolith vs microservices.

**Answer:**

| Aspect | Monolith | Microservices |
| --- | --- | --- |
| Deploy | One unit | Many independent units |
| Scaling | Whole app | Per service |
| Database | Shared | One per service |
| Team coupling | High | Low |
| Local dev | Easy | Harder (mock, compose) |
| Ops complexity | Low | High |
| Failure mode | Crash takes everything | Partial degradation |
| Refactoring | Compiler helps | Versioned APIs |

A monolith is faster to start. Microservices pay off only at scale, in team size and traffic.

## Q3. When should you choose a monolith?

**Answer:**

- The team is small (less than 20 engineers).
- The product is still finding fit; requirements change weekly.
- You don't have ops expertise (Kubernetes, observability stack).
- Throughput is modest.

A well-modularized monolith ("modular monolith") covers most needs for years.

## Q4. When should you choose microservices?

**Answer:**

- Multiple teams need to deploy independently without stepping on each other.
- Different parts of the system have different scaling profiles (e.g. search needs 50 servers, billing needs 2).
- Different parts have different reliability requirements.
- The codebase has grown so big that a single deploy is risky.

Microservices solve organizational and scaling problems, not technical elegance.

## Q5. What is a "distributed monolith" and why is it bad?

**Answer:**

A distributed monolith is microservices that must be deployed together because they share a database, share a release cycle, or call each other synchronously in tight loops. You get the operational complexity of microservices and the coupling of a monolith.

Tell-tale signs:

- Service A's deployment requires service B to deploy first.
- Two services share a table in the same database.
- A request fans out into 10 synchronous calls.

Fix by drawing real boundaries (own data, own deploy) or merging the services back into a monolith.

---

## 2. Service Boundaries and Decomposition

## Q6. How do you decide where to draw service boundaries?

**Answer:**

Use Domain-Driven Design (DDD): identify **bounded contexts** in your business domain. A bounded context is a chunk of the business with its own consistent language and rules. Each bounded context becomes one service.

For an e-commerce site:

- Catalog (products, categories)
- Inventory (stock levels)
- Pricing (rules, discounts)
- Cart
- Orders
- Payments
- Shipping
- Notifications

Each has different stakeholders, different rates of change, and different data. They are good service candidates.

## Q7. What is a bounded context?

**Answer:**

A bounded context is a logical boundary inside which a domain model is consistent. The same word can mean different things in different contexts. "Customer" in Sales is a lead with contact info; "Customer" in Billing is an account with invoices. Each context owns its own definition.

## Q8. What are aggregates and why do they matter for service design?

**Answer:**

An aggregate is a cluster of objects that must change together transactionally. The aggregate root is the entry point and enforces invariants. An order with its line items is an aggregate; the line items only exist because the order exists.

Aggregates fit naturally inside one service because cross-service transactions are hard. If two aggregates always change together, they probably belong in the same service.

## Q9. How granular should services be?

**Answer:**

A common heuristic: a service should be small enough that one team can own it but large enough that a single business operation usually completes within it.

Anti-patterns:

- **Nano-services**: a service per function (e.g. "calculate-discount"). High network overhead, no clear ownership.
- **Mega-services**: one service for half the business. Becomes a monolith with extra steps.

Aim for "one bounded context per service" and adjust based on team size.

## Q10. How do you migrate from monolith to microservices?

**Answer:**

The **strangler fig pattern**: route new functionality to new services while the monolith continues to handle the rest. Slowly carve out features until the monolith is empty.

```text
Step 1:        Step 2:               Step 3:
[Monolith]     [Gateway]             [Gateway]
               /        \             /  |  \
       [Monolith]    [New svc]   [New1][New2][New3]
```

Don't try a big-bang rewrite; the monolith keeps shipping while you migrate.

---

## 3. Inter-Service Communication

## Q11. What are the communication options?

**Answer:**

| Style | Examples |
| --- | --- |
| Synchronous request-reply | REST, gRPC, GraphQL |
| Asynchronous messaging | RabbitMQ, Kafka, SQS |
| Event-driven | Kafka topics, event bus |
| Streaming | gRPC streams, WebSocket |

A real system uses several. Synchronous calls for things that need an immediate answer; async events for everything else.

## Q12. Synchronous vs asynchronous — when to use which?

**Answer:**

| Sync (HTTP/gRPC) | Async (queue/events) |
| --- | --- |
| Need a result now | Fire-and-forget |
| Strong consistency required | Eventual consistency OK |
| Caller can wait | Caller shouldn't wait |
| Few callers | Many callers (broadcast) |

Default to async wherever possible. Sync calls couple services in time and propagate failures.

```js
// Sync (blocks caller)
const user = await fetch(`${USER_SVC}/users/${id}`).then(r => r.json());

// Async (fire-and-forget event)
await broker.publish('user.created', { id, email });
```

## Q13. REST vs gRPC?

**Answer:**

| | REST/JSON | gRPC |
| --- | --- | --- |
| Wire format | Text JSON | Binary protobuf |
| Schema | OpenAPI (optional) | Proto file (required) |
| Performance | OK | 5-10x faster |
| Browser support | Native | Needs gRPC-Web |
| Streaming | SSE only | Native bidi |
| Tooling for humans | curl, Postman | grpcurl |

Use gRPC for service-to-service communication where performance matters and both sides are yours. Use REST for public APIs and browser clients.

```proto
// orders.proto
service Orders {
  rpc CreateOrder (CreateOrderReq) returns (Order);
  rpc StreamOrders (stream OrderUpdate) returns (stream OrderAck);
}
```

## Q14. What is GraphQL federation?

**Answer:**

Federation lets multiple services contribute to a single GraphQL schema. Each service owns part of the schema; a gateway stitches them at query time.

```graphql
# users service
type User @key(fields: "id") {
  id: ID!
  name: String
}

# orders service extends User
extend type User @key(fields: "id") {
  id: ID! @external
  orders: [Order!]!
}
```

The client queries `user.orders.items` as if it were one graph; the gateway routes to the right services.

---

## 4. API Gateway and BFF

## Q15. What is an API gateway?

**Answer:**

An API gateway is a single entry point in front of all services. It handles cross-cutting concerns: TLS termination, auth, rate limiting, request routing, request/response shaping, and observability.

```text
[mobile] -\
[web]    -- [Gateway] -- [users] [orders] [payments]
[partner]-/
```

Without a gateway, every service has to redo the same plumbing.

## Q16. What is the BFF pattern?

**Answer:**

Backend For Frontend: a separate gateway per client type (mobile, web, partner API). Each BFF tailors responses to one client's needs without polluting backend services.

```text
[iOS]    -> [iOS BFF]    -> backend services
[Web]    -> [Web BFF]    -> backend services
[Partner]-> [Partner API]-> backend services
```

Mobile gets compact responses tuned for its screen; web gets richer payloads. Backend services stay generic.

## Q17. Should you put business logic in the API gateway?

**Answer:**

No. Keep gateways "smart pipes": auth, routing, rate limiting, response shaping. Business logic in the gateway becomes a single point of coupling and a deployment bottleneck. Logic belongs in services.

---

## 5. Service Discovery and Load Balancing

## Q18. What is service discovery?

**Answer:**

Services come and go (autoscaling, deployments, failures). Service discovery is how a caller finds the current set of healthy instances.

- **Server-side discovery**: caller sends to a load balancer; LB knows the instances.
- **Client-side discovery**: caller queries a registry (Consul, etcd) and picks an instance.

In Kubernetes, this is built in: a `Service` is a DNS name that resolves to healthy pods.

## Q19. L4 vs L7 load balancing?

**Answer:**

- **L4** (TCP/UDP): routes by IP and port. Fast, simple, doesn't see headers.
- **L7** (HTTP): inspects path, headers, cookies. Can do path-based routing, header-based routing, retries.

L7 for service-to-service routing where you care about the request; L4 for raw TCP traffic.

## Q20. Client-side load balancing — when?

**Answer:**

When you want to avoid an extra hop (no L7 LB between client and server) and when you want fancy strategies like outlier detection or weighted routing. gRPC and service meshes (Linkerd, Istio) do this by default.

---

## 6. Resilience Patterns

## Q21. What is the circuit breaker pattern?

**Answer:**

When a downstream service is failing, don't keep hammering it. A circuit breaker counts failures and "opens" after a threshold; subsequent calls fail fast without hitting the broken service. After a cooldown, it goes "half-open" and tests once; if that succeeds, it closes again.

```text
[CLOSED]  --(failures > threshold)--> [OPEN]
                                        |
                                  (cooldown elapsed)
                                        v
                                   [HALF-OPEN]
                                    /         \
                          (success)             (failure)
                              v                       v
                          [CLOSED]                  [OPEN]
```

```js
const CircuitBreaker = require('opossum');

const breaker = new CircuitBreaker(callPaymentService, {
  timeout: 3000,
  errorThresholdPercentage: 50,
  resetTimeout: 10000,
});

breaker.fallback(() => ({ status: 'queued' }));
const result = await breaker.fire(order);
```

## Q22. Why are timeouts critical?

**Answer:**

Without an explicit timeout, a network call can hang for minutes (TCP defaults are huge). Hung calls accumulate, threads exhaust, and the calling service falls over too. Set timeouts on every external call. A common rule: shorter than the calling service's own timeout, with retry.

```js
fetch(url, { signal: AbortSignal.timeout(2000) });
```

## Q23. What is retry, and what's the catch?

**Answer:**

If a call fails transiently, retrying often succeeds. The catches:

1. Retries can amplify load during an outage (a "retry storm"). Use exponential backoff with jitter.
2. Retrying non-idempotent calls causes duplicates. Make handlers idempotent or use idempotency keys.
3. Limit retries; don't retry forever.

```js
async function withRetry(fn, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try { return await fn(); }
    catch (e) {
      if (i === retries - 1) throw e;
      await sleep(Math.min(2 ** i * 100 + Math.random() * 100, 5000));
    }
  }
}
```

## Q24. What is the bulkhead pattern?

**Answer:**

Isolate resources so a problem in one area doesn't drown the whole service. Like ship bulkheads: one compartment floods but the ship stays afloat.

Examples:

- Separate thread pools per downstream service.
- Separate connection pools per database.
- Per-tenant request queues.

If service B is slow, only the calls to B back up; calls to service C still go through.

## Q25. What is failover / fallback?

**Answer:**

When the primary fails, switch to a secondary or a degraded mode.

```js
async function getRecommendations(userId) {
  try {
    return await mlService.recommend(userId);
  } catch {
    return defaultPopularItems(); // graceful degradation
  }
}
```

A page that shows generic recommendations is better than no page at all.

## Q26. What is rate limiting and where do you apply it?

**Answer:**

Rate limiting bounds requests per client per time window. Apply at multiple layers:

- **Edge / CDN**: stop floods before they reach you.
- **API gateway**: per API key.
- **Per service**: defend against internal misbehavior.
- **Per user**: prevent one user from monopolizing.

Common algorithms: token bucket, leaky bucket, fixed window, sliding window.

```text
Token bucket: bucket fills at R tokens/sec, max B tokens.
Each request consumes 1 token. No tokens? reject.
```

---

## 7. Sagas and Distributed Workflows

## Q27. Why can't you use 2PC across microservices?

**Answer:**

Two-phase commit (2PC) needs all participants to vote, then commit together. It requires:

- A coordinator that doesn't fail.
- All participants holding locks until commit.
- Synchronous availability of all of them.

In microservices, a downstream service may be unavailable for minutes. Holding locks across services kills throughput. 2PC is impractical for cross-service business workflows.

## Q28. What is a saga?

**Answer:**

A saga is a long-running business transaction split into local steps in each service. Each step has a compensating step that undoes it if a later step fails.

```text
Place order:
  1. Reserve inventory     (compensate: release inventory)
  2. Charge payment        (compensate: refund)
  3. Create shipment       (compensate: cancel shipment)

If step 3 fails, run compensations 2 and 1 in reverse.
```

## Q29. Orchestration vs choreography sagas?

**Answer:**

- **Orchestration**: a central orchestrator tells each service what to do.
- **Choreography**: each service publishes events; other services react.

```text
Orchestration:
[Orchestrator] -> calls Inventory
              -> on success, calls Payment
              -> on success, calls Shipping
              -> on failure, calls compensations

Choreography:
Order created -> Inventory reserves -> publishes "reserved"
              -> Payment charges    -> publishes "paid"
              -> Shipping ships     -> publishes "shipped"
```

| | Orchestration | Choreography |
| --- | --- | --- |
| Logic location | Central, easy to follow | Spread across services |
| Coupling | Orchestrator coupled to all | Services depend on events |
| Visibility | Easy | Harder, need tracing |
| Evolution | Change orchestrator | Change publish/subscribe |

Orchestration is easier to start with; choreography scales to more autonomous teams.

## Q30. How do you implement compensations?

**Answer:**

For each forward step, define an inverse. The compensation must be idempotent (you may retry it) and must work even if the forward step partially executed.

```js
async function compensateReserveInventory(orderId) {
  await inventoryService.releaseReservation(orderId);
  // safe to call repeatedly: returns OK even if already released
}
```

Some operations can't be inverted exactly (e.g. an email already sent). Use logical compensations (a retraction email) or design to avoid them.

## Q31. What's the role of an outbox in saga steps?

**Answer:**

Each saga step needs to atomically (a) update local state and (b) emit an event for the next step. The outbox pattern makes this safe: write the state change and the event in the same DB transaction; a separate process publishes the event to the broker.

---

## 8. Event-Driven Architecture, CQRS, Event Sourcing

## Q32. What is event-driven architecture?

**Answer:**

Services communicate by publishing events ("something happened") rather than calling each other. Other services subscribe to the events they care about.

```text
[Orders]   --"order.created"--> [Email]    (sends confirmation)
                              -> [Analytics] (records purchase)
                              -> [Inventory] (decrements stock)
```

Producer doesn't know who consumes. Adding a new consumer doesn't change the producer.

## Q33. Event vs command?

**Answer:**

- An **event** is "something happened" — past tense, broadcast to whoever cares. `OrderPlaced`.
- A **command** is "do this" — directed, with an expected outcome. `PlaceOrder`.

Events flow outward; commands flow inward. Mixing them creates confusion. Naming is the simplest way to keep them straight.

## Q34. What is CQRS?

**Answer:**

Command Query Responsibility Segregation: split the write model from the read model. The write side validates and applies changes; the read side is optimized for queries (often denormalized, even a different database).

```text
Write side:                 Read side:
[Command] -> [Aggregate]    [Query] -> [Materialized view]
                |
              emits event
                |
                +--> updates read view
```

Useful when read and write workloads differ wildly. Adds complexity, so use sparingly.

## Q35. What is event sourcing?

**Answer:**

Store the sequence of events that led to current state, instead of just the current state. Replay events to rebuild state.

```text
Events for Order #42:
  OrderPlaced       (id=42, total=100)
  ItemAdded         (sku=A, qty=2)
  CouponApplied     (code=SAVE10, discount=10)
  OrderShipped      (tracking=ABC)

Current state is the fold of all events.
```

Pros: full audit log, time travel, easy to add new read models. Cons: schema evolution is hard, queries require materialized views.

## Q36. CQRS without event sourcing — does that make sense?

**Answer:**

Yes. CQRS just means separate read and write models; you can use a normal SQL store for both, with read models updated via triggers or events. Event sourcing adds complexity that you only want when you genuinely need an audit log or time travel.

---

## 9. Data Consistency Patterns

## Q37. Why is "service per database" a rule?

**Answer:**

If two services share a database, they share a release cycle (schema changes break both), they couple at the data layer (one's queries affect the other's perf), and you've recreated the monolith. Each service must own its data; other services access it only through the service's API.

## Q38. What's the dual-write problem?

**Answer:**

When a service must update two systems (e.g. its DB and Kafka) and the second write fails after the first succeeds, the systems diverge.

```text
TX BEGIN
  INSERT INTO orders ...        # success
  COMMIT                        # success
publish 'order.created' to kafka  # fails
=> Order exists, no event published, downstream services don't know
```

Naive try/catch doesn't fix it; even retries can fail mid-flight.

## Q39. What is the transactional outbox pattern?

**Answer:**

Write the event to an `outbox` table in the same transaction as the data change. A relay process reads the outbox and publishes to the broker.

```sql
BEGIN;
  INSERT INTO orders (...) VALUES (...);
  INSERT INTO outbox (event_type, payload) VALUES ('OrderCreated', '{...}');
COMMIT;
```

The relay can be a polling worker or a CDC tool like Debezium reading the WAL. The event publishes if and only if the data change committed.

## Q40. What is the inbox pattern?

**Answer:**

The mirror of outbox on the consumer side. Before processing an event, write it to an `inbox` table; check the inbox for duplicates. This makes consumers idempotent against retries from the broker.

## Q41. What is Change Data Capture (CDC)?

**Answer:**

Mirror database changes (inserts, updates, deletes) into a stream by tailing the database's transaction log. Debezium for Postgres/MySQL/Mongo is the standard tool. Other services consume the change stream instead of querying the DB.

```text
Postgres WAL --> Debezium --> Kafka topic --> consumers
```

CDC is the engine behind the outbox pattern in production.

## Q42. What is eventual consistency?

**Answer:**

After a change, the system reaches a consistent state eventually, not immediately. Services see updates with some delay (milliseconds to seconds).

```text
T0: User updates email at user-service. user-db reflects new email.
T0+50ms: order-service still shows old email in cached view.
T0+200ms: event arrives, order-service updates its cache.
T0+200ms onward: every service shows new email.
```

Most distributed systems are eventually consistent. UX needs to handle the gap.

## Q43. What patterns help with read-after-write consistency?

**Answer:**

- **Read your own writes** by routing the next read to the primary or to a session-pinned replica.
- **Synchronous wait**: write returns only after the event has been applied to the relevant read view.
- **Optimistic updates** in the UI: show the change immediately, reconcile when the server confirms.

---

## 10. Idempotency and Exactly-Once

## Q44. Why is idempotency the most important property in distributed systems?

**Answer:**

Networks fail. Retries are inevitable. If a handler is idempotent (running it twice is the same as running it once), retries are safe. If not, retries cause duplicate orders, double-charges, double-emails.

```js
// Not idempotent: each call decrements stock
function reserveStock(sku, qty) {
  db.update('UPDATE inventory SET qty=qty-? WHERE sku=?', qty, sku);
}

// Idempotent: keyed by orderId, second call is a no-op
function reserveStock(orderId, sku, qty) {
  if (db.exists('reservations', { orderId })) return;
  db.transaction(() => {
    db.insert('reservations', { orderId, sku, qty });
    db.update('UPDATE inventory SET qty=qty-? WHERE sku=?', qty, sku);
  });
}
```

## Q45. How do you make non-idempotent operations idempotent?

**Answer:**

Pass an idempotency key from the caller; store it server-side and reject duplicates.

```http
POST /payments
Idempotency-Key: 9f2b3e7a-...
{ "amount": 100 }
```

```js
async function charge(req) {
  const seen = await db.findIdempotency(req.idempotencyKey);
  if (seen) return seen.response;
  const resp = await stripe.charge(req);
  await db.insertIdempotency(req.idempotencyKey, resp);
  return resp;
}
```

Stripe, AWS, Square — every serious API supports this.

## Q46. Is exactly-once delivery possible?

**Answer:**

Across networks: no, you can only choose at-most-once or at-least-once. You can however achieve **exactly-once processing** by combining at-least-once delivery with an idempotent consumer. The broker may deliver a message twice; the consumer detects duplicates and treats them as one.

---

## 11. Observability — Logging, Tracing, Metrics

## Q47. What are the three pillars of observability?

**Answer:**

| Pillar | Question it answers |
| --- | --- |
| Logs | What happened at this point in time? |
| Metrics | How is the system behaving over time? |
| Traces | What was the path of this request? |

You need all three. Logs give detail, metrics give aggregate, traces tie them across services.

## Q48. What is distributed tracing?

**Answer:**

Each request gets a unique trace ID. Each step gets a span. Spans link to a parent span across services, building a tree.

```text
trace_id=abc
  span: gateway (200ms)
    span: orders.create (180ms)
      span: payments.charge (90ms)
      span: inventory.reserve (40ms)
```

Tools: OpenTelemetry (instrumentation), Jaeger / Tempo / Zipkin (storage).

```js
const { trace } = require('@opentelemetry/api');
const tracer = trace.getTracer('orders');

const span = tracer.startSpan('createOrder');
try {
  await doWork();
} finally {
  span.end();
}
```

## Q49. Why does context propagation matter?

**Answer:**

Without propagating the trace ID across service calls, each service starts a new trace and you can't connect them. Every outgoing request must carry the trace context (usually in a `traceparent` header).

```http
GET /users/42
traceparent: 00-abc123...-def456...-01
```

Libraries with auto-instrumentation handle this; for custom transports you have to pass it explicitly.

## Q50. What are good metrics for a service?

**Answer:**

The "RED" method:

- **Rate**: requests per second.
- **Errors**: error rate.
- **Duration**: latency p50, p95, p99.

For backend resources, the "USE" method:

- **Utilization**: how busy is the resource.
- **Saturation**: queue or wait length.
- **Errors**: hardware/system errors.

Track per endpoint, per dependency, and overall.

## Q51. What is structured logging?

**Answer:**

Logs as JSON with consistent fields (`timestamp`, `level`, `service`, `trace_id`, `user_id`, `event`) instead of human-only strings.

```json
{"ts":"2025-01-01T00:00:00Z","level":"info","service":"orders","trace_id":"abc","event":"order.created","order_id":42}
```

Easy to search, aggregate, alert on. Use a log shipper (Vector, Fluent Bit) to send to Elasticsearch / Loki.

---

## 12. Testing Microservices

## Q52. What's the testing pyramid for microservices?

**Answer:**

```text
                  /\          End-to-end (few)
                 /  \
                /----\         Contract / integration (more)
               /      \
              /--------\       Component / service-level (many)
             /          \
            /------------\     Unit (most)
```

Don't try to E2E everything; the cost is huge and tests are flaky. Lean on unit and contract tests.

## Q53. What are consumer-driven contract tests?

**Answer:**

The consumer defines a "contract" of the API it expects (e.g. via Pact). The provider runs the contract as a test in CI; if the provider breaks the contract, the test fails.

```js
// Consumer test: defines the expected interaction
provider.given('user 42 exists')
  .uponReceiving('a request for user 42')
  .withRequest({ method: 'GET', path: '/users/42' })
  .willRespondWith({ status: 200, body: { id: 42 } });
```

This catches breaking API changes without needing to deploy both services.

## Q54. How do you test message-driven services?

**Answer:**

Use a real broker in test, or a test double:

- Spin up RabbitMQ/Kafka in Docker for integration tests.
- Use library mocks (`testcontainers`) for fast cleanup.
- For unit tests, treat the publish call as a side effect and assert on it.

Test both happy path and failure paths (broker down, malformed payload, replay).

## Q55. How do you test for resilience?

**Answer:**

- **Chaos testing**: kill instances, inject latency, drop packets (Chaos Mesh, Gremlin, Toxiproxy).
- **Game days**: scheduled exercises where the team responds to a simulated incident.
- **Load tests** that go past expected peak.

If you've never tested a failure, you don't know how it'll behave.

---

## 13. API Versioning and Evolution

## Q56. Strategies for versioning APIs?

**Answer:**

| Strategy | Example |
| --- | --- |
| URL versioning | `/v1/users`, `/v2/users` |
| Header versioning | `Accept: application/vnd.app.v2+json` |
| Schema versioning | Add fields, never remove |

URL versioning is most common because it's explicit and easy to debug. Schema-additive evolution is what you actually do day-to-day.

## Q57. What changes are backward-compatible?

**Answer:**

Safe:

- Add optional fields.
- Add new endpoints.
- Add new event types.

Unsafe:

- Remove or rename a field.
- Tighten validation.
- Change a field's type or semantics.

When you must break compatibility, run v1 and v2 in parallel and migrate consumers before retiring v1.

## Q58. How do you evolve an event schema?

**Answer:**

Same rules: additive only. Use a schema registry (Avro/Protobuf with `BACKWARD` compatibility) to enforce. For real breaking changes, publish to a new topic in parallel:

```text
Old: orders.created.v1
New: orders.created.v2
```

Run them in parallel until consumers migrate.

---

## 14. Deployment and Release

## Q59. Independent deploys — why is it the headline benefit?

**Answer:**

Independent deploys let teams move at different speeds. Without it, every team's deploy queue is everyone else's. With it, a hotfix in service A doesn't wait for service B's stalled feature.

This is the main reason microservices exist organizationally.

## Q60. What deployment patterns are common?

**Answer:**

- **Rolling**: replace instances one at a time. Default in Kubernetes.
- **Blue-green**: run two identical environments; swap traffic atomically. Easy rollback.
- **Canary**: route a small % of traffic to new version; ramp up if healthy.
- **Shadow**: send copies of real traffic to the new version without responding to users.

Canary is the safest for risky changes.

```yaml
# Canary with Argo Rollouts
strategy:
  canary:
    steps:
      - setWeight: 10
      - pause: { duration: 5m }
      - setWeight: 50
      - pause: { duration: 10m }
```

## Q61. What is a feature flag?

**Answer:**

A runtime toggle for a code path. Deploy code dark, enable per user/percentage/region without redeploying.

```js
if (await flags.enabled('new-checkout', user)) {
  return newCheckout(user);
}
return oldCheckout(user);
```

Lets you decouple deploy from release, test in production safely, and roll back without redeploying.

## Q62. Polyglot persistence — should each service really pick its own DB?

**Answer:**

In theory yes; in practice, ops cost is real. Most teams standardize on one or two databases (Postgres + Redis, say) and only branch out for genuine needs (e.g. Elasticsearch for search). "Best tool for the job" is true; "every team picks a different tool" is exhausting.

---

## 15. Service Mesh

## Q63. What is a service mesh?

**Answer:**

A sidecar proxy (Envoy) runs next to every service instance, intercepting all traffic in and out. The mesh handles mTLS, retries, timeouts, circuit breaking, traffic shifting, and observability — uniformly across services in any language.

```text
[svc A] - [envoy A] <--mTLS--> [envoy B] - [svc B]
```

The application doesn't know about the mesh; it just connects to localhost. Examples: Istio, Linkerd, Consul Connect.

## Q64. When should you adopt a service mesh?

**Answer:**

- You have many services in many languages and want uniform networking.
- You need mTLS between services.
- You want canary/traffic-splitting at the network layer without code changes.
- You're comfortable operating Envoy.

Don't adopt a mesh "because Netflix does." It's powerful but adds significant operational complexity.

## Q65. Service mesh vs API gateway?

**Answer:**

| | API gateway | Service mesh |
| --- | --- | --- |
| Traffic | North-south (in/out) | East-west (service-to-service) |
| Concerns | Auth, rate limit, public API | mTLS, retries, observability |
| Deployment | One per environment | Sidecar per pod |

Real systems use both: gateway at the edge, mesh inside.

---

## 16. Anti-Patterns and Pitfalls

## Q66. Common microservices anti-patterns.

**Answer:**

- **Distributed monolith** (Q5).
- **Chatty services**: one request fans out to dozens of synchronous calls.
- **Shared database**.
- **Nano-services**: too granular.
- **Inconsistent error handling**: each service returns errors differently.
- **Manual versioning** that breaks on every deploy.
- **No observability**: you find out about outages from customers.
- **Mock-heavy testing**: tests pass but real wiring breaks.

## Q67. What are "the fallacies of distributed computing"?

**Answer:**

Eight assumptions every newcomer makes that turn out false:

1. The network is reliable.
2. Latency is zero.
3. Bandwidth is infinite.
4. The network is secure.
5. Topology doesn't change.
6. There is one administrator.
7. Transport cost is zero.
8. The network is homogeneous.

Every microservices issue can be traced to violating one of these.

## Q68. What's the "two-pizza team" rule?

**Answer:**

Amazon's heuristic: a team should be small enough to feed with two pizzas (about 6-10 people). Smaller teams move faster, communicate easily, and own a service end to end.

## Q69. Why is "distributed transactions are hard" a recurring theme?

**Answer:**

Because cross-service consistency is fundamentally a hard problem and most attempts to make it look easy (2PC, generic frameworks) hide failure modes that bite later. Sagas, compensations, and idempotency are the honest answer; nothing makes them disappear.

---

## 17. When NOT to Use Microservices

## Q70. List concrete scenarios where microservices are the wrong choice.

**Answer:**

- New product, small team, requirements still moving.
- Single team, single deploy cadence.
- Latency-critical system (network hops matter).
- Tightly coupled domain that doesn't decompose cleanly.
- Limited ops capacity.

In any of these, a modular monolith is faster, cheaper, and easier to evolve.

## Q71. What's the right starting point for a new product?

**Answer:**

A modular monolith with clean module boundaries. When a module clearly grows beyond the rest (different scaling, different team, different release cadence), extract it into a service. By the time you have 5 services, you'll know your domain well enough to draw the rest of the boundaries correctly.

## Q72. Sensible defaults summary.

**Answer:**

- One bounded context per service; one database per service.
- Async events for cross-service communication; sync only when you need an answer now.
- Outbox pattern for reliable event publishing.
- Idempotent consumers, idempotency keys for client-facing APIs.
- Timeouts, retries with backoff, circuit breakers on every external call.
- Distributed tracing from day one.
- Schema additive; breaking changes go through a v2 in parallel.
- Independent deploys, canary releases, feature flags.
