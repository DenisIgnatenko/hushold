# 06. Events

## Transport

Kafka (KRaft mode locally via Redpanda or Apache Kafka image; Strimzi on EKS). One topic per aggregate and major version: `hushold.<context>.<aggregate>.v1`. Partition key: `householdId`. Retention: 30 days for state-change topics, 7 days for notification-style topics. Dead letter: `<topic>.dlq`.

## Envelope (CloudEvents 1.0, JSON structured mode)

```json
{
  "specversion": "1.0",
  "id": "018f2d6e-1234-7abc-8def-0123456789ab",
  "source": "/services/core-service",
  "type": "com.hushold.ledger.expense.confirmed.v1",
  "subject": "018f2d6e-...expenseId",
  "time": "2026-09-29T12:34:56.789Z",
  "datacontenttype": "application/json",
  "householdid": "018f2d6e-...householdId",
  "traceparent": "00-<trace>-<span>-01",
  "data": { ... }
}
```

`householdid` and `traceparent` are extension attributes, also duplicated into Kafka headers for filtering and tracing without deserialising.

## Catalogue

| Type | Topic | Producer | Data (summary) |
|---|---|---|---|
| ledger.expense.created.v1 | hushold.ledger.expense.v1 | core | full expense snapshot, status |
| ledger.expense.updated.v1 | same | core | snapshot, changedFields |
| ledger.expense.confirmed.v1 | same | core | snapshot including items |
| ledger.expense.voided.v1 | same | core | expenseId, reason |
| ledger.expense.draft-created.v1 | same | core | snapshot, originatingDocumentId |
| ledger.category.changed.v1 | hushold.ledger.category.v1 | core | category snapshot, action |
| ledger.recurring-rule.changed.v1 | hushold.ledger.recurring-rule.v1 | core | rule snapshot, action |
| ledger.recurring-occurrence.due.v1 | hushold.ledger.recurring-occurrence.v1 | core | ruleId, occurrenceOn, expenseId |
| membership.household.created.v1 | hushold.membership.household.v1 | core | householdId, ownerUserId |
| membership.household.deletion-requested.v1 | same | core | householdId, requestedAt |
| membership.member.joined.v1 | hushold.membership.member.v1 | core | householdId, userId, role |
| documents.document.queued.v1 | hushold.documents.document.v1 | core | documentId, mediaId, kind, ocrText (optional), ocrLines (optional) |
| documents.document.extracted.v1 | same | documents-worker | documentId, extraction (normalized) |
| documents.document.extraction-failed.v1 | same | documents-worker | documentId, reason, retryable |
| media.object.uploaded.v1 | hushold.media.object.v1 | media | mediaId, householdId, mime, sha256 |
| media.object.deleted.v1 | same | media | mediaId |
| forecasting.forecast.recomputed.v1 | hushold.forecasting.forecast.v1 | forecasting | householdId, horizonDays, totals |
| insights.insight.generated.v1 | hushold.insights.insight.v1 | insights | insightId, kind, severity, title |
| market.recommendation.generated.v1 | hushold.market.recommendation.v1 | market | recId, householdId, savingMinor |
| market.offers.refreshed.v1 | hushold.market.offers.v1 | market | source, count |

Each row corresponds to a schema file `contracts/events/<context>/<Aggregate><Action>.v1.schema.json`.

## Producer rules
- Write to `outbox` in the same transaction as the aggregate. The relay publishes in order per aggregate and marks `published_at`. See ADR-003 for the relay choice.
- The snapshot in `data` is complete enough for consumers to build projections without calling back. Consumers never call the producer to "get the rest".
- Amounts inside events use the same `{amountMinor, currency}` shape as the API.

## Consumer rules
- Check `processed_events` for the event id before acting; insert it in the same transaction as the side effect.
- Order is guaranteed per household within a topic; across topics it is not. Consumers must tolerate `expense.confirmed` arriving before `document.extracted` for the same document.
- On non-retryable failure, publish to `.dlq` with the error in headers and continue. Retryable failures use consumer-side backoff with a cap of 5 attempts.
- Consumers validate incoming `data` against the schema and treat unknown fields as ignorable (forward compatibility).

## Extraction payload (documents.document.extracted.v1, data.extraction)

```json
{
  "merchant": {"name": "Netto", "chainGuess": "NETTO", "confidence": 0.93},
  "occurredOn": {"value": "2026-09-27", "confidence": 0.98},
  "total": {"amountMinor": 23450, "currency": "DKK", "confidence": 0.99},
  "vat": {"amountMinor": 4690, "confidence": 0.7},
  "categoryHint": {"path": ["Groceries", "Supermarket"], "confidence": 0.9},
  "items": [
    {"lineNo": 1, "description": "Havredrik 1L", "quantity": 2, "unitPriceMinor": 1495, "lineTotalMinor": 2990, "isDeposit": false, "confidence": 0.95},
    {"lineNo": 2, "description": "Pant", "lineTotalMinor": 150, "isDeposit": true, "confidence": 0.9}
  ],
  "warnings": ["items_total_mismatch"],
  "model": "claude-sonnet-4-6",
  "promptVersion": "receipt-v3"
}
```

`items_total_mismatch` means the sum of line totals differs from the total by more than 1 øre after discounts; the draft still uses `total`.
