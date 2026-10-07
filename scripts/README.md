# Scripts

Repository automation called from the root `Makefile` and from CI. Not listed in the layout of `CLAUDE.md`, section 3; added by ADR-014.

| Script | Purpose | Milestone |
|---|---|---|
| `k3s-create.sh` | Create the OrbStack machine `hushold-k3s` with k3s, export its kubeconfig | M0 |
| `validate-events.sh` | Validate event examples against the envelope and event schemas | M0 |
| `gen-tokens-swift.sh` | Generate Swift design tokens from `contracts/design-tokens/tokens.json` | M0 |
| `migrate-in.sh`, `migrate-out.sh` | Move household data to and from `demo-aws` | M7 |
