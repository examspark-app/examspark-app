# Founder — Home AI chips for recording (Study Workspace)

**Date:** Jul 25, 2026  
**Goal:** Same study chips as Home, but **generate from this recording’s notes** (credits on first generate / Regenerate). Then teacher can **Share** those chips to a group.

---

## What you get

| Place | Behavior |
|--------|----------|
| **Study Workspace** (owner) | Chip row under title: Quiz · Flashcards · Revision · Learn More · Important Qs · More… |
| **Tap chip** | Opens sheet → generates from **lecture notes** (not Home chat) → saves to lecture |
| **Credits** | Charged on first generate & Regenerate (e.g. Quiz 5, Mind Map 30, Important Qs 20) |
| **Reopen** | Free (cached) |
| **Student (shared)** | Read / answer only — no chips / no Generate |

---

## ⚠ Manual setup

### 1) Share chips SQL (if not done yet)

Run `examspark_backend/share_chips_picker_migration.sql` in Supabase SQL Editor  
(needed so generated chips can be shared to groups).

### 2) Restart FastAPI

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 3) Hot restart Flutter

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter run -d chrome --web-port=8080
```

### .env

No new keys.

---

## 🧪 How to test

1. Open a **done** recorded lecture (or `TEST — Sample Lecture`)
2. See chip row under the title
3. Tap **Important Qs** or **Mind Map** (or More → Memory)  
4. **Expected:** sheet generates from notes; credits deducted; reopen = free  
5. **Share to Group** → those chips appear in the picker when generated  
6. Student opens share → can read chip tabs; **no** Generate chips

### Rollback

- UI only: hide chip bar by reverting Study Workspace (no SQL drop needed)  
- API routes can stay unused safely

---

## Cost reminder (recording ≠ Home free-first-open)

Home first chip open = free from Knowledge Object.  
**Recording** first generate = paid (same CREDIT_ECONOMY as Flashcards / Quiz / Mind Map / etc.).
