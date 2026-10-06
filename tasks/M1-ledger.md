# M1: Ledger and daily entry

Goal: the developer's household records every expense of the day from the iOS app, with categories, sees a month summary, and can upload a photo that is stored for M2. Kafka and the outbox are live.

Read first: `docs/01-domain-model.md`, `docs/03-services.md` (core-service, media-service), `docs/04-data-model.md`, `docs/05-api-contracts.md`, `docs/06-events.md`, ADR-003, ADR-004.

## Part A: core-service

### A.1 Shared kernel (`shared` module)
- `Money` value object: constructor validation, `plus`, `minus`, `times(int)`, `allocate(int parts)` with deterministic remainder distribution, equality, `toString` for logs. Tests for every operation including overflow guard. [KISS: no generic arithmetic framework]
- Typed ids: `HouseholdId`, `MemberId`, `UserId`, `ExpenseId`, `CategoryId`, `RuleId`, `DocumentId`, `MediaId` as records wrapping UUID v7. JPA attribute converters.
- `DomainException` hierarchy and Problem Details mapping for: `NotFound`, `NotAMember`, `InsufficientRole`, `InvalidState`, `Validation`, `Conflict`.
- Outbox: `EventOutbox` port, JPA adapter, Spring Modulith externalisation to Kafka with CloudEvents envelope, `householdid` and `traceparent` headers. Integration test with Testcontainers Kafka asserting the envelope. [DIP]
- Idempotency filter for POST: Redis-backed, key scoped by user, stores response for 24 hours.
- `HouseholdAccessPolicy` implementation with the role matrix from `docs/08-security-privacy.md`; unit tests for every cell.

### A.2 Membership module
- Aggregates: `Household`, `Member`, `Invitation`.
- Use cases: `CreateHousehold` (copies default category tree via a `ledger` published interface, not by touching ledger tables) [Modulith boundary], `GetMyMemberships`, `UpdateHousehold`, `ListMembers`, `ChangeMemberRole` (last OWNER rule), `RemoveMember`, `CreateInvitation` (returns token once; store hash), `AcceptInvitation`, `RequestHouseholdDeletion` (emits event, marks household).
- Events: `HouseholdCreated`, `MemberJoined`, `HouseholdDeletionRequested`.
- Endpoints: all under "Me", "Households" in `docs/05-api-contracts.md` except export and account deletion (M7).
- First-login provisioning: when a token subject is unknown, `GET /me` returns empty memberships; `POST /households` creates the member from token claims (`name` or `email` local part as displayName).

### A.3 Ledger module
- Aggregates: `Category` (tree, depth 3, archive), `Expense` (with items, tags, status machine), `RecurringRule` (create and list only in M1; generation in M3).
- Default category tree seeded from a YAML resource matching Appendix A; `CategoryTemplateService` copies it per household.
- Use cases: categories CRUD and move; `CreateExpense` (confirmed or draft), `UpdateExpense` (optimistic version via `If-Match`), `ConfirmExpense`, `VoidExpense`, `ListExpenses` (cursor pagination on `(occurred_on, id)`), `GetExpense`, `ListDrafts`; `CreateRecurringRule`, `ListRecurringRules`.
- Read models: `MonthSummary` (`GET /summary`) and `DaySheet` (`GET /day`) implemented as dedicated query classes with native SQL, not by loading aggregates. [SRP: write model and read model separated]
- Events: `ExpenseCreated`, `ExpenseUpdated`, `ExpenseConfirmed`, `ExpenseVoided`, `ExpenseDraftCreated`, `CategoryChanged`, `RecurringRuleChanged`, with schema files under `contracts/events/ledger/` and example payloads validated in CI.
- Tests: domain unit tests for the status machine and invariants; repository tests including the cross-household negative case; end-to-end test: create household, create expense, confirm, month summary matches; outbox test: confirming an expense produces exactly one `ExpenseConfirmed` on Kafka.

### A.4 Documents module (state only)
- `Document` entity with state machine; `POST /documents` validates `mediaId` ownership by consuming `MediaUploaded` into a local `known_media` table (eventual) or, if the event has not arrived yet, by a synchronous call to media-service `GET /internal/media/{id}` with a service token (fallback, logged). Emits `DocumentQueued`. Extraction handling is M2.

## Part B: media-service

- `POST /media/uploads`: membership is verified by calling core-service `GET /internal/households/{id}/members/{userId}` with a service token and caching the answer in Redis for 5 minutes. Record `PENDING`, return presigned PUT with content-type and length conditions.
- `POST /uploads/{id}/complete`: `HEAD` the object, verify size and mime by sniffing the first bytes, compute SHA-256 streaming, re-encode images (strip EXIF) into the final key, generate a 512 px thumbnail, set `UPLOADED`, write `MediaUploaded` to outbox.
- Outbox relay goroutine with `FOR UPDATE SKIP LOCKED`, batch size 100, publishing with `franz-go`, marking `published_at`.
- `GET /media/{id}/url?variant=`: membership check, presigned GET 5 minutes.
- `DELETE /media/{id}`: allowed only if no `ExpenseConfirmed` referenced it (tracked by consuming `ExpenseConfirmed` into `linked_media`).
- Retention job: objects with `retention_until < now()` deleted from S3 and marked `DELETED`, `MediaDeleted` emitted.
- Tests: handler tests with an in-memory S3 fake behind the `ObjectStore` interface [DIP], integration test with MinIO and Postgres Testcontainers, relay test asserting exactly-once publication under concurrent relays.

## Part C: iOS app (apps/ios)

- Xcode project `Hushold`, SwiftUI, iOS 17, Swift Package dependencies: `swift-openapi-generator`, `swift-openapi-urlsession`, `AppAuth`.
- Auth flow with PKCE against local Keycloak (use a reverse proxy hostname reachable from the simulator), token storage in Keychain, automatic refresh, sign out.
- Screens: Households list and create; Household home (today's day sheet, quick add); Add expense (amount with Danish keypad, category picker with the tree, date default today, merchant, note, tags, photo attach); Expense detail and edit; Month summary (totals, per category bars, per member); Drafts inbox (empty until M2); Settings (household, members, invite link share sheet).
- Offline: SwiftData cache of categories, last 60 days of expenses, month summary; write queue with idempotency keys replayed on connectivity; conflict shown to user on 412.
- Photo attach: capture or pick, upload via media-service presigned flow, attach `mediaId` to the expense (as an attachment; document queuing is M2).
- Design tokens generated from `contracts/design-tokens/tokens.json`.
- Tests: view model unit tests for the add-expense flow and the offline queue; one UI test for the add flow.

## Part D: platform
- Redpanda topics created by a bootstrap script from the catalogue in `docs/06-events.md` (only topics with producers in M1).
- Grafana dashboard: request rate, latency, error rate per service; outbox lag; Kafka consumer lag.
- `contracts.yml` CI now validates all M1 event examples and checks that the generated Swift client is up to date.

## Definition of Done
- [ ] Two members of the household, on two devices, record expenses in the same household from the iOS app; both see the day sheet and month summary update.
- [ ] Invitation flow works end to end via a shared link.
- [ ] Creating a category, moving it, archiving it, and creating expenses against it behave per the invariants; tests cover them.
- [ ] Confirming an expense produces one `ExpenseConfirmed` on Kafka with a valid envelope; media-service consumes it and records the link.
- [ ] Photo upload works from the app through presigned URLs; EXIF is stripped; thumbnail exists.
- [ ] The app works offline for reading last month and adding expenses; queued expenses sync without duplicates (idempotency verified by test).
- [ ] Cross-household access attempts return 404 (tests exist for expenses, categories, media).
- [ ] Traces show a single trace id from the iOS request through core-service, outbox, Kafka and media-service consumer.
- [ ] Runbooks updated; README shows screenshots; `docs/writeups/m1-outbox.md` written.
- [ ] The developer's household has used the app for seven consecutive days.
- [ ] Tag `m1-done`.
