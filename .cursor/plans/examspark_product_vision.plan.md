---
name: ExamSpark Product Vision Tracker
overview: Founder-led product tracker. PRD + UX + tech + credits saved Jul 2026.
todos:
  - id: discuss-one-liner
    content: "Discuss: One-liner — what is ExamSpark?"
    status: completed
  - id: discuss-problem
    content: "Discuss: Problem statement"
    status: completed
  - id: discuss-target-users
    content: "Discuss: Target users (teacher/student/coaching)"
    status: completed
  - id: discuss-user-flows
    content: "Discuss: Core user flows"
    status: completed
  - id: discuss-features
    content: "Discuss: Must-have vs nice-to-have features"
    status: completed
  - id: discuss-monetization
    content: "Discuss: Pricing, credits, who pays"
    status: completed
  - id: discuss-differentiators
    content: "Discuss: What makes ExamSpark different"
    status: completed
  - id: discuss-constraints
    content: "Discuss: Constraints (India, platforms, etc.)"
    status: completed
  - id: discuss-non-goals
    content: "Discuss: Non-goals — what NOT to build"
    status: completed
  - id: ux-architecture
    content: "UX: Home, Library, Workspace, Groups, Dashboard"
    status: completed
  - id: implement-ui-shell
    content: "Build: 5-tab shell + Home chat + StudyWorkspace widget"
    status: pending
isProject: false
---

# ExamSpark Product Vision — Discussion Tracker

## Save Rules (Founder Preference)

1. **Discuss freely** — brainstorming stays in chat until saved
2. **Save on command** — `save` / `save karo` / `save all`
3. **Partial save** — `save monetization`, `save ux`, etc.

## Files Updated on Save

| File | When |
|------|------|
| [`PRD.md`](../PRD.md) | Product flow, journeys, feature architecture |
| [`UX_ARCHITECTURE.md`](../UX_ARCHITECTURE.md) | Screen layouts, navigation, component map |
| [`examspark_frontend/PRODUCT_VISION.md`](../examspark_frontend/PRODUCT_VISION.md) | Vision summary + decisions log |
| [`.cursor/rules/examspark-ux-architecture.mdc`](../rules/examspark-ux-architecture.mdc) | Always-on UX guardrails |
| [`.cursor/rules/examspark-product-vision.mdc`](../rules/examspark-product-vision.mdc) | One-liner + pointers |
| This plan file | Checklist + decisions log |

## Section Checklist

- [x] One-liner
- [x] Problem
- [x] Target users
- [x] Core user flows
- [x] Key features (must-have / nice-to-have)
- [x] Monetization (Credit Economy v2)
- [x] Differentiators
- [x] Constraints / Platforms
- [x] Non-goals
- [x] UX Architecture (Home, Library, Workspace, Groups, Dashboard)
- [x] PRD v1
- [x] Platforms (Web, Android, iOS deferred App Store)
- [x] Manual ops policy (AI guides founder)
- [x] Tech stack (FastAPI, R2, pgvector, Redis, Docker)
- [x] Credit economy v2
- [x] Teacher platform (dashboard, access logic, R2)
- [x] Audio policy (delete default; teacher opt-in)
- [x] RAG (Notes → Clean Transcript → Web)

## Build Order (Next)

1. ✅ PRD + UX Architecture
2. UI/UX Screens (wireframes, components)
3. Database schema
4. AI Pipeline
5. Credits System (v2 saved)
6. Backend APIs

## Decisions Log

| Date | Section | Decision | Saved? |
|------|---------|----------|--------|
| Jul 2026 | Platforms | Web + Android now; iOS App Store ~3 months | Yes |
| Jul 2026 | Manual ops | AI step-by-step guides for SQL, .env, deploy | Yes |
| Jul 2026 | Tech stack | FastAPI + Docker + R2 + pgvector; no permanent audio | Yes |
| Jul 2026 | Credit Economy v2 | Session buckets; plans ₹199/₹499/₹999/Teacher | Yes |
| Jul 2026 | RAG | Notes + Clean Transcript in vector DB; Notes first retrieval | Yes |
| Jul 2026 | Audio policy | Delete after Whisper; teacher Save Original Audio (OFF) | Yes |
| Jul 2026 | UX — Home | ChatGPT-style; inline study after record; no new screen | Yes |
| Jul 2026 | UX — Library | Folders, search, recent, favorites → Study Workspace | Yes |
| Jul 2026 | UX — Groups | WhatsApp feel; broadcast only; no student chat | Yes |
| Jul 2026 | UX — Dashboard | Minimal cards; no complex tables | Yes |
| Jul 2026 | UX — Nav | 5 tabs: Home, Library, Groups, Progress, Profile | Yes |
| Jul 2026 | Teacher platform | Business dashboard, student access, R2 | Yes |
| Jul 2026 | Project Core Rules | Storage, groups, sharing, RAG, PYQ, watermark, security | Yes |

## Unsaved Discussion Buffer

```
(empty — last save: save all, Jul 2026)
```

## How to Start Next

- `"build shell"` → 5-tab nav + Home chat + StudyWorkspace scaffold
- `"save [section]"` → partial update
- Discuss new ideas in chat first; save when ready
