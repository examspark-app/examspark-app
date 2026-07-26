# Home / Ask AI — Thinking animation (Jul 26, 2026)

## What you see

While Home AI or Ask AI waits for the answer:

- Soft **brain** icon with a **fill ring**
- Thin **fill-up** bar
- Rotating lines: Understanding → Reasoning → Preparing answer
- Label: **Sonaxia AI**

Same look on Home chat + Study Workspace Ask AI (+ legacy Notes Ask).

## How to test

1. Flutter hot **restart** (`R`) — no FastAPI restart needed for this UI-only change.
2. Home → ask any short question → watch the new bubble (not old 3 dots).
3. Study Workspace → Ask AI → same bubble.

## Manual setup

- **No SQL**
- **No .env**
- Hot restart Flutter only

## Rollback

Revert `examspark_frontend/lib/presentation/widgets/ai/ai_thinking_bubble.dart`
