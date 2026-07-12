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
| **1B** | Low Fidelity Wireframes (mobile + desktop) | Sonnet 5 High | ✅ **Complete** — Jul 11, 2026 |
| **2** | Flutter UI (placeholder data) | Sonnet 5 High | ✅ **Complete** — Jul 11, 2026 |
| **3** | UI Polish | GPT-5.5 Medium | ✅ **Complete** — Jul 11, 2026 |
| **4** | Architecture (Supabase, RAG, R2 — no FastAPI yet) | Sonnet 5 High | ✅ **Complete** — Jul 11, 2026 |
| **5** | Backend (FastAPI, payments, AI pipeline) | Sonnet 5 High | ⏳ **Next — founder approval required** |
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

## Phase 1B — Low Fidelity Wireframes (founder approved Jul 11, 2026) ✅

**Deliverables:**

- [`WIREFRAMES.md`](WIREFRAMES.md) — expanded detailed draft, 28 screens/states/popups, Mobile + Desktop, ASCII wireframes only, no Flutter code.
- [`PHASE_1B_CORE_WIREFRAMES.md`](PHASE_1B_CORE_WIREFRAMES.md) — founder-requested core pass, 22 requested screens + 9 requested popups, grouped into 8 core UX areas.

**Ask founder:** "Phase 1B wireframes approve karein? Phir Phase 2 (AppShell) shuru karenge."

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

## Phase 2 — Flutter UI ✅ COMPLETE (founder approved Jul 11, 2026)

**Gates:** Phase 1B approved + founder says **"Phase 2 shuru karo"** ✅ cleared

**Model:** Sonnet 5 High

### Hard rules

- **Do NOT** remove or break Supabase authentication
- **Reuse** `SupabaseClient` + `AuthGate` + `LoginScreen` logic — UI restyle only
- **Keep** `LectureService`, `RecordingService`, edge functions wired
- **Placeholder data** for new tabs — no new backend
- **Never rewrite auth** unless founder explicitly requests

### Build list

- [x] `AppShell` — 5 bottom tabs (bottom `NavigationBar` mobile/tablet, `NavigationRail` desktop)
- [x] Home chat + `AppTopBar` + `BottomInputBar`
- [x] `StudyWorkspace` (split desktop · sheet mobile) — placeholder tab content
- [x] Library · Groups · Progress · Profile (Library/Groups use real data; Progress/Profile mostly placeholder)
- [x] Teacher Dashboard cards — business metric grid (placeholder data) + class folders
- [x] Theme + dark mode + responsive (existing `AppTheme` reused, `Responsive` breakpoints added)
- [x] Inline `StudyWorkspace` overlay — Library/Home cards open the workspace directly, no forced `/notes_result` page jump (old route kept working for backward compatibility)

---

## Phase 3 — UI Polish ✅ COMPLETE (Jul 11, 2026)

**Model:** GPT-5.5 Medium

- [x] Padding · icons · typography · colors
- [x] Responsive fixes · small widgets · accessibility
- [x] Focused bug/lint pass on recent Phase 2 files
- **Never** redesign architecture

---

## Phase 4 — Architecture (Data Layer) ✅ COMPLETE (Jul 11, 2026)

**Model:** Sonnet 5 High · Founder manual steps required

- [x] Supabase · SQL · RLS
- [x] Credits server rules · plan gating (`fn_deduct_credits`, `fn_user_plan_tier`)
- [x] Cloudflare R2 path columns (bucket creation deferred to Phase 5)
- [x] pgvector · RAG chunk schema (`rag_documents` with `source_type`, `chunk_hash`)
- [x] Group permissions · teacher dashboard data (`class_folders`, `group_shared_items`, `fn_group_item_access`)
- [x] Flutter wiring — `GroupsRepository`, `ClassService`, Teacher Dashboard, `SupabaseClient.deductCredits()`
- [x] Founder guide — [`PHASE_4_SUPABASE_SETUP.md`](PHASE_4_SUPABASE_SETUP.md)

**Backend APIs still not live** — data layer only. Founder must run SQL in Supabase (guided one step at a time).

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
1B Wireframes            🟡 Draft created, awaiting approval
2  Flutter UI            (after 1B OK)
3  UI Polish
4  Architecture / Data
5  Backend
6  Final Polish
```

---

## Related

[`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) · [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md) · [`TODO.md`](TODO.md) · [`PRD.md`](PRD.md)
