# M8: Android

Goal: native Android app at parity with iOS for entry, receipts, summary, forecast, insights and recommendations.

## Tasks
- Kotlin, Jetpack Compose, minimum API 26, Hilt, Room for offline cache, WorkManager for the offline write queue, `openapi-generator` Kotlin client from the same contracts, AppAuth for OIDC, design tokens generated from `tokens.json` (add `scripts/gen-tokens-kotlin.sh`).
- Screens mirror iOS; behaviour is defined by server contracts, so no new server endpoints should be needed. If one is needed, that is a signal that logic leaked into iOS; fix the server, not the client.
- notifications-service: `fcmSender` implementation behind the existing `Sender` interface. [OCP realised]
- Keycloak client `android-app`; Google sign-in.
- CI workflow for Android; internal testing track on Play Console.

## Definition of Done
- [ ] All Definition of Done items of M1 to M5 that concern the client pass on Android.
- [ ] No server change was required, or the change is documented as a leak fix.
- [ ] Both apps in internal testing; household members on both platforms use the same household.
- [ ] Tag `m8-done`.
