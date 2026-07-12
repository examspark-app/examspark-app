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

## 5. Groups UX (Broadcast Model)

**Saved Jul 2026** — full wireframes: [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) § Groups

- WhatsApp-inspired list + feed — **not** a chat app
- Teacher: upload lecture, share notes/summary/quiz/assignment/homework, pin posts
- Students: read, open notes, quiz, Ask AI, download if allowed — **no message, no upload**
- Feed card tap → shared `StudyWorkspace`
- Group settings: `☐ Allow downloads` (default OFF)

---

## 6. Dashboard UX (Minimal Cards)

Per [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) § Teacher Dashboard:

**Cards:** Students · Monthly Subscribers · New Students · Revenue · Credits Used · Storage · Lecture Hours · Groups

**Analytics:** single summary card (active week, top lecture, quiz %, top group)

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

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Teacher business dashboard spec saved |
| Jul 2026 | Student access logic saved |
| Jul 2026 | R2 storage corrections + folder architecture saved |
| Jul 2026 | Groups broadcast UX + minimal dashboard cards aligned with UX_ARCHITECTURE |
| Jul 2026 | Strict sharing policy + watermark/traceability saved |
| Jul 12, 2026 | "Estimated Commission" formula locked — 30% recurring, primary-teacher attribution, display-only (Phase 4) |
