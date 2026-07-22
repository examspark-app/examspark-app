# ExamSpark — Project Working Rules

> **Saved:** Jul 2026 — founder mandate
> **Status:** MUST FOLLOW before any code, docs, or architecture work
> **Audience:** AI agents + anyone contributing to ExamSpark

---

## 0. Never Guess

If any requirement is unclear — **ask the founder first**. Do not implement assumptions.

---

## 1. Save Everything

Whenever you make an important decision (architecture, UI, product flow, business logic, navigation, structure) — **save it permanently in project documentation**.

**Do NOT rely on chat history.**

### Required project docs (maintain at repo root)

| File | Purpose |
|------|---------|
| [`PROJECT_ROADMAP.md`](PROJECT_ROADMAP.md) | Phases — what’s done, what’s next |
| [`FEATURES.md`](FEATURES.md) | Feature list — must-have, nice-to-have, future |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | System architecture index + summary |
| [`TODO.md`](TODO.md) | Pending tasks |
| [`CHANGELOG.md`](CHANGELOG.md) | What changed and when |
| [`API_SETUP.md`](API_SETUP.md) | Every API key / `.env` variable — phase, dashboard, paste location |
| [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md) | **When** to paste keys — abhi vs Phase 4 vs Phase 5 (founder guide) |

### Deep-dive docs (also keep updated on save)

| File | Topic |
|------|-------|
| [`PRD.md`](PRD.md) | Product requirements |
| [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) | UX / navigation / screens |
| [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) | Storage, sharing, RAG, security |
| [`TECH_STACK.md`](TECH_STACK.md) | Tech stack target |
| [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) | Credits v2 |
| [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md) | Teacher / groups |
| [`examspark_frontend/PRODUCT_VISION.md`](examspark_frontend/PRODUCT_VISION.md) | Vision summary |

Every completed task → document. Every pending task → `TODO.md`. Every future idea → `FEATURES.md` or roadmap.

---

## 2. This Is an AI Study Platform

**Not** a notes app. **Not** a chatbot.

**ExamSpark = AI Study Platform**

- Conversation (ChatGPT-simple) **+** Study Workspace
- Teachers record → students study (Notes, Quiz, Flashcards, Ask AI)
- Groups = broadcast, not chat

Always implement from this vision. See [`PRD.md`](PRD.md) · [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md).

---

## 3. Work Phase by Phase

Never build everything at once. Small phases. **Complete one phase → ask founder before next.**

```
Phase 1A ✅ Product Foundation (LOCKED)
Phase 1B    Low-fi Wireframes (Sonnet 5) — NEXT
Phase 2     Flutter UI (Sonnet 5) — after 1B OK
Phase 3     UI polish (GPT-5.5 Medium)
Phase 4     Architecture / Data (Sonnet 5)
Phase 5     Backend (Sonnet 5)
Phase 6     Final polish (GPT-5.5 Medium)
```

**Official workflow:** [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md)

Current: **Phase 1 LOCKED** — wait for founder OK on Phase 2.

See [`PROJECT_ROADMAP.md`](PROJECT_ROADMAP.md) · [`IA_SCREEN_HIERARCHY.md`](IA_SCREEN_HIERARCHY.md).

### Phase 1 lock (founder Jul 11, 2026)

**Status: LOCKED.** No edits to Phase 1 docs (vision, IA, UX, rules, storage, flows) without explicit founder approval.

### Phase 2 — Auth & backend (founder rule, Jul 2026)

**Replace UI only. Never break what already works.**

| Rule | Meaning |
|------|---------|
| **Keep Supabase auth** | Do not remove or rewrite authentication unless founder explicitly asks |
| **Reuse login system** | Keep `SupabaseClient`, `AuthGate`, `LoginScreen` logic — restyle UI only |
| **Keep backend connections** | Existing services (`LectureService`, `RecordingService`, edge functions) stay wired |
| **Placeholder OK for new tabs** | Library · Groups · Progress may use fake data until Phase 4 |
| **Do not disconnect working flows** | Record → Processing → Notes must still call Supabase if they do today |

**Do NOT touch (unless founder requests):**

- `lib/core/network/supabase_client.dart` — auth + edge function methods
- `lib/main.dart` — Supabase `.env` init
- `lib/presentation/widgets/auth_gate.dart` — session gate
- `login_screen.dart` — `_handleLogin` / `_handleSignUp` logic (UI redesign OK)

**Safe to change in Phase 2:**

- Visual design of `LoginScreen`
- `HomeScreen` layout → new 5-tab `AppShell`
- New screens with placeholder content
- Theme, widgets, navigation shell

---

## 4. Founder Is a Non-Developer

Do **not** assume coding knowledge.

When manual work is required — **STOP**. Explain step-by-step. **Wait for confirmation.**

Examples: Supabase project · SQL · Storage bucket · `.env` · Google Console · Razorpay · Cloudflare · Play Console · Domain · API keys

Format: numbered steps · exact paths · copy-paste commands · verify checkpoint after each step.

---

## 5. Never Auto-Create External Services

Do **not** assume Supabase, Razorpay, R2, etc. exist or are configured.

Never say **"Done"** for external setup unless founder manually completed it.

Always list what **founder** must do.

---

## 6. Clean Project

Mark obsolete files for removal: old components, pages, APIs, services, docs, assets, unused code.

Remove **only after founder confirmation.**

No dead code · no duplicate logic · no root `lib/` mirror (use `examspark_frontend/lib/` only).

---

## 7. Single Source of Truth

- No duplicate business logic
- No duplicate UI patterns
- No duplicate models
- Reuse: `StudyWorkspace`, `credit_costs.dart`, `subscription_plans.dart`, etc.

Canonical Flutter: `examspark_frontend/lib/`  
Canonical backend: `examspark_backend/`

---

## 8. Always Self-Check

After every task, self-review and report in simple language:

- UI · Navigation · Logic · Performance
- Folder structure · Unused files · Broken imports
- Naming · Consistency

Founder is not a developer — explain plainly what was checked.

---

## 9. Ask Before Complex Tasks

If a task is large, touches many files, or is high-risk — **STOP**. Ask founder.

For **Phase 2+ Flutter UI** and **Phase 4–5 backend** — recommend **Claude Sonnet 5**.

For **Phase 3** small fixes — default/cheap model OK.

Wait for confirmation. Then continue.

---

## 10. You May Improve UX

Mandatory UX / navigation improvements that fit the vision — **OK to implement**.

**Do NOT:** change core product idea · remove requested features.

Always explain what improved and why.

---

## 11. Never Rush

Quality > speed. Think as:

- Senior Product Designer
- Senior Flutter Engineer
- Senior Backend Engineer
- Startup CTO

Production-quality architecture.

### CTO Working Charter (Founder Lock — Jul 17, 2026)

Full lock: [`examspark_backend/FOUNDER_CTO_WORKING_CHARTER.md`](examspark_backend/FOUNDER_CTO_WORKING_CHARTER.md)

- Honesty over ego; user-first; careful one-slice scope
- **Gate A:** Phase 4C careful smoke before new coding — [`FOUNDER_PHASE4C_SMOKE_CARD.md`](examspark_backend/FOUNDER_PHASE4C_SMOKE_CARD.md)
- **Gate B:** Next coding only when founder says `start …` — [`FOUNDER_PENDING_LOCKED.md`](examspark_backend/FOUNDER_PENDING_LOCKED.md)
- Never fake UI smoke pass; never claim external SQL/env done until founder did it

---

## 12. End of Every Task (Required Summary)

**Every code change must end with a Manual Setup Checklist and .env Checklist.** No feature is considered complete until both are explained to the founder.

Always finish with the **Feature Completion Report** (see §13.3):

```
✅ What was coded
📄 Files changed
⚠ Manual setup required
⚠ .env variables required
⚠ SQL required
⚠ Supabase changes
⚠ Cloudflare changes
🧪 How to test
   → Expected result
   → Rollback (if needed)
🗑 Files safe to remove (if any — ask before delete)
➡ Recommended next task
```

Never end an implementation task without this block.

---

## 13. Additional Permanent Development Rules

> **Saved:** Jul 11, 2026 — founder mandate (permanent)

### 13.1 Manual Setup Guide (Mandatory)

After every coding task, **do not assume setup is complete.**

Always provide a separate section:

**Manual Setup Required**

Explain step-by-step in simple language (non-developer friendly):

| What to explain | Examples |
|-----------------|----------|
| Files to edit manually | Which file, which line, what to paste |
| Supabase SQL | Exact SQL + where to run (Dashboard → SQL Editor) |
| Cloudflare R2 | Bucket name, folder structure, CORS |
| Edge Function | Deploy command, which function, secrets |
| FastAPI | Start command, Docker, Railway deploy |
| Environment variables | Which `.env` file, which keys |
| API keys | Where to get each key |
| Dashboard settings | Supabase, Cloudflare, Razorpay, Google Console |

**Never assume the founder already knows these steps.**

Format: numbered steps · exact paths · copy-paste commands · **verify checkpoint** after each step.

---

### 13.2 .env Rules

Whenever a new service is added, always tell the founder:

**Add these to `.env`**

Example template (add only what applies):

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
GROQ_API_KEY=
TAVILY_API_KEY=
R2_ACCOUNT_ID=
R2_ACCESS_KEY=
R2_SECRET_KEY=
R2_BUCKET=
OPENROUTER_API_KEY=
```

For **each key**, explain:

| Question | Must answer |
|----------|-------------|
| Where to get it? | Exact dashboard path or signup URL |
| Where to paste it? | `examspark_frontend/.env` or `examspark_backend/.env` |
| Restart required? | Yes/No — app restart, edge redeploy, etc. |

---

### 13.3 Feature Completion Report

After every completed feature, always generate:

| Section | Content |
|---------|---------|
| ✅ What was coded | Plain-language summary |
| 📄 Files changed | List of paths |
| ⚠ Manual setup required | Step-by-step (§13.1) |
| ⚠ .env variables required | Keys + where to get + where to paste (§13.2) |
| ⚠ SQL required | Copy-paste SQL if any |
| ⚠ Supabase changes | Tables, RLS, buckets, edge functions |
| ⚠ Cloudflare changes | R2 buckets, Pages, DNS |
| 🧪 How to test | Exact steps founder can follow |
| → Expected result | What they should see if it works |
| → Rollback | How to undo if something breaks |

**No feature = complete until Manual Setup Checklist + .env Checklist are both explained.**

---

### 13.4 Never Hide Manual Work

If any feature **cannot work** until manual setup is done:

**DO NOT silently continue.**

Stop and clearly say:

> **Manual setup required before next step.**

Then list exactly what the founder must do. Wait for confirmation before proceeding.

---

### 13.5 Cleanup Rules

**Never delete any file automatically.**

Before deleting:

1. Check whether it is used (imports, routes, references)
2. Explain why it can be removed
3. **Ask for confirmation**
4. Only then delete

Mark as "safe to remove" in the report — do not delete without founder OK.

---

### 13.6 Non-Developer Mode

Always explain as if the founder is **not** a developer.

**Never assume knowledge of:** SQL · Supabase · FastAPI · Cloudflare · Flutter · Git

- Use simple language
- Give copy-paste commands whenever possible
- One step at a time
- Verify checkpoint after each step ("agar ye dikhe to sahi hai")

---

### 13.7 Phase Rules

**Do not start the next phase automatically.**

At the end of every phase:

1. Audit everything
2. Verify documentation
3. Verify project structure
4. Tell founder what is completed
5. Tell founder what is still missing
6. **Wait for confirmation**

Phase 1 is **LOCKED** — no doc edits without founder approval.

---

## Cursor Rules (always-on)

- [`examspark-development-workflow.mdc`](.cursor/rules/examspark-development-workflow.mdc) — **official workflow**
- [`examspark-working-rules.mdc`](.cursor/rules/examspark-working-rules.mdc) — this document
- [`examspark-product-vision.mdc`](.cursor/rules/examspark-product-vision.mdc) — save policy
- [`examspark-core-rules.mdc`](.cursor/rules/examspark-core-rules.mdc) — storage / sharing / RAG
- [`examspark-ux-architecture.mdc`](.cursor/rules/examspark-ux-architecture.mdc) — UX guardrails

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Working rules v1 + doc file mandate |
| Jul 11, 2026 | §13 Additional Permanent Development Rules — manual setup, .env, feature report, cleanup, phase gate |
