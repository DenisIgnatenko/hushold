# M5: Danish market data and savings recommendations

Goal: at least one real Danish retail data source is ingested legally, products are matched to what the household buys, and recommendations with a concrete saving appear in the app.

## Tasks
- Source review before code: for each candidate (Salling Group API, Tjek, chain websites, clothing affiliate feeds) record in an ADR: terms of service, rate limits, data available, decision. Sources whose terms forbid automated access are not used.
- market-ingest (Go): `Source` interface with `Fetch(ctx) ([]RawOffer, error)`; scheduler; normalisation into `products` with `product_aliases` (brand, size, unit price per kg or litre); `offers` with validity; household purchase profile projected from `ExpenseConfirmed` line items (frequency, usual price, usual chain); matcher: token similarity plus unit normalisation, threshold configurable; recommendation generator: "same product cheaper elsewhere this week", "buy in bulk while on offer", "your usual store is not the cheapest for this basket"; `RecommendationGenerated` events. [OCP for sources; SRP: fetch, normalise, match, recommend are separate components]
- Public search endpoint over current offers.
- iOS: Recommendations screen with estimated saving, store, validity, dismiss; offer search.

## Definition of Done
- [ ] At least one source ingested daily with monitoring on freshness.
- [ ] Matching precision on the household's last 100 grocery line items measured and at or above 80 percent for matched items.
- [ ] At least three recommendations per week for the household with a computed saving; the household has acted on at least one.
- [ ] `docs/writeups/m5-market-ingestion.md` including the terms-of-service review summary.
- [ ] Tag `m5-done`.
