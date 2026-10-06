# 05. API contracts

Authoritative files: `contracts/openapi/*.yaml`. This document lists the endpoints, their semantics and the conventions the YAML files must follow. Write the YAML first, generate, then implement.

## Conventions

- Base path `/api/v1`. Gateway routes by prefix: `/api/v1/households/**` and `/api/v1/me/**` to core-service, `/api/v1/media/**` to media-service, `/api/v1/households/{id}/forecast/**` to forecasting-service, `.../insights/**` to insights-service, `.../recommendations/**` and `/api/v1/market/**` to market-ingest, `/api/v1/devices/**` to notifications-service.
- Authentication: `Authorization: Bearer <JWT>` on every call. `401` for invalid token, `403` for not a member or insufficient role, `404` when the resource is not visible to the caller (never leak existence across households).
- Errors: RFC 9457 `application/problem+json` with `type` URIs under `https://hushold.app/problems/<code>`. Validation errors include an `errors` array of `{field, message}`.
- Money in JSON: `{ "amountMinor": 23450, "currency": "DKK" }`. Never a decimal number.
- Dates: `occurredOn` as `YYYY-MM-DD`; timestamps as RFC 3339 UTC.
- Pagination: cursor-based, `?cursor=&limit=` with `nextCursor` in the response. Never offset pagination on expenses.
- Idempotency: `Idempotency-Key` header (UUID) required on all POST that create resources; replay returns the original response with `Idempotent-Replayed: true`.
- Versioning: additive changes only within v1. Deprecations marked in the YAML with `deprecated: true` and a sunset header.

## core-service

### Me
- `GET /me` : current user's memberships (household id, name, role).
- `PATCH /me` : displayName, avatarMediaId.
- `POST /me/export` : request a full GDPR export (async; result link delivered via notification or email).
- `DELETE /me` : request account deletion (async, all households where the user is the sole OWNER are deleted; otherwise membership is removed).

### Households
- `POST /households` : create. Caller becomes OWNER; default category tree is copied.
- `GET /households/{id}`
- `PATCH /households/{id}` : name, timeZone, settings. OWNER only.
- `DELETE /households/{id}` : OWNER only; starts the deletion flow.
- `GET /households/{id}/members`
- `PATCH /households/{id}/members/{memberId}` : role. OWNER only; cannot demote the last OWNER.
- `DELETE /households/{id}/members/{memberId}` : remove or leave.
- `POST /households/{id}/invitations` : role, expiresInHours. Returns a one-time link.
- `POST /invitations/{token}/accept`

### Categories
- `GET /households/{id}/categories` : full tree, including archived when `?includeArchived=true`.
- `POST /households/{id}/categories` : name, parentId, kind, icon.
- `PATCH /households/{id}/categories/{categoryId}`
- `POST /households/{id}/categories/{categoryId}/archive`
- `POST /households/{id}/categories/{categoryId}/move` : new parent; depth validated.

### Expenses
- `GET /households/{id}/expenses?from=&to=&categoryId=&memberId=&status=&source=&tag=&cursor=&limit=`
- `POST /households/{id}/expenses` : amount, occurredOn, categoryId, merchant, note, tags, items. Creates `CONFIRMED` by default; `?asDraft=true` creates a draft.
- `GET /households/{id}/expenses/{expenseId}`
- `PATCH /households/{id}/expenses/{expenseId}` : any editable field; `If-Match` with the version required.
- `POST /households/{id}/expenses/{expenseId}/confirm`
- `POST /households/{id}/expenses/{expenseId}/void` : reason.
- `GET /households/{id}/expenses/drafts` : pending drafts, newest first.

### Recurring rules
- `GET /households/{id}/recurring-rules`
- `POST /households/{id}/recurring-rules`
- `PATCH /households/{id}/recurring-rules/{ruleId}`
- `POST /households/{id}/recurring-rules/{ruleId}/archive`
- `GET /households/{id}/recurring-rules/{ruleId}/occurrences?from=&to=` : generated and upcoming.

### Documents
- `POST /households/{id}/documents` : mediaId, kind, optional `ocr` object (`text`, `lines[{text, box}]`, `engine`, `languages`) produced on the device. Returns document in `QUEUED`.
- `GET /households/{id}/documents?state=`
- `GET /households/{id}/documents/{documentId}`
- `POST /households/{id}/documents/{documentId}/retry` : after FAILED.

### Read models (screen-shaped)
- `GET /households/{id}/summary?month=YYYY-MM` : total confirmed, per category tree with amounts and percentage of month, per member, drafts count, comparison with previous month, top merchants. One call for the month screen.
- `GET /households/{id}/day?date=YYYY-MM-DD` : all expenses of a day with member and category, for the "today" entry screen.

## media-service
- `POST /media/uploads` : householdId, mime, sizeBytes, kind. Returns `{mediaId, uploadUrl, headers, expiresAt}`. Limits: 15 MB images, 25 MB PDF; mime whitelist `image/jpeg`, `image/heic`, `image/png`, `application/pdf`.
- `POST /media/uploads/{mediaId}/complete`
- `GET /media/{mediaId}/url?variant=original|thumbnail` : presigned GET, 5 minute TTL.
- `DELETE /media/{mediaId}` : only if not linked to a confirmed expense.

## forecasting-service
- `GET /households/{id}/forecast?horizonDays=30` : `{committed, predicted, lower, upper, total, breakdown:[{categoryId, committed, predicted, lower, upper}], computedAt, methodVersion, stale}`.
- `GET /households/{id}/forecast/committed?from=&to=` : list of upcoming occurrences with rule reference.

## insights-service
- `GET /households/{id}/insights?month=` : list of `{id, kind, severity, title, body, numbers, actions, dismissed}`.
- `POST /households/{id}/insights/{insightId}/dismiss`
- `POST /households/{id}/ask` : `{question}`; response `text/event-stream` of tokens, then a final event with cited expense ids.

## market-ingest
- `GET /households/{id}/recommendations?status=active`
- `POST /households/{id}/recommendations/{recId}/dismiss`
- `GET /market/offers?query=&chain=&limit=` : public product search over current offers.

## notifications-service
- `POST /devices` : platform (`IOS`, `ANDROID`), token, appVersion.
- `DELETE /devices/{deviceId}`
