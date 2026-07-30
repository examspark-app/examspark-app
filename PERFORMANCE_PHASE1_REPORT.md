# ExamSpark Performance — Phase 1 Report (Fast First Answer)

**Date:** Jul 15, 2026  
**Scope:** Home AI + Ask AI only. Credits / auth / RAG priority order unchanged.

---

## Targets vs delivery

| Target | Approach | Status |
|--------|----------|--------|
| First token &lt; 1s (stream) | SSE already live; skip RAG / cache replay | Improved path; absolute &lt;1s depends on OpenRouter RTT |
| Meaningful answer 2–3s (Home normal) | Direct route + brevity + max_tokens 512 + cache | Typical direct/Home uncached still LLM-bound |
| Ask AI &lt; 4s | Top-3 chunks, expand if low sim, embed cache, parallel index+credit | Improved; embed+R2+LLM still dominate cold path |
| No quality / cost spike | Same model slug; fewer chunks → often lower tokens | Locked |

---

## Before → After (architecture)

| Bottleneck | Before | After |
|------------|--------|-------|
| Streaming | SSE live | Unchanged (kept) |
| Home + open lecture always RAG | Always embed+vector | Smart route: product/general → **direct** (no embed) |
| Match count | Always top **5** | Default top **3**; expand to **5** if best sim &lt; 0.35 |
| Chunk payload | Full chunk text | Cap **1200** chars / chunk |
| Same query twice | Full LLM again + re-charge | In-process answer cache: **no LLM, credits_charged=0** |
| Same embed text | Re-call OpenRouter embeddings | In-process embedding TTL cache (~1h) |
| Pre-LLM | Index then credit then embed (serial) | Ask AI: **index ∥ credit precheck**, then embed/vector |
| Observability | Little timing | `examspark.perf` one-line logs per request |

---

## Bottlenecks removed / reduced

1. Unnecessary RAG on Home product/general questions  
2. Oversized RAG context (5 chunks, unbounded text)  
3. Duplicate embedding API calls for identical queries  
4. Duplicate LLM + double credit on identical SUCCESS questions (TTL ~30 min)  
5. Blind serial credit check after indexing (now parallel where safe)

---

## Remaining opportunities (not Phase 1)

| Item | Why later |
|------|-----------|
| Redis shared cache | Multi-worker / Railway; in-process only today |
| Tavily / real `web` route | Product not live |
| Smaller / faster chat model | Quality trade-off — founder `.env` choice |
| OpenRouter prompt caching headers | Optional; system prompts still large |
| Flutter “Searching notes…” label | UX only; deferred |
| Persist perf metrics to DB | Hot path stays log-only |

---

## Founder SQL checklist (pgvector)

Index already defined in [`examspark_backend/schema.sql`](examspark_backend/schema.sql):

`idx_rag_documents_embedding` — `ivfflat (embedding vector_cosine_ops)`

### 1) Confirm index exists (Supabase → SQL Editor)

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'rag_documents'
  AND indexname = 'idx_rag_documents_embedding';
```

**Expected:** one row with `USING ivfflat`.

If missing (only if you never applied full schema), run the `CREATE INDEX` from `schema.sql` for `rag_documents` embeddings — ask AI before pasting if unsure.

### 2) Optional EXPLAIN (replace UUIDs with real values)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, source_type, r2_chunk_path,
       (1 - (embedding <=> '[0,0,...]'::vector)) AS similarity
FROM rag_documents
WHERE user_id = 'YOUR_USER_UUID'
  AND lecture_id = 'YOUR_LECTURE_UUID'
  AND source_type = 'notes'
ORDER BY embedding <=> '[0,0,...]'::vector
LIMIT 3;
```

Prefer calling existing RPC in app (`match_rag_documents`) over rewriting it unless EXPLAIN shows sequential scans on large tables.

---

## How to read timing logs

Backend console / Railway logs — logger name `examspark.perf`:

```text
perf feature=home_ai_stream total_ms=1820 validation_ms=12 llm_ms=1600 route=direct cache_hit=False rag_skipped=True
```

Spans may include: `validation`, `pre_llm`, `index`, `embed`, `vector`, `llm`.

---

## Manual smoke (founder)

1. Restart FastAPI (or rely on `--reload`).  
2. Home: `what is credit economy` (with a lecture open) → should feel faster (route=direct, no RAG).  
3. Home: subject question about lecture → still RAG.  
4. Ask same Home question twice within ~30 min → second reply instant; credits **not** deducted again (`credits_charged: 0`).  
5. Ask AI lecture question → still grounded; first ask −5 credits.  
6. Language lock + typo tolerance still OK.
