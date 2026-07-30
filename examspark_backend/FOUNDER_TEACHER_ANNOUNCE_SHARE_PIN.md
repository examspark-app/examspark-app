# Founder — Personal Library vs Teacher share + Announcement / Message / Pin

**Date:** Jul 25, 2026

## Rule (locked)

| Place | Who | Purpose |
|--------|-----|---------|
| **Library tab** + Study Workspace | Teacher + Student | **Personal** study only |
| **Teacher Dashboard → My Library** | Teacher only | **Share** to groups (chips + optional message + pin) |
| **Group Info** | Teacher | **Post announcement** (title + message + pin) |

- One lecture → one group once (“Already shared here”)
- Students: read only — no messages / no Generate

## What changed this slice

1. **Share button removed** from personal Study Workspace  
2. Share sheet: **Message (optional)** + **Pin to top** + chips  
3. Group feed shows message preview; tap lecture → see message → Open study  
4. Announcement flow unchanged (title + message + pin) — already on Group Info

## ⚠ Manual setup

### SQL (if not done)

Run `share_chips_picker_migration.sql` (for chip share).  
No new SQL for message/pin (`body` + `is_pinned` already exist).

### Restart

Hot restart Flutter + FastAPI if server was already running.

### .env

None new.

## 🧪 Test

1. Open lecture from **Library tab** → no Share icon  
2. Teacher Dashboard → **My Library** → Share → write message → Pin → Share  
3. Student Group feed → see message under title → Pin on top if pinned  
4. Tap share → dialog with message → Open study  
5. Group Info → **Post announcement** → message + pin → students see Announcement

## Rollback

- Re-enable Workspace Share only if founder asks (product mix again)
