# Founder — Account delete (30-day Library recovery)

**Date:** Jul 26, 2026  
**Who:** Student + Teacher + all accounts

## What it does

| Step | Behavior |
|------|----------|
| Profile → **Delete account** | Replaces Storage row |
| Confirm | Type **DELETE** |
| Soft delete | Library kept; app shows **Recover** screen |
| Within 30 days | **Recover account** → full access again |
| After 30 days | Founder runs purge SQL → permanent delete (auth + data) |

Teachers: soft-deleted teachers hidden from Discover fuzzy search.

---

## ⚠ Manual setup (you must do)

### 1) SQL (required once)

1. Supabase → **SQL Editor** → New query  
2. Open file: `examspark_backend/account_delete_soft_migration.sql`  
3. Copy **all** → Paste → **Run**  
4. Verify: last queries show `deleted_at`, `purge_after` + 3 function names  

### 2) Flutter hot restart

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter run -d chrome --web-port=8080
```

### .env

None new.

---

## 🧪 Smoke

1. Login (student or teacher)  
2. Profile → **Delete account** → type `DELETE` → confirm  
3. See **Account scheduled for delete** + date  
4. Tap **Recover account** → app opens again; Library lectures still there  
5. Optional: delete again → **Sign out** → login → recovery screen again  

### After 30 days (or test purge early)

**Only for accounts past `purge_after`.** Soft-delete first, then temporarily set purge in past for a test user:

```sql
-- TEST ONLY — set one email's purge to the past, then purge
UPDATE public.users
SET purge_after = now() - interval '1 minute'
WHERE lower(email) = lower('TEST_EMAIL@gmail.com')
  AND deleted_at IS NOT NULL;

SELECT public.fn_purge_expired_deleted_accounts();
```

Normal monthly: just run:

```sql
SELECT public.fn_purge_expired_deleted_accounts();
```

Returns count of hard-deleted users.

---

## Rollback

- UI: restore Storage row / hide Delete account  
- SQL: columns can stay; stop calling RPCs  
  `ALTER TABLE users DROP COLUMN IF EXISTS deleted_at, DROP COLUMN IF EXISTS purge_after;`  
  only if you accept losing soft-delete state

---

## Recommended next

After smoke OK → schedule weekly purge reminder, or later wire Railway cron.
