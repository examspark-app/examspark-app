# Founder — Teacher Dashboard cards (Jul 26, 2026)

**Start phrase:** `start teacher dashboard cards`

## What changed

| Card | Status |
|------|--------|
| Students | Live (all joins) |
| Active today | Live (24h heartbeat) |
| **Subscribers** | **Live** — paid students only, primary teacher = most recent Group join |
| Est. Commission | Live — **30%** of those paid plans (display-only, no payout) |
| Credits | Live |
| Groups | Live |
| Revenue | **Upcoming** (placeholder) |
| Analytics | **Upcoming** (Storage card removed) |

Free group joins → Students only. Paid attributed students → Subscribers + Est. Commission.

## Manual setup (required)

1. Open **Supabase → SQL Editor → New query**
2. Open file: `examspark_backend/teacher_subscriber_count_migration.sql`
3. Copy all → Paste → **Run**
4. Verify (replace email if needed):

```sql
SELECT public.fn_teacher_subscriber_count(u.id) AS subscribers,
       public.fn_teacher_estimated_commission(u.id) AS est_commission_inr
FROM public.users u
WHERE lower(u.email) = lower('soniabuddy73@gmail.com');
```

5. Flutter: hot restart (or `flutter run -d chrome --web-port=8080`)
6. Profile → Teacher Dashboard → Business Overview

**.env:** none new.

## How to test

| Step | Expected |
|------|----------|
| No paid students in your groups | Subscribers `0`, Est. Commission `₹0` |
| Student joins + has active paid plan (₹199+) + your group is their latest | Subscribers ≥ 1, Est. Commission > 0 |
| Storage card | Gone |
| Revenue / Analytics | `—` + badge **Upcoming** |

## Rollback

```sql
DROP FUNCTION IF EXISTS public.fn_teacher_subscriber_count(UUID);
```

UI: revert `teacher_dashboard_screen.dart` cards if needed.

## Files

- SQL: `teacher_subscriber_count_migration.sql`
- Flutter: `teacher_dashboard_screen.dart`, `supabase_client.dart`, `groups_repository.dart`
- Docs: `TEACHER_PLATFORM.md` §6 · `FOUNDER_SQL_ORDER.md` step P
