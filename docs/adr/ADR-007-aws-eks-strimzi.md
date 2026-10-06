# ADR-007: AWS with EKS; Kafka via Strimzi rather than MSK

- Status: Accepted; timing superseded by ADR-009 (cloud used in a time-boxed M7 window, not permanently)
- Date: 2026-09-29
- Milestone: M7

## Context
Target cloud options: Azure (dominant at large Danish enterprises), AWS (developer preference and certification roadmap), Hetzner with k3s (cheapest). Managed Kafka (MSK) costs more than the rest of the stack combined at this scale.

## Decision
AWS in an EU region, EKS with Terraform and ArgoCD. Kafka runs on EKS via the Strimzi operator. Production is provisioned only at M7; M0 to M6 run locally.

## Consequences
- Monthly cost budgeted in `infra/terraform/COST.md` with an idle procedure.
- Operating Kafka on Kubernetes is itself a demonstrable skill.
- Portability to Azure later is realistic because nothing depends on AWS-only services except S3 (abstracted behind the S3 API) and IAM (IRSA, replaceable by workload identity).
