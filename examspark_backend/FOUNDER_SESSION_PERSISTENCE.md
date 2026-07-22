# ExamSpark Session Persistence & Resume (Founder Lock)

**Status:** Core UX Rule — mandatory, all modules  
**Locked:** Jul 18, 2026  
**Not a feature toggle** — default app behavior

---

## Objective

User must never lose work because they minimized the app, switched apps, locked the phone, rotated, or returned after a few minutes.

Restore last active screen + state. No surprise jump to Home. No AI regen. No extra credits.

## Modules

Home AI · Notes Workspace · Ask AI · Library · Lecture/PDF/Image processing · Quiz · Flashcards · Revision · Visual · Mind Map · future study modules

## Rules

1. **Auto-save** on background — screen, tab, scroll, chips, AI responses, drafts, sheets, session, processing  
2. **Auto-restore** on resume — exact prior UI; never re-call AI / never restart notes load / never deduct credits  
3. **Processing** continues when possible; show progress; do not restart from zero  
4. **Cache ladder:** Flutter memory → local prefs/SQLite → Supabase → AI last resort  
5. **Credits:** restore = free  

## Implementation note (Jul 18)

Phase 1 shipped in code: AuthGate ignore same-user auth noise; persist AppShell tab; persist Home AI chat locally; Ask AI visible button on selection (Web). Full scroll/sheet/processing persist continues in follow-ups.

## Success

Minimize without losing work · exact restore · no duplicate API/credits · premium continuous feel
