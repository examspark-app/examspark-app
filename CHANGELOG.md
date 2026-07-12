# ExamSpark — Changelog

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)
> **Format:** Date · What changed · Trigger / phase

---

## Jul 2026

### AI Pipeline Cost Strategy locked into docs (founder Jul 12, 2026)

Follow-up founder discussion after the Teacher Commission session below — no new code (no FastAPI/Phase 5 backend exists yet), but the confirmed AI-pipeline decision tree and free-tier economics are now locked into docs so Phase 5 has an exact spec to build against:

- **Speech decision tree** ([`TECH_STACK.md`](TECH_STACK.md) §AI Models): Groq Whisper Large v3 **Turbo** ($0.04/hr) is the default for every recording. If audio is noisy, a noise-cancellation preprocessing pass runs first. If Turbo still returns low confidence (`avg_logprob`/`no_speech_prob`) or errors, auto-fallback to Whisper Large v3 **non-turbo** ($0.111/hr). A cross-talk/random-voice detection step is locked as a Phase 5 diarization requirement (not built) so Notes generation can exclude background chatter/other students' voices from the main lecture content
- **Vision escalation rule:** Qwen3-VL-**Flash** ($0.05/M in, $0.40/M out) stays the default for every Diagram/Image/Math action; escalate to Qwen3-VL-**Plus** ($0.20/M in, $1.60/M out) only when Flash's output is low-confidence/unparseable (complex multi-step math, unclear diagrams) — escalation is the rare exception, not the default path
- **Free tier widened:** PDF Analysis (text-only) moved from ₹199 into Free — real cost is only ~₹0.10–0.20/use with no vision model involved. Free credits bumped **50 → 75/month** (real-cost check: ~₹0.35–0.45/user/month worst case — negligible at scale). Confirmed **monthly**, not daily, reset — a daily reset was modeled and rejected (~30x higher worst-case free-tier cost, ~₹10–13/user/month, for zero revenue)
- **Non-API Actions (Always Free)** codified in [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md): re-reading already-generated Notes/Summary/Transcript/Flashcards/Quiz in Library, browsing Group feed/Progress/Profile, and selecting text — only tapping "Ask AI" and sending costs credits
- **Teacher credits (20,000) validated, unchanged:** a heavy teacher (~20 hrs lecture/month + extras) only uses ~3,000–4,000 credits (~₹90–150 real cost vs ₹1,999 charged) — the 5x headroom is intentional "never run out" positioning for a paying B2B customer, not a cost risk
- **Margin Validation table recomputed** with real Groq/Qwen pricing (was rough estimates) — actual margins came in higher than originally estimated (e.g. Ask AI Normal ~96% vs the old ~80% guess), confirming current credit pricing is safe to keep as-is
- Audio chunking (10–15 min chunks), Ask AI prompt length (~800–1,000 words normal / ~2,000 deep), and RAG-embeds-both-Notes-and-Clean-Transcript were discussed and confirmed as already-correct existing behavior — no doc change needed for those
- Nothing here changes actual pipeline code — Whisper/Qwen API calls, noise-cancellation, and diarization remain unbuilt Phase 5 FastAPI work; today's change is `TECH_STACK.md` + `CREDIT_ECONOMY.md` documentation only

### Teacher Commission + Select-Text-Ask-AI (founder Jul 12, 2026)

Founder discussion on AI cost/profit strategy → two locked decisions + two shipped features:

- **Teacher Commission (30% recurring):** any Group member with an active paid plan (₹199/₹499/₹999) earns their **primary teacher** — the teacher whose Group they most recently joined (`class_memberships.joined_at`) — 30% of that subscription, every month, for as long as both stay active. Attribution rule exists so a student in multiple teachers' Groups doesn't get double-charged against the platform's own margin. Full formula + margin-after-commission math: [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) §Teacher Commission; dashboard card spec: [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md)
- DB: new `examspark_backend/teacher_commission_migration.sql` — `teacher_profiles.commission_rate` (default `0.30`) + `fn_teacher_estimated_commission(p_teacher_id)` (primary-teacher attribution via `ROW_NUMBER()` over `class_memberships.joined_at`, summed against `user_subscriptions`/`subscription_plans`). **Display-only** — no real payout wiring (stays Phase 5). `schema.sql` updated to match
- `groups_repository.dart` — new `fetchEstimatedCommission()` (RPC call, safe fallback to `0`); `teacher_dashboard_screen.dart` — new "Estimated Commission" card
- **Select text → Ask AI:** new `ask_ai_selectable_text.dart` — a `SelectableText` wrapper whose `contextMenuBuilder` adds an "Ask AI" button next to Copy/Select All. Wired into `notes_result_screen.dart` (Summary/Key Points/Clean Notes/Important Terms) and the Group shared-content viewer in `group_info_screen.dart`. Tapping it opens the existing `RAGChatModal` (now accepts an `initialQuery`) pre-filled with the selected snippet — reuses the existing Ask AI credit costs (5/12 credits) and the existing `process-lecture` `rag` action, no new backend call
- AI routing strategy (Groq Whisper Turbo → non-turbo fallback → Qwen 3 Instruct → Qwen3-VL for diagrams/math) and RAG priority order were confirmed unchanged — already locked in [`TECH_STACK.md`](TECH_STACK.md)

### Teacher Dashboard & Groups refinement (founder Jul 12, 2026)

UI + Postgres metadata for a batch of founder-requested fixes. Everything below is Flutter UI + client-side logic only — real server-side enforcement (RLS blocking joins over the limit, AI certificate check, etc.) is explicitly Phase 5, per the founder's "UI now, backend later" instruction this session.

- **Recording source restriction (fake-teacher prevention):** `lectures.source_type` (`'recorded'` / `'uploaded_audio'` / `'uploaded_document'`) now tracked on every lecture created from `recorder_screen.dart`. `study_workspace.dart` only shows a **"Share to Group"** action when the lecture is the caller's own AND `source_type == 'recorded'` — uploaded audio/PDF/photo lectures stay personal-only, so a teacher account can't pass off an upload as their own live teaching
- **Share to Group:** new `share_to_group_sheet.dart` — pick a content type (Lecture/Notes/Quiz) + which group, then `ClassService.shareItemToGroup()` inserts a real `group_shared_items` row
- **Certificate upload UI:** `teacher_profile_edit_sheet.dart` now really picks an image (`file_picker`) and titles it via a small dialog, instead of a "coming later" snackbar. Saved certs show a **"Pending Review"** status; a `rejected` status (set manually until Phase 5's AI check exists) shows **"Needs Review — Contact Support"** with a tap-through info dialog. `teacher_certificate_model.dart` gained a `status` field; `groups_repository.dart`'s `updateOwnTeacherProfile()` now actually persists certificates to `teacher_certificates` (previously silently dropped — profile save only touched `teacher_profiles`)
- **Group Join Limits:** founder-locked caps — Free=0, ₹199=1, ₹499=3, ₹999=6, Teacher=unlimited. New `SubscriptionPlanDef.maxGroups` + `GroupsRepository.canJoinAnotherGroup()` (reads `fn_user_plan_tier()` + counts `class_memberships`), wired into all 3 join entry points (Groups tab/list card, Group Info screen, "Join a Class" code dialog) via a new `buy_plan_sheet.dart` shown instead of letting an over-the-limit join through
- **Removed "Copy Code":** Teacher Dashboard's group card now shows only a full-width "Share Invite Link" button (`examspark.app/join/{joinCode}`) — matches the format `group_info_screen.dart`'s "Share Group" now also uses (was previously a mismatched `group.id` UUID)
- **Interactive quiz in group feed:** tapping a `quiz` item in Group Info's "Recent Shared Content" opens the existing `MCQQuizView` (A/B/C/D selection) with sample questions in a bottom sheet; other item types (notes/lecture/homework/announcement) open a simple read-only preview sheet
- **Recorder warnings + call-interruption auto-save** (shared by Home tab AND Teacher Dashboard — same `recorder_screen.dart`): new "Planned Duration" chip picker (≤30/30–60/60–90 min) on the Setup screen; a sound (`SystemSound.play`) + dismissible banner warns once the planned duration is reached (recording is **never** auto-stopped); sound + red snackbar on start/stop failures; `WidgetsBindingObserver` detects an app-pause/inactive event (e.g. an incoming call) **during** an active recording and immediately stops+saves the audio *before* the interruption, then shows a "Process Now / Discard" recovery dialog when the app resumes; network/processing failures after handoff to `/processing` now mark the lecture `'error'` so `processing_screen.dart`'s existing retry UI (+ a new alert sound) picks it up instead of spinning forever
- DB: new `examspark_backend/teacher_group_features_migration.sql` (run once) — adds `lectures.source_type`, `teacher_certificates.status`, `subscription_plans.max_groups` (+ backfills founder-locked values); `schema.sql` master copy updated to match for future fresh installs
- Docs: [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) (new "Group Join Limits" section), [`FEATURES_MASTER.md`](FEATURES_MASTER.md) (statuses updated for all features above)

### YouTube Link → Notes — icon + paste-link UI (founder Jul 12, 2026)

- New dedicated icon in `bottom_input_bar.dart`, placed **next to the Record icon** (not buried in the "+" Attach sheet) — founder-requested placement so it's immediately visible
- New `youtube_link_dialog.dart` — tapping the icon opens a dialog: paste a link, basic format validation (`youtube.com/watch`, `youtu.be/`, `youtube.com/shorts/`), shows the credit range and the public-video/1-hour rules before submitting
- Wired into `home_tab.dart` (logged-in users — submits to a "coming soon" message, since the fetch/transcribe backend isn't built yet) and `guest_home_screen.dart` (anonymous visitors — routes to the signup prompt like Record/Attach, since it's not part of the one free question)
- **Founder-locked pricing/limits (this session):** 1-hour hard cap, public videos only (private/unlisted/age-restricted/region-locked rejected), credits anchored to founder's **~₹15/hour** figure → 35 / 65 / 100 credits for ≤20 / 20–40 / 40–60 min (cheaper than Recording since there's no Whisper cost — captions come straight from the video). Added to `credit_costs.dart`, [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md), and [`FEATURES_MASTER.md`](FEATURES_MASTER.md)
- **Not built yet (Phase 5, needs founder OK first):** actual link fetch, caption/transcript extraction (`youtube-transcript-api`), and feeding it into the Notes/Summary/Flashcards/Quiz pipeline — today's change is Flutter UI + docs only, no backend call is made

### Guest trial — "Anonymous try → One Ask AI → Sign up" (founder Jul 12, 2026)

- Implements `PRODUCT_VISION.md` Core User Flow #1 (already decided, not new scope): **`AuthGate` now shows a chat screen to logged-out visitors instead of jumping straight to Login**
- New `guest_home_screen.dart` — same Home = Chat Screen layout (top bar, welcome, `BottomInputBar`) as the real `HomeTab`, but for anonymous visitors: type **one** free question, get **one** placeholder AI reply (same "Phase 4/5" placeholder `HomeTab` already used — no new backend needed)
- After that one reply: a thin "Free question used — Sign Up" banner appears, and sending another message (or tapping Attach/Record, which were never part of the free trial) opens a new `signup_prompt_sheet.dart` bottom sheet instead — "Create Free Account" / "I already have an account"
- `login_screen.dart` — new `startInSignUp` flag (opens straight on the Sign Up tab when coming from "Create Free Account"), and now pops itself after a successful login/signup when it was pushed on top of `GuestHomeScreen` (vs. being `AuthGate`'s direct root content) so the app underneath becomes visible
- After signup, the existing Role Selection → Student Onboarding / Teacher Dashboard flow (above) runs exactly as before — this only changes what a **logged-out** visitor sees first
- No credits, no real AI call, no auth logic changed — guest mode is purely a UI/UX addition in front of the existing (placeholder) chat

### Role selection screen — Student vs Teacher choice after signup (founder Jul 12, 2026)

- New `role_selection_screen.dart` — first screen after a new signup: "I'm a Student" / "I'm a Teacher" cards + a "Skip" button, shown before the student profile-details screen
- **Student** → continues straight into the existing `StudentOnboardingScreen` (username/age/education/subjects)
- **Teacher** → flips `users.role` to `'teacher'` (`SupabaseClient.chooseTeacherRole()`), then jumps directly into the **existing** Teacher Dashboard with its **existing** "Edit Teacher Profile" sheet auto-opened — no new/duplicate teacher-profile form was built, per the "single source of truth" rule
- **Skip** → stays a student with defaults, straight into the app (same as skipping inside the student screen)
- `groups_repository.dart` — `fetchOwnTeacherProfile()` now pre-fills a brand-new teacher's own edit sheet with their real name (from signup) instead of the "Mr. Rohan Sharma" mock, which was confusing right after picking "I'm a Teacher"
- `teacher_dashboard_screen.dart` / `app_router.dart` — new `openEditOnLoad` flag (via `/teacher` route args) auto-opens the edit sheet on first arrival
- `profile_tab.dart` — "Teacher Dashboard" row now only shows for users whose `role` is actually `'teacher'`
- New `core/router/app_navigation.dart` (global `navigatorKey`) so the role screen can hand off to `/teacher` right after `AuthGate` switches to `AppShell`

### Student onboarding screen — profile setup after signup (founder Jul 12, 2026)

- New `student_onboarding_screen.dart` — one screen shown right after a student's first login: avatar colour picker, username, age (scroll wheel picker), education level (chips), subjects of interest (multi-select chips), "Skip" button + "Finish Setup"
- Teachers are **not** shown this screen — they already set up their profile from the Teacher Dashboard, so they're marked onboarded immediately on signup
- `auth_gate.dart` now fetches the user's `role`/`onboarding_completed` after login and routes students who haven't onboarded yet to the new screen before `AppShell` — fails open into the app if the row/columns aren't found (e.g. migration not yet run) instead of blocking login
- DB: `examspark_backend/student_onboarding_migration.sql` (run once) — adds `users.username` (unique), `users.avatar_color`, `users.onboarding_completed`, and a new `student_profiles` table (`age`, `education_level`, `subjects[]`) with owner-only RLS; `schema.sql` master copy updated to match for future fresh installs
- New `SupabaseClient.completeStudentOnboarding()` / `skipStudentOnboarding()`
- New shared constants: `core/constants/subjects.dart` (also now reused by `recording_setup_screen.dart` — no more duplicate subject list), `core/constants/education_levels.dart`, `core/constants/avatar_colors.dart`
- New `StudentProfileModel` (`fromMaps`/`toUsersMap`/`toStudentProfileMap`/`copyWith`)

### Auth UI redesign — Login/Sign Up split + password reset (founder Jul 12, 2026)

- `login_screen.dart` rebuilt: segmented Login/Sign Up toggle (old vs new user flow now unmistakable) instead of two stacked buttons, "Forgot password?" link, real Google "G" mark instead of the generic `g_mobiledata` icon
- New `email_verification_screen.dart` — real page shown after sign-up when Supabase requires email confirmation (was previously just a snackbar, looked like nothing happened)
- New `reset_password_screen.dart` + `update_password_screen.dart` — full forgot-password flow (send link → email → set new password)
- `auth_gate.dart` now listens for Supabase's `passwordRecovery` auth event and routes to `UpdatePasswordScreen` instead of dumping the user into the app
- `supabase_client.dart`: added `resetPasswordForEmail()`, `updatePassword()`, `resendSignUpEmail()`, `isPasswordRecoveryEvent()`
- New `google_logo.dart` — brand-colour Google "G" drawn with `CustomPainter`, no image asset/extra package needed
- Auth logic itself untouched (still Supabase `signInWithPassword`/`signUp`/`signInWithOAuth`) — UI/UX restyle only, per Phase 2 auth rule

### Phase 4 — Architecture / Data Layer (founder Jul 11, 2026)

- Full Supabase schema in `examspark_backend/schema.sql`: teacher platform (`teacher_profiles`, `teacher_certificates`, `teacher_achievements`), group system (`class_folders` extended, `group_shared_items`, `class_memberships`), RAG (`rag_documents` with `source_type`/`chunk_hash`/ivfflat index), R2 path columns, payment tables (schema only)
- Postgres functions: `fn_deduct_credits` (server-enforced credits), `fn_user_plan_tier`, `fn_group_item_access` (join-before/after-share rule)
- Row Level Security policies on all sensitive tables
- Flutter wiring: `GroupsRepository` → real Supabase with mock fallback; `ClassService` join/leave/feed; Teacher Dashboard Students/Groups/Credits real data; `SupabaseClient.deductCredits()` RPC
- Model `fromMap`/`toMap` on GroupModel, TeacherProfileModel, certificates, achievements, suggested teachers
- New [`PHASE_4_SUPABASE_SETUP.md`](PHASE_4_SUPABASE_SETUP.md) — founder one-run SQL guide
- No FastAPI, no R2 upload, no live AI pipeline — those remain Phase 5

### FOUNDER_MANUAL_SETUP_GUIDE.md — accounts & paste steps (founder Jul 11, 2026)

- Added [`FOUNDER_MANUAL_SETUP_GUIDE.md`](FOUNDER_MANUAL_SETUP_GUIDE.md) — non-developer guide: kaunsa account banana hai, kya copy karna hai, kis file (`.env`) mein paste karna hai, kab karna hai

### ENV_PASTE_TIMELINE.md — when to paste `.env` keys (founder Jul 11, 2026)

- Added [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md) — simple founder guide: abhi sirf optional Supabase keys; Phase 4 step-by-step; Phase 5 payments later
- Created `examspark_frontend/.env` (Supabase keys only active; Phase 5 keys commented out) and `examspark_backend/.env` (all keys with phase section comments, empty values) — both gitignored
- Linked from `API_SETUP.md`, `README.md`, `TODO.md`, `PROJECT_WORKING_RULES.md`

### Docs + env alignment sync (founder Jul 11, 2026)

- Updated `README.md`, `PROJECT_ROADMAP.md`, `TODO.md`, `PROJECT_WORKING_RULES.md` — phase status now shows Phases 1B–3 complete, Phase 4 next
- `examspark_backend/main.py` — reads `SUPABASE_SERVICE_ROLE_KEY` (falls back to legacy `SUPABASE_KEY`)
- `examspark_frontend/lib/core/config/app_config.dart` — reads `FASTAPI_BASE_URL` (falls back to legacy `API_BASE_URL`)

### API_SETUP.md — environment variable guide (founder Jul 11, 2026)

- Added [`API_SETUP.md`](API_SETUP.md) — single source of truth for every API key / env variable, grouped by phase (1–5)
- Documents where to get each key, what it is used for, and which file to paste it into (Flutter `.env`, backend `.env`, Supabase secrets, Cloudflare)
- Updated [`examspark_frontend/.env.example`](examspark_frontend/.env.example) and [`examspark_backend/.env.example`](examspark_backend/.env.example) to match canonical variable names
- Added root [`.env.example`](.env.example) — master template with all empty variables (founder-specified list)
- Standardized `SUPABASE_SERVICE_ROLE_KEY` (replaces old backend `SUPABASE_KEY` name in docs/templates)
- Rule: never commit `.env`, always commit `.env.example`, one variable name across Flutter / FastAPI / Edge Functions / Cloudflare

### Phase 3 — UI polish pass (founder Jul 11, 2026)

- Founder approved Phase 3 using GPT-5.5 Medium for small UI polish only — no architecture redesign
- `LoginScreen` polish: added autofill hints, keyboard focus flow, drag-to-dismiss keyboard behavior, password visibility tooltip, logo semantics, and cleaner button/loading formatting. Supabase login/signup logic remained untouched.
- `TeacherDashboardScreen` polish: fixed `_creditBalance` lint by making it final; business metric cards now use a responsive 2/3/4-column grid depending on available width
- Focused analyzer check on polished files passed: `No issues found`
- No backend, Supabase SQL, `.env`, Cloudflare, payments, RAG, or auth logic changes

### Phase 2 — AppShell + 5-tab Flutter UI (founder approved Jul 11, 2026)

- Founder approved Phase 1B wireframes and explicitly requested Phase 2 (Flutter UI), listing: AppShell, 5 bottom tabs, responsive layout, components, theme, dark mode, reusable widgets, animations, Home ChatGPT UI, Study Workspace, Teacher Dashboard, Groups, Library — placeholder data only
- New `AppShell` (`lib/presentation/shell/app_shell.dart`) — single navigation root after login: bottom `NavigationBar` on mobile/tablet, `NavigationRail` on desktop (≥900px). `AuthGate` now shows `AppShell` instead of the old `HomeScreen`; `/home` route updated to match. **Auth logic itself untouched.**
- New shared `StudyWorkspace` widget (`lib/presentation/widgets/study_workspace.dart`) — the core "conversation + Study Workspace" differentiator. 7 tabs (Notes · Summary · Transcript · Flashcards · Quiz · Revision · Ask AI). Opens as a swipe-up bottom sheet on mobile, as a persistent right-side split panel on desktop (`StudyWorkspaceSidePanel`, animated open/close). Placeholder tab content this pass — does not touch or replace the existing `/notes_result` (`NotesResultScreen`) route, which keeps working exactly as before.
- New reusable widgets (`lib/presentation/widgets/`): `AppTopBar`, `CreditsPill`, `BottomInputBar`, `LectureCard`, `ProfileRow` — shared across all 5 tabs for one consistent visual language
- New `Responsive` breakpoint helper (`lib/core/theme/responsive.dart`) — mobile <600, tablet 600–899, desktop ≥900
- New tabs, all under `lib/presentation/screens/`:
  - `home/home_tab.dart` — ChatGPT-style conversation UI (no sidebar). Credits balance + recent lectures are **real** Supabase/`LectureService` data. General chat replies are placeholder (Ask AI backend not wired yet); mic button still opens the real `/recording_setup` flow
  - `library/library_tab.dart` — Recent + Folders (grouped by subject) using **real** `LectureService.getLecturesForUser()` data — honest empty state instead of fake sample lectures
  - `groups/groups_tab.dart` — same `GroupsRepository` + `GroupCard` as the standalone `/groups` screen, embedded without its own back arrow
  - `progress/progress_tab.dart` — placeholder study stats (streak, study time, quiz score, recent activity)
  - `profile/profile_tab.dart` — Subscription · Credits · Storage · Library Size · Teacher Dashboard · Settings · Help · Logout rows; logout calls real `SupabaseClient.signOut()`
- `flutter analyze` — 0 errors, 0 new warnings (20 pre-existing info/warnings untouched)
- **Phase 2 completion pass (same day):** `LoginScreen` restyled with `AppTheme` (auth logic untouched); `TeacherDashboardScreen` gained business metric cards grid (Students · Subscribers · Revenue · Credits · Storage · Groups · Analytics) — placeholder data only
- `lib/presentation/screens/dashboard/home_screen.dart` is no longer referenced by any route — marked in `TODO.md` for removal, **not deleted** pending founder confirmation
- **Not done this pass (still placeholder/not wired):** general Ask AI chat replies, Study Workspace real content (Notes/Summary/Transcript/Flashcards/Quiz/Revision), Settings screen, Storage/Library Size real numbers, Progress real analytics — all Phase 4/5 backend work

### Phase 1B — Core wireframes completion pass (founder Jul 11, 2026)

- Founder asked for a focused 8-10 core wireframe pass while still covering the requested screen list and popups
- Added [`PHASE_1B_CORE_WIREFRAMES.md`](PHASE_1B_CORE_WIREFRAMES.md) — 22 requested screens + 9 requested popups, grouped into 8 core UX areas
- Includes Mobile + Desktop ASCII wireframes for: Home, Library, Groups, Progress, Profile, Study Workspace, Recording, Upload, Notes, Summary, Flashcards, Quiz, Teacher Dashboard, Teacher Profile, Group Information, Create Group, Subscription, Credits, Settings, Splash, Login, Signup
- Includes popup wireframes for: Join Group, Leave Group, Share, Delete, Report, Plan Locked, Credits Low, Upload Options, Confirmation Dialogs
- Includes Phase 1B Completion Report: total screens, total popups, missing items, UX consistency check, navigation consistency check, founder approval checklist
- No Flutter code, widgets, or navigation implementation were added
- **Gate unchanged:** Phase 2 will not start until founder approval

### Phase 1B — Wireframes v2, full 12-point detail (founder Jul 11, 2026)

- Founder asked to continue Phase 1B with a stricter, complete template: every screen now documents **Purpose · Mobile Wireframe · Desktop Wireframe · Header · Navigation · Main Content · Bottom Navigation · Floating Action Button · Bottom Sheet placement · Popup placement · User Journey · Screen relationships**
- [`WIREFRAMES.md`](WIREFRAMES.md) expanded from 22 → **28 screens/states/popups** — added Search Overlay, Notifications Panel, Help/FAQ, Credits Detail, Storage Detail, Library Size Detail (all referenced in `IA_SCREEN_HIERARCHY.md` Profile rows / header icons but not previously drafted)
- Still ASCII-only — no Dart, no widgets, no navigation code, per Phase 1B rule
- Updated `TODO.md` — screen count corrected to 28
- **Gate unchanged:** Phase 2 (`AppShell`, 5-tab navigation) will NOT start until founder approves `WIREFRAMES.md`

### Phase 1B — Low Fidelity Wireframes v1 drafted (founder Jul 11, 2026)

- Founder chose to strictly follow the permanent workflow: no `AppShell`/Flutter code until Phase 1B wireframes are approved
- Added `WIREFRAMES.md` v1 — 22 screens/states, Mobile + Desktop, ASCII-only low-fidelity wireframes (no Dart, no widgets, no navigation code)
- Covers: Splash, Home (empty + inline study block), Sign Up Gate, Study Workspace, Library (+folder), Groups List, Group Info, Progress (student + teacher), Profile, Teacher Dashboard, Settings, Subscription, Auth, and 6 popups
- Updated `TODO.md`, `PROJECT_ROADMAP.md`, `DEVELOPMENT_WORKFLOW.md` — Phase 1B status → "Draft created, awaiting founder approval"
- **Gate:** Phase 2 (`AppShell`, 5-tab navigation) will NOT start until founder approves this document

### Teacher Profile & Group Information System — fast-tracked (founder Jul 11, 2026)

- Founder explicitly fast-tracked this feature straight to Flutter code (skipped 1B wireframe step for this feature only, per founder's own choice when asked)
- New models: `TeacherProfileModel`, `TeacherCertificateModel`, `TeacherAchievementModel`, `GroupModel` (+ `GroupSharedItem`), `SuggestedTeacherModel` — `lib/core/models/`
- New placeholder repository: `GroupsRepository` (`lib/core/data/groups_repository.dart`) — mock data only, TODO comments mark exact Supabase swap points for Phase 4/5
- New screens: `GroupsListScreen`, `GroupInfoScreen` (`lib/presentation/screens/groups/`) — Study Community pattern, WhatsApp-inspired but not a copy, no chat/messaging
- Teacher Dashboard updated with editable public profile card (`TeacherProfileCard` + `TeacherProfileEditSheet`)
- New routes `/groups`, `/group_info`; temporary entry point added on Home top bar (will move into 5-tab `AppShell` once built)
- Did NOT touch Supabase auth, login, or existing recording/lecture logic
- `flutter analyze`: 0 errors, 0 new lints on all new files

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
