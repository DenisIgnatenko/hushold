# hushold

hushold (from Danish *husholdning*, household) is an expense tracker for families living in Denmark. Each member records spending from their own phone, by hand or by photographing a receipt that AI turns into a draft; the household sees the whole month, a forecast of what is coming, and concrete suggestions for spending less based on Danish retail data. It is also a deliberately production-grade demonstration of event-driven Java and Go microservices; every architectural choice is justified in [`docs/adr/`](docs/adr/).

## Architecture

```
                 +-------------------+          +--------------------+
   iOS app  ---> |  API gateway      | -------> |  Keycloak (OIDC)   |
 (Android later) |  (Traefik)        |          +--------------------+
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

  PostgreSQL: one database per service (one instance locally, CloudNativePG in Kubernetes)
  Redis: cache and rate limiting (shared instance, key-prefixed per service)
  S3 / SeaweedFS locally: receipt images and PDFs (media-service owns the bucket)
  OpenTelemetry collector -> Prometheus, Loki, Tempo, Grafana
```

Details: [`docs/02-architecture.md`](docs/02-architecture.md), services in [`docs/03-services.md`](docs/03-services.md), local environment in [`docs/07-infrastructure.md`](docs/07-infrastructure.md).

## Run locally

Requires OrbStack (or any Docker with Compose v2), JDK 21+, Go 1.27, Node 22, GNU make.

```sh
make up          # platform and services, waits until healthy
make test        # unit and Testcontainers tests of every service
make down        # stop, keep data (make reset wipes it)
make help        # every other target
```

## Milestones

| Milestone | Outcome | Status |
|---|---|---|
| [M0](tasks/M0-foundation.md) Foundation | Repository, Compose platform, service skeletons, one traced authenticated request | in progress |
| [M1](tasks/M1-ledger.md) Ledger | Households, categories, expenses, iOS daily entry, media uploads, outbox | planned |
| [M2](tasks/M2-receipts.md) Receipts | Photo and PDF to draft expense through OCR and LLM | planned |
| [M3](tasks/M3-forecast.md) Forecast | Committed and variable spending forecast | planned |
| [M4](tasks/M4-insights.md) Insights | Monthly insights, anomalies, ask-your-ledger | planned |
| [M5](tasks/M5-market.md) Market | Danish offers and savings recommendations | planned |
| [M6](tasks/M6-bank-import.md) Bank import | PSD2 import as drafts (optional) | planned |
| [M7](tasks/M7-cloud-rehearsal-and-release.md) Cloud rehearsal | Helm, ArgoCD, time-boxed EKS window, push, TestFlight | planned |
| [M8](tasks/M8-android.md) Android | Kotlin and Compose app at parity | planned |
