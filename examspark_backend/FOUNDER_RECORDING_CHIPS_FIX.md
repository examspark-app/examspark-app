# Recording chips fix + Teacher exam-quality (Jul 26)

## What was fixed

### 1. Clear copy (recording ≠ Home free)
Recording / Study Workspace line:
**First generate uses credits · Reopen free · Regenerate AI = new result (credits)**

Home chips keep: Free from database · …

### 2. One generate path
Flashcards / Quiz / Revision **tabs** now use the same `/study-tools` API as chips (cache reopen free; Regenerate paid).

### 3. Credits + double-tap
- Chip sheet: `onCreditsUpdated` → `SessionLiveSync.refreshAll`
- Sheet blocks double Regenerate while in flight

### 4. Teacher high-quality Quiz / Important Qs
On **first AI generate** (paid — as you wanted):
- Match lecture topic to **PYQ bank metadata** (weightage = exam probability)
- Prompt: prefer high-weightage + strong notes topics **first**
- Still **original practice** only — never copy PYQ paper text

Restart **FastAPI** for #4. Flutter hot restart for 1–3.

## Manual setup

| Step | Action |
|------|--------|
| 1 | Restart FastAPI (`uvicorn` / your usual start) |
| 2 | Flutter hot restart (`R`) |
| 3 | Open recording → Quiz / Important Qs → first generate (credits) |
| 4 | Close & reopen → 0 credits |

No SQL / `.env` for this slice (PYQ bank must already exist for focus tags).

## Rollback
Revert `study_tool_copy.dart`, `study_workspace.dart`, `lecture_study_tool_sheet.dart`, `lecture_study_tools_service.py`, `qwen_service.py` quiz/IQ prompts.
