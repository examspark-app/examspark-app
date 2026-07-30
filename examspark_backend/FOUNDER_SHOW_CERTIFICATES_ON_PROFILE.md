# Founder — Show certificates on profile (ON/OFF)

**What:** Teacher chooses whether uploaded **profile certificates** appear for students (e.g. Group Info).

| Toggle | Effect |
|--------|--------|
| **OFF** (default) | Certificates private — only teacher sees them while editing |
| **ON** | Students can see certificate titles on Group Info |

**Not the same as Get Verified (AI Trusted badge).**

---

## 1. Manual SQL (required once)

1. Supabase → **SQL Editor** → New query  
2. Open `examspark_backend/show_certificates_on_profile_migration.sql`  
3. Copy all → Paste → **Run**  
4. Verify: column `show_certificates_on_profile` exists  

---

## 2. App refresh

Flutter hot **restart** (`R`). No new `.env` keys.

---

## 3. Smoke test

1. Teacher → Edit / Complete profile → add a certificate  
2. Leave **Show certificates on profile** = **OFF** → Save  
3. Student → Group Info for that teacher → **no** certificate section (or no certs)  
4. Teacher → turn toggle **ON** → Save  
5. Student refresh Group Info → certificates **visible**  

---

## Rollback (only if founder asks)

```sql
DROP POLICY IF EXISTS "teacher_certificates_select" ON public.teacher_certificates;
CREATE POLICY "teacher_certificates_select_all" ON public.teacher_certificates
  FOR SELECT USING (true);
-- Optional: keep column; or:
-- ALTER TABLE public.teacher_profiles DROP COLUMN IF EXISTS show_certificates_on_profile;
```
