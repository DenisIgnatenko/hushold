# ADR-009: Local-first environments; cloud as a rehearsed, time-boxed window

- Status: Accepted (supersedes the "when" part of ADR-007; the AWS and Kubernetes choices in ADR-007 stand)
- Date: 2026-10-06
- Milestone: M0 (applies to all)

## Context
The system will have two users (the developer's household) and perhaps a few test households for a long time. Permanent cloud infrastructure at this stage costs 120 to 250 USD per month on AWS, which the developer considers unjustified. A home server costs money up front and raises availability and GDPR questions for third-party households. The developer's Mac has 64 GB of memory and can run the whole stack.

Options considered: permanent EKS (ADR-007 as originally written); Hetzner k3s at about 20 EUR per month; a home mini PC; the Mac only, with the cloud used in short windows.

## Decision
- Phases A and B (M0 to M6) run exclusively on the developer's Mac via OrbStack (Compose for daily work, an OrbStack Linux machine with k3s for Helm and ArgoCD).
- M7 creates a minimal EKS environment with Terraform for one to two weeks, migrates real data in and out, and destroys it. This proves the cloud path at 40 to 60 USD per window.
- A home x86 mini PC (32 GB, Core Ultra 5 class) is an optional later step if 24/7 availability for the household becomes desirable; Hetzner remains the fallback if a permanent EU-hosted environment is needed before paying users exist.
- Permanent cloud infrastructure is created only when funded by external paying households.

## Consequences
- Zero infrastructure cost for at least the first two phases.
- Every environment uses the same Helm charts and ArgoCD setup, so portability is exercised rather than assumed; the M7 migration is the rehearsal for any later move.
- Availability during phases A and B depends on the Mac being on; acceptable for the household.
- Interview one-liner: "I kept the stack cloud-portable but ran it on my laptop until there was a reason to pay; the EKS deployment is Terraform I have applied and destroyed, not a diagram."
