# Phase 4C — One-page smoke card (NOW)

> **CTO Charter:** [`FOUNDER_CTO_WORKING_CHARTER.md`](FOUNDER_CTO_WORKING_CHARTER.md)  
> **Detail:** [`FOUNDER_PHASE4C_HOME_AI.md`](FOUNDER_PHASE4C_HOME_AI.md)  
> **Rule:** Fail pe STOP. Screenshot + `smoke fail`. Naya feature mat shuru.

---

## 0) Setup (once)

| Step | Do this | OK when |
|------|---------|---------|
| SQL 1 | Supabase → SQL Editor → paste [`home_ai_phase4c_migration.sql`](home_ai_phase4c_migration.sql) → Run | No fatal error (or already exists) |
| SQL 2 | Same → paste [`home_ai_phase4c_v2_migration.sql`](home_ai_phase4c_v2_migration.sql) → Run | Result: `phase4c_v2_ok` |
| Backend | Browser `http://localhost:8000/` | `"ExamSpark Backend Active"` |
| Flutter | Chrome app open → terminal capital **`R`** | App reloads |

**.env:** No new keys.

---

## Smoke order (copy pass phrases into chat)

| # | Action | Expect | Pass phrase |
|---|--------|--------|-------------|
| 1 | Home: `What is photosynthesis?` | Short answer + Visual card (if any) + **5 primary chips** (Quiz…Learn More) + More; credits **−5 once** | `4c ask pass` |
| 2 | Tap **Flashcards** → close → open again | Free/Cached; credits **unchanged** | `4c chips free pass` |
| 3 | **Quiz** = MCQ; **More → Mind Map / Common Mistakes** = different layout | Not same essay dump | `4c unique chips pass` |
| 4 | Ask: `photosynthesis meaning` | Fast reuse; **0 extra credits** | `4c semantic pass` |
| 5 | Ask: `Explain in Hindi` | New answer (charged); new bubble + chips | `4c v2 follow-up pass` |
| 6 | Library lecture → Notes; minimize Chrome → restore | Notes load; Home not wiped; still logged in | `notes + session pass` |

---

## Prefer reply (all at once when done)

```
4c ask pass · 4c chips free pass · 4c unique chips pass · 4c semantic pass · 4c v2 follow-up pass · notes + session pass
```

Or: `smoke fail` + what broke.

---

## After all pass

Say **one** only: `start PYQs` · `start Tavily` · `start Railway deploy guide`  
(See [`FOUNDER_PENDING_LOCKED.md`](FOUNDER_PENDING_LOCKED.md) §C — Gate B.)
