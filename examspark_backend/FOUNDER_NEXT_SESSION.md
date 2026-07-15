# Next session — kya baki hai

> **Jul 16, 2026** · Single memory card.  
> **Rule:** Jo pehle **pass / OK** hai — **dobara setup / smoke / SQL re-nag mat karo.**

---

## Already done (yaad mat dilao)

- Groups join limits · Free lock · ₹199 1/1
- YouTube Link → Notes (**smoke pass**)
- Session 5 gating · Session 3 RAG Ask AI core · Session 4 R2 core
- Session 6 **code** (keys smoke alag)

---

## Abhi pending (sirf yeh)

### 1) Realtime + trim — ek baar (coding nahi)

Guide: [`FOUNDER_SESSION_LIVE_SYNC.md`](FOUNDER_SESSION_LIVE_SYNC.md) · trim: [`subscription_change_trim_groups_migration.sql`](subscription_change_trim_groups_migration.sql)

| Step | Action |
|------|--------|
| A1 | Realtime ON: `users` · `user_subscriptions` · `class_memberships` |
| A2 | Trim migration SQL (agar nahi chalaya) |
| A3 | Chat: `groups + realtime checklist done` |

Verify Realtime:

```sql
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('users', 'user_subscriptions', 'class_memberships');
```

Expect **3 rows**.

### 2) Razorpay Session 6 smoke — ⏸ jab keys ready

- Guide: [`FOUNDER_RAZORPAY_SESSION6.md`](FOUNDER_RAZORPAY_SESSION6.md)
- Pass: `Session 6 Razorpay smoke pass`
- **Do not start** without Test Mode keys

### 3) Next coding (aap “start” bolo)

| Prefer | Work |
|--------|------|
| **Default** | Flashcards / Quiz / Revision extras → FastAPI + credits |
| Later | Google Play Internal · Refund live check · PhonePe · Tavily/PYQ · Storage MB |

---

## Abhi mat karo

- Purane smoke SQL dobara (SEED / ALL_ACCOUNTS / FREE…) jab tak naya bug na ho
- Random UI polish
- Razorpay bina keys
- Flashcards / PhonePe jab tak aap start na bole

---

## Prefer reply (ek line)

`1 Realtime` · `2 Razorpay jab ready` · `3 Flashcards next`
