# ADR-003: Kafka with transactional outbox for all cross-service effects

- Status: Accepted
- Date: 2026-09-29
- Milestone: M1

## Context
Cross-service consistency without distributed transactions. Alternatives: dual write (unsafe), synchronous REST between services (coupling and cascading failures), change data capture with Debezium (operationally heavier), application-level outbox with a relay.

## Decision
Every producer writes events to an `outbox` table in the same transaction as the state change. In Java the relay is Spring Modulith's event publication registry with a Kafka externaliser; in Go a small polling relay with `FOR UPDATE SKIP LOCKED`. Debezium remains an option for M7 if polling latency becomes a problem; the table layout is Debezium-compatible on purpose.

## Consequences
- At-least-once delivery; every consumer must be idempotent (`processed_events`).
- Ordering per household via partition key.
- Interview one-liner: "Outbox gives me atomicity between state and event without 2PC; consumers are idempotent so at-least-once is safe."
