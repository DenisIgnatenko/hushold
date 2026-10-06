# ADR-001: Microservices by bounded context from the first milestone

- Status: Accepted
- Date: 2026-09-29
- Milestone: M0

## Context
The product could be built as one application. The developer's goals include demonstrating event-driven microservices for the Danish job market and gaining practical Go experience. The risk is that distributed complexity slows the first usable version and the project stalls.

Alternatives: (a) modular monolith with Spring Modulith and later extraction; (b) microservices from day one for every context; (c) microservices from day one but only where a boundary is justified, adding services by milestone.

## Decision
Option (c). Services are introduced only with a written justification in `docs/03-services.md`. M1 starts with two services (core-service, media-service). Kafka is introduced in M1 because media-service is already a second consumer of ledger events. core-service keeps Spring Modulith discipline internally.

## Consequences
- The developer practises the full distributed toolset (outbox, idempotent consumers, tracing) from M1.
- Slower first version than a monolith; mitigated by keeping M1 to two services.
- Interview one-liner: "I split by bounded context where load profile, change rhythm or technology differed, wrote down why for each service, and kept a modular monolith discipline inside the core so I could extract further only when there was a reason."
