# ExamSpark Home AI Phase 4C — Final Hardening (Founder Lock)

**Status:** LOCKED + code (Jul 17, 2026)  
**CTO charter:** [`FOUNDER_CTO_WORKING_CHARTER.md`](FOUNDER_CTO_WORKING_CHARTER.md)  
**One-page smoke (start here):** [`FOUNDER_PHASE4C_SMOKE_CARD.md`](FOUNDER_PHASE4C_SMOKE_CARD.md)  
**SQL (run in order if not done):**  
1. [`home_ai_phase4c_migration.sql`](home_ai_phase4c_migration.sql)  
2. [`home_ai_phase4c_v2_migration.sql`](home_ai_phase4c_v2_migration.sql) ← Knowledge V2 + stale

This is **NOT** a redesign. UX + architecture + cost optimization only.

---

## Goal

Home AI = Study Workspace, not ChatGPT.  
One expensive AI generation → one reusable **Knowledge Object**.  
Everything else reuses that object.

---

## Credits (STRICT)

| Action | Credits |
|--------|---------|
| Home Ask (first generation → Knowledge Object) | **5** / **12** deep |
| Open chips from Knowledge Object | **0** (no AI) |
| Explicit **Regenerate** | Paid |
| Follow-up needing new knowledge (Hindi / Class 8 / more examples) | New Ask → **V2** → parent chips **stale** |
| Near-duplicate question (semantic) | **0** — reuse cached answer |

---

## Careful ONE-TIME smoke (do in order — stop on fail)

### 0) Setup
1. Run SQL 1 then SQL 2 in Supabase (if not already).  
2. Backend: `http://localhost:8000/` → Active.  
3. Flutter capital **`R`**.

### 1) Home Ask (paid once)
- Ask: `What is photosynthesis?`  
- Expect: short answer + Recommended chips + “free from this answer”.  
- Credits: −5 once.  
Pass phrase: `4c ask pass`

### 2) Free chips (no credit drop)
- Tap **Flashcards** → sheet, badge Free/Cached.  
- Close → reopen Flashcards → **Cached · free**.  
- Credits unchanged.  
Pass: `4c chips free pass`

### 3) Unique formats
- Quiz → MCQ UI (not same essay).  
- Memory / Exam Booster (More) → different layout.  
Pass: `4c unique chips pass`

### 4) Semantic reuse (no second charge)
- Ask: `photosynthesis meaning`  
- Expect: fast reuse / 0 credits (same session cache).  
Pass: `4c semantic pass`

### 5) Follow-up V2
- Ask: `Explain in Hindi`  
- Expect: new answer (charged), new chips on **new** bubble.  
- Old bubble chips may show ready again (stale refresh).  
Pass: `4c v2 follow-up pass`

### 6) Workspace Notes (regression)
- Open Library lecture → Notes loads; switch tabs instant.  
- Minimize Chrome → restore → still logged in, Home not wiped.  
Pass: `notes + session pass`

### Stop rules
- Error / wrong credit cut → screenshot + stop. Do not continue.  
- Do not re-run SQL if tables already exist (v2 is IF NOT EXISTS safe).

---

## Smarter free chips (Jul 17 night)

Chips stay **0 credits** (no LLM on open). Derive templates are **unique study jobs**:
Flashcards = questions · Quiz = shuffled MCQ + varied stems · 5 Min = timed drill ·
Exam Booster = marks script · Memory = cue+scene · not the same essay with a new title.

**If an old chip still looks generic:** open the chip again (legacy cache auto-upgrades once, free) · or ask a **new** Home question · or **Regenerate** (paid). Soft restart backend if `--reload` missed the file.

---

## Still later (not this smoke)
- Redis / SQLite multi-device L1–L4  
- PYQ Style live bank  
- Richer AI Regenerate quality pass  
