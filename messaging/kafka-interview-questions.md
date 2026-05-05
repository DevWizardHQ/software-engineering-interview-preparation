# Apache Kafka Interview Questions and Answers

A complete pedagogical guide to Apache Kafka. Each question explains the concept in plain language and pairs it with a working code example. If you have never used Kafka, start at Q1 and read in order; later sections build on earlier ones.

---

## How to Use This Guide

Code samples use Node.js with `kafkajs` and Java where the official client is more idiomatic. To follow along, run a local Kafka broker with Docker:

```bash
docker run -d --name kafka -p 9092:9092 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT \
  apache/kafka:latest
```

---

## 1. Fundamentals

## Q1. What is Kafka?

**Answer:**

Kafka is a distributed log. Producers append records (events) to a topic, brokers store them on disk in append-only files, and consumers read at their own pace. Unlike a queue, records are not removed when read; consumers track their own offset and can replay history.

Kafka was built at LinkedIn for high-throughput event streaming. Today it's used for activity tracking, change data capture, log aggregation, and as the backbone of event-driven architectures.

```js
// Producer in Node.js
const { Kafka } = require('kafkajs');
const kafka = new Kafka({ brokers: ['localhost:9092'] });
const producer = kafka.producer();
await producer.connect();
await producer.send({
  topic: 'page-views',
  messages: [{ key: 'user-42', value: JSON.stringify({ url: '/home' }) }],
});
```

## Q2. How is Kafka different from a traditional queue?

**Answer:**

| | Queue (RabbitMQ, SQS) | Kafka |
| --- | --- | --- |
| Storage | Removed when consumed | Retained for a configurable period |
| Read model | Push-based | Pull-based with offsets |
| Replay | Hard | Built-in (rewind the offset) |
| Throughput | Tens of thousands/sec | Millions/sec |
| Routing | Rich (exchanges, headers) | Topic + partition only |
| Per-message ack | Yes | No (offsets only) |

Kafka is a log; RabbitMQ is a router. Choose Kafka when many independent consumers need the same stream of events.

## Q3. What guarantees does Kafka provide out of the box?

**Answer:**

- **Order is preserved within a partition**, not across partitions of the same topic.
- **At-least-once delivery** by default (consumer might reprocess on retry).
- **Durability** when records are replicated to a configurable number of brokers.
- **High availability** via leader election: one replica is the leader, others sync.

Exactly-once is achievable but only with idempotent producers and transactions configured.

---

## 2. Architecture and Components

## Q4. Describe the core architecture.

**Answer:**

```text
        +-------------+
producer ->| broker 1   |\
        |             | \
        | (leader for | -- ZooKeeper / KRaft (metadata)
        |  partition) | /
        +-------------+/
              |
              | replication
              v
        +-------------+
        | broker 2    |  (follower)
        +-------------+
```

| Component | Role |
| --- | --- |
| Broker | A Kafka server that hosts partitions |
| Topic | A logical feed of records |
| Partition | An ordered, append-only log file inside a topic |
| Producer | Writes records to a topic |
| Consumer | Reads records from a topic |
| Consumer group | Set of consumers that share work |
| Controller | Broker elected to manage cluster metadata |
| ZooKeeper / KRaft | Stores cluster metadata |

## Q5. What is a Kafka record?

**Answer:**

A record (message) has a key, a value, a timestamp, an offset (assigned by the broker), and optional headers.

```json
{
  "key": "user-42",
  "value": "{ \"url\": \"/home\" }",
  "timestamp": 1737000000000,
  "headers": { "trace-id": "abc-123" }
}
```

Keys matter: records with the same key are routed to the same partition, which preserves their order.

---

## 3. Topics, Partitions, Offsets

## Q6. What is a partition?

**Answer:**

A partition is a single ordered log file. A topic is split into N partitions so it can be spread across brokers and read in parallel. Each partition has one leader and zero or more replicas. Within one partition, records are strictly ordered by offset.

```bash
# Create a topic with 6 partitions, replication factor 3
kafka-topics.sh --create --topic orders --partitions 6 --replication-factor 3 \
  --bootstrap-server localhost:9092
```

## Q7. How is a record placed in a partition?

**Answer:**

1. If the producer specifies a partition, that one is used.
2. Else if a key is set, the partition is `hash(key) % numPartitions`.
3. Else round-robin (sticky batching) across partitions.

If you need ordering for a related stream of events (e.g. all events for one order), use the same key.

```js
await producer.send({
  topic: 'orders',
  messages: [{ key: order.id, value: JSON.stringify(order) }],
});
```

## Q8. What is an offset?

**Answer:**

An offset is the position of a record in a partition, starting at 0 and increasing by 1 for each record. Consumers commit the offset they've processed so they can resume from there after a restart.

## Q9. How do you choose the number of partitions?

**Answer:**

The number of partitions caps consumer parallelism: at most one consumer per partition per group. Pick partitions equal to your peak required parallelism, plus headroom for growth. Common starting points: 6 to 12 for moderate topics, 30 to 60 for high-volume topics.

Too few partitions: bottleneck. Too many: increased metadata, slower failovers, and each partition has fixed overhead per broker.

## Q10. Can you reduce the number of partitions?

**Answer:**

No. You can only increase partitions. Reducing would lose ordering guarantees because keyed records would suddenly land in different partitions. To reduce, create a new topic and migrate.

## Q11. What happens to ordering when adding partitions?

**Answer:**

New keys hash into the new partition, but existing keys may still hash to old partitions or new ones depending on `numPartitions`. Adding partitions breaks the "same key always goes to same partition" guarantee for in-flight data, so plan additions during low-traffic windows.

---

## 4. Producers — Internals and Tuning

## Q12. How does the producer work internally?

**Answer:**

1. Application calls `send()`.
2. The record is serialized.
3. A partitioner picks the partition.
4. The record is added to a per-partition buffer.
5. A background I/O thread groups buffered records into a batch and sends to the broker.
6. The broker responds with the assigned offset.
7. The producer's callback fires.

This batching is why Kafka is fast: thousands of records per network round-trip.

## Q13. Key producer configs.

**Answer:**

| Config | Effect |
| --- | --- |
| `acks` | How many replicas must ack (0, 1, all) |
| `linger.ms` | Wait this long to fill a batch |
| `batch.size` | Max bytes per batch |
| `compression.type` | `none`, `gzip`, `snappy`, `lz4`, `zstd` |
| `enable.idempotence` | Prevents producer-side duplicates |
| `max.in.flight.requests.per.connection` | Bounded for ordering |
| `retries` | How many times to retry a failed send |

```js
const producer = kafka.producer({
  idempotent: true,
  maxInFlightRequests: 5,
  allowAutoTopicCreation: false,
});
```

## Q14. What does `acks` control?

**Answer:**

How many replicas must confirm the write before the broker acks the producer.

| `acks` | Behavior | Trade-off |
| --- | --- | --- |
| `0` | Don't wait | Fast, lose data on failure |
| `1` | Leader acks | Default; loses data if leader dies before replicating |
| `all` | All in-sync replicas ack | Slowest but durable |

For data you can't lose, use `acks=all` plus `min.insync.replicas=2`.

## Q15. What does `linger.ms` do?

**Answer:**

Tells the producer to wait up to N milliseconds for more records to fill the batch before sending. A small wait dramatically improves throughput. Default is 0; setting `linger.ms=5` is a common sweet spot.

## Q16. What does `max.in.flight.requests.per.connection` mean?

**Answer:**

How many unacknowledged requests the producer can have to a single broker. With idempotence enabled, you can safely have up to 5; without it, set to 1 if you need strict ordering after retries (otherwise a retried request can land after a later one).

---

## 5. Consumers and Consumer Groups

## Q17. What is a consumer group?

**Answer:**

A consumer group is a logical "subscriber". Kafka assigns each partition of a topic to exactly one consumer in the group. If you have 6 partitions and 3 consumers in the group, each consumer reads 2 partitions.

```js
const consumer = kafka.consumer({ groupId: 'order-processor' });
await consumer.subscribe({ topic: 'orders' });
await consumer.run({
  eachMessage: async ({ message }) => {
    console.log(message.value.toString());
  },
});
```

To process the same topic for two different purposes, use two different group ids; each group has independent offsets.

## Q18. What is rebalancing?

**Answer:**

When a consumer joins or leaves a group, partitions are reassigned across the remaining consumers. This is called a rebalance. During a rebalance, processing pauses briefly. Frequent rebalances are a sign of misconfigured timeouts or a slow consumer.

Modern Kafka uses **incremental cooperative rebalancing**, which only revokes the partitions that change owner instead of stopping all consumers.

## Q19. What is offset commit and what are the modes?

**Answer:**

Committing an offset tells Kafka "I've processed up to here". On restart the consumer resumes from the last committed offset.

| Mode | When |
| --- | --- |
| Auto-commit (`enable.auto.commit=true`) | Periodic background commit; risk of reprocessing or skipping |
| Manual sync commit | Block until the broker confirms; safest |
| Manual async commit | Fire-and-forget; faster but may lose offsets |

```js
await consumer.run({
  autoCommit: false,
  eachMessage: async ({ topic, partition, message }) => {
    await process(message);
    await consumer.commitOffsets([{ topic, partition, offset: (Number(message.offset) + 1).toString() }]);
  },
});
```

## Q20. What is `auto.offset.reset`?

**Answer:**

What to do when a consumer starts with no committed offset.

| Value | Behavior |
| --- | --- |
| `earliest` | Read from the beginning of the partition |
| `latest` | Skip everything before joining |
| `none` | Throw an error |

Use `earliest` for batch processors and analytics; `latest` for live dashboards.

## Q21. What is `max.poll.interval.ms` and why does it matter?

**Answer:**

The maximum time between two `poll()` calls. If a consumer takes longer than this to process a batch, Kafka assumes it's dead and triggers a rebalance. Set it generously if your processing is slow, or split work across more partitions.

## Q22. Can two consumers in the same group read the same partition?

**Answer:**

No. Within a consumer group, each partition is assigned to exactly one consumer. To process the same data twice, use two consumer groups.

## Q23. How do you achieve consumer parallelism greater than partition count?

**Answer:**

You can't, within a group, because partitions are the unit of parallelism. Workarounds:

1. Repartition the topic with more partitions (planning ahead is best).
2. Inside the consumer, hand records off to a worker pool. Be careful: you must commit offsets only after all workers have finished, or you risk data loss.

---

## 6. Replication, ISR, Leader Election

## Q24. What is replication factor?

**Answer:**

How many copies of each partition exist across brokers. RF=3 is the default for production: one leader and two followers. The producer writes to the leader; the leader fans out to followers.

## Q25. What is the ISR?

**Answer:**

In-Sync Replicas: the set of replicas that are caught up to the leader within `replica.lag.time.max.ms`. A write with `acks=all` must be acknowledged by all ISR. If a follower lags, it falls out of ISR; it rejoins when it catches up.

## Q26. What happens when a leader fails?

**Answer:**

The controller detects the failure and elects a new leader from the ISR. Producers receive a `NOT_LEADER_FOR_PARTITION` error and re-fetch metadata. Failover takes a few seconds.

If `unclean.leader.election=true`, a non-ISR replica may be elected to keep the partition available, but data loss is possible. Default is `false`; prefer durability over availability.

## Q27. What is the controller?

**Answer:**

One broker is elected controller. It manages partition leader assignments, handles broker failures, and tracks ISR membership. In KRaft mode, the controller role is dedicated and replicated separately from data brokers.

## Q28. Sync vs async replication?

**Answer:**

Kafka replication is asynchronous from the leader's perspective; followers pull data. With `acks=all`, the leader waits for all ISR followers to fetch and ack before responding to the producer, which is effectively synchronous from the producer's view.

---

## 7. Delivery Semantics

## Q29. Define at-most-once, at-least-once, exactly-once.

**Answer:**

| Semantic | Definition | When |
| --- | --- | --- |
| At-most-once | May lose, never duplicate | Commit offset before processing |
| At-least-once | May duplicate, never lose | Commit after processing (default) |
| Exactly-once | No loss, no duplicates | Idempotent producer + transactions |

## Q30. Why is exactly-once hard?

**Answer:**

Network can fail at any point: producer-to-broker, broker replication, consumer ack. To avoid duplicates, the producer must be idempotent (broker dedups retries) and the consumer offset commit must be in the same transaction as the side effect. The "side effect" is hard if it's an external system.

## Q31. How does Kafka achieve exactly-once for Kafka-to-Kafka?

**Answer:**

Two pieces:

1. **Idempotent producer** (`enable.idempotence=true`): the broker tags messages with a producer id and sequence number, so retries don't duplicate.
2. **Transactions**: producer's writes to multiple topics, and its consumer offset commit, are atomic.

```java
producer.initTransactions();
producer.beginTransaction();
producer.send(new ProducerRecord<>("output", key, value));
producer.sendOffsetsToTransaction(offsets, "input-group");
producer.commitTransaction();
```

This works for stream processing inside Kafka (input topic to output topic). For sinks outside Kafka, you need an idempotent or transactional writer.

---

## 8. Idempotence and Transactions

## Q32. What does the idempotent producer do?

**Answer:**

The broker assigns the producer a Producer ID (PID) and tracks a sequence number per partition. Duplicate sequence numbers are rejected. So even if a network blip causes the producer to retry, the broker writes the message once.

```js
const producer = kafka.producer({ idempotent: true });
```

## Q33. What's the cost of transactions?

**Answer:**

Transactions add latency (around 50ms overhead) because they require a coordinator to log begin/end markers. They also reserve a producer id slot and can fail if the coordinator is unavailable. Use them when you really need exactly-once for Kafka-to-Kafka pipelines, not for general writes.

---

## 9. Retention and Log Compaction

## Q34. How does retention work?

**Answer:**

Each topic has a retention policy that deletes old segments:

- `retention.ms`: time-based (e.g. 7 days).
- `retention.bytes`: size-based per partition.

Once a segment is older than the retention or the partition exceeds the byte limit, the broker deletes the segment.

```bash
kafka-configs.sh --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name orders \
  --alter --add-config retention.ms=604800000 # 7 days
```

## Q35. What is log compaction?

**Answer:**

Compaction keeps only the latest record for each key, instead of deleting by time. It's used for tables stored as a stream of changes: e.g. "current user profile" where only the latest version per `user_id` matters.

```text
Before compaction:
(user1, v1) (user2, v1) (user1, v2) (user1, v3)

After compaction:
(user2, v1) (user1, v3)
```

To delete a key, write a record with that key and a `null` value (a "tombstone").

```bash
kafka-configs.sh --alter --add-config cleanup.policy=compact ...
```

## Q36. Can you mix delete and compact?

**Answer:**

Yes: `cleanup.policy=compact,delete`. Compaction removes obsolete versions, and a max retention also deletes very old data. This is useful for hybrid topics where you want a "snapshot of current state" but don't want infinite growth.

---

## 10. ZooKeeper vs KRaft

## Q37. What was ZooKeeper used for?

**Answer:**

ZooKeeper stored Kafka's metadata: brokers, topics, partitions, ACLs, and the controller election. Every metadata change went through ZooKeeper. It's a separate cluster you have to operate.

## Q38. What is KRaft?

**Answer:**

KRaft (Kafka Raft) replaces ZooKeeper with a Kafka-native consensus mechanism. A small set of controller brokers maintain metadata using Raft, removing the need for a separate ZooKeeper cluster. It's the default in modern Kafka and is faster on startup, supports more partitions, and has fewer moving parts.

## Q39. How do you migrate from ZooKeeper to KRaft?

**Answer:**

The official path is "ZooKeeper to KRaft migration mode": run the new controllers alongside the existing brokers, dual-write metadata, then cut over. It's a multi-step rolling migration documented in KIP-866. For new clusters, start with KRaft.

---

## 11. Kafka Ecosystem

## Q40. What is Kafka Connect?

**Answer:**

Kafka Connect is a framework for moving data between Kafka and other systems using pre-built **connectors** (source connectors read into Kafka; sink connectors write from Kafka). It runs as workers; connectors are configured via REST or YAML.

```json
{
  "name": "postgres-source",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "db",
    "topic.prefix": "cdc"
  }
}
```

Common connectors: JDBC, Debezium (CDC), S3, Elasticsearch, MongoDB.

## Q41. What is Kafka Streams?

**Answer:**

Kafka Streams is a Java library for building streaming applications. It reads from Kafka topics, transforms data (filter, map, join, aggregate), and writes back. State is stored locally with a backing changelog topic, so it's fault-tolerant.

```java
StreamsBuilder b = new StreamsBuilder();
b.<String, String>stream("orders")
  .filter((k, v) -> v.contains("paid"))
  .mapValues(v -> enrich(v))
  .to("paid-orders");
```

It's not a separate cluster — it's just an application using Kafka.

## Q42. What is ksqlDB?

**Answer:**

ksqlDB is a SQL layer over Kafka Streams. You define streams and tables in SQL, and ksqlDB compiles them to Streams topologies.

```sql
CREATE STREAM paid_orders AS
  SELECT *
  FROM orders
  WHERE status = 'PAID' EMIT CHANGES;
```

Lower barrier than writing Java; useful for analysts and quick prototypes.

## Q43. What is MirrorMaker 2?

**Answer:**

A Kafka Connect-based tool that replicates topics across clusters (for example, multi-DC or cloud-to-on-prem). It preserves topic configuration and offsets and supports active-active topologies.

---

## 12. Schema Registry

## Q44. Why use a schema registry?

**Answer:**

Kafka stores raw bytes; without schemas, every consumer has to know the format and a producer change can break consumers silently. A schema registry stores Avro/Protobuf/JSON schemas centrally. The producer registers the schema, the message is tagged with a schema id, and consumers fetch the schema by id and deserialize safely.

This catches incompatible schema changes at publish time.

## Q45. What are the compatibility modes?

**Answer:**

| Mode | Allowed change |
| --- | --- |
| `BACKWARD` | New schema can read old data (default) |
| `FORWARD` | Old schema can read new data |
| `FULL` | Both directions |
| `NONE` | Anything goes |

`BACKWARD` is the default because it lets you upgrade consumers first.

## Q46. Avro vs Protobuf vs JSON Schema?

**Answer:**

| | Avro | Protobuf | JSON Schema |
| --- | --- | --- | --- |
| Wire format | Compact binary | Compact binary | JSON text |
| Schema needed to read | Yes (or registry) | Tagged ids | No |
| Tooling | Strong in JVM | Strong everywhere | Native to web |
| Default in Kafka world | Yes | Growing | Used |

Avro is the historical Kafka default and pairs well with the Confluent registry.

---

## 13. Performance Tuning

## Q47. How does Kafka achieve such high throughput?

**Answer:**

1. Sequential disk I/O instead of random.
2. Page cache: producers and consumers share the OS file cache.
3. Zero-copy from disk to socket via `sendfile`.
4. Batching at producer and consumer.
5. Compression on the producer side.

Kafka is essentially streaming bytes from disk to a network card with minimal CPU work.

## Q48. Producer tuning checklist.

**Answer:**

- `linger.ms=5..50` to allow batching.
- `batch.size=64KB..1MB` for high throughput.
- `compression.type=lz4` or `zstd`.
- `acks=all`, `enable.idempotence=true` for durability.
- `max.in.flight.requests.per.connection=5` (with idempotence).
- Keep payloads under 1MB; large messages hurt throughput.

## Q49. Consumer tuning checklist.

**Answer:**

- `fetch.min.bytes` to avoid tiny fetches.
- `max.poll.records` to bound batch size.
- Manual offset commits for at-least-once.
- Don't block in `eachMessage`; offload heavy work but commit only after success.
- Right-size partitions for the parallelism you need.

## Q50. Broker-side tuning.

**Answer:**

- Use SSDs and a separate disk for logs.
- `num.network.threads` and `num.io.threads` ~= number of cores.
- Heap around 6 GB; rely on the OS page cache for the rest.
- `log.flush.interval.messages=Long.MAX_VALUE` so writes are flushed by the OS, not Kafka.
- Monitor under-replicated partitions and ISR shrinks.

---

## 14. Monitoring and Operations

## Q51. What metrics matter?

**Answer:**

| Metric | Why |
| --- | --- |
| Consumer lag | The single most important metric: how far behind consumers are |
| Under-replicated partitions | Replication is broken or slow |
| ISR shrinks per second | Followers falling behind |
| Request latency | Producer / consumer slowness |
| Bytes in / bytes out | Capacity planning |
| Active controllers | Should be exactly 1 |
| Disk usage | Retention won't save you in time |

## Q52. What does consumer lag mean and how do you reduce it?

**Answer:**

Consumer lag is the difference between the latest produced offset and the consumer's committed offset for a partition. Persistent lag means the consumer can't keep up with production rate.

Reduce lag by:

1. Adding more consumers (up to the partition count).
2. Increasing partitions so you can add more consumers.
3. Speeding up per-message processing.
4. Increasing `fetch.min.bytes` and `max.poll.records`.

## Q53. What are ISR shrinks and why are they bad?

**Answer:**

A follower replica falls out of ISR when it can't keep up. The cluster runs with fewer guarantees: a write with `acks=all` only requires the remaining ISR. Repeated shrinks indicate disk, network, or CPU bottlenecks on a broker.

## Q54. What's a typical production cluster topology?

**Answer:**

- 3 to 5 brokers per cluster.
- 3 KRaft controllers (or a 3-node ZooKeeper).
- Topics replicated 3x with `min.insync.replicas=2`.
- Spread brokers across availability zones.
- Separate clusters per environment (dev/staging/prod).
- Schema Registry and Connect on dedicated nodes.

---

## 15. Common Patterns

## Q55. Event sourcing with Kafka.

**Answer:**

Store every state-changing event as a record in a topic. The current state is derived by replaying events. Kafka's compacted topics work well for keeping the latest snapshot per entity.

```text
events: (order-1, created) (order-1, paid) (order-1, shipped)
```

A consumer can replay from offset 0 to rebuild any view.

## Q56. Change Data Capture (CDC).

**Answer:**

Mirror database changes into Kafka by reading the database's transaction log. Tools like Debezium produce one record per row change.

```text
(users.42, INSERT, {name: 'Iqbal'})
(users.42, UPDATE, {name: 'Iqbal H.'})
```

Downstream services consume changes without polling the source database.

## Q57. Outbox pattern.

**Answer:**

A common problem: how do you save to your DB and publish a Kafka event atomically? Don't dual-write. Instead:

1. In the same DB transaction, write to the business table and an `outbox` table.
2. A separate process (or Debezium) reads from `outbox` and publishes to Kafka.

```sql
BEGIN;
INSERT INTO orders (...) VALUES (...);
INSERT INTO outbox (event_type, payload) VALUES ('OrderCreated', '{...}');
COMMIT;
```

The outbox guarantees the event is published if and only if the DB commit succeeded.

## Q58. Stream-table join.

**Answer:**

Join an event stream with a slowly-changing table. Example: enrich `clicks` events with `users` profile data.

```java
KStream<String, Click> clicks = builder.stream("clicks");
KTable<String, User> users = builder.table("users");
clicks.leftJoin(users, (click, user) -> enrich(click, user))
      .to("clicks-enriched");
```

The table is materialized locally as a state store so the join is fast.

## Q59. Log aggregation.

**Answer:**

Application logs flow into Kafka topics, then are sunk to Elasticsearch, S3, or a SIEM via Kafka Connect. Kafka decouples log producers from log consumers and survives downstream outages by buffering.

## Q60. Notification system.

**Answer:**

Producer publishes `notification.requested` events. Multiple consumer groups handle email, SMS, and push, each scaling independently. Failures don't block other channels because each group commits its own offsets.

---

## 16. Kafka vs Other Brokers

## Q61. Kafka vs RabbitMQ?

**Answer:**

| Need | Choice |
| --- | --- |
| Many consumers replay the same events | Kafka |
| Smart routing with patterns | RabbitMQ |
| Per-message TTL / priority | RabbitMQ |
| Millions of msgs/sec | Kafka |
| Background job queue | RabbitMQ |
| Stream processing | Kafka |
| Event sourcing / CDC | Kafka |

## Q62. Kafka vs Pulsar?

**Answer:**

Pulsar separates compute (brokers) from storage (BookKeeper) and supports both queue and stream semantics natively, with multi-region built in. Kafka is more mature, has a richer ecosystem, and is operationally simpler. Most teams pick Kafka unless they need Pulsar's specific features.

## Q63. Kafka vs SQS / Kinesis?

**Answer:**

- **SQS**: simple managed queue. No replay, no ordering across partitions. Use when you want zero ops.
- **Kinesis**: AWS-native streaming, similar model to Kafka. Lower throughput per shard, simpler ops, tightly integrated with AWS services. Use Kinesis if you're all-in on AWS and want Amazon to operate it.
- **Kafka**: best ecosystem, highest throughput, more work to operate. Use for serious streaming workloads or if you need portability.

---

## 17. Common Pitfalls

## Q64. "All my keys go to one partition" — why?

**Answer:**

Probably your key has low cardinality (e.g. `null`, a constant string, or a single tenant id) and the hash always lands on the same partition. Solution: choose a higher-cardinality key (user id, request id) or use `null` keys to round-robin.

## Q65. "Consumer rebalances constantly" — why?

**Answer:**

Most common causes:

- Processing a single batch takes longer than `max.poll.interval.ms`.
- The consumer group's network is unstable.
- A consumer was OOM-killed and restarted in a loop.

Increase `max.poll.interval.ms`, reduce `max.poll.records`, or split the work into smaller batches.

## Q66. "Messages are lost" — what's likely?

**Answer:**

- Producer is using `acks=0` or `acks=1` and the leader died.
- `unclean.leader.election=true` and a non-ISR replica became leader.
- Consumer commits the offset before it processes the record.
- `min.insync.replicas` not set and only the leader had the data.

## Q67. "Messages are duplicated" — what's likely?

**Answer:**

- Producer retries without idempotence.
- Consumer crashes after processing but before committing.
- Rebalance after processing without commit.

Fixes: enable idempotent producer, commit offsets only after the work is durable, and design downstream consumers to be idempotent.

## Q68. "Topic creation works in test, fails in prod" — why?

**Answer:**

Production usually has `auto.create.topics.enable=false`. Test environments may auto-create topics on first use. Always create topics explicitly in prod with the right partition count and replication factor.

## Q69. How do you handle schema-breaking changes safely?

**Answer:**

- Register schemas in the Schema Registry with `BACKWARD` compatibility.
- Add fields with defaults; never rename or remove without a migration plan.
- For hard-breaking changes: produce to a v2 topic in parallel, migrate consumers, then retire the v1 topic.

## Q70. When NOT to use Kafka?

**Answer:**

- You need request-reply RPC (use REST/gRPC).
- You need per-message routing with rules (use RabbitMQ).
- You have low message volume and don't need replay (use SQS or RabbitMQ).
- You can't operate it (use a managed service, Confluent Cloud or MSK).

## Q71. Sensible defaults for production.

**Answer:**

- Replication factor 3, `min.insync.replicas=2`.
- `acks=all`, idempotent producer enabled.
- 6-12 partitions for moderate topics, 30+ for high-volume.
- Retention 7 days unless you have a reason for more.
- Monitor consumer lag, under-replicated partitions, and disk usage.
- One consumer group per logical use of the topic; never share.
- Use the schema registry from day one.
