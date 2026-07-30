# Founder — Student profile: no Skip + Edit profile

**Date:** Jul 26, 2026  
**No new SQL** · Hot restart Flutter only

## What changed

| Before | After |
|--------|--------|
| Role screen had **Skip** | Must pick **Student** or **Teacher** |
| Student form had **Skip** | No Skip — minimum required |
| Profile had no student edit | Students: **Edit profile** row |
| — | **No** “Become Teacher” on Profile for normal users |

### Minimum (student)

- Username  
- Education level  
- Preferred language (or Custom…)  
- At least **1** subject  

Optional: exam / board, city. Age has a default wheel.

Teachers still: signup → I’m a Teacher → Teacher Dashboard only.

## Manual setup

1. Hot restart Flutter (`R` or restart `flutter run`)
2. No SQL · no `.env`

## Smoke

1. New signup → **no Skip** on role screen → I’m a Student  
2. Finish Setup without username → error toast  
3. Fill minimum → app opens  
4. Profile → **Edit profile** → change subject → Save → name/subjects stick  
5. Teacher account → Profile shows Teacher Dashboard, **not** student Edit  

## Already-skipped old accounts

They stay in app. Use **Profile → Edit profile** to fill minimum (Discover match improves).

## Rollback

Revert Flutter files for onboarding + `profile_tab.dart`.
