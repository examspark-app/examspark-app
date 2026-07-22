# ExamSpark Phase 4D – Home AI Study History & Workspace (Founder Lock)

**Status:** IN PROGRESS (P0 coded Jul 18, 2026) — founder must run SQL + smoke  
**Locked:** Jul 18, 2026  
**Gate:** Founder said `ok pass` (4C) + `start phase 4` / home history.

**Do NOT:** rewrite existing Home AI backend · store Home AI chat in R2  
**Do:** extend current architecture (`home_ai_responses` / `home_ai_tools` → sessions + messages + history UI)

---

## P0 shipped (code)

| Piece | File / route |
|-------|----------------|
| SQL | [`home_ai_phase4d_migration.sql`](home_ai_phase4d_migration.sql) |
| Auto-save Q+A into session | `home_ai_session_service.ensure_session_for_turn` (after every SUCCESS Home AI / vision) |
| List history | `GET /api/v1/home-ai/sessions` — **0 credits** |
| Restore | `GET /api/v1/home-ai/sessions/{id}` — messages + chip statuses — **0 credits · no AI** |
| Rename / pin / delete | PATCH / POST pin / DELETE |
| Flutter | Home **History** (clock) + **New chat**; restore rebuilds bubbles + chips |

Chips stay in `home_ai_tools` (Phase 4C). Restore only reads cached statuses/payloads — never regenerates.

---

## Founder SQL (required once)

1. Supabase Dashboard → **SQL Editor** → New query  
2. Open [`home_ai_phase4d_migration.sql`](home_ai_phase4d_migration.sql) → copy **all** → paste → **Run**  
3. Verify query at bottom shows `home_ai_sessions` + `home_ai_messages` column counts  
4. Restart backend (uvicorn) if already running  
5. Flutter Hot Restart **`R`**

Until SQL runs: Home AI still works; `session_id` may be null; History list empty/error.

---

## Smoke (careful)

1. Home → ask a short question (5 credits) → answer + chips appear  
2. Open Quiz or Flashcards chip once (0 credits first open)  
3. Tap **History** (clock) → session title = your question  
4. Tap **New chat** → empty Home  
5. History → open that session → **same answer + chips**, snackbar says 0 credits  
6. Credits balance must **not** drop on steps 3–5  

Pass phrase: `Phase 4D history smoke pass`

---

## Objective

Every successful Home AI question → reusable **Study Session**.  
Leave app → return tomorrow → same session → continue without regenerating AI.

Feel: ChatGPT history + study notebook.

## Core principle

```text
One Question → One Knowledge Object → One Study Session
  → Many Learning Tools → Permanent History
```

## Storage

| Store | Where |
|-------|--------|
| Sessions, messages, KO, chips JSON, progress, timestamps | **Supabase only** |
| Large PDF/images/transcripts/exports | R2 (unchanged) |
| Home AI chat / history | **Never R2** |

## Credits

| Action | Credits |
|--------|---------|
| Reopen history / open cached chips | **0** |
| New question / new Knowledge Object | Paid (5 / 12) |
| Regenerate chip | Paid |
| Follow-up needing new KO | Paid (same session) |

## Related docs

- Phase 4C smoke: [`FOUNDER_PHASE4C_SMOKE_CARD.md`](FOUNDER_PHASE4C_SMOKE_CARD.md)  
- Storage policy: [`DATA_STORAGE_POLICY.md`](../DATA_STORAGE_POLICY.md)  
- CTO charter: [`FOUNDER_CTO_WORKING_CHARTER.md`](FOUNDER_CTO_WORKING_CHARTER.md)  
- Pending lock: [`FOUNDER_PENDING_LOCKED.md`](FOUNDER_PENDING_LOCKED.md)
