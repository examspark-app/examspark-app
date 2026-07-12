# ExamSpark — Features Master List

> **Saved:** Jul 2026 — pre-Phase 2 documentation
> **Audience:** Founder (non-developer) + team
> **Rule:** Status = **actual today** (code audit Jul 2026), not wish-list

**Status legend:**

| Label | Simple meaning |
|-------|----------------|
| **Done** | Works in app (may need Supabase setup) |
| **Partial** | Some code exists; incomplete or old design |
| **UI Only** | Screen looks real; fake data or no backend |
| **Docs Only** | Saved in documents; no app code yet |
| **Future** | Planned later |

**Companion:** [`IA_SCREEN_HIERARCHY.md`](IA_SCREEN_HIERARCHY.md) · [`PRD.md`](PRD.md) · [`APP_FLOW.md`](APP_FLOW.md)

---

## Student Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Email login** | Student signs in with email + password | Partial | Login | Supabase Auth, `users` table |
| **Email signup** | Create new account | Partial | Login | Supabase Auth |
| **One free Ask AI (guest)** | Try AI once before account | Docs Only | Home | Anonymous session, signup gate modal |
| **Ask AI (global)** | Type question on Home; general AI chat | Partial | Home (old sidebar layout) | Edge function / FastAPI, credits deduct |
| **Ask AI (lecture)** | Question about one lecture only | Partial | Notes Result / Study Workspace (planned) | RAG pipeline, lecture context |
| **View lecture notes** | Read AI-generated notes | Partial | Notes Result | Supabase `notes` + edge function |
| **View transcript** | Re-read teacher explanation text | Partial | Notes Result | Supabase `transcripts`, R2 |
| **View summary** | Short overview of lecture | Partial | Notes Result | Notes pipeline |
| **Flashcards** | Revise with front/back cards | Partial | Notes Result → Extra Actions | Edge function, credits |
| **Quiz / MCQ** | Practice multiple-choice | Partial | Notes Result / Student Portal (demo) | Edge function, credits |
| **Revision notes** | Exam-focused recap | Partial | Notes Result | Edge function, credits |
| **Important questions** | Long-answer prep list | Docs Only | Study Workspace `+` menu | AI pipeline |
| **YouTube Link → Notes** | Paste public video link (≤1 hr) → Notes/Summary/Flashcards/Quiz | UI Only (icon + paste-link dialog; "coming soon" on submit) | Home bottom bar (icon next to Record) | `youtube-transcript-api` fetch + Qwen 3 Instruct pipeline (Phase 5) |
| **Progress tab** | Study stats, streaks, quiz scores | UI Only | Progress tab | Analytics tables |
| **Library browse** | Find saved lectures by folder | UI Only (real lecture list) | Library tab | Real folder metadata |
| **Search library** | Search titles, subjects | UI Only | Library tab | Server-side search index |
| **Recent lectures** | Quickly reopen last items | Done (real data) | Library tab / Home | — |
| **Favorites** | Pin important lectures | Docs Only | Library | `favorites` metadata |
| **Join group** | Enter code/link to join teacher batch — gated by plan's Group Join Limit (₹199=1, ₹499=3, ₹999=6; Free=0) with a "Buy Plan" prompt if over | UI Only (real limit check, client-side) | Student Portal (old), Groups tab, Group Info | Groups tab, memberships DB; real server-side enforcement Phase 5 |
| **Read group feed** | See teacher shared lectures | UI Only | Student Portal | Real group feed, permissions |
| **Take group quiz** | Interactive MCQ (A/B/C/D) quiz opened from the group feed | UI Only (sample questions; real quiz content from R2 is Phase 5) | Group Info Screen → `MCQQuizView` | Group content access rules, real R2 fetch |
| **Download content** | Save file offline | Docs Only | Group settings | Teacher `Allow downloads` toggle |
| **Share invite link only** | Student shares group join link — never notes/PDF | Docs Only | Groups | Optional 100 credits (future) |
| **Progress / weak topics** | See what to revise | Future | Progress | Analytics |

---

## Teacher Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Record lecture** | Mic capture → AI pipeline. Planned-duration picker (≤30/30–60/60–90 min) with sound+banner warning at threshold (never auto-stops); sound+banner warning on start/stop failure and network/processing errors; auto-save (stop+persist) if a call/app-switch interrupts, with a resume-or-discard prompt on return. Shared by Home tab and Teacher Dashboard. | Partial (real warnings/auto-save; mic capture/edge function still Phase 4/5) | Recorder | Mobile mic; edge function; not on Web record |
| **Upload audio file** | Upload existing recording | Partial | Recorder | File picker, edge function |
| **Upload PDF** | Send PDF into AI pipeline | UI Only | Recorder (document button) | PDF ingest pipeline, plan gating |
| **Upload image** | Photo/diagram analysis | UI Only | Recorder | Qwen3-VL routing, plan gating |
| **Transcription quality** | Turbo vs high-accuracy Whisper | Partial | Recorder setup | Auto-fallback in pipeline |
| **Recording source restriction** | Only real mic recordings (`source_type = 'recorded'`) are eligible to Share to Group — uploaded audio/PDF/photo stay personal-only (fake-teacher prevention) | UI Only (real `lectures.source_type` tracking + gating) | Recorder, Study Workspace | — |
| **Create group** | New class/batch | UI Only | Teacher Dashboard | `class_folders` DB write |
| **Rename / delete group** | Manage batches | Docs Only | Groups management | Backend CRUD |
| **Share to group** | Teacher shares one of their own real-recorded lectures (as Lecture/Notes/Quiz) into a group's feed | UI Only (real `group_shared_items` insert; picks group + content type) | Study Workspace → "Share to Group" | Groups feed + permissions |
| **Pin post** | Keep important item on top | Docs Only | Group feed | Feed metadata |
| **Share announcement** | Text announcement to class | Docs Only | Group feed | Broadcast model |
| **Teacher name + photo visible** | Trust on group feed | Docs Only | Group feed | Profile metadata |
| **Group description** | Explain what batch is about | Docs Only | Group detail | Groups table |
| **Allow downloads toggle** | Let students download or not | Docs Only | Group settings | Permission enforcement |
| **Watermark shared content** | `Shared by Teacher • Group` on views | Docs Only | Study Workspace / export | Render layer + `lecture_id` |
| **Save Original Audio** | Opt-in keep raw audio | Docs Only | Settings (teacher) | R2 audio path, default OFF |
| **Teacher Dashboard** | Business cards: students, revenue… | UI Only | Teacher Dashboard | Analytics APIs, payment data |
| **Teacher public profile** | Photo, name, subject, bio, qualification, experience, certificates, verification, stats — editable | UI Only (placeholder data) | Teacher Dashboard (top card + edit sheet) | Supabase `teacher_profiles` table, R2 photo/certificate storage |
| **Certificate upload & verification** | Teacher uploads a certificate image → saved with "Pending Review" status; rejected certs show "Contact Support" | UI Only (real image pick + Postgres save of title/status; real/fake AI check is Phase 5) | Teacher Dashboard → Edit Profile sheet | AI real/fake document check, R2 image storage |
| **Student list** | See who joined batch | Docs Only | Dashboard → Students | Memberships query |
| **Today's lectures** | Quick link to recent content | Docs Only | Dashboard | Lecture metadata |
| **Subscribers / revenue** | Coaching business metrics | Docs Only | Dashboard | Payment tables (live) |

---

## AI Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Speech-to-text (Whisper)** | Audio → transcript | Partial | Processing (auto) | Groq API, temp audio delete |
| **Auto Whisper fallback** | Poor audio → non-turbo retry | Docs Only | Pipeline (silent) | Quality detection logic |
| **Clean transcript** | Remove fillers for search | Docs Only | Pipeline | Qwen cleanup step |
| **Notes generation** | Structured notes from transcript | Partial | Notes Result | Qwen3 Instruct |
| **Summary generation** | Short overview | Partial | Notes Result | Same pipeline |
| **Flashcard generation** | AI creates cards | Partial | Notes Result extras | Edge function, credits |
| **Quiz generation** | 20 MCQ style | Partial | Notes Result extras | Edge function, credits |
| **Revision generation** | Exam recap | Partial | Notes Result extras | Edge function, credits |
| **Formula sheet** | Extract formulas | Future | Study Workspace `+` | AI pipeline |
| **Mind map** | Visual concept map | Future | Study Workspace `+` | AI pipeline |
| **Translate** | Translate content | Future | Study Workspace `+` | AI pipeline |
| **Voice read (TTS)** | Read notes aloud | Future | Study Workspace `+` | TTS service |
| **Diagram / image (Qwen3-VL)** | Handwriting, charts | Partial | Pipeline routing | Vision model |
| **PDF text extract** | PDF → notes path | Docs Only | Attachment flow | PDF pipeline |
| **OCR image** | Image text extract | Docs Only | Attachment flow | OCR step |
| **RAG — Notes first** | Answer from user notes | Partial | Ask AI | pgvector chunks |
| **RAG — Transcript backup** | Clean transcript chunks | Docs Only | Ask AI | Clean transcript index |
| **RAG — Teacher shared** | Group content in answers | Docs Only | Ask AI | Shared notes index |
| **RAG — Web search** | Tavily when local weak | Docs Only | Ask AI | Tavily API |
| **PYQ exam tags** | "Related: NEET 2024" only | Docs Only | Notes display | PYQ mapping DB; never show Q/A |
| **Credit deduct per action** | Server charges credits | Partial | All AI actions | Server enforcement v2 costs |
| **Plan tier gating** | Block feature by plan | Docs Only | Modals | `plan_tier_gating.dart` wire-up |

---

## Groups Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Group list** | Study Community batch list — teacher photo, name, subject, verified badge, qualification, students count, join button | UI Only (placeholder data) | Groups List Screen | Real DB groups |
| **Group Information screen** | Teacher profile header + group info + achievements + recent content + suggested teachers (WhatsApp-inspired, own design) | UI Only (placeholder data) | Group Info Screen | `GroupModel`/`TeacherProfileModel` → Supabase |
| **Join / Leave group** | Toggle membership, no chat/messaging | UI Only (local mock state) | Group Info Screen, Group card | `group_memberships` table |
| **Suggested teachers** | Horizontal discovery cards below Group Info | UI Only (placeholder data) | Group Info Screen | `SuggestedTeacherModel` → Supabase |
| **Group feed** | Broadcast cards, no chat | UI Only | Student Portal | Feed API |
| **Pinned items** | Top of feed | Docs Only | Group feed | Pin metadata |
| **No student messages** | Read-only for students | Docs Only | Group feed | No input UI + server block |
| **No student uploads** | Teacher only uploads | Docs Only | Entire groups | Permission checks |
| **Join before share rule** | Old members get content immediately | Docs Only | Backend | `class_memberships` + `shared_at` |
| **Join after share rule** | New members only see future shares | Docs Only | Backend | Access logic |
| **Expired subscription** | Read-only or locked | Docs Only | Backend | Subscription status |
| **Invite link (student)** | Share join link only | Docs Only | Groups | Optional credit cost |
| **Strict no content share** | Students cannot forward notes/PDF | Docs Only | Entire app | OS copy block where possible |
| **Group join limits** | Plan-based cap on how many Groups a student may join (₹199=1, ₹499=3, ₹999=6, Free=0); "Buy Plan" sheet shown when over the limit | UI Only (real client-side check via `fn_user_plan_tier` + `class_memberships` count) | Groups tab/list, Group Info, Join-by-code dialog | Real server-side enforcement (Phase 5) |
| **Invite link only (Teacher Dashboard)** | "Copy Code" removed — "Share Invite Link" (`examspark.app/join/{joinCode}`) is the only invite path, matching Group Info's Share Group button | Done | Teacher Dashboard | — |

---

## Library Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Auto-save every lecture** | No manual Save button | Partial | Pipeline → DB | Lecture + notes insert |
| **One entry per lecture** | Transcript, notes, quiz in one place | Partial | Notes Result | Library metadata model |
| **Subject folders** | Physics, Chemistry… | UI Only | Library tab | Real folder CRUD (grouped by `subject` field for now) |
| **Folder drill-down** | Lectures inside subject | Docs Only | Library | Navigation into folder detail |
| **Global search** | Find any lecture | UI Only (client-side filter) | Library tab | Server-side search index |
| **Recent** | Last opened | Done (real data) | Library tab | — |
| **Favorites** | Starred lectures | Docs Only | Library | Favorites flag (no DB column yet) |
| **Open → Study Workspace** | One lecture, all tabs | UI Only | StudyWorkspace | Real content wiring |
| **Library size in Profile** | How many lectures / GB | UI Only (placeholder number) | Profile tab | Storage aggregation |
| **Private library** | Other users cannot search yours | Docs Only | Backend | RLS / auth |

---

## Credits Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Credits balance display** | Show remaining credits | Partial | Home sidebar, Subscription (fake nums) | `users.credits_balance` |
| **Credits pill (top bar)** | Quick glance on Home | Done (real data) | Home top bar (`CreditsPill`) | — |
| **Session-based costs** | Per feature, not per minute | Docs Only | AI action buttons | `credit_costs.dart` enforced server-side |
| **Recording buckets** | ≤30m / 30–60m / 60–90m costs | Docs Only | Recorder / inline card | Duration detection |
| **Insufficient credits modal** | Upgrade or buy pack | Docs Only | Modal | Balance check API |
| **Credit history** | See past usage | Docs Only | Profile → Credits | `credit_transactions` |
| **Server-only deduct** | Never trust app for math | Partial | Backend | Edge function / FastAPI |
| **Never show ₹ for AI** | Credits only in UI | Docs Only | Entire app | Copy rules |
| **Invite link credit cost** | 100 credits optional | Future | Groups | Config flag |

**v2 costs saved:** See [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md)

---

## Subscription Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Free plan** | Ask AI only; no record/upload | Docs Only | Plans | Plan gating enforcement |
| **₹199 plan** | PDF, image, study features | Docs Only | Subscription | Razorpay / Play Billing |
| **₹499 plan** | + Audio recording | Docs Only | Subscription | Plan gating |
| **₹999 plan** | Full access | Docs Only | Subscription | Plan gating |
| **Teacher ₹1,999** | Bulk + dashboard + groups | Docs Only | Subscription | B2B plan |
| **Plan comparison UI** | See features per tier | Partial | Subscription | Real plan data from DB |
| **Upgrade flow** | Buy higher plan | UI Only | Subscription | Payment gateways (all TODO) |
| **Credit packs** | One-time top-up | Docs Only | Subscription | `credit_packs` table |
| **Renewal date** | When plan renews | UI Only | Subscription (hardcoded date) | Subscription DB |
| **Profile → Subscription row** | Manage plan | Done | Profile tab | — |

---

## Future Features

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **Mind Map** | Visual concept map | Future | Study Workspace | AI + renderer |
| **Formula Sheet** | Dedicated formula doc | Future | Study Workspace | AI pipeline |
| **Translate** | Multi-language content | Future | Study Workspace | Translation API |
| **Voice Read** | Text-to-speech | Future | Study Workspace | TTS |
| **Hindi UI** | App in Hindi | Future | Entire app | i18n |
| **iOS App Store** | iPhone release | Future | iOS build | Apple Developer account |
| **Institute admin role** | Multi-teacher coaching | Future | Admin portal | Role system |
| **Offline flashcards** | Download for offline | Future | Library | Local cache |
| **NCERT / books RAG** | Licensed book content | Future | RAG | Licensing |
| **PYQ deep mapping** | Richer exam tags | Future | Notes | PYQ DB (tags only) |
| **Important Questions tab** | Dedicated tab | Future | Study Workspace | AI generation |
| **Notifications push** | "Notes ready" alerts | Future | Home bell | FCM / web push |

---

## Platform & Shell (cross-cutting)

| Feature | Description | Status | Screen | Future dependencies |
|---------|-------------|--------|--------|---------------------|
| **5-tab bottom nav** | Home · Library · Groups · Progress · Profile | UI Only | AppShell | Real per-tab backend data (Phase 4/5) |
| **ChatGPT-style Home** | Center chat + bottom input | UI Only | Home tab | Ask AI backend (Phase 4/5) |
| **Study Workspace widget** | Shared lecture tabs | UI Only | StudyWorkspace | Real Notes/Summary/Transcript/Flashcards/Quiz/Revision/Ask AI content (Phase 4/5) |
| **Desktop split pane** | Chat left, study right | UI Only | AppShell + StudyWorkspaceSidePanel | Wired — placeholder content only |
| **Mobile bottom sheet** | Study tabs slide up | UI Only | StudyWorkspace | Wired — placeholder content only |
| **Dark mode** | System light/dark | Partial | Entire app | Theme exists; polish Phase 3 |
| **Supabase Auth** | Login system | Partial | Login | `.env` configured |
| **FastAPI backend** | Target API server | UI Only | — | Phase 5; all routes TODO |
| **Cloudflare R2** | File storage | Docs Only | — | Phase 5; buckets manual |
| **Admin payment screens** | Internal admin UI | UI Only | Admin routes | FastAPI admin API |

---

## Summary counts (approximate)

| Status | Count |
|--------|-------|
| Docs Only | ~55 features (designed, not built to new spec) |
| Partial | ~20 features (old scaffold, some work) |
| UI Only | ~10 features (fake/demo data) |
| Future | ~12 features |

**New UX (Phase 2 target):** ~80% of student/teacher daily flow is **Docs Only** until Flutter UI ships.

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | FEATURES_MASTER.md created — pre-Phase 2 |
| Jul 12, 2026 | Added YouTube Link → Notes (founder-locked pricing/limits; Flutter icon + dialog built, backend pending Phase 5) |
| Jul 12, 2026 | Teacher/Groups refinement: recording source-type restriction (only real mic recordings shareable), real certificate upload UI (Pending Review), Group Join Limits + Buy Plan sheet, removed Copy Code, interactive quiz in group feed, recorder duration warnings + call-interruption auto-save |
