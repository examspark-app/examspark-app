# ExamSpark — Start PYQs (Founder guide)

**Gate:** You said `start PYQs` / `ok start` (Jul 18, 2026).  
**Status:** **PASS locked Jul 18 night** — founder `all pass ok lock`.  
**Copyright lock:** metadata only — never original question text.

## What you get

| Piece | File |
|-------|------|
| Table + seed labels + `match_exam_pyqs` RPC | [`pyq_exam_pyqs_migration.sql`](pyq_exam_pyqs_migration.sql) |
| Embed topic labels → vectors | [`scripts/seed_pyq_embeddings.py`](scripts/seed_pyq_embeddings.py) |
| Live retrieval | [`app/services/pyq_retrieve.py`](app/services/pyq_retrieve.py) → **Important Questions** chip (not every Home ask) |

## Steps (do in order)

### 1) SQL

1. Supabase Dashboard → **SQL Editor** → New query  
2. Open `examspark_backend/pyq_exam_pyqs_migration.sql` → copy **all** → paste → **Run**  
3. Bottom verify: `exam_pyqs_rows` ≥ 6, `match_fn` = `ok`, `with_embedding` may be `0` until step 2  

### 2) Embeddings (needs OpenRouter + Supabase in `.env`)

Backend folder mein:

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python scripts/seed_pyq_embeddings.py
```

**Verify:** print `OK` for each row.  
SQL verify dubara: `with_embedding` = same as row count.

### 3) Restart backend

```powershell
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

### 4) Smoke

1. Home: `how many chambers in the human heart` → short answer; may show **Related: NEET 2024** (or CBSE) if similarity ≥ 0.80  
2. Home: `what is photosynthesis` → may show **Related: NEET 2023** Biology Photosynthesis  
3. Random unrelated: `how do I buy credits on ExamSpark` → **no** Related PYQ section  

Pass phrase: `PYQs bank smoke pass`

## .env (already used by backend)

- `OPENROUTER_API_KEY` — embeddings  
- `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` — table + RPC  

No new env names.

## Threshold + UX (Jul 18 night)

1. Similarity **0.45** = internal floor only — **student never sees the number**. Tags look like `Related: NEET 2023 · Biology · …`
2. Home/Ask **answer path skips PYQ match** (faster first token). PYQ bank is used inside **Important Questions** chip (weightage = chance bias).
3. IVFFlat on tiny bank was broken — optional SQL: `pyq_fix_ivfflat_index.sql`
4. Learn More **Regenerate**: Qwen + **5 credits**, shorter prompt (faster). First Learn More open still **0 credits** (KO).

Re-seed if needed:

```powershell
python scripts/seed_pyq_embeddings.py --force
```

### Important Questions smoke

1. Home ask any biology topic → **Important Qs** (free) — may show Focus tags from PYQ bank  
2. Sheet **Regenerate** — Qwen + **10 credits**; questions biased to high weightage chapters  
3. No original paper question text ever
