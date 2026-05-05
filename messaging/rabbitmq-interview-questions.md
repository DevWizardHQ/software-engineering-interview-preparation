# RabbitMQ Interview Questions and Answers

A complete pedagogical guide to RabbitMQ for backend developers preparing for interviews. Each question explains the concept in plain language and pairs it with a working code example.

---

## How to Use This Guide

Read each answer, understand the idea, then practice explaining it in your own words. Code samples use Node.js with `amqplib` and Python with `pika` because those are the two most common production stacks.

To follow along, install RabbitMQ locally with Docker:

```bash
docker run -d --hostname rabbit --name rabbit -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

Open `http://localhost:15672` (guest / guest) for the management UI.

---

## 1. Fundamentals and AMQP

## Q1. What is RabbitMQ?

**Answer:**

RabbitMQ is a message broker. A producer publishes a message to RabbitMQ, RabbitMQ stores it temporarily, and a consumer reads it later. The producer and consumer never talk directly. They only know about RabbitMQ.

This is useful when you want to decouple services, smooth out traffic spikes, or run a slow task in the background. For example, when a user signs up, your API can publish a `user.registered` message and return immediately. A separate worker reads that message later and sends the welcome email.

```js
// producer.js
const amqp = require('amqplib');

const conn = await amqp.connect('amqp://localhost');
const ch = await conn.createChannel();
await ch.assertQueue('emails');
ch.sendToQueue('emails', Buffer.from(JSON.stringify({ to: 'a@b.com' })));
```

## Q2. What is AMQP?

**Answer:**

AMQP (Advanced Message Queuing Protocol) is the wire protocol RabbitMQ speaks. It defines how clients connect, how messages flow, and the building blocks: connections, channels, exchanges, queues, and bindings.

The important idea is that producers do not publish directly to a queue. They publish to an **exchange**, and the exchange routes the message to one or more queues based on **bindings**. This indirection is what makes RabbitMQ flexible.

```text
Producer -> Exchange -> (binding rules) -> Queue -> Consumer
```

## Q3. What does a message lifecycle look like?

**Answer:**

A message passes through five stages:

1. Producer publishes to an exchange with a routing key.
2. The exchange uses its type and bindings to decide which queues get the message.
3. Each matching queue stores the message (memory or disk).
4. A consumer pulls or is pushed the message.
5. The consumer acknowledges (`ack`) so the broker can delete it.

If the consumer crashes before acking, RabbitMQ redelivers the message to another consumer. That's why ack is critical for reliability.

## Q4. What is a channel and why use one?

**Answer:**

A connection is an actual TCP socket to RabbitMQ. Opening TCP connections is expensive. A channel is a lightweight virtual connection multiplexed over a single TCP connection. You should open one connection per process and one channel per thread or task.

```js
const conn = await amqp.connect('amqp://localhost'); // one TCP connection
const ch1 = await conn.createChannel();              // cheap virtual channel
const ch2 = await conn.createChannel();              // another one
```

## Q5. What is a virtual host (vhost)?

**Answer:**

A vhost is a logical grouping inside one RabbitMQ server. Each vhost has its own exchanges, queues, bindings, and permissions. Use vhosts to separate environments (`dev`, `staging`, `prod`) or tenants on the same broker.

```bash
rabbitmqctl add_vhost orders
rabbitmqctl set_permissions -p orders app_user ".*" ".*" ".*"
```

The connection URI selects the vhost: `amqp://user:pass@host:5672/orders`.

---

## 2. Architecture and Components

## Q6. What are the core RabbitMQ components?

**Answer:**

| Component | Purpose |
| --- | --- |
| Producer | Application that publishes messages |
| Exchange | Routes messages to queues based on rules |
| Binding | A rule connecting an exchange to a queue |
| Queue | Stores messages until a consumer reads them |
| Consumer | Application that processes messages |
| Broker | The RabbitMQ server itself |

```text
[Producer] --publish--> [Exchange] --binding--> [Queue] --deliver--> [Consumer]
```

## Q7. Where do messages live, in the exchange or the queue?

**Answer:**

Messages live in the **queue**. The exchange is just a routing layer. If a message is published to an exchange but no queue is bound that matches the routing key, the message is dropped (unless an alternate exchange is configured).

## Q8. How does RabbitMQ persist data?

**Answer:**

Two settings work together:

1. **Durable queue**: the queue definition survives a broker restart.
2. **Persistent message** (`deliveryMode: 2`): the message body is written to disk.

You need both. A persistent message in a non-durable queue is lost on restart because the queue itself disappears.

```js
await ch.assertQueue('orders', { durable: true });
ch.sendToQueue('orders', Buffer.from('hi'), { persistent: true });
```

---

## 3. Exchanges and Routing

## Q9. What are the four built-in exchange types?

**Answer:**

| Type | Routing rule |
| --- | --- |
| `direct` | Routing key must match queue's binding key exactly |
| `fanout` | Sends to every bound queue, ignores routing key |
| `topic` | Pattern-match routing key with wildcards (`*` and `#`) |
| `headers` | Match on message headers instead of routing key |

## Q10. Show a topic exchange example.

**Answer:**

Topic exchanges use dotted routing keys with two wildcards: `*` matches one word, `#` matches zero or more words.

```js
await ch.assertExchange('logs', 'topic', { durable: true });

// Queue 1 receives all error logs
await ch.assertQueue('errors');
await ch.bindQueue('errors', 'logs', '*.error');

// Queue 2 receives anything from the auth service
await ch.assertQueue('auth_all');
await ch.bindQueue('auth_all', 'logs', 'auth.#');

// Publishing
ch.publish('logs', 'auth.error', Buffer.from('bad password'));
// Goes to BOTH queues: matches '*.error' and 'auth.#'
```

## Q11. When would you use a fanout exchange?

**Answer:**

Use fanout for broadcast scenarios where every consumer should receive every message. A common case is cache invalidation: when a value changes, every server's local cache must drop its copy.

```js
await ch.assertExchange('cache_invalidate', 'fanout');
ch.publish('cache_invalidate', '', Buffer.from('user:42'));
// Every queue bound to this exchange receives the message
```

## Q12. What is a headers exchange?

**Answer:**

A headers exchange ignores the routing key and matches on message headers. The binding specifies header key-value pairs and an `x-match` strategy (`all` or `any`). It's flexible but rarely used because topic exchanges cover most cases more efficiently.

```js
await ch.bindQueue('vip', 'orders_hx', '', { 'x-match': 'all', tier: 'gold', region: 'us' });
ch.publish('orders_hx', '', Buffer.from('order'), { headers: { tier: 'gold', region: 'us' } });
```

## Q13. What is the alternate exchange?

**Answer:**

An alternate exchange catches messages that the primary exchange could not route. Without it, unroutable messages are silently dropped. With it, you can send unrouted messages to a "lost messages" queue for debugging.

```js
await ch.assertExchange('orders', 'direct', { alternateExchange: 'unrouted' });
await ch.assertExchange('unrouted', 'fanout');
await ch.assertQueue('unrouted_log');
await ch.bindQueue('unrouted_log', 'unrouted', '');
```

---

## 4. Queues — Properties and Behavior

## Q14. What are the key queue properties?

**Answer:**

| Property | Meaning |
| --- | --- |
| `durable` | Survives broker restart |
| `exclusive` | Only the connection that created it can use it; deleted on disconnect |
| `auto-delete` | Deleted when the last consumer disconnects |
| `x-message-ttl` | Default TTL for messages in milliseconds |
| `x-max-length` | Max number of messages |
| `x-dead-letter-exchange` | Where to send rejected/expired messages |
| `x-max-priority` | Enable priority sorting |

```js
await ch.assertQueue('jobs', {
  durable: true,
  arguments: {
    'x-message-ttl': 60_000,
    'x-max-length': 10_000,
    'x-dead-letter-exchange': 'jobs.dlx',
  },
});
```

## Q15. Difference between a durable queue and a persistent message?

**Answer:**

`durable: true` on the queue means the queue definition survives a broker restart. `persistent: true` on the message means the message body is written to disk. You need both for end-to-end durability. A durable queue with non-persistent messages will exist after a restart but be empty.

## Q16. What is an exclusive queue?

**Answer:**

An exclusive queue can only be used by the connection that declared it, and is auto-deleted when that connection closes. They are typically used for RPC reply queues so each client has its own private inbox.

```js
const { queue } = await ch.assertQueue('', { exclusive: true });
console.log('Reply queue:', queue); // unique name
```

## Q17. What is a lazy queue?

**Answer:**

A lazy queue stores messages directly on disk instead of memory. This makes it slower but lets the queue hold millions of messages without exhausting RAM. Use it when consumers may fall far behind.

```js
await ch.assertQueue('bulk', {
  durable: true,
  arguments: { 'x-queue-mode': 'lazy' },
});
```

## Q18. What are quorum queues?

**Answer:**

Quorum queues are the modern, replicated queue type in RabbitMQ. They use the Raft consensus algorithm so a majority of nodes must agree before a message is committed. They survive node failures safely and are recommended for any production queue that must not lose messages.

```js
await ch.assertQueue('payments', {
  durable: true,
  arguments: { 'x-queue-type': 'quorum' },
});
```

## Q19. Mirrored queues vs quorum queues?

**Answer:**

Mirrored (classic HA) queues use a primary/mirror replication model that has known edge cases during network partitions and is now deprecated. Quorum queues use Raft consensus, are safer, and are the recommended choice for new systems. Use quorum queues unless you are stuck on a very old RabbitMQ version.

## Q20. What are streams in RabbitMQ?

**Answer:**

Streams are an append-only log type added in RabbitMQ 3.9. Unlike normal queues, messages are not removed when consumed; consumers track their own offset, similar to Kafka. Use streams when multiple consumer groups need to replay the same events independently.

```js
await ch.assertQueue('events', {
  durable: true,
  arguments: { 'x-queue-type': 'stream' },
});
```

---

## 5. Messages — Properties and Delivery

## Q21. What message properties matter?

**Answer:**

| Property | Use |
| --- | --- |
| `messageId` | Unique ID for idempotency |
| `correlationId` | Tie a reply back to its request |
| `replyTo` | Queue to send the reply to (RPC) |
| `contentType` | e.g. `application/json` |
| `deliveryMode` | 1 = transient, 2 = persistent |
| `priority` | 0–255 for priority queues |
| `expiration` | Per-message TTL in ms (string) |
| `headers` | Custom key-value metadata |

```js
ch.sendToQueue('orders', Buffer.from(JSON.stringify(order)), {
  persistent: true,
  messageId: order.id,
  contentType: 'application/json',
  headers: { tenant: 'acme' },
});
```

## Q22. How do you implement priority queues?

**Answer:**

Declare the queue with `x-max-priority` and set the message `priority` field on publish. The broker pulls higher-priority messages first.

```js
await ch.assertQueue('tasks', {
  durable: true,
  arguments: { 'x-max-priority': 10 },
});

ch.sendToQueue('tasks', Buffer.from('urgent'), { priority: 9 });
ch.sendToQueue('tasks', Buffer.from('normal'), { priority: 1 });
```

Keep priority levels small (e.g. 0–10). Each level adds memory overhead.

## Q23. How do you set message TTL?

**Answer:**

Either set it per queue (applies to all messages) or per message (applies to that message only).

```js
// Per-queue TTL: messages older than 60s are removed
await ch.assertQueue('temp', { arguments: { 'x-message-ttl': 60_000 } });

// Per-message TTL
ch.sendToQueue('temp', Buffer.from('hi'), { expiration: '10000' });
```

Combine with a dead letter exchange to capture expired messages.

---

## 6. Acknowledgments, Prefetch, Reliability

## Q24. What are the acknowledgment modes?

**Answer:**

- **Auto-ack** (`noAck: true`): RabbitMQ deletes the message as soon as it's delivered. Fast but unsafe; if the consumer crashes, the message is lost.
- **Manual ack**: the consumer must call `ack` after processing. If the consumer dies before ack, the broker redelivers.

Always use manual ack in production.

## Q25. What's the difference between `ack`, `nack`, and `reject`?

**Answer:**

| Method | Meaning |
| --- | --- |
| `ack` | Successfully processed; remove from queue |
| `nack(requeue=true)` | Failed, put back in queue (will be retried) |
| `nack(requeue=false)` | Failed, drop or send to DLX |
| `reject` | Same as `nack` but for one message at a time |

```js
ch.consume('orders', (msg) => {
  try {
    process(msg);
    ch.ack(msg);
  } catch (err) {
    ch.nack(msg, false, false); // don't requeue, send to DLX
  }
});
```

## Q26. What is consumer prefetch (QoS)?

**Answer:**

Prefetch limits how many unacked messages RabbitMQ will deliver to a consumer at once. Without it, a fast broker pushes thousands of messages to a slow consumer, and one consumer ends up with the whole queue while others sit idle.

```js
await ch.prefetch(10); // at most 10 unacked messages per consumer
```

## Q27. Why does `prefetch=1` matter?

**Answer:**

With `prefetch=1`, RabbitMQ sends a consumer one message at a time and waits for the ack before sending the next. This guarantees fair work distribution across consumers when tasks have very different durations.

## Q28. What happens to unacked messages if a consumer disconnects?

**Answer:**

RabbitMQ detects the broken connection and requeues all unacked messages so another consumer can pick them up. This is why ack-after-success is the foundation of reliable processing.

## Q29. How do you guarantee no message loss end-to-end?

**Answer:**

Five things must all be in place:

1. Durable queue.
2. Persistent message (`deliveryMode: 2`).
3. Publisher confirms enabled, and you wait for the confirm before reporting success to the client.
4. Manual ack on the consumer side; ack only after the work is committed.
5. Replication: use quorum queues so a single node failure doesn't lose data.

```js
await ch.confirmSelect();
ch.sendToQueue('q', buf, { persistent: true }, (err) => {
  if (err) reject(err); else resolve();
});
```

---

## 7. Dead Letter Exchanges, Retries, Delays

## Q30. What is a Dead Letter Exchange (DLX)?

**Answer:**

A DLX is just a regular exchange that a queue is configured to forward "dead" messages to. A message becomes dead when it is rejected with `requeue=false`, expires (TTL), or the queue's max length is exceeded. The DLX lets you route those failures to a separate queue for inspection or replay.

```js
await ch.assertExchange('orders.dlx', 'fanout');
await ch.assertQueue('orders.dlq');
await ch.bindQueue('orders.dlq', 'orders.dlx', '');

await ch.assertQueue('orders', {
  durable: true,
  arguments: { 'x-dead-letter-exchange': 'orders.dlx' },
});
```

## Q31. How do you implement retries with backoff?

**Answer:**

RabbitMQ has no built-in retry-with-delay. The classic pattern is a "wait queue" with a TTL whose DLX points back to the main queue.

```text
[main queue] -- nack(no requeue) --> [DLX] -> [wait queue (TTL=5s)]
                                                     |
                                            (TTL expires)
                                                     v
                                                [main queue]
```

```js
await ch.assertQueue('jobs.retry', {
  arguments: {
    'x-message-ttl': 5000,
    'x-dead-letter-exchange': '',
    'x-dead-letter-routing-key': 'jobs', // back to main
  },
});
```

Track an `x-retries` header and dead-letter to a final DLQ when it exceeds a max.

## Q32. How do you implement delayed messages?

**Answer:**

Two options:

1. **TTL + DLX trick** as in Q31.
2. **Delayed Message Plugin** (`rabbitmq_delayed_message_exchange`), which adds an `x-delayed-message` exchange type:

```js
await ch.assertExchange('schedule', 'x-delayed-message', {
  arguments: { 'x-delayed-type': 'direct' },
});

ch.publish('schedule', 'send_email', Buffer.from('hi'), {
  headers: { 'x-delay': 60_000 }, // deliver in 60s
});
```

The plugin is simpler but stores delayed messages in Mnesia and doesn't scale to millions.

## Q33. What is head-of-line blocking?

**Answer:**

If a single slow message blocks a queue, every message behind it waits. This happens because RabbitMQ delivers strictly in order within a queue. The fix is to add more consumers (so parallel processing happens), use prefetch correctly, or split slow work into its own queue.

---

## 8. Publisher Confirms and Transactions

## Q34. What are publisher confirms?

**Answer:**

By default, `publish` is fire-and-forget; the broker may have crashed and you'd never know. With publisher confirms, the broker sends an `ack` back once the message is safely stored. Wait for the confirm before considering the publish successful.

```js
await ch.confirmSelect();
await new Promise((resolve, reject) => {
  ch.publish('ex', 'rk', Buffer.from('hi'), { persistent: true }, (err) =>
    err ? reject(err) : resolve()
  );
});
```

## Q35. Publisher confirms vs AMQP transactions?

**Answer:**

AMQP transactions (`tx.select`, `tx.commit`) are slow, around 200x slower than confirms, because each commit forces a broker round-trip. Publisher confirms are async and pipelined. Always prefer confirms.

## Q36. What does `mandatory: true` do on publish?

**Answer:**

If `mandatory: true` is set and the message cannot be routed to any queue, the broker returns it to the producer via a `basic.return`. Without it, unroutable messages are silently dropped (or sent to the alternate exchange if configured).

---

## 9. Clustering and High Availability

## Q37. How does RabbitMQ clustering work?

**Answer:**

Multiple RabbitMQ nodes form a cluster sharing metadata (users, vhosts, exchanges, queue definitions). By default, each queue lives on a single node. To replicate the queue's data, you must use quorum queues or streams. Clients can connect to any node; the broker proxies requests to the queue's home node.

```bash
# Join node2 to node1's cluster
rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@node1
rabbitmqctl start_app
```

## Q38. RAM nodes vs disc nodes?

**Answer:**

A disc node persists metadata to disk; a RAM node keeps it in memory. RAM nodes are faster for metadata-heavy operations but a cluster needs at least one disc node. With modern hardware the speed difference is small. Use disc nodes everywhere unless you have a specific reason not to.

## Q39. What is the recommended cluster size?

**Answer:**

Three or five nodes for quorum queues. Quorum queues use Raft, which needs an odd number to form majorities (2 of 3, 3 of 5). Two-node clusters cannot form a quorum if either node fails.

## Q40. How does RabbitMQ handle a network partition?

**Answer:**

Quorum queues automatically pick the partition that has a majority and pause writes on the minority side; this is consistent and safe. Classic mirrored queues used `pause_minority`, `autoheal`, or `ignore` policies, each with trade-offs. With quorum queues, partition handling is built in and safe.

---

## 10. Federation, Shovel, Multi-DC

## Q41. What is federation?

**Answer:**

Federation links exchanges or queues across two clusters. Messages published to a federated exchange in cluster A are forwarded to the matching exchange in cluster B. Use it for loose links between clusters that may have intermittent connectivity.

```bash
rabbitmqctl set_parameter federation-upstream remote_dc \
  '{"uri":"amqp://remote-host:5672"}'
```

## Q42. What is shovel?

**Answer:**

Shovel pulls messages from a source queue and republishes them to a destination, possibly on a different broker. It's simpler than federation; just "move messages from here to there". Use it for one-off migrations or to bridge to a different broker.

```json
{
  "src-uri": "amqp://source",
  "src-queue": "events",
  "dest-uri": "amqp://dest",
  "dest-queue": "events"
}
```

## Q43. How would you replicate messages across data centers?

**Answer:**

Run a separate cluster per DC and federate (or shovel) the events that must cross. Do not stretch one cluster across DCs; the latency between DCs breaks Raft quorum and degrades performance. Each DC processes locally; cross-DC replication is async.

---

## 11. Operations — Management UI, Monitoring

## Q44. What does the management UI offer?

**Answer:**

The management plugin gives you a web UI on port 15672 to:

- Inspect queues, message counts, and rates.
- Publish test messages.
- Define exchanges, queues, bindings, policies.
- View connections and channels.
- Export/import the broker's full topology as JSON.

```bash
rabbitmq-plugins enable rabbitmq_management
```

## Q45. What metrics matter most in production?

**Answer:**

| Metric | Why |
| --- | --- |
| Queue depth | Backlog growth is the earliest sign of trouble |
| Publish rate vs deliver rate | Mismatch means consumers are too slow |
| Unacked messages | Stuck consumers leave messages unacked |
| Connection / channel count | Spikes indicate a misbehaving client |
| Memory and disk free | Triggering an alarm pauses publishers |
| File descriptors | Each connection eats one |

## Q46. What is a memory alarm?

**Answer:**

When RabbitMQ exceeds the memory high-watermark (default 40% of RAM), it blocks publishers until consumers catch up. This protects the broker from running out of memory. If publishers freeze in production, the alarm is the first thing to check.

---

## 12. Common Patterns

## Q47. Work queue pattern.

**Answer:**

One queue, many competing consumers. Each message is processed by exactly one consumer. The queue spreads work across workers; if a worker is slow, others pick up new work. This is the most common RabbitMQ pattern.

```js
// Publisher
ch.sendToQueue('jobs', Buffer.from('process file 42'));

// Worker (run multiple instances)
ch.prefetch(1);
ch.consume('jobs', async (msg) => {
  await doWork(msg);
  ch.ack(msg);
});
```

## Q48. Publish/subscribe pattern.

**Answer:**

A fanout exchange with multiple queues, one queue per subscriber. Every subscriber gets every message.

```js
await ch.assertExchange('events', 'fanout');
const { queue } = await ch.assertQueue('', { exclusive: true });
await ch.bindQueue(queue, 'events', '');
ch.consume(queue, (msg) => console.log(msg.content.toString()));
```

## Q49. RPC pattern.

**Answer:**

Use a `replyTo` queue and a `correlationId`. The client publishes the request with both fields. The server processes and publishes the reply to `replyTo` with the same `correlationId`. The client matches replies by id.

```js
const { queue: replyQ } = await ch.assertQueue('', { exclusive: true });
const id = crypto.randomUUID();

ch.consume(replyQ, (msg) => {
  if (msg.properties.correlationId === id) {
    console.log('got reply:', msg.content.toString());
  }
}, { noAck: true });

ch.sendToQueue('rpc_queue', Buffer.from('add 1 2'), {
  correlationId: id,
  replyTo: replyQ,
});
```

## Q50. Routing pattern.

**Answer:**

A direct exchange where each queue binds to one or more routing keys. Useful for log levels: error queue binds to `error`, info queue binds to `info`.

```js
await ch.assertExchange('logs_direct', 'direct');
await ch.bindQueue('errors', 'logs_direct', 'error');
await ch.bindQueue('all', 'logs_direct', 'info');
await ch.bindQueue('all', 'logs_direct', 'error');
ch.publish('logs_direct', 'error', Buffer.from('boom'));
```

## Q51. Topic pattern.

**Answer:**

A topic exchange with hierarchical routing keys. Subscribers bind to patterns. Common in event systems where event types follow a domain hierarchy like `order.created`, `order.shipped`, `user.signup`.

```js
await ch.bindQueue('audit', 'events', '#');         // everything
await ch.bindQueue('orders_team', 'events', 'order.*');
ch.publish('events', 'order.created', Buffer.from('ok'));
```

---

## 13. Performance Tuning

## Q52. How do you scale RabbitMQ throughput?

**Answer:**

In order of impact:

1. Add more consumers to the work queue.
2. Increase prefetch to keep consumers busy.
3. Use shorter messages and avoid huge payloads.
4. Use multiple channels per connection.
5. Shard a hot queue into N queues by hash.
6. Scale the broker cluster horizontally for parallel queues (one queue still lives on one node).

## Q53. What are the typical bottlenecks?

**Answer:**

Disk I/O for persistent messages, single-node queues capping at one CPU core, slow consumers causing backlogs, and large payloads causing GC pressure. RabbitMQ is not designed for million-msgs-per-second throughput on a single queue; for that, use Kafka.

## Q54. Persistent messages vs throughput trade-off?

**Answer:**

Persistent messages are written to disk before ack, so they're slower. On SSDs the gap is smaller (about 2x) than on HDDs (about 10x). Use persistent messages for any data you can't afford to lose. Use transient messages for telemetry or throwaway notifications.

## Q55. When should queues NOT be durable?

**Answer:**

When the data is meaningless after a restart: a temporary RPC reply queue, a per-connection notification queue, or a sensor stream where stale samples don't matter. For everything else, default to durable.

---

## 14. RabbitMQ vs Other Brokers

## Q56. RabbitMQ vs Kafka — when to use which?

**Answer:**

| Scenario | Choice |
| --- | --- |
| Task queue / background jobs | RabbitMQ |
| Routing with rich filters | RabbitMQ |
| RPC / request-reply | RabbitMQ |
| Event streaming with replay | Kafka |
| Millions of messages/sec | Kafka |
| Per-message ack and complex retry | RabbitMQ |
| Stream processing | Kafka |

In short: RabbitMQ is a smart broker that routes individual messages. Kafka is a dumb log of events that consumers replay.

## Q57. RabbitMQ vs SQS?

**Answer:**

SQS is a managed AWS queue; you don't run anything yourself. It's reliable but has fewer features (no exchange types, no priority, limited routing). Use SQS if you want zero ops in AWS and basic queueing. Use RabbitMQ for richer routing, RPC, or running outside AWS.

## Q58. RabbitMQ vs Pulsar?

**Answer:**

Pulsar combines queue and stream semantics with tiered storage and built-in geo-replication. It's powerful but operationally heavier. Choose RabbitMQ for simplicity and rich routing; choose Pulsar when you need both Kafka-like streams and queue-like consumption with multi-DC built in.

---

## 15. Common Gotchas and Production Pitfalls

## Q59. What is a poison message and how do you handle it?

**Answer:**

A poison message is a message that always fails processing (bad payload, missing reference, etc.). Without protection, it gets requeued forever, blocking the queue. Limit retries by tracking an `x-retries` header or by checking the `x-death` header (added by the DLX) and dead-lettering to a final DLQ when retries exceed a threshold.

```js
const deaths = msg.properties.headers?.['x-death'] ?? [];
if ((deaths[0]?.count ?? 0) >= 5) {
  ch.publish('orders.parking_lot', '', msg.content);
  ch.ack(msg);
  return;
}
```

## Q60. Why might messages get "stuck" in the queue?

**Answer:**

Common causes:

- Consumers are connected but never call `ack`, so messages remain "unacked" and block redelivery.
- `prefetch` is too high and a slow consumer is hogging messages.
- A consumer is in an infinite loop.
- A memory or disk alarm has paused publishers (and consumers may be blocked too).

Check the management UI for "Unacked" count vs "Ready" count; high unacked means a consumer-side problem.

## Q61. Why are duplicate messages possible?

**Answer:**

If a consumer processes a message but crashes before acking, the broker redelivers it to another consumer; that's at-least-once delivery. To handle duplicates, design consumers to be idempotent: include a `messageId` on every message and skip ones you've already processed.

```js
if (await seen.exists(msg.properties.messageId)) {
  ch.ack(msg);
  return;
}
await process(msg);
await seen.set(msg.properties.messageId);
ch.ack(msg);
```

## Q62. What happens when a queue gets too long?

**Answer:**

Memory pressure rises, paging to disk slows the broker, and a memory alarm may pause all publishers. Set `x-max-length` (with a DLX) to cap the queue, use a lazy queue if backlogs are expected, and alert on queue depth so you scale consumers before disaster.

## Q63. What is partial failure in a multi-step workflow?

**Answer:**

If a saga has steps A, B, C and B succeeds but C fails, the system is half-done. RabbitMQ doesn't know about your saga, so you need compensating actions (undo B if C fails) or a state machine that retries C until it succeeds. See microservices saga patterns.

## Q64. How do you safely upgrade a RabbitMQ cluster?

**Answer:**

Rolling upgrade: take one node down, upgrade, restart, wait for it to rejoin, then move to the next. With quorum queues this is safe because the queue continues to operate as long as a majority of replicas remain online. Always check that minor and patch versions are compatible.

## Q65. How do you debug a sudden throughput drop?

**Answer:**

Walk the metrics:

1. Is publish rate down? Check producers.
2. Is deliver rate down but queue growing? Check consumers (slow, crashed, stuck).
3. Are there memory or disk alarms?
4. Is a single queue hot? Check per-queue stats; sharding may help.
5. Are connections / channels normal?
6. Network: any retransmits or partition?

The management UI's per-queue rate graph is the single most useful tool.

## Q66. Where does RabbitMQ sit in CAP?

**Answer:**

RabbitMQ favors consistency over availability. With quorum queues, a partitioned minority refuses writes rather than risk diverging state. Plan for a brief unavailability during failover rather than tolerating split-brain data.

## Q67. What's a sensible default configuration?

**Answer:**

A safe baseline for production:

- Quorum queues with replication factor 3.
- Durable queues, persistent messages.
- Manual ack with `prefetch` between 10 and 50.
- Publisher confirms enabled.
- DLX on every business queue.
- `x-max-length` on every queue to cap backlogs.
- Management plugin enabled with read-only monitoring user.
- Prometheus exporter scraping every 15s.

```js
await ch.assertQueue('orders', {
  durable: true,
  arguments: {
    'x-queue-type': 'quorum',
    'x-max-length': 1_000_000,
    'x-dead-letter-exchange': 'orders.dlx',
  },
});
await ch.confirmSelect();
await ch.prefetch(20);
```
