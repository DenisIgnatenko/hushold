# ADR-014: Build, lint and CI tooling

- Status: Accepted
- Date: 2026-10-06
- Milestone: M0

## Context
M0 requires lint, tests, contract checks and image scanning in CI, and a set of `make` targets, but the documents leave several tool choices open or contradictory:
- No Java linter or formatter is named.
- No JSON Schema validator is named for event examples.
- No severity threshold is set for Trivy.
- `CLAUDE.md` section 7 says Go migrations use "the same naming as Java" (`V1__name.sql`), while `tasks/M0-foundation.md` uses `000001_init.up.sql`. golang-migrate only understands `{version}_{title}.up.sql` and `.down.sql`.
- The M0 DoD requires `make k3s-create`, which is missing from the target list in `docs/07-infrastructure.md`; `k3s-deploy` and `k3s-argocd` are listed there but belong to M7.
- `scripts/` is used by M0 (design tokens) and M7 (data migration) but is not part of the layout in `CLAUDE.md` section 3.

## Decision
- Java formatting and lint: Spotless with palantir-java-format, enforced by `./gradlew spotlessCheck` in CI. It formats with four spaces, matching `.editorconfig`.
- Go lint: golangci-lint with `.golangci.yml` at the repository root (as `CLAUDE.md` section 7 already requires); CI fails on any finding.
- OpenAPI lint: Spectral with `.spectral.yaml` at the repository root.
- JSON Schema validation: `ajv-cli` (draft 2020-12) through `npx`, wrapped in `scripts/validate-events.sh`, used by both `make events-validate` and CI. [DRY: one script, two callers]
- Trivy: the build fails on CRITICAL vulnerabilities that have a fix available (`--ignore-unfixed`); HIGH findings are reported but do not fail the build.
- Go migrations follow golang-migrate naming: `000001_init.up.sql` and `000001_init.down.sql`. The rule in `CLAUDE.md` section 7 is read as "same versioning discipline", not the same file name format.
- `make k3s-create` is added. `make k3s-deploy` and `make k3s-argocd` exist from M0 but exit with a message pointing to M7. [YAGNI: no Helm or ArgoCD work before M7, yet the documented interface stays stable]
- `scripts/` is a top-level directory for automation called from the `Makefile` and CI; its README lists every script and its milestone.
- Every CI workflow is path-filtered and also has `workflow_dispatch`, so each can be run on `main` on demand.

## Consequences
- Formatting arguments are settled by tools, not reviews; CI and local `make lint` run the same commands.
- `npx` downloads ajv-cli and Spectral on first use; Node 22 is required locally (already installed) and is preinstalled on GitHub runners.
- Ignoring unfixed vulnerabilities means a known but unpatched CRITICAL issue does not block work; it remains visible in the scan report.
- Interview one-liner: "Every quality gate is one command that runs the same way on my laptop and in CI, and each tool choice is written down with its reason."
