# Founder mock test — Group join limits

> **Code already shipped.** Yeh sirf test guide hai — koi naya coding nahi.  
> **SQL file:** [`group_join_limits_enforce_migration.sql`](group_join_limits_enforce_migration.sql)

```text
Step 1: SQL run (ek baar)
Step 2: Confirm 2 functions exist
Step 3: User Free hai?
Step 4: Flutter → Join Group → lock sheet
Step 5: (Optional) trim SQL
```

---

## Pehle samjho — pass kya hai

| Rule | Expected |
|------|----------|
| Free plan | Groups join **nahi** — **Buy Plan / lock** sheet |
| Paid + under limit | Join OK (Razorpay ready hone ke baad) |
| Refund / Free again | Student group memberships auto-leave |

Flutter Chrome (`8080`) chal raha ho to theek hai.

### Founder verify log (Jul 15, 2026) — SQL PASS

| Check | Result |
|-------|--------|
| Both functions in `pg_proc` | Pass (2 rows) |
| Users on Free (`260157cd-…`, `cc1ab44e-…`) | Pass (`fn_user_plan_tier` = `free`) |
| `fn_trim_group_memberships` + membership count | Pass (0 / 0) |

**Ab sirf Step 4 (Flutter) bacha hai.**

### Bug fix (Jul 15 evening) — Free join UI bypass

Pehle server reject ke baad Flutter **fake joined** + group page khol deta tha. Ab fix:
- mock-on-error hata diya
- Free (`maxGroups <= 0`) hard block
- Join fail → Buy Plan sheet; page **nahi** khulti

**Retest (full restart zaroori):**

1. Flutter terminal mein **`q`** (quit) → phir:
   ```text
   flutter run -d chrome --web-port=8080
   ```
2. Free login (45 credits OK)
3. Groups → **Join Group** → sirf **Buy Plan** sheet
4. Optional SQL:
   ```sql
   SELECT id, max_groups FROM subscription_plans WHERE id = 'free';
   -- expect max_groups = 0
   ```
5. Pass line: `SQL done + Free join = lock sheet`

---

## Step 1 — SQL (Supabase mein ek baar)

1. Cursor mein file kholo: `examspark_backend/group_join_limits_enforce_migration.sql`
2. **Ctrl+A** → **Ctrl+C** (poora file)
3. Browser → [Supabase Dashboard](https://supabase.com/dashboard) → apna ExamSpark project
4. Left side: **SQL Editor** → **New query**
5. **Ctrl+V** → **Run**
6. **Green Success** → Step 2  
   **Red error** → chat mein poora error paste karo; aage mat badho

---

## Step 2 — Verify (functions bani?)

SQL Editor mein yeh run karo (alag query):

```sql
SELECT proname FROM pg_proc
WHERE proname IN ('fn_enforce_group_join_limit', 'fn_trim_group_memberships');
```

| Result | Matlab |
|--------|--------|
| **2 rows** (dono names) | Pass → Step 3 |
| **0 rows** | Step 1 dubara / error chat mein bhejo |

---

## Step 3 — User Free hai?

1. Supabase → **Authentication** → **Users**
2. Apni email wali row → **User UID** copy (dashes wala)
3. SQL Editor (UUID replace karo — quotes ke andar):

```sql
SELECT public.fn_user_plan_tier('PASTE-YOUR-UUID-HERE');
```

| Result | Matlab |
|--------|--------|
| `free` | Perfect → Step 4 |
| `plan_199` / `plan_499` / `plan_999` / `teacher` | Neeche cancel SQL chalao, ya dusra Free account |

Free chahiye (sirf test) — UUID replace:

```sql
UPDATE user_subscriptions
SET status = 'cancelled', updated_at = now()
WHERE user_id = 'PASTE-YOUR-UUID-HERE' AND status = 'active';

SELECT public.fn_user_plan_tier('PASTE-YOUR-UUID-HERE');
```

Phir result **`free`** hona chahiye.

---

## Step 4 — Flutter mock test (main check)

1. Chrome app mein **usi Free user** se login
2. Flutter terminal (jahan `flutter run` chal raha) → keyboard **`R`** (hot restart)
3. Bottom nav → **Groups**
4. Kisi group pe **Join Group** dabao

| Pass | Fail |
|------|------|
| **Buy Plan / upgrade** sheet khule; join **na** ho | Seedha join / kuch na ho |

Yahi primary mock pass hai.

---

## Step 5 — Optional: trim (refund jaisa)

UUID replace:

```sql
SELECT public.fn_trim_group_memberships('PASTE-YOUR-UUID-HERE');
```

Phir:

```sql
SELECT count(*) FROM class_memberships
WHERE student_id = 'PASTE-YOUR-UUID-HERE';
```

Free user pe **Pass** = `count` = **0**.

---

## Chat mein kya likho

Ek line kaafi:

- `SQL done + Free join = lock sheet` → **mock pass**
- Ya: kis step pe stuck + SQL error text / screenshot

---

## Abhi mat karo

- Real Razorpay se ₹499 → 3 groups test (keys ready hone ke baad)
- Naya Flutter / backend code (pehle se ready)

---

## .env

Is test ke liye **koi naya .env variable nahi**.
