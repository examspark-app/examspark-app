# ExamSpark — App Notification Map (founder-locked Jul 23, 2026)

> **Saved:** Founder `save notification map`  
> **Channels:** In-app (Home bell + Groups unread) · Push (FCM lock screen / tray) when Firebase configured  
> **Guide:** [`examspark_backend/FOUNDER_NOTIFICATIONS.md`](examspark_backend/FOUNDER_NOTIFICATIONS.md)

---

## Principles

1. **Fewer taps** — tap notification → correct screen (group / subscription / pending list).
2. **No chat** — Groups notifications = broadcast content only, not messaging.
3. **Credits/rupees** — payment alerts never show internal credit economics; plan name / success-fail only.
4. **Soft vs hard** — legal Create Group disclaimer is **optional product** (not locked as required); join/payment/expiry alerts are the priority build list below.

---

## Live today (coded)

| Who | Event | In-app | FCM push | Deep link |
|-----|--------|--------|----------|-----------|
| Student | Teacher **shares** notes/quiz/lecture / **announcement** | ✅ Home bell + Groups badge | ✅ (if FCM set) | That group |
| Student | Join **Pending** | ✅ | ✅ | Group Info |
| Teacher | **New pending request** | ✅ | ✅ | Group dashboard |
| Student | Join **Accepted** / **Rejected** | ✅ | ✅ | Group Info |
| Both | Plan **expires in 7 / 3 / 1 day** + **expired** | ✅ | ✅ | Subscription |
| Both | Payment **success** / **failed** | ✅ | ✅ | Subscription |

Implementation: share · join · expiry · `notify_payment_success` / `notify_payment_failed` in payment orchestrator

---

## Not built yet (locked map — build order)

### Priority A — Join approval — **Done** Jul 23

### Priority B — Subscription & payment

| Who | Event | Status |
|-----|--------|--------|
| Both | Plan expiry 7/3/1 + expired | **Coded** Jul 23 |
| Both | Payment **success** / **failed** | **Coded** Jul 23 |

### Priority C — Study & credits

| Who | Event | When to send |
|-----|--------|----------------|
| Student | Notes / lecture **ready** | Own recording pipeline done |
| Student | **Low credits** | Balance under soft threshold (e.g. &lt; 50) — exact number TBD at `start` |
| Teacher | Soft **verification** result | Get Verified ≥90% or fail (optional) |

### Priority D — Teacher business (after payments live)

| Who | Event | When to send |
|-----|--------|----------------|
| Teacher | New **student joined** (Auto / paid skip Pending) | Membership insert |
| Teacher | New **subscriber** attributed | Paid plan + primary teacher (commission later) |

---

## Explicitly out of scope (for now)

- Student↔student chat pings  
- Marketing spam / promo blasts  
- Government KYC alerts  
- Manual admin “review queue” for verification (soft AI only)

---

## Create Group disclaimer popup

| Item | Status |
|------|--------|
| Soft one-time disclaimer on first Create Group | **Coded** Jul 23 — local SharedPreferences |
| Copy | *“Students see content you share. No chat. You are responsible for what you post.”* |

Does **not** replace Setup Gate or Teacher plan gate. Flutter only — no SQL.

---

## Suggested coding starts (when founder ready)

1. ~~`start notifications pending-approval`~~ **Done** Jul 23  
2. ~~`start subscription expiry alerts`~~ **Done** Jul 23  
3. ~~`start payment notifications`~~ **Done** Jul 23  
4. ~~`start create-group disclaimer`~~ **Done** Jul 23  
5. Optional later: `start notes-ready notifications` · `start low-credits notifications`

---

## Changelog

| Date | Change |
|------|--------|
| Jul 23, 2026 | Full app notification map saved (live = group post only; A–D backlog) |
