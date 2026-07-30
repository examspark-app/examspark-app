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
| C2 | [`rag_match_user_wide_migration.sql`](rag_match_user_wide_migration.sql) | **Full-store RAG** — `match_rag_documents_user` (cross-lecture weighted Ask) · [`FOUNDER_YOUTUBE_WHISPER_FALLBACK.md`](FOUNDER_YOUTUBE_WHISPER_FALLBACK.md) |
| C3 | [`lecture_dedupe_migration.sql`](lecture_dedupe_migration.sql) | **Duplicate content** — `content_hash` / `youtube_video_id` / `duplicate_of` + `match_own_transcript_near_dup` · [`FOUNDER_LECTURE_DEDUPE.md`](FOUNDER_LECTURE_DEDUPE.md) |
| C4 | [`rag_exclude_pdf_photo_cleanup.sql`](rag_exclude_pdf_photo_cleanup.sql) | **Optional** — delete old PDF/photo chunks from RAG (audio+YouTube only lock) |
| D | [`pyq_exam_pyqs_migration.sql`](pyq_exam_pyqs_migration.sql) | **start PYQs** — `exam_pyqs` + `match_exam_pyqs`; then `python scripts/seed_pyq_embeddings.py` · [`FOUNDER_START_PYQS.md`](FOUNDER_START_PYQS.md) |
| E | [`quiz_attempts_migration.sql`](quiz_attempts_migration.sql) | **Quiz Attempts Slice A** — Learning Score + Quiz Completed on Progress · [`FOUNDER_QUIZ_ATTEMPTS.md`](FOUNDER_QUIZ_ATTEMPTS.md) |
| F | [`teacher_coupon_migration.sql`](teacher_coupon_migration.sql) | **Teacher Coupon + Discovery fields + notifications + device_tokens** · [`FOUNDER_TEACHER_COUPON.md`](FOUNDER_TEACHER_COUPON.md) · FCM later [`FOUNDER_FCM_SETUP.md`](FOUNDER_FCM_SETUP.md) |
| G | [`teacher_share_access_migration.sql`](teacher_share_access_migration.sql) | **Share → real open + quiz_attempts teacher read** · [`FOUNDER_TEACHER_SHARE.md`](FOUNDER_TEACHER_SHARE.md) |
| H | [`group_daily_active_migration.sql`](group_daily_active_migration.sql) | **Daily Active** — `class_memberships.last_active_at` · [`FOUNDER_DAILY_ACTIVE.md`](FOUNDER_DAILY_ACTIVE.md) |
| I | [`create_study_group_v1_migration.sql`](create_study_group_v1_migration.sql) | **Create Study Group form v1** — `class_level` / `exam` / `language` · [`FOUNDER_CREATE_GROUP.md`](FOUNDER_CREATE_GROUP.md) |
| J | [`create_study_group_v2_approval_migration.sql`](create_study_group_v2_approval_migration.sql) | **Join approval + Pending** — `join_approval_mode` + `group_join_requests` · [`FOUNDER_CREATE_GROUP.md`](FOUNDER_CREATE_GROUP.md) |
| K | [`paid_auto_skip_pending_migration.sql`](paid_auto_skip_pending_migration.sql) | **Paid skip Pending** — Free→Pending; plan_199/499/999 Auto · [`FOUNDER_CREATE_GROUP.md`](FOUNDER_CREATE_GROUP.md) |
| L | [`teacher_social_links_migration.sql`](teacher_social_links_migration.sql) | **Teacher social / trust links** (optional) · [`FOUNDER_TEACHER_SOCIAL_LINKS.md`](FOUNDER_TEACHER_SOCIAL_LINKS.md) |
| M | [`teacher_plan_2999_migration.sql`](teacher_plan_2999_migration.sql) | **Teacher plan ₹2,999** · setup gate docs [`FOUNDER_TEACHER_SETUP_GATE.md`](FOUNDER_TEACHER_SETUP_GATE.md) |
| N | [`teacher_verification_v1_migration.sql`](teacher_verification_v1_migration.sql) | **Teacher Verification v1** (score/hash) + Tavily soft · [`FOUNDER_TEACHER_VERIFICATION_V1.md`](FOUNDER_TEACHER_VERIFICATION_V1.md) |
| O | [`account_delete_soft_migration.sql`](account_delete_soft_migration.sql) | **Account delete + 30-day recover** · [`FOUNDER_ACCOUNT_DELETE_30_DAY.md`](FOUNDER_ACCOUNT_DELETE_30_DAY.md) |
| P | [`teacher_subscriber_count_migration.sql`](teacher_subscriber_count_migration.sql) | **Dashboard Subscribers card** (paid + primary teacher) · [`FOUNDER_TEACHER_DASHBOARD_CARDS.md`](FOUNDER_TEACHER_DASHBOARD_CARDS.md) |
| Q | [`library_favorites_migration.sql`](library_favorites_migration.sql) | **Library Favorites** (`is_favorite`) · [`FOUNDER_PHASE2_SLICE2_FAVORITES.md`](FOUNDER_PHASE2_SLICE2_FAVORITES.md) |

### Jul 16, 2026 — Study extras + Visual Notes (aapka next SQL)

**One paste (recommended):** [`FOUNDER_SQL_JUL16_PENDING.sql`](FOUNDER_SQL_JUL16_PENDING.sql)

Or separately: `extras_payload_json_migration.sql` → `notes_short_supabase_migration.sql` → `notes_visual_payload_migration.sql`

Daily checklist: [`FOUNDER_NEXT_SESSION.md`](FOUNDER_NEXT_SESSION.md)

### Jul 17, 2026 — Home AI Phase 4C (Gate A smoke — NOW)

Run **in order** (safe IF NOT EXISTS):

| Step | File |
|------|------|
| 4C-1 | [`home_ai_phase4c_migration.sql`](home_ai_phase4c_migration.sql) |
| 4C-2 | [`home_ai_phase4c_v2_migration.sql`](home_ai_phase4c_v2_migration.sql) → expect `phase4c_v2_ok` |

Smoke card: [`FOUNDER_PHASE4C_SMOKE_CARD.md`](FOUNDER_PHASE4C_SMOKE_CARD.md) · CTO: [`FOUNDER_CTO_WORKING_CHARTER.md`](FOUNDER_CTO_WORKING_CHARTER.md)

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
