# ExamSpark — Teacher Platform & Student Access

> **Saved:** Jul 2026 — founder `save` (teacher dashboard, access logic, R2 corrections)
> **Status:** Product spec — UI scaffold exists; full business dashboard pending implementation.

---

## 1. Teacher Dashboard (Business Platform)

Teacher ko sirf notes upload nahi — **business dashboard** milna chahiye.

### Dashboard Overview

```text
Today's Active Students
Monthly Active Students
New Students (This Month)
Total Joined Students
Expired Students
Revenue This Month
Estimated Commission
AI Credits Used
Storage Used
Groups Created
Notes Shared
Lecture Hours
Total Ask AI Usage by Students
```

### Business Metrics (Coaching Value)

```text
Today's Revenue
Monthly Revenue
Total Subscribers
New Subscribers
Renewal Rate
Churn Rate
Most Viewed Lecture
Most Asked Topic
Top Performing Batch
```

> Ye coaching teachers ke liye valuable — content share ke saath **batch engagement + subscription health** dikhe. Simple notes app se **teacher business platform** banata hai.

**"Estimated Commission" card (founder-locked Jul 12, 2026):** 30% of the price of every active paid-plan (₹199/₹499/₹999) subscription belonging to a student whose **primary teacher** (most recently joined Group) is this teacher — recurring every month, not one-time. Full formula + margin math: [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) §Teacher Commission. **Display-only today** — computed by `fn_teacher_estimated_commission()`; no real payout/Razorpay wiring until Phase 5 (per "Do Not Build Yet Without Founder OK" below).

---

## 1b. Teacher Setup Gate (founder-locked Jul 25, 2026 — hard order)

**Hard lock (no skip):** full profile → **Get Verified (AI)** → Teacher plan ₹2,999 → Create Group.

### Two different things (do not mix)

| Thing | What it is | Gate? |
|-------|------------|-------|
| **Get Verified** | AI soft verification → Trusted badge | **Yes** — unlocks Teacher plan, then Create Group |
| **Profile certificate PDF/photo** | Optional upload for students if teacher wants to show | **No** — teacher choice only (**Show certificates on profile** ON/OFF, default OFF) |

### Flow (order locked)

1. **Full profile** — Name + Subject (1+) + City + State + Qualification. Red alert while pending. Full-page setup. Multi-subject chips.  
2. **Get Verified (AI)** — Trusted badge → unlocks payment  
3. **Buy Teacher plan ₹2,999** → unlocks Create Group  
4. **Create Group** — only when profile + AI verified + Teacher plan  

Free / non-Teacher / unverified / incomplete profile → Create Group **blocked**. No “Not now” / skip on gate.

### When Teacher ₹2,999 month ends (founder lock **B** — Jul 25, 2026)

| Still allowed | Locked until renew |
|---------------|-------------------|
| Own existing Groups (browse / students / invite link) | **Live Record** |
| Dashboard browse, profile, Get Verified | **New Create Group** |
| Already-joined students keep the group + old shared posts | **Share any Study Workspace** (lecture / notes / quiz / announce / pin) |
| | **Discover / Suggest / Search** — teacher **hidden** from new students |

Students are **not** removed when the teacher’s plan expires. Renew Teacher plan → Record + Create Group + Share + Discover unlock again (setup gate still applies for create).

### Student month-end (same groups, two paths)

| Join path | After 1 month |
|-----------|----------------|
| **Coupon** (free first month) | Stay in group · content **read-only/locked** · upgrade prompt · no kick |
| **Paid** (link/QR + ₹199/499/999) | Tier → Free · **new** joins blocked · memberships trimmed toward Free (0) on plan change · content uses expired access mode |

### Profile fields

| Field | Before Get Verified | Create Group |
|-------|---------------------|--------------|
| **Profile photo** | Recommended | Optional |
| Full Name | **Mandatory** | **Mandatory** |
| Teaching Subject (1+) | **Mandatory** (multi add) | **Mandatory** |
| **City** | **Mandatory** | **Mandatory** |
| **State** | **Mandatory** | **Mandatory** |
| **Qualification** | **Mandatory** | **Mandatory** |
| **Certificate on profile** | Optional (students) — **Show on profile** toggle, default OFF | Optional |
| **Get Verified (AI)** | After profile | **Mandatory** |
| **Teacher plan ₹2,999** | After AI verified | **Mandatory** |
| Experience (years) | Optional | Optional |
| Short Bio | Optional | Optional |
| Social links | Optional (Dashboard) | Optional |

### Not in this gate

- Social links never block Create Group  
- Experience / Bio never block Create Group  
- Profile certificate upload never blocks buy / Create Group  
- **Show certificates on profile** (default OFF) — teacher ON → students see certs on Group Info; OFF → private. SQL: `show_certificates_on_profile_migration.sql`. Not Get Verified.

**Entry:** Profile → Teacher Dashboard (not a 6th bottom tab).  
**Code:** Full-page [`teacher_profile_setup_screen.dart`](examspark_frontend/lib/presentation/screens/dashboard/teacher_profile_setup_screen.dart) · gate [`teacher_setup_gate.dart`](examspark_frontend/lib/core/services/teacher_setup_gate.dart). Guide: [`FOUNDER_TEACHER_SETUP_GATE.md`](examspark_backend/FOUNDER_TEACHER_SETUP_GATE.md). Price SQL: [`teacher_plan_2999_migration.sql`](teacher_plan_2999_migration.sql).

---

## 1c. Teacher Verification v1 — AI Soft Verification (founder-locked Jul 23, 2026)

**Only inside Teacher Dashboard.** Soft skip OK while browsing. **Create Group requires verified** (§1b). Trusted badge = soft AI pass ≥90%. Certificate on file still needed for profile gate; badge needs this soft AI pass.

### Entry

Teacher Dashboard → Profile → **Get Verified**

### Required

At least **one education-related** certificate / proof. Accepted types:

- Teacher Certificate · Teaching License (if applicable) · Board Certificate  
- Degree (B.Ed, D.El.Ed, B.A, B.Sc, M.A, M.Sc, etc.) · Diploma · Training  
- University / College Certificate · Coaching Institute Teacher Certificate  

**Not accepted / never request:** Aadhaar, PAN, Passport, Driving License, or any government identity KYC.

### Soft AI rules (founder Jul 23, 2026)

AI does **soft** verification only — confidence score, no legal KYC, **no manual review queue**.

| Soft OK | Block / fail confidence |
|---------|-------------------------|
| Clear photo **or photocopy (“just copy”)** of a **real** education certificate | **AI-created / generated fake** certificate |
| Normal scan / phone photo of real doc | **Heavy edit / tampering** (name swap, photoshop) |
| Education-related document | **Duplicate** of another teacher’s (or reused) certificate hash |
| Name roughly matches teacher profile | Government ID uploaded as “certificate” |

AI checks (generate **confidence score only**):

1. OCR text extraction · readability  
2. Authenticity confidence (real vs fake / AI-generated)  
3. Name consistency with profile  
4. Education-related classification (reject gov ID)  
5. Subject/category match if possible  
6. Duplicate detection (`certificate_hash`)  
7. Basic tampering / edit detection  
8. **Tavily soft web check** on extracted institution/issuer name (small ± to score only; missing key = skip)  

### Result

| Score | Outcome |
|-------|---------|
| **≥ 90%** | **Trusted Teacher Badge** (verify success) |
| **&lt; 90%** | No badge. Show: *We couldn't verify your certificate automatically. Please upload a clearer education certificate. If you believe this is an error, contact support.* + **Contact Support** button |

### Optional trust links (do **not** affect score)

Personal Website · LinkedIn · YouTube · X · Facebook · Coaching Website  

(Other Dashboard social links e.g. Instagram / WhatsApp / Telegram remain display-only for trust; still **not** part of verification score.)

### Database (store)

`verification_status` · `verification_score` · `certificate_type` · `certificate_subject` · `certificate_hash` · `verification_date` · optional trust links (may reuse `link_*` columns)

### Explicit non-goals

- No manual admin review for badge  
- No government identity verification  
- No legal KYC  
- Badge **only** when AI confidence **≥ 90%**

**Code status:** **Coded** Jul 23 — Get Verified sheet + `POST /api/v1/teachers/verify-certificate` (vision soft + Tavily institution soft) · SQL [`teacher_verification_v1_migration.sql`](examspark_backend/teacher_verification_v1_migration.sql) · [`FOUNDER_TEACHER_VERIFICATION_V1.md`](examspark_backend/FOUNDER_TEACHER_VERIFICATION_V1.md).

---

### Student Analytics (per group)

```text
Group A
  Students: 150
  Active Today: 62
  New This Month: 18
  Expired: 5
  Renewal Due: 12
  Notes Opened: 540
  AI Questions Asked: 2,430
```

---

### Student List

| Column | Purpose |
|--------|---------|
| Name | Student identity |
| Plan | Current subscription |
| Joined | Join date |
| Expires | Subscription end |
| Last Active | Engagement signal |
| Credits Used | AI usage |
| Progress | Learning progress |

Teacher ko exact pata chale:
- Kisne join kiya
- Kisne renew kiya
- Kaun inactive hai
- Kaun top learner hai

---

### Group Analytics

```text
Physics Batch
  250 Students
  145 Active
  32 New
  Average Study Time: 2.8 Hours
  Lecture Completion: 92%
```

---

## 2. Student Access Logic

```text
Teacher uploads Lecture
        ↓
Students who already joined
        ↓
Access immediately
        ↓
New student joins later
        ↓
Gets access only from subscription period
        ↓
Old subscriber
        ↓
Keeps access until expiry
        ↓
After expiry
        ↓
Read-only  OR  Locked  (configurable per business rules)
```

### Rules (configurable)

| Scenario | Default access |
|----------|----------------|
| Joined before lecture share | Immediate full access |
| Joined after lecture share | Access from subscription start only |
| Active subscription | Full access to entitled content |
| Expired subscription | Read-only or locked (founder configures) |

---

## 3. Cloudflare R2 Storage (Corrected)

### Permanently store in R2

```
Transcript
Clean Transcript
Notes
Summary
Flashcards
Quiz
MCQ
Mind Map
Revision Notes
Formula Sheet
PDF
Images
Teacher Files
User Library
Exports
```

### Do NOT store in R2 (default)

```
Raw Audio
```

### Processing flow

```text
Audio
  ↓
Whisper
  ↓
Transcript
  ↓
Delete Audio
  ↓
Save Transcript (R2)
  ↓
Generate Notes
  ↓
Save Notes (R2)
```

**Future optional:** "Save Original Audio" — off by default.

---

## 4. R2 Folder Architecture

```text
Cloudflare R2
├── Users
│
├── Library
│     ├── Transcript
│     ├── Notes
│     ├── Summary
│     ├── Flashcards
│     ├── Quiz
│     ├── Revision
│     ├── MindMap
│     ├── Formula
│     ├── Images
│     └── PDFs
│
├── Teachers
│     ├── Groups
│     ├── Shared Notes
│     ├── Shared PDFs
│     └── Shared Files
│
└── Exports
```

---

## Implementation Notes

- Teacher dashboard: Flutter Web + mobile — same design system
- Analytics data: PostHog + Postgres aggregates; revenue from payment tables
- Access control: server-side — check `class_memberships` + `user_subscriptions` + lecture `shared_at`
- R2 paths mirror folder architecture above; metadata in Supabase Postgres

---

## 5. Groups UX (Study Group — Broadcast Model)

**Saved Jul 2026** — wireframes: [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) § Groups  
**Architecture + Create Flow locked Jul 23, 2026** (founder FOUNDER TASK).

### Hard rules

- This is a **Study Group**, **not** a WhatsApp / chat group
- **No** student messaging, comments, random profile posts, or social feed
- WhatsApp-inspired **list → feed** rhythm only (UI feel) — content is study posts
- Teacher: share notes / quiz / assignment / homework / announcement, pin posts
- Students: read, open Study Workspace, quiz, Ask AI, download if allowed — **no message, no upload**
- Feed card tap → shared `StudyWorkspace`
- Group settings: `☐ Allow downloads` (default OFF)
- Create flow target: **under 60 seconds** — no unnecessary settings

### Architecture (scalable — schools, coaching, tutors)

```text
Teacher account
  └── Multiple Study Groups (unlimited)
        └── ONE primary subject per group
              ├── Separate feed / notes / quizzes / assignments
              ├── Separate student progress
              └── Separate analytics
```

**One subject per group** — do not mix Physics + Biology + History in one group.  
If teacher teaches multiple subjects → create multiple groups.

**Students** may join many groups (plan join caps still apply — [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md)).

**Future only (not now):** organization Folders (e.g. NEET → Biology / Physics / Chemistry) — labels only, not a second group type.

### Profile ↔ Group ↔ Discover sync (locked Option A — Jul 26, 2026)

| Layer | Rule |
|-------|------|
| **Teacher Profile** | Master source: subjects, languages, city/state, class levels, boards/exams — **unlimited** (no max) |
| **Create / Edit Group** | Subject · Class · Board · Language **only from Profile** — no free random values outside Profile |
| **Discover filters** | **City · Subject · Class · Board** (4). Language not in primary filter set. List refreshes when teachers/groups change (Realtime when enabled) |

SQL: [`teacher_profile_class_exam_migration.sql`](examspark_backend/teacher_profile_class_exam_migration.sql) · Guide: [`FOUNDER_DISCOVER_PROFILE_GROUP_SYNC.md`](examspark_backend/FOUNDER_DISCOVER_PROFILE_GROUP_SYNC.md).

### Create Group flow (locked)

Mobile-first bottom sheet or full-screen. Steps:

1. **Basic (required)**  
   - Group Name* (e.g. `NEET Biology Batch A`, `Class 10 Science`)  
   - Subject* — **one** primary — **from Teacher Profile subjects only**

2. **Academic (optional)**  
   - Class / Board / Language — **from Teacher Profile lists only** (add more on Profile first)

3. **Privacy**  
   - **Private (recommended)** — invite code / teacher approval  
   - **Public** — discoverable; join or request

4. **Join methods** (one or more)  
   - Invite Code (e.g. `BIO2026`)  
   - QR Code (auto)  
   - Share Link (auto, e.g. `https://examspark.ai/join/ABCD1234`) — share via WhatsApp / Telegram / Email / Classroom

5. **Student approval** (teacher choice at Create Group time)  
   - Create form **default selection = Auto** (recommended) — teacher may switch to Approve  
   - **Auto** — Free (and anyone allowed by join limits) joins instantly  
   - **Approve** — applies to **Free** only → Pending; see Paid vs Free rule below  
   - Not a forced Free default of Pending or Auto — teacher chooses per group

6. **Create** → system generates Group ID, Invite Code, QR, Share Link

### Paid vs Free — join approval (founder-locked Jul 23, 2026)

Teacher still chooses **Auto / Approve** per Study Group. Enforcement by **student plan**:

| Student plan | If group is **Approve** | If group is **Auto** |
|--------------|-------------------------|----------------------|
| **Free** | Goes to **Pending** → teacher Accept / Reject | Instant join (if plan allows a group — Free max_groups = 0 unless coupon / future institute) |
| **₹199 / ₹499 / ₹999** | **Always Auto join** — **no** Pending, **no** teacher approval gate | Instant join |
| Teacher / institute bulk free join / kick-remove controls | **Future only** — not built now | |

**Does not change** Group Join Limits ([`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md)): Free=0 · ₹199=1 · ₹499=3 · ₹999=6 · Teacher=unlimited.  
Approval skip for paid ≠ unlimited groups.

**Code status:** Rule **saved** + SQL [`paid_auto_skip_pending_migration.sql`](examspark_backend/paid_auto_skip_pending_migration.sql) — founder must run SQL for live skip.

### After creation — per-group teacher view

Members · Pending Requests · Assignments · Quizzes · Notes Shared · Group Analytics  
(Independent per group — not one mixed multi-subject board.)

### Student join paths

Invite Code · QR · Share Link · Teacher Invite

### Implementation slices (build order)

| Slice | Scope | Status |
|-------|--------|--------|
| **v1** | Name* · Subject* · Class/Exam/Language · Private/Public · Create → code + link | **Coded** — SQL: [`create_study_group_v1_migration.sql`](examspark_backend/create_study_group_v1_migration.sql) |
| **v2** | Auto vs Teacher Approval + Pending list | **Coded** — SQL: [`create_study_group_v2_approval_migration.sql`](examspark_backend/create_study_group_v2_approval_migration.sql) · [`FOUNDER_CREATE_GROUP.md`](examspark_backend/FOUNDER_CREATE_GROUP.md) |
| **v3** | QR generate + share sheet | **Coded** Jul 23 — teacher QR on create + Dashboard (**QR** button). In-app student camera scan = later |
| **v4** | Per-group dashboard cards (members, pending, activity) | **Coded** Jul 23 — [`group_dashboard_screen.dart`](examspark_frontend/lib/presentation/screens/groups/group_dashboard_screen.dart) · no new SQL |
| **Analytics v1** | Summary card: Members · Active today · Notes · Quizzes | **Coded** Jul 23 — same screen · no new SQL |
| **Analytics v2** | Members: last active + quiz % (shared lectures in group) | **Coded** Jul 23 — `GET .../teacher/groups/{id}/students` |
| **Analytics v3** | Week / Month toggle (active + quiz %) | **Coded** Jul 23 |
| **Analytics v4** | Top lecture by quiz attempts (week/month) | **Coded** Jul 23 — open-count tracking = future |

DB today: `class_folders` has `name`, `subject`, `join_code`, `is_public`.  
v1+ needs additive columns: `class_level`, `exam`, `language`, `join_approval_mode` (and later pending-requests table).

---

## 6. Dashboard UX (Minimal Cards)

Per [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) § Teacher Dashboard:

**Cards (Jul 26, 2026):** Students · Active today · **Subscribers** (paid + primary teacher) · Est. Commission (30%) · Credits · Groups · Revenue (**Upcoming**) · Analytics (**Upcoming**). **Storage removed** (Profile account delete covers lifecycle).

**Analytics:** per-group summary already on Group open; dashboard Analytics card = upcoming charts.

**No complicated tables** unless necessary — card lists preferred.

Entry: Profile → Teacher Dashboard (not a 6th bottom tab).

---

## 7. Sharing Policy (Strict)

**Only Teacher shares content.** Full rules: [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) §3

### Students CANNOT

Share PDF · Notes · Summary · Transcript · forward files · export · download protected · copy protected content

### Students MAY

**Share Group Invite Link only** — never content.

Future (configurable): Invite link share may cost **100 Credits**. Not enforced until configured.

### Teacher CAN share

Lecture · PDF · Notes · Summary · Assignment · Homework · Quiz · Announcements

---

## 8. Watermark & Traceability

Every teacher-shared asset:

```
Shared by: {Teacher Name} • {Group Name}
```

**Internal metadata:** `lecture_id` · `teacher_id` · `group_id` on every R2 object and shared view.

Enables leak tracing — legal + business protection.

Apply on: student view render · PDF export · shared file delivery.

---

## 9. Teacher Library (reusable content bank — founder Jul 25, 2026)

**Distinct from** personal Library tab (teacher + student personal study — **no Share**).

| Rule | Detail |
|------|--------|
| What it stores | Teacher’s own **recorded** lectures (notes/quiz/flashcards live on that lecture) |
| Where in UI | Teacher Dashboard → **My Library (share bank)** — **only** Share entry point |
| Personal Library / Workspace | Study only — Share button removed (Jul 25, 2026) |
| Re-share | Link same `lecture_id` into another owned group — **free**, no AI regen, no credit charge |
| Duplicate | Same `lecture_id` + same `class_id` blocked (DB unique + API 409 “Already shared here”) |
| Not built | Rate limits / spam scores — group caps + Report button suffice |
| Data model | One lecture row; many `group_shared_items` link rows — **never** copy content |

SQL: [`examspark_backend/teacher_library_share_unique_migration.sql`](examspark_backend/teacher_library_share_unique_migration.sql)  
Founder smoke: [`examspark_backend/FOUNDER_TEACHER_LIBRARY.md`](examspark_backend/FOUNDER_TEACHER_LIBRARY.md)

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Teacher business dashboard spec saved |
| Jul 2026 | Student access logic saved |
| Jul 2026 | R2 storage corrections + folder architecture saved |
| Jul 2026 | Groups broadcast UX + minimal dashboard cards aligned with UX_ARCHITECTURE |
| Jul 2026 | Strict sharing policy + watermark/traceability saved |
| Jul 26, 2026 | **Discover ↔ Profile ↔ Group sync (Option A)** — Profile master (subjects/languages/city/class/board, no max); Group picks from Profile only; Discover filters City·Subject·Class·Board + realtime. SQL: `teacher_profile_class_exam_migration.sql` |
| Jul 25, 2026 | **Suggestion scores** — Subject40/Exam30/City15/Language15 (redistribute if student field missing); Discover sort + `Matches:` badge. SQL: `teacher_suggestion_score_migration.sql` |
| Jul 25, 2026 | **Discover fuzzy (pg_trgm)** — city/state/subject/name typos; threshold 0.35; Language = dropdown on profile + Create Group. SQL: `teacher_discover_fuzzy_trgm_migration.sql` |
| Jul 25, 2026 | **Show certificates on profile** — teacher ON/OFF (default OFF); students see certs only when ON; RLS + UI. SQL: `show_certificates_on_profile_migration.sql` |
| Jul 25, 2026 | Personal Library/Workspace ≠ share bank; Share only Dashboard My Library; unique `(class_id, lecture_id)` |
| Jul 25, 2026 | **Discover/Suggest/Search** — only teachers with **active Teacher ₹2,999**; inactive plan hidden (existing members keep their groups) |
| Jul 25, 2026 | **Teacher plan month-end = B** — lock **Record + new Create Group**; keep existing Groups; students stay |
| Jul 25, 2026 | **Setup lock corrected** — profile → Get Verified (AI) → Teacher ₹2,999 → Create Group; profile cert upload optional for students |
| Jul 25, 2026 | **Teacher setup hard lock** — full profile page (multi-subject, red alert, no skip) → unlock Teacher plan → Get Verified → Create Group |
| Jul 25, 2026 | **Teacher profile photo** — Edit Profile upload → Storage `teacher-photos` → `photo_url`; shows Dashboard / My Groups / Discover / Group Info. SQL: `teacher_photos_storage_migration.sql` |
| Jul 23, 2026 | **Teacher Verification v1 (AI Soft)** — optional Get Verified; education cert only; photocopy OK; fail AI-fake / duplicate / heavy edit; ≥90% Trusted Badge; no KYC / no manual review |
| Jul 23, 2026 | **Teacher Setup Gate** — (superseded Jul 25 hard lock) soft profile → Teacher ₹2,999 → Create Group |
| Jul 23, 2026 | **Join approval: Free → Pending (if Approve); Paid ₹199/499/999 → always Auto skip Pending.** Institute bulk / kick = future. Join caps unchanged. |
| Jul 23, 2026 | **Teacher social / trust links** — optional 8 links on Dashboard; student Group Info icons · SQL `teacher_social_links_migration.sql` |
| Jul 12, 2026 | "Estimated Commission" formula locked — 30% recurring, primary-teacher attribution, display-only (Phase 4) |
