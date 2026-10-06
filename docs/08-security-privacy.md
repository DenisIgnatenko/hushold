# 08. Security and privacy

## Identity

- Keycloak realm `hushold`. Public client `ios-app` uses Authorization Code with PKCE via `AppAuth`; tokens stored in the iOS Keychain. Refresh token rotation enabled. Access token lifetime 10 minutes, refresh 30 days with sliding expiry.
- Identity brokering: Sign in with Apple (mandatory for App Store when any third-party login is offered) and Google. Email plus password stays enabled for development and as fallback.
- Services validate JWTs locally against the realm JWKS (cached); the gateway does the same and rejects early. Audience and issuer are checked.
- Service-to-service calls use client credentials with per-service confidential clients and a dedicated audience.

## Authorisation

Two layers, both mandatory:
1. Token validity and audience (gateway and service filter).
2. Use-case level: the caller's `userId` must be an active member of the household in the path with a role sufficient for the operation. This check is a single reusable component (`HouseholdAccessPolicy`) injected into use cases, never repeated inline. [DRY, SRP]

Role matrix (excerpt):

| Operation | OWNER | ADULT | LIMITED |
|---|---|---|---|
| Create expense | yes | yes | yes (own) |
| Edit or void any expense | yes | yes | own only |
| Manage categories, rules | yes | yes | no |
| Invite members | yes | yes | no |
| Change roles, delete household | yes | no | no |
| View household summary | yes | yes | yes |

## Household isolation

- All repository methods take `householdId` as a parameter; there is no "find by id" without household. Repository tests include a negative cross-household case.
- Optional hardening at M7: PostgreSQL row-level security with `SET app.household_id` per request, as a second line of defence.
- Media keys are prefixed by household id; presigned URLs are minted only after a membership check.

## Data minimisation towards LLM providers

- documents-worker sends the image and a fixed prompt. It does not send member names, household names or notes.
- insights-service sends aggregated numbers, category names, merchant names and dates. Free-text notes are sent only if the household has enabled `llmNotesOptIn` in settings, and only after redaction of email addresses, phone numbers and CPR-like patterns.
- Prefer provider endpoints and settings with no training on inputs and zero or minimal retention; record the choice in ADR-008.
- Every LLM call is logged with tokens and cost but never with the full prompt at INFO; full prompts are stored in the service database with the same retention as extractions.

## GDPR

- Lawful basis: contract (providing the service). Consent is collected separately for the notes opt-in and for market recommendations that profile purchases.
- Right of access: `POST /me/export` produces a ZIP with JSON of all personal data across services (each service contributes via a `PersonalDataExportRequested` event; core assembles) plus media files.
- Right to erasure: account deletion and household deletion flows fan out through events; each service reports completion; the flow is complete when all services have acknowledged. Keycloak user deleted last.
- Data location: AWS `eu-north-1` (Stockholm) or `eu-central-1` (Frankfurt). Never outside the EU.
- Privacy policy and data map maintained in `docs/04-data-model.md`, GDPR section.

## Application security baseline

- Input validation at the boundary, output encoding not applicable (no HTML), parameterised queries only.
- Rate limiting at the gateway per user and per IP; stricter limits on upload and extraction endpoints.
- Dependency scanning (Dependabot, Trivy), secrets scanning in CI.
- Uploads: mime sniffing server-side, size limits, image re-encoding to strip metadata (EXIF, including GPS) before storage.
- Audit log of role changes, invitations, deletions and exports in core-service.
- Threat model document at M7 (`docs/09-threat-model.md`), STRIDE per service.
