# 03. Services

Each service section states: responsibility, why it is a separate service, technology, owned data, API, produced and consumed events, and milestone of introduction. The "why separate" line is what the developer must be able to defend in an interview.


## core-service (Java 21, Spring Boot 3, Spring Modulith)

**Responsibility.** Membership and Ledger. The book of record for households, members, categories, expenses, drafts, recurring rules and documents' lifecycle state.

**Why separate.** It is the transactional heart with strict consistency requirements and the largest surface for the client. Everything else can fail without losing money records.

**Why one service for two contexts.** Membership and Ledger change together (every ledger operation authorises against membership) and both need strict consistency. They are separate Spring Modulith modules with a verified boundary so that Membership can be extracted later if a second product needs it. [SRP at module level, YAGNI at service level]

**Modules.** `membership`, `ledger`, `documents` (lifecycle state only), `shared` (Money, ids, Problem Details mapping, outbox).

**Owned data.** `households`, `members`, `invitations`, `categories`, `expenses`, `expense_items`, `tags`, `expense_tags`, `recurring_rules`, `recurring_occurrences`, `documents`, `outbox`, `idempotency_keys` (Redis), `processed_events`.

**API.** `contracts/openapi/core-service.yaml`. See `docs/05-api-contracts.md`.

**Produces.** `ExpenseCreated`, `ExpenseUpdated`, `ExpenseConfirmed`, `ExpenseVoided`, `ExpenseDraftCreated`, `CategoryChanged`, `RecurringRuleChanged`, `DocumentQueued`, `HouseholdCreated`, `MemberJoined`, `HouseholdDeletionRequested`.

**Consumes.** `DocumentExtracted`, `DocumentExtractionFailed`, `MediaUploaded` (to validate `mediaId` ownership before queuing a document).

**Scheduled jobs.** Recurring occurrence generation (daily, per household time zone), invitation expiry, idempotency cleanup.

**Introduced.** M0 (skeleton), M1 (full Membership and Ledger).


## media-service (Go)

**Responsibility.** Presigned uploads, object verification, thumbnails, integrity hashes, retention and deletion of images and PDFs.

**Why separate.** Different load profile (large binary uploads, CPU-bound image processing), different language strengths (Go's image and concurrency libraries), and the bucket must be owned by exactly one service so that retention and GDPR deletion have one owner. It also keeps binary handling out of the JVM service's memory profile.

**Owned data.** `media_objects` (id, household_id, uploader_user_id, s3_key, mime, size_bytes, sha256, status, thumbnail_key, created_at, expires_at), `outbox`, `processed_events`.

**API.** `POST /api/v1/media/uploads`, `POST /api/v1/media/uploads/{id}/complete`, `GET /api/v1/media/{id}/url` (presigned GET, short TTL), `DELETE /api/v1/media/{id}`. Internal: `GET /internal/media/{id}/url` with service token.

**Produces.** `MediaUploaded`, `MediaDeleted`.

**Consumes.** `HouseholdDeletionRequested` (delete all objects), `ExpenseConfirmed` (extend retention of linked media), retention policy timer.

**Introduced.** M1.


## documents-worker (Go)

**Responsibility.** Turn a queued document into structured extraction data using a vision-capable LLM, validate it, and publish the result.

**Why separate.** Long-running, externally dependent, retryable work with its own failure modes and cost controls (rate limits per household, provider fallbacks). It must scale independently of the API and must be able to be paused without affecting expense entry. It has no REST API, which alone makes it a different kind of process.

**Technology.** Go, `franz-go`, provider adapters behind an `Extractor` interface (Anthropic, OpenAI; a local model adapter is allowed later). [OCP: new provider is a new adapter] Prompts are versioned files in the repo; each extraction records `promptVersion` and `model`.

**Owned data.** `extractions` (document_id, media_id, household_id, provider, model, prompt_version, raw_response_json, normalized_json, confidence, tokens_in, tokens_out, cost_minor, status, error, created_at), `processed_events`.

**Produces.** `DocumentExtracted`, `DocumentExtractionFailed`.

**Consumes.** `DocumentQueued`.

**Cost control.** Per-household daily extraction cap (configurable, default 50), token accounting per extraction, exponential backoff on provider errors, dead-letter after N attempts with a `DocumentExtractionFailed` event so the user sees the failure.

**Introduced.** M2.


## forecasting-service (Java)

**Responsibility.** Maintain per-household spending facts as a projection, compute committed spending from recurring rules, predict variable spending per category, expose forecasts.

**Why separate.** Read-heavy analytical workload on a projection that is deliberately denormalised, with recomputation that would harm the transactional service's latency. Its data model (facts by day and category) differs from the ledger's. It can be rebuilt from the event log if it is lost.

**Owned data.** `expense_facts`, `recurring_facts`, `forecasts`, `forecast_versions`, `processed_events`.

**API.** `GET /api/v1/households/{id}/forecast?horizonDays=30|60|90`, `GET .../forecast/committed`, `POST .../forecast/recompute` (admin).

**Produces.** `ForecastRecomputed`.

**Consumes.** `ExpenseConfirmed`, `ExpenseUpdated`, `ExpenseVoided`, `RecurringRuleChanged`, `CategoryChanged`.

**Methods.** M3 step 1: committed = sum of recurring occurrences in horizon. Step 2: variable = per-category moving average with seasonal adjustment (weekday and month-of-year factors) and a simple confidence band from historical variance. Step 3 (optional, own ADR): a Python service with a proper time-series model if step 2 proves insufficient.

**Introduced.** M3.


## insights-service (Java, LangChain4j)

**Responsibility.** Generate insights and recommendations from the household's spending facts and forecasts; answer natural-language questions about the household's own history (RAG over its ledger).

**Why separate.** It depends on external LLM providers, has bursty and expensive workloads, needs pgvector, and its failures must not affect recording or forecasting. It reuses the developer's LangChain4j work from a previous project.

**Owned data.** `insight_facts` (projection), `insights`, `embeddings` (pgvector), `processed_events`, `llm_calls` (audit and cost).

**API.** `GET /api/v1/households/{id}/insights?month=`, `POST .../insights/{id}/dismiss`, `POST .../ask` (SSE streamed answer).

**Produces.** `InsightGenerated`.

**Consumes.** `ExpenseConfirmed`, `ExpenseUpdated`, `ExpenseVoided`, `ForecastRecomputed`, `RecommendationGenerated` (from market-ingest).

**Privacy.** Sends only aggregated numbers and anonymised category and merchant names to the LLM; never member names or free-text notes without explicit per-household opt-in. See `docs/08-security-privacy.md`.

**Introduced.** M4.


## market-ingest (Go)

**Responsibility.** Collect offers and prices from Danish retail sources, normalise products, match them to a household's line items and recurring purchases, and publish recommendations.

**Why separate.** Scheduled, high-volume, source-specific ingestion with unreliable upstreams. Scrapers and API clients change often and must not be deployed together with money-handling code. Go is a good fit for concurrent fetching and parsing.

**Sources (each behind a `Source` interface; each is its own adapter and its own ADR when added). [OCP]**
- Salling Group public API (Netto, Føtex, Bilka): stores, anti-food-waste items. Verify current terms before use.
- Tjek (formerly eTilbudsavis) leaflet data: verify API availability and terms; fallback is not implemented if terms forbid it.
- Rema 1000, Lidl, Coop: no public API known at the time of writing; candidates for leaflet parsing only if terms allow. Do not scrape sites whose terms prohibit it; record the decision per source.
- Clothing and shoes: partner feeds only (Zalando, Boozt affiliate feeds) if accessible; otherwise out of scope.

**Owned data.** `sources`, `products`, `product_aliases`, `offers`, `store_chains`, `recommendations`, `household_purchase_profiles` (projection from line items), `processed_events`.

**API.** `GET /api/v1/households/{id}/recommendations`, `POST .../recommendations/{id}/dismiss`, `GET /api/v1/market/offers?query=` (search).

**Produces.** `RecommendationGenerated`, `OffersRefreshed`.

**Consumes.** `ExpenseConfirmed` (with line items), `RecurringRuleChanged`.

**Introduced.** M5.


## notifications-service (Go)

**Responsibility.** Deliver push notifications and, later, email. Device token registry.

**Why separate.** Platform-specific delivery (APNs now, FCM in M8) with its own credentials and retry semantics; every other service just emits events. [OCP: `Sender` interface with `apnsSender` and `fcmSender`]

**Owned data.** `device_tokens`, `notification_log`, `processed_events`.

**API.** `POST /api/v1/devices` (register token), `DELETE /api/v1/devices/{id}`.

**Consumes.** `ExpenseDraftCreated`, `DocumentExtractionFailed`, `InsightGenerated`, `RecommendationGenerated`, `RecurringOccurrenceDue`.

**Introduced.** M7.


## Not a service: Keycloak

Identity is delegated entirely. Custom code touches Keycloak only through: the OIDC discovery document (token validation), the admin API (create realm and clients in infra scripts), and identity brokering configuration (Apple, Google). Users' profile fields in hushold are limited to `displayName` and `avatarMediaId`, stored in core-service `members`, populated from the token on first login. [KISS: no user table beyond what the product needs]
