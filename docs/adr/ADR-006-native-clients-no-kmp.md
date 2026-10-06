# ADR-006: Native iOS and Android clients, no cross-platform layer

- Status: Accepted
- Date: 2026-09-29
- Milestone: M1

## Context
Options: React Native or Flutter (single codebase), Kotlin Multiplatform (shared networking and models, native UI), fully native twice.

## Decision
Fully native: SwiftUI, then Kotlin with Jetpack Compose. Duplication is kept cheap by thin clients, contract-first OpenAPI with generated clients on both platforms, and generated design tokens. KMP was rejected: with thin clients there is little shared logic to justify its build complexity.

## Consequences
- Every screen is built twice; the server owns all rules so the duplication is presentation only.
- Android is scheduled last (M8), after the backend is stable and iOS has shipped to TestFlight.
