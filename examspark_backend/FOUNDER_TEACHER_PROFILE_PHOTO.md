# Founder — Teacher profile photo (Groups everywhere)

**Coded Jul 25, 2026.** Photo saves to Supabase Storage + `teacher_profiles.photo_url`.  
Shows on: Teacher Dashboard · My Groups list · Discover · Group Info header.

---

## 1) Manual SQL (required once)

1. Open [Supabase](https://supabase.com/dashboard) → your project → **SQL Editor**  
2. Open file: [`teacher_photos_storage_migration.sql`](teacher_photos_storage_migration.sql)  
3. Copy all → paste → **Run**

**Verify:** Storage → Buckets → **`teacher-photos`** exists and is **Public**.

---

## 2) App smoke

1. Flutter **R**  
2. Profile → Teacher Dashboard → **Edit**  
3. Camera icon / **Add profile photo** → pick image → **Save Profile**  
4. Check photo on Dashboard card  
5. Groups → My Groups / Discover / open group → teacher photo same  

---

## .env

None new.

---

## If upload fails

- Bucket missing → run SQL above  
- “new row violates policy” → re-run policies section of SQL  
- Very large image → use JPG under ~5 MB  
