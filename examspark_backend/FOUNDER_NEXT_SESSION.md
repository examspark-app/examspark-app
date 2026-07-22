# Next session — kya baki hai (MASTER LIST)

> **Jul 16, 2026** · Single memory card.  
> **Rule:** Jo pehle **pass / OK** hai — **dobara setup / smoke / SQL re-nag mat karo.**  
> **Plans:** `.cursor/plans/*.plan.md` = history only. **Yeh file** = aapka daily to-do.  
> **Pending LOCK (honest freeze):** [`FOUNDER_PENDING_LOCKED.md`](FOUNDER_PENDING_LOCKED.md)  
> **CTO Charter:** [`FOUNDER_CTO_WORKING_CHARTER.md`](FOUNDER_CTO_WORKING_CHARTER.md)  
> **NOW (Gate A):** [`FOUNDER_PHASE4C_SMOKE_CARD.md`](FOUNDER_PHASE4C_SMOKE_CARD.md) — Phase 4C careful smoke pehle; phir hi `start …`

---

## Already done (yaad mat dilao)

> **Jul 16 night review:** [`FOUNDER_TODAY_JUL16_NIGHT_CHECK.md`](FOUNDER_TODAY_JUL16_NIGHT_CHECK.md) — aaj ka list + audit + smoke order.

- Groups join limits · Free lock · ₹199 1/1
- YouTube Link → Notes (**smoke pass**)
- **Flashcards + Quiz + Revision** Study Workspace → FastAPI (**code shipped** — founder UI smoke pending)
- **Important Questions + Mind Map** → FastAPI (**code shipped** — smoke after Visual Notes)
- **Smart Visual Notes** + **Select AI** → FastAPI (**code shipped** — founder UI smoke pending)
- **5 Minute Revision** Home chip → FastAPI (**code shipped Jul 16** — founder UI smoke pending; 5 credits)
- Session 5 gating · Session 3 RAG Ask AI core · Session 4 R2 core
- Session 6 **code** (keys smoke alag)

---

## Aaj / is week — exact order

### Step 0 — Servers

**Terminal 1 — backend (open rakho):**

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Browser: `http://localhost:8000/` → `"ExamSpark Backend Active"`

**Terminal 2 — Flutter:**

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter pub get
flutter run -d chrome
```

Hot restart: **`R`**. `.env` must have `FASTAPI_BASE_URL=http://localhost:8000` (or your PC IP).

---

### Step 1 — SQL (ek baar, jo abhi tak nahi chala)

**Easiest:** Supabase → **SQL Editor** → New query → paste entire  
[`FOUNDER_SQL_JUL16_PENDING.sql`](FOUNDER_SQL_JUL16_PENDING.sql) → **Run**.

Or run separately (same effect):

1. [`extras_payload_json_migration.sql`](extras_payload_json_migration.sql)
2. [`notes_short_supabase_migration.sql`](notes_short_supabase_migration.sql) — agar pehle nahi
3. [`notes_visual_payload_migration.sql`](notes_visual_payload_migration.sql)

Agar pehle chalaya tha → **dobara mat chalao**. Error “already exists” = OK, skip.

Verify query is inside `FOUNDER_SQL_JUL16_PENDING.sql` (expect rows for `payload_json` + notes columns).

---

### Step 2 — Smoke (ek ek karke)

| # | Test | Pass message (chat mein likho) |
|---|------|--------------------------------|
| 3 | Flashcards → Quiz → Revision (5/5/5) | `Flashcards Quiz Revision smoke pass` |
| 3c | Visual Notes (Physics/Math Notes + Home AI) | `Visual Notes 5A smoke pass` |
| 3b | Important Questions + Mind Map (Home chips; 20/30) | after 3c — report pass/error |
| 3d | Select AI (Notes select → Explain 2 / Quiz 3) | `Select AI smoke pass` |
| 3e | 5 Minute Revision (Home chip; 5 credits) | `5 Minute Revision smoke pass` |

#### 3) Flashcards + Quiz + Revision

| Step | Action |
|------|--------|
| B2 | Open a lecture that already has **Notes** |
| B3 | Study Workspace → **Flashcards** → Generate (5 credits) → flip cards |
| B4 | **Quiz** tab → Generate (5 credits) → answer MCQs |
| B5 | **Revision** tab → Generate (5 credits) → read sheet |
| B6 | Close + reopen same lecture → loads without re-charge (GET) |
| B7 | Chat: `Flashcards Quiz Revision smoke pass` |

#### 3c) Smart Visual Notes

| Step | Action |
|------|--------|
| D2 | Physics/Math lecture → **Notes** → LaTeX / graph / diagram if AI sent them |
| D3 | Home AI math question → stream + visual after done (if model included) |
| D4 | **Cheat Sheet** chip → opens Notes |
| D5 | Chat: `Visual Notes 5A smoke pass` |

#### 3b) Important Questions + Mind Map (after 3c)

Home chips → generate → results sheet. Credits **20** / **30**.

#### 3d) Select AI

| Step | Action |
|------|--------|
| E2 | Notes → select paragraph → **Select AI** → **Explain** (2 credits) |
| E3 | Select → **Generate Quiz** (3 credits) → 5 MCQs |
| E4 | Optional: Flashcards text → **Memory Trick** (2 credits) |
| E5 | Chat: `Select AI smoke pass` |

#### 3e) 5 Minute Revision smoke — founder test

| Step | Action |
|------|--------|
| F1 | Home AI reply → study chip **5 Minute Revision** (5 credits) |
| F2 | Bottom sheet shows short Must-know / Formulas / Recap |
| F3 | Chat: `5 Minute Revision smoke pass` or report error |

Error → screenshot / exact text — naya plan mat kholo.

---

## Alag pending (coding nahi)

### 1) Realtime + trim — ek baar

Guide: [`FOUNDER_SESSION_LIVE_SYNC.md`](FOUNDER_SESSION_LIVE_SYNC.md) · trim: [`subscription_change_trim_groups_migration.sql`](subscription_change_trim_groups_migration.sql)

| Step | Action |
|------|--------|
| A1 | Realtime ON: `users` · `user_subscriptions` · `class_memberships` |
| A2 | Trim migration SQL (agar nahi chalaya) |
| A3 | Chat: `groups + realtime checklist done` |

```sql
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('users', 'user_subscriptions', 'class_memberships');
```

Expect **3 rows**.

### 2) Razorpay Session 6 — ⏸ jab keys ready

- Guide: [`FOUNDER_RAZORPAY_SESSION6.md`](FOUNDER_RAZORPAY_SESSION6.md)
- Pass: `Session 6 Razorpay smoke pass`
- **Do not start** without Test Mode keys

---

## Next coding (aap “start” bolo)

| Prefer | Work |
|--------|------|
| **Default** | PYQs → FastAPI |
| Later | Google Play Internal · Refund live · PhonePe · Tavily · Storage MB |

```text
start PYQs
```

---

## Abhi mat karo

- 100 plan.md files ek ek follow
- Purane smoke SQL dobara jab pass ho chuka
- Razorpay bina keys
- Naya feature coding jab tak smoke (jitna ho sake) nahi

---

## Prefer reply (ek line)

`Flashcards Quiz Revision smoke pass` · `Visual Notes 5A smoke pass` · `Select AI smoke pass` · `5 Minute Revision smoke pass` · `groups + realtime checklist done` · `start PYQs`
