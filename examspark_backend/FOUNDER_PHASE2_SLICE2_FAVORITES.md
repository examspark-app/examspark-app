# Founder — Phase 2 Slice 2: Library Favorites

**Start phrase:** `start phase 2 slice 2`  
**Date:** Jul 26, 2026

## What you get

| Item | Behavior |
|------|----------|
| Star on lecture card | Tap star → pin / unpin |
| **Favorites** section | Top of Library (when ≥1 favorited) |
| Folders / Recent | Unchanged |
| Auth / Record / FastAPI | **Not touched** |

## Manual setup (required)

1. Supabase → **SQL Editor** → New query  
2. Open: `examspark_backend/library_favorites_migration.sql`  
3. Copy all → Paste → **Run**  
4. Flutter **hot restart**  
5. Library tab → star a lecture → see **FAVORITES** section  

**.env:** none.

## Smoke

1. Library → star on a lecture → filled star  
2. Pull refresh → still favorited  
3. Tap star again → leaves Favorites list  
4. Open folder → star still works  
5. Tap card (not star) → Study Workspace opens  

## Next slices

| Say | Work |
|-----|------|
| `start phase 2 slice 3` | Home top **Search** (real) |
| `start phase 2 slice 4` | Teacher Progress / polish (UI only) |

## Rollback

```sql
ALTER TABLE public.lectures DROP COLUMN IF EXISTS is_favorite;
DROP INDEX IF EXISTS idx_lectures_user_favorite;
```

## Files

- SQL: `library_favorites_migration.sql`
- Flutter: `library_tab.dart`, `lecture_card.dart`, `lecture_service.dart`
