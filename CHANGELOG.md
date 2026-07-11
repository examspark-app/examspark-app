# ExamSpark — Changelog

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)
> **Format:** Date · What changed · Trigger / phase

---

## Jul 2026

### Phase 1 — LOCKED (founder approval)

- Founder declared Phase 1 **LOCKED** Jul 11, 2026
- Locked: Product Vision, IA, Navigation, UX, Components, Rules, Storage, AI Flow, Credits, Teacher/Student flows
- **Rule:** No further Phase 1 doc edits without founder approval
- Phase 2 still blocked until founder says "Phase 2 shuru karo"

### Permanent Development Workflow (founder Jul 11, 2026)

- Added [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) — official phases 1A–6, model strategy, Sonnet budget
- Added `.cursor/rules/examspark-development-workflow.mdc` — always-on
- **New phase split:** 1A LOCKED · **1B wireframes NEXT** · Phase 2 blocked until 1B approved
- Phases 3–6 added (UI polish, architecture, backend, final polish)
- Permanent unless founder says "Update Development Workflow"

### Additional Permanent Development Rules (founder Jul 11, 2026)

- `PROJECT_WORKING_RULES.md` §13 — manual setup guide, .env rules, feature completion report
- Every code change must end with Manual Setup Checklist + .env Checklist
- Never hide manual work; never auto-delete files; non-developer explanations mandatory

### Pre-Phase 2 — Master Documentation (Complete)

- Added [`FEATURES_MASTER.md`](FEATURES_MASTER.md) — every feature by category with status, screen, dependencies
- Added [`DATA_STORAGE_POLICY.md`](DATA_STORAGE_POLICY.md) — temp, R2, Postgres, vector DB (founder-friendly)
- Added [`APP_FLOW.md`](APP_FLOW.md) — full user journey + mermaid flow diagram
- Updated `README.md`, `ARCHITECTURE.md` — index links
- **Gate:** Phase 2 Flutter UI still blocked — waiting for founder approval

### Phase 2 constraint — Auth reuse (founder rule)

- `PROJECT_WORKING_RULES.md` — keep Supabase auth, reuse login, UI-only changes, backend intact
- `PROJECT_ROADMAP.md` — Phase 2 hard rules updated (no auth rewrite)
- `.cursor/rules/examspark-working-rules.mdc` — always-on auth rule

### Phase 1 — IA + Screen Hierarchy (Complete)

- Added [`IA_SCREEN_HIERARCHY.md`](IA_SCREEN_HIERARCHY.md) — every screen in simple language
- Realigned [`PROJECT_ROADMAP.md`](PROJECT_ROADMAP.md) — Sonnet 5 phase workflow (1–5)
- Phase gate: ask founder before Phase 2 Flutter UI
- **Not started:** Supabase, SQL, RAG, payments (by design)

### Project Core Rules

- Added [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) — storage tiers, strict sharing, RAG 4-tier, PYQ, watermark, security
- Updated `TECH_STACK.md`, `TEACHER_PLATFORM.md`, cursor rules

### UX Architecture

- Added [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) — Home chat, Study Workspace hero, 5-tab nav, Library, Groups, Profile
- Study Workspace: desktop split + mobile bottom sheet
- Design process: IA → Nav → Hierarchy → UI

### Product

- Added [`PRD.md`](PRD.md) — full product flow, build order
- Updated [`examspark_frontend/PRODUCT_VISION.md`](examspark_frontend/PRODUCT_VISION.md) — vision filled

### Credit Economy v2

- Updated `CREDIT_ECONOMY.md`, `credit_costs.dart`, `subscription_plans.dart`, backend seeds
- Plans: ₹199 / ₹499 / ₹999 / Teacher; session-based recording costs

### Earlier (scaffold phases 0–5)

- Flutter screens: recorder, processing, notes result, subscription, dashboards
- Supabase schema, edge function interim, payment architecture (no live keys)
- Auth gate, recording services, credit constants v1→v2

---

## How to Log Changes

When completing a task:

1. Add entry here (date + summary)
2. Check off in [`TODO.md`](TODO.md)
3. Update [`PROJECT_ROADMAP.md`](PROJECT_ROADMAP.md) if phase advances
4. Update feature checkboxes in [`FEATURES.md`](FEATURES.md) if applicable
