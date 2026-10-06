# 00. Vision and scope

## Purpose

hushold is a household expense tracker for people living in Denmark. Several people (a family) share one household; each member records their own spending from their own phone; the household sees the whole picture, a forecast of what is coming, and concrete suggestions on how to spend less.

The project has two goals that are equally important and must be kept in balance:

1. **A tool the developer's family actually uses.** Every milestone ends with something that can be used day to day. If a milestone does not improve daily use, it is either infrastructure that unblocks the next one, or it is cut.
2. **A public, reviewable demonstration of production engineering.** The stack is deliberately richer than a family app needs (microservices, Kafka, Kubernetes, observability, AI pipeline, two native mobile clients). Every piece of that richness must have a written justification (see `docs/adr/`) so that the developer can defend each choice in a technical interview.

Longer term, the service may be opened to other households in Denmark. Multi-tenancy, GDPR compliance and abuse protection are therefore designed in from the first milestone rather than retrofitted.

## Scope: what is in

- Recording every kind of expense: rent, utilities, groceries, subscriptions, transport, children's activities, adult activities, one-off purchases. An expense is any outflow of money.
- Manual entry with category selection, optimised for entering a day's expenses in under a minute.
- Photographing receipts and uploading PDF invoices; AI extracts merchant, date, total and line items into a draft the user confirms.
- Categories: a sensible Danish default tree, editable per household.
- Households: invite members, roles, per-member and per-household views.
- Recurring expenses: fixed obligations with a schedule, producing a forward view of committed spending.
- Forecasting: committed spending from recurring rules plus a model-based estimate of variable categories (groceries first).
- Insights: monthly analysis, anomalies, comparisons, AI-generated recommendations on what to cut, defer or substitute.
- Danish market data: ingesting store offers and prices where available, and recommending when and where a planned purchase is cheaper.
- Optional bank import through a PSD2 aggregator (late milestone).
- Native iOS app, then native Android app.

## Scope: what is out (for now)

- Income tracking and net worth. The product is about outflows. (May be revisited; would be a new bounded context.)
- Multi-currency conversion. Everything is DKK. Foreign expenses are recorded in DKK as charged by the bank.
- Shared wallets, splitting bills between households, or settling debts between members.
- Investment, tax, or pension features.
- Web client. Mobile only until further notice.
- Real-time collaboration inside one screen.

## Positioning

Hushold helps families in Denmark see what is coming and spend less, starting from the receipt, not the bank statement.

Bank aggregators (Spiir and the like) are a mirror of the past at transaction level. Hushold is a navigator: it knows what is inside the receipt (line items), it treats the household rather than the account as the unit, it forecasts committed and variable spending, and it recommends concrete savings on the Danish market. The first audience is families who recently moved to Denmark and lack the local intuition for what things should cost; the interface is English and Danish and the default categories reflect Danish life (pant, Rejsekort, SFO, fagforening, a-kasse).

Bank import (M6) is a convenience, never the core. Hushold does not compete with aggregators on their ground.

## Unit economics and pricing hypothesis

Figures are estimates to be replaced with measured ones from M2 onwards.
- Cost per active user per month: LLM 30 to 60 cents on a mid-tier model with vision for every receipt; 5 to 10 cents with on-device OCR first (ADR-010). Infrastructure about 15 cents at 1000 users on a minimal EKS profile. Total well under 1 USD.
- Price hypothesis: 49 DKK per month or 349 DKK per year per household. After 25 percent Danish VAT and Apple's 15 percent small-business commission, about 33 DKK (about 4.9 USD) net per household. Break-even on a 150 USD per month cloud environment is roughly 30 paying households.
- Model: freemium. Free: manual entry, categories, household sharing, 10 receipts per month. Paid: receipts up to a soft cap of 300 per month, forecast, insights, market recommendations. The per-household quota from M2 is therefore a product feature, not only a cost guard.
- Self-hosted LLM: deferred; see ADR-010 for the break-even reasoning.

## Load targets (design assumptions, recorded for capacity decisions)

1000 users, about 400 households: about 50 thousand API requests per day with evening peaks of 10 to 20 requests per second; about 700 receipt extractions per day; about 3.6 million expense rows per year. A single node of Core Ultra 5 class with 32 GB handles this; the reasons to move to a cloud environment at that scale are availability, trust and compliance, not CPU. The first thing that scales badly is the LLM bill, which is why quotas and the OCR-first path exist.

## Non-negotiable qualities

- **Correctness of money.** Integer minor units everywhere; every aggregation is exact.
- **Household isolation.** No path exists by which one household reads another's data.
- **Privacy by design.** Data minimisation towards LLM providers; export and deletion of a household's full data on request.
- **Everything demonstrable.** Each service has health endpoints, metrics, traces and a runbook section; the whole system starts with one command locally.

## Success criteria per phase

- Phase A (M0 to M2): the developer's household enters all its expenses through the app for four consecutive weeks, including receipts through the AI pipeline.
- Phase B (M3 to M5): the household consults the forecast and at least one market recommendation each week and finds them credible.
- Phase C (M6 to M8): the system runs on AWS with monitoring, the iOS app is in TestFlight, the Android app reaches parity for core flows.

## Why the stack is deliberately complex

A family expense tracker could be a single Rails app. This one is not, for reasons that are stated once here and referenced from ADRs:

- The developer targets Java and Go backend roles at Danish employers where event-driven microservices on Kubernetes are the norm. The project must exercise that exact skill set end to end, including the painful parts (idempotency, outbox, schema evolution, distributed tracing).
- Each service boundary maps to a bounded context with a different load profile, change rhythm or technology need. The boundaries are not arbitrary; see `docs/03-services.md`.
- Complexity is introduced by milestone, not all at once. Kafka arrives when there is a second consumer. Kubernetes arrives when there is a reason to run in the cloud. This keeps the project shippable at every step.
