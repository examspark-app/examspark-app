# Founder — Share chips picker (All / specific)

**Date:** Jul 25, 2026  
**Goal:** Teacher shares **already generated** chips to a group (free link). Students **read / answer only** — no Generate.

---

## What you get

| Actor | Behavior |
|--------|----------|
| **Teacher** | Share sheet: **All generated chips** or pick Notes / Quiz / Flashcards / Revision / Mind Map / etc. |
| **Student** | Opens Study Workspace with **only those chips**; Generate / Share / Ask AI hidden |

Same lecture → same group still blocked (“Already shared here”).

---

## ⚠ Manual setup (required once)

### 1) Run SQL in Supabase

1. Open **Supabase** → your project → **SQL Editor**
2. Open file: `examspark_backend/share_chips_picker_migration.sql`
3. Copy all → paste → **Run**
4. Verify result shows column `shared_chips` on `group_shared_items`

### 2) Restart FastAPI (so share API knows `shared_chips`)

In PowerShell:

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 3) Hot restart Flutter (Chrome)

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter run -d chrome --web-port=8080
```

### .env

No new `.env` keys for this feature.

---

## 🧪 How to test

1. Teacher: open a **recorded** lecture in Study Workspace  
2. Generate at least Notes + Quiz (or use **TEST — Sample Lecture** seed)  
3. Tap **Share to Group** → see chip checkboxes → leave **All** or uncheck some → Share  
4. Student (or second account): open that Group → tap the share  
5. **Expected:** only selected tabs appear; no Generate / no Ask AI  
6. Share same lecture again to same group → **Already shared here**

### Rollback

- SQL: `ALTER TABLE public.group_shared_items DROP COLUMN IF EXISTS shared_chips;`  
  (old app builds ignore the column; new builds treat missing chips as legacy “all tabs except Ask AI”)

---

## Files (coded)

- `share_chips_picker_migration.sql`
- `teacher_performance_service.py` / `groups.py` — `shared_chips` on share
- `share_to_group_sheet.dart` — All / specific picker
- `share_chip_catalog.dart` · `class_service.listShareableChips`
- `study_workspace.dart` — `allowedChips` + read-only
- `group_info_screen.dart` — pass chips to workspace
