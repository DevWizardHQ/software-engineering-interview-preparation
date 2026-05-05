# Full-Stack Senior Engineer Interview Preparation

> A comprehensive, senior-level interview preparation repository covering languages, frameworks, databases, DevOps, system design, behavioral questions, and worst-case scenarios. Designed for engineers targeting senior full-stack / software engineering roles in the international market.

---

## Quick Start

| If you are... | Start here |
|---------------|------------|
| Preparing for a senior full-stack role | [Critical Scenarios](#critical-scenarios), [System Design](architecture/system-design-interview-questions.md), [Behavioral](#behavioral--hr) |
| In a Laravel / PHP / Vue stack | [Laravel](languages/laravel-interview-questions.md), [PHP](languages/php-interview-questions.md), [Vue.js](frontend/vuejs-interview-questions.md), [Merged Guide](fullstack-guides/fullstack-php-laravel-vuejs-complete.md) |
| In a Node.js / React / Next.js stack | [Node.js](backend/nodejs-interview-questions.md), [React](frontend/react-interview-questions.md), [Next.js](frontend/nextjs-interview-questions.md), [Merged Guide](fullstack-guides/fullstack-react-nextjs-nodejs-guide.md) |
| Preparing for system design rounds | [System Design](architecture/system-design-interview-questions.md), [Microservices](architecture/microservices-interview-questions.md), [Scaling](performance/scaling-millions-traffic-data.md) |
| Brushing up on algorithms | [Algorithms](#algorithms--coding) |
| Worried about the HR round | [HR Questions](behavioral/hr-questions.md), [Career Change](behavioral/career-change-questions.md) |
| Worried about "no time for architecture" | [Architecture Time Pressure](critical-scenarios/architecture-time-pressure.md) |

---

## Repository Structure

```
fullstack-interview-preparation/
├── README.md                       ← you are here
├── languages/                      ← language deep-dives
├── frontend/                       ← React, Vue, Next, Nuxt, HTML/CSS, Tailwind
├── backend/                        ← Node.js, NestJS
├── databases/                      ← SQL fundamentals + MySQL / Postgres / MongoDB / Redis / MariaDB / SQLite
├── messaging/                      ← RabbitMQ, Kafka, WebSockets
├── devops/                         ← Docker, Linux, Nginx, Git, CI/CD
├── architecture/                   ← microservices, system design
├── algorithms/                     ← coding patterns, SQL puzzles, DSA, Big-O
├── performance/                    ← optimization at every layer + scaling to millions
├── critical-scenarios/             ← worst case, financial, architecture-under-pressure
├── behavioral/                     ← HR, behavioral STAR, career change, AI questions
└── fullstack-guides/               ← merged comprehensive references
```

---

## Languages

Deep-dive Q&A on programming languages — basic to advanced, with senior-level pitfalls and trade-offs.

| File | Topic | Q&A |
|------|-------|-----|
| [JavaScript](languages/javascript-interview-questions.md) | Vanilla JS / ES6+ / ECMAScript | 90+ |
| [TypeScript](languages/typescript-interview-questions.md) | Generics, utility types, type-level programming | 56+ |
| [PHP](languages/php-interview-questions.md) | PHP 8.x, OOP, modern features, security | 62+ |
| [Laravel](languages/laravel-interview-questions.md) | Deep Laravel framework knowledge | 87+ |

---

## Frontend

| File | Topic | Q&A |
|------|-------|-----|
| [React](frontend/react-interview-questions.md) | Hooks, performance, patterns | 45+ |
| [Next.js](frontend/nextjs-interview-questions.md) | App Router, SSR/SSG/ISR, Server Components | 35+ |
| [Vue.js](frontend/vuejs-interview-questions.md) | Composition API, reactivity, Pinia | 35+ |
| [Nuxt.js](frontend/nuxtjs-interview-questions.md) | Nuxt 3, Nitro, hybrid rendering | 56+ |
| [HTML / CSS](frontend/html-css-interview-questions.md) | Semantic HTML, Flexbox, Grid, modern CSS | 72+ |
| [Tailwind CSS](frontend/tailwindcss-interview-questions.md) | Utility-first, JIT, design systems | 45+ |

---

## Backend

| File | Topic | Q&A |
|------|-------|-----|
| [Node.js](backend/nodejs-interview-questions.md) | Event loop, streams, Express, scaling | 38+ |
| [NestJS](backend/nestjs-interview-questions.md) | Modules, DI, guards, interceptors, pipes | 32+ |

---

## Databases

| File | Topic | Q&A |
|------|-------|-----|
| [SQL Fundamentals](databases/sql-fundamentals.md) | Joins, aggregates, CTEs, window functions, indexes, transactions | 60+ |
| [MySQL](databases/mysql-interview-questions.md) | InnoDB, replication, performance, ops | 48+ |
| [PostgreSQL](databases/postgresql-interview-questions.md) | MVCC, JSONB, indexes, partitioning, advanced features | 50+ |
| [MariaDB](databases/mariadb-interview-questions.md) | MariaDB-specific features, Galera Cluster | 47+ |
| [SQLite](databases/sqlite-interview-questions.md) | WAL, FTS5, embedded use, scaling tools (Litestream, Turso, D1) | 56+ |
| [MongoDB](databases/mongodb-interview-questions.md) | Documents, aggregation, sharding, transactions | 66+ |
| [Redis](databases/redis-interview-questions.md) | Data structures, persistence, cluster, use cases | 59+ |

---

## Messaging & Real-Time

| File | Topic | Q&A |
|------|-------|-----|
| [RabbitMQ](messaging/rabbitmq-interview-questions.md) | AMQP, exchanges, queues, DLX, clustering | 67+ |
| [Kafka](messaging/kafka-interview-questions.md) | Partitions, ISR, semantics, Streams, Connect | 71+ |
| [WebSockets](messaging/websockets-interview-questions.md) | Protocol, scaling, Socket.io, Nginx/ALB config | 52+ |

---

## DevOps & Infrastructure

| File | Topic | Q&A |
|------|-------|-----|
| [Docker](devops/docker-interview-questions.md) | Containers, multi-stage builds, networking, security | 60+ |
| [Linux](devops/linux-interview-questions.md) | Filesystem, systemd, networking, bash, troubleshooting | 65+ |
| [Nginx](devops/nginx-interview-questions.md) | Reverse proxy, load balancing, TLS, caching, rate limiting | 52+ |
| [Git](devops/git-interview-questions.md) | Internals, merge/rebase, hooks, common scenarios | 61+ |
| [CI/CD + GitHub Actions](devops/cicd-github-actions-interview-questions.md) | Workflows, OIDC, deployment strategies, comparison vs others | 52+ |

---

## Architecture & System Design

| File | Topic | Q&A |
|------|-------|-----|
| [Microservices](architecture/microservices-interview-questions.md) | Patterns, sagas, CQRS, observability, anti-patterns | 72+ |
| [System Design](architecture/system-design-interview-questions.md) | URL shortener, Twitter, Chat, Uber, Dropbox, etc. | 49 (16 deep dives) |

---

## Algorithms & Coding

| File | Topic |
|------|-------|
| [SQL Algorithm Questions](algorithms/sql-algorithm-questions.md) | Nth highest salary, top-N per group, gaps & islands, recursive CTEs |
| [Coding Algorithm Questions](algorithms/coding-algorithm-questions.md) | Two Sum, Kadane's, sliding window, DP, trees, graphs |
| [Pattern Printing](algorithms/pattern-printing-questions.md) | Star/number patterns frequently asked in interviews |
| [Data Structures Fundamentals](algorithms/data-structures-fundamentals.md) | Arrays, lists, trees, heaps, graphs, tries — implementations |
| [Big-O Complexity](algorithms/big-o-complexity.md) | Analysis, master theorem, cheat sheets |

---

## Performance & Scaling

| File | Topic |
|------|-------|
| [Database Optimization](performance/database-optimization.md) | Indexing, query tuning, sharding, replication, caching |
| [Laravel & PHP Optimization](performance/laravel-php-optimization.md) | OPcache, JIT, Octane, Eloquent tuning, FPM |
| [JavaScript & Frontend Optimization](performance/javascript-frontend-optimization.md) | Bundle splitting, web vitals, React/Vue tuning |
| [Node.js Backend Optimization](performance/nodejs-backend-optimization.md) | V8 profiling, event loop, connection pooling |
| [Scaling to Millions](performance/scaling-millions-traffic-data.md) | Multi-region, CDN, sharding, async patterns |

---

## Critical Scenarios (Interview Pain Points)

These are the questions senior interviewers love and most candidates fail.

| File | What it covers |
|------|----------------|
| [Architecture Under Time Pressure](critical-scenarios/architecture-time-pressure.md) | Strong answer for "what if you don't have time to design?" |
| [Worst Case Scenarios](critical-scenarios/worst-case-scenarios.md) | Production outages, data loss, security incidents — incident playbook |
| [Financial & Transactional Systems](critical-scenarios/financial-transactional-systems.md) | Money handling, ACID, idempotency, double-entry, reconciliation |

---

## Behavioral & HR

| File | What it covers |
|------|----------------|
| [HR Questions](behavioral/hr-questions.md) | Self-introduction, why this company, strengths/weaknesses, salary negotiation |
| [Behavioral Questions](behavioral/behavioral-questions.md) | STAR framework, leadership, conflict, failure, success stories |
| [Career Change & Tricky Questions](behavioral/career-change-questions.md) | Why change stack, why move company, "you're stuck in X", salary pushback |
| [AI-Related Questions](behavioral/ai-related-questions.md) | How you use AI tools, AI replacing engineers, prompt engineering, ethics |

---

## Comprehensive Reference Guides

Combined, multi-topic preparation guides:

| File | Stack |
|------|-------|
| [PHP / Laravel / Vue.js Complete Guide](fullstack-guides/fullstack-php-laravel-vuejs-complete.md) | Strategic prep + deep Laravel + 500-Q&A across PHP/Laravel/Vue/JS/MySQL/REST/Git |
| [React / Next.js / Node.js Guide](fullstack-guides/fullstack-react-nextjs-nodejs-guide.md) | Mid-level full-stack reference covering React/Next/Node/Postgres/system design |

---

## Recommended Study Plan

### 7-Day Intensive (Pre-Interview)

| Day | Focus |
|-----|-------|
| 1 | Languages — your primary stack ([Laravel](languages/laravel-interview-questions.md) or [Node.js](backend/nodejs-interview-questions.md) + [JavaScript](languages/javascript-interview-questions.md) + [TypeScript](languages/typescript-interview-questions.md)) |
| 2 | Frontend — your primary framework ([React](frontend/react-interview-questions.md) / [Vue](frontend/vuejs-interview-questions.md)) + [HTML/CSS](frontend/html-css-interview-questions.md) |
| 3 | Databases — [SQL Fundamentals](databases/sql-fundamentals.md) + your DB ([Postgres](databases/postgresql-interview-questions.md) / [MySQL](databases/mysql-interview-questions.md) / [MongoDB](databases/mongodb-interview-questions.md)) + [SQL Algorithms](algorithms/sql-algorithm-questions.md) |
| 4 | System Design — [System Design](architecture/system-design-interview-questions.md) + [Microservices](architecture/microservices-interview-questions.md) |
| 5 | DevOps — [Docker](devops/docker-interview-questions.md), [Linux](devops/linux-interview-questions.md), [Git](devops/git-interview-questions.md), [CI/CD](devops/cicd-github-actions-interview-questions.md) |
| 6 | Critical scenarios — [Architecture Pressure](critical-scenarios/architecture-time-pressure.md), [Worst Case](critical-scenarios/worst-case-scenarios.md), [Financial Systems](critical-scenarios/financial-transactional-systems.md) + [Performance](performance/database-optimization.md) |
| 7 | Behavioral & HR — all 4 behavioral files. Mock interview. Rest. |

### 30-Day Comprehensive

- **Week 1:** Languages + Frontend + Backend depth
- **Week 2:** Databases + Algorithms (SQL + coding)
- **Week 3:** Architecture + System Design + Performance
- **Week 4:** DevOps + Critical Scenarios + Behavioral + Mock interviews

---

## How to Use This Repository

1. **Don't memorize.** Understand the concepts and practice explaining them in your own words.
2. **Build real examples.** For every concept, have at least one project example you can talk about.
3. **Practice out loud.** The interview room will not be the place to rehearse for the first time.
4. **Cover trade-offs.** Senior engineers are evaluated on trade-off thinking, not just answers.
5. **Prepare 5-7 STAR stories.** Mix them across behavioral questions.
6. **Mock interview.** Find a peer or use AI to simulate questions and give feedback.

---

## Tips for Senior-Level Interviews

- **Slow down.** A 2-second pause before answering reads as thoughtful, not slow.
- **Frame trade-offs explicitly.** "If we optimize for X, we sacrifice Y" — that's the senior signal.
- **Bring numbers.** "p95 dropped from 800ms to 80ms" beats "made it faster."
- **Own mistakes.** "I underestimated X — here's what I learned" beats "everything went well."
- **Ask clarifying questions.** Especially in system design and behavioral rounds.
- **Match the room.** Read the interviewer — adjust depth, pace, and detail accordingly.

---

## Topic Coverage Summary

| Category | Files | Approx Q&A |
|----------|------:|-----------:|
| Languages | 4 | 295+ |
| Frontend | 6 | 288+ |
| Backend | 2 | 70+ |
| Databases | 7 | 386+ |
| Messaging | 3 | 190+ |
| DevOps | 5 | 290+ |
| Architecture | 2 | 121+ |
| Algorithms | 5 | 200+ |
| Performance | 5 | 375+ |
| Critical Scenarios | 3 | Detailed playbooks |
| Behavioral | 4 | 100+ |
| Reference Guides | 2 | 500+ |
| **Total** | **48** | **2800+ Q&A** |

---

## Contributing

This is a personal interview preparation repository. If you find errors or want to add scenarios from your own interviews, feel free to fork and adapt. Each file is self-contained — no cross-file dependencies that prevent partial use.

---

## License

This content is for personal interview preparation. Feel free to use, adapt, and share for non-commercial educational purposes.
