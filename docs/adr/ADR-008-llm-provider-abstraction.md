# ADR-008: LLM providers behind ports; prompts versioned; forecasting starts statistical

- Status: Accepted
- Date: 2026-09-29
- Milestone: M2

## Context
Vision extraction and insight generation depend on external LLM APIs whose models, prices and terms change. Forecasting could use an LLM, a Python time-series model, or simple statistics.

## Decision
- documents-worker and insights-service depend on provider-neutral ports (`Extractor`, `InsightGenerator`); adapters exist for Anthropic and OpenAI. Prompts are versioned files; every call records model and prompt version. [OCP, DIP]
- Providers are configured with no-training and minimal-retention options where offered.
- Forecasting uses deterministic statistics in Java first. An LLM is used to explain forecasts, not to compute them. A Python model service is a separate future ADR if statistics prove insufficient.

## Consequences
- Provider switch is configuration plus an adapter, not a rewrite.
- Extraction quality can be measured against a labelled set of the household's own receipts (kept out of the repo).
