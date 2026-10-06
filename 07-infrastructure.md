# 07. Infrastructure

## Environments, in order of appearance

| Environment | Role | When | Monthly cost |
|---|---|---|---|
| `local` | The only environment for phases A and B. Developer's Mac (Apple Silicon, 64 GB) running OrbStack: Docker Compose for day-to-day work, a Linux machine with k3s for Helm and ArgoCD. | M0 to M6 | 0 |
| `demo-aws` | Time-boxed EKS environment created by Terraform, used to prove the cloud path, migrate real data in and out, and produce the M7 write-up. Destroyed after one to two weeks. | M7 | 40 to 60 USD per window |
| `home` (optional) | A small x86 Linux box (Intel Core Ultra 5 class, 32 GB) with k3s if the household wants the system running 24/7 without the Mac. Decided after M7. See ADR-009. | after M7 | about 40 DKK electricity |
| `prod-cloud` (future) | Permanent EKS (minimal profile) or equivalent, created only when there are external users paying for it. | undecided | about 120 to 150 USD |

The deployment artefacts (Helm charts, ArgoCD applications, Terraform) are identical across environments; only `values-<env>.yaml` files differ. Nothing in application code knows which environment it runs in beyond environment variables for Postgres, Kafka, S3, Redis and Keycloak addresses.

## Local environment

### Tooling
- OrbStack provides Docker, Compose, a Kubernetes toggle and Linux machines. No Docker Desktop. All project commands are standard `docker compose`, `kubectl`, `helm`; nothing is OrbStack-specific except hostnames.
- Hostnames: OrbStack resolves `<container>.<project>.orb.local` automatically. Keycloak's issuer is `http://keycloak.hushold.orb.local`, used identically by services, the browser and the iOS simulator. No `/etc/hosts` edits.
- A Linux machine `hushold-k3s` (Ubuntu) created with `orb create ubuntu hushold-k3s` runs k3s. It is used to install the Helm charts and ArgoCD exactly as they will be used in `demo-aws` and `home`. It is not the day-to-day workflow before M7.

### Docker Compose (M0 onwards)
`infra/compose/docker-compose.yml` starts, with `make up`:
- PostgreSQL 16, one instance; init script creates a database and role per service (`core`, `media`, `documents`, `forecasting`, `insights`, `market`, `notifications`, `keycloak`).
- Redis 7.
- Redpanda single node (Kafka API) plus Redpanda Console.
- Keycloak 25 with realm import from `infra/keycloak/realm-hushold.json`.
- MinIO with bucket `hushold-media` created on start.
- OpenTelemetry Collector, Prometheus, Grafana, Loki, Tempo, with dashboards provisioned from `infra/grafana/`. Retention 3 days locally.
- Traefik as gateway, routes from labels.
- The services, built from their Dockerfiles, grouped in Compose profiles (`core`, `documents`, `forecast`, `insights`, `market`, `notify`) so that `make up-core` starts only what M1 needs. With 64 GB the full stack can run at once; profiles exist for focus, not for memory.

Memory budget with limits set in Compose (and mirrored in Helm values): 512 MB heap per JVM service (768 MB container limit), 128 MB per Go service, 1 GB Redpanda, 1 GB Keycloak, 1 GB Postgres, 256 MB Redis, 512 MB MinIO, 3 GB for the observability stack. Full stack about 10 GB.

`make` targets: `up`, `up-<profile>`, `down` (stop, keep volumes), `reset` (drop volumes), `logs`, `migrate`, `test`, `lint`, `openapi-gen`, `events-validate`, `k3s-deploy` (helm upgrade into the OrbStack machine), `k3s-argocd` (install ArgoCD there).

Stopping: `make down` for the project; `orb stop` to stop the whole OrbStack VM and return memory to macOS; `orb stop hushold-k3s` for the k3s machine.

### Images
- Multi-arch builds (`linux/arm64` for the Mac, `linux/amd64` for any x86 target) via `docker buildx` in CI; locally arm64 only.
- Java: multi-stage Dockerfile, Eclipse Temurin 21 JRE, non-root, layered jar, container-aware memory flags.
- Go: multi-stage, `CGO_ENABLED=0`, distroless static, non-root.
- Registry: GHCR (free for public repositories) from M0. ECR only inside `demo-aws`.

### CI (GitHub Actions, from M0)
Path-filtered workflows per service: lint, unit tests, Testcontainers integration tests, multi-arch image build, contract checks (Spectral for OpenAPI, JSON Schema validation of example events, generated-client freshness), Trivy scan. iOS builds run on a self-hosted runner on the developer's Mac (GitHub macOS minutes are expensive); the workflow is added in M1.

### Secrets
Locally: dummy values named `local-only-*` in Compose. In any Kubernetes environment: SOPS with an `age` key; encrypted files committed to the repository, the private key present only on the target cluster (and in the developer's password manager). External Secrets Operator with AWS Secrets Manager is used only in `demo-aws`, to demonstrate it; it is not the default.

## demo-aws (M7)

Purpose: prove that the system runs on managed Kubernetes in an EU region, that Terraform creates it from zero, that real data migrates in and out, and that the developer can operate it. It is not meant to stay up.

Terraform under `infra/terraform/aws/`, remote state in S3 with DynamoDB locking, single workspace.
- Region `eu-north-1`.
- VPC with public subnets only; nodes in public subnets protected by security groups. No NAT Gateway.
- EKS (standard support version only), one managed node group with one `t4g.large` on-demand (or spot when acceptable), cluster autoscaler off.
- No RDS: PostgreSQL via CloudNativePG on the cluster with backups to S3.
- Kafka: Redpanda single node on the cluster (Strimzi is documented as the path for `prod-cloud`, not installed here).
- One S3 bucket for media, one for backups, one for Loki and Tempo.
- ECR repositories per service.
- One ALB through the AWS Load Balancer Controller, ACM certificate, Route 53 zone. One public IPv4 address only.
- Control plane logging to CloudWatch disabled; logs go to the in-cluster Loki.
- IRSA for media-service (S3) and CloudNativePG (backups); External Secrets Operator with AWS Secrets Manager for provider keys.
- ArgoCD installed by Terraform (Helm provider) and pointed at this repository; images from GHCR or ECR.

Forbidden cost items, enforced by a `COST.md` checklist and Terraform code review: NAT Gateway, extra public IPv4 addresses, CloudWatch Logs ingestion, Extended Support Kubernetes versions, a second cluster, RDS.

Procedure: `make aws-up` (terraform apply, about 25 minutes), data migration in (`scripts/migrate-in.sh`: pg_dump restore, rclone for MinIO to S3, Keycloak realm import), one to two weeks of real household use, data migration out, `make aws-down` (terraform destroy, verified empty account with a cost check the following day). Expected cost 40 to 60 USD per window.

## home (optional, after M7)

If chosen: Intel Core Ultra 5 class mini PC with 32 GB, Ubuntu Server or Proxmox VE with a k3s VM, Tailscale for all administrative access (Grafana, ArgoCD, Redpanda Console, Keycloak admin), Cloudflare Tunnel only if external test households need the API. Backups with CloudNativePG to an S3-compatible bucket outside the home (AWS S3 or Backblaze B2). Pull-based deployment through ArgoCD; no inbound ports. See ADR-009.

## prod-cloud (future)

Minimal EKS profile as in `demo-aws` but permanent, with Strimzi (three brokers) and RDS reconsidered at that point; funded by subscriptions, never by the developer. Trigger: first external paying household. The migration procedure rehearsed in M7 is the migration procedure used here.

## Helm

One chart per service under `infra/k8s/charts/<service>/` with Deployment, Service, HPA, PodDisruptionBudget, ServiceAccount (IRSA annotation when applicable), ConfigMap, Secret (SOPS) or ExternalSecret, ServiceMonitor, ingress toggle. A shared library chart holds common templates. [DRY] Values files: `values.yaml` (defaults), `values-local-k3s.yaml`, `values-demo-aws.yaml`, `values-home.yaml`.

## Runbooks

Each service folder has `RUNBOOK.md`: start, health endpoints, dashboards, common failures, replaying events from an offset, rebuilding a projection. `infra/RUNBOOK.md` covers environment creation and teardown.
