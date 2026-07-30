# Founder — Teacher Setup Gate (updated Jul 25, 2026)

Spec: [`TEACHER_PLATFORM.md`](../TEACHER_PLATFORM.md) §1b · Price: [`CREDIT_ECONOMY.md`](../CREDIT_ECONOMY.md)

## Do not mix

| | Get Verified | Profile certificate |
|---|--------------|---------------------|
| What | **AI** soft verify → Trusted badge | Simple PDF/photo on profile |
| For | Unlock buy → Create Group | Students (teacher choice) |
| Gate? | **Yes** | **No** |

## Locked flow (hard — no skip)

1. **Full profile** — Name + Subject(s) + City + State + Qualification  
2. **Get Verified (AI)** → unlocks Teacher plan  
3. **Buy Teacher ₹2,999** → unlocks Create Group  
4. **Create Group**

Optional forever: Experience, Bio, Social links, profile photo, **profile certificates** (+ **Show on profile** ON/OFF, default OFF).

## When Teacher ₹2,999 month ends (lock **B** + share)

- **Lock:** live Record · **new** Create Group · **Share workspace** (lecture/notes/quiz/announce/pin) · Discover/Suggest/Search  
- **Keep:** existing Groups + students + old shared posts · invite link OK  
- Renew plan → unlock again  

## Student month-end

- **Coupon join:** stay in group · content locked/read-only · upgrade prompt  
- **Paid join:** Free tier · no new joins · trim toward Free caps  

## Manual setup (price in Supabase)

[`teacher_plan_2999_migration.sql`](teacher_plan_2999_migration.sql)  
Verify `price_inr_paise` = **299900** for `teacher`

Verification SQL: [`teacher_verification_v1_migration.sql`](teacher_verification_v1_migration.sql)

## Smoke (Flutter R)

1. Profile complete → checklist shows **Get Verified (AI)** next (Buy plan disabled)  
2. Get Verified → Trusted badge  
3. Buy plan enables → mock/real Teacher ₹2,999  
4. Create Group opens  
5. Profile certificate optional — Create Group still works without it  

## Entry

Teacher Dashboard via Profile / Home school icon (not a 6th tab).
