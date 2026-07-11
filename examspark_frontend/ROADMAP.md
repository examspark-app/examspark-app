# ExamSpark Roadmap

> **Note:** Product vision + UX saved Jul 2026. See [`PRD.md`](../PRD.md) · [`UX_ARCHITECTURE.md`](../UX_ARCHITECTURE.md) · [`PRODUCT_VISION.md`](PRODUCT_VISION.md)

Premium AI learning platform — ChatGPT-simple home + Study Workspace. _(see PRODUCT_VISION.md)_

## Phase 0 — UI Prototype (legacy — pre-UX-architecture)
- [x] Recording Setup screen
- [x] Recorder, Processing, Notes Result screens
- [x] Login, Home, Teacher Dashboard, Student Portal
- [x] Subscription screen with plans
- [x] AppTheme + CreditCosts
- [x] Duplicate screen cleanup

## Phase 1 — Foundation
- [x] Supabase init in `main.dart`
- [x] Routes: `/login`, `/home`, `/recorder`, `/processing`, `/notes_result`, `/subscription`, `/teacher`, `/student`
- [x] RecordingSetup → Recorder navigation with subject/topic args
- [x] `schema.sql` — lectures, notes, transcripts, extras, credit_transactions, class_folders

## Phase 2 — Real Recording
- [x] `record`, `file_picker`, `permission_handler` packages
- [x] `RecordingService` — mic capture + timer
- [x] `LectureService` — create lecture, upload audio, trigger processing
- [x] RecorderScreen wired to real lectureId

## Phase 3 — Notes + AI Extras
- [x] Edge function persists lectures/notes/transcripts with status updates
- [x] `ExtraActionsPanel` wired via callbacks to `NotesResultScreen`
- [x] RAG chat uses edge function

## Phase 4 — Auth + Dashboard
- [x] `AuthGate` — login if no session, else home
- [x] Home lecture history → notes screen
- [x] `ClassService` for teacher/student class data

## Phase 5 — Payment Architecture
- [x] Payment interfaces (Razorpay Web, Google Play Android) — no live keys
- [x] FastAPI payment routes + DB schema
- [x] Admin payment pages (pending)
- [ ] Live Razorpay / Google Play integration
- [ ] Production webhooks

> **Note:** Phases 0–5 are scaffold. **UX Architecture saved** — next phase aligns UI to [`UX_ARCHITECTURE.md`](../UX_ARCHITECTURE.md).

## Phase 6 — UX Shell (next — per saved architecture)
- [ ] 5-tab `AppShell` (Home · Library · Groups · Progress · Profile)
- [ ] Home chat screen (top bar 5 items + bottom input bar)
- [ ] Inline `LectureResultCard` in conversation (no route to notes_result)
- [ ] Reusable `StudyWorkspace` widget (Library + Groups + Home expand)
- [ ] `LibraryScreen` (folders, search, recent, favorites)
- [ ] `GroupsScreen` (broadcast feed, no chat input)
- [ ] `TeacherDashboardScreen` — minimal cards layout
- [ ] Deprecate standalone `/processing` → `/notes_result` navigation pattern

## Run

**Platforms:** Web + Android (ship now) · iOS (structure ready, App Store ~3 months)

```bash
cd examspark_frontend
cp .env.example .env   # fill Supabase URL + anon key
flutter pub get
flutter run
```
