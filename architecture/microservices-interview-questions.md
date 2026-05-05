# Microservices Architecture — Interview Questions

**Purpose:** Senior-level coverage of microservices for system design and architecture interviews. Covers boundaries, communication, resilience, data consistency, observability, deployment, and the hard-won lessons of running services in production.

---

## Table of Contents

1. [Monolith vs Microservices](#monolith-vs-microservices)
2. [Service Boundaries and Decomposition](#service-boundaries-and-decomposition)
3. [Inter-Service Communication](#inter-service-communication)
4. [API Gateway and BFF](#api-gateway-and-bff)
5. [Service Discovery and Load Balancing](#service-discovery-and-load-balancing)
6. [Resilience Patterns](#resilience-patterns)
7. [Sagas and Distributed Workflows](#sagas-and-distributed-workflows)
8. [Event-Driven Architecture, CQRS, Event Sourcing](#event-driven-architecture-cqrs-event-sourcing)
9. [Data Consistency Patterns](#data-consistency-patterns)
10. [Idempotency and Exactly-Once](#idempotency-and-exactly-once)
11. [Observability — Logging, Tracing, Metrics](#observability--logging-tracing-metrics)
12. [Testing Microservices](#testing-microservices)
13. [API Versioning and Evolution](#api-versioning-and-evolution)
14. [Deployment and Release](#deployment-and-release)
15. [Service Mesh](#service-mesh)
16. [Anti-Patterns and Pitfalls](#anti-patterns-and-pitfalls)
17. [When NOT to Use Microservices](#when-not-to-use-microservices)

---

## Monolith vs Microservices

### Q1. Define monolith and microservices.

**Monolith:** A single deployable unit containing all business capabilities. One codebase, one process, one database (typically). Simple to develop, test, and deploy initially; becomes harder as it grows.

**Microservices:** Multiple independently-deployable services, each owning a bounded business capability and (usually) its own data store. Services communicate over the network via APIs or messages.

---

### Q2. Compare monolith vs microservices.

| Aspect | Monolith | Microservices |
|--------|----------|---------------|
| Deployment | One artifact, all-or-nothing | Independent per service |
| Scaling | Whole app together | Per-service |
| Team autonomy | Limited | High |
| Tech stack | Usually single | Polyglot possible |
| Local dev | Easy | Harder (many services to run) |
| Testing | E2E in one process | Cross-service contracts, integration |
| Data | One DB, transactions easy | Per-service DB, eventual consistency |
| Operational complexity | Low | High |
| Failure isolation | Crash = everything down | One service can fail in isolation |
| Latency | In-process calls | Network hops |
| Initial productivity | High | Low |
| Productivity at scale | Decreases | Increases (with mature platform) |

---

### Q3. When should you choose a monolith over microservices?

- Small team (under ~20 engineers).
- Domain not well-understood — boundaries are guesses.
- Low operational maturity — no CI/CD, no containers, no observability.
- Latency-sensitive workflows that would suffer from network hops.
- Greenfield product still finding fit.

The "modular monolith" — a single deploy with strict module boundaries — is often the best starting point. Migrate to microservices when team or domain growth makes the monolith painful.

---

### Q4. When should you choose microservices?

- Multiple teams need to ship independently.
- Components have wildly different scaling needs (one is CPU-heavy, another I/O-heavy).
- Different parts have different reliability/SLO requirements.
- Different parts benefit from different tech stacks.
- The domain has clear, stable bounded contexts.

The benefit is **organizational scalability**, not better software per se. Conway's Law: your architecture mirrors your team structure.

---

### Q5. What is a "distributed monolith" and why is it bad?

**Answer:** A system that looks like microservices but behaves like a monolith — services are tightly coupled, deployed together, share a database, or have to be released in lockstep. You pay all the costs of distributed systems (latency, partial failure, deployment complexity) and get none of the benefits (independent deploy, isolation, autonomy).

Common signs:

- Releasing service A requires also releasing service B.
- Multiple services share the same database tables.
- Adding a field to one service breaks another.
- Local development requires running 15 services.
- One service's outage cascades to all.

---

## Service Boundaries and Decomposition

### Q6. How do you decide where to draw service boundaries?

Common approaches:

1. **Domain-Driven Design (DDD)** — boundaries follow **bounded contexts**.
2. **Business capability** — group around what the business does (orders, billing, fulfillment).
3. **Team boundaries** — Conway's Law in reverse: design teams around the desired services.
4. **Volatility / change rate** — separate frequently-changing parts from stable cores.
5. **Data ownership** — one service owns each entity's source of truth.

The best test: would you be willing to call this a "service" or is it really a feature of another?

---

### Q7. What is a bounded context?

**Answer:** A boundary within which a domain model is consistent and unambiguous. The same word can mean different things in different contexts — "Customer" in Sales is not the same as "Customer" in Support. Each bounded context maps cleanly to a service. Communication between contexts requires explicit translation (anti-corruption layers).

---

### Q8. What are aggregates and why do they matter for service design?

**Answer:** An **aggregate** (DDD term) is a cluster of domain objects treated as a unit for data changes. The aggregate root enforces invariants. Examples:

- `Order` aggregate root + `OrderLine` children.
- `Cart` aggregate root + `CartItem` children.

Service boundaries are usually drawn at aggregate boundaries — you don't share aggregates across services. One service owns the `Order` aggregate; others reference orders by ID.

---

### Q9. How granular should services be?

**Answer:** "As small as possible, as large as necessary." Avoid:

- **Nano-services** — services so small that they can't make decisions alone, requiring N hops for one request.
- **God services** — too much responsibility, becomes a mini-monolith.

Practical sizing: a service should fit in one team's head, own a coherent business capability, and be independently releasable.

---

### Q10. How do you migrate from monolith to microservices?

**Strangler Fig pattern.**

1. Put the monolith behind an API gateway or proxy.
2. Identify a bounded context to extract first (low risk, well-understood, ideally read-mostly).
3. Build the new service.
4. Route traffic for that capability through the gateway to the new service.
5. Migrate data ownership — eventually the monolith no longer touches that data.
6. Repeat for other contexts.
7. Eventually the monolith withers and dies — or remains as a thin glue layer.

Don't try a "big bang" rewrite. Keep both running side-by-side and migrate slice by slice.

---

## Inter-Service Communication

### Q11. What are the communication options?

| Mechanism | Style | When to use |
|-----------|-------|-------------|
| REST/HTTP | Sync request/response | Public APIs, simple internal calls |
| gRPC | Sync request/response, binary | Internal services, low latency, typed contracts |
| GraphQL | Sync, client-driven shape | Mobile clients, BFFs, aggregating reads |
| Message queue (RabbitMQ, SQS) | Async commands/tasks | Background work, decoupling |
| Event bus (Kafka, NATS) | Async events, replay | Event-driven workflows, log of business events |
| WebSocket / SSE | Push from server | Real-time updates to clients |
| Database CDC | Async event derivation | Avoiding dual writes |

---

### Q12. Synchronous vs asynchronous — when to use which?

**Synchronous (HTTP, gRPC):**

- Caller needs an immediate answer.
- Call is short-lived (< few hundred ms).
- The two services are tightly coupled by user expectation (search → results).

**Asynchronous (queues, events):**

- Caller doesn't need immediate confirmation.
- Work can be deferred / retried.
- Systems should keep working when downstream is degraded.
- Multiple consumers may need to react.

Rule: **prefer async for write paths, sync for read paths**. Sync writes couple availability — if downstream is down, you're down too.

---

### Q13. REST vs gRPC?

| Aspect | REST | gRPC |
|--------|------|------|
| Protocol | HTTP/1.1 or 2 | HTTP/2 |
| Payload | Usually JSON | Protobuf (binary) |
| Schema | OpenAPI optional | .proto files mandatory |
| Browser support | Native | Limited (grpc-web) |
| Streaming | Limited (SSE, chunked) | Native bidirectional streaming |
| Tooling | Universal | Excellent for typed languages |
| Performance | Good | Better (binary, multiplexed) |
| Best for | Public APIs, web clients | Internal service-to-service |

Most large companies expose REST/GraphQL externally and use gRPC internally.

---

### Q14. What is GraphQL federation?

**Answer:** A way to compose multiple GraphQL services into one unified graph. Each service owns a slice of the schema; a gateway resolves queries by routing field-by-field to the right service.

```
┌── users service ── User { id, name }
│
gateway ── one schema ──┤
│
└── orders service ── Order { id, user: User, total }
```

Useful when many services own pieces of the same logical graph and front-ends want to query across them. Operationally complex — federation gateway is a critical path component.

---

## API Gateway and BFF

### Q15. What is an API gateway?

**Answer:** A single entry point that:

- Routes requests to the right service.
- Handles cross-cutting concerns: TLS termination, authentication, authorization, rate limiting, logging, request shaping, caching.
- Aggregates calls (to a few backend services) into one client request when needed.
- Enforces external API contract; protects internal API from being exposed.

Examples: Kong, AWS API Gateway, Apigee, Tyk, Envoy-based custom gateways.

---

### Q16. What is the BFF pattern?

**Answer:** **Backend For Frontend.** A dedicated API layer per client type (web, iOS, Android, partner). Each BFF aggregates and shapes responses for its specific client.

```
       ┌── Web BFF ──┐
       │             │
mobile ┼── iOS BFF ──┼── microservices
       │             │
       └── Partner ──┘
            BFF
```

Why: clients have different needs. The web wants a giant aggregate; mobile wants a slim payload. A single backend API serving all is a compromise; BFFs let each client get exactly what it needs.

Avoid: one BFF per page or per endpoint — that's just a god service in disguise.

---

### Q17. Should you put business logic in the API gateway?

**No.** The gateway should handle infrastructure concerns (auth, rate limit, routing). Business logic belongs in services. Gateways with business logic become bottlenecks, single points of failure, and impossible to evolve.

A BFF can hold light orchestration logic, but heavy business rules belong in the owning service.

---

## Service Discovery and Load Balancing

### Q18. What is service discovery?

**Answer:** The mechanism by which a service finds the network address of another. Two styles:

- **Client-side discovery** — client queries a registry (Consul, Eureka), gets addresses, picks one. Client-side load balancing.
- **Server-side discovery** — client calls a virtual address, the LB or DNS resolves to instances. Simpler clients.

In Kubernetes, the platform handles this — a Service has a stable DNS name and the kube-proxy/iptables load-balances to pods.

---

### Q19. L4 vs L7 load balancing?

| Aspect | L4 | L7 |
|--------|----|----|
| Layer | Transport (TCP/UDP) | Application (HTTP) |
| Routing decisions | Based on IP/port | Based on URL, headers, cookies |
| Performance | Faster | Slower |
| Features | Connection-level | Path routing, retries, header rewriting |
| Examples | AWS NLB, HAProxy in TCP mode | AWS ALB, Envoy, Nginx, Traefik |

Use L7 for HTTP services where you need path-based routing and request-level resilience. Use L4 for raw TCP, or in front of L7 LBs at the edge.

---

### Q20. Client-side load balancing — when?

**Answer:** When you want fine-grained control: weighted round-robin, EWMA latency-based, request hedging, retries with locality awareness. Common in gRPC clients (Envoy as a sidecar provides this transparently).

---

## Resilience Patterns

### Q21. What is the circuit breaker pattern?

**Answer:** A wrapper around a remote call that "opens" (fails fast) when downstream is unhealthy.

States:

- **Closed** — calls pass through; failures counted.
- **Open** — calls fail immediately without trying. Dependent system gets time to recover.
- **Half-open** — after a cooldown, allow a few test calls. If they succeed, close the breaker; otherwise reopen.

```
[CLOSED] ──failures > threshold──> [OPEN]
                                     │
                              cooldown elapsed
                                     ▼
                                [HALF-OPEN]
                                  /     \
                          success /       \ failure
                                 ▼         ▼
                            [CLOSED]    [OPEN]
```

Implementations: Hystrix (legacy), Resilience4j, Polly, Envoy, Istio.

---

### Q22. Why are timeouts critical?

**Answer:** Without explicit timeouts, a slow downstream propagates slowness up the stack until threads or connections exhaust. A request that takes "forever" pins threads — eventually the whole service stalls.

Rules:

- Every remote call has a timeout.
- Inner timeouts must be shorter than outer timeouts (cascading budget).
- Downstream timeout < user-facing timeout − overhead.
- Set default timeouts in the HTTP client; don't rely on caller code.

---

### Q23. What is retry, and what's the catch?

**Answer:** Re-attempt a failed call. Catches:

- **Retry storms** — when downstream is overloaded, retries make it worse. Use exponential backoff with jitter.
- **Non-idempotent operations** — retrying a `POST` may charge a card twice. Use idempotency keys.
- **Retry budget** — cap retries cluster-wide so a fraction of traffic doesn't blow up downstream.

Best practice: retry on transient errors (network, 5xx), not on 4xx; back off exponentially; cap attempts (often 3); add jitter; tag retries to avoid retry-of-retry amplification.

---

### Q24. What is the bulkhead pattern?

**Answer:** Isolate resources (thread pools, connection pools, semaphores) per dependency so one slow downstream can't drain all of them. Named after a ship's compartments — a leak in one doesn't sink the ship.

```
service depends on: payment, inventory, recommendations
allocate: 50 threads each, separate pools

if recommendations is slow → only those 50 threads stall;
payment and inventory still work
```

---

### Q25. What is the failover / fallback pattern?

**Answer:** When the primary call fails or breaker is open, return a degraded but acceptable result:

- Cached previous response.
- Static default ("recommended for you" → bestsellers).
- Empty list with a "try later" hint.
- Async-queue the request, return optimistic acknowledgment.

Fallbacks must be carefully chosen — sometimes "no data" is much worse than failing loudly.

---

### Q26. What is rate limiting and where do you apply it?

| Layer | Why |
|-------|-----|
| Edge / gateway | Protect from abusive clients, DDoS |
| Per-service ingress | Protect overloaded service |
| Per-user / per-tenant | Fair share |
| Outbound to dependencies | Protect downstream |

Algorithms:

- **Token bucket** — allows bursts up to bucket size, refills at fixed rate.
- **Leaky bucket** — smooths bursts; constant rate out.
- **Fixed window** — easy but boundary spikes.
- **Sliding window** — smoother, more accurate.
- **Concurrency limit** — cap in-flight requests, not rate.

---

## Sagas and Distributed Workflows

### Q27. Why can't you use 2PC across microservices?

**Answer:** Two-phase commit (XA) requires:

- All participants support XA.
- A coordinator that doesn't fail.
- Locks held across the network for the duration of the transaction.

Problems in microservices:

- HTTP and most NoSQL DBs don't support XA.
- Lock holding magnifies latency and blocks other work.
- Coordinator failure leaves participants in "in-doubt" state.
- A misbehaving participant blocks everyone.

In practice, 2PC is avoided. Sagas are the standard.

---

### Q28. What is a saga?

**Answer:** A long-running business transaction split into a sequence of local transactions, each with a compensating action that undoes its effect on failure.

```
order placed → reserve inventory → charge card → arrange shipping
                      │                  │
                  compensation      compensation
                  (release)         (refund)
```

If shipping fails, you compensate by refunding the card and releasing the inventory. The system reaches a consistent state through the compensation chain.

---

### Q29. Orchestration vs choreography sagas?

**Orchestration:** A central orchestrator service tells each service what to do.

```
orchestrator ─► reserve inventory
            ─► charge card
            ─► arrange shipping
```

- Pros: explicit flow, easy to reason about, easy to test.
- Cons: orchestrator is a coupling point.

**Choreography:** Services emit events; others react.

```
OrderPlaced ─► InventoryService reacts ─► InventoryReserved
                                       ─► PaymentService reacts ─► PaymentCharged
                                                                ─► ShippingService reacts
```

- Pros: loose coupling, each service is autonomous.
- Cons: harder to see the whole flow, harder to debug, easy to create cyclic dependencies.

Use **orchestration** for complex flows where you want explicit control. Use **choreography** for simple event-reaction chains.

---

### Q30. How do you implement compensations?

- Each forward action has a paired compensation that semantically "undoes" it.
- Compensations are best-effort and idempotent.
- Compensations are not always perfect inverses — once an email is sent, you can't unsend it; the compensation might be sending a "we're sorry" email.

Design forward actions to be reversible where possible; warn loudly where they aren't.

---

### Q31. What's the role of an outbox in saga steps?

**Answer:** Each saga step writes its state change AND its outgoing event to the same DB transaction. A relay process publishes events from the outbox to the broker. This makes each step atomic — you don't get into a state where the DB updated but the event was lost (or vice versa).

---

## Event-Driven Architecture, CQRS, Event Sourcing

### Q32. What is event-driven architecture?

**Answer:** Services communicate primarily through asynchronous events. Producers publish events; consumers subscribe. The producer doesn't know who's listening.

Benefits:

- Loose coupling.
- Resilience — consumers down ≠ producer down.
- Replayable history.
- Easy to add new subscribers without changing the producer.

Drawbacks:

- Harder to reason about ordering and timing.
- Eventual consistency.
- Schema evolution is critical.

---

### Q33. Difference between event and command?

| Aspect | Event | Command |
|--------|-------|---------|
| Tense | Past — "OrderPlaced" | Imperative — "PlaceOrder" |
| Direction | Producer doesn't know consumers | Sent to a specific recipient |
| Failure | Already happened | May still fail |
| Multiple receivers | Yes | No |
| Coupling | Low | Higher |

A queue carries commands; an event bus carries events.

---

### Q34. What is CQRS?

**Answer:** **Command Query Responsibility Segregation.** Separate the write model from the read model.

```
        commands
client ──────────► write model (normalized, source of truth)
                          │
                          │ events
                          ▼
                   read model (denormalized, optimized for queries)
        queries           ▲
client ──────────────────┘
```

- The write side enforces invariants and emits events.
- The read side projects events into query-optimized stores (search index, denormalized views).

Use when read and write workloads diverge sharply (e.g., complex querying with heavy reporting).

---

### Q35. What is event sourcing?

**Answer:** Persist every change as an event. The current state is derived by replaying events.

```
events: AccountOpened, MoneyDeposited(100), MoneyWithdrawn(30)
state: balance = 70
```

Pros:

- Full audit trail.
- Time travel ("what was the state on March 1?").
- Easy to add new projections.
- Natural fit with Kafka.

Cons:

- Schema evolution of events is critical (events are forever).
- Snapshots needed to avoid replaying millions of events.
- Querying current state requires projections.

Event sourcing pairs naturally with CQRS but they are independent ideas.

---

### Q36. CQRS without event sourcing — does that make sense?

**Yes.** Many systems benefit from separate read/write models without going full event-sourced. Use CDC or domain events to sync.

---

## Data Consistency Patterns

### Q37. Why is "service per database" a rule?

**Answer:** If two services share a DB, they're coupled at the schema level. A change in one breaks the other. They can't deploy independently. They can't choose the right DB for their workload. They become one big monolith with extra steps.

Each service owns its data. Other services access it only via the owner's API or events.

---

### Q38. What's the dual-write problem?

**Answer:** A service needs to update its DB AND publish an event. If you do them as separate operations:

```
write to DB ✓
publish event ✗  → DB updated but no event → downstream out of sync
```

Or:

```
publish event ✓
write to DB ✗  → event published for change that never happened
```

You can't reliably do both atomically with a network in between.

---

### Q39. What is the transactional outbox pattern?

**Answer:** Solves the dual-write problem. The service writes the business change AND an outbox row in the same DB transaction. A relay reads the outbox and publishes to the broker; on success, marks/deletes the row.

```sql
BEGIN;
UPDATE orders SET status = 'PAID' WHERE id = 1;
INSERT INTO outbox (event_type, payload) VALUES ('OrderPaid', '{...}');
COMMIT;

-- separate process
-- reads pending outbox rows, publishes to Kafka, marks done
```

Now the event is guaranteed to be published as long as the DB write committed. At-least-once delivery; consumers must be idempotent.

---

### Q40. What is the inbox pattern?

**Answer:** Mirror of the outbox on the consumer side. Each incoming event is recorded in an `inbox` table within the same DB transaction as the side effect. Before processing, check whether the event ID is already in the inbox — if so, skip. Provides idempotency at the consumer.

---

### Q41. What is Change Data Capture (CDC)?

**Answer:** Reading the database's transaction log (WAL/binlog) and emitting a stream of row-level changes. Tools: Debezium (Kafka Connect), Maxwell, AWS DMS.

```
Postgres WAL → Debezium → Kafka topic → consumers
```

Benefits:

- No application changes needed.
- Captures every change including those bypassing the app.
- Excellent for syncing read models, search indices, data lakes.

Caveats:

- Schema in Kafka mirrors DB schema — coupling.
- Reordering across tables is possible.
- Initial snapshots can be heavy.

---

### Q42. What is eventual consistency?

**Answer:** A consistency model where, given no new updates, all replicas eventually converge to the same value. In microservices, the period of inconsistency is typically milliseconds to seconds.

Implications:

- A user may not see their write immediately on a read in another service.
- "Read your writes" guarantees require routing reads of fresh data to the source of truth.
- UI may need to optimistically show changes before confirmation.

Not all use cases tolerate eventual consistency — money, inventory, security tokens often need strong consistency.

---

### Q43. What patterns help with read-after-write consistency?

- **Read from primary** for the user's own recent writes (sticky session).
- **Optimistic UI** — show the change locally, accept on confirmation.
- **Causal consistency** — pass a session token; reads wait until they see writes for that token.
- **Bounded staleness** — accept up to N seconds of lag.
- **Avoid the problem** — keep the read and the write in the same service for that flow.

---

## Idempotency and Exactly-Once

### Q44. Why is idempotency the most important property in distributed systems?

**Answer:** Networks fail. Retries happen — explicitly (you retry) or implicitly (a timeout, the original eventually succeeded). Without idempotency, retries cause duplicates.

Idempotent: applying the operation twice has the same effect as applying it once.

```
PUT /users/123 {name: 'X'}    → idempotent
DELETE /users/123             → idempotent (after first, second is no-op)
POST /charges {amount: 100}   → NOT idempotent (charges twice)
```

---

### Q45. How do you make non-idempotent operations idempotent?

**Idempotency keys.** Caller provides a unique key. The server stores `(key → result)`. If the same key arrives, return the stored result instead of re-executing.

```http
POST /charges
Idempotency-Key: 7f9e4c1a-8d2b-4a5e-9f3c-1234567890ab
{ "amount": 100 }
```

Stripe, AWS, and most reputable APIs implement this. Server stores keys for ~24h. Client retries with the same key.

---

### Q46. Is exactly-once delivery possible?

**Answer:** "Exactly-once delivery" is impossible in a distributed system in the general case (because you can't know if your ack was received). What you can achieve:

- **Exactly-once processing** — the side effect happens at most once, even if the message is delivered multiple times. Requires idempotent consumers + dedup.

So: at-least-once delivery + idempotent consumers = exactly-once effective semantics.

---

## Observability — Logging, Tracing, Metrics

### Q47. What are the three pillars of observability?

| Pillar | What it tells you | Tools |
|--------|-------------------|-------|
| Logs | What happened (events) | ELK, Loki, Splunk, CloudWatch |
| Metrics | How much / how fast (aggregates) | Prometheus, Datadog, CloudWatch |
| Traces | How a request flowed across services | Jaeger, Zipkin, Tempo, Honeycomb |

OpenTelemetry is the emerging standard for instrumenting all three with one SDK.

---

### Q48. What is distributed tracing?

**Answer:** A request that hops across services is given a `trace_id` at the entry point. Each service that handles it records a `span` with that trace ID and its parent span ID. A trace UI assembles the spans into a tree showing the request's path and timing.

```
trace_id: abc123
   └─ gateway (5 ms)
       └─ orders service (120 ms)
           ├─ inventory service (30 ms)
           └─ pricing service (80 ms)
               └─ pricing DB (45 ms)
```

This lets you see where time was spent, which dependencies were called, and which step caused an error.

---

### Q49. Why does context propagation matter?

**Answer:** A trace ID, user ID, request ID, and tenant ID often need to flow with the request across all hops. Without consistent propagation:

- You can't correlate logs across services.
- You can't do per-tenant rate limiting.
- You can't tie an error in one service to the root request.

OpenTelemetry's W3C Trace Context (`traceparent` header) is the standard. Custom application context goes in `baggage`.

---

### Q50. What are good metrics for a service?

**RED method (per service):**

- **Rate** — requests per second.
- **Errors** — error count or %.
- **Duration** — latency p50, p95, p99.

**USE method (per resource):**

- **Utilization** — % busy.
- **Saturation** — queue depth.
- **Errors** — count.

**Golden signals (Google SRE):**

- Traffic, errors, latency, saturation.

Always track percentiles, not averages. p99 latency is the user-experienced latency for 1% of users — and they're the ones who complain.

---

### Q51. What is structured logging?

**Answer:** Logs as JSON (or similar) instead of free-text. Each log line has fields:

```json
{"ts":"2024-01-01T12:00:00Z","level":"error","service":"orders","trace_id":"abc","user_id":42,"msg":"payment failed","err":"timeout"}
```

Benefits: queryable, aggregatable, filterable. Modern log platforms (ELK, Loki, Datadog) parse JSON natively.

---

## Testing Microservices

### Q52. What's the testing pyramid for microservices?

```
              ┌──────────────┐
              │   E2E (few)  │
              ├──────────────┤
              │ Contract /   │
              │  Integration │
              ├──────────────┤
              │  Component   │
              ├──────────────┤
              │  Unit (many) │
              └──────────────┘
```

- **Unit tests** — pure logic, mocks, fast.
- **Component tests** — service in isolation, real DB, mocked external dependencies.
- **Contract tests** — verify each service honors the API contracts that consumers depend on.
- **Integration tests** — a small set of services together with real wires.
- **E2E** — full system; expensive and flaky; use sparingly.

---

### Q53. What are consumer-driven contract tests?

**Answer:** Consumers define the API contracts they rely on; producers verify they don't break those contracts.

Workflow (with Pact):

1. Consumer team writes a Pact test: "I expect to call `/users/{id}` and get JSON with `name` and `email`."
2. Pact records the expectations as a contract file.
3. Producer team runs the contract verification against their service in CI.
4. If the producer breaks the contract, CI fails before deployment.

Catches breaking changes early without running full E2E suites.

---

### Q54. How do you test message-driven services?

- Unit-test the handler logic.
- Spin up an embedded broker (RabbitMQ via Testcontainers, Kafka via Testcontainers).
- Verify message format with schema registry tests.
- Contract tests over the message schema (Pact for messages).
- Test idempotency by replaying the same message.

---

### Q55. How do you test for resilience?

**Chaos engineering.** Inject faults in production-like environments:

- Kill instances randomly (Chaos Monkey).
- Slow down dependencies (latency injection).
- Cut network between services.
- Simulate partial failures.

Tools: Chaos Mesh, Gremlin, AWS Fault Injection Simulator.

Verify that timeouts, retries, breakers, and fallbacks behave as designed.

---

## API Versioning and Evolution

### Q56. Strategies for versioning APIs?

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| URL versioning | `/v1/users` | Simple, visible | All clients see the version |
| Header versioning | `Accept: application/vnd.x.v2+json` | Clean URLs | Harder to debug |
| No versioning, additive evolution | Just add fields, never break | Long-term simpler | Requires discipline |
| Date-based | `/api?version=2024-01-01` | Stripe-style | Same as URL really |

In practice: support `/v1` and `/v2` simultaneously, deprecate `/v1` with a sunset date, give consumers months to migrate.

---

### Q57. What changes are backward-compatible?

**Safe (additive):**

- Adding optional request fields with defaults.
- Adding new response fields.
- Adding new endpoints.
- Loosening validation.

**Breaking:**

- Removing or renaming fields.
- Changing field types.
- Adding new required fields.
- Tightening validation.
- Changing semantics of an existing field.

Treat your API as a public contract — even internal APIs.

---

### Q58. How do you evolve an event schema?

- Use a schema registry (Avro, Protobuf, JSON Schema).
- Configure compatibility (BACKWARD or FULL).
- Add fields with defaults; never remove or rename.
- For breaking changes: introduce a new event type, dual-publish, migrate consumers, retire old.

Events are forever — they're persisted in Kafka and replayed years later.

---

## Deployment and Release

### Q59. Independent deploys — why is it the headline benefit?

**Answer:** Without independent deploy, you can have all the microservices in the world and still be a monolith. Each team should be able to release on their own cadence without coordinating with others.

Requirements:

- API contracts that don't break (or use feature flags).
- Backward-compatible schema changes.
- No shared database tables.
- CI/CD per service.
- Consumer-driven contract tests in CI.

---

### Q60. What deployment patterns are common?

| Pattern | Description |
|---------|-------------|
| Rolling update | Replace pods one at a time |
| Blue/green | Two stacks; switch traffic atomically |
| Canary | Send small % to new version; ramp up if healthy |
| Feature flags | Deploy code dark; turn on selectively |
| Shadow / mirror | Send copy of prod traffic to new version, don't return its results |
| A/B test | Different versions for different cohorts (product experiment, not release) |

Combine: deploy new version dark via canary + feature flag, then ramp.

---

### Q61. What is a feature flag?

**Answer:** A runtime switch that enables/disables a code path without deploying. Flags let you:

- Decouple deploy from release.
- Roll back instantly without redeploying.
- Gradually ramp a new feature to 1%, 10%, 100%.
- Per-user, per-tenant, per-region targeting.

Tools: LaunchDarkly, Unleash, Flagsmith, custom tables.

Discipline: every flag has an owner and a removal date. Stale flags rot the codebase.

---

### Q62. Polyglot persistence — should each service really pick its own DB?

**Tension:**

- For: services have different data needs (relational for orders, search for catalog, time-series for metrics).
- Against: every new DB is operational burden, expertise, backup, monitoring, cost.

**Pragmatic answer:** allow ~3 approved DB technologies (e.g., Postgres, Redis, Elasticsearch) and let services pick from those. Avoid sprawl. New tech requires a strong case.

---

## Service Mesh

### Q63. What is a service mesh?

**Answer:** A dedicated infrastructure layer that handles service-to-service communication concerns transparently. Implemented as **sidecars** (Envoy proxies) injected into each pod, controlled by a central control plane.

Features:

- mTLS between services (zero-trust).
- Traffic management (canary routing, retries, timeouts, circuit breaking).
- Observability (tracing, metrics) without app instrumentation.
- Policy (auth, rate limits).

Examples: Istio, Linkerd, Consul Connect, AWS App Mesh.

---

### Q64. When should you adopt a service mesh?

- You have many services (dozens+).
- You need consistent mTLS, observability, traffic policy across them.
- You want to standardize without changing every codebase.

Costs:

- Operational complexity (control plane upgrades, sidecar memory/CPU).
- Latency overhead (one extra hop per request).
- Debugging difficulty.

Linkerd is lighter; Istio is more featureful but heavier. Don't add a mesh prematurely — many teams over-invest.

---

### Q65. Service mesh vs API gateway?

| Aspect | API gateway | Service mesh |
|--------|-------------|--------------|
| Traffic | North-south (external → internal) | East-west (internal → internal) |
| Concerns | Auth, rate limit, routing for external clients | mTLS, retries, observability between services |
| Position | Edge | Inside the cluster |
| Often combined? | Yes |  |

You typically have both — gateway at the edge, mesh between services.

---

## Anti-Patterns and Pitfalls

### Q66. List common microservices anti-patterns.

| Anti-pattern | Symptom |
|--------------|---------|
| Distributed monolith | Lockstep deploys |
| Shared database | Multiple services write same tables |
| Synchronous chains | Request hops through 5 services serially |
| God service | One service knows everything |
| Nano-services | One field per service |
| Chatty interfaces | N+1 calls between services |
| Brittle integration tests | Whole system needed to test one service |
| No backward compatibility | Every change requires coordinated release |
| Ignoring partial failure | Treating remote calls like local calls |
| One-team-many-services | More services than people |
| Over-eager extraction | Splitting before bounded contexts are stable |
| Wrong data ownership | Service A's data lives in service B |

---

### Q67. What is "the fallacies of distributed computing"?

The classic eight fallacies that engineers wrongly assume:

1. The network is reliable.
2. Latency is zero.
3. Bandwidth is infinite.
4. The network is secure.
5. Topology doesn't change.
6. There is one administrator.
7. Transport cost is zero.
8. The network is homogeneous.

Every microservices design has to confront each of these. Most production incidents come from violating one.

---

### Q68. What's the "two-pizza team" rule?

**Answer:** A team should be small enough to be fed by two pizzas (~6–10 people). Each team owns one or a few services end-to-end. Larger teams force communication overhead. If a team's service depends on another team's service for daily work, the boundary is wrong.

---

### Q69. Why is "distributed transactions are hard" a recurring theme?

Because the problem is fundamental, not a tooling gap. The CAP theorem says: in a partition, you choose C or A. Real systems span partitions occasionally. So real distributed transactions are either slow (locks across the network), unavailable (CP), or eventually consistent (AP). Sagas, outboxes, and idempotency are the workarounds — they don't make the problem disappear.

---

## When NOT to Use Microservices

### Q70. List concrete scenarios where microservices are the wrong choice.

- **Small team (< 20 engineers).** Coordination overhead is more than the productivity gain.
- **Greenfield startup.** You don't know the boundaries yet. Wrong boundaries cost more than refactoring a monolith.
- **No platform maturity.** Without CI/CD, observability, on-call processes, you can't run dozens of services.
- **Latency-critical pipeline.** Every hop adds milliseconds. A monolith may be required for hard real-time.
- **Simple CRUD with low traffic.** A monolith plus a CDN scales further than people think.
- **Your team has no operational experience.** Microservices = distributed systems = much harder to operate.

---

### Q71. What's the right starting point for a new product?

**Modular monolith.**

- One repo, one deploy, one DB.
- But strict module boundaries — modules talk through internal APIs, not by reaching into each other's tables.
- Each module owns its tables.
- Logical domain events emitted internally for decoupling.
- Easy to extract a module into a service later when team or scaling needs demand it.

This is the path most successful companies take: start as a monolith, extract services where the seams are clear and the pain is real.

---

### Q72. Senior-level rules of thumb.

- Microservices solve organizational problems, not engineering ones.
- Bound services around business capabilities, not technical layers.
- Each service owns its data; never share schemas.
- Prefer async events for writes, sync for reads.
- Make every consumer idempotent and every producer use the outbox pattern.
- Always set timeouts; always have circuit breakers; always have bulkheads.
- Distributed tracing is mandatory at this scale.
- Backwards-compatible schema and API evolution is non-negotiable.
- A service mesh adds value only after you have many services and a platform team.
- Modular monolith first; extract when you have to, not because you can.
- The hardest problems are organizational: ownership, on-call, contracts.
