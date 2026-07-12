# ExamSpark - Phase 1B Core Low-Fidelity Wireframes

> Status: Draft for founder approval
> Scope: UX planning only
> Hard rule: No Flutter code, no widgets, no navigation implementation

This file keeps Phase 1B focused on core wireframes. The screens are grouped into 8 core UX areas, but every screen requested by the founder is covered.

---

## Core UX Groups

1. App Entry: Splash, Login, Signup
2. Home and Capture: Home, Recording, Upload
3. Study Workspace: Study Workspace, Notes, Summary, Flashcards, Quiz
4. Library: Library
5. Groups: Groups, Group Information, Join/Leave flows, Create Group
6. Teacher: Teacher Dashboard, Teacher Profile
7. Account: Profile, Subscription, Credits, Settings
8. Progress: Progress

---

## Screen 1 - Splash

Purpose: Show brand while app checks login/session state.

Mobile Wireframe:

```text
+------------------------------+
|                              |
|                              |
|            LOGO              |
|          ExamSpark           |
|                              |
|        Loading...            |
|                              |
+------------------------------+
```

Desktop Wireframe:

```text
+--------------------------------------------------+
|                                                  |
|                                                  |
|                    LOGO                          |
|                  ExamSpark                       |
|                                                  |
|                  Loading...                      |
|                                                  |
+--------------------------------------------------+
```

UX Notes: No header, no bottom navigation, no FAB, no popup. Auto moves to Login/Signup or Home.

---

## Screen 2 - Login

Purpose: Existing Supabase login entry. UI planning only, auth logic must stay unchanged.

Mobile Wireframe:

```text
+------------------------------+
|          ExamSpark           |
|                              |
|  Email                       |
|  [________________________]  |
|                              |
|  Password                    |
|  [________________________]  |
|                              |
|  [ Log In ]                  |
|  [ Continue with Google ]    |
|                              |
|  New here? Sign up           |
+------------------------------+
```

Desktop Wireframe:

```text
+--------------------------------------------------+
|                                                  |
|                 ExamSpark                        |
|                                                  |
|             +----------------------+             |
|             | Email                |             |
|             | [________________]   |             |
|             | Password             |             |
|             | [________________]   |             |
|             | [ Log In ]           |             |
|             | [ Continue Google ]  |             |
|             | New here? Sign up    |             |
|             +----------------------+             |
+--------------------------------------------------+
```

UX Notes: No bottom navigation before auth. Login success moves to Home. Signup link opens Signup.

---

## Screen 3 - Signup

Purpose: Create account using existing Supabase signup flow. UI only.

Mobile Wireframe:

```text
+------------------------------+
|          ExamSpark           |
|                              |
|  Full name                   |
|  [________________________]  |
|  Email                       |
|  [________________________]  |
|  Password                    |
|  [________________________]  |
|                              |
|  [ Create Account ]          |
|  [ Continue with Google ]    |
|                              |
|  Already have account? Login |
+------------------------------+
```

Desktop Wireframe:

```text
+--------------------------------------------------+
|                                                  |
|                 ExamSpark                        |
|                                                  |
|             +----------------------+             |
|             | Full name            |             |
|             | [________________]   |             |
|             | Email                |             |
|             | [________________]   |             |
|             | Password             |             |
|             | [________________]   |             |
|             | [ Create Account ]   |             |
|             | Already login?       |             |
|             +----------------------+             |
+--------------------------------------------------+
```

UX Notes: No bottom navigation before auth. Signup success moves to Home.

---

## Screen 4 - Home

Purpose: Main AI conversation screen. User asks, records, uploads, and receives study output inline.

Mobile Wireframe:

```text
+------------------------------+
| Logo   Search  Credits  Bell |
+------------------------------+
|                              |
|     Ask anything or record   |
|          a lecture           |
|                              |
|  AI conversation appears     |
|  here after first action     |
|                              |
+------------------------------+
| Attach  [Type message] Mic Send |
+------------------------------+
| Home Library Groups Progress Profile |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Logo   [ Search lectures/groups ]       Credits  Bell  Profile |
+----------+-----------------------------------------------------+
| Home     |                                                     |
| Library  |             Conversation column                     |
| Groups   |                                                     |
| Progress |        Ask anything or record a lecture             |
| Profile  |                                                     |
+----------+-----------------------------------------------------+
|          | Attach  [Type message................]  Mic  Send   |
+----------+-----------------------------------------------------+
```

UX Notes: Header has logo, search, credits, notification, profile. Bottom input stays sticky. No separate FAB because mic/send are in the bottom input. Upload Options popup opens from Attach. Recording starts from Mic.

---

## Screen 5 - Recording

Purpose: Start and monitor lecture recording from Home without breaking the conversation flow.

Mobile Wireframe:

```text
+------------------------------+
| Logo   Search  Credits  Bell |
+------------------------------+
|                              |
|       Recording lecture       |
|                              |
|          00:12:45             |
|                              |
|      [ Pause ] [ Stop ]       |
|                              |
|   Subject: Physics            |
|   Topic: optional             |
|                              |
+------------------------------+
| Home Library Groups Progress Profile |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Logo   [ Search ]                         Credits Bell Profile |
+----------+-----------------------------------------------------+
| Nav rail |                                                     |
|          |              Recording lecture                      |
|          |                 00:12:45                            |
|          |              [ Pause ] [ Stop ]                     |
|          |                                                     |
|          | Subject: Physics     Topic: optional                |
+----------+-----------------------------------------------------+
```

UX Notes: Opens from Home mic button. Stop returns result inline on Home as Notes/Summary card. No new bottom tab. No FAB.

---

## Screen 6 - Upload

Purpose: Upload PDF, image, audio, or document into the AI study flow.

Mobile Wireframe:

```text
+------------------------------+
| Upload content                |
+------------------------------+
|                              |
|  [ PDF Document ]             |
|  [ Image / Photo ]            |
|  [ Audio File ]               |
|  [ Cancel ]                   |
|                              |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Home input attach menu                                          |
|                                                                 |
|             +----------------------------+                      |
|             | Upload content             |                      |
|             | [ PDF Document ]           |                      |
|             | [ Image / Photo ]          |                      |
|             | [ Audio File ]             |                      |
|             | [ Cancel ]                 |                      |
|             +----------------------------+                      |
+----------------------------------------------------------------+
```

UX Notes: Mobile appears as bottom sheet from Home attachment button. Desktop appears as anchored popup/dropdown. Upload result returns to Home conversation and then Study Workspace.

---

## Screen 7 - Study Workspace

Purpose: One lecture's full study area. Same workspace opens from Home, Library, and Groups.

Mobile Wireframe:

```text
+------------------------------+
| Drag handle                   |
| Lecture title                 |
| Teacher / Subject / Date      |
+------------------------------+
| Notes Summary Transcript      |
| Flashcards Quiz Revision Ask  |
+------------------------------+
|                              |
| Active tab content            |
|                              |
|                              |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Logo   [ Search ]                         Credits Bell Profile |
+----------+--------------------------+--------------------------+
| Nav rail | Conversation stays here  | Study Workspace          |
|          |                          | Lecture title            |
|          |                          | Notes Summary Transcript |
|          |                          | Flashcards Quiz Revision |
|          |                          | Active tab content       |
+----------+--------------------------+--------------------------+
```

UX Notes: Mobile is bottom sheet. Desktop is right split panel. Tabs change content in place. No separate quiz/notes pages from the user's point of view.

---

## Screen 8 - Notes

Purpose: Show clean AI notes for one lecture inside Study Workspace.

Mobile Wireframe:

```text
+------------------------------+
| Study Workspace header        |
+------------------------------+
| Notes Summary Transcript ...  |
+------------------------------+
| Notes                         |
| - Heading                     |
| - Key explanation             |
| - Important formula           |
| - Exam point                  |
|                              |
| [ Ask AI about this ]         |
+------------------------------+
```

Desktop Wireframe:

```text
+--------------------------+-------------------------------+
| Conversation             | Study Workspace                |
|                          | Notes tab active              |
|                          | - Heading                     |
|                          | - Explanation                 |
|                          | - Formula                     |
|                          | [ Ask AI about this ]         |
+--------------------------+-------------------------------+
```

UX Notes: Notes is a tab inside Study Workspace, not a separate route. Ask AI may trigger Credits Low or Plan Locked popup.

---

## Screen 9 - Summary

Purpose: Provide short lecture recap inside Study Workspace.

Mobile Wireframe:

```text
+------------------------------+
| Study Workspace header        |
+------------------------------+
| Notes Summary Transcript ...  |
+------------------------------+
| Summary                       |
| 1. Main idea                  |
| 2. What to remember           |
| 3. Exam relevance             |
|                              |
| [ Generate Revision ]         |
+------------------------------+
```

Desktop Wireframe:

```text
+--------------------------+-------------------------------+
| Conversation             | Study Workspace                |
|                          | Summary tab active            |
|                          | 1. Main idea                  |
|                          | 2. What to remember           |
|                          | 3. Exam relevance             |
+--------------------------+-------------------------------+
```

UX Notes: Summary is included after recording. Extra generation actions may need credits.

---

## Screen 10 - Flashcards

Purpose: Let student revise lecture through question/answer cards.

Mobile Wireframe:

```text
+------------------------------+
| Study Workspace header        |
+------------------------------+
| Notes Summary ... Flashcards |
+------------------------------+
|        Flashcard 1 / 20       |
|                              |
|   Question on front side      |
|                              |
|        [ Show Answer ]        |
|                              |
| [ Prev ]              [ Next ]|
+------------------------------+
```

Desktop Wireframe:

```text
+--------------------------+-------------------------------+
| Conversation             | Flashcards tab active          |
|                          | +---------------------------+ |
|                          | | Flashcard 1 / 20          | |
|                          | | Question                  | |
|                          | | [ Show Answer ]           | |
|                          | +---------------------------+ |
+--------------------------+-------------------------------+
```

UX Notes: Flashcards may be generated with credits. If unavailable, Plan Locked or Credits Low popup appears.

---

## Screen 11 - Quiz

Purpose: Practice lecture through MCQs inside Study Workspace.

Mobile Wireframe:

```text
+------------------------------+
| Study Workspace header        |
+------------------------------+
| Notes Summary ... Quiz        |
+------------------------------+
| Quiz 1 / 20                   |
| Question text                 |
| ( ) Option A                  |
| ( ) Option B                  |
| ( ) Option C                  |
| ( ) Option D                  |
|                              |
| [ Submit Answer ]             |
+------------------------------+
```

Desktop Wireframe:

```text
+--------------------------+-------------------------------+
| Conversation             | Quiz tab active                |
|                          | Quiz 1 / 20                   |
|                          | Question text                 |
|                          | ( ) A  ( ) B                  |
|                          | ( ) C  ( ) D                  |
|                          | [ Submit Answer ]             |
+--------------------------+-------------------------------+
```

UX Notes: Quiz stays inside Study Workspace. No separate quiz page. Credit/plan gating popups can appear before generation.

---

## Screen 12 - Library

Purpose: Saved lecture archive with folders, recent items, favorites, and search.

Mobile Wireframe:

```text
+------------------------------+
| Library                Search |
+------------------------------+
| Recent                        |
| [ Lecture card ]              |
| [ Lecture card ]              |
|                              |
| Favorites                     |
| [ Lecture card ]              |
|                              |
| Folders                       |
| Physics            24 lect >  |
| Chemistry          12 lect >  |
+------------------------------+
| Home Library Groups Progress Profile |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Logo   [ Search library ]                 Credits Bell Profile |
+----------+-----------------------------------------------------+
| Nav rail | Recent:   [Card] [Card] [Card]                     |
|          | Favorites:[Card] [Card]                            |
|          | Folders: [Physics] [Chemistry] [Biology]           |
+----------+-----------------------------------------------------+
```

UX Notes: Bottom nav visible, Library active. Card opens Study Workspace. Folder opens folder view later, but core planning keeps Library as primary.

---

## Screen 13 - Groups

Purpose: Teacher-led Study Communities list. Not chat, no messaging.

Mobile Wireframe:

```text
+------------------------------+
| Groups                Join + |
+------------------------------+
| +--------------------------+ |
| | Teacher photo             | |
| | Physics Batch NEET        | |
| | Mr Sharma / Physics / OK  | |
| | M.Sc badge  120 students | |
| | [ Join Group ]            | |
| +--------------------------+ |
|                              |
| +--------------------------+ |
| | Chemistry Group           | |
| | [ Joined ]                | |
| +--------------------------+ |
+------------------------------+
| Home Library Groups Progress Profile |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Groups                                            [ Join + ]    |
+----------+-----------------------------------------------------+
| Nav rail | [Group Card]   [Group Card]   [Group Card]          |
|          | [Group Card]   [Group Card]                         |
+----------+-----------------------------------------------------+
```

UX Notes: Groups tab active. Join button opens Join Group popup if code-based. Tapping group/teacher opens Group Information.

---

## Screen 14 - Group Information

Purpose: Full group + teacher trust page before/after joining.

Mobile Wireframe:

```text
+------------------------------+
| Back   Group name             |
+------------------------------+
|        Teacher photo          |
|        Teacher name OK        |
|        Subject / Qualification|
|        Experience             |
|        Certificate previews   |
|        Short bio              |
+------------------------------+
| [ Join Group ]                |
| [ Share ] [ Report ]          |
+------------------------------+
| Group Information             |
| Description                   |
| Students / Lectures / Date    |
| Rules                         |
| Allowed content               |
+------------------------------+
| Recent shared content         |
| Lecture / Homework / Quiz     |
| Suggested teachers            |
+------------------------------+
| Home Library Groups Progress Profile |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Back   Group name                                               |
+----------+------------------------+-----------------------------+
| Nav rail | Teacher profile        | Group information           |
|          | Photo                  | Description                 |
|          | Name / Subject / OK    | Students / Lectures / Date  |
|          | Qualification / Certs  | Rules / Allowed content     |
|          | [ Join or Leave ]      | Recent content              |
|          | [ Share ] [ Report ]   | Suggested teachers          |
+----------+------------------------+-----------------------------+
```

UX Notes: Join/Leave is based on membership state. Report opens Report popup. Share copies or opens Share popup. Recent content opens Study Workspace.

---

## Screen 15 - Create Group

Purpose: Teacher creates a new study community/class/batch.

Mobile Wireframe:

```text
+------------------------------+
| Back   Create Group           |
+------------------------------+
| Group name                    |
| [________________________]    |
| Subject                       |
| [________________________]    |
| Description                   |
| [________________________]    |
| Rules                         |
| [________________________]    |
| Allowed content               |
| [x] Notes [x] Quiz [x] Homework|
|                              |
| [ Create Group ]              |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Back   Create Group                                             |
+----------+-----------------------------------------------------+
| Nav rail | +-----------------------------------------------+   |
|          | | Group name                                    |   |
|          | | Subject                                       |   |
|          | | Description                                   |   |
|          | | Rules                                         |   |
|          | | Allowed content checkboxes                    |   |
|          | | [ Create Group ]                              |   |
|          | +-----------------------------------------------+   |
+----------+-----------------------------------------------------+
```

UX Notes: Teacher-only. Opened from Groups header or Teacher Dashboard. Confirmation dialog appears before final creation if needed.

---

## Screen 16 - Teacher Dashboard

Purpose: Teacher business dashboard with cards, groups, credits, profile entry.

Mobile Wireframe:

```text
+------------------------------+
| Back   Teacher Dashboard   + |
+------------------------------+
| Teacher profile summary       |
| Photo / Name / Subject / OK   |
| [ Edit Profile ]              |
+------------------------------+
| Students | Groups | Lectures  |
| Revenue  | Credits | Storage  |
+------------------------------+
| My Groups                     |
| Physics Batch          Share  |
| Chemistry Group        Share  |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Back   Teacher Dashboard                              [ + ]     |
+----------+-----------------------------------------------------+
| Nav rail | Teacher profile summary                             |
|          | [Students] [Groups] [Lectures] [Revenue]            |
|          | [Credits]  [Storage][Analytics][Subscribers]        |
|          | My Groups: [Card] [Card] [Card]                     |
+----------+-----------------------------------------------------+
```

UX Notes: Entry from Profile only, not bottom tab. Plus creates group. Edit opens Teacher Profile.

---

## Screen 17 - Teacher Profile

Purpose: Public teacher identity and editable teacher profile details.

Mobile Wireframe:

```text
+------------------------------+
| Back   Teacher Profile   Edit |
+------------------------------+
|        Profile photo          |
|        Full name OK           |
|        Teaching subject       |
|        Short bio              |
+------------------------------+
| Qualification                 |
| Experience                    |
| Joined since                  |
| Total students / groups       |
| Total shared lectures         |
+------------------------------+
| Certificates                  |
| [cert] [cert] [cert]          |
| Achievements / documents      |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Back   Teacher Profile                                  [Edit]  |
+----------+----------------------+-------------------------------+
| Nav rail | Photo / Name / OK    | Bio                           |
|          | Subject              | Qualification / Experience    |
|          | Stats                | Certificates / Documents      |
|          | Joined since         | Achievements                  |
+----------+----------------------+-------------------------------+
```

UX Notes: Teacher can edit anytime. Certificate upload is future storage work, not implemented in Phase 1B.

---

## Screen 18 - Progress

Purpose: Student progress or teacher snapshot.

Mobile Wireframe:

```text
+------------------------------+
| Progress                      |
+------------------------------+
| Lectures completed            |
| [progress bar]                |
|                              |
| Quiz scores                   |
| Physics 82 percent            |
| Chemistry 75 percent          |
|                              |
| Study streak                  |
+------------------------------+
| Home Library Groups Progress Profile |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Progress                                                       |
+----------+-----------------------------------------------------+
| Nav rail | [Lectures completed] [Quiz scores] [Study streak]   |
|          | [Teacher snapshot if teacher account]               |
+----------+-----------------------------------------------------+
```

UX Notes: Progress tab active. Teacher variant shows class snapshot and link to Teacher Dashboard.

---

## Screen 19 - Profile

Purpose: Account center for plan, credits, storage, settings, help, teacher dashboard, logout.

Mobile Wireframe:

```text
+------------------------------+
| Profile                       |
+------------------------------+
| User photo                    |
| Name / Email                  |
+------------------------------+
| Subscription              >   |
| Credits                   >   |
| Storage                   >   |
| Library Size              >   |
| Settings                  >   |
| Help                      >   |
| Teacher Dashboard         >   |
+------------------------------+
| [ Logout ]                    |
+------------------------------+
| Home Library Groups Progress Profile |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Profile                                                       |
+----------+-----------------------------------------------------+
| Nav rail | User photo / Name / Email                          |
|          | [Subscription] [Credits] [Storage] [Library Size]   |
|          | [Settings] [Help] [Teacher Dashboard]               |
|          | [Logout]                                           |
+----------+-----------------------------------------------------+
```

UX Notes: Profile tab active. Logout opens confirmation dialog. Teacher Dashboard row visible only for teacher accounts.

---

## Screen 20 - Subscription

Purpose: Show plans and upgrade path using credits-first language.

Mobile Wireframe:

```text
+------------------------------+
| Back   Subscription           |
+------------------------------+
| Current plan                  |
| Plan 499 / 3500 credits       |
+------------------------------+
| [ Free ]                      |
| [ Plan 199 ]                  |
| [ Plan 499 current ]          |
| [ Plan 999 ]                  |
| [ Teacher Plan ]              |
+------------------------------+
| [ Upgrade Plan ]              |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Back   Subscription                         Current: Plan 499   |
+----------+-----------------------------------------------------+
| Nav rail | [Free] [199] [499 current] [999] [Teacher]          |
|          | [ Upgrade Plan ]                                    |
+----------+-----------------------------------------------------+
```

UX Notes: Opened from Profile, Plan Locked popup, or Credits screen. No live payment implementation in Phase 1B.

---

## Screen 21 - Credits

Purpose: Show credit balance and recent credit usage.

Mobile Wireframe:

```text
+------------------------------+
| Back   Credits                |
+------------------------------+
| 1,245 Credits                 |
| Approx 15 lecture sessions    |
+------------------------------+
| Recent usage                  |
| Ask AI Normal       -5        |
| Quiz generated      -25       |
| Record 45 min       -80       |
+------------------------------+
| [ Buy More Credits ]          |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Back   Credits                 1,245 credits   [Buy More]       |
+----------+-----------------------------------------------------+
| Nav rail | Usage table                                         |
|          | Ask AI Normal     -5                                |
|          | Quiz generated    -25                               |
|          | Record 45 min     -80                               |
+----------+-----------------------------------------------------+
```

UX Notes: Opened from Profile credits row or top-bar credits pill. Credits Low popup links here or Subscription.

---

## Screen 22 - Settings

Purpose: Account preferences and teacher-specific audio policy.

Mobile Wireframe:

```text
+------------------------------+
| Back   Settings               |
+------------------------------+
| Notifications          [on]   |
| Dark mode              [on]   |
| Save original audio    [off]  |
| Language               >      |
| About ExamSpark        >      |
+------------------------------+
```

Desktop Wireframe:

```text
+----------------------------------------------------------------+
| Back   Settings                                                 |
+----------+-----------------------------------------------------+
| Nav rail | Notifications [on]      Dark mode [on]               |
|          | Save original audio [off]                            |
|          | Language >             About >                       |
+----------+-----------------------------------------------------+
```

UX Notes: Opened from Profile. Save original audio is teacher-only and default off.

---

# Popup Wireframes

## Popup 1 - Join Group

Mobile:

```text
+------------------------------+
| Join Group                    |
| Enter invite code/link        |
| [________________________]    |
| [ Join ] [ Cancel ]           |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Join Group                    |
| [ Invite code/link ]          |
| [ Join ] [ Cancel ]           |
+------------------------------+
```

Placement: Mobile bottom sheet or centered dialog. Desktop centered dialog.

---

## Popup 2 - Leave Group

Mobile:

```text
+------------------------------+
| Leave this group?             |
| You may lose access to future |
| shared content.               |
| [ Leave ] [ Cancel ]          |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Leave this group?             |
| [ Leave ] [ Cancel ]          |
+------------------------------+
```

Placement: Centered confirmation dialog over Group Information.

---

## Popup 3 - Share

Mobile:

```text
+------------------------------+
| Share                         |
| [ Copy group link ]           |
| [ Share invite ]              |
| [ Cancel ]                    |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Share                         |
| Copy group link               |
| Share invite                  |
+------------------------------+
```

Placement: Mobile bottom sheet. Desktop small popover near Share button.

---

## Popup 4 - Delete

Mobile:

```text
+------------------------------+
| Delete item?                  |
| This action cannot be undone. |
| [ Delete ] [ Cancel ]         |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Delete item?                  |
| [ Delete ] [ Cancel ]         |
+------------------------------+
```

Placement: Centered confirmation dialog. Use for future delete actions only after founder confirmation.

---

## Popup 5 - Report

Mobile:

```text
+------------------------------+
| Report this group?            |
| Inappropriate content or      |
| behavior will be reviewed.    |
| [ Report ] [ Cancel ]         |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Report this group?            |
| [ Report ] [ Cancel ]         |
+------------------------------+
```

Placement: Centered dialog from Group Information.

---

## Popup 6 - Plan Locked

Mobile:

```text
+------------------------------+
| Feature locked                |
| Upgrade plan to use this.     |
| [ Upgrade ] [ Later ]         |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Feature locked                |
| [ Upgrade ] [ Later ]         |
+------------------------------+
```

Placement: Centered dialog from credit/plan-gated actions.

---

## Popup 7 - Credits Low

Mobile:

```text
+------------------------------+
| Credits low                   |
| You need more credits.        |
| [ Buy Credits ] [ Cancel ]    |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Credits low                   |
| [ Buy Credits ] [ Cancel ]    |
+------------------------------+
```

Placement: Centered dialog from any paid AI action.

---

## Popup 8 - Upload Options

Mobile:

```text
+------------------------------+
| Upload Options                |
| PDF                           |
| Image                         |
| Audio file                    |
| Cancel                        |
+------------------------------+
```

Desktop:

```text
+------------------+
| Upload Options   |
| PDF              |
| Image            |
| Audio file       |
+------------------+
```

Placement: Mobile bottom sheet from attachment button. Desktop anchored dropdown.

---

## Popup 9 - Confirmation Dialogs

Mobile:

```text
+------------------------------+
| Are you sure?                 |
| Short explanation here.       |
| [ Confirm ] [ Cancel ]        |
+------------------------------+
```

Desktop:

```text
+------------------------------+
| Are you sure?                 |
| [ Confirm ] [ Cancel ]        |
+------------------------------+
```

Placement: Centered modal for logout, delete, leave, report, create group confirmation.

---

# Phase 1B Completion Report

## Total Screens

22 screens:

1. Home
2. Library
3. Groups
4. Progress
5. Profile
6. Study Workspace
7. Recording
8. Upload
9. Notes
10. Summary
11. Flashcards
12. Quiz
13. Teacher Dashboard
14. Teacher Profile
15. Group Information
16. Create Group
17. Subscription
18. Credits
19. Settings
20. Splash
21. Login
22. Signup

## Total Popups

9 popups:

1. Join Group
2. Leave Group
3. Share
4. Delete
5. Report
6. Plan Locked
7. Credits Low
8. Upload Options
9. Confirmation Dialogs

## Missing Items

No requested screen is missing from this file.

Note: Help, notifications, search, storage detail, and library-size detail are already covered in the larger `WIREFRAMES.md` v2. They are not repeated here because the founder asked for 8-10 core wireframes in this pass.

## UX Consistency Check

- Home remains the primary conversation and capture screen.
- Study Workspace remains the single place for Notes, Summary, Flashcards, and Quiz.
- Groups remain Study Communities, not chat groups.
- Teacher Dashboard is accessed from Profile, not as a sixth bottom tab.
- Credits language is used for AI actions, not rupee-per-action pricing.
- Popups are simple and minimal.

## Navigation Consistency Check

- Bottom navigation remains exactly 5 tabs: Home, Library, Groups, Progress, Profile.
- No sixth bottom tab is introduced.
- Study Workspace opens from Home, Library, or Groups.
- Teacher Dashboard opens from Profile.
- Group Information opens from Groups.
- Recording and Upload start from Home.
- Login/Signup remain pre-auth screens.

## Founder Approval Checklist

- [ ] Home, Recording, Upload flow approved
- [ ] Study Workspace, Notes, Summary, Flashcards, Quiz approved
- [ ] Library layout approved
- [ ] Groups, Group Information, Join/Leave flow approved
- [ ] Teacher Dashboard and Teacher Profile approved
- [ ] Profile, Subscription, Credits, Settings approved
- [ ] Splash, Login, Signup approved
- [ ] Popups approved
- [ ] 5-tab navigation rule approved
- [ ] Ready to start Phase 2 only after founder says: "Phase 1B approved, Phase 2 shuru karo"

Phase 2 is not started automatically.
