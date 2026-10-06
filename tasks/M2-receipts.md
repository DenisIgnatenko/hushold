# M2: Receipts and invoices to draft expenses

Goal: a photo of a receipt or a PDF invoice becomes a draft expense with items in under a minute, the user confirms it in the app, and failures are visible and retryable.

Read first: `docs/02-architecture.md` (asynchronous path), `docs/03-services.md` (documents-worker), `docs/06-events.md` (extraction payload), ADR-008, ADR-010.

## Tasks

### 2.1 documents-worker (Go)
- Consumer of `hushold.documents.document.v1` filtered on `document.queued`; idempotent via `processed_events`.
- `Extractor` interface: `Extract(ctx, input) (Extraction, error)`. Two families of adapters: text extractors (`anthropicTextExtractor`, `openaiTextExtractor`) that take the OCR text supplied by the app, and vision extractors (`anthropicVisionExtractor`, `openaiVisionExtractor`) that take the image. An `extractionStrategy` runs the text path first and falls back to vision on low confidence, unresolved total or validation failure (ADR-010). Provider order is configuration. [OCP, DIP, Strategy]
- The `DocumentQueued` event carries `ocrText` and `ocrLines` (with bounding boxes) when the app produced them; absence of OCR text routes straight to the vision path (PDF invoices, Android before M8, failures of on-device OCR).
- Metrics: extractions, cost and latency labelled by path (`text`, `vision`) and provider.
- Prompt files `prompts/receipt-text-v1.md`, `prompts/receipt-vision-v1.md`, `prompts/invoice-vision-v1.md` with a strict JSON output instruction; response validated against `contracts/events/documents/Extraction.schema.json`; on validation failure one repair attempt with the validation errors appended, then fail.
- Normalisation: Danish number formats, `pant` detection, chain name guessing from a small dictionary (`Netto`, `Føtex`, `Bilka`, `Rema 1000`, `Lidl`, `Coop`, `SuperBrugsen`, `Kvickly`, `365discount`, `Irma`), date parsing with `Europe/Copenhagen`.
- Media access: `GET /internal/media/{id}/url` on media-service with service token; download with size cap; PDF pages rasterised (first three pages) before sending to a vision model.
- Quota: per-household daily cap, config default 50; exceeding emits `DocumentExtractionFailed` with `reason=QUOTA_EXCEEDED`, `retryable=false`.
- Cost accounting from provider token counts; Prometheus counters for tokens and cost per provider.
- Retry policy: 5 attempts with jittered backoff on provider 5xx and 429; DLQ afterwards with `DocumentExtractionFailed(retryable=true)`.
- Tests: golden tests with a set of anonymised receipt images and expected JSON (stored in a private fixtures bucket, not in the repo; CI uses a small synthetic set), adapter tests with recorded HTTP fixtures, consumer idempotency test.

### 2.2 core-service
- Consume `DocumentExtracted`: map `categoryHint.path` to the household's tree (best match by name, fallback `Other`), create the `DRAFT` expense with items and `source`, link `documentId`, set document `EXTRACTED`, emit `ExpenseDraftCreated`.
- Consume `DocumentExtractionFailed`: set document `FAILED` with reason; `POST /documents/{id}/retry` re-emits `DocumentQueued` when `retryable`.
- Drafts inbox endpoint returns extraction confidence per field so the app can highlight low-confidence values.
- Confirming a draft may edit fields first (`PATCH` then `confirm`); the document link is preserved.

### 2.3 media-service
- `GET /internal/media/{id}/url` for service tokens; extend retention when `ExpenseConfirmed` links the media (`retention_until = confirmed_at + household receipt_retention_days`).

### 2.4 iOS app
- Scan flow: camera with document edge detection (VisionKit `VNDocumentCameraViewController`), on-device OCR with `VNRecognizeTextRequest` (accurate mode, languages `da` and `en`) producing text lines with bounding boxes, multi-page PDF import from Files, upload of the image, queue document with the OCR payload, show "processing" state with polling every 5 seconds (push arrives in M7). OCR is a device capability, not business logic; the server never trusts it as final.
- Drafts inbox: list with thumbnail, merchant, total, confidence badges; detail with editable fields, low-confidence fields highlighted, items list, confirm and reject actions.

### 2.5 Observability
- Trace continuity: `traceparent` from `DocumentQueued` continues in the worker span and in the provider HTTP call span.
- Dashboard panel: extraction success rate, latency p95, cost per day and per receipt by path, share of receipts resolved by the text path, DLQ depth.

## Definition of Done
- [ ] Ten real receipts from at least three different chains produce correct totals and dates; at least eight have all items correct.
- [ ] A PDF invoice (for example an electricity bill) produces a draft with the correct total and a `Housing > Utilities` category hint.
- [ ] Provider outage (simulated) results in retries, then a visible failure in the app, then successful manual retry.
- [ ] Quota exceeded results in an immediate, clear failure and no provider call.
- [ ] Trace from tap in app to provider call is a single trace in Tempo.
- [ ] At least 70 percent of receipts are resolved by the text path without vision fallback (measured over two weeks).
- [ ] `docs/writeups/m2-extraction-pipeline.md` written, including measured cost per receipt by path and the actual provider bill for the period.
- [ ] Household has used receipt scanning for two weeks.
- [ ] Tag `m2-done`.
