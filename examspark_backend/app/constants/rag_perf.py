"""RAG retrieval tuning for Phase 1 performance (architecture unchanged)."""

# Default top-k; expand when best similarity is below expand threshold.
MATCH_COUNT_DEFAULT = 3
MATCH_COUNT_EXPAND = 5

# Expand when best cosine similarity is below this (aligns with MEDIUM band).
EXPAND_SIMILARITY_BELOW = 0.35

# Cap each chunk text sent to the LLM (chars).
CHUNK_MAX_CHARS = 1200

# Select AI (Phase 6) — selection-first, minimal RAG.
SELECT_MATCH_COUNT = 2
SELECT_CHUNK_MAX_CHARS = 800
SELECT_MAX_TOKENS = 384
