# ExamSpark — Important Pending Work (Founder)

> **Saved:** Jul 15, 2026 · **Updated:** Jul 16, 2026  
> **Purpose:** Single list of important unfinished work. Not a grab-bag polish queue.

**Rule:** Jo founder **pass / OK** keh chuka — **dobara setup/SQL/smoke re-nag mat karo.**

**Health check:** `http://localhost:8000/` (not `/health`)

**➡ Memory card:** [`examspark_backend/FOUNDER_NEXT_SESSION.md`](examspark_backend/FOUNDER_NEXT_SESSION.md)

| Status | Item |
|--------|------|
| **NEXT (founder ~15 min)** | Realtime 3 tables + trim SQL (if open) |
| **⏸ paused** | Session 6 Razorpay — jab Test keys ready |
| **Next coding (bolo tab)** | Flashcards / Quiz extras → FastAPI |

**Credit rules:** [`FOUNDER_CREDIT_RULES_AS_SHIPPED.md`](FOUNDER_CREDIT_RULES_AS_SHIPPED.md)

### Passed (do not re-test / re-run unless bug)

- [x] Groups join limits mock + Free lock + ₹199 1/1 (Jul 16)
- [x] YouTube Link → Notes smoke pass (Jul 16)
- [x] Session live sync **code** (Realtime wire in Flutter)
- [x] SEED_DEMO_GROUPS / RLS path used in mock pass
- [x] Free join UI bypass fix · Session 5 gating

### Still open (founder)

- [ ] **Enable Realtime** on `users`, `user_subscriptions`, `class_memberships`
- [ ] **Run** [`subscription_change_trim_groups_migration.sql`](examspark_backend/subscription_change_trim_groups_migration.sql) if not already
- [ ] Chat: `groups + realtime checklist done`
- [ ] **Razorpay Test keys + smoke** — ⏸ until founder calls ([`FOUNDER_RAZORPAY_SESSION6.md`](examspark_backend/FOUNDER_RAZORPAY_SESSION6.md))

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

- [x] **Session 5** — Server-side plan-tier + credit gating polish (Jul 15, 2026)
- [ ] **Session 6** — Razorpay test keys + pay smoke (code shipped; founder: FOUNDER_NEXT_AFTER_GROUPS.md Part B)

### Session 5 — Free-tier lock smoke (full founder guide)

#### Pehle padho — Free = 50 credits (v2.2)

| Concept | Matlab |
|---------|--------|
| **Free plan** | Har mahine **50 credits**; Ask/PDF/Photo **credits** se |
| **Plan lock** | **Sirf audio** record/upload → **₹199+** |
| Credits zero | Test ke liye mat karo — Ask/PDF fail ho jayenge |

Naya SQL (ek baar): [`examspark_backend/credit_economy_free50_audio199_migration.sql`](examspark_backend/credit_economy_free50_audio199_migration.sql)

---

#### Part 0 — Servers on

1. Backend Active: open `http://localhost:8000/` (not `/health`)
2. Flutter Chrome chal raha ho
3. Har SQL change ke baad Flutter terminal mein hot restart **`R`**

---

#### Part 1 — Apna user UUID copy karo

1. Browser → [Supabase Dashboard](https://supabase.com/dashboard) → apna ExamSpark project  
2. Left: **Authentication** → **Users**  
3. Apni email wali row → copy **User UID** (dashes wala UUID)  
4. Notepad mein paste — neeche saari SQL mein `PASTE-YOUR-UUID-HERE` ki jagah yeh UUID

Example shape: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

---

#### Part 2 — Abhi ka plan check (sirf SELECT)

1. Supabase → **SQL Editor** → New query  
2. Paste (UUID replace karo — quotes ke andar):

```sql
select public.fn_user_plan_tier('PASTE-YOUR-UUID-HERE');
```

3. **Run**

| Result | Matlab |
|--------|--------|
| `free` | Free plan — Part 4 (E1–E5) ready; Part 3 skip |
| `plan_199` / `plan_499` / `plan_999` / `teacher` | Paid active — pehle **Part 3** |
| ERROR: function does not exist | Chat mein bolo — `fn_user_plan_tier` schema fix |

---

#### Part 3 — Paid plan OFF → Free (lock tests)

Goal: koi bhi **active + not-expired** `user_subscriptions` row na rahe.

**Step A — dekho kya hai**

```sql
select id, plan_id, status, current_period_end
from public.user_subscriptions
where user_id = 'PASTE-YOUR-UUID-HERE'
order by current_period_end desc;
```

Note down `plan_id` (rollback ke liye, e.g. `plan_499`).

**Step B — Free banao (safest: expire; delete mat pehle)**

```sql
update public.user_subscriptions
set status = 'expired',
    updated_at = now()
where user_id = 'PASTE-YOUR-UUID-HERE'
  and status = 'active';
```

**Step C — dobara verify**

```sql
select public.fn_user_plan_tier('PASTE-YOUR-UUID-HERE');
```

Expected: **`free`**

**Step D — credits enough rakho (zero mat karo)**

```sql
select credits_balance from public.users where id = 'PASTE-YOUR-UUID-HERE';
```

Agar balance **40 se kam** hai (sirf testing bump):

```sql
update public.users
set credits_balance = 50
where id = 'PASTE-YOUR-UUID-HERE';
```

**Step E — app**

Flutter terminal → **`R`** → same account se login.

---

#### Part 4 — Tests E1–E5 (v2.2 Free = credits; only audio locked)

| # | Kya karo | Expected |
|---|----------|----------|
| E1 | Home short Ask | Answer; **−5** credits |
| E2 | Text PDF upload | Chalna (agar ≥20 credits); **−20** |
| E3 | JPG/PNG diagram | **Free pe OK**; **−25** (plan lock nahi) |
| E4 | Record / audio upload (Free or ₹199) | **Lock pehle dikhe** (mic lock / ₹499 sheet) — recording screen na khule |
| E5 | Plan `plan_499` set → **`R`** → short record | Unlock; credits 40/80/120 |

Fail → E# + screenshot → chat.

---

#### Part 5 — Rollback (daily paid testing wapas)

Part 3A se jo `plan_id` tha (example `plan_499`):

```sql
update public.user_subscriptions
set status = 'active',
    current_period_end = now() + interval '30 days',
    updated_at = now()
where user_id = 'PASTE-YOUR-UUID-HERE'
  and plan_id = 'plan_499';  -- jo pehle tha woh likho
```

Verify:

```sql
select public.fn_user_plan_tier('PASTE-YOUR-UUID-HERE');
```

Expected: wapas `plan_499` (ya jo set kiya). Flutter **`R`**.

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

1. Run SQL: `credit_economy_free50_audio199_migration.sql` (Free → 50)
2. Restart FastAPI + Flutter **`R`**
3. Free plan pe **E1–E5** ([`FOUNDER_CREDIT_RULES_AS_SHIPPED.md`](FOUNDER_CREDIT_RULES_AS_SHIPPED.md))
4. Then Session 6 (Razorpay) when ready
