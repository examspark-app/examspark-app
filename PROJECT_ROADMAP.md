# ExamSpark — Project Roadmap

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)
> **Official workflow:** [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md)
> **Last updated:** Jul 11, 2026

**Vision:** AI Study Platform — not notes app, not chatbot.

**Gate rule:** Jab ek phase complete ho → **audit → report → founder se poocho** → tab agla phase.

---

## Phase Status (Official)

| Phase | Name | Model | Status |
|-------|------|-------|--------|
| **1A** | Product Foundation (docs only) | Sonnet 5 High | 🔒 **LOCKED** — Jul 11, 2026 |
| **1B** | Low Fidelity Wireframes (mobile + desktop) | Sonnet 5 High | 🔵 **NEXT** |
| **2** | Flutter UI (placeholder data) | Sonnet 5 High | ⏳ Blocked until 1B approved |
| **3** | UI Polish | GPT-5.5 Medium | ⏳ Pending |
| **4** | Architecture (Supabase, RAG, R2 — no FastAPI yet) | Sonnet 5 High | ⏳ Pending |
| **5** | Backend (FastAPI, payments, AI pipeline) | Sonnet 5 High | ⏳ Pending |
| **6** | Final Polish | GPT-5.5 Medium | ⏳ Pending |

### Sonnet budget (founder strategy)

| Phase | Share |
|-------|-------|
| 1A | 15% |
| 1B | 10% |
| 2 | 35% |
| 4 | 20% |
| 5 | 20% |

Small fixes → **GPT-5.5 Medium** only. Never waste Sonnet on padding/icons.

### Legacy scaffold (pre-UX-arch)

Old technical scaffold (recorder, edge function, payment stubs) — see [`examspark_frontend/ROADMAP.md`](examspark_frontend/ROADMAP.md). Align in Phase 2, do not throw away blindly.

---

## Phase 1A — Product Foundation ✅ LOCKED

**Founder lock:** Jul 11, 2026 — no further edits without founder approval.

**Deliverables (all complete):**

- [x] Product Vision · PRD · IA · Navigation · User/Teacher/Student/Library/Group flows
- [x] Credits Architecture · Storage Policy · Folder Structure · Development Rules
- [x] `PROJECT_ROADMAP.md` · `PROJECT_WORKING_RULES.md` · `ARCHITECTURE.md`
- [x] `APP_FLOW.md` · `FEATURES_MASTER.md` · `DATA_STORAGE_POLICY.md`
- [x] `CHANGELOG.md` · `TODO.md` · `README.md`
- [x] `IA_SCREEN_HIERARCHY.md` · `UX_ARCHITECTURE.md` · `PRD.md` · core rules

**No Flutter. No Backend.**

---

## Phase 1B — Low Fidelity Wireframes (NEXT)

**Ask founder:** "Phase 1B wireframes shuru karun?"

**Model:** Sonnet 5 High

**Rules:**

- No Flutter code
- Mobile wireframes + Desktop wireframes for every screen
- Each screen shows: Header · Navigation · Content · Bottom bar · Buttons · FABs · Popups · Sheet placement
- Founder approval required before Phase 2

**Screens to wireframe:**

- [ ] Splash / Auth (Login)
- [ ] Home (Chat) + Inline Study Block
- [ ] Study Workspace (mobile sheet + desktop split)
- [ ] Library · Groups · Progress · Profile
- [ ] Teacher Dashboard · Subscription · Settings
- [ ] Popups: Sign Up Gate · Plan Lock · Low Credits · Upload · Share · Logout

**Output:** Wireframe doc or assets (TBD on start)

---

## Phase 2 — Flutter UI

**Gates:** Phase 1B approved + founder says **"Phase 2 shuru karo"**

**Model:** Sonnet 5 High

### Hard rules

- **Do NOT** remove or break Supabase authentication
- **Reuse** `SupabaseClient` + `AuthGate` + `LoginScreen` logic — UI restyle only
- **Keep** `LectureService`, `RecordingService`, edge functions wired
- **Placeholder data** for new tabs — no new backend
- **Never rewrite auth** unless founder explicitly requests

### Build list

- [ ] `AppShell` — 5 bottom tabs
- [ ] Home chat + `TopBar` + `BottomInputBar`
- [ ] `StudyWorkspace` (split desktop · sheet mobile)
- [ ] Library · Groups · Progress · Profile
- [ ] Teacher Dashboard cards
- [ ] Theme + dark mode + responsive
- [ ] Inline `LectureResultCard` — no `/notes_result` jump

---

## Phase 3 — UI Polish

**Model:** GPT-5.5 Medium

- [ ] Padding · icons · typography · colors
- [ ] Responsive fixes · small widgets · accessibility
- [ ] Empty states · loading skeletons · modals
- **Never** redesign architecture

---

## Phase 4 — Architecture (Data Layer)

**Model:** Sonnet 5 High · Founder manual steps required

- [ ] Supabase · SQL · RLS
- [ ] Credits server rules · plan gating
- [ ] Cloudflare R2 buckets
- [ ] pgvector · RAG chunk schema
- [ ] Group permissions · teacher dashboard data

**Backend APIs still not live** — data layer only.

---

## Phase 5 — Backend

**Model:** Sonnet 5 High only

- [ ] FastAPI + Docker
- [ ] APIs · auth · R2 · pgvector
- [ ] AI pipeline (Groq, Qwen)
- [ ] Payments: Razorpay · Google Play · PhonePe

---

## Phase 6 — Final Polish

**Model:** GPT-5.5 Medium

- [ ] Testing · bug fixes
- [ ] Remove unused files (founder confirmation)
- [ ] Docs update · performance · cleanup

---

## Implementation Order

```
1A Product Foundation    🔒 LOCKED
1B Wireframes            🔵 NEXT
2  Flutter UI            (after 1B OK)
3  UI Polish
4  Architecture / Data
5  Backend
6  Final Polish
```

---

## Related

[`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) · [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md) · [`TODO.md`](TODO.md) · [`PRD.md`](PRD.md)
