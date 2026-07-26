# Ask AI — Speed + Question Language (Jul 26, 2026)

## What changed

### 1. Language (English Q → Hindi A bug)
- Clear **English** questions (e.g. chip *Explain the main idea…*) now resolve to **ENGLISH**, not weak `MATCH_QUESTION`.
- Answer language = **question language** (Hindi / Hinglish / Bengali / Japanese / …).
- Explicit switch still works: `english main baat karo`, `bengali mein`, `answer in Japanese`, etc.
- Notes/transcript language must **not** leak into the answer (facts may be translated).

### 2. Speed
- Removed **double** RAG index call on every Ask.
- Credit check + RAG retrieve run **in parallel**.
- Warm-indexed lectures skip an extra DB count query.
- Study Workspace **warms** `/lectures/{id}/index` when the lecture opens (free, no credits) so the first Ask is faster.

## Founder test (local)

1. **Restart FastAPI** (backend must reload).
2. Flutter: hot **restart** (`R`) on `localhost:8080`.
3. Open **TEST — Sample Lecture** → wait ~2s (index warms quietly).
4. **Ask AI** → tap *Explain the main idea in simple words*.
5. **Expect:** answer in **English** (not Hindi), even if notes are Hindi.
6. Type: `hindi mein batao` → next answer Hindi.
7. Type: `english main baat karo` → back to English.
8. Feel: first token should arrive sooner than before (especially 2nd+ Ask on same lecture).

## Manual setup

- **No new SQL**
- **No new .env**
- Restart FastAPI after pull

## Rollback

Revert:
- `app/constants/language_hint.py`
- `app/services/rag_ask_service.py`
- `app/services/rag_index_service.py`
- `lib/core/services/lecture_service.dart` (`warmLectureRagIndex`)
- `lib/presentation/widgets/study_workspace.dart` (warm call)
