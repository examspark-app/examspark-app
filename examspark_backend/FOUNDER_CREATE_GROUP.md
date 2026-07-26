# Founder — Create Study Group (v1–v4)

Locked: [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md) §5

## Paid vs Free — join approval (saved Jul 23, 2026)

| Student | Approve group | Auto group |
|---------|---------------|------------|
| Free | **Pending** → teacher Accept/Reject | Instant (if join limit allows) |
| Paid ₹199/499/999 | **Always Auto** — no Pending | Instant |
| Institute bulk / kick | Future | Future |

Join **count** limits unchanged (Free=0, 199=1, 499=3, 999=6).

**Code:** SQL ready — run [`paid_auto_skip_pending_migration.sql`](paid_auto_skip_pending_migration.sql) after v2.

---

## Status

| Slice | Status |
|-------|--------|
| **v1** Name · Subject · Class/Exam/Language · Private/Public · code + link | Coded |
| **v2** Auto vs Teacher Approval + Pending Accept/Reject | Coded — SQL done |
| **Paid skip Pending** | Coded — run [`paid_auto_skip_pending_migration.sql`](paid_auto_skip_pending_migration.sql) |
| **v3 QR** | Coded — Create success + Dashboard **QR** button (screenshot / any scanner). No new SQL |
| **v4** Per-group dashboard | **Coded** — Members · Pending · Invite/QR · activity · Open feed. No new SQL |
| **Analytics v1** | **Coded** — Analytics card: Members · Active today · Notes · Quizzes. No new SQL |
| **Analytics v2** | **Coded** — Members: last active + quiz % (shared lectures). API + Flutter. No new SQL |
| **Analytics v3** | **Coded** — Week/Month toggle (active + quiz %). No new SQL |
| **Analytics v4** | **Coded** — Top lecture by quiz attempts (week/month). No new SQL. A1–A4 done |

## Manual setup — run SQL in order

### A. If not done yet — v1 columns

[`create_study_group_v1_migration.sql`](create_study_group_v1_migration.sql)

### B. v2 approval (required)

[`create_study_group_v2_approval_migration.sql`](create_study_group_v2_approval_migration.sql)

**Verify:** `join_approval_mode` + `group_join_requests`

### C. Paid skip Pending (required for this rule)

[`paid_auto_skip_pending_migration.sql`](paid_auto_skip_pending_migration.sql)

**Verify:** `has_paid_skip` = true  

Tell CTO: **SQL paid skip pending done**

### D. Flutter (v4 + Analytics v1–v4)

Hot restart (**R**). **Restart FastAPI**. No new `.env`. No new SQL for Analytics v1–v4.

**Smoke Analytics v3–v4**
1. Analytics → **Week** / **Month**  
2. Active + Avg quiz + member % switch  
3. **Top lecture** row: title + attempts · students (or empty hint if no quiz attempts)  
4. Share quiz + student attempt → Refresh → top lecture title appears  

**Note:** Top lecture = most **quiz attempts** on shared lectures (honest proxy). True “most opened” needs a future open-count — not built.

Analytics A1–A4 complete. Optional later: open-count tracking / Assignments.

---

## How to test paid skip

1. Teacher: Create Group → **Approve**  
2. **Paid** student (₹199+) joins with code → **instant member** (no Pending)  
3. **Free** student joins same group → **Pending** → teacher Accept  

## How to test v2 (Free Pending)

1. Teacher → Create Group → **Approve** → Create  
2. Free student → Join with code → “waiting for teacher approval”  
3. Teacher → **Pending requests** → **Accept**  
4. Student opens group  

## Rollback (v2 only)

```sql
DROP FUNCTION IF EXISTS fn_request_or_join_group(UUID);
DROP FUNCTION IF EXISTS fn_accept_group_join_request(UUID);
DROP FUNCTION IF EXISTS fn_reject_group_join_request(UUID);
DROP TABLE IF EXISTS group_join_requests;
ALTER TABLE class_folders DROP COLUMN IF EXISTS join_approval_mode;
```
