# RabbitMQ Interview Questions — Basic to Advanced

**Purpose:** Senior-level coverage of RabbitMQ for backend interviews. Covers AMQP, exchanges, queues, reliability, clustering, performance, and the patterns engineers use in production.

---

## Table of Contents

1. [Fundamentals and AMQP](#fundamentals-and-amqp)
2. [Architecture and Components](#architecture-and-components)
3. [Exchanges and Routing](#exchanges-and-routing)
4. [Queues — Properties and Behavior](#queues--properties-and-behavior)
5. [Messages — Properties and Delivery](#messages--properties-and-delivery)
6. [Acknowledgments, Prefetch, Reliability](#acknowledgments-prefetch-reliability)
7. [Dead Letter Exchanges, Retries, Delays](#dead-letter-exchanges-retries-delays)
8. [Publisher Confirms and Transactions](#publisher-confirms-and-transactions)
9. [Clustering and High Availability](#clustering-and-high-availability)
10. [Federation, Shovel, Multi-DC](#federation-shovel-multi-dc)
11. [Operations — Management UI, Monitoring](#operations--management-ui-monitoring)
12. [Common Patterns](#common-patterns)
13. [Performance Tuning](#performance-tuning)
14. [RabbitMQ vs Kafka and Other Brokers](#rabbitmq-vs-kafka-and-other-brokers)
15. [Common Gotchas and Production Pitfalls](#common-gotchas-and-production-pitfalls)

---

## Fundamentals and AMQP

### Q1. What is RabbitMQ?

**Answer:** RabbitMQ is an open-source message broker that implements the AMQP 0-9-1 protocol (and supports STOMP, MQTT, and AMQP 1.0 via plugins). Producers publish messages to exchanges, exchanges route them to queues based on bindings, and consumers receive messages from queues. It is built on Erlang/OTP and is well known for low-latency, flexible routing, and per-message delivery semantics.

---

### Q2. What is AMQP and why does it matter?

**Answer:** AMQP (Advanced Message Queuing Protocol) is a binary, wire-level protocol for message-oriented middleware. AMQP 0-9-1 is the version RabbitMQ implements natively. It defines:

- **Frames** — protocol units (method, header, body, heartbeat).
- **Channels** — multiplexed virtual connections inside one TCP connection.
- **Methods** — `basic.publish`, `basic.consume`, `basic.ack`, etc.
- **Classes** — exchange, queue, basic, tx, confirm.

Because AMQP is a defined wire protocol, any AMQP-compliant client can talk to any AMQP-compliant broker. This is unlike Kafka, which has its own proprietary protocol.

---

### Q3. What does the AMQP message lifecycle look like?

```
producer → exchange → (binding rules) → queue → consumer
                          |
                  routing key + headers + exchange type
```

1. Producer connects to broker over TCP.
2. Opens a channel.
3. Declares (or assumes) an exchange.
4. Publishes a message with a routing key.
5. The exchange evaluates bindings and routes to zero or more queues.
6. The queue stores the message until a consumer acknowledges it.
7. The consumer acks → broker removes the message.

---

### Q4. What is a channel and why use it?

**Answer:** A channel is a lightweight virtual connection multiplexed over a single TCP connection. Opening TCP connections is expensive; channels are cheap. Best practice is one TCP connection per process and one channel per thread of execution. Channels are not thread-safe — sharing a channel between threads will cause undefined behavior.

---

### Q5. What is a virtual host (vhost)?

**Answer:** A vhost is a namespace inside a RabbitMQ broker. It isolates exchanges, queues, bindings, users, and permissions. Two services using the same broker but different vhosts cannot see each other's resources. Use vhosts to separate environments (`/dev`, `/staging`, `/prod`) or tenants without spinning up extra brokers.

```bash
rabbitmqctl add_vhost orders
rabbitmqctl set_permissions -p orders order_svc ".*" ".*" ".*"
```

---

## Architecture and Components

### Q6. List the core RabbitMQ components.

| Component | Role |
|-----------|------|
| Producer | Publishes messages |
| Connection | TCP connection to broker |
| Channel | Multiplexed virtual connection inside a connection |
| Exchange | Receives messages and routes to queues |
| Binding | Rule linking an exchange to a queue (with routing key/headers) |
| Queue | FIFO buffer holding messages |
| Consumer | Reads messages from a queue |
| Broker | The RabbitMQ server itself |
| Cluster | Multiple brokers sharing metadata |

---

### Q7. Where do messages live — in the exchange or the queue?

**Answer:** In the **queue**. Exchanges are routing engines and do not store messages. If a message arrives at an exchange and no binding matches any queue, the message is dropped (unless `mandatory=true` and the producer handles `basic.return`, or an alternate exchange is configured).

---

### Q8. How does RabbitMQ persist data?

**Answer:** Two storage subsystems:

- **Message store** — message bodies (separate file per message above a size threshold; otherwise embedded in the queue index).
- **Queue index** — per-queue index of message references and ack state.

Messages are persisted to disk only if both:
1. The message has `delivery_mode=2` (persistent).
2. The queue is `durable=true`.

Even then, messages can be lost if the broker crashes between accepting the publish and flushing to disk. Use **publisher confirms** for durability guarantees.

---

## Exchanges and Routing

### Q9. What are the four built-in exchange types?

| Type | Routing rule | Use case |
|------|--------------|----------|
| Direct | Routing key must equal binding key | Targeted routing (per-customer queues) |
| Fanout | Ignores routing key, broadcasts to all bound queues | Pub/sub broadcast |
| Topic | Routing key matches binding key with wildcards `*` (one word) and `#` (zero or more words) | Hierarchical routing (`logs.error.*`) |
| Headers | Matches on message headers, not routing key | Content-based routing |

Plus the **default exchange** — an unnamed direct exchange that routes by queue name. Publishing to `""` with routing key `"my_queue"` delivers to that queue.

---

### Q10. Show a topic exchange routing example.

```
Bindings:
  queue_errors  ←  logs.*.error
  queue_billing ←  logs.billing.#
  queue_all     ←  logs.#

Publish:
  routing_key = "logs.billing.error"
  
Routes to: queue_errors, queue_billing, queue_all
```

- `*` matches exactly one word.
- `#` matches zero or more words.

---

### Q11. When would you use a fanout exchange?

**Answer:** Broadcasting events to multiple independent consumers, each needing their own copy. Examples:

- Cache invalidation across N application servers.
- Real-time notifications to all online services.
- Replicating audit events to logging, analytics, and archive services simultaneously.

Each consumer binds its own queue to the fanout exchange. Each queue gets a copy of every message.

---

### Q12. What is a headers exchange and why is it rarely used?

**Answer:** Routes based on the `x-match` header argument:

- `x-match=all` — every header must match (AND).
- `x-match=any` — any header matches (OR).

Powerful for content-based routing without parsing message bodies, but rarely used because:
- Slower (header comparison vs hash lookup on routing key).
- Harder to reason about routing topology.
- Topic exchanges with structured routing keys cover most cases.

---

### Q13. What is the alternate exchange?

**Answer:** When an exchange cannot route a message (no matching binding), instead of dropping it, the broker forwards it to the alternate exchange:

```python
channel.exchange_declare(
    exchange='primary',
    exchange_type='topic',
    arguments={'alternate-exchange': 'unrouted'}
)
```

Useful for catching unroutable messages for debugging or dead-letter analysis.

---

## Queues — Properties and Behavior

### Q14. What are the key queue properties?

| Property | Meaning |
|----------|---------|
| `durable` | Queue survives broker restart (its definition, not necessarily messages) |
| `exclusive` | Used by only one connection; deleted when that connection closes |
| `auto-delete` | Deleted when the last consumer unsubscribes |
| `arguments` | TTL, max-length, DLX, priority, queue type, etc. |

```python
channel.queue_declare(
    queue='orders',
    durable=True,
    exclusive=False,
    auto_delete=False,
    arguments={
        'x-message-ttl': 60000,
        'x-max-length': 100000,
        'x-dead-letter-exchange': 'orders.dlx'
    }
)
```

---

### Q15. Difference between durable queue and persistent message?

**Answer:** Both are needed for survival of broker restart:

- **Durable queue** — the queue's metadata (definition) survives restart.
- **Persistent message** — the message body is written to disk.

A persistent message in a non-durable queue is lost on restart (the queue itself disappears). A non-persistent message in a durable queue is also lost (the queue exists, but messages were only in memory).

---

### Q16. What is an exclusive queue?

**Answer:** Visible only to the connection that declared it, and deleted when that connection closes. Common use: server-named reply queues for RPC patterns. Do not use exclusive queues for long-lived consumers in a load-balanced pool — the queue dies with the connection.

---

### Q17. What is a lazy queue?

**Answer:** A queue declared with `x-queue-mode=lazy`. Messages are written to disk as soon as they enter the queue and only read into RAM when consumed. Trade-off:

- **Pros:** stable behavior under huge backlogs (no memory blowup), survives consumer outages of millions of messages.
- **Cons:** higher disk I/O, lower max throughput than the default in-memory mode.

In RabbitMQ 3.12+, lazy mode is largely superseded by **quorum queues** which behave similarly.

---

### Q18. What are quorum queues?

**Answer:** A modern queue type (RabbitMQ 3.8+) implementing the Raft consensus algorithm. Replaces classic mirrored queues for HA. Properties:

- Always durable.
- Replicated to a configurable quorum of nodes (typically 3 or 5).
- Strong leader-follower model — writes acknowledged only after replication to a majority.
- Built-in poison-message handling (`x-delivery-limit`).
- Lower throughput than classic queues but predictable, safer failure semantics.

```python
channel.queue_declare(
    queue='orders',
    durable=True,
    arguments={'x-queue-type': 'quorum', 'x-delivery-limit': 5}
)
```

---

### Q19. Mirrored (classic HA) queues vs quorum queues — which to use?

| Feature | Classic Mirrored | Quorum |
|---------|------------------|--------|
| Replication algorithm | Eager replication (all mirrors) | Raft consensus |
| Split-brain safety | Vulnerable | Safe (majority required) |
| Failover speed | Fast | Slightly slower |
| Throughput | Higher | Lower but predictable |
| Memory profile | Can spike | Steady |
| Status | Deprecated since 3.8 | Recommended |
| Poison message handling | Manual | Built-in |

Use **quorum queues** for any new HA requirement. Classic mirrored queues are removed in 4.0.

---

### Q20. What are streams in RabbitMQ?

**Answer:** A persistent, append-only log structure (RabbitMQ 3.9+) similar in spirit to Kafka topics. Consumers can replay from any offset. Streams support:

- High write throughput.
- Multiple independent consumer groups.
- Long retention based on size or time.

When you need replayability or fan-out at scale, use streams; when you need traditional work queues with selective ack/nack, use queues.

---

## Messages — Properties and Delivery

### Q21. What message properties are available?

| Property | Purpose |
|----------|---------|
| `content_type` | MIME type (`application/json`) |
| `content_encoding` | Compression (`gzip`) |
| `delivery_mode` | 1 transient, 2 persistent |
| `priority` | Numeric priority (requires priority queue) |
| `correlation_id` | RPC correlation |
| `reply_to` | Queue to reply to (RPC) |
| `expiration` | Per-message TTL (string ms) |
| `message_id` | Unique ID for idempotency |
| `timestamp` | Producer-side timestamp |
| `type` | Application message type |
| `user_id` | Authenticated user |
| `app_id` | Producing app identifier |
| `headers` | Custom key/value table |

---

### Q22. How do you implement priority queues?

```python
channel.queue_declare(
    queue='jobs',
    durable=True,
    arguments={'x-max-priority': 10}
)

channel.basic_publish(
    exchange='',
    routing_key='jobs',
    body=payload,
    properties=pika.BasicProperties(priority=8)
)
```

Caveats:
- Priority is a hint, not a strict guarantee under high load.
- Priority queues consume more memory and CPU.
- Keep priority levels small (1–10).
- Consumer prefetch can starve low-priority messages — set `prefetch_count` low or use multiple queues per priority class instead.

---

### Q23. How do you set message TTL?

Three ways:

1. **Per-queue:** `x-message-ttl` in queue arguments — every message expires.
2. **Per-message:** `expiration` property in milliseconds.
3. **Per-policy:** TTL applied via broker-side policy.

When a message expires it's either dropped or routed to the queue's DLX if configured.

---

## Acknowledgments, Prefetch, Reliability

### Q24. What are the acknowledgment modes?

- **Auto-ack (`auto_ack=true`)** — message considered delivered the moment it leaves the broker. Fast but unsafe; if the consumer crashes mid-processing, the message is gone.
- **Manual ack (`basic.ack`)** — consumer explicitly acks after processing. Broker holds the message until ack arrives.

Always use manual acks for anything you cannot afford to lose.

---

### Q25. What's the difference between `basic.ack`, `basic.nack`, and `basic.reject`?

| Method | Purpose | Multiple? | Requeue? |
|--------|---------|-----------|----------|
| `basic.ack` | Successful processing | Yes (`multiple=true`) | N/A |
| `basic.nack` | Negative ack (RabbitMQ extension) | Yes | Optional |
| `basic.reject` | Reject single message | No | Optional |

```python
# Success
channel.basic_ack(delivery_tag=tag)

# Failure, requeue for another consumer
channel.basic_nack(delivery_tag=tag, requeue=True)

# Failure, do not requeue (goes to DLX if configured, else dropped)
channel.basic_nack(delivery_tag=tag, requeue=False)
```

---

### Q26. What is consumer prefetch (QoS)?

**Answer:** `basic.qos` with `prefetch_count` limits how many unacked messages a consumer can hold. Without it, the broker shoves all available messages to the first consumer that connects, starving others.

```python
channel.basic_qos(prefetch_count=10)
```

Pick prefetch based on:
- Per-message processing time.
- Number of consumers.
- Memory budget on the consumer.

A common value is 1–50. Use `prefetch_count=1` for slow tasks where fairness matters; higher values for fast tasks where throughput matters.

---

### Q27. Why does setting `prefetch_count=1` matter?

**Answer:** The default behavior of round-robin distribution still hands out messages without waiting for ack. So if consumer A is slow and consumer B is fast, A gets queued up with backlog while B sits idle. With `prefetch_count=1`, the broker only sends a new message once the previous one is acked → fast consumers process more.

---

### Q28. What happens to unacked messages if a consumer disconnects?

**Answer:** RabbitMQ requeues all unacked messages from that consumer back to the head of the queue (or to a separate position depending on configuration). The next consumer picks them up. The `redelivered` flag is set so consumers can detect a possible duplicate.

---

### Q29. How do you guarantee no message loss end-to-end?

| Layer | Setting |
|-------|---------|
| Connection | Automatic recovery in client |
| Queue | `durable=true` |
| Message | `delivery_mode=2` (persistent) |
| Producer | Publisher confirms enabled |
| Consumer | Manual ack after persistence/processing |
| Broker | Quorum queues for HA |
| DR | Mirroring/streams across regions, backup of definitions |

Without all of these together, there are still loss windows.

---

## Dead Letter Exchanges, Retries, Delays

### Q30. What is a Dead Letter Exchange (DLX)?

**Answer:** An exchange where messages are sent when they:

1. Are rejected with `requeue=false`.
2. Expire (TTL).
3. Exceed the queue's `x-max-length`.

Configure with `x-dead-letter-exchange` (and optionally `x-dead-letter-routing-key`):

```python
channel.queue_declare(
    queue='orders',
    durable=True,
    arguments={
        'x-dead-letter-exchange': 'orders.dlx',
        'x-dead-letter-routing-key': 'orders.failed'
    }
)
```

Use DLX for poison messages, retry queues, and audit trails.

---

### Q31. How do you implement retries with backoff in RabbitMQ?

**Pattern: TTL + DLX hop.**

```
work_queue  ──nack──► DLX ──► retry_queue (TTL=30s) ──► back to DLX ──► work_queue
```

Each hop is bounded by a TTL. Use a `x-death` header (auto-set by RabbitMQ) to count retries; on the Nth retry, route to a parking queue instead.

A cleaner alternative: use **quorum queues** with `x-delivery-limit` — built-in poison message handling.

```python
arguments={'x-queue-type': 'quorum', 'x-delivery-limit': 5}
```

---

### Q32. How do you implement delayed messages?

Two options:

1. **TTL + DLX hop** — set per-message TTL, route expired messages to the worker queue. Limitation: messages must expire in publish order, otherwise head-of-line blocking.

2. **`rabbitmq_delayed_message_exchange` plugin** — declare an exchange of type `x-delayed-message`. Set the `x-delay` header per message. The broker holds the message in a Mnesia-backed store until it's time.

```python
channel.exchange_declare(
    exchange='scheduled',
    exchange_type='x-delayed-message',
    arguments={'x-delayed-type': 'direct'}
)

channel.basic_publish(
    exchange='scheduled',
    routing_key='reminder',
    body=payload,
    properties=pika.BasicProperties(headers={'x-delay': 60000})
)
```

The plugin scales poorly to millions of pending messages — for those scales, use a scheduler service (Quartz, Airflow, custom).

---

### Q33. What is head-of-line blocking in RabbitMQ?

**Answer:** When a single slow message blocks subsequent messages from being delivered. Causes:

- TTL-based delay queues — messages must expire in arrival order.
- Single consumer with low prefetch on a hot partition.
- A poison message that keeps requeueing without ack.

**Mitigations:** more consumers, prefetch tuning, retry queues with separate per-attempt delays, quorum queue delivery limits.

---

## Publisher Confirms and Transactions

### Q34. What are publisher confirms?

**Answer:** An RabbitMQ extension that lets a producer know the broker has accepted responsibility for the message (durably stored if persistent). Three modes:

1. **Synchronous (`waitForConfirms`)** — publish, then wait. Simple, slow.
2. **Async** — broker sends `basic.ack` (or `basic.nack`) frames asynchronously; producer maintains a map of in-flight sequence numbers to messages.
3. **Batch** — publish N messages, then call `waitForConfirms`. Higher throughput but on nack you must resend the whole batch.

```python
channel.confirm_delivery()
try:
    channel.basic_publish(...)
except pika.exceptions.UnroutableError:
    # Broker did not accept
```

---

### Q35. Publisher confirms vs AMQP transactions — which?

**Answer:** Use **publisher confirms**. AMQP transactions (`tx.select`, `tx.commit`) are around 250x slower than confirms because they synchronously fsync per commit. Confirms give the same guarantee with much higher throughput.

---

### Q36. What does `mandatory=true` do on publish?

**Answer:** If the message cannot be routed to any queue, the broker returns it to the producer via `basic.return`. Without `mandatory`, unroutable messages are silently dropped. Use mandatory for critical publishes where missed delivery must be detected.

---

## Clustering and High Availability

### Q37. How does RabbitMQ clustering work?

**Answer:** Multiple Erlang nodes form a cluster. Each node:

- Shares metadata (exchanges, bindings, vhosts, users).
- Owns its own queues unless those queues are explicitly mirrored or quorum-replicated.

A connection to any node lets the client interact with queues anywhere in the cluster — the receiving node proxies requests to the queue's master node.

```bash
rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@node1
rabbitmqctl start_app
```

---

### Q38. What's the difference between RAM and disc nodes?

**Answer:** All nodes persist messages to disk. A "disc node" persists cluster metadata to disk; a "RAM node" keeps metadata in memory only. RAM nodes are faster for metadata changes but require at least one disc node in the cluster. In modern deployments, all nodes are disc nodes — RAM nodes are an optimization rarely worth the complexity.

---

### Q39. What is the recommended cluster size?

**Answer:** Odd numbers — 3 or 5. Quorum queues need a majority to commit. A 2-node cluster has no real safety: if you lose one, the other cannot commit. Avoid 4-node clusters for the same reason.

---

### Q40. How does RabbitMQ handle a network partition?

**Answer:** Configurable via `cluster_partition_handling`:

- `ignore` (default in older versions) — partitions are not auto-resolved; cluster is effectively split-brained.
- `pause_minority` — minority nodes pause until quorum is restored. **Recommended.**
- `autoheal` — broker picks a "winner" (largest partition) and restarts losers, possibly losing messages.

Quorum queues handle partitions automatically using Raft.

---

## Federation, Shovel, Multi-DC

### Q41. What is federation?

**Answer:** Federation links exchanges or queues across two independent broker clusters. Messages flow from upstream to downstream when there's local interest (a binding or a consumer). Loosely coupled — a downstream outage doesn't break the upstream.

Use case: replicate a global events exchange to regional brokers so local consumers don't cross WAN per message.

---

### Q42. What is shovel?

**Answer:** A simple, point-to-point worker that consumes from one queue/exchange and re-publishes to another. Tighter pairing than federation, but simpler — useful for one-off migrations or pulling messages across security boundaries.

| Aspect | Federation | Shovel |
|--------|------------|--------|
| Granularity | Exchange or queue | Single queue, single destination |
| Direction | Pull on demand | Continuous pump |
| Coupling | Loose | Tighter |
| Use case | Multi-DC topology | Bridge or migration |

---

### Q43. How would you replicate messages across data centers?

**Options:**

1. **Federation** — for pub/sub style replication; easy to add new regions.
2. **Shovel** — for explicit copying between specific queues.
3. **Streams + replication** — for log-style replay.
4. **Application-level** — publish to multiple brokers from the producer (only safe with confirms and idempotent consumers).

Avoid clustering across high-latency WAN links — clustering assumes LAN-grade latency.

---

## Operations — Management UI, Monitoring

### Q44. What does the management UI offer?

**Answer:** Web UI and HTTP API for:

- View/declare exchanges, queues, bindings.
- Publish/consume messages manually for debugging.
- Inspect connections, channels, consumers.
- View per-queue rates (publish, deliver, ack), depth, memory.
- Manage users, vhosts, permissions, policies.
- Cluster topology and node health.

Enable with `rabbitmq-plugins enable rabbitmq_management` (port 15672).

---

### Q45. What metrics matter most in production?

| Metric | Why |
|--------|-----|
| Queue depth (`messages_ready`) | Backlog; rising = consumers can't keep up |
| `messages_unacknowledged` | In-flight; rising = consumers slow or stuck |
| Publish rate vs deliver rate | Throughput delta = backlog growth |
| Memory usage | OOM risk if message rate exceeds disk-flush rate |
| Disk space, disk_free_alarm | Broker pauses publishers when low |
| File descriptors, sockets | Connection capacity |
| Channel count | Channel leaks |
| Connection churn | Cost of frequent reconnects |
| Cluster partitions | Split-brain detection |
| Erlang process count | Internal health |

Tools: Prometheus + `rabbitmq_prometheus` plugin, Grafana dashboards.

---

### Q46. What is a memory alarm?

**Answer:** When broker memory passes `vm_memory_high_watermark` (default 0.4 of RAM), publishers are blocked until memory drops. The broker also has a disk free alarm and a paging threshold. Producers see this as `connection.blocked` frames — handle them in your client to avoid connection-level timeouts.

---

## Common Patterns

### Q47. Work queue pattern.

```
producers ──► default exchange ──► [work_queue] ──► many workers
```

Multiple workers compete for messages from a single durable queue with manual ack and a sane prefetch. Use for distributing CPU-bound or I/O-bound jobs.

```python
channel.queue_declare(queue='tasks', durable=True)
channel.basic_qos(prefetch_count=1)
channel.basic_consume(queue='tasks', on_message_callback=handler)
```

---

### Q48. Publish/subscribe pattern.

```
producer ──► fanout_exchange ──┬──► queue_A ──► consumer A
                                ├──► queue_B ──► consumer B
                                └──► queue_C ──► consumer C
```

Each consumer gets every message via its own queue.

---

### Q49. RPC pattern.

```
client ──pub(reply_to=callback_q, correlation_id=xyz)──► rpc.queue ──► server
client ◄────── reply on callback_q with correlation_id xyz ─────────── server
```

The client publishes a request with a `reply_to` queue and `correlation_id`. The server processes and publishes the result to that queue. Consider gRPC or HTTP for new RPC needs — RabbitMQ RPC has more moving parts.

---

### Q50. Routing pattern.

Direct exchange with multiple routing keys; consumers bind to the keys they care about.

```
publisher ──(key=error)──► direct ──► error_queue
publisher ──(key=info)───► direct ──► info_queue
```

---

### Q51. Topic pattern.

Topic exchange with wildcards. Useful for hierarchical event streams.

```
publisher ──► topic ──► queue_A (binds: "logs.*.error")
                 └────► queue_B (binds: "logs.billing.#")
```

---

## Performance Tuning

### Q52. How do you scale RabbitMQ throughput?

| Lever | Effect |
|-------|--------|
| Increase consumers | Parallel processing |
| Tune prefetch | Balance throughput vs fairness |
| Use multiple channels per connection | Less contention |
| Batch publishes with confirms | Higher publisher throughput |
| Keep messages small | Less network and disk I/O |
| Avoid persistent unless needed | Persistent ~5–10x slower than transient |
| Use lazy/quorum queues for big backlogs | Stable memory |
| Shard queues across nodes | Use a hash exchange or app-level routing |
| Avoid large fanouts to thousands of queues | Routing cost grows |
| Use streams for high-throughput logs | Append-only, replayable |

---

### Q53. What are the typical bottlenecks?

1. **Producer publishing without confirms** — fast but unsafe.
2. **Persistent messages on slow disks** — disk fsync becomes the bottleneck.
3. **Single consumer with high prefetch** — unbounded RAM use.
4. **Single hot queue** — queue is single-leader (master); cannot scale beyond one node's CPU. Solution: shard.
5. **Mirrored queues** — replication overhead. Solution: quorum queues, fewer mirrors, or partitioned queues.

---

### Q54. Persistent messages vs throughput — what's the trade-off?

Persistent messages must hit the disk before the broker confirms. On commodity SSDs that's ~5–10x slower than transient. For ultra-high throughput non-critical streams (metrics, telemetry), transient + occasional loss may be acceptable. For business events, accept the cost.

---

### Q55. When should you NOT make queues durable?

- Throwaway data (cache invalidation broadcasts).
- Per-connection scratch queues (RPC reply queues).
- Anything where a redelivery costs nothing.

---

## RabbitMQ vs Kafka and Other Brokers

### Q56. RabbitMQ vs Kafka — when to use which?

| Aspect | RabbitMQ | Kafka |
|--------|----------|-------|
| Model | Smart broker, dumb consumer | Dumb broker, smart consumer (offset) |
| Routing | Rich (exchanges, bindings) | Topic + partition only |
| Per-message ack | Yes | No (consumer commits offsets) |
| Replay | Limited (streams) | Native, by offset |
| Throughput | High but lower than Kafka | Very high |
| Latency | Sub-ms typical | A few ms typical |
| Ordering | Per-queue | Per-partition |
| Retention | Until consumed | Time/size-based, replayable |
| Best for | Task distribution, RPC, complex routing | Event sourcing, log aggregation, stream processing |

Rule of thumb: **RabbitMQ for tasks and commands, Kafka for events and streams.**

---

### Q57. RabbitMQ vs SQS?

| Aspect | RabbitMQ | SQS |
|--------|----------|-----|
| Hosting | Self-hosted or CloudAMQP/etc | Fully managed AWS |
| Routing | Rich | Single queue, no exchanges |
| Latency | Sub-ms | ~10ms |
| Ordering | FIFO via queue | Standard (no order) or FIFO queue |
| Throughput | Depends on hardware | Effectively unlimited (Standard) |
| Retention | Until consumed | Up to 14 days |
| Cost model | Server cost | Per-request |

Use SQS for AWS-native workloads needing simplicity and infinite scale. Use RabbitMQ when you need routing complexity, multi-cloud, or sub-ms latency.

---

### Q58. RabbitMQ vs Pulsar?

Pulsar combines queue and stream models with tiered storage and multi-tenancy. Strong story for very large multi-tenant platforms. Operationally heavier than RabbitMQ. RabbitMQ is the simpler, more mature choice unless you need Pulsar-specific features.

---

## Common Gotchas and Production Pitfalls

### Q59. What is a poison message and how do you handle it?

**Answer:** A message that always fails processing — e.g., malformed JSON, missing referential data, a bug in the consumer. If the consumer nacks-and-requeues forever, it loops forever and blocks the queue.

**Handling:**

- Quorum queue `x-delivery-limit` — auto-route to DLX after N redeliveries.
- Manual retry counter in headers, route to DLQ on threshold.
- Wrap consumer in try/catch and route hard failures explicitly to DLQ.

---

### Q60. Why might messages "stuck" in the queue?

- All consumers crashed; messages remain in `unacked`.
- Consumers connected but stuck (deadlock, slow downstream).
- Prefetch too high → all messages held by one stuck consumer.
- Channel-level flow control engaged.
- Memory or disk alarm blocking publishers, but consumers stalled too.

`rabbitmqctl list_queues name messages_ready messages_unacknowledged consumers` is your friend.

---

### Q61. Why are duplicate messages possible?

**Answer:** RabbitMQ provides at-least-once delivery by default. Duplicates happen when:

- Consumer processed but crashed before acking → broker requeues.
- Network glitch lost the ack → broker requeues on consumer disconnect.
- Producer retried after network blip without confirming the original.

**Solution: idempotent consumers.** Use a `message_id`, store processed IDs in a deduplication table or cache, and ignore duplicates.

---

### Q62. What happens when a queue gets too long?

**Answer:** Default behavior: queue keeps growing → memory pressure → memory alarm → producers blocked. Mitigation:

- `x-max-length` — drop oldest or dead-letter on overflow.
- `x-max-length-bytes` — same but byte-based.
- `x-overflow=reject-publish` — reject new publishes (with publisher confirms returning nack).
- Lazy or quorum queues — keep memory steady regardless of depth.

---

### Q63. What is partial failure in a multi-step workflow?

**Answer:** When you publish to two queues to fan out work and one publish succeeds but the other fails (network blip mid-batch). The consumer of the first queue acts on stale assumptions. Solutions:

- **Outbox pattern** — write events to a DB table in the same transaction, a separate worker pumps them to RabbitMQ with confirms.
- **Single fanout** — publish once to a fanout exchange that routes to both queues atomically.

---

### Q64. How do you safely upgrade a RabbitMQ cluster?

1. Drain connections from one node.
2. Stop the app on that node (`rabbitmqctl stop_app`).
3. Upgrade the package.
4. Start the app.
5. Move on to the next node.
6. Validate with quorum-aware queues that minority pauses worked.

Prefer rolling upgrades within a minor version; for major-version upgrades, consult the official upgrade guide — feature flags must be enabled in the right order.

---

### Q65. How do you debug a sudden throughput drop?

Checklist:

- Memory alarm? `rabbitmqctl status | grep memory`
- Disk alarm? Check disk_free_limit.
- Flow control? `rabbitmqctl list_channels name connection_details flow`.
- Queue master location skewed? Use `queue_master_locator`.
- Single hot queue? Shard or move to streams.
- Network: TCP retransmits, ACK delays.
- Erlang scheduler utilization (`rabbitmqctl status`).
- Client-side: connection churn, channel leaks.

---

### Q66. What is the CAP positioning of RabbitMQ?

**Answer:** Classic mirrored queues lean **AP** (available under partition, with split-brain risk depending on `cluster_partition_handling`). Quorum queues are **CP** — they lose availability in the minority partition rather than risk inconsistency. Pick the queue type based on whether your workload prefers correctness or availability.

---

### Q67. Final senior-level rules of thumb.

- Tasks and commands → RabbitMQ. Event streams and replay → Kafka or streams.
- One TCP connection per process; one channel per thread.
- Always set prefetch.
- Use quorum queues for HA, not classic mirrored.
- Always use publisher confirms for anything you don't want to lose.
- Always handle poison messages explicitly.
- Never put a network call inside a DB transaction; use the outbox pattern.
- Make consumers idempotent — at-least-once is the default.
- Monitor queue depth, unacked, and publish/deliver rates above all else.
- Don't run a 2-node cluster.
