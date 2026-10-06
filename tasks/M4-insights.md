# M4: Insights and ask-your-ledger

Goal: each month the household receives a handful of specific, numerically grounded insights, and can ask questions about its own spending in natural language.

## Tasks
- insights-service (Java, LangChain4j): projection `insight_facts`; rule-based detectors first (category above trailing average by X percent, new merchant with recurring pattern, overlapping subscriptions, unusual single expense) producing candidate facts; LLM turns candidate facts into concise insight text with actions, using the `InsightGenerator` port; `llm_calls` audit; dismiss endpoint. [OCP: detectors implement `InsightDetector`; adding one does not change the pipeline]
- RAG: embeddings of redacted expense summaries (`merchant, category, amount, date, items`) per household in pgvector, filtered by `household_id` in every query; `POST /ask` streams an answer via SSE with cited expense ids; questions are answered only from the household's data; refusal on questions outside scope.
- Privacy: implement redaction and the `llmNotesOptIn` gate; add tests that member names never appear in prompts.
- iOS: Insights screen (monthly list, severity, dismiss), Ask screen with streaming answer and tappable citations.

## Definition of Done
- [ ] Insights for the last two months are judged useful by both household adults (a simple thumbs rating stored locally is enough).
- [ ] "How much did we spend on groceries in August compared with July?" and "What did we buy at Rema last week?" answer correctly with citations.
- [ ] Prompt inspection test proves no member names or raw notes leave the service without opt-in.
- [ ] Cost per household per month measured and recorded.
- [ ] `docs/writeups/m4-rag-over-ledger.md`.
- [ ] Tag `m4-done`.
