# M6 (optional): Bank transaction import

Goal: transactions from the household's bank arrive as drafts through a PSD2 aggregator, deduplicated against manually entered and receipt-based expenses.

## Tasks
- Aggregator selection ADR (candidates: GoCardless Bank Account Data, Tink, Enable Banking); sandbox first.
- bank-import module in core-service or a new Go service `bank-connector` (decide in the ADR based on the aggregator's callback and polling model; the default is a Go service consuming callbacks and polling, emitting `BankTransactionImported`).
- Reconciliation in core-service: match by amount, date within 2 days and merchant similarity against existing expenses; matched transactions attach to the expense as a bank reference; unmatched become drafts with `source=BANK`.
- Consent and connection management in the app; clear disconnect and data deletion.

## Definition of Done
- [ ] Sandbox account transactions appear as drafts; real account used only after a written privacy review.
- [ ] Duplicate rate under 2 percent on a month of real data.
- [ ] Tag `m6-done`.
