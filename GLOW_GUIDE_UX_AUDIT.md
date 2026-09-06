# GlowGuide UX & AI Response Audit

**Status:** Findings only — no product code or test changes made.

## Current user flow

1. User opens GlowGuide and selects a category.
2. The app sends the category to the AI in the background.
3. AI asks a tailored follow-up question, with optional quick-select choices.
4. User can choose an option, type an answer, or attach a photo.
5. AI returns a verdict, confidence note, detailed explanation, and, when available, research sources.
6. Chats are saved and can be reopened or renamed from history.

## What is already working well

- Category-led entry makes an otherwise broad assistant easy to start.
- Free text, quick choices, and image upload are all available in the same flow.
- The response presentation supports a concise result, an evidence/confidence note, and deeper detail.
- The AI prompt has strong instructions for language matching, uncertainty, photos, and medically sensitive queries.

## Changes to consider — do not implement without a focused pass

### P0 — protect trust and billing clarity

1. **Show credit cost before a charge.** A text turn costs 2 credits; a photo costs 8 credits; live web research can add 10 credits. The current research notice appears after the turn, so a user may learn of it only after the cost has been taken.
2. **Make the first response language-safe.** The category selection currently sends an internal English sentence (for example, `Category: Skin Care selected.`) while language is set to auto-detect. That can make the AI's first response English even when the user expects Hindi/Hinglish.
3. **Resolve the professional-role wording.** The AI is described as a board-certified dermatologist but also instructed to say it is not a doctor. Choose one safe, consistent identity such as “science-based skin and product-fit guide.”

### P1 — improve the completed-answer experience

4. **Define a natural completion state.** A conversation is only marked complete after 100 exchanges. A user should instead see a clear, non-blocking next action after a verdict: “Check another product,” “Ask a follow-up,” or “Start new consultation.”
5. **Avoid duplicate verdict content.** The interface shows a structured verdict badge and the model is also instructed to begin its reply with a consultation card. Keep the UI badge as the summary and make the model reply explanatory, or render the model card as the sole summary.
6. **Collapse detailed breakdown initially.** It is expanded by default, which makes a concise answer feel long on a phone. Start collapsed with a clear “See detailed breakdown” action.

### P2 — small flow consistency fixes

7. **Connect “Upgrade Now” to the real subscription journey.** It currently closes the premium modal rather than taking the user to upgrading.
8. **Refresh outdated UI tests.** Existing tests still expect the removed language-selection screen. Update them only together with the intentional final flow, not as a standalone test-only edit.
9. **Make model choice simpler.** Model selection is useful for advanced users, but it can distract from a beauty-care consultation. Consider keeping “Fast” / “Detailed” language in the main UI and placing model names under an advanced setting.

## Safe implementation order

1. Confirm final language and credit-consent behavior with product owner.
2. Implement one P0 item at a time.
3. Run the full affected Flutter and backend test suites after each item.
4. Manually test text-only, photo-only, Hindi/Hinglish, low-credit, research, premium, and restored-chat journeys.
5. Only then refine P1 presentation items.

