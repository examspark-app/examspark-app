# ExamSpark — Architecture

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)
> **Index of canonical architecture docs** — avoid duplicating detail here; link to source of truth.

---

## Product Architecture

| Doc | Contents |
|-----|----------|
| [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) | **Official** permanent workflow — phases 1A–6, models, gates |
| [`IA_SCREEN_HIERARCHY.md`](IA_SCREEN_HIERARCHY.md) | Phase 1A — IA, screens, flows |
| [`FEATURES_MASTER.md`](FEATURES_MASTER.md) | **Every feature** — status, screen, dependencies |
| [`APP_FLOW.md`](APP_FLOW.md) | Full user journey diagram (Guest → Ask AI) |
| [`PRD.md`](PRD.md) | Product flow, journeys, build order |
| [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) | IA, navigation, screens, Study Workspace |
| [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) | Storage, sharing, RAG, PYQ, security |
| [`DATA_STORAGE_POLICY.md`](DATA_STORAGE_POLICY.md) | Temp vs permanent — R2, Postgres, vectors |
| [`FEATURES.md`](FEATURES.md) | Feature checklist (lighter) |

---

## Technical Architecture

| Doc | Contents |
|-----|----------|
| [`TECH_STACK.md`](TECH_STACK.md) | FastAPI, R2, pgvector, Redis, Docker, Flutter |
| [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) | Credits v2, plans, gating |
| [`PAYMENT_ARCHITECTURE.md`](PAYMENT_ARCHITECTURE.md) | Razorpay, Google Play (not live) |
| [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md) | Groups, dashboard, access, watermark |

---

## Code Layout

```
ExamSpark-Project/
├── examspark_frontend/lib/     ← Canonical Flutter (ONLY)
├── examspark_backend/          ← FastAPI + edge function (interim)
├── PROJECT_*.md                ← Working docs (this index)
├── PRD.md, UX_ARCHITECTURE.md  ← Product
└── .cursor/rules/              ← Always-on AI rules
```

**Deprecated:** Root `lib/` — see `lib/DEPRECATED.md` if present.

---

## System Diagram (target)

```
Flutter (Android / Web / Desktop)
        ↓
Cloudflare (CDN / R2)
        ↓
FastAPI (Docker / Railway)  ← target
        ↓
┌───────────────┬──────────────┬─────────────┐
│ Supabase Auth │ Postgres     │ pgvector    │
│               │ (metadata)   │ (RAG)       │
└───────────────┴──────────────┴─────────────┘
        ↓
Groq Whisper · Qwen3 · Qwen3-VL · Tavily (web)
```

**Interim:** Supabase Edge Function `process-lecture` — migrate to FastAPI.

---

## Data Layers (summary)

| Layer | Stores | Rule |
|-------|--------|------|
| **Temp** | Raw audio, OCR cache, upload cache | Delete after processing |
| **R2** | Notes, summary, quiz, PDF, images, transcripts | Permanent blobs |
| **Postgres** | Users, groups, lecture metadata, credits, paths | Metadata only |
| **Vectors** | Clean transcript chunks, notes, teacher shared | No raw binaries |

Full rules: [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) §1

---

## Key Components (Flutter — target)

| Component | Role |
|-----------|------|
| `AppShell` | 5-tab bottom navigation |
| `HomeScreen` | Conversation + bottom input |
| `StudyWorkspace` | Shared lecture tabs (split / sheet / full) |
| `LibraryScreen` | Folders, search, favorites |
| `GroupsScreen` | Broadcast feed |
| `ProfileScreen` | Account + plan |

---

## AI Pipeline (product order)

```
Input → Transcript → Clean → Chunk → Vector
     → Notes → Summary → Extras → Library (R2)
```

**RAG answer order:** Notes → Transcript → Teacher Shared → Web

---

## Security (summary)

- Server-side credit + plan checks
- Group / library isolation
- Teacher-only content share
- Student invite-link only
- Watermark + lecture_id on shared assets

---

## Modular / Replaceable

- AI models (Groq, Qwen)
- Storage (R2)
- Payments (Razorpay, Google Play)
- Vector store (pgvector → dedicated later)

Never tight-couple in business logic — use gateway/adapter interfaces.

---

## Cursor Rules (enforcement)

| Rule file | Topic |
|-----------|-------|
| `examspark-working-rules.mdc` | Process, docs, founder workflow |
| `examspark-core-rules.mdc` | Storage, sharing, RAG |
| `examspark-ux-architecture.mdc` | UX guardrails |
| `examspark-tech-stack.mdc` | Stack hard rules |
| `examspark-credit-economy.mdc` | Credits v2 |
| `examspark-teacher-platform.mdc` | Teacher / groups |
| `examspark-roadmap.mdc` | Phase status |

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Architecture index created |
