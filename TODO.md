# ExamSpark — TODO

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)

---

## ✅ Phase 1A — LOCKED 🔒 (founder Jul 11, 2026)

**No further doc edits without founder approval.**

- [x] Product Vision · PRD · IA · Navigation · all flows
- [x] Credits · Storage · Rules · master docs
- [x] `DEVELOPMENT_WORKFLOW.md` — official permanent workflow

**⏸ Phase 1B wireframes = NEXT** — ask founder before start.

---

## 🔵 Phase 1B — Low Fidelity Wireframes (blocked until founder says go)

**Model:** Sonnet 5 High · **No Flutter code**

- [ ] Mobile wireframes — every screen
- [ ] Desktop wireframes — every screen
- [ ] Header · Nav · Content · Bottom bar · Buttons · FABs · Popups · Sheets
- [ ] Founder approval before Phase 2

---

## ⏳ Phase 2 — Flutter UI (blocked until 1B approved + founder OK)

**Founder rules:** Keep Supabase auth · reuse login · UI only · backend connections intact · never rewrite auth unless asked.

- [ ] `AppShell` — 5 bottom tabs (keep `AuthGate`)
- [ ] Restyle `LoginScreen` — same `_handleLogin` / `_handleSignUp`
- [ ] Home chat layout
- [ ] `StudyWorkspace` widget
- [ ] Library · Groups · Progress · Profile (placeholder OK)
- [ ] Teacher Dashboard cards
- [ ] Theme + dark mode + responsive
- [ ] Keep `LectureService` + `RecordingService` wired

---

## ⏳ Phase 3 — UI Polish (GPT-5.5 Medium)

- [ ] Text, icons, padding, small fixes — never redesign architecture

---

## ⏳ Phase 4 — Architecture / Data (NOT YET — founder manual)

- [ ] Supabase · SQL · RAG schema · credits · R2 · permissions

---

## ⏳ Phase 5 — Backend (NOT YET)

- [ ] FastAPI · APIs · payments · AI pipeline

---

## ⏳ Phase 6 — Final Polish (GPT-5.5 Medium)

- [ ] Testing · cleanup · docs · performance

---

## 🗑 Marked for Removal (confirm first)

| Item | Reason |
|------|--------|
| `/processing` → `/notes_result` navigation | Inline conversation |
| `/teacher`, `/student` top routes | Groups + Profile |
| Home sidebar | Library tab |
| Root `lib/` duplicate | Deprecated |

---

## 💡 Future

See [`FEATURES.md`](FEATURES.md)
