# M3: Recurring spending and forecast

Goal: the household sees what is committed for the next 30, 60 and 90 days and a credible estimate of variable spending with a confidence band.

## Tasks
- core-service: recurring occurrence generator (daily job per household time zone) producing drafts or auto-confirmed expenses `generate_days_ahead` in advance; emits `RecurringOccurrenceDue`; idempotent by `(rule_id, occurrence_on)`. Rule editing and archiving endpoints. Schedule DSL validated (monthly by day, weekly by weekday, yearly, every N months); occurrences preview endpoint.
- forecasting-service (Java): projections `expense_facts` and `recurring_facts` from events; rebuild command from Kafka beginning; committed calculation from rules; variable prediction per category: trailing 26-week weekly mean with weekday and month-of-year factors, band from historical standard deviation, `methodVersion=stat-v1`; recompute on `stale` with debounce (30 seconds); `GET /forecast`, `GET /forecast/committed`.
- iOS: Forecast screen with committed list (upcoming occurrences), predicted per category with bands, total for horizon; Recurring rules management.
- Tests: golden tests for the forecast method on a synthetic year of data; projection rebuild test.
- ADR if a Python model service is deemed necessary; otherwise note in the write-up why statistics suffice.

## Definition of Done
- [ ] All the household's fixed obligations are recurring rules and appear as committed spending.
- [ ] Back-testing on the household's own history: predicted groceries for the last three months falls inside the band in at least two.
- [ ] Forecast recomputes within 5 seconds of confirming an expense (measured).
- [ ] Projection rebuilt from scratch matches live state.
- [ ] `docs/writeups/m3-projections-and-forecast.md`.
- [ ] Tag `m3-done`.
