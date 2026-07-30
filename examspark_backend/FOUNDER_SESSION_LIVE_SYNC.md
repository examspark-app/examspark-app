# Founder guide — Live credits / plan / groups (no logout)

> **Jul 15, 2026** — App now syncs credits, plan, and group memberships **without** logout/login when Supabase Realtime is on.

Flutter code: `examspark_frontend/lib/core/services/session_live_sync.dart`

---

## Step 1 — Enable Realtime (ek baar)

1. Browser → [Supabase Dashboard](https://supabase.com/dashboard) → ExamSpark project  
2. Left: **Database** → **Publications** (kabhi **Replication**)  
   - Ya Table Editor → table → **Realtime** toggle  
3. Enable Realtime for these **3** tables:

| Table | Why |
|-------|-----|
| `public.users` | Credits pill updates |
| `public.user_subscriptions` | Plan Free ↔ ₹499 live |
| `public.class_memberships` | Leave/join groups live in Groups tab |

4. Save / confirm each is listed under the `supabase_realtime` publication.

**Verify (SQL Editor):**

```sql
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('users', 'user_subscriptions', 'class_memberships');
```

Expect **3 rows**. Agar kam: Dashboard se toggle ON, ya:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.class_memberships;
```

(Agar "already member" error aaye = pehle se ON — theek.)

---

## Step 2 — Flutter restart (code load)

1. Terminal → **`q`** quit old `flutter run`  
2. Phir:
   ```text
   flutter run -d chrome --web-port=8080
   ```
3. Login (ek baar enough — phir logout mat karo tests ke liye)

---

## Step 3 — Live test (bina logout)

Same UUID use karo jo Chrome login hai.

### A) Credits

```sql
DO $$
BEGIN
  PERFORM set_config('app.allow_credit_change', 'true', true);
  UPDATE public.users SET credits_balance = 50
  WHERE id = 'PASTE-YOUR-UUID-HERE';
  PERFORM set_config('app.allow_credit_change', 'false', true);
END $$;
```

**Pass:** Home credits pill ~1–2 sec me **50** (bin logout).  
Agar nahi: Groups tab → Home tab (focus refresh), ya Step 1 Realtime check.

### B) Leave all groups

```sql
DELETE FROM public.class_memberships
WHERE student_id = 'PASTE-YOUR-UUID-HERE';
```

**Pass:** Groups list me saare **Join Group** (Open/Leave gayab) — live ya Groups tab pe dubara tap.

### C) Plan → ₹499

```sql
UPDATE public.user_subscriptions
SET status = 'expired', updated_at = now()
WHERE user_id = 'PASTE-YOUR-UUID-HERE'
  AND status IN ('active', 'grace_period', 'pending');

INSERT INTO public.user_subscriptions (
  user_id, plan_id, status, platform, gateway,
  current_period_start, current_period_end
) VALUES (
  'PASTE-YOUR-UUID-HERE',
  'plan_499',
  'active',
  'web',
  'razorpay',
  now(),
  now() + interval '30 days'
);
```

**Pass:** Profile → Subscription shows **₹499 Plan**; Groups → 2nd Join **without** Free sheet.

---

## Backup agar Realtime off

Tab switch (Home / Groups / Profile) ab bhi **refetch** karta hai — bilkul live nahi, lekin logout zaroori nahi.

---

## .env

Koi naya variable nahi.
