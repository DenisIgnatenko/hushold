# M7: Cloud rehearsal, notifications, release

Goal: the system is deployed with Helm and ArgoCD on the permanent local k3s target, has been deployed to a time-boxed EKS environment with real data migrated in and out, push notifications work, and the iOS app is in TestFlight.

Read first: `docs/07-infrastructure.md`, ADR-007, ADR-009.

## Tasks

### 7.1 Kubernetes on the local k3s machine (permanent target)
- Helm charts per service plus the library chart; `values-local-k3s.yaml`.
- ArgoCD installed on the OrbStack `hushold-k3s` machine, watching this repository; image tags updated by CI commits to values files.
- SOPS with `age` for secrets; key stored outside the repository.
- kube-prometheus-stack, Loki, Tempo, Grafana with Keycloak OIDC login; dashboards and alerts per service; Alertmanager to Telegram.
- CloudNativePG for PostgreSQL with scheduled backups to an S3-compatible bucket (MinIO locally, S3 in the cloud).
- Redpanda single node via Helm.

### 7.2 demo-aws window
- Terraform under `infra/terraform/aws/` per `docs/07-infrastructure.md`, with `COST.md` listing forbidden items and the idle checklist.
- `make aws-up`, then `scripts/migrate-in.sh` moving the household's real data from local to the cloud (Postgres dump and restore, rclone for objects, Keycloak realm export and import).
- `values-demo-aws.yaml` with IRSA annotations, External Secrets for provider keys, ALB ingress, ACM certificate, Route 53 record.
- Household uses the cloud environment for one to two weeks from the TestFlight build.
- `scripts/migrate-out.sh` back to local; `make aws-down`; verify the account is empty and the next day's bill shows nothing recurring.
- `docs/writeups/m7-cloud-rehearsal.md` with the measured cost, the timings of apply, migration and destroy, and what broke.

### 7.3 notifications-service (Go)
- Device registry, `Sender` interface with `apnsSender`; consumers for `ExpenseDraftCreated`, `DocumentExtractionFailed`, `InsightGenerated`, `RecommendationGenerated`, `RecurringOccurrenceDue`; per-user quiet hours.

### 7.4 Compliance and hardening
- Account export and deletion flows completed across all services; Keycloak deletion last.
- Threat model `docs/09-threat-model.md` (STRIDE per service); row-level security decision; rate limits tuned.
- Load test with k6 on expense creation and month summary at the 1000-user load targets from `docs/00-vision.md`; SLOs documented with alerts.

### 7.5 Release
- Apple Developer Program enrolment; Sign in with Apple enabled; privacy nutrition labels; TestFlight build; self-hosted macOS runner for the iOS workflow.

## Definition of Done
- [ ] A commit to main deploys to the local k3s machine through ArgoCD without manual steps.
- [ ] `terraform apply` from zero to a running EKS system, documented and repeated once; `terraform destroy` leaves nothing billable.
- [ ] Real household data migrated to the cloud and back with no loss (row counts and checksums compared).
- [ ] Push notification received on a real device for a receipt draft.
- [ ] Export ZIP and full deletion verified for a test household across every service and object storage.
- [ ] Dashboards and alerts exist for every service; one alert tested by breaking something.
- [ ] Household uses the TestFlight build daily for two weeks.
- [ ] Measured cost of the cloud window recorded in the write-up.
- [ ] Tag `m7-done`.
