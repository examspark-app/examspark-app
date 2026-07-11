# ExamSpark — Data Storage Policy

> **Saved:** Jul 2026 — pre-Phase 2 documentation
> **Audience:** Founder (non-developer) + backend team
> **Rule:** Minimize cost. Store only what matters. Delete the rest.

**Companion:** [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) · [`TECH_STACK.md`](TECH_STACK.md)

---

## One-line summary

| Layer | Stores what | Simple analogy |
|-------|-------------|----------------|
| **Temporary** | Raw audio, scratch files | Kitchen prep bowl — throw after cooking |
| **Cloudflare R2** | Notes, PDFs, transcripts (files) | Filing cabinet for big documents |
| **PostgreSQL** | IDs, paths, credits, who owns what | Index cards — not the books themselves |
| **Vector DB** | Search chunks for Ask AI | Smart index for "find the right paragraph" |

**Never store raw lecture audio permanently** (unless teacher explicitly opts in).

---

## 1. Temporary Storage

**What:** Files that exist only while AI is working.

| Item | Why it exists | When deleted |
|------|---------------|--------------|
| **Raw audio** | Whisper needs the sound file to transcribe | **Immediately after** transcript is ready |
| **Temporary AI files** | Mid-step outputs (chunks, scratch JSON) | After that pipeline step finishes |
| **Temporary OCR files** | Image → text conversion workspace | After text is extracted |
| **Temporary upload cache** | Buffer while file moves to R2 | After permanent save succeeds |

**Why this layer exists:** AI needs raw input briefly. Keeping it wastes money (storage + privacy risk).

**Where (today vs target):**

| Today (interim) | Target |
|-----------------|--------|
| Supabase `temp-audio` bucket | Same pattern on R2 temp prefix, then delete |

**Exception — teacher only:**

```
Settings → ☐ Save Original Audio (default OFF)
```

If ON → move audio to R2 teacher folder instead of delete. Default = delete.

---

## 2. Permanent Storage — Cloudflare R2

**What:** All **user-visible files** and **AI outputs** that must survive.

R2 = cheap cloud file storage (like a hard drive in the cloud). **Big files live here, not in the database.**

### What we store in R2

| Asset | What it is | Why we keep it |
|-------|------------|----------------|
| **Transcript** | Full text from Whisper (user can re-read teacher's words) | Users need original explanation in Library |
| **Clean Transcript** | Same content, cleaned for search (no "umm", "dekho") | Better Ask AI without showing messy text |
| **Notes** | Structured AI notes (key points, concepts) | Main study material |
| **Summary** | Short overview | Quick revision |
| **Quiz** | Generated MCQ set | Practice tests |
| **Flashcards** | Front/back revision cards | Memorization |
| **Revision** | Exam-focused recap | Board/exam prep |
| **Formula Sheet** | Extracted formulas (future) | STEM subjects |
| **Mind Map** | Visual map data (future) | Visual learners |
| **Images** | Uploaded photos, diagrams | Source material + vision AI input |
| **PDFs** | Uploaded documents | Textbooks, notes PDFs |
| **Teacher Shared Files** | Files broadcast to a group | Group content delivery |

### What we NEVER store in R2 (default)

| Asset | Why not |
|-------|---------|
| **Raw lecture audio** | Large, privacy-sensitive, not needed after transcript — **delete** |

### R2 folder idea (simple)

```
R2
├── Users/{user_id}/Library/{lecture_id}/
│     ├── transcript.json
│     ├── clean_transcript.json
│     ├── notes.json
│     ├── summary.json
│     ├── flashcards.json
│     ├── quiz.json
│     └── ...
├── Teachers/{teacher_id}/Groups/{group_id}/
│     └── shared/...
└── Exports/   (PDF exports when built)
```

Postgres only stores **the path** to each file (e.g. `Users/abc/Library/lect12/notes.json`).

---

## 3. PostgreSQL (Supabase) — Metadata Only

**What:** Small structured records — **who, what, when, how much** — not the actual essay-length content.

### What we store

| Data | Why it exists |
|------|---------------|
| **User / Teacher profile** | Login, name, role, @username |
| **Groups** | Batch name, teacher, join code, description |
| **Group memberships** | Which student joined which batch, when |
| **Lecture metadata** | Title, subject, date, status (`processing` / `done`) |
| **R2 storage paths** | Pointer to each file in R2 |
| **Credits balance** | How many AI credits left |
| **Subscription** | Which plan, renew date, active/expired |
| **Payment history** | Transaction IDs, amounts (business records) |
| **Usage history** | Which AI action used how many credits |
| **Analytics** | Active students, opens, quiz completion counts |
| **Library metadata** | Folder name, favorite flag, last opened |
| **Permissions** | Who can see which group content |

### What we do NOT store in PostgreSQL

| Data | Why not |
|------|---------|
| **Audio files** | Too large — temp only |
| **PDF / image binaries** | Too large — R2 |
| **Full transcript text (at scale)** | Can be huge — R2 JSON; Postgres may hold snippet for search preview only |
| **Embeddings vectors** | Use pgvector tables separately, not mixed with user rows |

**Simple analogy:** Postgres = library **catalog card** (title, shelf number). R2 = the **actual book** on the shelf.

---

## 4. Vector Database (pgvector)

**What:** Small **chunks** of text converted to numbers (embeddings) so Ask AI can find the right paragraph.

### What we store ONLY

| Source | Why |
|--------|-----|
| **Clean Transcript chunks** | Backup search when Notes don't have the answer — without noisy filler words |
| **AI Notes chunks** | Primary search — structured, high quality |
| **Teacher Shared Notes chunks** | Answers for students in a group context |

### What we do NOT put in Vector DB

| Item | Why not |
|------|---------|
| **Raw audio** | Not text — cannot embed |
| **Raw PDF binary** | Extract text first → then chunk |
| **Raw image binary** | OCR/VL extracts text first → then chunk |
| **Duplicate chunks** | Cost rule: upsert by lecture + source — never duplicate vectors |

### How Ask AI uses it (order)

```
1. Search Notes chunks
2. If weak → Search Clean Transcript chunks
3. If weak → Search Teacher Shared chunks
4. If weak → Web Search (Tavily)
```

**Simple analogy:** Vector DB = smart **index at the back of a textbook**, not the whole textbook.

---

## 5. Data flow (one lecture)

```text
User records audio
        ↓
[TEMP] Raw audio file
        ↓
Whisper → Transcript text
        ↓
[TEMP] Audio DELETED ✓
        ↓
[R2] Save Transcript + Clean Transcript
        ↓
[VECTOR] Chunk + embed Clean Transcript + Notes
        ↓
[R2] Save Notes, Summary, Quiz, Flashcards…
        ↓
[POSTGRES] Save lecture row + R2 paths + credits used
        ↓
User sees in Library → Study Workspace
```

---

## 6. Cost & security rules

| Rule | Reason |
|------|--------|
| Delete temp immediately | Storage cost + privacy |
| One canonical Notes file per lecture | No duplicate R2 objects |
| No duplicate vectors | Re-index only when content changes |
| Students isolated | Cannot read another user's R2 paths |
| Group content gated | Server checks membership before R2 signed URL |
| Watermark on shared views | Trace leaks — metadata has `lecture_id` |

---

## 7. Current implementation vs policy

| Policy item | Code today |
|-------------|------------|
| Temp audio delete | Edge function deletes from `temp-audio` after Whisper |
| R2 permanent storage | **Not wired** — still Supabase interim |
| Postgres metadata only | Schema designed; **manual SQL run may be pending** |
| Clean transcript + vector chunks | **Not implemented** — basic `rag_documents` insert only |
| Teacher Save Original Audio | **Not implemented** |

**Target architecture:** [`TECH_STACK.md`](TECH_STACK.md)

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | DATA_STORAGE_POLICY.md — founder-friendly full policy |
