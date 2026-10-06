# 09. Roadmap

Each milestone has its own file in `tasks/` with the detailed task list and Definition of Done. This page is the map. Time estimates assume evenings and weekends with Claude Code doing most of the typing; they are deliberately conservative. Overrunning an estimate is fine; skipping a Definition of Done is not.

| Milestone | Outcome | New technology | Estimate |
|---|---|---|---|
| M0 Foundation | Repo, CLAUDE.md, Compose, CI, service skeletons with health, one end-to-end request through gateway and Keycloak | Gradle, Go module, Docker, Traefik, Keycloak, GitHub Actions, OpenTelemetry basics | 2 weeks |
| M1 Ledger | Households, members, invitations, categories, manual expenses, recurring rules (create only), month and day read models; media-service uploads; iOS app for daily entry | Spring Modulith, Flyway, Testcontainers, outbox, Kafka (Redpanda), sqlc, S3 presigned flow, SwiftUI, swift-openapi-generator, AppAuth | 6 weeks |
| M2 Receipts | Photo and PDF to draft expense: on-device OCR and text model first, vision model as fallback (ADR-010); confirm flow in app; failure handling; cost caps and cost per receipt metric | VisionKit OCR, franz-go consumers, LLM provider adapters, JSON Schema validation, DLQ, tracing across Kafka | 4 weeks |
| M3 Forecast | Recurring occurrence generation, committed spending, variable spending prediction with bands, forecast screen | Event projections, scheduled jobs, statistical forecasting | 4 weeks |
| M4 Insights | Monthly insights, anomalies, AI recommendations, ask-your-ledger with SSE | LangChain4j, pgvector, RAG, SSE | 4 weeks |
| M5 Market | Danish offer ingestion from at least one real source, product matching, recommendations screen | Source adapters, scheduling, fuzzy matching, terms-of-service review per source | 5 weeks |
| M6 Bank import (optional) | Transactions imported from a PSD2 aggregator sandbox, deduplicated against manual entries, proposed as drafts | OAuth flows with aggregator, reconciliation | 3 weeks |
| M7 Cloud rehearsal and release | Time-boxed EKS window via Terraform with real data migrated in and out (ADR-009), ArgoCD and Helm on the OrbStack k3s machine as the permanent target, observability stack, notifications (APNs), TestFlight, threat model, runbooks | Kubernetes, Helm, Terraform, IRSA, External Secrets, SOPS, APNs | 6 weeks |
| M8 Android | Kotlin and Compose app at parity for entry, receipts, summary, forecast; FCM sender | Kotlin, Compose, Room, openapi-generator kotlin, FCM | 6 weeks |

Infrastructure cost for M0 to M6 is zero (developer's Mac with OrbStack); M7 costs 40 to 60 USD for the cloud window plus 99 USD per year for the Apple Developer Program.

Total: roughly 40 weeks of part-time work. Phases A (M0 to M2), B (M3 to M5), C (M6 to M8) each end with a demo the developer can show in an interview.

## Rules of the road

- Do not begin M(n+1) before M(n)'s Definition of Done is met and tagged (`git tag m1-done`).
- Each milestone ends with an update to `README.md` (what works, screenshots, how to run) and, where applicable, a short write-up in `docs/writeups/` explaining one interesting decision. These write-ups double as interview material.
- If a milestone stalls for more than three weeks with no commits, the next session starts by cutting scope from that milestone, not by adding tools.
