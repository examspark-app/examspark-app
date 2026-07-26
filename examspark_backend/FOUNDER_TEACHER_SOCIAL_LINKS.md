# Founder — Teacher Social Links (trust)

Students see optional links on teacher profile (Group Info). Teacher edits on **Teacher Dashboard** (not only long profile create).

## Links (all optional)

Website · YouTube · Instagram · Facebook · LinkedIn · WhatsApp · Telegram · X

## Manual setup

### 1. SQL (required once)

Supabase → **SQL Editor** → paste → **Run**:

[`teacher_social_links_migration.sql`](teacher_social_links_migration.sql)

**Verify:** 8 rows `link_website` … `link_x`

Tell CTO: **SQL teacher social links done**

### 2. Flutter

Hot restart (**R**). No new `.env`.

## Smoke

1. Teacher Dashboard → **Social links (optional)** → paste 1–2 URLs → Save  
2. Student opens that teacher's Group Info → icons dikhein → tap opens browser / WhatsApp  

## Rollback

```sql
ALTER TABLE teacher_profiles
  DROP COLUMN IF EXISTS link_website,
  DROP COLUMN IF EXISTS link_youtube,
  DROP COLUMN IF EXISTS link_instagram,
  DROP COLUMN IF EXISTS link_facebook,
  DROP COLUMN IF EXISTS link_linkedin,
  DROP COLUMN IF EXISTS link_whatsapp,
  DROP COLUMN IF EXISTS link_telegram,
  DROP COLUMN IF EXISTS link_x;
```
