# ADR-004: Money as integer minor units in a single currency

- Status: Accepted
- Date: 2026-09-29
- Milestone: M1

## Context
Floating point cannot represent 0.10 exactly; decimal types are exact but slower and awkward across Java, Go, Swift and Kotlin. The product is DKK-only.

## Decision
`Money { long amountMinor; Currency currency }`. Database columns `*_minor BIGINT` plus `currency CHAR(3)`. JSON `{amountMinor, currency}`. Division (for example splitting) uses a documented allocation algorithm that distributes remainders deterministically. Multi-currency conversion is explicitly out of scope; foreign purchases are entered in DKK as charged.

## Consequences
- Exact sums everywhere; trivial to test.
- Displaying amounts requires client-side formatting with the household locale (`da_DK`).
- Adding a second currency later requires a conversion context and rate source; the model does not prevent it.
