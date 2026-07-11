# ExamSpark — Features

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)
> **Product:** AI Study Platform · [`PRD.md`](PRD.md)

---

## Core Identity

| Is | Is NOT |
|----|--------|
| AI Study Platform | Notes-only app |
| Conversation + Study Workspace | ChatGPT clone |
| Teacher broadcast groups | WhatsApp chat app |
| Credits-only AI UX | Per-rupee AI pricing in UI |

---

## Must-Have (v1)

### Home — Chat

- [ ] ChatGPT-style conversation canvas
- [ ] Bottom input: Attachment · Record · Text · Send
- [ ] Top bar: Logo · Search · Credits · Notification · Profile
- [ ] One free Ask AI before signup
- [ ] Inline study block after lecture (no new screen)
- [ ] Anonymous → signup gate

### Study Workspace (hero)

- [ ] Tabs: Notes · Summary · Transcript · Flashcards · Quiz · Revision · Ask AI
- [ ] Desktop: right split panel
- [ ] Mobile: bottom sheet
- [ ] One lecture = all study inside

### Library

- [ ] Auto-save every lecture
- [ ] Folders (subjects) · Search · Recent · Favorites
- [ ] Tap → Study Workspace

### Groups

- [ ] Teacher: create, share, pin, announcements
- [ ] Student: read, quiz, Ask AI — no message, no upload
- [ ] WhatsApp feel, broadcast only
- [ ] Watermark: Shared by Teacher • Group
- [ ] Strict sharing: students invite-link only

### Ask AI / RAG

- [ ] Priority: Notes → Transcript → Teacher Shared → Web
- [ ] PYQ: exam tags only (NEET 2024, etc.) — never original Q/A

### Teacher

- [ ] Record / upload lecture
- [ ] Share to group
- [ ] Dashboard cards (students, revenue, credits, storage…)
- [ ] Save Original Audio toggle (default OFF)

### Student

- [ ] Library + groups + revision
- [ ] Progress tab
- [ ] Quiz / flashcards in workspace

### Account

- [ ] Profile: Subscription, Credits, Storage, Library Size, Settings, Help, Logout
- [ ] 5-tab nav only
- [ ] Plans + credit gating (v2 saved)

### Platform

- [ ] Flutter Android + Web + Desktop responsive
- [ ] iOS structure ready (App Store later)

---

## Nice-to-Have (architecture-ready)

- [ ] Mind Map
- [ ] Formula Sheet
- [ ] Translate
- [ ] Voice Read
- [ ] Important Questions in workspace `+` menu
- [ ] Global search across library + groups

---

## Future (documented, not built)

- [ ] Institute / multi-teacher admin role
- [ ] Invite link share = 100 credits (configurable)
- [ ] Hindi UI
- [ ] Offline flashcard download
- [ ] iOS App Store release
- [ ] NCERT / licensed books in RAG (licensing TBD)
- [ ] PYQ deep topic mapping (tags only, never answers)

---

## Explicitly NOT Building

- Student chat in groups
- Student content sharing (PDF/notes/transcript)
- Permanent raw audio (default)
- PYQ answer generation
- Colorful / gamified edu-app UI
- 6th bottom nav tab

See [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) · [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md)

---

## Implementation Status Legend

| Symbol | Meaning |
|--------|---------|
| [x] | Done (may be legacy scaffold — check roadmap) |
| [ ] | Not done / needs UX-arch alignment |
| 🔵 | Current phase |

Update this file when features ship or scope changes.
