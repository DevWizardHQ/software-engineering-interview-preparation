# WebSockets and Real-Time Communication — Interview Questions

**Purpose:** Senior-level coverage of WebSockets and the broader real-time communication landscape: HTTP polling vs SSE vs WebSocket vs WebRTC, scaling, authentication, deployment, and production pitfalls.

---

## Table of Contents

1. [Real-Time Transport Mechanisms](#real-time-transport-mechanisms)
2. [WebSocket Protocol — Internals](#websocket-protocol--internals)
3. [Connection Lifecycle](#connection-lifecycle)
4. [Reconnection and Reliability](#reconnection-and-reliability)
5. [Socket.io vs Raw WebSockets](#socketio-vs-raw-websockets)
6. [Authentication and Authorization](#authentication-and-authorization)
7. [Scaling WebSockets](#scaling-websockets)
8. [Deployment — Load Balancers and Proxies](#deployment--load-balancers-and-proxies)
9. [Kubernetes Considerations](#kubernetes-considerations)
10. [Common Patterns](#common-patterns)
11. [Security](#security)
12. [Monitoring and Operations](#monitoring-and-operations)
13. [WebRTC and When to Use What](#webrtc-and-when-to-use-what)
14. [Common Pitfalls](#common-pitfalls)

---

## Real-Time Transport Mechanisms

### Q1. What are the options for real-time communication over HTTP/TCP?

| Mechanism | Direction | Connection model | Browser support |
|-----------|-----------|------------------|-----------------|
| Short polling | C→S only (server data fetched on each call) | New HTTP request every interval | Universal |
| Long polling | S→C delayed | HTTP request held open until server has data | Universal |
| Server-Sent Events (SSE) | S→C only | Long-lived HTTP, text/event-stream | Universal except old IE |
| WebSocket | Bidirectional, full-duplex | Single TCP connection upgraded from HTTP | Universal |
| HTTP/2 server push | S→C | Promised resources over HTTP/2 | Phased out |
| WebRTC | Bidirectional, peer-to-peer | UDP (with STUN/TURN), direct between clients | Modern browsers |
| gRPC streaming | Bidirectional | HTTP/2 streams | Browser via grpc-web (server-stream only) |

---

### Q2. Compare short polling, long polling, SSE, and WebSocket.

| Aspect | Short polling | Long polling | SSE | WebSocket |
|--------|---------------|--------------|-----|-----------|
| Latency | High (interval) | Lower (on-demand) | Low | Lowest |
| Server load | High (always reconnecting) | Medium (held open) | Low | Lowest |
| Direction | Half-duplex | Half-duplex | S→C only | Full-duplex |
| Headers per message | Full HTTP each time | Full HTTP each call | Initial only | Initial only |
| Proxy/firewall friendliness | Best | Good | Good | Sometimes blocked |
| Browser reconnection | Manual | Manual | Built-in `EventSource` | Manual or library |
| Binary data | Awkward (base64) | Awkward | Text only | Native binary frames |
| Typical use | Status checks | Fallback, low-rate updates | Notifications, news feeds | Chat, games, collab editing |

---

### Q3. When would you choose SSE over WebSocket?

**Answer:** When the data flow is server-to-client only, the client is a browser, and you want simplicity. SSE:

- Auto-reconnects with `Last-Event-ID` for replay.
- Multiplexes naturally over HTTP/2.
- Easier to debug (it's just HTTP text).
- Works over standard CDNs/proxies more often than WebSockets.

Examples: stock tickers, live scores, push notifications. If you also need C→S messages, you can pair SSE with regular HTTP POSTs.

---

### Q4. When NOT to use WebSocket?

- One-way data flow → SSE is simpler.
- Request/response semantics → HTTP/gRPC is simpler.
- Very infrequent updates → polling is fine and easier to operate.
- Hostile network environments → polling works through more proxies.
- True peer-to-peer media (audio/video) → WebRTC.

---

## WebSocket Protocol — Internals

### Q5. How does a WebSocket handshake work?

A WebSocket starts as an HTTP/1.1 request that asks to be upgraded:

```
Client → Server:
GET /chat HTTP/1.1
Host: example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Origin: https://example.com

Server → Client:
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

After the 101 status code, the same TCP connection is reused for binary WebSocket frames. The `Sec-WebSocket-Accept` is a SHA-1 hash of the client's key + a fixed GUID — proves the server understood the upgrade.

---

### Q6. What does a WebSocket frame look like?

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127  |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
|     Masking-key (continued)   |          Payload Data         |
+-------------------------------+ - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

Key bits:

- **FIN** — last frame of a message (messages can be split into multiple frames).
- **Opcode** — `0x1` text, `0x2` binary, `0x8` close, `0x9` ping, `0xA` pong, `0x0` continuation.
- **MASK** — client→server frames must be masked (XOR with 32-bit key) to prevent cache poisoning attacks on intermediaries.
- **Payload length** — 7 bits, or 16, or 64 bits for big payloads.

---

### Q7. What are control frames?

**Answer:** Frames used for protocol-level signaling, not application data:

- **Close (0x8)** — initiates orderly close, optional status code (1000 normal, 1006 abnormal).
- **Ping (0x9)** — keepalive probe.
- **Pong (0xA)** — response to ping.

Control frames are at most 125 bytes and never fragmented.

---

### Q8. What is a ping/pong and why use it?

**Answer:** A keepalive mechanism. The server (or client) periodically sends a ping; the peer must respond with a pong. If no pong arrives within a timeout, the connection is presumed dead and closed. Why this matters:

- TCP can keep half-open connections "alive" indefinitely if no data flows.
- Network middleboxes (NAT, load balancers) drop idle connections — typical NAT timeout 30–120 s.
- Without ping/pong, a "dead" WebSocket may sit forever, blocking a slot.

Typical interval: 25–45 seconds. Tune below the load balancer's idle timeout.

---

### Q9. Why are client→server frames masked?

**Answer:** Without masking, malicious JavaScript could craft WebSocket frames that look like HTTP to misconfigured intermediaries (cache poisoning attack on proxies). Masking with a per-frame random key makes the bytes unpredictable and prevents this. Server→client frames are not masked.

---

## Connection Lifecycle

### Q10. Walk through the lifecycle of a WebSocket connection.

```
TCP handshake
       │
HTTP Upgrade request
       │
Server returns 101 Switching Protocols
       │
WebSocket open ─── application sends/receives frames ───
       │
       │ ping/pong keepalives
       │
either side sends close frame
       │
TCP FIN
```

States exposed to JavaScript:

| State | Code | Description |
|-------|------|-------------|
| CONNECTING | 0 | Handshake in progress |
| OPEN | 1 | Ready |
| CLOSING | 2 | Close handshake initiated |
| CLOSED | 3 | Closed (normal or error) |

---

### Q11. What close codes should I know?

| Code | Meaning |
|------|---------|
| 1000 | Normal closure |
| 1001 | Going away (page unload, server shutdown) |
| 1002 | Protocol error |
| 1003 | Unsupported data |
| 1005 | No status received |
| 1006 | Abnormal closure (no close frame) |
| 1008 | Policy violation |
| 1009 | Message too big |
| 1011 | Server error |
| 1012 | Service restart |
| 1013 | Try again later |

`1006` is the most common in production — it indicates the connection was lost without an orderly close (network blip, force-killed process). Treat 1006 differently from 1000 in your reconnect logic.

---

## Reconnection and Reliability

### Q12. How should a client reconnect?

**Answer:** Use exponential backoff with jitter. Naïve fixed-interval reconnect creates a thundering herd when the server restarts.

```javascript
class ResilientSocket {
  constructor(url) {
    this.url = url;
    this.attempt = 0;
    this.maxBackoff = 30_000;
    this.connect();
  }

  connect() {
    this.ws = new WebSocket(this.url);
    this.ws.onopen = () => { this.attempt = 0; };
    this.ws.onclose = (e) => {
      if (e.code === 1000) return;          // intentional
      const base = Math.min(1000 * 2 ** this.attempt, this.maxBackoff);
      const jitter = Math.random() * 0.3 * base;
      setTimeout(() => this.connect(), base + jitter);
      this.attempt++;
    };
  }
}
```

Cap the backoff (often 30 s) and add ±30% jitter. After connecting, replay or resubscribe.

---

### Q13. How do you avoid losing messages during reconnect?

**Options:**

1. **Server-side queue per session** — buffer outbound messages keyed by session ID; on reconnect, replay from the last delivered seq.
2. **Sequence numbers + ACKs** — client tracks last seen sequence; on reconnect, server resends missed records.
3. **Idempotency keys** — duplicates from "send + crash + retry" are deduplicated downstream.
4. **Persistent log (Kafka / SSE Last-Event-ID)** — push events to a log, WebSocket gateway reads from it; reconnect resumes from offset.

Without one of these, messages sent during the disconnect window are lost.

---

### Q14. How do you detect a half-open connection?

**Answer:** A half-open connection is one where TCP thinks it's alive but the peer is gone (e.g., NAT timed out, peer host crashed). TCP keepalive can take 2 hours by default to detect this.

Detection options:

- **Application-level ping/pong** — primary mechanism, fast detection (seconds).
- **OS-level TCP keepalive** — tunable but slow.
- **Server-side timeout on no data received** — close after N seconds of silence.

---

## Socket.io vs Raw WebSockets

### Q15. What does Socket.io give you over raw WebSocket?

| Feature | Raw WS | Socket.io |
|---------|--------|-----------|
| Transport | WebSocket only | WebSocket with HTTP long-poll fallback |
| Auto-reconnect | DIY | Built-in with backoff |
| Rooms / namespaces | DIY | First-class |
| Acknowledgments per message | DIY | Built-in (`socket.emit(..., ack)`) |
| Broadcasting | DIY | Built-in |
| Multi-instance scaling | DIY | Adapter (Redis, Kafka) |
| Binary support | Yes | Yes (encoded) |
| Wire protocol | RFC 6455 | Custom on top of WS/HTTP |
| Interop with non-Socket.io clients | Yes | Only Socket.io clients |

Use Socket.io when you want batteries-included real-time. Use raw WebSocket when you need wire-protocol control, interop with non-JS clients, or minimum overhead.

---

### Q16. What are namespaces and rooms in Socket.io?

- **Namespace** — a logical separation, like `/chat`, `/admin`. Each is its own WebSocket-level path; reuses one connection.
- **Room** — a server-side label grouping sockets within a namespace. Used for broadcasting to subsets.

```javascript
io.of('/chat').on('connection', (socket) => {
  socket.join(`room:${roomId}`);
  io.of('/chat').to(`room:${roomId}`).emit('message', payload);
});
```

Rooms are not persistent — they exist only as long as connected sockets are in them.

---

### Q17. How do acknowledgments work in Socket.io?

```javascript
// Client
socket.emit('save', payload, (ack) => {
  console.log('server confirmed:', ack);
});

// Server
socket.on('save', (payload, ack) => {
  // ... do work
  ack({ ok: true, id: 123 });
});
```

Wraps the message with a callback ID; the server's response triggers the callback. Useful for request/response semantics on a streaming connection.

---

## Authentication and Authorization

### Q18. How do you authenticate a WebSocket connection?

**The handshake is HTTP** — you can use anything HTTP supports:

1. **Cookie** — same-site cookie sent automatically with the upgrade request. Simplest if the WebSocket is on the same origin.
2. **Authorization header** — server-to-server only; the browser WebSocket API doesn't allow custom headers.
3. **Token in query string** — `wss://api/ws?token=...`. Convenient but logs/proxies may capture the token.
4. **Subprotocol header** — pass token as `Sec-WebSocket-Protocol`. Less likely to leak, sent by the browser API.
5. **Post-connect auth message** — first frame is an auth payload; close on failure.

Validate the token at the Upgrade step. Never accept a connection and trust later messages without auth.

---

### Q19. How do you authorize per-message after auth?

**Answer:** Authentication happens once; authorization should be re-checked per action:

- Identify the user from the connection-level claims.
- For each message, check whether the user is allowed to perform it (post to room X, edit document Y).
- Cache permissions briefly to avoid hammering an authz service per message.
- Re-validate on `room.join` / `subscribe` actions.

---

### Q20. How do you handle token expiration on a long-lived connection?

**Strategies:**

- **Refresh tokens over the WebSocket itself** — client sends a refresh message before expiration; server updates internal state.
- **Server enforces max session length** — close after N hours, force reconnection (and reauth).
- **Periodic re-validation against an auth service** — every M minutes, ask "is this token still valid?" and close if not.

Don't ignore expiration on long connections — a compromised token could otherwise live forever.

---

## Scaling WebSockets

### Q21. Why is scaling WebSockets harder than scaling HTTP?

**Answer:**

- **Stateful** — each connection is a long-lived TCP socket pinned to one server.
- **Memory per connection** — modest but adds up (a few KB to tens of KB depending on buffers and library).
- **Per-instance fan-out problem** — to broadcast to all users, every server holding a relevant connection must do its share.
- **Sticky sessions usually required** — load balancers must keep the user on the same instance.
- **Horizontal scaling needs cross-instance message bus** — Redis pub/sub, Kafka, NATS.

---

### Q22. How do you broadcast a message to all users when they're spread across N servers?

**The pub/sub fan-out pattern:**

```
            ┌──── server A ──── connections [1..1000]
publisher → │
            │     Redis pub/sub / Kafka / NATS
            │
            └──── server B ──── connections [1001..2000]
                  server C ──── connections [2001..3000]
```

1. Each server subscribes to the broadcast channel.
2. Any server can publish a "broadcast to room X" message to the bus.
3. Every server that has connections in room X delivers locally.

**Redis pub/sub** is most common — fast, simple, no persistence (lost messages on disconnect from Redis are not retried).

**Socket.io adapter:** `@socket.io/redis-adapter` does this transparently:

```javascript
const io = new Server();
io.adapter(createAdapter(pubClient, subClient));
io.to('room:42').emit('event', payload);  // delivered cluster-wide
```

---

### Q23. When should you use Kafka instead of Redis pub/sub for fan-out?

| Need | Pick |
|------|------|
| Sub-millisecond fan-out, lossy okay | Redis pub/sub |
| Replay missed messages on reconnect | Kafka (read from offset) |
| Persistence, audit trail | Kafka |
| Massive fan-out at high throughput | Kafka |
| Tiny ops footprint | Redis pub/sub |

A common combo: Kafka as the durable log, Redis pub/sub or NATS as the WebSocket fan-out fast path.

---

### Q24. How many WebSocket connections per server?

**Answer:** Depends on:

- Memory per connection (Node.js: 5–50 KB; raw Go: 2–10 KB).
- Message rate.
- Heartbeat work.
- Fan-out hot keys.

A single tuned Node process can hold ~10–50k connections. With tuning (file descriptor limits, kernel buffer sizes, `epoll`), Go services routinely hold 100k–1M per box. WhatsApp famously held millions per Erlang server.

Plan for ~10k per process and scale horizontally.

---

### Q25. Sticky vs non-sticky sessions for WebSockets — which?

**Answer:** **Sticky.** Once a TCP connection is established to server A, all subsequent frames must continue to server A. WebSockets don't survive being load-balanced mid-stream.

For the **initial handshake** (HTTP/Upgrade), most LBs hash by IP or use a cookie to route. For the long-lived connection, the LB just keeps the TCP socket pinned.

If you must avoid stickiness (rare), use a service mesh that proxies frame-level traffic, or terminate WebSockets at a thin gateway layer that fans out to a stateless backend.

---

### Q26. How do you drain WebSocket connections during deployment?

**Graceful shutdown:**

1. Stop accepting new upgrades (LB removes the instance from the pool).
2. Send a `close` frame with code 1012 ("service restart") or a custom message.
3. Allow clients to reconnect; clients re-establish to a healthy instance.
4. Wait for connections to drain or hard-close after a timeout.

```javascript
process.on('SIGTERM', () => {
  io.close(() => process.exit(0));        // stops accepting, closes existing
  setTimeout(() => process.exit(1), 30_000);  // hard-fail safety net
});
```

For zero-disruption, push reconnect logic in the client and accept a brief reconnection blip.

---

## Deployment — Load Balancers and Proxies

### Q27. How do you configure Nginx for WebSockets?

```nginx
location /ws/ {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_read_timeout 3600s;            # keep connection open
    proxy_send_timeout 3600s;
}
```

Critical pieces:

- `proxy_http_version 1.1` — required for upgrade.
- `Upgrade` and `Connection` headers — pass through the upgrade request.
- `proxy_read_timeout` — must exceed your ping interval, or Nginx kills the connection.

Plan ping/pong below the timeout (e.g., 30 s pings under a 60 s timeout).

---

### Q28. AWS ALB vs NLB for WebSockets — which?

| Aspect | ALB | NLB |
|--------|-----|-----|
| Layer | L7 | L4 |
| WebSocket support | Yes (handles upgrade) | Yes (transparent at L4) |
| Idle timeout | Configurable up to 4000 s | 350 s, not configurable |
| Routing | Path/host/header rules | TCP/UDP only |
| TLS termination | Yes | Yes (TLS listener) |
| Cost | Per LCU | Per LCU |
| Best for | App-aware routing, multiple paths | Ultra low-latency, raw TCP |

**ALB** is the common choice for WebSocket apps. Set idle timeout above your ping interval. **NLB** is better for raw TCP, MQTT, or huge connection counts.

---

### Q29. What is the typical WebSocket deployment behind a CDN?

**Answer:** Traditional CDNs (CloudFront classic, Fastly) terminate WebSockets at the edge and proxy to origin — but with strict path requirements and timeouts. Many teams bypass the CDN entirely for the WebSocket subdomain (`wss://realtime.example.com`) and only use CDN for static assets.

If your CDN supports WebSocket origin push, verify:

- Idle timeout high enough.
- Headers preserved.
- WebSocket subprotocols passed through.
- Geographic terminating point isn't far from your backend.

---

### Q30. CORS and WebSockets.

**Answer:** WebSockets do **not** use CORS — they use the `Origin` header at the upgrade step. The server should validate `Origin` and reject unknown origins:

```javascript
const wss = new WebSocketServer({
  verifyClient: ({ origin }) => allowedOrigins.has(origin)
});
```

CORS preflight does not apply because WebSocket isn't a CORS-controlled fetch. But the `Origin` check is the critical defense against cross-site WebSocket hijacking.

---

## Kubernetes Considerations

### Q31. How do you run WebSockets on Kubernetes?

- **Service of type ClusterIP** behind an Ingress with WebSocket-aware annotations:
  ```
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  nginx.ingress.kubernetes.io/upstream-hash-by: "$binary_remote_addr"  # sticky
  ```
- **HPA** based on CPU is a poor fit — connection count is a better signal. Use a custom metric (active connections) or expose Prometheus metrics.
- **Pod disruption budget** so rolling updates don't kick all clients at once.
- **PreStop hook** to stop accepting new connections and gracefully drain.
- **Avoid frequent restarts** — every restart triggers reconnect storms.

---

### Q32. How do you size pods for WebSocket workloads?

- Target ~10k connections per pod (Node) or ~50k (Go) as a starting point.
- Right-size memory: connections × per-connection overhead × safety margin.
- Tune file descriptor limits (`ulimit -n`) — each connection is a socket FD.
- Kernel: `net.core.somaxconn`, `net.ipv4.tcp_max_syn_backlog`, ephemeral port range.

---

## Common Patterns

### Q33. Chat application architecture.

```
clients ── WebSocket ── ┌─ ws-server-1 ─┐
                        ├─ ws-server-2 ─┤ ── Redis pub/sub for fan-out
                        └─ ws-server-3 ─┘
                                │
                          message store (Postgres / Cassandra)
                                │
                          search index, push, analytics (via Kafka)
```

Per-message flow:

1. Client A sends message via WebSocket to server-1.
2. Server-1 persists to DB.
3. Server-1 publishes to Redis pub/sub on `room:42`.
4. All servers with subscribers in `room:42` deliver to their local sockets.
5. Async pipeline pushes to Kafka for offline notifications, search indexing, etc.

---

### Q34. Real-time dashboard.

- Aggregate metrics in a stream processor.
- Push deltas to a WebSocket gateway.
- Coalesce updates (don't push 1000 frames/sec — batch into ~10 fps).
- Send full snapshots on connect, deltas thereafter.

---

### Q35. Notification system.

- Notification service publishes events to Kafka.
- WebSocket gateway consumes and pushes to connected users.
- Offline users → push notification (APNs, FCM) or email.
- Track `last_delivered_id` per user for catch-up on reconnect.

---

### Q36. Collaborative editing (Google Docs style).

Two main approaches:

| Approach | Description |
|----------|-------------|
| Operational Transform (OT) | Operations are transformed against concurrent ops. Centralized server. |
| CRDTs | Conflict-free replicated data types. Decentralized, eventually consistent. |

WebSocket carries the deltas; server may store the canonical document and broadcast operations to all editors. Latency budget is tight (under 100 ms per keystroke roundtrip).

---

### Q37. Live multiplayer game.

- Authoritative server pattern: clients send inputs, server simulates, broadcasts state.
- Tick-based — server runs at 20–60 Hz, broadcasts state per tick.
- Use binary frames + delta compression to fit a tick into a small payload.
- For very low latency, use UDP via WebRTC data channels rather than WebSocket.

---

### Q38. Backpressure — what is it and how do you handle it?

**Answer:** When the server produces frames faster than the client (or its network) can consume, the server's send buffer fills up. Without handling, memory grows unbounded.

**Detection:** monitor each socket's `bufferedAmount` (browser) or `socket.write` return value (Node).

**Strategies:**

- **Drop policy** — drop oldest frames; OK for telemetry.
- **Coalesce** — keep only latest snapshot per topic.
- **Pause/resume** — stop pushing; resume when buffer drains.
- **Disconnect slow clients** — protect server health.
- **Per-client send queues with caps** — bounded memory.

```javascript
function send(socket, data) {
  if (socket.bufferedAmount > 1_000_000) {
    socket.close(1013, 'slow consumer');
    return;
  }
  socket.send(data);
}
```

---

### Q39. Rate limiting on WebSockets.

Apply at multiple layers:

- **Connection rate** — N upgrades per IP per minute, at the LB or gateway.
- **Message rate per connection** — token bucket per socket; close on persistent abuse.
- **Per-user rate** — across all connections from one user.
- **Topic rate** — limit subscribes/unsubscribes to one room per second.

Token bucket and sliding window are common algorithms.

---

## Security

### Q40. Common WebSocket security risks?

| Risk | Mitigation |
|------|------------|
| Cross-Site WebSocket Hijacking | Validate `Origin` header on upgrade |
| Token leakage in URL | Use subprotocol header or first-frame auth |
| Man-in-the-middle | Always `wss://` (TLS), never `ws://` over the open internet |
| Resource exhaustion | Connection caps, rate limits, idle timeouts, max frame size |
| Injection in messages | Validate every payload — same as HTTP input |
| Authorization bypass post-connect | Re-check auth per action |
| Compression amplification (BREACH-like) | Disable per-message-deflate or use carefully |

---

### Q41. Should you use compression on WebSockets?

**Answer:** Per-message-deflate (`permessage-deflate`) can save bandwidth for repetitive JSON. Caveats:

- Compression context per connection — memory cost.
- Compression amplification attacks (CRIME-like) if user-controlled data is mixed with secrets.
- CPU overhead.

For high-frequency small messages, compression often hurts more than it helps. Benchmark first.

---

## Monitoring and Operations

### Q42. What WebSocket metrics matter?

| Metric | Purpose |
|--------|---------|
| Active connections (per instance, total) | Capacity tracking |
| Connections per second (open / close) | Churn detection |
| Bytes in / out per second | Bandwidth |
| Messages per second | Throughput |
| Send buffer depth | Backpressure |
| Ping/pong RTT | Connection health |
| Disconnect codes (1000 vs 1006 distribution) | Error rate |
| Time-to-first-message | Reconnect storm detection |
| CPU per active connection | Efficiency |

---

### Q43. How do you debug a WebSocket issue?

- **Browser dev tools** → Network tab → WS filter → frame-by-frame view.
- **Wireshark / tcpdump** for protocol-level issues (handshake failures).
- **Server-side per-connection trace logs** (sampled, low rate).
- **Reproduce against a single instance** by bypassing the LB.
- **Test with `wscat`** or `websocat` to isolate client vs server bugs.
- **Watch close codes** — 1006 patterns suggest network/middlebox; 1009 suggests message size; 1011 suggests server bugs.

---

## WebRTC and When to Use What

### Q44. WebRTC vs WebSocket — what's different?

| Aspect | WebSocket | WebRTC |
|--------|-----------|--------|
| Transport | TCP | UDP (with optional reliable channel) |
| Topology | Client ↔ Server | Peer ↔ Peer (with optional SFU/MCU) |
| Use case | Bidirectional messaging | Real-time audio/video, low-latency data |
| NAT traversal | None needed (uses HTTP) | STUN/TURN required |
| Latency | TCP retransmits add lag | UDP — drop instead of retransmit |
| Complexity | Low | High |

WebRTC includes signaling — but signaling itself is **often done over WebSocket**. WebRTC excels at A/V media and ultra-low-latency P2P data channels (gaming, file transfer).

---

### Q45. When should you choose what?

| Need | Pick |
|------|------|
| Server pushes data to many clients | SSE or WebSocket |
| Client and server exchange messages | WebSocket |
| Bidirectional with HTTP fallback | Socket.io |
| P2P audio/video | WebRTC |
| Low-latency data, drop-tolerant | WebRTC data channel (unreliable mode) |
| Just request/response | HTTP/gRPC |
| Replay missed events on reconnect | SSE (with Last-Event-ID) or WebSocket on top of Kafka |

---

## Common Pitfalls

### Q46. Forgetting heartbeat → silent disconnects.

If you don't ping/pong, NAT will kill connections at idle, and your server keeps the socket forever. Always ping; always close on missed pong.

---

### Q47. Reconnect storm on deployment.

10k clients all reconnect at the same instant after a deploy → spike on auth service, DB, Redis. Fixes:

- Jitter in client backoff.
- Stagger pod rollout.
- Cache auth results briefly server-side.
- Pre-warm new instances before draining old ones.

---

### Q48. State pinned to one instance.

If your "who is in room X" lives only in instance A's memory, instance B can't broadcast properly. Move shared state to Redis or rebuild on subscribe events.

---

### Q49. Using polling fallback for new browsers.

Don't enable Socket.io's HTTP long-poll fallback unless you need IE11. It significantly increases your server load and complicates ops. WebSocket has been universal since 2012.

---

### Q50. Treating WebSocket as a pub/sub bus.

WebSocket is a **transport**, not a message broker. Don't push 100k connections worth of "every event" to the server and expect it to scale. Use Kafka/Redis as the bus and WebSocket as the last-mile delivery.

---

### Q51. Trusting the client.

Same as HTTP — never trust the input. Validate every frame against the schema, authorize the action, sanitize before broadcast. A compromised client can do anything a real client could.

---

### Q52. Senior-level rules of thumb.

- Use SSE if data is one-way; WebSocket otherwise.
- Always `wss://`, validate `Origin`, handle auth at upgrade.
- Always ping/pong; tune below LB idle timeout.
- Sticky sessions on the LB.
- Cluster fan-out via Redis pub/sub (or Kafka for replay).
- Reconnect with exponential backoff and jitter.
- Make message handling idempotent and replay-safe.
- Plan for backpressure and drop or close slow clients.
- Treat the WebSocket gateway as a thin layer; keep state outside.
- Monitor active connections, churn, send buffer depth, and close code distribution.
