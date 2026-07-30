# ExamSpark Project

**AI Study Platform** for India — ChatGPT-simple conversation + Study Workspace. Not a notes app. Not a chatbot.

**Canonical app:** [`examspark_frontend/`](examspark_frontend/) — run all Flutter commands from here.

**Backend:** [`examspark_backend/`](examspark_backend/)

---

## Start Here (for humans + AI)

| Doc | Purpose |
|-----|---------|
| [**IA_SCREEN_HIERARCHY.md**](IA_SCREEN_HIERARCHY.md) | **Phase 1** — every screen explained (simple) |
| [**FEATURES_MASTER.md**](FEATURES_MASTER.md) | **Every feature** — status, screen, dependencies |
| [**DATA_STORAGE_POLICY.md**](DATA_STORAGE_POLICY.md) | **Where data lives** — temp, R2, Postgres, vectors |
| [**APP_FLOW.md**](APP_FLOW.md) | **Full user journey** — Guest → Ask AI |
| [**API_SETUP.md**](API_SETUP.md) | **Every API key** — what it is, dashboard link |
| [**ENV_PASTE_TIMELINE.md**](ENV_PASTE_TIMELINE.md) | **When to paste keys** — abhi vs Phase 4 vs Phase 5 |
| [**FOUNDER_MANUAL_SETUP_GUIDE.md**](FOUNDER_MANUAL_SETUP_GUIDE.md) | **Step-by-step** — account banao, kya copy, kis file mein paste |
| [**DEVELOPMENT_WORKFLOW.md**](DEVELOPMENT_WORKFLOW.md) | **Official workflow** — phases 1A–6, models, founder rules |
| [**PROJECT_WORKING_RULES.md**](PROJECT_WORKING_RULES.md) | **Read first** — how we work |
| [PROJECT_ROADMAP.md](PROJECT_ROADMAP.md) | Phase status — **Phases 1–3 complete · Phase 4 next** |
| [TODO.md](TODO.md) | Pending tasks |
| [CHANGELOG.md](CHANGELOG.md) | What changed |
| [FEATURES.md](FEATURES.md) | Feature checklist (lighter) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Architecture index |

## Product & UX

[PRD.md](PRD.md) · [UX_ARCHITECTURE.md](UX_ARCHITECTURE.md) · [examspark_frontend/PRODUCT_VISION.md](examspark_frontend/PRODUCT_VISION.md)

## Technical & Business Rules

[TECH_STACK.md](TECH_STACK.md) · [PROJECT_CORE_RULES.md](PROJECT_CORE_RULES.md) · [CREDIT_ECONOMY.md](CREDIT_ECONOMY.md) · [TEACHER_PLATFORM.md](TEACHER_PLATFORM.md) · [PAYMENT_ARCHITECTURE.md](PAYMENT_ARCHITECTURE.md)

---

## Important

- Root-level `lib/` (if present) is **deprecated** — use `examspark_frontend/lib/` only.
- Founder is non-developer: external setup (Supabase, R2, Razorpay…) requires **manual step-by-step** guides.
- Work **phase by phase** — ask before next phase.
- Decisions saved in docs — **not** chat history.

## Run

```bash
cd examspark_frontend
flutter pub get
flutter run -d chrome
```
