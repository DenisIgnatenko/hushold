# M0: Foundation

Goal: a repository where every later milestone has a place to land, and one authenticated request travels through gateway, Keycloak and a service with a trace visible in Grafana.

Read first: `CLAUDE.md`, `docs/00-vision.md`, `docs/02-architecture.md`, `docs/07-infrastructure.md`, ADR-009.

Environment: the developer's Mac with OrbStack. Nothing in this milestone touches a cloud account. The Terraform directory is created as a skeleton with a README only; it is written in M7.

## Tasks

### 0.1 Repository
- Create the layout from `CLAUDE.md` section 3. Empty directories get a `README.md` stating what will live there and in which milestone.
- Root `Makefile` with the targets listed in `docs/07-infrastructure.md`.
- `.editorconfig`, `.gitignore` (Java, Go, Swift, Terraform), `.gitattributes`.
- Root `README.md`: one paragraph on the product, the architecture diagram from `docs/02-architecture.md`, how to run locally, milestone status table.

### 0.2 Local platform (Compose)
- `infra/compose/docker-compose.yml` with PostgreSQL 16 (init script creating databases `core`, `media`, `documents`, `forecasting`, `insights`, `market`, `notifications`, `keycloak`, each with its own role), Redis 7, Redpanda plus Console, Keycloak with realm import, MinIO with bucket bootstrap, Traefik, OpenTelemetry Collector, Prometheus, Grafana, Loki, Tempo.
- Keycloak realm `hushold` in `infra/keycloak/realm-hushold.json`: clients `ios-app` (public, PKCE, redirect `hushold://auth/callback`), `core-service`, `media-service` (confidential), two test users, a `household-user` realm role. Apple and Google brokers configured with placeholder secrets and disabled by default.
- Grafana provisioned with data sources and an empty "hushold overview" dashboard.
- `make up` brings everything healthy; `make reset` wipes volumes.

### 0.3 core-service skeleton (Java)
- Gradle Kotlin DSL, Java 21, Spring Boot 3.x, Spring Modulith, Spring Web, Spring Security (resource server JWT), Actuator, Micrometer with OTLP, Flyway, Spring Data JPA, Testcontainers, openapi-generator plugin.
- Package `com.hushold.core` with modules `shared`, `membership`, `ledger`, `documents` as empty Spring Modulith modules and a passing `ApplicationModules.verify()` test.
- `contracts/openapi/core-service.yaml` containing only `GET /me` for now; controller generated and implemented to return the token subject and an empty membership list.
- Security: JWT validation against the local Keycloak, audience check, `HouseholdAccessPolicy` interface declared (implementation in M1).
- Problem Details advice with one mapped exception (`DomainException`).
- Structured JSON logging with MDC (`userId`, `traceId`).
- Flyway `V1__init.sql` creating `outbox` and `processed_events` only.
- Dockerfile as specified. Health at `/actuator/health`, metrics at `/actuator/prometheus`, traces exported to the collector.

### 0.4 media-service skeleton (Go)
- Go module `github.com/<owner>/hushold/services/media-service`, layout per `CLAUDE.md` section 7.
- `chi` router with `/healthz`, `/readyz`, `/metrics`; JWT validation middleware against Keycloak JWKS; slog JSON logging; OpenTelemetry tracing with OTLP exporter.
- `golang-migrate` with `000001_init.up.sql` creating `outbox`, `processed_events`.
- `sqlc` configured with one trivial query to prove the pipeline.
- Dockerfile as specified.

### 0.5 Gateway
- Traefik routes: `/api/v1/me`, `/api/v1/households` to core-service; `/api/v1/media` to media-service. ForwardAuth is not used; services validate tokens themselves. Rate limit middleware with generous local values.

### 0.6 CI
- `.github/workflows/core-service.yml`, `media-service.yml`, `contracts.yml`, each path-filtered. Steps: lint, test (Testcontainers), build image, Trivy scan. `contracts.yml` runs Spectral on OpenAPI files and validates example events against schemas (examples directory may be empty in M0).

### 0.7 Contracts directory
- `contracts/events/README.md` describing the envelope and naming; `contracts/events/_envelope.schema.json` for CloudEvents attributes; one example event file validating against it.
- `contracts/design-tokens/tokens.json` with an initial palette, spacing scale and type scale; a script (`scripts/gen-tokens-swift.sh`) that generates `apps/ios/.../DesignTokens.swift`. Kotlin generation is added in M8.

### 0.8 Documentation hygiene
- `docs/adr/` contains ADR-000 to ADR-008 (already present) plus any new ADR created during M0.
- `services/core-service/RUNBOOK.md`, `services/media-service/RUNBOOK.md` with start, health, dashboards.

## Definition of Done
- [ ] `make up` on a clean machine results in all containers healthy within 3 minutes.
- [ ] Obtaining a token from Keycloak for a test user and calling `GET /api/v1/me` through Traefik returns 200 with the subject; calling without a token returns 401; a token with wrong audience returns 401.
- [ ] The request appears as a trace in Tempo via Grafana, with spans from Traefik and core-service, and the log line with the same `traceId` is visible in Loki.
- [ ] `make test` passes for both services, including a Testcontainers-backed test that runs migrations.
- [ ] CI is green on the main branch for all three workflows.
- [ ] `ApplicationModules.verify()` passes.
- [ ] Both Dockerfiles produce multi-arch images under 200 MB (Java) and 30 MB (Go), running as non-root, pushed to GHCR by CI.
- [ ] `make k3s-create` results in `kubectl get nodes` showing one Ready node inside the OrbStack machine.
- [ ] README explains how to run all of the above in under ten lines.
- [ ] Tag `m0-done`.
