# ADR-002: Java for transactional and analytical services, Go for workers and ingestion

- Status: Accepted
- Date: 2026-09-29
- Milestone: M0

## Context
Two languages increase build and tooling surface. The developer's primary market is Java; Go is a secondary requirement that appears in Danish backend roles for infrastructure and high-throughput services.

## Decision
Java 21 with Spring Boot for core-service, forecasting-service and insights-service (rich domain, transactions, JPA, LangChain4j). Go for media-service, documents-worker, market-ingest and notifications-service (binary handling, concurrent I/O, small domain, long-running consumers). No service exists only to use a language; each Go service has work that Go fits naturally.

## Consequences
- Two CI pipelines, two conventions sections in CLAUDE.md, two sets of Testcontainers setups.
- Clear story in interviews about choosing a language per workload rather than per preference.
