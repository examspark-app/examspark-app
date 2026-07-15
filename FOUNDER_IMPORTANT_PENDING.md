# ExamSpark — Important Pending Work (Founder)

> **Saved:** Jul 15, 2026  
> **Purpose:** Single list of important unfinished work. Not a grab-bag polish queue — follow locked Phase 5 order for Sessions 5–6.

**Health check:** `http://localhost:8000/` (not `/health`)

---

## SQL — re-run rules

| Situation | Action |
|-----------|--------|
| You already ran a migration successfully | **Do not** re-run the whole stack |
| File says “safe to re-run” / `IF NOT EXISTS` | Optional only if something broke |
| New SQL appears in CHANGELOG/TODO | Run **that new file only** |
| Performance Phase 1 | **No new SQL** (optional index check in [`PERFORMANCE_PHASE1_REPORT.md`](PERFORMANCE_PHASE1_REPORT.md)) |

---

## P0 — UX broken / blocked today

- [x] **Library Study Workspace Ask AI → FastAPI** — wired Jul 15 (`workspace_ask_ai_pane.dart`)
- [x] **Groups: open group page after join** — auto-open + Open group button Jul 15

---

## P1 — Phase 5 (locked order — do not skip)

- [ ] **Session 5** — Server-side plan-tier + credit gating polish
- [ ] **Session 6** — Razorpay live webhooks + founder setup guide

---

## P2 — Study generate (FastAPI)

- [ ] Flashcards / Quiz / MCQ / Revision / Answer-Key → FastAPI (still edge function today)
- [ ] Home AI study-action chips → generate on click (today: snackbar)

---

## P3 — Knowledge / later AI

- [ ] Trusted Web Search (Tavily) — `answer_source=WEB`
- [ ] PYQ database (metadata-only copyright policy)
- [ ] Translate API product (8 credits) — multilingual Q&A prompt already soft-live
- [ ] Persist `answer_source` / `confidence` to analytics DB
- [ ] Perf later: Redis shared cache, smaller chat model (founder `.env`), real web route

---

## Teacher platform — honest status (~40–45%)

| Area | Roughly |
|------|---------|
| Role + dashboard cards scaffold | ~60–70% |
| Groups create/join UI + wiring | ~50–60% |
| Share recorded lecture to group | ~40–50% |
| Live revenue / commission payout | ~10% display-only |
| Full analytics + student lists | Spec only |
| ExamSpark “admin” create platform groups | **Not built** |

Teacher rule remains: **teacher owns group**; students cannot upload/message; share content = teacher only.

---

## Already shipped (do not re-build)

SSE stream · language lock · typo tolerance · AI speed 512 · Perf Phase 1 caches/routing · Session 3 Ask AI RAG core · Session 4 R2 paths

---

## Aapka recommended next

1. Smoke P0: Library lecture → Ask AI chat; Groups Join → page opens  
2. Then Session 5 when you ask  
