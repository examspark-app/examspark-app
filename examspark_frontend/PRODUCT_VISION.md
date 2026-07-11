# ExamSpark — Product Vision

> **Status:** Active — founder decisions saved Jul 2026
> **Save policy:** Files update when founder says "save" / "save karo" / "save all"
> **Canonical UX:** [`UX_ARCHITECTURE.md`](../UX_ARCHITECTURE.md) · **PRD:** [`PRD.md`](../PRD.md)

---

## One-liner

**ExamSpark** — Premium AI learning platform for India. Teachers record once; students study with Notes, Quiz, Flashcards, and Ask AI — all in a ChatGPT-simple interface with an education-focused Study Workspace.

---

## Problem

- Students drown in raw lectures — no structured revision
- Teachers repeat content across batches manually
- Coaching groups run on WhatsApp — spam, no structured study tools
- Generic edu-apps are cluttered; ChatGPT has no lecture memory or exam-focused outputs

---

## Target Users

| Segment | Role | Priority |
|---------|------|----------|
| Students | Self-study + teacher content | Primary |
| Teachers | Record, share, analytics | Primary |
| Coaching Institutes | Groups, subscribers, scale | Secondary |

---

## Core User Flows

1. **Anonymous try** → One Ask AI → Sign up → @username + Library
2. **Record / Upload** → Inline conversation processing → Study Tabs + AI Actions
3. **Library** → Folder browse → Study Workspace (tabs)
4. **Teacher** → Record → Share to Group (broadcast) → Dashboard cards
5. **Student** → Join group → Read feed → Quiz / Ask AI / Revise

---

## Key Features

### Must-have

- Home chat screen (ChatGPT-style input bar)
- Inline + full Study Workspace (Notes, Summary, Transcript, Quiz, Flashcards…)
- Library (folders, search, recent, favorites)
- Groups (WhatsApp-feel broadcast, no student chat)
- Ask AI (Notes → Clean Transcript → RAG → Web)
- Teacher Dashboard (minimal cards)
- 5-tab navigation only
- Credit economy v2 (credits-only UX)

### Nice-to-have (architecture-ready)

- Mind Map · Formula Sheet · Translate · Voice Read
- Institute multi-teacher role
- iOS App Store launch
- Offline revision download

---

## Monetization

**Saved** — [`CREDIT_ECONOMY.md`](../CREDIT_ECONOMY.md) v2

- Plans: Free · ₹199 · ₹499 · ₹999 · Teacher ₹1,999
- Users see credits only — never per-action ₹
- Feature gating: Free (Ask AI) → Entry (PDF/Image) → Mid (Audio) → Premium (full) → Teacher (B2B)

Partial save: `save credits`

---

## Differentiators

1. **Study Workspace** — ChatGPT has conversation only; ExamSpark adds split-pane (desktop) / bottom-sheet (mobile) study tabs — Notes · Summary · Transcript · Flashcards · Quiz · Revision · Ask AI — one lecture, no page hopping
2. **Broadcast groups** — coaching scale without WhatsApp chaos
3. **Clean dual RAG** — Notes first, Clean Transcript backup (not noisy raw transcript)
4. **Session-based credits** — simple, never per-minute
5. **Premium minimal UI** — Apple + ChatGPT simplicity, not colorful edu-app

---

## Constraints

### Platforms (founder decision — Jul 2026)

| Platform | Now | Future (~3 months) |
|----------|-----|---------------------|
| **Web** | Build & deploy | Primary target |
| **Android** | Build & deploy | Play Store ready |
| **iOS** | Structure ready, test locally | App Store upload (~3 months) |

- Flutter multi-platform: single codebase in `examspark_frontend/`
- Responsive: Android · Web · Desktop

(e.g. India-first, Hindi content supported, NCERT/PYQ alignment via exam tags)

---

## UX Architecture

**Saved** — [`UX_ARCHITECTURE.md`](../UX_ARCHITECTURE.md) · [`PRD.md`](../PRD.md)

- Home = ChatGPT conversation + inline Study Block after processing
- Library = separate tab → Study Workspace
- Groups = broadcast feed (not chat)
- Teacher Dashboard = cards only
- 5 bottom tabs: Home · Library · Groups · Progress · Profile

Partial save: `save ux`

---

## Tech Stack

**Saved** — full architecture: [`TECH_STACK.md`](../TECH_STACK.md)

Summary: Flutter (Android/Web/iOS future) → Cloudflare → FastAPI (Docker/Railway) → Supabase Postgres + pgvector + Redis + Cloudflare R2 → Groq Whisper + Qwen3 + Qwen3-VL.

Partial save command: `save tech`

---

## Credit Economy

**Final system saved** — [`CREDIT_ECONOMY.md`](../CREDIT_ECONOMY.md)

**v2 saved** — session-based costs; internal 1 Credit ≈ ₹0.15 (backend only). Recording: 40/80/120 by duration bucket. Plans: Free → ₹199 → ₹499 → ₹999 → Teacher (1,300 / 3,500 / 8,000 / 20,000 credits). Users see credits only — never per-action ₹.

Partial save command: `save credits` / `save credit-economy`

### User Library (founder decision — Jul 2026)

- **Transcript saved** for users in Library (subject → lecture → Transcript | Notes | Summary)
- User can re-read teacher's **original explanation** via Transcript
- **Audio still deleted** after processing
- **RAG priority:** Notes → Clean Transcript → Web Search

---

## Teacher Platform

**Saved** — [`TEACHER_PLATFORM.md`](../TEACHER_PLATFORM.md)

- Business dashboard (not just upload): students, revenue, credits, groups, engagement
- Student access logic: join timing + subscription expiry (read-only/locked after expiry)
- R2 corrected asset list + folder architecture

Partial save: `save teacher` / `save teacher-platform`

---

## Manual Operations (AI Guides Founder)

When founder must do hands-on steps, AI provides **step-by-step guides** — not just "go configure it".

| Task | AI guides through |
|------|-------------------|
| Supabase SQL | Open dashboard → SQL Editor → paste `schema.sql` → run → verify tables |
| `.env` keys | Which file (`examspark_frontend/.env`, `examspark_backend/.env`), which keys (URL, anon, service role), where to copy from Supabase dashboard |
| Edge function deploy | `supabase functions deploy process-lecture`, secrets, storage bucket |
| Storage buckets | Create `temp-audio`, policies |
| Backend deploy | FastAPI hosting (Railway/Render/VPS) → env vars → health check → webhook URL |
| Payment webhooks | Razorpay / Google Play dashboard → webhook URL → test event |
| Android release | Keystore, `build.gradle`, Play Console steps |
| iOS (future) | Xcode signing, Archive, TestFlight, App Store Connect |

**Rule:** End-to-end guidance until step is done — founder bol sakta hai "ab SQL run karo guide karo" and AI walks through each click/command.

---

## Non-goals

- **Permanent audio storage (default)** — delete after processing; teacher opt-in only
- **Student chat in groups** — broadcast only
- **ChatGPT clone** — we use interaction patterns, not copy UI
- **Colorful / gamified edu-app design**
- **PYQ text display** — exam reference tags only
- **Student content sharing** — invite link only; never notes/PDF/transcript
- **Large files in Postgres** — metadata only; R2 for blobs

## Core Rules

**Saved** — [`PROJECT_CORE_RULES.md`](../PROJECT_CORE_RULES.md)

Storage tiers · Group ownership · Strict sharing · RAG priority · PYQ mapping · Watermark · Security · Cost optimization

Partial save: `save core-rules`
- **Per-minute credit pricing in UI**
- **Complicated teacher BI tables** — cards only

---

## Open Questions

1. Hindi UI timeline — English UI first assumed
2. Institute admin role — future slot
3. Student self-record vs teacher-only emphasis — both supported, TBD marketing focus
4. Group join: code vs link — both planned

---

## Decisions Log

| Date | Section | Decision | Reason |
|------|---------|----------|--------|
| Jul 2026 | Platforms | Web + Android + iOS; iOS App Store in ~3 months | iOS structure ready now, store upload later |
| Jul 2026 | Manual ops | AI step-by-step guides for Supabase, .env, backend deploy | Founder does hands-on; AI walks through end-to-end |
| Jul 2026 | Tech stack | FastAPI + Docker + R2 + pgvector + Redis + Qwen/Groq pipeline | Founder `save tech` — full architecture documented |
| Jul 2026 | Credit economy | Tier-based credits (archived) | Founder `save` — superseded below |
| Jul 2026 | **Final credits + gating (v1)** | Locked 80/25/35/5/20; plans Free/₹299/₹499/₹999/Teacher | Superseded by v2 |
| Jul 2026 | **Credit Economy v2** | Session-based costs; ₹0.15/credit internal; plans ₹199/₹499/₹999/Teacher | Volume discount + healthier margins; credits-only UX |
| Jul 2026 | Teacher platform | Business dashboard + student access + R2 corrections | Teacher business platform, not notes-only app |
| Jul 2026 | User Library + RAG | Save transcript for users; RAG order Notes → Clean Transcript → Web Search | Original explanation re-read; quality + speed balance |
| Jul 2026 | Audio policy | Default delete after Whisper; teacher opt-in Save Original Audio | Storage + privacy; processing-only audio |
| Jul 2026 | Study Workspace differentiator | Desktop right panel + mobile bottom sheet; 7 study tabs in one lecture | ChatGPT-simple + education-focused — not a clone |
| Jul 2026 | Project Working Rules | Doc mandate, phase-by-phase, non-dev founder workflow, task summary | Never lose context; quality over speed |
| Jul 2026 | PRD v1 | Full product flow, AI pipeline product rules, feature placement | Foundation before UI/DB/API implementation |

---

## Changelog

| Date | What changed | Trigger |
|------|--------------|---------|
| Jul 2026 | Platforms + manual ops guidance saved | Founder instruction |
| Jul 2026 | Tech stack saved to TECH_STACK.md | Founder `save tech` |
| Jul 2026 | Credit economy saved to CREDIT_ECONOMY.md | Founder `save` |
| Jul 2026 | Library transcript + RAG priority saved | Founder `save` |
| Jul 2026 | Final credits + plan gating saved (v1) | Founder `save` |
| Jul 2026 | Credit Economy v2 saved | Founder spec — session buckets + new plans |
| Jul 2026 | Teacher platform + R2 + access logic saved | Founder `save` |
| Jul 2026 | PRD + UX Architecture saved | Founder `save all` |
| Jul 2026 | UX v1.1 — IA, nav flow, Profile | Founder UX refinement |
| Jul 2026 | Study Workspace differentiator | Desktop split + mobile bottom sheet |
| Jul 2026 | Project Core Rules saved | Storage, sharing, RAG, PYQ, watermark |
| Jul 2026 | Project Working Rules + doc system | PROJECT_ROADMAP, FEATURES, ARCHITECTURE, TODO, CHANGELOG |
| — | Initial template created | Setup only |
