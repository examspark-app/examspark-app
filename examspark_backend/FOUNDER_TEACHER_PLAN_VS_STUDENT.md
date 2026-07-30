# Teacher ₹2,999 vs Student plans (guide)

## Refresh button (coded Jul 26)

Teacher Dashboard top-right **↻ Refresh** — reloads students, groups, credits, subscribers, commission.  
Realtime auto-update is **not** on this screen yet; Refresh = temporary fix.

---

## Who buys what?

| Plan | Price | Kaun | Kya milta hai |
|------|-------|------|----------------|
| **Teacher** | **₹2,999** | Teacher | Dashboard · **own** Groups create · share · **own AI credits** · **cannot join others** |
| **Student ₹199** | ₹199 | Student | More credits · join **1** Group · audio locked |
| **Student ₹499** | ₹499 | Student | Credits + audio · join **3** Groups |
| **Student ₹999** | ₹999 | Student | Full · join **6** Groups |
| **Free** | ₹0 | Student | 50 credits · **0 Groups** (unless coupon / special) |

## Teacher cannot join (locked Jul 26)

Teacher ₹2,999 = **own Groups only**. No student-style join.  
SQL: [`teacher_no_join_groups_migration.sql`](teacher_no_join_groups_migration.sql) · Guide: [`FOUNDER_TEACHER_NO_JOIN.md`](FOUNDER_TEACHER_NO_JOIN.md)

---

## Important (spam / money clear)

1. **Teacher ₹2,999** = teacher ka **apna** use + dashboard + groups create.  
2. **Student group join** = student ko **apna** paid plan chahiye (199 / 499 / 999) — Teacher plan students pe free join nahi kholta.  
3. **Student join** se teacher ke **credits cut nahi** hote.  
   Teacher credits cut = jab **teacher** AI use kare (record, quiz generate, Ask…).  
4. Teacher **commission** (30% display) = paid students jo group join karein — payout baad mein; abhi estimate card.

---

## Simple picture

```text
Teacher buys ₹2,999  →  Dashboard + Groups + own credits
Student buys ₹199/499/999  →  can join Groups (caps 1/3/6)
Student Free  →  cannot join (0 groups) unless coupon
```

No SQL / `.env` for this guide. Refresh = hot restart Flutter after pull.
