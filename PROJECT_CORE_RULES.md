# ExamSpark — Project Core Rules

> **Saved:** Jul 2026 — founder `save all` (core rules)
> **Status:** MUST FOLLOW — architecture, backend, frontend, AI pipeline
> **Companion:** [`TECH_STACK.md`](TECH_STACK.md) · [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md) · [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md)

---

## 1. Data Storage Policy

**Status:** LOCKED Jul 16, 2026. Full spec: [`DATA_STORAGE_POLICY.md`](DATA_STORAGE_POLICY.md)

**Core principle:** Supabase = structured/searchable data. R2 = large files + exports + **temporary** audio staging only. Never mix roles. **Audio never stored permanently.**

### Cloudflare R2

| Role | Content |
|------|---------|
| **Temp only** | Raw audio — delete immediately after transcription (success or failure) |
| **Permanent** | Original PDF/image uploads, OCR output, clean transcript, full lecture notes (.md), exports (PDF/DOCX/PPT/ZIP), backups |

**Not in R2:** Flashcards, Quiz, Mind Map, Revision/Cheat Sheet **JSON/text** — Supabase. R2 only for **exports** of those.

### Supabase (Postgres + pgvector)

| Store | Examples |
|-------|----------|
| Structured JSON | Flashcards, Quiz, Mind Map (future), Revision/Cheat Sheet (future) |
| Short notes fields | Summary, key points, important terms (target; full notes still R2 today) |
| Metadata + paths | Users, lectures, credits, R2 path references, analytics |
| Vectors | Clean transcript chunks, AI notes chunks, teacher shared notes |

Never store large binaries in Postgres.

### Vector Database (pgvector) — embeddings only

**Store ONLY:**

- Clean Transcript chunks
- AI Notes chunks
- Teacher Shared Notes chunks

**Do NOT vectorize:** Raw Audio · Raw Images (binary) · Raw PDFs (binary)

PDF/image **text** may be extracted → Notes or Clean Transcript path → then chunked for vectors.

**RAG search order (never skip):** Notes → Clean Transcript → Teacher Shared → Web Search

**Search rule:** Supabase/pgvector/metadata first — never search R2 directly.

---

## 2. Teacher Group Rules

Teacher **owns** the group.

### Students CANNOT

- Upload anything
- Send messages
- Edit anything

### Teacher CAN

| Action | Allowed |
|--------|---------|
| Create / Delete / Rename Group | ✅ |
| Upload Lecture | ✅ |
| Upload PDF | ✅ |
| Upload Notes / Summary | ✅ |
| Upload Assignment / Homework | ✅ |
| Upload Quiz | ✅ |
| Pin posts | ✅ |
| Share Announcements | ✅ |

### Group UX requirements

- Teacher profile photo visible
- Teacher name always visible
- Group description supported
- Pinned announcement always on top of feed

---

## 3. Sharing Policy (Strict)

**Only Teacher can share content.**

### Students CANNOT

| Action | Blocked |
|--------|---------|
| Share PDF | ❌ |
| Share Notes | ❌ |
| Share Summary | ❌ |
| Share Transcript | ❌ |
| Forward files | ❌ |
| Export protected files | ❌ |
| Download protected files | ❌ (unless teacher enables) |
| Copy protected content | ❌ where technically possible |

### Students MAY

| Action | Allowed |
|--------|---------|
| **Share Group Invite Link only** | ✅ |

**Content sharing (Notes / PDF / Transcript) = never for students.**

Invite link sharing may cost **100 Credits** in future (configurable). Not live until configured.

**Piracy control:** Teacher content stays protected; invite grows group without content leakage.

---

## 4. Shared Content Watermark (Teacher)

Every teacher-shared lecture/file is automatically watermarked:

```
Shared by: {Teacher Name} • {Group Name}
```

**Internal linkage:** Every file tied to `lecture_id` (+ `teacher_id`, `group_id`).

If content leaks later → trace origin lecture, teacher, group. Legal + business protection.

Implement at export / student view render layer + metadata on R2 objects.

---

## 5. RAG Rules

Every AI answer **MUST** follow this priority. **Never skip order.**

| Priority | Source |
|----------|--------|
| **1** | User Notes |
| **2** | Transcript (Clean Transcript chunks in vector DB) |
| **3** | Teacher Shared Content |
| **4** | Web Search (Tavily) |

Only escalate to next tier if previous tier has insufficient context (confidence / retrieval threshold).

**Note:** User Library shows raw Transcript for re-read; RAG uses **Clean Transcript** embeddings (not noisy fillers).

PYQ database is **not** a RAG answer source — see §6.

---

## 6. PYQ Rules

PYQ Database must **NEVER** generate answers directly.

**Purpose:** Topic mapping only.

### Allowed (high semantic confidence only)

```
✓ Related: NEET 2024
✓ Related: JEE 2023
✓ Related: UPSC 2022
```

### Never display

- Original question text
- Original options
- Official answer key
- Original explanation

**Only exam reference tags.**

---

## 7. User Library

Every processed lecture **automatically** creates one library entry.

### One lecture = one container

| Included | Auto-saved |
|----------|------------|
| Transcript | ✅ |
| Notes | ✅ |
| Summary | ✅ |
| Flashcards | ✅ (when generated) |
| Quiz | ✅ (when generated) |
| Revision | ✅ (when generated) |
| Attachments | ✅ |
| Search index | ✅ (metadata + R2 pointers) |

Everything belongs to **one lecture** — no scattered orphans.

---

## 8. Cost Optimization

| Rule | Action |
|------|--------|
| Minimize storage | Temp purge; metadata in Postgres; blobs in R2 |
| Minimize AI cost | Reuse pipeline outputs; no redundant model calls |
| Minimize duplicates | One canonical Notes doc per lecture |
| Reuse RAG | Re-index only when content changes |
| Never duplicate vectors | Upsert by `lecture_id` + `source_type` + chunk hash |
| Never duplicate notes | Regenerate replaces prior version |

---

## 9. Security

| Rule | Enforcement |
|------|-------------|
| Student isolation | Cannot access another student's private library |
| Group isolation | Group content scoped to memberships |
| Teacher ownership | Teacher owns group content |
| Private library | Never searchable by other users |
| AI requests | Server-side permission check on every action |
| Sharing | Teacher-only content share; student invite-link only |

---

## 10. Future Proof (Modular Architecture)

| Layer | Replaceable |
|-------|-------------|
| AI models | Groq Whisper, Qwen3, Qwen3-VL → swap without UI change |
| Storage | R2 → another S3-compatible |
| Payments | Razorpay, Google Play → gateway interface |
| Vector DB | pgvector → dedicated service later |

**Never tightly couple** implementation to one vendor in business logic — use adapters/interfaces.

---

## Quick Reference

```
TEMP     → delete after processing (audio, OCR cache, upload cache)
R2       → notes, summary, flashcards, quiz, PDF, images, transcripts
Postgres → metadata only
Vectors  → clean transcript chunks + notes + teacher shared notes
RAG      → Notes → Transcript → Teacher Shared → Web
PYQ      → exam tags only, never answers
Share    → teacher content only; student invite link only
```

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Core rules v1 — storage, groups, sharing, RAG, PYQ, security, watermark |
