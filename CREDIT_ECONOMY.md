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
| ₹199 | ₹199 | 1,300 | ₹0.153 |
| ₹499 | ₹499 | 3,500 | ₹0.143 |
| ₹999 | ₹999 | 8,000 | ₹0.124 |
| Teacher ₹1,999 | ₹1,999 | 20,000 | ₹0.0999 |

Plan IDs: `free` (gating only) · `plan_199` · `plan_499` · `plan_999` · `teacher`

Bigger plans = lower effective per-credit rate (buy more, save more).

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

**Critical:** Credits are **feature-based**, never minute-based in user-facing copy.

---

## Margin Validation (Internal — Healthy)

| Feature | Charged (₹) | Real AI Cost | Margin |
|---------|-------------|--------------|--------|
| Record 30–60 min | ₹12 | ~₹3 | ~75% |
| Record 60–90 min | ₹18 | ~₹5.6 | ~69% |
| Ask AI Normal | ₹0.75 | ~₹0.15 | ~80% |
| Diagram (Qwen3-VL) | ₹3.75 | ~₹0.2–0.3 | ~92%+ |
| Quiz | ₹3.75 | ~₹0.15 | ~96% |

---

## Plan-Tier Feature Gating

| Plan | Features Unlocked |
|------|-------------------|
| **Free** | Ask AI only. No audio, PDF, photo. |
| **₹199** (`plan_199`) | Ask AI + PDF + Photo/Diagram. Audio locked. |
| **₹299** (optional re-entry) | Same as ₹199 if reintroduced |
| **₹499** | Above + Audio Recording/Upload |
| **₹999** | Full access — no locks |
| **Teacher ₹1,999** | Bulk record + PDF export + share links + class dashboard |

Check order: (1) plan unlock → (2) credit balance. Server-side only.

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
- `subscription_plans.dart` — plan catalog

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | v1 locked costs (superseded) |
| Jul 2026 | **v2** — ₹0.15/credit, new plans, duration buckets, full feature table |
