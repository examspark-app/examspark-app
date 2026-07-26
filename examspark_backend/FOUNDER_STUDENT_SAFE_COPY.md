# Student-safe copy — no technical jargon (Jul 26, 2026)

## Rule
Students must **never** see: RAG, database, FastAPI, SQL, R2, Whisper, OpenRouter, pydantic, Detail dumps, port numbers.

Use short professional lines instead.

## What changed
- New helper: `student_copy.dart` + `studentSafeError()`
- Errors (Home / Ask / lecture): friendly only — no `Detail: […]`
- Labels: “from database” → **already saved** / **Saved · free to reopen**
- Trust line: `Source: Notes` → **From: Your notes**
- Snacks / timeouts / verification: no FastAPI / SQL wording

## Test
1. Flutter **hot restart**
2. Force a Home AI error (or retry old bad chat) → short friendly text, **no** `literal_error` / `Detail`
3. Study chips footer → no “database”
4. Ask AI error → friendly only

## Manual setup
- No SQL · No .env · Hot restart Flutter (FastAPI restart optional)

Founder-only setup guides may still say SQL — that is for **you**, not in-app students.
