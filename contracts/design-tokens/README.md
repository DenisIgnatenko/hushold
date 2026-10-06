# Design tokens

`tokens.json` is the single source for colours, spacing and typography of both native apps. Never hardcode a colour or spacing value in Swift or Kotlin.

- Swift: `scripts/gen-tokens-swift.sh` generates `apps/ios/Hushold/DesignSystem/DesignTokens.swift` (M0).
- Kotlin: generator added in M8.
