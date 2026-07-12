# ExamSpark — TODO

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)

---

## ✅ Phase 1A — LOCKED 🔒 (founder Jul 11, 2026)

**No further doc edits without founder approval.**

- [x] Product Vision · PRD · IA · Navigation · all flows
- [x] Credits · Storage · Rules · master docs
- [x] `DEVELOPMENT_WORKFLOW.md` — official permanent workflow

**⏸ Phase 5 = NEXT** — ask founder before start.

---

## ✅ API / Environment Setup (COMPLETE — Jul 11, 2026)

- [x] [`API_SETUP.md`](API_SETUP.md) — every env variable by phase
- [x] [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md) — founder guide: kab kaunsi keys paste karni hain
- [x] [`.env.example`](.env.example) — master template (empty values)
- [x] [`examspark_backend/.env.example`](examspark_backend/.env.example) — full server keys
- [x] [`examspark_frontend/.env.example`](examspark_frontend/.env.example) — client-safe keys only
- [x] `examspark_frontend/.env` + `examspark_backend/.env` — created with phase comments (empty values, gitignored)

---

## ✅ Phase 1B — Low Fidelity Wireframes (COMPLETE — Jul 11, 2026)

**Model:** Sonnet 5 High · **No Flutter code**

- [x] Mobile wireframes — every screen (28 screens/states/popups)
- [x] Desktop wireframes — every screen (28 screens/states/popups)
- [x] Full 12-point template per screen (Purpose · Mobile · Desktop · Header · Nav · Content · Bottom nav · FAB · Sheet · Popup · User Journey · Screen relationships) — see [`WIREFRAMES.md`](WIREFRAMES.md)
- [x] Founder-requested core pass — 22 requested screens + 9 requested popups, grouped into 8 core UX areas — see [`PHASE_1B_CORE_WIREFRAMES.md`](PHASE_1B_CORE_WIREFRAMES.md)
- [x] Founder approval before Phase 2 (AppShell + Flutter) — founder gave explicit go-ahead Jul 11, 2026

---

## ✅ Phase 2 — Flutter UI (COMPLETE — Jul 11, 2026)

**Founder rules:** Keep Supabase auth · reuse login · UI only · backend connections intact · never rewrite auth unless asked.

- [x] `AppShell` — 5 bottom tabs (kept `AuthGate`, only swapped destination screen)
- [x] Responsive layout — bottom `NavigationBar` (mobile/tablet) / `NavigationRail` (desktop ≥900px)
- [x] Restyle `LoginScreen` — same `_handleLogin` / `_handleSignUp` logic, AppTheme UI
- [x] Home chat layout (`HomeTab` — top bar, conversation, sticky input; real credits/lecture data)
- [x] `StudyWorkspace` widget — bottom sheet (mobile) / split panel (desktop), 7 tabs, placeholder content
- [x] Library · Groups · Progress · Profile (placeholder where noted; Library/Groups use real data)
- [x] Teacher Dashboard cards — business metric cards (Students, Subscribers, Revenue, Credits, Storage, Groups, Analytics) + class folders
- [x] Theme + dark mode + responsive (reused existing `AppTheme`; added `Responsive` breakpoints)
- [x] Keep `LectureService` + `RecordingService` wired — Library/Home use real Supabase data

---

## ✅ Phase 3 — UI Polish (GPT-5.5 Medium) — complete Jul 11, 2026

- [x] Text, icons, padding, small fixes — no architecture redesign
- [x] Login accessibility polish — autofill, focus flow, password tooltip, logo semantics
- [x] Teacher Dashboard responsive metric grid — 2/3/4 columns by width
- [x] Focused analyzer pass — no issues found in polished files

---

## ✅ Phase 4 — Architecture / Data (COMPLETE — Jul 11, 2026)

**Model:** Sonnet 5 High · Founder manual SQL run required (see [`PHASE_4_SUPABASE_SETUP.md`](PHASE_4_SUPABASE_SETUP.md))

- [x] Supabase SQL schema — `examspark_backend/schema.sql`
- [x] Groups, Teacher Platform, RAG, Credits, RLS policies
- [x] Flutter wiring — GroupsRepository, ClassService, Teacher Dashboard, deductCredits RPC
- [x] [`PHASE_4_SUPABASE_SETUP.md`](PHASE_4_SUPABASE_SETUP.md) founder guide

**Founder must still run SQL in Supabase** — AI guides one step at a time.

### Additional Phase 4 refinements (founder Jul 12, 2026)

- [x] Auth UI redesign (Login/Sign Up toggle, Google icon, forgot password, email verification)
- [x] Student onboarding + Teacher/Student role selection (skip button both)
- [x] Guest "try before signup" flow (one free Ask AI, then signup prompt)
- [x] YouTube Link → Notes — Flutter UI only (icon + dialog); backend fetch/transcribe is Phase 5
- [x] Teacher/Groups refinement — recording source restriction, real certificate upload UI, Group Join Limits + Buy Plan sheet, removed Copy Code, interactive group quiz, recorder duration warnings + call-interruption auto-save
- [ ] **Founder must run** `examspark_backend/teacher_group_features_migration.sql` in Supabase (adds `lectures.source_type`, `teacher_certificates.status`, `subscription_plans.max_groups`)

---

## ⏳ Phase 5 — Backend (NOT YET)

- [ ] FastAPI · APIs · payments · AI pipeline

---

## ⏳ Phase 6 — Final Polish (GPT-5.5 Medium)

- [ ] Testing · cleanup · docs · performance

---

## 🗑 Marked for Removal (confirm first)

| Item | Reason |
|------|--------|
| `/processing` → `/notes_result` navigation | Inline conversation |
| `/teacher`, `/student` top routes | Groups + Profile |
| Home sidebar | Library tab |
| Root `lib/` duplicate | Deprecated |
| `lib/presentation/screens/dashboard/home_screen.dart` | Replaced by `AppShell` + `HomeTab` (Jul 11, 2026) — no longer referenced by any route, kept for now pending founder confirmation |

---

## 💡 Future

See [`FEATURES.md`](FEATURES.md)
