"""Embed exam_pyqs.topic_label → embedding (1536). Run AFTER pyq_exam_pyqs_migration.sql.

Usage (from examspark_backend, with .env OPENROUTER + SUPABASE service role):

  python scripts/seed_pyq_embeddings.py

Safe to re-run: only rows with NULL embedding are updated.
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

# Allow `python scripts/seed_pyq_embeddings.py` from backend root
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.embedding_service import EmbeddingError, embed_texts
from app.services.supabase_admin import get_supabase_admin


async def main() -> int:
    force = "--force" in sys.argv
    sb = get_supabase_admin()
    query = sb.table("exam_pyqs").select("id,topic_label,exam,year,subject,chapter")
    if not force:
        query = query.is_("embedding", "null")
    res = query.execute()
    rows = list(res.data or [])
    if not rows:
        print("No rows need embeddings (all set or table empty).")
        print("Tip: re-write all vectors with: python scripts/seed_pyq_embeddings.py --force")
        return 0

    texts: list[str] = []
    ids: list[str] = []
    for r in rows:
        label = (r.get("topic_label") or "").strip()
        if not label:
            label = (
                f"{r.get('exam')} {r.get('year')} {r.get('subject')} {r.get('chapter')}"
            ).strip()
        if not label:
            print(f"Skip {r.get('id')}: no topic_label")
            continue
        texts.append(label)
        ids.append(str(r["id"]))

    if not texts:
        print("Nothing to embed.")
        return 0

    print(f"Embedding {len(texts)} PYQ topic label(s)…")
    try:
        vectors = await embed_texts(texts)
    except EmbeddingError as e:
        print(f"FAIL: {e}")
        return 1

    for i, row_id in enumerate(ids):
        vec = vectors[i]
        # Store as pgvector literal string for reliable RPC match
        literal = "[" + ",".join(str(float(x)) for x in vec) + "]"
        sb.table("exam_pyqs").update({"embedding": literal}).eq("id", row_id).execute()
        print(f"  OK {row_id[:8]}…")

    print("Done. Restart backend if needed, then smoke Home/Ask AI.")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
