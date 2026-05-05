# Architecture Under Time Pressure

**The Problem:** Interviewer says "we don't have much time for architecture, what would you do?" or "you're spending too much time on design — just code it."

This is one of the most underestimated interview questions. It's not just a technical question — it's testing your **judgment, prioritization, communication, and pragmatism**. Senior engineers earn their level by knowing what to skip without breaking things later.

---

## Table of Contents

1. [The Strong Default Answer (Memorize This)](#the-strong-default-answer-memorize-this)
2. [The Mental Framework: Triage in 5 Minutes](#the-mental-framework-triage-in-5-minutes)
3. [What "Architecture" Actually Means in Time-Pressured Situations](#what-architecture-actually-means-in-time-pressured-situations)
4. [The 3-Layer Approach](#the-3-layer-approach)
5. [Sample Q&A Variations](#sample-qa-variations)
6. [Red Flags vs Smart Shortcuts](#red-flags-vs-smart-shortcuts)
7. [Real Scenarios with Strong Answers](#real-scenarios-with-strong-answers)
8. [Communication Patterns That Save You](#communication-patterns-that-save-you)
9. [The "Architectural Smell" Signal Test](#the-architectural-smell-signal-test)
10. [Senior-Level Recovery Phrases](#senior-level-recovery-phrases)

---

## The Strong Default Answer (Memorize This)

> "When time is short, I do not skip architecture — I shrink it. I spend a focused few minutes identifying three things: the data model, the trust boundary, and the irreversible decisions. Everything else I treat as code I can refactor later. The risk is not 'no architecture' — the risk is making one decision now that I cannot undo cheaply later. So my time goes to those decisions only. After that, I write the simplest working version, ship it, and iterate."

**Why this works:**
- Acknowledges the constraint without surrendering quality
- Shows you have a framework, not just panic
- Names what to protect (data, security, lock-in)
- Names what to defer (everything reversible)
- Demonstrates senior-level prioritization

---

## The Mental Framework: Triage in 5 Minutes

When time is short, ask three questions in order:

### 1. What is irreversible?
- Database schema with live data
- Public API contracts
- Authentication and authorization model
- File storage paths and naming conventions
- Money and financial logic
- Vendor lock-in (cloud-specific services, proprietary protocols)

**These need design time. Always.**

### 2. What is reversible?
- Internal class structure
- File/folder organization
- Library choices that have alternatives
- UI layout and component breakdown
- Helper utilities
- Naming inside the code

**These can be refactored. Skip the design meeting.**

### 3. What can go wrong silently?
- Money rounding
- Concurrent updates
- Authentication holes
- Unbounded queries (N+1, no pagination)
- Missing indexes
- Unhandled async errors
- Time zones

**These need a checklist, not a design doc.**

---

## What "Architecture" Actually Means in Time-Pressured Situations

There is a misconception that "architecture" = drawing diagrams for hours. In a time crunch, architecture is just **a small set of high-stakes decisions**.

### Senior-level architecture in 10 minutes looks like:

| Decision | Time spent | Output |
|----------|------------|--------|
| Data model + key relationships | 3-4 min | One ER sketch on paper |
| Auth model (who, what, how) | 1-2 min | Roles + token strategy |
| Critical API surface (3-5 endpoints) | 2-3 min | Names + status codes |
| Failure modes (3 worst-case) | 1-2 min | What happens if X dies |
| Where to defer | 1 min | "I'll figure that out in code" |

Total: 10 minutes. That's it. That's the architecture.

You're not designing a system, you're protecting yourself from making the **3 mistakes that cost a week of rework later**.

---

## The 3-Layer Approach

Use this when an interviewer cuts your design time short:

### Layer 1: Required (cannot skip)
- Data model (tables, key fields, relationships)
- Authentication boundaries (who can do what)
- Money/security flow if applicable

### Layer 2: Strongly Preferred (skip only if forced)
- API contract sketch
- Failure handling strategy
- Caching/scale touchpoints

### Layer 3: Defer to Code (skip freely)
- File structure
- Helper modules
- Logging format
- UI component decomposition

**Verbalize the layers** so the interviewer sees you're not skipping carelessly:

> "Given the time, I'll lock down the data model and auth — those I can't easily change. The API shape I'll draft as I code. Internal structure I'll refactor as patterns emerge."

---

## Sample Q&A Variations

### Q1. "We don't have much time for architecture — just start coding."

**Strong Answer:**

> "Understood. Let me confirm two things in 60 seconds so I don't get stuck later: the data model and the auth model. Those I cannot refactor cheaply once data exists. Everything else I'll handle in code. Can I sketch the data model quickly before I start?"

**What this does:**
- You don't argue. You comply, but smart.
- You name the two things worth protecting.
- You ask, not demand — collaborative tone.

---

### Q2. "You're spending too much time designing — what would a senior engineer do?"

**Strong Answer:**

> "A senior engineer protects irreversible decisions and treats everything else as cheap. So I'd lock down the schema and the auth boundary, then write the simplest version that works. I would not draw diagrams for things I can refactor in an hour. Architecture is not the artifact, it's the small set of decisions that I cannot easily change later."

---

### Q3. "Skip the architecture, just give me the code."

**Strong Answer:**

> "I'll start coding. Two quick assumptions I'll make explicit so you can correct them if needed: I'll use `users → orders → order_items` as the schema, and I'll authenticate with JWT in the Authorization header. If those are wrong, the rework cost is high — so I want to surface them now. Otherwise I move forward."

**Key technique: name your assumptions out loud, even while coding.**

---

### Q4. "We're in a startup mode, no time for over-engineering."

**Strong Answer:**

> "Agreed. Over-engineering is the enemy. My rule is: build the simplest thing that handles today's load and one obvious near-term change. No abstraction without two real use cases. No microservices, no event buses, no premature caching. Just modular code, clean boundaries between business logic and I/O, and tests around the money paths. That's enough."

---

### Q5. "How would you balance design and delivery?"

**Strong Answer:**

> "I think in three buckets: irreversible, expensive-to-change, and free-to-change. Irreversible decisions get design time — schemas, contracts, security. Expensive changes get a short discussion — query patterns, framework choice. Everything else I write fast and refactor when it hurts. The trap is treating reversible decisions like irreversible ones — that's where weeks get burned on architecture for things that don't matter."

---

## Red Flags vs Smart Shortcuts

When time is tight, some shortcuts are smart and some are dangerous. Know the difference.

### Smart Shortcuts (do these)

- Use a single table where two would be ideal but reversible
- Skip an in-memory cache layer initially
- Use simple sessions instead of JWT until needed
- Hardcode config values you'll move later
- Skip retries until you see real failures
- Use one programming pattern consistently, even if not optimal
- Combine controller and service layer in early code (split later)

### Dangerous Shortcuts (never do these)

- Storing passwords in plain text "for now"
- Disabling SSL "in dev"
- Using string concatenation for SQL "to save time"
- Storing money as floats "for simplicity"
- Skipping database transactions on multi-step operations
- Trusting client-supplied user IDs "we'll add validation later"
- Letting one user's data leak into another's "we'll fix it"

**Memorize the rule:** speed comes from simpler code, not from skipping safety.

---

## Real Scenarios with Strong Answers

### Scenario 1: "Build a payment integration in 2 hours"

**Wrong move:** Start coding right away.

**Right move:**
1. (2 min) Confirm idempotency strategy — what if the same request hits twice?
2. (2 min) Confirm money type — decimal/integer cents, never float
3. (2 min) Confirm transaction boundary — when do we mark "paid"?
4. Then code.

**What you say:**
> "Before I write code, three things I want to lock — idempotency keys, money representation, and the moment we transition order status to paid. These cause real bugs and refactoring is painful. After that, the integration is mechanical."

---

### Scenario 2: "Quick MVP feature in 1 hour, multi-user"

**Wrong move:** Build features fast, sort out auth at the end.

**Right move:**
1. (3 min) Define `current_user` context — every query must filter by it
2. (2 min) Define data ownership — who can read/write which records
3. Then build features.

**What you say:**
> "Multi-user means tenant isolation is the silent killer. I'll set up `current_user` access early so every query filters by it. Otherwise I'll spend the last 10 minutes hunting cross-tenant data leaks. That's my one design moment."

---

### Scenario 3: "Add a search feature, fast"

**Wrong move:** Spin up Elasticsearch, design index strategy.

**Right move:**
1. (1 min) `LIKE '%term%'` on indexed columns — works for <100K rows
2. Build it.
3. Move to full-text search if it actually slows down.

**What you say:**
> "I won't reach for Elasticsearch yet. PostgreSQL `LIKE` with a trigram index covers most use cases below the millions of rows. Move to full-text or external search only when query times prove it. Premature search infra is a classic time-sink."

---

### Scenario 4: "Set up a CRUD module, fast"

**Wrong move:** Generate scaffolding, customize 200 files.

**Right move:**
1. Repository → service → controller, three layers, simple.
2. One DTO for create, one for update, one for response.
3. Skip caching, skip soft delete, skip audit trail unless required.

**What you say:**
> "Three layers, three DTOs, no extras. Caching, soft delete, and audit logs are valid — but only when there's a real reason. I'd rather add them when needed than carry the weight from day one."

---

## Communication Patterns That Save You

### Pattern 1: "I'm protecting against X"

Whenever you spend time on something, frame it as protecting against a specific risk:

> "I'm spending 2 minutes on the schema because once we have production data, ALTER TABLE on a million rows is a 4-hour migration. So I'd rather get the columns right now."

### Pattern 2: "I'll handle that in code"

For things you're skipping:

> "Logging strategy and helper utilities — I'll handle those in code. They're cheap to refactor."

### Pattern 3: "Two assumptions I'm making"

When the interviewer pushes you forward:

> "Two assumptions I'm making explicit: payments are processed asynchronously via webhook, and refunds are a separate flow. If those don't match, the design needs to change. If they're correct, I move on."

### Pattern 4: "What would change my answer?"

When you're not sure if the design is right:

> "My current design assumes single-region deployment. What would change my answer is if we need multi-region with sub-100ms latency — then I'd add a different layer. Is single-region OK?"

This makes you look thoughtful, not indecisive.

---

## The "Architectural Smell" Signal Test

When asked to skip architecture, identify the smells in 30 seconds. If any of these are present, **push back**:

| Smell | Push back |
|-------|-----------|
| "Just hardcode the user ID for now" | No — auth is irreversible |
| "We don't need transactions for this" | Verify — money flows always need transactions |
| "Add validation later" | Validate at the boundary, always |
| "We can fix the schema in production" | Migrations on live data are painful |
| "Just store it as JSON" | Sometimes fine, sometimes a long-term tax |
| "Skip the tests, ship it" | Money paths and security paths need tests |

Don't argue blindly. Push back **with the cost** clearly stated:

> "Skipping the database transaction here means a partial order if the email fails. That bug shows up under load and is hard to reproduce. The transaction is 3 lines of code. Worth it."

---

## Senior-Level Recovery Phrases

If you've already spent too long on architecture and the interviewer is impatient:

### Recovery 1: Acknowledge and pivot
> "I notice I've been in design longer than needed. Let me lock in the data model and auth — those two only — and start coding."

### Recovery 2: Time-box yourself
> "Give me 90 seconds to confirm the schema, then I move to code."

### Recovery 3: Sketch out loud while moving
> "I'll think through the API as I code. The data model I want to confirm: users, jobs, applications, with these foreign keys [...]. Now starting code."

### Recovery 4: Defer to a checkpoint
> "I'll make the simple choice now and revisit if it doesn't fit. The pivot point will be when I implement the second feature — if I'm copy-pasting, I refactor."

### Recovery 5: Convert design to questions
> "Rather than design more, let me ask three quick questions: [a, b, c]. Answers from you save me from designing for the wrong assumptions."

---

## Personal Reflection (for the user's specific past experience)

The interviewer's feedback — "you don't have much time for architecture, what do you do?" — is not a trap. It's a real-world signal: **senior engineers ship**. They don't draw diagrams for things they can refactor.

The mistake to avoid is over-correcting. Don't go to the other extreme and skip all design. The right answer is:

> Architecture in proportion to risk. High-risk decisions get design time. Low-risk decisions get code time. Most decisions are low-risk.

If you internalize this, the question stops being scary. You'll have a clear, confident answer every time.

---

## Quick Card to Memorize

**When asked "what do you do without time for architecture?":**

1. State the framework: irreversible vs reversible.
2. List what you protect: data model, auth, money.
3. List what you defer: file structure, helpers, internal patterns.
4. Reassure: "I refactor reversible code when patterns emerge."
5. Move forward.

**Total response: 30-45 seconds. Confident. No apology.**

---

## Closing Thought

The trap is thinking the interviewer wants either "no architecture" or "full architecture." What they actually want is **proportional architecture**. They want to see that you know:

- when to invest design time
- when to skip and ship
- the difference between the two
- how to communicate the trade-off out loud

If you show that, you pass — even if your final design is imperfect. They're hiring judgment, not perfection.
