# Founder — Teacher Library (smoke + SQL)

**What it is:** Teacher’s **share bank** on **Teacher Dashboard → My Library**.

**Not the same as** the 5-tab **Library** (personal study for teacher + student).

| Surface | Purpose |
|---------|---------|
| Library tab + Study Workspace | Personal only — **no Share** |
| Teacher Dashboard → My Library | **Only** place to Share to groups |

**Rules (locked):**
- One lecture row = single source of truth (no copy when re-sharing)
- Share same lecture to **another** group = **free** (link only — no Whisper/Qwen, no credits)
- Same lecture + **same** group again = blocked → **“Already shared here”**
- No rate-limiter / spam score — unique DB index + group limits + Report button are enough
- Optional share **message** + **pin** on share sheet (see `FOUNDER_TEACHER_ANNOUNCE_SHARE_PIN.md`)

---

## 1. Manual SQL (required once)

1. Open **Supabase** → **SQL Editor** → New query  
2. Open file: `examspark_backend/teacher_library_share_unique_migration.sql`  
3. Copy all → Paste → **Run**  
4. Verify: last query should show index `uq_group_shared_items_class_lecture`

If you already have duplicate shares of the same lecture in one group, the script deletes extras (keeps oldest) before creating the unique index.

Also run `share_chips_picker_migration.sql` if chip share is used.

## 2. Restart / refresh

| What | Action |
|------|--------|
| Backend | If uvicorn is running with `--reload`, wait ~2s after Python save. Else stop + start again. |
| Flutter | Hot **restart** (`R` in terminal), not only hot reload |

---

## 3. Smoke tests

### A — Reuse across two groups (free)

1. Teacher account with active ₹2,999 + **two** Study Groups (e.g. Class 10A, Class 10B)  
2. **Record** one lecture → wait until notes ready  
3. Note credits balance (Credits pill)  
4. Teacher Dashboard → **My Library** → that lecture → **Share to group** → pick **10A**  
5. Confirm toast: shared free  
6. Open Group **10A** feed → lecture appears  
7. Credits **unchanged**  
8. My Library → same lecture → **Share to group** → pick **10B** only (10A hidden)  
9. Group **10B** feed shows same lecture  
10. Credits still **unchanged**  
11. Card shows: `Shared to: Class 10A, Class 10B`

### B — Duplicate blocked

1. My Library → same lecture → Share → **10A** should **not** appear in picker  
2. If you force share somehow (old build): expect **Already shared here** — no second feed row  

### C — Student Library unchanged

Student bottom tab **Library** still = personal student lectures only. Teacher Library is only under Teacher Dashboard.

---

## 4. .env

No new `.env` keys for this feature.

---

## Rollback (SQL only if needed)

```sql
DROP INDEX IF EXISTS uq_group_shared_items_class_lecture;
```

Do **not** drop unless founder asks — removing the index allows duplicate shares again.
