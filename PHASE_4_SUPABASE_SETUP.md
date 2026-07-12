# Phase 4 — Supabase Setup Guide (Founder — step by step)

> **Ek hi baar karna hai.** Ye guide aapko Supabase project banane se lekar
> poora database (Groups, Teacher Dashboard, Credits, RAG) taiyar karne tak
> le jaayegi. Har step ke baad "Verify" line check karo.

**Related docs:** [`FOUNDER_MANUAL_SETUP_GUIDE.md`](FOUNDER_MANUAL_SETUP_GUIDE.md) · [`API_SETUP.md`](API_SETUP.md) · [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md)

---

## Step 1 — Supabase project (skip if already done)

1. **https://supabase.com** kholo → Sign up / Login
2. **New project** → Name: `ExamSpark` → strong DB password (save it) → Region: **South Asia (Mumbai)**
3. 2–3 minute wait karo

**Verify:** Dashboard khul jaaye, left side "Table Editor" dikhe.

---

## Step 2 — Paste URL + anon key into Flutter

1. Supabase Dashboard → ⚙️ **Project Settings** → **API**
2. Copy **Project URL** aur **anon public** key
3. Open `examspark_frontend/.env` → paste:

```env
SUPABASE_URL=https://apna-project-url.supabase.co
SUPABASE_ANON_KEY=apni-anon-key-yahan
```

4. Save (Ctrl + S)

**Verify:** `flutter run -d chrome` se login screen khulta hai.

---

## Step 3 — Run the full database schema (one paste, one click)

1. Supabase Dashboard → left side **SQL Editor** → **New query**
2. Open [`examspark_backend/schema.sql`](examspark_backend/schema.sql) in this project
3. **Select All** (Ctrl+A) → **Copy** (Ctrl+C) the entire file
4. Paste into the Supabase SQL Editor
5. Click **Run** (bottom right)

**Verify:** Bottom panel shows "Success. No rows returned." No red error.

**Agar error aaye:** Screenshot lo aur AI ko dikhao — copy-paste the exact error text.

---

## Step 4 — Verify tables exist

Left side → **Table Editor** → confirm these tables appear:

- [ ] `users`, `lectures`, `transcripts`, `notes`, `extras`, `credit_transactions`
- [ ] `teacher_profiles`, `teacher_certificates`, `teacher_achievements`
- [ ] `class_folders`, `class_memberships`, `group_shared_items`
- [ ] `rag_documents`, `exam_pyqs`, `ncert_vectors`
- [ ] `subscription_plans` (should already have 5 rows: free, plan_199, plan_499, plan_999, teacher)
- [ ] `payments`, `payment_transactions`, `user_subscriptions`, `credit_history`

---

## Step 5 — Confirm Row Level Security (RLS) is ON

Table Editor → click any table (e.g. `lectures`) → top right should show
**"RLS enabled"** with a green shield icon.

**Why this matters:** Without this, any logged-in user could read/edit
anyone else's lectures, notes, or credits. The schema turns this on for
every sensitive table automatically — this step is just a visual check.

---

## Step 6 — Paste the service-role key into the backend

1. Supabase → Project Settings → API → **service_role** key (⚠ secret — never
   put this in Flutter)
2. Open `examspark_backend/.env` → paste:

```env
SUPABASE_SERVICE_ROLE_KEY=apni-service-role-key-yahan
```

3. Also add the same key: Supabase Dashboard → **Edge Functions** → **Secrets**

**Verify:** `examspark_backend/.env` has the key, Flutter `.env` does **not**.

---

## Step 7 — (Optional now, required before Phase 5) Cloudflare R2 bucket

Not needed to test Groups / Teacher Dashboard today — R2 upload code is
Phase 5. When you're ready:

1. **https://dash.cloudflare.com** → R2 → **Create bucket** (name: `examspark-storage`)
2. R2 → **Manage API tokens** → Create token → copy Access Key ID + Secret
3. Paste into `examspark_backend/.env`:

```env
CLOUDFLARE_ACCOUNT_ID=
CLOUDFLARE_API_TOKEN=
R2_BUCKET_NAME=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_PUBLIC_URL=
```

---

## What's now working end-to-end

| Feature | Status after this guide |
|---|---|
| Login / Signup | Already working (Phase 2) |
| Lectures / Notes / Transcripts | Already working (Phase 2, RLS now enforced) |
| **Groups** — create, join by code, feed | ✅ Real Supabase (`class_folders` etc.) |
| **Teacher Dashboard** — Students, Groups, Credits cards | ✅ Real data |
| Teacher Dashboard — Revenue, Subscribers, Analytics | ⏳ Placeholder — Phase 5 (payments + PostHog) |
| Credits balance display | ✅ Real (`users.credits_balance`) |
| Credit deduction | ✅ Server-enforced (`fn_deduct_credits`) — not yet called by any UI action (Phase 5 wires the AI actions that spend credits) |
| RAG / vector search | Schema ready; population + search logic is Phase 5 (FastAPI + AI pipeline) |
| R2 file storage | Schema ready (path columns); actual upload/download is Phase 5 |

---

## Rollback

Made a mistake or want to start over? In the SQL Editor, run:

```sql
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
```

Then re-run Step 3. **Warning:** this deletes all data in the project — only
do this on a fresh/test project, never in production.

---

## Changelog

| Date | Change |
|------|--------|
| Jul 11, 2026 | Initial Phase 4 Supabase setup guide |
