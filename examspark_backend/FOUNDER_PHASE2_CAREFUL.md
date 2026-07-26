# Founder — Phase 2 careful (Slice 1)

**Date:** Jul 26, 2026  
**Honest status:** Full Phase 2 shell (5 tabs + StudyWorkspace) was **already built**. This is a **gap pass**, not rebuild.

## Slice 1 done (UI only)

| Item | Status |
|------|--------|
| Profile → **Settings** real screen | Done — notify toggles + **desktop browser alerts** (web) |
| Profile → **Help** FAQ screen | Done — static FAQ |
| Auth / Login / FastAPI / SQL | **Not touched** |
| Storage row | **Not restored** — Delete account stays |
| Save original audio | **Removed** (cancelled with R2 meter) |

## Cancelled (founder Jul 26)

- Save-audio **server** wiring  
- R2 Storage MB meter  

## Still pending (Settings extras)

- Theme picker · language · about → say `start settings extras`

## Manual setup

1. Hot restart Flutter  
2. **No SQL · no .env**

## Smoke

1. Profile → Settings → toggles flip · back  
2. If teacher: Save original audio OFF by default · toggle saves local note  
3. Profile → Help → open 2 FAQs  
4. Logout still works  

## Next slices (say `start phase 2 slice …`)

| Slice | Gap | Status |
|-------|-----|--------|
| 2 | Library **Favorites** | **Done** — [`FOUNDER_PHASE2_SLICE2_FAVORITES.md`](FOUNDER_PHASE2_SLICE2_FAVORITES.md) · SQL `library_favorites_migration.sql` |
| 3 | Home top **Search** (real, not Coming soon) | **Done** — [`FOUNDER_PHASE2_SLICE3_SEARCH.md`](FOUNDER_PHASE2_SLICE3_SEARCH.md) · no SQL |
| 4 | Teacher Progress / Dashboard placeholder polish (UI only) | Next |

**Do not** start full redesign / auth rewrite without naming it + Sonnet for big multi-file.
