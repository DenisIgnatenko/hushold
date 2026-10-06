# ADR-010: On-device OCR first, vision model as fallback

- Status: Accepted
- Date: 2026-10-06
- Milestone: M2

## Context
Sending every receipt photo to a vision LLM costs about one cent per receipt on mid-tier models and is the dominant variable cost of the product (about 30 to 60 cents per active user per month, versus about 15 cents of infrastructure at 1000 users). It also sends the full image, which may contain more than the receipt, to a third party.

iOS (VisionKit, Vision framework) and Android (ML Kit) perform OCR on the device for free and offline.

## Decision
- The app runs OCR on the device and uploads both the image (for audit and fallback) and the extracted text with layout hints (line order, bounding boxes).
- documents-worker first calls a text-only model with the OCR text to produce the structured extraction. This uses a fraction of the tokens of a vision call.
- If the text path yields low overall confidence, an `items_total_mismatch` warning with no resolvable total, or a provider validation failure, the worker falls back to the vision model on the image.
- Both paths implement the same `Extractor` port; the choice is a strategy in front of them, with metrics per path. [OCP, Strategy]
- Cost per receipt, per path, is a first-class metric on the M2 dashboard.

## Consequences
- Expected LLM cost per receipt drops by five to ten times for the majority of receipts.
- Privacy improves: most images never reach a provider.
- Two prompts to maintain (text and vision) and a small amount of client-side logic that is presentation-adjacent (OCR is a capability of the device, not a business rule, so this does not violate the thin-client principle).
- Self-hosting an LLM is explicitly deferred: break-even against API pricing is roughly 30 to 70 thousand receipts per month, far beyond the planned scale. The port makes it a future adapter, not a redesign.
