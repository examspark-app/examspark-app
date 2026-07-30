# Founder — Teacher Coupon (first-month free)

> Jul 23, 2026 — Slice 1 · Architecture lock Jul 25, 2026 (one group, two join paths).

## Core concept

**One group** (e.g. Class 10A Physics). Two entry paths into the **same** `class_memberships` row set:

| Path | How | Gate | Tag |
|------|-----|------|-----|
| **Paid** | Share link / QR (`join_code`) | Paid plan + free slot (1/3/6) or paywall | `join_type=paid` |
| **Coupon** | Separate “Enter coupon” UI | Group-scoped code, max 100, no payment | `join_type=coupon` |

Coupon does **not** create a second group.

## Coupon rules

- Teacher generates coupon for **one** group (max **100** students).
- Redeem → join without payment; **bypasses** paid group-slot limit; **no commission**.
- Credits: Free account already has **50/month** at signup — coupon does **not** add another 50.
- After 30 days: student **stays** in group; content **read-only/locked** + upgrade prompt (not removed).

## Manual SQL (required)

1. If not done: [`teacher_coupon_migration.sql`](teacher_coupon_migration.sql)  
2. **Then run:** [`group_join_paths_architecture_migration.sql`](group_join_paths_architecture_migration.sql)  
   - Adds `join_type`  
   - Paid slots ignore coupon members  
   - Expired coupon → `fn_group_item_access` read_only/locked  

Supabase → SQL Editor → paste → Run.

## Smoke

1. Restart backend + Flutter **`R`**  
2. Teacher: Share link / QR → Free student → **paywall** (not coupon)  
3. Teacher: Generate Coupon → Free student → Groups → **Coupon** → join same group  
4. Teacher member list: both paid + coupon students; coupon tagged  
5. After `access_ends_at` (or test SQL): coupon student opens feed item → locked / upgrade  

## Related

- Discovery · Notifications · [`FOUNDER_FCM_SETUP.md`](FOUNDER_FCM_SETUP.md)
