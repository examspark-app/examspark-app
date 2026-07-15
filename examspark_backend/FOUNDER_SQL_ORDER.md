# ExamSpark — Founder SQL Run Order (Single Reference)

> **Rule:** Ek time pe **ek file** Supabase SQL Editor mein run karo.  
> **Already ran schema?** Skip to step 7 only (`smoke_test_all_in_one.sql`).  
> **After SQL:** smoke + next session method → [`FOUNDER_SMOKE_AND_NEXT.md`](FOUNDER_SMOKE_AND_NEXT.md)  
> (smoke gate → Session 3 → 4 → 5 → 6 — **no** separate polish bag).

Supabase path: **Dashboard → SQL Editor → New query → paste → Run**

---

## Fresh project (never ran SQL before)

| Step | File | Kab run karo | Safe re-run? |
|------|------|--------------|--------------|
| 1 | [`schema.sql`](schema.sql) | Pehli baar database setup | No — duplicates error |
| 2 | [`student_onboarding_migration.sql`](student_onboarding_migration.sql) | After schema | Yes (IF NOT EXISTS) |
| 3 | [`teacher_group_features_migration.sql`](teacher_group_features_migration.sql) | After schema | Yes |
| 4 | [`teacher_commission_migration.sql`](teacher_commission_migration.sql) | After step 3 | Yes |
| 5 | [`credit_economy_v2_1_migration.sql`](credit_economy_v2_1_migration.sql) | Before live smoke test | Yes |
| 6 | [`auth_user_bootstrap.sql`](auth_user_bootstrap.sql) | Optional — included in step 7 | Yes |
| 7 | [`smoke_test_all_in_one.sql`](smoke_test_all_in_one.sql) | Before Flutter record/upload test | Yes |

---

## Existing project (schema already ran — aapka case)

| Step | File | Kyun |
|------|------|------|
| A | [`credit_economy_v2_1_migration.sql`](credit_economy_v2_1_migration.sql) | Plan credits + credit_packs (agar pehle run nahi kiya) |
| B | [`smoke_test_all_in_one.sql`](smoke_test_all_in_one.sql) | **GRANTs + user trigger + plan_499** — record/upload 42501 fix |
| C | [`session3_rag_match.sql`](session3_rag_match.sql) | **Session 3 Ask AI** — `match_rag_documents` RPC (after smoke) |

**Mat run karo dubara:** `schema.sql` (purana DB toot sakta hai)

**Deprecated — mat use karo:** [`group_shared_items_grants_migration.sql`](group_shared_items_grants_migration.sql) — step B mein sab included hai

---

## Verify after step B

**Supabase result tables (script ke end mein):**
- Grants rows for `lectures`, `users`, `group_shared_items`
- Your email + `plan_499` + `active`

**Terminal (backend folder):**
```powershell
cd examspark_backend
python scripts/verify_smoke_prereqs.py
```
Expected: `ALL CHECKS PASSED`

---

## Important constraints (errors avoid karo)

| Mat karo | Kyun |
|----------|------|
| `UPDATE users SET credits_balance = ...` | Trigger block — sirf `fn_deduct_credits()` se change |
| `user_subscriptions` INSERT bina `platform` + `gateway` | NOT NULL columns — use `web` + `razorpay` |
| Alag-alag GRANT files | Sirf `smoke_test_all_in_one.sql` |

---

## Smoke test terminals (after SQL OK)

**Terminal 1 — backend (open rakho):**
```powershell
cd examspark_backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```
Browser: `http://localhost:8000/` → `"ExamSpark Backend Active"`

**Terminal 2 — Flutter:**
```powershell
cd examspark_frontend
flutter run -d chrome
```
`.env` must have: `FASTAPI_BASE_URL=http://localhost:8000`

**App:** Record Lecture → Upload Document/Photo → chhota JPG → wait for done.

---

## Rollback

- GRANTs: no rollback needed (safe)
- plan_499 test row: change `plan_id` back to `free` in Supabase Table Editor if needed
- Code rollback: git restore — never force-push
