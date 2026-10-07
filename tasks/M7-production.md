# M7: Production on AWS, notifications, TestFlight

> Status: Superseded by `tasks/M7-cloud-rehearsal-and-release.md` (ADR-009). Kept for history; do not implement from this file.

Goal: the system runs on EKS with GitOps and full observability, push notifications work, and the iOS app is distributed via TestFlight to the household.

## Tasks
- Terraform per `docs/07-infrastructure.md`; `COST.md`; idle procedure.
- Helm charts per service plus library chart; ArgoCD apps; image promotion by CI commit.
- Strimzi Kafka, Keycloak, Redis on cluster or ElastiCache (ADR), External Secrets, kube-prometheus-stack, Loki, Tempo, Grafana with Keycloak OIDC.
- notifications-service (Go): device registry, `Sender` interface with `apnsSender`; consumers for `ExpenseDraftCreated`, `DocumentExtractionFailed`, `InsightGenerated`, `RecommendationGenerated`, `RecurringOccurrenceDue`; per-user quiet hours.
- Account export and deletion flows completed across all services; Keycloak deletion last.
- Threat model `docs/09-threat-model.md`; row-level security decision; rate limits tuned; WAF basic rules.
- Load test with k6 on expense creation and month summary; SLOs documented (p95 latency, availability) with alerts.
- App Store readiness: Sign in with Apple enabled, privacy nutrition labels, TestFlight build.

## Definition of Done
- [ ] `terraform apply` from zero to a running system, documented and repeated once.
- [ ] A commit to main deploys through ArgoCD without manual steps.
- [ ] Push notification received on a real device for a receipt draft.
- [ ] Export ZIP and full deletion verified for a test household across every service and S3.
- [ ] Dashboards and alerts exist for every service; one alert tested by breaking something.
- [ ] Household uses the TestFlight build daily for two weeks.
- [ ] `docs/writeups/m7-platform.md`.
- [ ] Tag `m7-done`.
