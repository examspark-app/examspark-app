# Founder smoke gate + best next method (Phase 5)

> **Official method (Jul 14, 2026):** Finish smoke → Session 3 → 4 → 5 → 6.  
> **Do not** open a separate “half-done polish” track. Polish leftovers are absorbed into Sessions 4–6.  
> **Hard gate:** Do **not** start Session 3 (RAG) until the founder types **`smoke test pass`** in chat.

Companion SQL order: [`FOUNDER_SQL_ORDER.md`](FOUNDER_SQL_ORDER.md)

---

## Step 0 — Smoke checklist (you do this)

### A. SQL (Supabase → SQL Editor → New query → Run)

1. Open and run: `examspark_backend/credit_economy_v2_1_migration.sql` (once; if already run, skip)
2. Open and run: `examspark_backend/smoke_test_all_in_one.sql` (safe to re-run)

**Verify:** last query in smoke file shows your email, `credits_balance`, and `plan_499` (or active plan).

### B. Backend + Flutter

**Backend** (leave window open):

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

**Flutter** (other window — hot restart `R` if already running):

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter run -d chrome --web-port=8080
```

### C. One live upload (pick ONE)

| Try | File | Pass when |
|-----|------|-----------|
| A | Small JPG/PNG | Processing → `done` → Summary tab shows **real sentences** |
| B | Text PDF (not scan-only) | Same |
| C | 5–10 sec **speech** audio | Same |

**Do not tap** Generate More (MCQ / Flashcards / Ask with RAG) — not on FastAPI yet.

### D. Unlock Session 3

In Cursor chat type exactly:

```text
smoke test pass
```

Until you type that, agents must refuse Session 3 / RAG code.

---

## Best next method (after smoke)

| Order | Session | Model | Absorbs from “half-done” list |
|-------|---------|-------|-------------------------------|
| 1 | **Session 3** — RAG chunk + pgvector + Ask AI | Sonnet 5 High | Ask with RAG on notes screen |
| 2 | **Session 4** — R2 path polish | Auto OK / Sonnet if large | R2 folder polish (half) |
| 3 | **Session 5** — Plan-tier + credit gating polish | Auto OK / Sonnet if large | Plan-tier polish (half) |
| 4 | **Session 6** — Razorpay live | Auto OK | Credit packs checkout + payment stubs |

**Extras** (MCQ / Flashcards / Revision): after Session 3 Ask AI core — separate FastAPI work with founder OK.  
**Deduct-then-R2 gap:** small fix only when founder asks — not a full session.

**Wrong method (do not do):** Grab-bag polish of every half-done item before Session 3 — wastes API money and breaks the locked gate.

---

## Money-safe Cursor habit

1. You finish smoke + say `smoke test pass` (SQL in dashboard = free for agent bill)
2. **New chat → Claude Sonnet 5 High** — paste the Session 3 handoff below (one focused session)
3. Short “give me cmd / restart” asks → Auto is fine; don’t burn Sonnet
4. After each session: audit → wait for your OK → never auto-start the next session

---

## Session 3 handoff prompt (copy after `smoke test pass`)

Paste into a **new** Sonnet 5 High chat:

```text
# ExamSpark — Phase 5 Session 3 (RAG + Ask AI)

Founder said: smoke test pass. Implement Session 3 ONLY.

## Hard rules
1. Do NOT start Sessions 4–6.
2. Do NOT rewrite Supabase auth.
3. Do NOT open a “polish all half-done” bag.
4. List files you will change; wait for founder "OK proceed" before large diffs if unsure.
5. End with Manual Setup Checklist + .env Checklist (PROJECT_WORKING_RULES.md).
6. Founder is non-developer — copy-paste commands, numbered steps.

## Project path
C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project

## Build (Session 3 only)
- Chunk Clean Notes + Clean Transcript for a lecture
- Embed + store in pgvector on Supabase Postgres
- FastAPI Ask AI endpoint (RAG order: Notes → Clean Transcript → then stop; Tavily only if founder enables later)
- Deduct Ask AI credits server-side after success (5 Normal / 12 Deep per CREDIT_ECONOMY.md)
- Wire Flutter notes "Ask with RAG" off the old process-lecture edge function onto FastAPI

## Do not build yet
- MCQ / Flashcards / full extras suite (unless tiny stub)
- Razorpay, Session 4 R2 export polish, Session 5 full gating rewrite

## Success
- One Ask AI question on a done lecture returns grounded answer from notes/transcript
- Credits drop server-side
- Update TODO.md + CHANGELOG.md only

Start with a short Phase A audit table (files + gaps). Wait for "OK proceed" before coding if your audit finds big choices.
```

---

## After Session 3 succeeds

Founder says **OK Session 4** (or equivalent). Same pattern: one session per chat, half-done R2 items only inside Session 4, then 5, then 6.
