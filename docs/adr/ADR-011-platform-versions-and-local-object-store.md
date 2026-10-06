# ADR-011: Platform versions for M0 and SeaweedFS as the local object store

- Status: Accepted (supersedes the version statements "Spring Boot 3.x" in `CLAUDE.md` section 6 and "Keycloak 25" and "MinIO" in `docs/07-infrastructure.md`; those documents are not rewritten)
- Date: 2026-10-06
- Milestone: M0 (applies to all)

## Context
The specification was written with versions that were current when it was drafted. At the start of M0 (October 2026):
- Spring Boot 3.5, the last 3.x line, left open-source support in June 2026. The supported line is 4.x (4.1.1 is the latest GA release), paired with Spring Modulith 2.x (2.1.1).
- Keycloak 25 no longer receives fixes; the current release is 26.8.0.
- Go 1.23, the minimum in `CLAUDE.md` section 7, is out of support; the current release is Go 1.27.
- MinIO, named as the local S3 store, no longer publishes container images: `minio/minio`, `quay.io/minio/minio` and `minio/mc` cannot be pulled from any registry (verified with `docker manifest inspect` on 2026-10-06). The community edition is source-only and in maintenance mode.
- The DoD of M0 asks for a Java image "under 200 MB" without saying how it is measured. A Temurin 21 JRE on Ubuntu plus a Spring Boot jar is about 150 MB compressed and above 300 MB uncompressed.

Alternatives considered for the object store: SeaweedFS (Apache-2.0, mature, single container), Garage (AGPL, needs a CLI bootstrap of layout and keys on every fresh start), RustFS (Apache-2.0, MinIO drop-in, young project), building MinIO from source (unmaintained, own build to own).

## Decision
- Java 21 (unchanged), Spring Boot 4.1.x, Spring Modulith 2.1.x.
- Keycloak 26.x (`quay.io/keycloak/keycloak`, pinned to a minor release in Compose).
- Go: the current stable release (1.27 at the time of writing) in `go.mod` and CI.
- PostgreSQL 16 and Redis 7 stay as specified.
- Local S3-compatible object storage is SeaweedFS (`chrislusf/seaweedfs`, S3 gateway enabled), bucket `hushold-media`. Every service talks to it through the plain S3 API only; nothing SeaweedFS-specific appears in application code. [DIP: the store is an adapter behind the S3 API, swappable for AWS S3 in `demo-aws`]
- The Java image size limit of 200 MB is measured as the compressed size reported by GHCR. Base image `eclipse-temurin:21-jre`. [KISS: no custom jlink runtime]
- Image tags are pinned to a minor version in Compose and Dockerfiles; upgrades are deliberate commits.

## Consequences
- The project starts on versions that receive security fixes, so Trivy findings are actionable rather than permanent noise.
- Spring Boot 4 is newer than some tooling: openapi-generator support must be verified in step 0.3. If generation does not work, that is a new ADR, not a silent downgrade.
- Wherever later documents say MinIO (M1 Testcontainers, M7 `rclone` migration, CloudNativePG backups), read "SeaweedFS locally, S3 in AWS". Testcontainers runs SeaweedFS as a generic container.
- The Java image metric is weaker than an uncompressed limit; it reflects what is pulled over the network, which is what matters for deploy time.
- Interview one-liner: "When MinIO stopped shipping images I swapped the local object store for SeaweedFS in one Compose service, because every service only speaks the S3 API."
