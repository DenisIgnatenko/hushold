# 01. Domain model

This document defines the ubiquitous language and the bounded contexts. Code uses these terms exactly. If a concept is not here, it does not exist in the system yet; add it here first.

## Bounded contexts

| Context | Responsibility | Owning service |
|---|---|---|
| Identity | Who the user is. Authentication, tokens, external identity providers. | Keycloak (not custom code) |
| Membership | Households, members, roles, invitations. | core-service (`membership` module) |
| Ledger | Expenses, categories, tags, recurring rules, drafts and confirmation. The book of record. | core-service (`ledger` module) |
| Media | Upload, storage, integrity and lifecycle of images and PDFs. | media-service |
| Documents | Turning a media object into structured expense data using AI. | documents-worker |
| Forecasting | Committed future spending and predicted variable spending. | forecasting-service |
| Insights | Analysis, anomalies, recommendations, natural-language explanations. | insights-service |
| Market | Danish store offers and prices; matching them to household purchases. | market-ingest |
| Notifications | Delivering messages to devices. | notifications-service |

Contexts communicate through events on Kafka and, for synchronous reads, through REST calls to the owning service. No context reads another context's database.

## Ubiquitous language

**Household.** The tenant. A group of people who share spending. Has a name, a base currency (always DKK for now), a time zone (`Europe/Copenhagen` default), settings. Every piece of financial data belongs to exactly one household.

**Member.** A user's participation in a household, with a role. A user can be a member of several households (for example their own family and an elderly parent's household they help manage).

**Role.** `OWNER` (full control, can delete the household), `ADULT` (adds and edits any expense, manages categories), `LIMITED` (adds and edits only their own expenses, reads household totals). Roles are a closed set; no custom permissions.

**Invitation.** A time-limited, single-use token that lets a user join a household with a given role. Created by an `OWNER` or `ADULT`.

**Expense.** A single outflow of money on a specific date, belonging to a household, recorded by a member. Has an amount (Money), a date (`occurredOn`, a calendar date in the household's time zone), a category, an optional merchant, an optional note, tags, a source, a status, and optional line items. An expense is the aggregate root of the Ledger.

**Money.** A value object: `amountMinor` (long, in øre), `currency` (ISO 4217, `DKK`). Never negative on an expense; refunds are a separate concept (see below). Arithmetic is exact integer arithmetic.

**Category.** A node in a per-household tree, up to three levels deep (`Housing > Utilities > Electricity`). Each household starts from the system default tree (see appendix) and may rename, add or archive nodes. Categories are never hard-deleted once used; they are archived, so history stays valid. Categories carry a `kind`: `FIXED` (rent, insurance), `VARIABLE` (groceries, transport), `DISCRETIONARY` (dining, entertainment). The kind drives forecasting.

**Tag.** A free-text label on an expense (`vacation-2026`, `kids`). Household-scoped, flat.

**Source.** Where the expense came from: `MANUAL`, `RECEIPT` (photo), `INVOICE` (PDF), `BANK` (imported transaction, M6), `RECURRING` (generated from a rule).

**Status.** `DRAFT` (proposed by AI or import, not yet confirmed by a member), `CONFIRMED` (in the book), `VOID` (cancelled; kept for audit, excluded from totals).

**Line item.** A row inside an expense: description, quantity, unit price, line total, optional product category hint. Present when the source is a receipt with readable items. Line items are used by Market for matching and by Insights for detail; totals are always taken from the expense, not summed from items, because receipts contain discounts and rounding.

**Refund.** A negative movement against a previous expense. Modelled as a separate `Refund` entity referencing the original expense, not as a negative expense. Out of scope until M4, listed here so that the model does not paint itself into a corner.

**Recurring rule.** A definition of an expected repeating expense: template (amount, category, merchant, note), schedule (RRULE subset: monthly on day N, weekly on weekday, yearly on date, every N months), start date, optional end date, `autoConfirm` flag. The rule generates expense drafts (or confirmed expenses when `autoConfirm`) ahead of time. The rule is the source of truth for committed spending in the forecast.

**Document.** A media object that the household wants turned into an expense. Has an extraction state: `QUEUED`, `EXTRACTING`, `EXTRACTED`, `FAILED`, `REJECTED`. On success it results in exactly one expense draft.

**Extraction.** The structured result of AI reading a document: merchant, date, total, VAT if visible, line items, confidence per field, model and prompt version used. Stored for audit and for improving prompts; never shown to another household.

**Forecast.** For a household and a horizon (next 30, 60, 90 days): committed amount (from recurring rules), predicted variable amount per category with a confidence band, and total. Recomputed on ledger changes, cached, versioned.

**Insight.** A generated statement about the household's spending with supporting numbers, a category, a severity, and optional actions. Examples: "Groceries in September are 18 percent above your six-month average", "Three streaming subscriptions overlap in content; cancelling one saves 89 DKK per month".

**Offer.** A Market fact: product, store chain, price, valid-from, valid-to, unit, source and fetch time. Offers are ephemeral and refreshed; they are never joined into the Ledger.

**Recommendation.** A Market suggestion linked to a household's spending pattern: "You buy oat milk weekly at Netto for 14.95; Rema 1000 lists it at 10.00 this week". Has a validity window and can be dismissed.

## Invariants (enforced in domain code and covered by tests)

- An expense always belongs to a household and was created by a member of that household at creation time.
- `Money.amountMinor` on an expense is greater than zero. Zero-amount expenses are rejected.
- An expense's category belongs to the same household as the expense (or is a system default).
- A `DRAFT` can be confirmed or voided; a `CONFIRMED` expense can be edited or voided; a `VOID` expense is immutable.
- Confirming a draft that originated from a document links the document permanently; the document cannot produce a second expense.
- Archived categories cannot be assigned to new expenses but remain on old ones.
- A recurring rule never generates the same occurrence twice (idempotency key: rule id plus occurrence date).
- Household totals are computed only over `CONFIRMED` expenses.

## Appendix A. Default category tree (Danish household)

```
Housing (FIXED)
  Rent or mortgage
  Utilities
    Electricity
    Heating
    Water
  Insurance
  Maintenance
Groceries (VARIABLE)
  Supermarket
  Bakery
  Specialty
Transport (VARIABLE)
  Public transport (Rejsekort)
  Car
    Fuel
    Parking
    Repairs
  Bicycle
Children (FIXED)
  Daycare and school
  Activities and clubs
  Clothes and gear
Health (VARIABLE)
  Pharmacy
  Dentist
  Doctor and therapy
Subscriptions (FIXED)
  Streaming
  Phone and internet
  Software
  Gym and sports
Dining out (DISCRETIONARY)
Clothing and shoes (DISCRETIONARY)
Home and furniture (DISCRETIONARY)
Leisure and travel (DISCRETIONARY)
Gifts and charity (DISCRETIONARY)
Other (VARIABLE)
```

## Appendix B. Glossary of Danish market terms used in code

- `tilbud`: offer. Used in Market as `Offer`.
- `tilbudsavis`: weekly offer leaflet. Source type `LEAFLET`.
- `pant`: bottle deposit. Line items with `pant` are flagged `isDeposit` and excluded from product matching.
- `moms`: VAT (25 percent). Stored on extraction when visible; never used in totals.
