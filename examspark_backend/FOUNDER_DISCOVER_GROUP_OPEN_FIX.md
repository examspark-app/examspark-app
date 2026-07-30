# Founder — Discover / Group open fix (Jul 25, 2026)

## What changed

- Discover shows **only teachers who already created ≥1 group**
- **AND** teacher must have **active Teacher plan ₹2,999** (`user_subscriptions`: `plan_id=teacher`, `status=active`, `current_period_end >= now`)
- Suggest + Search use the same rule — inactive plan → **hidden**
- Logged-in: **no Demo mock** teachers if query empty/fails
- Join prefers **public** group → opens group info
- **Joined** row → tap **Open** / card → group info
- Already-joined students: group **stays** even if teacher plan ends (only new discovery hides)

## Smoke

1. Flutter hot restart (**R**)
2. Groups → **Discover**
3. Teacher with **0 groups** → list mein **nahi**
4. Teacher with group + **active Teacher plan** → dikhe → **Join**
5. Teacher plan expire / not teacher → Discover / Suggest / Search mein **nahi**
6. Student already in that teacher’s group → My Groups mein **rehta**

## Manual / .env

None for this fix.
