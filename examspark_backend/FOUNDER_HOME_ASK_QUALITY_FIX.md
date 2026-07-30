# Home / Ask AI — language error + answer quality (Jul 26, 2026)

## What was broken (screenshot)

Error like:
`conversation_language … should be 'english'/'hindi'… (L101)`

**Cause:** After language lock, app sent values like `MATCH_QUESTION` / `ENGLISH` that the API rejected.

## Fixes

1. **API accepts** `ENGLISH` / `HINDI` / `BENGALI` / `HINGLISH` / `MATCH_QUESTION` (any case).
2. **Diagrams** — only when student asks (draw / diagram / graph…). Not on every answer.
3. **Answer length** — short ask → short Shape 1; “explain clearly / detail” → longer Shape 3.

## Founder test

1. **Restart FastAPI** (required).
2. Home → **New chat** (+ or clear) so old bad language lock clears.
3. Type `hi` → should answer (no L101 error), short, **no diagram**.
4. Type `What is photosynthesis?` → text answer, **no diagram**.
5. Type `Explain photosynthesis with a diagram` → then diagram OK.
6. Type `Explain this clearly for a student: …` → longer, clearer answer.
7. Ask AI tab same rules.

## Manual setup

- **No SQL**
- **No .env**
- Restart FastAPI + Flutter hot restart
- Prefer **New chat** once after restart

## Rollback

Revert:
- `app/models/ask_ai.py`, `select_ai.py`
- `app/services/visual_fallback.py`
- `app/constants/ai_speed.py`
- `app/services/home_ai_service.py`, `rag_ask_service.py`
