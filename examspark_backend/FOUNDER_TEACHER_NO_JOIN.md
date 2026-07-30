# Teacher ₹2,999 — own Groups only (no join)

## Rule (founder Jul 26, 2026)

Teacher plan user:
- ✅ Create / manage **own** Groups (Dashboard)
- ✅ Share, invite, analytics on **own** groups
- ❌ **Cannot join** another teacher’s Group as a student
- ❌ No student join actions (code / Discover / invite link as member)

Students who want to join need **₹199 / ₹499 / ₹999** (or Free+coupon where allowed).

---

## Code + SQL

| Layer | Change |
|-------|--------|
| Flutter | `teacher` `maxGroups = 0` · `canJoinAnotherGroup` blocks · sheet message |
| SQL | [`teacher_no_join_groups_migration.sql`](teacher_no_join_groups_migration.sql) — `max_groups=0` + RPC block |

## Manual setup (founder)

1. Supabase → SQL Editor → run **`teacher_no_join_groups_migration.sql`**
2. Expect: `max_groups = 0` for teacher
3. Flutter hot restart (`R`)
4. Smoke: Teacher account → try Join code of another group → blocked sheet → Dashboard button

No `.env`.
