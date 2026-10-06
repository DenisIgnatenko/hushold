# ADR-005: Keycloak as the identity provider

- Status: Accepted
- Date: 2026-09-29
- Milestone: M0

## Context
AWS Cognito is cheaper to operate on AWS. Keycloak is portable, runs locally in Compose, supports identity brokering for Apple and Google, fine-grained client configuration, and is common in Danish enterprises.

## Decision
Keycloak. Realm configuration is versioned as JSON and applied by infrastructure code. The application never stores passwords.

## Consequences
- One more stateful component to operate in M7.
- Identical identity setup locally and in production, which simplifies testing.
