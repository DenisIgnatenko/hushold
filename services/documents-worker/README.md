# documents-worker (Go)

Turns a queued receipt or invoice into structured extraction data: OCR text through a text model first, vision model as fallback (ADR-010), validated against JSON Schema and published as `DocumentExtracted` or `DocumentExtractionFailed`. No REST API.

Introduced in **M2**. See `docs/03-services.md` and `tasks/M2-receipts.md`.
