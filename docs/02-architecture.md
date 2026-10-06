# 02. Architecture

## System overview

```
                 +-------------------+          +--------------------+
   iOS app  ---> |  API gateway      | -------> |  Keycloak (OIDC)   |
 (Android later) |  (Kong or Traefik)|          +--------------------+
                 +---------+---------+
                           |  REST /api/v1 (JWT)
        +------------------+-------------------+-------------------+
        v                  v                   v                   v
  core-service       media-service      forecasting-service  insights-service
  (Java)             (Go)               (Java)               (Java, LangChain4j)
        |                  |                   ^                   ^
        | outbox           | outbox            | consumes          | consumes
        v                  v                   |                   |
   +-------------------------- Kafka (topics per event type) --------------------+
        ^                  ^                   |                   |
        |                  |                   v                   v
  documents-worker   market-ingest     notifications-service    (external LLM API,
  (Go, vision LLM)   (Go, scrapers/APIs)  (Go, APNs / FCM)        Anthropic or OpenAI)

  PostgreSQL: one database per service (one instance locally, RDS in AWS)
  Redis: cache and rate limiting (shared instance, key-prefixed per service)
  S3 / MinIO: receipt images and PDFs (media-service owns the bucket)
  OpenTelemetry collector -> Prometheus, Loki, Tempo, Grafana
```

## Style

Event-driven microservices organised by bounded context, each following Clean Architecture internally. Synchronous REST for client-facing reads and writes; asynchronous events for everything that crosses a service boundary as a consequence of a state change.

## Thin clients

The mobile apps contain no business rules. They:
- authenticate and hold tokens,
- render server responses,
- cache the last known state for offline reading (SwiftData / Room),
- queue writes made offline and replay them with idempotency keys,
- capture photos and upload them directly to object storage via presigned URLs.

The server therefore exposes screen-shaped read models where useful (`GET /households/{id}/summary?month=2026-09` returns everything the month screen needs). This is a BFF-style read model inside core-service, not a separate BFF service; a second client platform reuses it unchanged.

Rule of thumb, applied at every code review: if a rule would need to be implemented twice (iOS and Android), it belongs on the server.

## Synchronous path: a manual expense

1. App calls `POST /api/v1/households/{householdId}/expenses` with an `Idempotency-Key` header.
2. Gateway validates the JWT signature and forwards the request with the token.
3. core-service `ExpenseController` (generated interface from OpenAPI) maps the DTO and calls `CreateExpenseUseCase`.
4. The use case loads membership, checks the caller's role, builds the `Expense` aggregate (invariants enforced in the constructor), persists it and writes an `ExpenseCreated` event row into `outbox` in the same transaction. [DIP: the use case depends on `ExpenseRepository` and `EventOutbox` ports.]
5. The outbox relay (Spring Modulith event publication or a Debezium connector, see ADR-003) publishes to Kafka topic `hushold.ledger.expense.v1`.
6. forecasting-service consumes it and marks the household's forecast stale; insights-service consumes it for anomaly detection.

## Asynchronous path: a receipt photo

1. App asks `POST /api/v1/media/uploads` (media-service) with content type and size; receives a presigned S3 PUT URL and a `mediaId`.
2. App uploads the image directly to S3.
3. App calls `POST /api/v1/media/uploads/{mediaId}/complete`. media-service verifies the object exists, computes SHA-256, generates a thumbnail, stores metadata, and emits `MediaUploaded` via outbox.
4. App calls `POST /api/v1/households/{id}/documents` on core-service with `mediaId` and `documentKind` (`RECEIPT` or `INVOICE`). core-service creates a `Document` in `QUEUED` state and emits `DocumentQueued`.
5. documents-worker consumes `DocumentQueued`, fetches the object from S3 via a presigned GET from media-service, calls the vision LLM through the `Extractor` port (implementations per provider), validates the result against a JSON Schema, and emits `DocumentExtracted` (or `DocumentExtractionFailed`).
6. core-service consumes `DocumentExtracted`, creates an `Expense` in `DRAFT` with `source=RECEIPT`, category guessed by the extractor mapped through the household's category tree, and emits `ExpenseDraftCreated`.
7. notifications-service (M7) pushes "Receipt from Netto, 234.50 DKK, tap to confirm". Before M7 the app polls or refreshes.
8. User confirms or edits in the app; `POST .../expenses/{id}/confirm` transitions to `CONFIRMED`.

Every consumer is idempotent using the CloudEvents `id`. Every step is traced with the same trace id propagated through Kafka headers (W3C `traceparent`).

## Data ownership

Database per service. Locally a single PostgreSQL instance with one database and one role per service; in AWS one RDS instance with the same layout until load justifies separation. No cross-database queries, no shared schemas. When a service needs another service's data for a read model, it builds its own projection from events (for example forecasting-service keeps its own `expense_facts` table populated from `ExpenseCreated`, `ExpenseUpdated`, `ExpenseVoided`).

## Contracts

- REST: OpenAPI 3.1 per public service under `contracts/openapi/`. Clients are generated. Breaking changes require a new `/api/v2` path; additive changes are fine.
- Events: JSON Schema per event version under `contracts/events/`. Consumers validate incoming payloads; producers validate outgoing ones in tests. See `docs/06-events.md`.
- Internal synchronous calls between services are rare by design. Where needed (documents-worker asking media-service for a presigned GET), they use REST with service-to-service tokens (Keycloak client credentials). gRPC is reserved for M5+ if market-ingest and insights-service need a high-volume streaming interface; do not introduce it earlier. [YAGNI]

## Cross-cutting

- **Authentication:** Keycloak realm `hushold`, clients `ios-app` (public, PKCE), `android-app` (M8), one confidential client per service. Identity brokering to Apple and Google. See `docs/08-security-privacy.md`.
- **Authorisation:** performed inside use cases against Membership, not in the gateway. Gateway only checks the token.
- **Idempotency:** all POST endpoints that create state accept `Idempotency-Key`; core-service stores key, request hash and response for 24 hours in Redis.
- **Observability:** OpenTelemetry SDK in every service; traces to Tempo, metrics to Prometheus, logs to Loki, dashboards in Grafana. Each service ships a Grafana dashboard JSON in its repo folder.
- **Configuration:** twelve-factor; environment variables, with a typed config object per service. Secrets from AWS Secrets Manager via External Secrets Operator in Kubernetes.
- **Resilience:** timeouts on every outbound call, retries with jitter only on idempotent operations, circuit breaker (Resilience4j in Java, `gobreaker` in Go) around LLM and external APIs, dead-letter topics for poison events.

## Rejected alternatives (summary; details in ADRs)

- Single modular monolith: rejected as the end state (ADR-001), but Spring Modulith discipline is kept inside core-service.
- Kotlin Multiplatform for shared client logic: rejected (ADR-006); thin clients plus generated API clients give most of the benefit.
- Amazon Cognito instead of Keycloak: rejected (ADR-005); Keycloak is portable and richer, and demonstrates OIDC administration.
- MSK: rejected on cost (ADR-007); Strimzi on EKS.
- Python service for forecasting: deferred (ADR-008); start with statistical methods in Java, introduce a Python service only if a model that needs it is chosen in M3.
