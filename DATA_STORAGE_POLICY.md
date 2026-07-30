# ExamSpark Storage Architecture Policy (Final — Locked)

> **Status:** LOCKED (Jul 16, 2026). All development must follow this unless explicitly changed by the founder.
> **Audience:** Founder + backend + Flutter team
> **Companion:** [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) · [`TECH_STACK.md`](TECH_STACK.md) · [`ARCHITECTURE.md`](ARCHITECTURE.md)

---

## Core Principle

Use the right storage for the right data. **Supabase is not a file store. Cloudflare R2 is not a database.** Never mix responsibilities.

**Audio is NEVER stored permanently anywhere** — this overrides any other instruction.

---

## Cloudflare R2 — Temporary Staging + Permanent Export Files Only

| Content | R2 Role |
|---|---|
| **Raw Audio** | **TEMPORARY ONLY** — staged during active transcription/chunking, deleted immediately (success or failure) the moment transcription completes. Never persists beyond that single processing window. |
| Original PDF/Image uploads (user-provided) | Permanent — kept as source reference |
| OCR Output (raw, large) | Permanent |
| Clean Transcript (.txt/.md) | Permanent |
| Full Lecture Notes (.md, large) | Permanent |
| Generated exports (PDF, DOCX, PPT, ZIP) | Permanent |
| Backup files | Permanent |

**Critical:** Audio is the one exception to "R2 = permanent" — it is explicitly temporary, deleted right after transcription. Everything else listed above in R2 is a legitimate large file that can stay permanently.

**Do NOT store in R2:** Flashcards JSON, Quiz JSON, Mind Map JSON, Revision/Cheat Sheet text (structured) — these live in Supabase. R2 holds **export files** of those features when the user exports to PDF/image.

---

## Supabase (Postgres + pgvector) — Structured, Searchable Data Only

| Content | Notes |
|---|---|
| Users, Teacher Accounts, Student Accounts | |
| Lecture Metadata (title, subject, date, R2 file paths) | |
| Credits, Plans, Purchases | |
| Chat History / Saved Conversations / Bookmarks | Only if user explicitly saves/bookmarks (see Home AI rule below) |
| Flashcards (JSON) | `extras.payload_json` |
| Quiz (JSON) | `extras.payload_json` |
| Mind Map (structured JSON) | Future — Supabase |
| Revision Sheet / Cheat Sheet (Markdown, short) | Future — Supabase |
| Important Questions | Future — Supabase |
| PYQ Metadata (never the actual copyrighted paper text unless licensed) | |
| AI Analytics: token usage, AI cost, confidence score, processing status | |
| Embeddings (pgvector) | |
| R2 File Paths, file size, content type, checksum, created date | Reference only — never duplicate the actual large file in Postgres |

**Short notes** (summary, key points, important terms) → Supabase.  
**Full/large lecture notes** (complete markdown document) → R2, with metadata (title, R2 path, word count) in Supabase.

Never store large binary files inside Postgres.

---

## RAG Architecture Flow

```text
Lecture Audio
  → R2 (temporary staging)
  → Groq Whisper transcription
  → Clean Transcript (saved to R2 permanently as .txt/.md; audio deleted from R2 now)
  → Chunk transcript
  → Generate embeddings
  → Store embeddings in Supabase pgvector
  → [User asks a question]
  → Similarity search in pgvector (never search R2 directly)
  → Retrieved context + question → Qwen3/Qwen3-VL
  → Answer
```

**RAG always searches pgvector, never R2 directly.**

---

## Feature-by-Feature Save Rules

### Home AI (general chat, not tied to a specific lecture)

Do **NOT** auto-save every response. Save only if the user bookmarks, pins, explicitly saves the conversation, or has auto-history enabled.

### Ask AI (RAG, lecture/PYQ-grounded)

Store: user question, AI answer, timestamp, lecture ID, answer source, confidence score, credits used — all in Supabase.

Do **NOT** store the retrieved chunks themselves (they're regenerable from pgvector on demand).

### Flashcards / Quiz / Mind Map

Store the structured JSON in **Supabase**. If the user exports to PDF/image, that export file goes to **R2**.

### Revision Sheet / Cheat Sheet

Markdown/text version in **Supabase**. PDF export goes to **R2**.

### Notes

| Part | Where |
|------|--------|
| Short notes (summary, key points, important terms) | Supabase |
| Full/large lecture notes (complete markdown) | R2 + metadata in Supabase |

### PYQ

Only metadata (exam name, year, topic tags, similarity embedding) in Supabase. Never store the actual copyrighted question-paper text/scans unless properly licensed.

---

## Search Rule

All searching happens: **Supabase → pgvector → metadata**. Never search R2 directly — R2 is fetched only when the actual file content needs to be displayed/downloaded, after the relevant record is already found via Supabase.

---

## Scalability Rule

| Data type | Store |
|-----------|--------|
| Small, searchable, frequently-queried | Supabase |
| Large, occasionally-downloaded files | Cloudflare R2 |

---

## Final Rule

| System | Role |
|--------|------|
| **Supabase** | Structured data + search + metadata + analytics + chat + RAG embeddings |
| **Cloudflare R2** | Large files + full notes + PDFs + temporary audio staging + exports |
| **Audio** | Sole R2 exception: staged temporarily, deleted immediately after transcription — **never permanent** |

Never use one system for the other's purpose.

---

## Implementation status (Jul 16, 2026)

| Policy item | Code today |
|-------------|------------|
| Flashcards JSON → Supabase | **Done** — `extras.payload_json` |
| Quiz JSON → Supabase | **Done** — `extras.payload_json` |
| Legacy extras `r2_path` | Backfill on read; new generates skip R2 |
| Full notes + transcript → R2 | **Done** (Session 2/4 pipeline) |
| Short notes split → Supabase | **Done** — `notes.clean_notes`, `notes.short_summary`, `notes.key_points`, `notes.important_terms` |
| Revision JSON → Supabase | **Done** — `extras.payload_json` (+ optional `visualPayload`) |
| Visual payload (graphs/diagrams) → Supabase | **Done** — `notes.visual_payload_json`; Ask/Home AI `done.visual_payload` |
| Mind Map → Supabase | **Done** — `extras.payload_json` |
| Home AI save-on-bookmark only | **Not built** — superseded by Phase 4D lock (full Study History); see [`FOUNDER_PHASE4D_HOME_HISTORY.md`](examspark_backend/FOUNDER_PHASE4D_HOME_HISTORY.md) |
| Phase 4C master response + chip cache | **Done** — `home_ai_responses` / `home_ai_tools` (building block for 4D sessions) |
| Phase 4D sessions + history UI | **Future** — after 4C smoke + `start Phase 4D` |
| Audio temp R2 staging | In-memory today; temp R2 when chunking added |
| Raw audio never permanent | **Enforced** (delete after Whisper) |

Migration for Flashcards/Quiz column: [`examspark_backend/extras_payload_json_migration.sql`](examspark_backend/extras_payload_json_migration.sql)
Migration for short notes columns: [`examspark_backend/notes_short_supabase_migration.sql`](examspark_backend/notes_short_supabase_migration.sql)
Migration for visual payload: [`examspark_backend/notes_visual_payload_migration.sql`](examspark_backend/notes_visual_payload_migration.sql)

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Initial founder-friendly DATA_STORAGE_POLICY.md |
| Jul 16, 2026 | **Smart Subject Understanding Rule** — expanded per-subject visual decision (Math through English, Economics, CS); teacher-like “text alone vs visual” gate in all Qwen prompts |
