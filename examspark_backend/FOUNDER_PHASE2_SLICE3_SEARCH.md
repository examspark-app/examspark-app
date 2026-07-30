# Founder — Phase 2 Slice 3: Home Search (universal)

**Start phrase:** `start phase 2 slice 3`  
**Date:** Jul 26, 2026

## What you get

| Item | Behavior |
|------|----------|
| 🔍 Home / Library / Groups | Opens real search overlay (not “Coming soon”) |
| **Lectures** | Title / subject / topic match → Study Workspace |
| **Groups** | Joined or your teacher groups → Group Info |
| Auth / FastAPI / SQL | **Not touched** |

Empty query = recent-ish list (first 12 each). Type to filter.

## Manual setup

1. Flutter **hot restart**  
2. **No SQL · no .env**

## Smoke

1. Home → 🔍 → type lecture title → tap → workspace opens  
2. Type a group name → tap → Group Info  
3. Library / Groups top bar 🔍 same overlay  
4. No match → “No results…”  

## Next

| Say | Work |
|-----|------|
| `start phase 2 slice 4` | Teacher Progress / placeholder polish (UI only) |
| `start FCM` | Real push (after smoke) |

## Files

- `examspark_frontend/lib/presentation/screens/search/search_overlay_screen.dart`
- Wired: `home_tab.dart`, `library_tab.dart`, `groups_tab.dart`
