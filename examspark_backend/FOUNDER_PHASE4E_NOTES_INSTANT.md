# Phase 4E — Notes Instant Open Optimization (Founder Lock)

**Status:** Locked Jul 18, 2026 — implement in slices  
**Goal:** Saved notes open **&lt;300ms** on repeat; never full-screen spinner when cache exists.

## Priority

| Slice | What |
|-------|------|
| **P0** | Memory + SharedPreferences cache; open-first sync-later; sticky error fix |
| **P1** | Lazy load Quiz/Flashcards/Revision only when tab opens |
| **P2** | Preload last 10 notes after login |
| **P3** | Batch notes API (1 round-trip) |
| **P4–P5** | Markdown pre-render + skeleton UI |

## Cache ladder (never AI)

Memory → Local prefs/SQLite → Supabase → R2 → AI never

## Credits / AI

Restore from cache = **0 credits**. No regenerate on open.

## Related bugs fixed with P0

- Sticky `notesError` cache blocking reopen
- Library history duplicate titles (display dedupe + create reuse)
