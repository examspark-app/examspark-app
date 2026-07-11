# ExamSpark — Product Requirement Document (PRD v1)

> **Saved:** Jul 2026 — founder `save all`
> **Scope:** Product Architecture · UX Flow · User Journey
> **Out of scope in this doc:** Backend APIs · Database schema · Credit math · API cost

**Companion docs:** [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) · [`TECH_STACK.md`](TECH_STACK.md) · [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) · [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md)

---

## 1. Product Vision

Premium AI learning platform for India. Students study smarter; teachers record once and reach many; coaching institutes scale without chat chaos.

**Quality bar:** ChatGPT familiarity · Claude trust · Notion organization · Apple simplicity  
**Not:** colorful edu-app · gamified clutter · futuristic gimmicks

**Brand:** White · black/charcoal · one subtle accent · generous whitespace · fast · no decorative animation

**Platforms:** Flutter Android · Flutter Web · Desktop responsive · iOS structure ready (App Store ~3 months)

---

## 2. Target Users

| Persona | Primary need |
|---------|----------------|
| **Student** | Ask AI, revise, quiz, access teacher content |
| **Teacher** | Record lecture → auto notes → share to class |
| **Coaching Institute** | Groups, analytics, subscriber visibility, bulk content |

---

## 3. Core Principles

1. **Try before signup** — one free Ask AI, then elegant signup gate
2. **One input bar** — text, audio, attachments (ChatGPT pattern)
3. **One AI pipeline** — all inputs converge
4. **Library-first** — every output auto-saved
5. **Study Workspace** — conversation + study tabs in one place (hero differentiator vs ChatGPT)
   - Desktop: right panel split pane
   - Mobile: bottom sheet
   - Tabs: Notes · Summary · Transcript · Flashcards · Quiz · Revision · Ask AI
6. **Teacher broadcast, not chat** — groups without spam
7. **PYQ as reference only** — exam tags, never raw PYQ display
8. **Credits-only UX** — users never see rupee amounts for AI actions
9. **30-second clarity** — user understands app immediately; reduce taps; no unnecessary screens

---

## 4. Design Process Order

```
1. Information Architecture
2. Navigation Flow
3. Screen Hierarchy
4. UI (last — never before IA)
```

Full IA + hierarchy: [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) §3–5

---

## 5. User Journey

### Anonymous → First value

```
Open app (no signup) → Home chat → One free Ask AI
→ Answer delivered → Elegant signup popup
→ Sign up → @username, profile, library, history
```

### Student daily loop

```
Home (Ask AI) → Library / Groups → Study Workspace
→ Flashcards, Quiz, Revision → Progress
```

### Teacher content loop

```
Home (Record) → Processing inline in conversation
→ Study cards in thread → Share to Group
→ Teacher Dashboard (cards)
```

---

## 6. Navigation — 5 Tabs Only

```
Home  |  Library  |  Groups  |  Progress  |  Profile
```

**Nothing more.**

| Tab | Student | Teacher |
|-----|---------|---------|
| Home | Ask AI + record | Same + record prominent |
| Library | Own + group content | Own recordings |
| Groups | Joined (read-only feed) | Create, share, pin |
| Progress | Personal stats | Light class snapshot |
| Profile | Subscription, credits, storage | + Teacher Dashboard |

Subscription · Settings · Dashboard — all under Profile, not bottom nav.

### Profile rows

Subscription · Credits · Storage · Library Size · Settings · Help · Logout

---

## 7. Screen List

### Universal
Splash · Home (Chat) · Processing (inline) · Study Workspace · Library · Search · Folders · Favorites · Groups List · Group Feed · Profile · Auth · Sign Up Gate · Onboarding · Plans · Settings

### Teacher-only
Teacher Dashboard · Share Sheet · Group Management · Student List

### Student-only
Revision Hub · Join Group · Progress detail

### Modals
Sign Up Gate · Plan-locked feature · Insufficient credits · Upload picker · Share to Group

---

## 8. Home Screen (ChatGPT-inspired)

**Top bar ONLY:** Logo · Search · Credits · Notification · Profile

**Center:** Large conversation area

**Bottom sticky input:** Attachment · Record Audio · Text Input · Send

**After lecture processing:** Stay in same conversation — NO new screen. Below AI response:
- Study Tabs: Notes · Summary · Transcript
- AI Actions section: Ask AI · Flashcards · Quiz · MCQ · Revision · Important Questions · Formula Sheet · Mind Map (future) · Translate · Voice Read

See [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) § Home for wireframes.

---

## 9. Recording & Upload

### Recording
- Tap Record → inline user bubble with timer
- Groq Whisper Large v3 Turbo (default)
- Poor quality → auto-retry Whisper Large v3 non-turbo (silent, no user choice)
- Background recording where platform allows
- Processing status in thread — no route change

### Upload (Attachment button)
PDF · Image · Audio file → same AI pipeline

### Audio retention
- **Default:** Delete after transcription (processing only)
- **Teacher exception:** Settings → `☐ Save Original Audio` (default OFF)

---

## 10. AI Processing Flow

```
Input (Audio / PDF / Image / Text)
  → Transcript or Extracted Text
  → Clean Transcript (for RAG quality)
  → Chunking → Vector DB
  → Notes → Summary → Extras
  → Auto-save Library
```

### Model routing
| Content | Model |
|---------|-------|
| Diagram, chart, handwriting | Qwen3-VL |
| Plain text | Qwen3 Instruct |
| Auto-detect fails | Default Qwen3-VL |

### RAG retrieval priority (Ask AI)
1. User Notes
2. Clean Transcript
3. RAG (vector chunks)
4. Web Search (Tavily)

PYQ database informs "Related Exam" tags only — does not directly answer. Never show original Q/options/answers.

**RAG priority (mandatory):** Notes → Transcript (clean) → Teacher Shared → Web Search. See [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md).

---

## 11. Notes Content Architecture

Every note includes: Summary · Key Points · Important Concepts · Revision · MCQ · Flashcards · Important Questions

**Future:** Mind Map · Formula Sheet

**PYQ mapping display:**
```
Related Exam
✓ NEET 2024
✓ JEE 2023
✓ CBSE 2025
```
Never show original PYQ text.

---

## 12. Library

Separate screen (bottom tab). Folders (subjects) · Search · Recent · Favorites.

Lecture card → tap → **Study Workspace** (full screen).

Tabs: Transcript · Notes · Summary · Flashcards · Quiz · Revision · Ask AI

No per-feature page navigation inside workspace.

---

## 13. Groups (Broadcast Model)

WhatsApp-inspired **feel**, not a chat app.

**Teacher can:** Upload lecture · Share Notes/Summary/Quiz/Assignment/Homework · Pin posts

**Students can:** Read · Open notes · Take quiz · Ask AI · Download (if allowed)

**Students cannot:** Message · Upload

**Access:** Join-before-share = immediate; join-after = post-join content only; expired = read-only/locked per plan.

---

## 14. Teacher Dashboard

Minimal cards only — no complicated tables.

Students · Monthly Subscribers · New Students · Revenue · Credits Used · Storage Used · Lecture Hours · Groups · Analytics (4–5 line summary card)

Entry: Profile → Teacher Dashboard

---

## 15. Subscriptions — Feature Separation

| Tier | Unlocks (product level) |
|------|-------------------------|
| Free | Ask AI only; no audio/PDF/photo |
| Entry (₹199) | + PDF, Image, study features |
| Mid (₹499) | + Audio record/upload |
| Premium (₹999) | Full access |
| Teacher | Record, Groups, Share, Dashboard, Analytics |

Credit amounts: see [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) v2.

---

## 16. Design System

| Element | Spec |
|---------|------|
| Background | White / off-white |
| Text | Near-black |
| Accent | Single color, sparingly |
| Radius | 8–12px cards |
| Motion | Subtle fade only |
| Empty states | One line + one action |

---

## 17. Feature Placement

| Feature | Location |
|---------|----------|
| Record | Home input 🎤 |
| Ask AI (global) | Home input |
| Upload PDF/Image | Home 📎 |
| Notes, Summary, Transcript | Home inline + Study Workspace |
| Flashcards, Quiz, Revision | Home AI Actions + Workspace tabs |
| Groups | Bottom Groups tab |
| Analytics | Teacher Dashboard |
| Credits | Top-right + Profile |
| Subscription | Profile |
| Library | Bottom Library tab |

---

## 18. Build Order (Recommended)

| Step | Focus |
|------|-------|
| 1 | ✅ PRD + UX Architecture (this doc) |
| 2 | UI/UX Screens (wireframes, components) |
| 3 | Database schema |
| 4 | AI Pipeline |
| 5 | Credits System (v2 saved) |
| 6 | Backend APIs |

---

## 19. Future Expansion

Mind Map · Formula Sheet · Voice Read · Translate · Institute multi-teacher · iOS App Store · Offline revision · PYQ deep linking (tags only)

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | PRD v1 saved — full product + UX flow |
| Jul 2026 | PRD v1.1 — design process order, Profile spec, 5-tab lock |
| Jul 2026 | Project Core Rules v1 — storage, sharing, RAG+PYQ, watermark | Founder `save all` |
