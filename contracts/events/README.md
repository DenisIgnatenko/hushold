# Event contracts

One JSON Schema per event version: `<context>/<Aggregate><Action>.v<N>.schema.json`, plus `examples/<same name>.json`. The `_envelope.schema.json` describes the CloudEvents attributes shared by all events. CI validates every example against its schema and against the envelope. See `docs/06-events.md`.
