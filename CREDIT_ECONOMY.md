# ExamSpark — Credit Economy Model (v2)

> **Saved:** Jul 2026 — founder `save` (v2 supersedes v1)
> **Rule:** Feature/session-based credits — **never per-minute** in UI or pricing config.

---

## Core Principle

Users see **Credits** (or single translated usage estimate) — **never rupee amounts for AI cost**.

Internal (**backend only**): **1 Credit ≈ ₹0.15 charged-value**

---

## Plans & Credits (Volume Discount)

| Plan | Price | Credits | Effective ₹/Credit |
|------|-------|---------|-------------------|
| Free | ₹0 | 75 / **month** | — |
| ₹199 | ₹199 | 1,500 | ₹0.133 |
| ₹499 | ₹499 | 3,500 | ₹0.143 |
| ₹999 | ₹999 | 8,000 | ₹0.124 |
| Teacher ₹1,999 | ₹1,999 | 16,000 | ₹0.125 |

Plan IDs: `free` (gating only) · `plan_199` · `plan_499` · `plan_999` · `teacher`

**Jul 13, 2026 update:** `plan_199` 1,300 → 1,500 credits (Ask AI headroom — see "Fee-Corrected Margin Validation" below) · `teacher` 20,000 → 16,000 (60hr/month max-usage risk-ceiling validation, not a margin change).

Bigger plans = lower effective per-credit rate (buy more, save more).

**Free credits — founder-locked Jul 12, 2026: 50 → 75/month, monthly reset (not daily).** Real-cost check: even a free user who spends all 75 credits every month (mix of Ask AI + PDF Analysis) costs only **~₹0.35–0.45/user/month** in real AI cost — negligible at any scale. A **daily** reset was considered and rejected: 75 credits/day would allow up to ~2,250/month worth of usage per highly-active free user (~30x higher worst-case cost, ~₹10–13/user/month) with zero revenue — a monthly allowance keeps free-tier cost predictable at scale and preserves upgrade pressure for users who want daily/unlimited usage.

**Teacher credits ceiling resized Jul 13, 2026 — 20,000 → 16,000/month.** Re-validated against a **60 hours/month maximum-usage** assumption (not the typical ~20hr/month case): 60hrs of recording (mostly 60–90min sessions, ≈48 sessions × 120 credits = 5,760 credits) + **every single lecture** also getting Flashcards+Quiz+Revision+Formula+MindMap (~135 credits × 48 = 6,480 credits) + heavy Ask AI (200 Normal + 50 Deep ≈ 1,600 credits) tops out at **~13,840 credits even in this extreme case**. Adding a 15–20% safety buffer on top gives **~16,000** — still comfortably covers the extreme case with room to spare, while tightening the platform's worst-case exposure per teacher by ~4,000 credits (~₹600 charged-value). This is a **risk/abuse-ceiling** adjustment, not a margin lever — real teacher AI cost even at the 60hr extreme is only ~₹250–300/month against ₹1,999 charged, tiny either way.

---

## Buy Extra Credits (a-la-carte top-up — founder-locked Jul 13, 2026)

For users who don't want to upgrade their subscription plan but need more credits this month. **No teacher commission applies** — commission is only on recurring subscription price, not one-time top-ups.

| Pack | Credits | Price | ₹/Credit |
|------|---------|-------|----------|
| `pack_100` | 100 | ₹25 | ₹0.25 |
| `pack_500` | 500 | ₹110 | ₹0.22 |
| `pack_1000` | 1,000 | ₹200 | ₹0.20 |
| `pack_5000` | 5,000 | ₹850 | ₹0.17 |
| `pack_10000` | 10,000 | ₹1,500 | ₹0.15 |

**Pricing rule:** Per-credit rate is always **≥** the cheapest subscription plan's rate (`plan_199` = ₹0.133/credit) — top-ups never undercut the incentive to subscribe.

**Margin (worst-case Google Play 15% fee):**
- `pack_100` (₹25): −₹3.75 fee, −₹1.50 real AI cost, −₹0.50 hosting → **EBITDA ₹19.25 (~77%)**
- `pack_10000` (₹1,500): −₹225 fee, −₹150 real AI cost, −₹5 hosting → **EBITDA ₹1,120 (~75%)**

**Status:** Pricing/catalog live in `subscription_plans.dart` (`creditPacks`) and `credit_packs` table. Live checkout is Phase 5 Session 6 (Razorpay webhooks) work.

---

## Non-API Actions (Always Free — founder-locked Jul 12, 2026)

Codifies the existing "Library read = free" rule with concrete examples, so Phase 5 backend only deducts credits on actions that trigger a **new** AI API call — never on reading something already generated:

- Viewing/re-reading previously generated **Notes, Summary, Transcript, Flashcards, Quiz** for any lecture you own or have access to (Library)
- Browsing **Group feed**, **Progress**, **Profile**, **Settings** — no AI call involved
- **Selecting text** anywhere (`AskAiSelectableText`) is free — only tapping "Ask AI" and sending the question costs credits (that's the new API call)
- Re-opening a Group's shared-content preview sheet — free; only generating something new from it costs credits

If an action doesn't call Whisper/Qwen/Tavily, it doesn't cost credits — full stop.

---

## Feature Credit Costs (Session/Feature-Based)

| Feature | Credits |
|---------|---------|
| Record ≤30 min | 40 |
| Record 30–60 min | 80 |
| Record 60–90 min | 120 |
| Summary | Included with recording |
| Ask AI (Normal) | 5 |
| Ask AI (Deep) | 12 |
| Flashcards | 20 |
| Quiz (20 MCQ) | 25 |
| Important Questions | 20 |
| Revision Notes | 20 |
| Formula Sheet | 15 |
| Mind Map | 30 |
| Diagram/Image (Qwen3-VL) | 25 |
| PDF Analysis | 20 |
| OCR Image | 15 |
| Translate | 8 |
| Voice Read | 5 |
| YouTube Link → Notes (≤20 min) | 35 |
| YouTube Link → Notes (20–40 min) | 65 |
| YouTube Link → Notes (40–60 min) | 100 |

**Critical:** Credits are **feature-based**, never minute-based in user-facing copy.

### YouTube Link → Notes (founder-locked Jul 12, 2026)

- **Basis:** ~₹15/hour charged-value (founder-specified), converted at ₹0.15/credit → 100 credits at the 1-hour cap. Cheaper than Recording because there's no Whisper/STT cost — the video's own captions/transcript feed the same Notes/Summary/Flashcards/Quiz pipeline.
- **Hard limit:** 1 hour max per video. Longer videos are rejected before any credits are charged.
- **Restriction:** Public videos only. Private, unlisted, age-restricted, region-locked, or live-stream videos are rejected with a clear error (no partial charge).
- **UI placement:** Dedicated icon next to Record in the bottom input bar (not inside the "+" Attach sheet) — founder-requested for visibility.
- **Status:** Flutter UI (icon + paste-link dialog) built; backend fetch/transcribe pipeline is Phase 5 work (not started).

---

## Margin Validation (Internal — Healthy)

**Recomputed Jul 12, 2026 with real Groq/Qwen pricing** (see [`TECH_STACK.md`](TECH_STACK.md) Real Cost Reference) — actual cost came in even lower than the original estimates below:

| Feature | Charged (₹) | Real AI Cost (computed) | Margin |
|---------|-------------|--------------------------|--------|
| Record 30–60 min (Turbo STT + Qwen3 notes) | ₹12 | ~₹3.1 | ~74% |
| Record 60–90 min | ₹18 | ~₹5.6 | ~69% |
| Ask AI Normal (~500 in / 300 out tokens) | ₹0.75 | ~₹0.03 | ~96% |
| Ask AI Deep (~1,500 in / 800 out tokens) | ₹1.80 | ~₹0.08 | ~95% |
| Diagram (Qwen3-VL-Flash, default) | ₹3.75 | ~₹0.02 | ~99% |
| Diagram (Qwen3-VL-Plus, rare escalation) | ₹3.75 | ~₹0.07 | ~98% |
| Quiz (20 MCQ, text-only) | ₹3.75 | ~₹0.10 | ~97% |
| PDF Analysis (text-only, Free-tier eligible) | ₹3 | ~₹0.10–0.20 | ~93–97% |

The buffer between real AI cost and charged credits covers Razorpay's ~2% fee, Redis/Railway/R2 hosting, and the occasional non-turbo/Qwen3-VL-Plus escalation — pricing stays as-is for now.

### Margin after 30% Teacher Commission (per plan, per month) — superseded below

| Plan | Price | Teacher Commission (30%) | Typical AI Cost/mo | Platform Net |
|------|-------|---------------------------|---------------------|---------------|
| ₹199 | ₹199 | ₹59.70 | ~₹10–30 | ~₹110–130 (~55–65%) |
| ₹499 | ₹499 | ₹149.70 | ~₹30–70 | ~₹280–320 (~56–64%) |
| ₹999 | ₹999 | ₹299.70 | ~₹60–150 | ~₹550–640 (~55–64%) |

Even after paying teachers 30%, the platform keeps ~55–65% net margin at every tier, because per-feature AI cost is only 4–30% of charged value (see table above). **Caveat found Jul 13, 2026: this table never subtracted the payment gateway / Google Play cut — see the corrected version below.**

### Fee-Corrected Margin Validation (founder-locked Jul 13, 2026 — worst-case assumption)

Adds the missing **payment gateway fee** line — assumes **worst case: every payment goes through Android/Google Play Billing at 15%** (vs. Web/Razorpay's ~2%). Commission stays at 30% (unchanged, per founder decision — the credit/ceiling adjustment this round is about the teacher's own monthly allocation, not the commission rate).

| Plan | Price | Google Play Fee (15%, worst case) | Teacher Commission (30%) | Real AI Cost | Hosting | Platform EBITDA |
|------|-------|-------------------------------------|---------------------------|---------------|---------|-------------------|
| ₹199 | ₹199 | −₹29.85 | −₹59.70 | −₹7 to −₹10 (no audio feature on this tier) | −₹3 | **~₹99–102 (~50–51%)** |
| ₹499 | ₹499 | −₹74.85 | −₹149.70 | −₹30 to −₹50 | −₹4 | **~₹220–240 (~44–48%)** |
| ₹999 | ₹999 | −₹149.85 | −₹299.70 | −₹60 to −₹105 | −₹5 | **~₹440–485 (~44–48%)** |

**Findings:**
- **₹199** lands almost exactly at the 50% EBITDA target even in the worst case — it has no audio/recording feature, so real AI cost stays cheap. This is what freed the room to bump its credits 1,300 → 1,500 (see Buy Extra Credits / Plans table above).
- **₹499 / ₹999** land at ~44–48% EBITDA in the worst case, below 50% — driven by the more expensive recording feature plus the Google Play cut. **This is a flagged watch-item, not yet acted on** — founder decision (Jul 13, 2026) was to leave the 30% commission unchanged this round. If a **blended/actual** fee split is used instead of worst-case (e.g. more users checking out via Web/Razorpay's ~2% fee), EBITDA on these tiers recovers to **~70–75%**. Revisit once real Web-vs-Android payment split data is available, or explicitly ask to solve for exactly 50% here (would need commission ~24% instead of 30%, uniformly across tiers).
- **Teacher ₹1,999** plan has no commission line item (it's the teacher's own plan, not a commission payout) — EBITDA stays healthy at ~₹1,416 (~71%) even at worst-case fee.

---

## Teacher Commission (founder-locked Jul 12, 2026)

**Rate:** 30% of a student's subscription price, **recurring every month** the student stays subscribed — not a one-time signup bonus.

**Who qualifies:** Any student who is a member of the teacher's Group **and** has an active paid plan (₹199/₹499/₹999) — regardless of how or when they joined the group or bought the plan.

**Attribution rule (avoids double-paying):** A student can be a member of multiple teachers' Groups, but only **one** teacher earns commission on them at a time — their **primary teacher**, defined as the teacher who owns the Group with the **most recent `joined_at`** among all of that student's active `class_memberships`. If the student later joins a newer Group (more recent `joined_at`), the primary teacher automatically switches on the next calculation — no manual reassignment needed.

**Scope today (Phase 4):** Display-only. The Teacher Dashboard's "Estimated Commission" card (see [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md)) shows this as a calculated estimate via `fn_teacher_estimated_commission()`. **No real money moves** — actual payout to a teacher's bank account (Razorpay Route / manual payout) is explicit Phase 5 work per the "Revenue/commission live wiring" gate.

**Code:** `teacher_profiles.commission_rate` (default `0.30`, kept per-teacher configurable for future flexibility) · `fn_teacher_estimated_commission(p_teacher_id)` in `schema.sql` / `teacher_commission_migration.sql`.

---

## Plan-Tier Feature Gating

| Plan | Features Unlocked |
|------|-------------------|
| **Free** | Ask AI + PDF Analysis (text-only). No Photo/Diagram (vision), no audio (recording or upload). Cannot join Groups. |
| **₹199** (`plan_199`) | Above + Photo/Diagram (vision). Audio still locked. Join up to 1 Group. |
| **₹299** (optional re-entry) | Same as ₹199 if reintroduced |
| **₹499** | Above + Audio Recording/Upload. Join up to 3 Groups. |
| **₹999** | Full access — no locks. Join up to 6 Groups. |
| **Teacher ₹1,999** | Bulk record + PDF export + share links + class dashboard. Unlimited Groups (owns groups, doesn't "join" as a student). |

**Founder-locked Jul 12, 2026:** PDF Analysis moved from ₹199 into Free — real cost is only ~₹0.10–0.20/use (text-only, no vision model), cheap enough to give away as a hook. Photo/Diagram (needs Qwen3-VL) and all audio remain paid-only — those are the real differentiators and cost drivers.

Check order: (1) plan unlock → (2) credit balance. Server-side only.

---

## Group Join Limits (founder-locked Jul 12, 2026)

| Plan | Max Groups a student can join |
|------|-------------------------------|
| Free | 0 — shows "Upgrade to join Groups" |
| ₹199 | 1 |
| ₹499 | 3 |
| ₹999 | 6 |
| Teacher | Unlimited (owns groups) |

- Enforced client-side today via `GroupsRepository.canJoinAnotherGroup()` reading `fn_user_plan_tier()` + a `class_memberships` count against `subscription_plans.max_groups`. Real server-side enforcement (RLS/trigger blocking the `INSERT`) is Phase 5.
- Hitting the limit (or being on Free) shows the "Buy Plan" sheet (`buy_plan_sheet.dart`) instead of letting the join go through — wired into all 3 join entry points: Groups tab/list card, Group Info screen, and the "Join a Class" code dialog.
- "Copy Code" was removed from the Teacher Dashboard's group card (Jul 12, 2026) — "Share Invite Link" (`examspark.app/join/{joinCode}`) is now the only invite path, matching the format used on the Group Info screen's "Share Group" button.

---

## User-Facing UI

### Dashboard (Recommended — ONE primary stat)

```
AI Balance
● 1,245 Credits Remaining
≈ 15 Lecture Sessions (if used only for recording)
```

Do NOT show multiple translated stats as if independent pools — all draw from same balance.

If multiple estimates shown, include disclaimer:
```
Remaining AI Usage (estimates only — using one reduces the others)
Lecture Sessions : 15
Ask AI : 220
```

### Feature Button
```
Generate Notes
Cost: 80 Credits
[Generate]
```

### After Success
```
✓ Notes Generated
-80 Credits
Remaining: 2,370 Credits
```

### Insufficient Credits
```
Not enough AI Credits.
Remaining: 12 | Required: 20
[Upgrade Plan]  or  [Buy 500 Credits]
```

### Feature Locked
```
🔒 This feature needs the ₹499+ Plan
[View Plans]
```

---

## Implementation Rules

1. Deduct credits **server-side only**
2. Plan tier check **before** balance check
3. Never show rupee amounts for AI actions in UI
4. Per-feature/session pricing only — enforce in config + UI copy

## Future Credit Costs (not live)

| Action | Credits | Notes |
|--------|---------|-------|
| Group Invite Link share (student) | 100 | Configurable; anti-spam — **not** content sharing |

Students never spend credits to share notes/PDF — content share blocked entirely.

## Code

- `credit_costs.dart` — locked costs + `recordCreditsForDurationMinutes()`
- `plan_tier_gating.dart` — tier unlocks
- `credit_usage_display.dart` — dashboard translated estimates
- `subscription_plans.dart` — plan catalog + `maxGroups` per plan + `creditPacks` (Buy Extra Credits)
- `groups_repository.dart` — `canJoinAnotherGroup()` (Group Join Limits above)
- `credit_economy_v2_1_migration.sql` — DB sync for the Jul 13, 2026 numbers (founder must run once)

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | v1 locked costs (superseded) |
| Jul 2026 | **v2** — ₹0.15/credit, new plans, duration buckets, full feature table |
| Jul 12, 2026 | Added Group Join Limits (₹199=1, ₹499=3, ₹999=6, teacher=unlimited); removed "Copy Code" from Teacher Dashboard |
| Jul 12, 2026 | Added Teacher Commission (30% recurring, primary-teacher attribution, display-only Phase 4) + margin-after-commission table |
| Jul 12, 2026 | Free tier: added PDF Analysis (text-only), 50→75 credits/month; recomputed Margin Validation with real Groq/Qwen pricing; added Non-API Actions (Always Free) list; teacher-credit validation note (20,000 kept unchanged) |
| Jul 13, 2026 | Added Buy Extra Credits (5 a-la-carte packs, no teacher commission); Fee-Corrected Margin Validation adds worst-case 15% Google Play fee line (was missing); plan_199 1,300→1,500 credits (room found once real no-audio AI cost used, stays ~50% EBITDA); teacher 20,000→16,000 (60hr/month max-usage risk-ceiling validation); free 50→75 code/DB sync fix (doc already said 75 since Jul 12); flagged plan_499/plan_999 at ~44–48% EBITDA worst-case as a watch-item (commission left at 30%, not acted on this round) |
