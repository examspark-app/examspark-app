# ExamSpark — Phase 1B Low-Fidelity Wireframes (Full Detail)

> **Phase:** 1B — Low Fidelity Wireframes (per [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md))
> **Model:** Sonnet 5 High
> **Status:** 🟡 Draft v2 (full 12-point detail) — awaiting founder approval before Phase 2 (AppShell)
> **Rule followed:** No Flutter code · No widgets · No navigation implementation — text/ASCII wireframes only
> **Source of truth:** [`IA_SCREEN_HIERARCHY.md`](IA_SCREEN_HIERARCHY.md) (screen bible, locked)
> **Companion:** [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) · [`FEATURES_MASTER.md`](FEATURES_MASTER.md) · [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md)

---

## How to Read This Document

Har screen ka ek fixed 12-point template hai:

1. **Purpose** — ye screen kyun hai
2. **Mobile Wireframe** — ASCII box layout
3. **Desktop Wireframe** — ASCII box layout
4. **Header** — top bar kya hai
5. **Navigation** — yahan kaise aaye, kahan ja sakte
6. **Main Content** — beech ka area
7. **Bottom Navigation** — 5-tab bar visible hai ya nahi
8. **Floating Action Button** — koi floating button hai ya nahi
9. **Bottom Sheet placement** — kaunsa sheet is screen se khulta hai
10. **Popup placement** — kaunsa popup is screen se khulta hai
11. **User Journey** — step-by-step path
12. **Screen relationships** — parent screen / child screens

**Legend:** `🏠📚👥📈👤` = bottom nav (Home · Library · Groups · Progress · Profile) — always this order, never a 6th tab.

---

## Screen Index (28 total)

| # | Screen | Type |
|---|--------|------|
| 1 | Splash / Loading | Level 0 |
| 2 | Home — Empty State | Level 1 tab |
| 3 | Home — Inline Study Block | Level 1 tab (state) |
| 4 | Search Overlay | Overlay |
| 5 | Notifications Panel | Overlay |
| 6 | Sign Up Gate | Popup |
| 7 | Study Workspace | Level 2 |
| 8 | Library | Level 1 tab |
| 9 | Library → Folder Opened | Level 2 |
| 10 | Groups List | Level 1 tab |
| 11 | Group Info Screen | Level 2 |
| 12 | Progress (Student) | Level 1 tab |
| 13 | Progress (Teacher snapshot) | Level 1 tab (variant) |
| 14 | Profile | Level 1 tab |
| 15 | Credits Detail | Level 2 |
| 16 | Storage Detail | Level 2 |
| 17 | Library Size Detail | Level 2 |
| 18 | Help / FAQ | Level 2 |
| 19 | Teacher Dashboard | Level 2 |
| 20 | Settings | Level 2 |
| 21 | Subscription / Plans | Level 2 |
| 22 | Auth — Login / Sign Up | Level 0 |
| 23 | Popup — Upload Picker | Popup |
| 24 | Popup — Share to Group | Popup |
| 25 | Popup — Plan Locked 🔒 | Popup |
| 26 | Popup — Low Credits | Popup |
| 27 | Popup — Logout Confirm | Popup |
| 28 | Popup — Report Group | Popup |

---

## 1. Splash / Loading

**1. Purpose:** First thing user sees on app launch — brand moment while session/auth state resolves (<1 sec).

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│                                │
│                                │
│           [ LOGO ]            │
│          ExamSpark             │
│                                │
│                                │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌───────────────────────────────────────────────┐
│                                                 │
│                  [ LOGO ]                      │
│                 ExamSpark                       │
│                                                 │
└───────────────────────────────────────────────┘
```

**4. Header:** None.
**5. Navigation:** None — fully automatic, no user input possible.
**6. Main Content:** Centered logo + wordmark only.
**7. Bottom Navigation:** Not shown.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** None.
**11. User Journey:** App icon tap → Splash (<1 sec) → auto-routes to Home (logged in) or Auth (#22, first time / logged out).
**12. Screen relationships:** Root screen — leads to either Home (#2) or Auth (#22). No parent.

---

## 2. Home — Empty State (Main Chat) ⭐

**1. Purpose:** App's core screen — single place to Ask AI, record a lecture, or upload content. Everything else is reached from here or the bottom tabs.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ Logo      🔍   ●1,245  🔔  👤 │
├──────────────────────────────┤
│                                │
│                                │
│        "Ask anything or        │
│         record a lecture"      │
│                                │
│                                │
├──────────────────────────────┤
│ 📎  [ Type a message...  ] 🎤 ↑│
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ Logo        [ 🔍 Search lectures / groups ]        ●1,245 🔔 👤  │
├───────┬───────────────────────────────────────────────┬─────────┤
│ 🏠Home│                                               │         │
│ 📚Lib │        (centered conversation column,         │  empty  │
│ 👥Grp │         max ~768px width)                     │  space  │
│ 📈Prog│                                               │  /future│
│ 👤Prof│        "Ask anything or record a lecture"     │  widget │
├───────┴───────────────────────────────────────────────┴─────────┤
│              📎  [ Type a message... ]   🎤   ↑                  │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Logo · Search icon (→ #4) · Credits pill (→ #15) · Notification bell (→ #5) · Profile avatar (→ #14).
**5. Navigation:** Landing tab after login/splash. Bottom tabs switch to Library/Groups/Progress/Profile; on desktop the same 5 items may render as a left side rail instead of a bottom bar (IA Part I — optional).
**6. Main Content:** Empty conversation placeholder, centered vertically.
**7. Bottom Navigation:** Visible — `🏠📚👥📈👤`, Home tab active.
**8. Floating Action Button:** None — record/send live inside the sticky bottom input bar, not a separate FAB.
**9. Bottom Sheet placement:** Upload Picker (#23) opens as a bottom sheet from 📎. Study Workspace (#7) opens as a bottom sheet once a lecture exists (via #3).
**10. Popup placement:** Sign Up Gate (#6) appears centered over Home, dimmed background, after the first free guest Ask AI reply.
**11. User Journey:** Login/Splash → Home lands here → type question or tap 🎤 to record → response appears inline (→ #3).
**12. Screen relationships:** Parent of Inline Study Block (#3), Search (#4), Notifications (#5); triggers Sign Up Gate (#6) and Upload Picker (#23). Sibling tabs: Library (#8), Groups (#10), Progress (#12), Profile (#14).

---

## 3. Home — Inline Study Block (after a lecture is recorded)

**1. Purpose:** Show AI results (Notes/Summary/Transcript + extra actions) directly inside the conversation — this is the core "not a ChatGPT clone" differentiator; no page navigation after recording.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ Logo      🔍   ●1,245  🔔  👤 │
├──────────────────────────────┤
│ 🧑 You: 🎤 Recorded lecture    │
│                                │
│ 🤖 AI: Your notes are ready.   │
│ ┌────────────────────────────┐│
│ │ [Notes][Summary][Transcript]││
│ │────────────────────────────││
│ │ (short notes preview...)   ││
│ │                            ││
│ │ [Flashcards] [Quiz]        ││
│ │ [Revision]   [Ask AI]      ││
│ │                            ││
│ │   ⤢  Open Full Workspace   ││
│ └────────────────────────────┘│
├──────────────────────────────┤
│ 📎  [ Type a message...  ] 🎤 ↑│
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ Logo        [ 🔍 Search ]                          ●1,245 🔔 👤  │
├───────┬───────────────────────────────────────────────┬─────────┤
│ Nav   │ 🧑 You: 🎤 Recorded lecture                     │         │
│ rail  │ 🤖 AI: Your notes are ready.                    │         │
│       │ ┌───────────────────────────────────────────┐  │         │
│       │ │ [Notes][Summary][Transcript]               │  │         │
│       │ │ (short notes preview...)                   │  │         │
│       │ │ [Flashcards][Quiz][Revision][Ask AI]       │  │         │
│       │ │              ⤢ Open Full Workspace         │  │         │
│       │ └───────────────────────────────────────────┘  │         │
├───────┴───────────────────────────────────────────────┴─────────┤
│              📎  [ Type a message... ]   🎤   ↑                  │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Same as Home Empty State — unchanged.
**5. Navigation:** No navigation happens here by design — content swaps inline. Only exit is "Open Full Workspace".
**6. Main Content:** AI message bubble containing a card: mini tab row (Notes/Summary/Transcript) + 4 extra-action buttons (Flashcards, Quiz, Revision, Ask AI) + expand action.
**7. Bottom Navigation:** Visible, unchanged, Home tab active.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** "Open Full Workspace" tap → Study Workspace (#7) slides up as bottom sheet (mobile) or opens right split panel (desktop).
**10. Popup placement:** None triggered directly from this state (credit-gating popups like Plan Locked #25 / Low Credits #26 may appear if tapping Flashcards/Quiz/etc. without enough credits or plan access).
**11. User Journey:** Home (#2) → record/upload → "Processing…" inline → Inline Study Block appears in same chat → tap an extra action (credits deducted) or "Open Full Workspace".
**12. Screen relationships:** Child state of Home (#2); parent of Study Workspace (#7) via expand; can trigger Plan Locked (#25) / Low Credits (#26) popups.

---

## 4. Search Overlay

**1. Purpose:** One universal search across saved Lectures (Library) and Groups — reachable from any tab's header.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ←  [ 🔍 Search...        ] ✕ │
├──────────────────────────────┤
│ Lectures                       │
│ Lecture 12: Electromagnetism   │
│ Lecture 11: Optics              │
├──────────────────────────────┤
│ Groups                         │
│ Physics Batch NEET 2026        │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ Logo   [ 🔍 electromag_________________ ]           ●1,245 🔔 👤 │
│        ┌───────────────────────────────┐                        │
│        │ Lectures                       │                        │
│        │ Lecture 12: Electromagnetism   │                        │
│        │ Groups                          │                        │
│        │ Physics Batch NEET 2026         │                        │
│        └───────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Mobile — dedicated full-width search input row with back arrow + cancel (✕). Desktop — expands inline inside the existing top-bar search field.
**5. Navigation:** Opened by tapping 🔍 from Home/Library/Groups/Progress/Profile header. Tapping a result navigates directly to that result's screen.
**6. Main Content:** Grouped results list — "Lectures" section, "Groups" section (empty-state: "No results" text if nothing matches).
**7. Bottom Navigation:** Hidden on mobile (full-screen overlay); desktop keeps everything else visible since it's just a dropdown under the search field.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None — mobile uses a full-screen overlay, not a sheet.
**10. Popup placement:** This overlay itself behaves like a popup/dropdown on desktop.
**11. User Journey:** Any tab → tap 🔍 → type query → tap a Lecture result → Study Workspace (#7); tap a Group result → Group Info (#11).
**12. Screen relationships:** Reachable from every Level-1 tab; leads into Study Workspace (#7) or Group Info (#11).

---

## 5. Notifications Panel

**1. Purpose:** Central place for alerts — teacher shared content, notes ready, low credits, plan expiring.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Notifications      Clear all│
├──────────────────────────────┤
│ 🔔 Mr. Sharma shared new notes │
│    Physics Batch · 2h ago      │
├──────────────────────────────┤
│ 🔔 Your Notes are ready         │
│    Lecture 12 · 5h ago          │
├──────────────────────────────┤
│ 🔔 Low credits — 45 remaining  │
│    1d ago                        │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
                                   ┌───────────────────────────┐
                                   │ Notifications   Clear all │
                                   │ 🔔 Mr. Sharma shared notes │
                                   │ 🔔 Notes ready — Lecture12 │
                                   │ 🔔 Low credits — 45 left   │
                                   └───────────────────────────┘
```

**4. Header:** Mobile — pushed screen with back arrow + "Clear all". Desktop — anchored dropdown panel under the 🔔 icon, small "Notifications" title + "Clear all" inside the panel.
**5. Navigation:** Opened from 🔔 icon on any screen's header. Tapping a notification deep-links to its source screen and dismisses the panel.
**6. Main Content:** Reverse-chronological list of alerts, each with icon, message, source, and timestamp.
**7. Bottom Navigation:** Hidden on mobile (full push); not applicable on desktop (floats above current screen as a dropdown, rest of UI stays visible).
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Mobile may alternatively render this as a bottom sheet instead of a full push for a quicker glance — either is acceptable at this fidelity; sheet is the lighter-weight recommendation.
**10. Popup placement:** Behaves like a popup/panel itself on desktop.
**11. User Journey:** Any screen → tap 🔔 → Notifications → tap "Notes ready" → Study Workspace (#7); tap "shared new notes" → Group Info (#11); tap "Low credits" → Credits Detail (#15).
**12. Screen relationships:** Reachable from every screen's header; leads to Study Workspace (#7), Group Info (#11), or Credits Detail (#15).

---

## 6. Sign Up Gate (Popup)

**1. Purpose:** Convert a guest's first free Ask AI moment into a signed-up account so their result is saved.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ (Home content dimmed behind)  │
│   ┌────────────────────────┐  │
│   │        ✦ ✦ ✦            │  │
│   │   Save this for free!   │  │
│   │  Sign up to keep your   │  │
│   │  notes, quizzes & more  │  │
│   │   [   Sign Up Free   ]  │  │
│   │   [ Continue as Guest ] │  │
│   └────────────────────────┘  │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ (Home content dimmed behind)                                    │
│                    ┌───────────────────────────┐                │
│                    │   Save this for free!      │                │
│                    │  Sign up to keep your      │                │
│                    │  notes, quizzes & more     │                │
│                    │  [ Sign Up Free ]           │                │
│                    │  [ Continue as Guest ]      │                │
│                    └───────────────────────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** None — this is a modal, not a screen with its own header.
**5. Navigation:** No back button; only the two in-modal buttons are actionable. Tapping outside does not dismiss (forces a choice).
**6. Main Content:** Short pitch text + two buttons.
**7. Bottom Navigation:** Hidden behind the dimmed overlay.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Not a sheet — center-anchored modal on both platforms.
**10. Popup placement:** This IS the popup — dimmed full-screen scrim behind, card centered.
**11. User Journey:** Guest → Home → asks first free question → AI answers → Sign Up Gate appears → "Sign Up Free" → Auth (#22) **or** "Continue as Guest" → dismiss, answer stays unsaved.
**12. Screen relationships:** Triggered only by Home (#2); leads to Auth (#22) or dismisses back to Home.

---

## 7. Study Workspace ⭐ (Hero screen)

**1. Purpose:** The single place where all study material for one lecture lives — Notes, Summary, Transcript, Flashcards, Quiz, Revision, Ask AI — without ever leaving the lecture's context. This is ExamSpark's core differentiator vs a plain chatbot.

**2. Mobile Wireframe (bottom sheet, swiped up)**

```
┌──────────────────────────────┐
│  🏠    📚    👥    📈    👤   │  (tab bar visible behind, dimmed)
├──────────────────────────────┤
│        ▂▂▂ (drag handle)      │
│ ← Lecture 12: Electromagnetism│
│   Mr. Sharma · Physics·12 Jul │
├──────────────────────────────┤
│ [Notes][Summary][Transcript]  │
│ [Flashcards][Quiz][Revision]  │
│ [Ask AI]                      │
├──────────────────────────────┤
│                                │
│    (active tab content —      │
│     Notes shown by default)   │
│                                │
└──────────────────────────────┘
```

**3. Desktop Wireframe (right split panel)**

```
┌─────────────────────────────────────────────────────────────────┐
│ Logo        [ 🔍 Search ]                          ●1,245 🔔 👤  │
├───────┬───────────────────────────┬───────────────────────────────┤
│ Nav   │ Conversation (left ~45%)  │ Study Workspace (right ~55%)  │
│ rail  │ 🧑 You: ...                 │ Lecture 12: Electromagnetism  │
│       │ 🤖 AI: notes ready...       │ Mr. Sharma · Physics · 12 Jul │
│       │                            ├────────────────────────────────┤
│       │                            │ Notes|Summary|Transcript       │
│       │                            │ Flashcards|Quiz|Revision       │
│       │                            │ Ask AI                         │
│       │                            ├────────────────────────────────┤
│       │                            │  (active tab content)          │
├───────┴───────────────────────────┴───────────────────────────────┤
│              📎  [ Type a message... ]   🎤   ↑                    │
└─────────────────────────────────────────────────────────────────────┘
```

**4. Header:** Lecture title, teacher name, subject, date — always pinned above the tab row; back arrow (mobile drag-down / desktop close "×").
**5. Navigation:** Tapping a tab swaps content in place — never a page change. Closing returns to whichever screen opened it (Home, Library, or Group Info) — never a dead end.
**6. Main Content:** Exactly one tab's content at a time: Notes → Summary → Transcript → Flashcards → Quiz → Revision → Ask AI.
**7. Bottom Navigation:** Mobile keeps the 5-tab bar visible (dimmed) underneath the sheet; desktop keeps the Home input bar docked at the very bottom.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Mobile — bottom sheet, ~90% height, drag handle to dismiss, opens on top of whichever tab is currently active underneath. Desktop — not a sheet, a persistent right-side split panel instead.
**10. Popup placement:** Plan Locked (#25) or Low Credits (#26) may appear over this screen if a tab's action needs a higher plan or more credits (e.g. Deep Ask AI).
**11. User Journey:** Library card tap **or** Group Info "Recent Shared Content" tap **or** Home "Open Full Workspace" → Study Workspace opens → switch tabs freely → close → back to caller screen.
**12. Screen relationships:** Child of Home (#3), Library (#8/#9), and Group Info (#11) — same shared screen used everywhere, never duplicated per entry point.

---

## 8. Library

**1. Purpose:** Personal archive of every saved lecture, organized by Recent, Favorites, and subject Folders — the "school bag" for the student.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Library              🔍     │
├──────────────────────────────┤
│ Recent                        │
│ [Card] [Card] [Card]  →scroll │
├──────────────────────────────┤
│ Favorites ★                   │
│ [Card] [Card]                 │
├──────────────────────────────┤
│ Folders                       │
│ 📁 Physics          24 lect › │
│ 📁 Chemistry        12 lect › │
│ 📁 Biology           8 lect › │
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ Logo   [ 🔍 Search library ]                       ●1,245 🔔 👤  │
├───────┬───────────────────────────────────────────────────────────┤
│ Nav   │ Recent: [Card][Card][Card][Card]                          │
│ rail  │ Favorites ★: [Card][Card]                                 │
│       │ Folders (grid): [📁 Physics][📁 Chemistry][📁 Biology][+]  │
└───────┴───────────────────────────────────────────────────────────┘
```

**4. Header:** Section title "Library" + Search icon (mobile) / full search bar (desktop) → opens Search Overlay (#4).
**5. Navigation:** Reached via bottom tab `📚`. Tapping any lecture card → Study Workspace (#7). Tapping a folder → Library Folder (#9).
**6. Main Content:** Three stacked sections in fixed order — Recent → Favorites → Folders — per IA §5. Every AI-generated result auto-saves here.
**7. Bottom Navigation:** Visible, Library tab active.
**8. Floating Action Button:** None (no manual "create lecture" action here — recording only happens from Home).
**9. Bottom Sheet placement:** None triggered directly; Study Workspace (#7) opens as sheet/panel from any card tap.
**10. Popup placement:** Each lecture card's `⋮` overflow may open a small action popup (rename/favorite/delete — future).
**11. User Journey:** Bottom tab → Library → tap Recent/Favorite card (1 tap) or Folder (1 tap) → lecture card (1 tap) → Study Workspace. Matches IA's "2-tap" rule for saved lectures.
**12. Screen relationships:** Level-1 tab; parent of Library Folder (#9) and Study Workspace (#7); linked from Library Size Detail (#17).

---

## 9. Library → Folder Opened (example: Physics)

**1. Purpose:** Drill into one subject folder to browse all lectures under it.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Physics (24)          🔍    │
├──────────────────────────────┤
│ Lecture 12: Electromagnetism  │
│ Mr. Sharma · 12 Jul       ⋮  │
├──────────────────────────────┤
│ Lecture 11: Optics             │
│ Mr. Sharma · 10 Jul       ⋮  │
├──────────────────────────────┤
│ Lecture 10: Thermodynamics     │
│ Mr. Sharma · 8 Jul        ⋮  │
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Physics (24 lectures)                    [ 🔍 Search ] ●1,245 │
├───────┬───────────────────────────────────────────────────────────┤
│ Nav   │ [Lecture12][Lecture11][Lecture10]                         │
│ rail  │ [Lecture 9][Lecture 8][Lecture 7]     (3–4 col grid)      │
└───────┴───────────────────────────────────────────────────────────┘
```

**4. Header:** Back arrow + folder name + count + search icon.
**5. Navigation:** Reached only from Library (#8) → folder tap. Back returns to Library.
**6. Main Content:** Flat list (mobile) / grid (desktop) of lecture cards belonging to this folder — same `LectureCard` component as Library's Recent/Favorites rows.
**7. Bottom Navigation:** Visible, Library tab still highlighted (this is a Level-2 push under Library).
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Study Workspace (#7) opens as sheet/panel from any lecture card tap.
**10. Popup placement:** Card `⋮` overflow menu (same as Library).
**11. User Journey:** Library → tap "Physics" folder → Folder screen → tap lecture card → Study Workspace.
**12. Screen relationships:** Child of Library (#8); parent of Study Workspace (#7).

---

## 10. Groups List

**1. Purpose:** Browse and join teacher-led Study Communities. Explicitly NOT a chat app — no messaging anywhere in this section.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Groups             [Join +]│
├──────────────────────────────┤
│ ┌────────────────────────┐   │
│ │ 👤  Physics Batch NEET  │   │
│ │ Mr. Sharma · Physics ✔  │   │
│ │ 🎓 M.Sc   👥 120 students│   │
│ │      [   Join Group   ] │   │
│ └────────────────────────┘   │
│ ┌────────────────────────┐   │
│ │ 👤  Organic Chem Mastery│   │
│ │ Ms. Verma · Chemistry ✔ │   │
│ │ 🎓 M.Sc   👥 95 students │   │
│ │       [   Joined    ]   │   │
│ └────────────────────────┘   │
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Groups                                          [ Join + ]     │
├───────┬───────────────────────────────────────────────────────────┤
│ Nav   │ [Group Card]        [Group Card]        [Group Card]     │
│ rail  │ (2–3 column grid, same card content as mobile)            │
└───────┴───────────────────────────────────────────────────────────┘
```

**4. Header:** Title "Groups" + "Join" text button (enter code/link, → popup similar to Upload Picker's sheet style). Teacher accounts see "+ New Group" instead.
**5. Navigation:** Reached via bottom tab `👥`. Tapping a teacher photo or group name → Group Info (#11).
**6. Main Content:** One card per group — teacher photo, teacher name, subject, verified badge, small qualification badge, student count, Join/Joined button. Nothing else (spec rule: clean cards only).
**7. Bottom Navigation:** Visible, Groups tab active.
**8. Floating Action Button:** None (Join/+New Group live in the header, not floating).
**9. Bottom Sheet placement:** "Join" (student) opens a small bottom sheet to enter a join code/link.
**10. Popup placement:** None else directly — Report Group (#28) and Share Group are reached from within Group Info (#11), not this list.
**11. User Journey:** Bottom tab → Groups → tap Join button on a card (toggles membership in place) **or** tap teacher photo/group name → Group Info.
**12. Screen relationships:** Level-1 tab; parent of Group Info (#11).

---

## 11. Group Info Screen

**1. Purpose:** Full picture of a teacher and their group before/after joining — profile, credibility (verification/qualification/achievements), group rules, and recent study content — inspired by WhatsApp Group Info but redesigned as ExamSpark's own Study Community pattern (no chat, no member list wall).

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Physics Batch NEET 2026     │
├──────────────────────────────┤
│         ( large photo )       │
│       Mr. Rohan Sharma ✔      │
│           Physics             │
│   🎓 M.Sc Physics   💼 8 yrs   │
│      [cert] [cert] preview     │
│  "Teaching Physics for NEET…" │
├──────────────────────────────┤
│      [    Join Group    ]     │
│  [ Share Group ] [ Report ]   │
├──────────────────────────────┤
│ GROUP INFORMATION              │
│ Complete NEET Physics...       │
│ 👥120 students  📖24 lectures  │
│ 📅 Created 15 Mar 2024         │
│ Rules: • Be respectful  • ...  │
│ Allowed Content: [Notes][Quiz] │
├──────────────────────────────┤
│ TEACHER ACHIEVEMENTS           │
│ 🏅 Best Faculty Award 2023     │
│ 📄 M.Sc Physics Degree         │
├──────────────────────────────┤
│ RECENT SHARED CONTENT          │
│ 📌 Unit Test — Revision Notes  │
│ ▶  Lecture 12 — Electromagnetism│
│ 📋 Homework — Chapter 4        │
├──────────────────────────────┤
│ SUGGESTED TEACHERS     →scroll│
│ [👤 Priya Verma] [👤 Aditya Rao]│
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Physics Batch NEET 2026                                        │
├───────┬─────────────────────────┬─────────────────────────────────┤
│ Nav   │  TEACHER PROFILE (sticky│  GROUP INFO + ACHIEVEMENTS +      │
│ rail  │  left column)           │  RECENT CONTENT + SUGGESTED       │
│       │  (large photo)          │  TEACHERS (scrollable right col)  │
│       │  Mr. Rohan Sharma ✔     │  Description, stats, rules,       │
│       │  Physics · 🎓M.Sc 💼8yrs │  allowed content...               │
│       │  [cert][cert] · bio      │  Achievements list...             │
│       │  [ Join Group ]         │  Recent shared content list...    │
│       │  [Share][Report]        │  Suggested teachers (row of cards)│
└───────┴─────────────────────────┴─────────────────────────────────┘
```

**4. Header:** Back arrow + group name.
**5. Navigation:** Reached from Groups List (#10) teacher photo/group name tap, or from a Notification (#5) / Search result (#4). Back returns to the caller.
**6. Main Content (top → bottom):** Teacher profile → action buttons → Group Information (description, stats, rules, allowed content) → Teacher Achievements (hidden entirely if nothing uploaded) → Recent Shared Content → Suggested Teachers.
**7. Bottom Navigation:** Visible on mobile (Groups tab still active); desktop shows the persistent nav rail.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Tapping a "Recent Shared Content" item opens Study Workspace (#7) as sheet/panel. No sheet needed for the page itself since it's a full Level-2 screen.
**10. Popup placement:** Report Group (#28) opens as a centered confirm dialog. "Share Group" copies an invite link and shows a toast (no full popup).
**11. User Journey:** Groups (#10) → tap teacher photo/group name → Group Info → tap "Join Group" (toggles to "Leave Group") → scroll to see achievements/recent content → tap a Suggested Teacher's "Join" to follow another group directly from here.
**12. Screen relationships:** Child of Groups List (#10); parent of Study Workspace (#7) via Recent Shared Content; triggers Report Group (#28); can also open another Group Info instance via Suggested Teachers.

---

## 12. Progress (Student)

**1. Purpose:** Quick, read-only report card — how much studied, quiz performance, streak.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Progress                    │
├──────────────────────────────┤
│ Lectures completed: 18 / 24    │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▁▁▁▁▁▁          │
├──────────────────────────────┤
│ Quiz Scores                    │
│ Physics    82%  ▓▓▓▓▓▓▓▁▁▁     │
│ Chemistry  75%  ▓▓▓▓▓▓▁▁▁▁     │
├──────────────────────────────┤
│ 🔥 Study Streak: 5 days (future)│
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Progress                                                        │
├───────┬───────────────────────────────────────────────────────────┤
│ Nav   │ [Lectures 18/24]  [Physics 82%]  [Chemistry 75%]  [Streak]│
│ rail  │           (stat cards in a row instead of stacked)        │
└───────┴───────────────────────────────────────────────────────────┘
```

**4. Header:** Title "Progress" only — no actions.
**5. Navigation:** Reached via bottom tab `📈`. No forward navigation from stat cards at this fidelity (future: tap a subject → filtered Library view).
**6. Main Content:** Lecture completion bar, per-subject quiz score bars, study streak (future).
**7. Bottom Navigation:** Visible, Progress tab active.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** None.
**11. User Journey:** Bottom tab → Progress → glance at stats → back to any other tab.
**12. Screen relationships:** Level-1 tab, standalone — no children at this fidelity. Teacher accounts see variant #13 instead.

---

## 13. Progress (Teacher snapshot variant)

**1. Purpose:** Lightweight class snapshot for teachers, with a deep link into the full business Dashboard — keeps the Progress tab consistent for both roles without duplicating the Dashboard here.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Progress                    │
├──────────────────────────────┤
│ Class Snapshot                 │
│ 👥 205 students · 3 groups     │
│ 📈 68% avg completion          │
│                                │
│   [ View Full Dashboard → ]    │
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Progress — Class Snapshot        [ View Full Dashboard → ]     │
├───────┬───────────────────────────────────────────────────────────┤
│ Nav   │ 👥 205 students · 3 groups        📈 68% avg completion   │
│ rail  │                    (wider snapshot card, single row)      │
└───────┴───────────────────────────────────────────────────────────┘
```

**4. Header:** Title "Progress"; desktop places the "View Full Dashboard" button in the header row itself.
**5. Navigation:** Reached via bottom tab `📈` for teacher accounts. "View Full Dashboard" → Teacher Dashboard (#19).
**6. Main Content:** One snapshot card — student/group counts + average completion.
**7. Bottom Navigation:** Visible, Progress tab active.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** None.
**11. User Journey:** Bottom tab → Progress (teacher) → glance at snapshot → "View Full Dashboard" → Teacher Dashboard.
**12. Screen relationships:** Level-1 tab (teacher variant of #12); parent of Teacher Dashboard (#19).

---

## 14. Profile

**1. Purpose:** Account control center — plan, credits, storage, settings, help, logout, and (for teachers) the Dashboard entry point.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Profile                     │
├──────────────────────────────┤
│   👤   Rohan Sharma            │
│        rohan@email.com         │
├──────────────────────────────┤
│ 💳 Subscription        ₹499 › │
│ ●  Credits            1,245 › │
│ 💾 Storage            2.1GB › │
│ 📚 Library Size     24 lect › │
│ ⚙️  Settings                 › │
│ ❓ Help                      › │
│ 🎓 Teacher Dashboard          › │  (teacher accounts only)
├──────────────────────────────┤
│        [   Logout   ]         │
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Profile                                                         │
├───────┬───────────────────────────────────────────────────────────┤
│ Nav   │  👤 Rohan Sharma · rohan@email.com   (centered, max       │
│ rail  │  ────────────────────────────────     ~600px column)     │
│       │  💳 Subscription   ●Credits   💾Storage   📚Library      │
│       │  ⚙️ Settings   ❓ Help   🎓 Teacher Dashboard              │
│       │  [ Logout ]                                                │
└───────┴───────────────────────────────────────────────────────────┘
```

**4. Header:** Title "Profile" only.
**5. Navigation:** Reached via bottom tab `👤`. Each row pushes its own Level-2 screen: Subscription (#21), Credits Detail (#15), Storage Detail (#16), Library Size Detail (#17), Settings (#20), Help (#18), Teacher Dashboard (#19, teacher only).
**6. Main Content:** Account header (avatar, name, email) + fixed row order exactly per `IA_SCREEN_HIERARCHY.md` §8 — Subscription · Credits · Storage · Library Size · Settings · Help · (Teacher Dashboard) · Logout.
**7. Bottom Navigation:** Visible, Profile tab active.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None on this screen itself.
**10. Popup placement:** Logout Confirm (#27) appears when tapping "Logout".
**11. User Journey:** Bottom tab → Profile → tap any row → respective detail screen → back → Profile.
**12. Screen relationships:** Level-1 tab; parent of #15, #16, #17, #18, #19, #20, #21; triggers Logout Confirm (#27).

---

## 15. Credits Detail

**1. Purpose:** Let the user see their AI credit balance and recent usage — always shown in **credits**, never rupees, per Credit Economy rules.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Credits                     │
├──────────────────────────────┤
│      ●  1,245 Credits          │
│   ≈ 15 Lecture Sessions        │
├──────────────────────────────┤
│ Recent Usage                   │
│ Ask AI (Normal)        -5 cr  │
│ Quiz Generated         -25 cr │
│ Record 45 min          -80 cr │
├──────────────────────────────┤
│   [   Buy More Credits   ]     │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Credits — ● 1,245 (≈ 15 Lecture Sessions)  [ Buy More Credits ]│
├─────────────────────────────────────────────────────────────────┤
│ Date       Feature              Credits                          │
│ Today      Ask AI (Normal)      -5 cr                            │
│ Today      Quiz Generated       -25 cr                           │
│ Yesterday  Record 45 min        -80 cr        (table layout)     │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Back arrow + "Credits" title (desktop shows balance + CTA inline in header row).
**5. Navigation:** Reached only from Profile (#14) → Credits row. "Buy More Credits" → Subscription (#21).
**6. Main Content:** Balance pill + one primary translated stat (per dashboard UX rule: "≈ N Lecture Sessions") + usage history list.
**7. Bottom Navigation:** Hidden (Level-2 full push on mobile) — desktop keeps nav rail visible.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** Low Credits (#26) may link here when it appears elsewhere in the app.
**11. User Journey:** Profile → Credits → review usage → "Buy More Credits" → Subscription.
**12. Screen relationships:** Child of Profile (#14); forward link to Subscription (#21); referenced by Low Credits popup (#26).

---

## 16. Storage Detail

**1. Purpose:** Transparency on cloud storage (Cloudflare R2) usage, broken down by content type — builds trust that raw audio isn't kept forever.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Storage                     │
├──────────────────────────────┤
│   2.1 GB used of 10 GB         │
│   ▓▓▓▓▓▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁         │
├──────────────────────────────┤
│ Notes & Summaries      0.4 GB │
│ Transcripts            0.9 GB │
│ Quiz & Flashcards       0.2 GB │
│ Images / PDFs           0.6 GB │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Storage — 2.1 GB used of 10 GB   ▓▓▓▓▓▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁          │
├─────────────────────────────────────────────────────────────────┤
│ [Notes 0.4GB] [Transcripts 0.9GB] [Quiz/Flash 0.2GB] [Images 0.6GB]│
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Back arrow + "Storage" title.
**5. Navigation:** Reached only from Profile (#14) → Storage row. Read-only, no forward navigation.
**6. Main Content:** Overall usage bar + breakdown by content type — matches R2 permanent-storage categories (never raw audio, which is deleted after processing).
**7. Bottom Navigation:** Hidden on mobile push; nav rail visible on desktop.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** None.
**11. User Journey:** Profile → Storage → view breakdown → back.
**12. Screen relationships:** Child of Profile (#14) only — no further children.

---

## 17. Library Size Detail

**1. Purpose:** Quick numeric summary of saved content, with a one-tap deep link back into the full Library.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Library Size                │
├──────────────────────────────┤
│  24 Lectures across 3 folders  │
│  📁 Physics     10             │
│  📁 Chemistry    8             │
│  📁 Biology      6             │
├──────────────────────────────┤
│    [   Open Library   ]        │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Library Size — 24 lectures across 3 folders  [ Open Library ] │
├─────────────────────────────────────────────────────────────────┤
│ [📁 Physics 10]   [📁 Chemistry 8]   [📁 Biology 6]              │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Back arrow + "Library Size" title.
**5. Navigation:** Reached only from Profile (#14) → Library Size row. "Open Library" → Library (#8).
**6. Main Content:** Folder-wise lecture counts.
**7. Bottom Navigation:** Hidden on mobile push; nav rail visible on desktop.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** None.
**11. User Journey:** Profile → Library Size → "Open Library" → Library tab.
**12. Screen relationships:** Child of Profile (#14); forward link to Library (#8).

---

## 18. Help / FAQ

**1. Purpose:** Self-serve support so most questions never need a support ticket.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Help                        │
├──────────────────────────────┤
│ 🔍 [ Search help topics... ]  │
├──────────────────────────────┤
│ FAQ                            │
│ › How do I record a lecture?  │
│ › How do credits work?        │
│ › How do I join a group?      │
│ › How do I cancel my plan?    │
├──────────────────────────────┤
│ [   Contact Support   ]        │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Help                                    [ 🔍 Search topics ]  │
├─────────────────────────────────────────────────────────────────┤
│ › How do I record a lecture?     › How do I join a group?        │
│ › How do credits work?           › How do I cancel my plan?      │
│                    [ Contact Support ]                            │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Back arrow + "Help" title + search field.
**5. Navigation:** Reached only from Profile (#14) → Help row. Tapping an FAQ expands its answer inline (accordion) — no further page.
**6. Main Content:** Search bar + FAQ accordion list + "Contact Support" button.
**7. Bottom Navigation:** Hidden on mobile push; nav rail visible on desktop.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None — FAQ answers expand inline, not as a sheet.
**10. Popup placement:** "Contact Support" may open a simple mail/chat popup (future scope — not detailed further at this fidelity).
**11. User Journey:** Profile → Help → search or scroll FAQs → tap a question → read inline answer → back.
**12. Screen relationships:** Child of Profile (#14) only.

---

## 19. Teacher Dashboard

**1. Purpose:** A teacher's simple business view — class folders + public profile + at-a-glance business cards. Cards only, never spreadsheet tables.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← My Classes & Folders   [+] │
├──────────────────────────────┤
│ (Teacher Profile Card)         │
│  👤 Mr. Sharma ✔     [ Edit ] │
│  Physics · M.Sc Physics        │
│  205 Students|3 Groups|42 Lect │
├──────────────────────────────┤
│ (Balance) ● 450 Credits   [+] │
├──────────────────────────────┤
│ Your Classes                   │
│ 📁 Class 12 Physics   45 std ⤴ │
│ 📁 NEET Batch A        32 std ⤴ │
│ 📁 JEE Mains Prep      28 std ⤴ │
├──────────────────────────────┤
│  🏠    📚    👥    📈    👤   │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← My Classes & Folders                                    [ + ]  │
├───────┬───────────────────────────────────────────────────────────┤
│ Nav   │ (Teacher Profile Card — full width)                       │
│ rail  ├───────────────────────────────────────────────────────────┤
│       │ [Students][Subscribers][Revenue][Credits]                │
│       │ [Storage] [Groups]     [Analytics][ + more]  (2×4 grid)  │
└───────┴───────────────────────────────────────────────────────────┘
```

**4. Header:** Title + "+" action to create a new Class Folder.
**5. Navigation:** Reached from Profile (#14) → Teacher Dashboard row, or from Progress teacher snapshot (#13) "View Full Dashboard". "Edit" on the profile card opens the edit sheet.
**6. Main Content:** Teacher public profile card (photo, verified badge, subject, qualification, stats) → credit balance card → business metric cards → class folder list.
**7. Bottom Navigation:** Visible on mobile (Profile tab context retained); nav rail on desktop.
**8. Floating Action Button:** "+" lives in the app bar (acts as the create-folder action) rather than a floating circular button, to match the existing app pattern.
**9. Bottom Sheet placement:** "Edit" profile → edit sheet slides up from bottom (mobile) / modal dialog (desktop). "Share Invite Link" on a class folder → small share sheet.
**10. Popup placement:** "Create New Class Folder" (+ button) opens a small dialog with a name field.
**11. User Journey:** Profile → Teacher Dashboard → view profile/business cards → tap "Edit" to update profile → tap a class folder → "Share Invite Link"/"Copy Code".
**12. Screen relationships:** Child of Profile (#14); also reachable from Progress teacher variant (#13).

---

## 20. Settings

**1. Purpose:** Account-level preferences — notifications, appearance, teacher audio policy, language.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Settings                    │
├──────────────────────────────┤
│ Notifications           [ON] │
│ Dark Mode                [ON] │
│ ☐ Save Original Audio (teacher│
│    accounts only, default OFF)│
│ Language              English>│
│ About ExamSpark               >│
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Settings                                                        │
├─────────────────────────────────────────────────────────────────┤
│ Notifications [ON]         Dark Mode [ON]                        │
│ ☐ Save Original Audio (teacher only, default OFF)                │
│ Language  English >        About ExamSpark >                    │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Back arrow + "Settings" title.
**5. Navigation:** Reached only from Profile (#14) → Settings row. "Language"/"About" rows push tiny sub-screens (not detailed further at this fidelity — out of scope for MVP).
**6. Main Content:** Toggle rows + link rows, no nested settings pages needed yet.
**7. Bottom Navigation:** Hidden on mobile push; nav rail visible on desktop.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** None.
**11. User Journey:** Profile → Settings → toggle a preference → auto-saved → back.
**12. Screen relationships:** Child of Profile (#14) only. "Save Original Audio" row is hidden entirely for student accounts.

---

## 21. Subscription / Plans

**1. Purpose:** Show current plan and let the user upgrade — always framed in credits, never rupee-per-action pricing.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│ ← Subscription                │
├──────────────────────────────┤
│ Current Plan: ₹499 (3,500 cr) │
├──────────────────────────────┤
│ [ Free ]                       │
│ [ ₹199 ]                       │
│ [ ₹499  ✓ current ]            │
│ [ ₹999 ]                       │
│ [ Teacher ₹1999 ]               │
├──────────────────────────────┤
│      [   Upgrade Plan   ]      │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│ ← Subscription — Current: ₹499 (3,500 credits)                   │
├─────────────────────────────────────────────────────────────────┤
│ [Free] [₹199] [₹499 ✓] [₹999] [Teacher ₹1999]   (row of cards)   │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** Back arrow + "Subscription" title + current plan summary.
**5. Navigation:** Reached from Profile (#14) → Subscription row, or from Credits Detail (#15) "Buy More Credits", or from Plan Locked popup (#25) "Upgrade Plan". "Upgrade Plan" → payment flow (Razorpay — Phase 5, not built yet).
**6. Main Content:** Current plan banner + selectable plan cards (Free, ₹199, ₹499, ₹999, Teacher ₹1999) — credits shown, never rupee-per-action.
**7. Bottom Navigation:** Hidden on mobile push; nav rail visible on desktop.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None at this fidelity (payment method selection would be Phase 5 scope).
**10. Popup placement:** None triggered from here at this fidelity.
**11. User Journey:** Profile → Subscription → compare plans → "Upgrade Plan" → (future) payment flow.
**12. Screen relationships:** Child of Profile (#14); also reachable from Credits Detail (#15) and Plan Locked popup (#25).

---

## 22. Auth — Login / Sign Up

**1. Purpose:** Email/Google authentication — existing Supabase logic, UI restyle only, never rewritten.

**2. Mobile Wireframe**

```
┌──────────────────────────────┐
│                                │
│          [ ExamSpark Logo ]   │
│                                │
│  Email     [_______________]  │
│  Password  [_______________]  │
│                                │
│         [    Log In    ]      │
│      [  Continue with Google ]│
│                                │
│    New here? Sign up            │
└──────────────────────────────┘
```

**3. Desktop Wireframe**

```
┌─────────────────────────────────────────────────────────────────┐
│                    [ ExamSpark Logo ]                             │
│         Email     [_____________________]                        │
│         Password  [_____________________]                        │
│                    [       Log In       ]                         │
│                 [   Continue with Google  ]                       │
│                     New here? Sign up                              │
└─────────────────────────────────────────────────────────────────┘
```

**4. Header:** None — logo doubles as the brand header.
**5. Navigation:** Reached from Splash (#1, first time / logged out) or Sign Up Gate (#6) "Sign Up Free", or Profile Logout (#27). Successful login/signup → Home (#2).
**6. Main Content:** Email + Password fields, primary Log In button, Google button, Sign Up toggle link.
**7. Bottom Navigation:** Not shown — pre-authentication screen.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** None.
**10. Popup placement:** Inline error text for invalid credentials (no separate popup needed).
**11. User Journey:** Splash/Sign-Up-Gate/Logout → Auth → enter credentials or Google → Home.
**12. Screen relationships:** Root-level screen — reached from #1, #6, #27; leads only to Home (#2). **Reuses existing `LoginScreen`, `AuthGate`, `SupabaseClient` logic as-is — UI restyle only, per Authentication Rule.**

---

## 23. Popup — Upload Picker

**1. Purpose:** Let the user attach a PDF, image, or audio file into the conversation from Home.

**2. Mobile Wireframe (bottom sheet from 📎)**

```
┌──────────────────────────────┐
│        ▂▂▂ (drag handle)      │
│  Add to conversation           │
│  📄  PDF Document               │
│  🖼️  Image / Photo              │
│  🎵  Audio File                 │
└──────────────────────────────┘
```

**3. Desktop Wireframe (dropdown anchored to 📎 icon)**

```
            ┌───────────────────┐
            │ 📄 PDF Document    │
            │ 🖼️ Image / Photo   │
            │ 🎵 Audio File       │
            └───────────────────┘
```

**4. Header:** "Add to conversation" label (mobile sheet only); desktop dropdown has no header, just the three options.
**5. Navigation:** Opened only from Home's (#2/#3) 📎 icon. Selecting an option closes the picker and starts the respective upload/attach flow inline in the conversation.
**6. Main Content:** Three options — PDF Document, Image/Photo, Audio File.
**7. Bottom Navigation:** Hidden behind the sheet dim (mobile); untouched on desktop (small dropdown doesn't cover the nav rail).
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** THIS screen IS the bottom sheet on mobile — anchored to the bottom, drag handle, dismiss by dragging down or tapping outside.
**10. Popup placement:** On desktop this is the popup (small anchored dropdown, not a full sheet).
**11. User Journey:** Home → tap 📎 → Upload Picker → choose type → file picker (OS native) → attached inline in conversation.
**12. Screen relationships:** Triggered only by Home (#2/#3); no further children beyond the OS file picker (out of wireframe scope).

---

## 24. Popup — Share to Group (Teacher only)

**1. Purpose:** Let a teacher broadcast notes/quiz/homework/announcements to one of their groups — enforces "only teacher shares content" rule.

**2. Mobile Wireframe (bottom sheet)**

```
┌──────────────────────────────┐
│        ▂▂▂ (drag handle)      │
│  Share to Group                │
│  ◉ Physics Batch NEET 2026     │
│  ○ JEE Mathematics Sprint      │
│  ────────────────────────────  │
│  ☐ Pin this to top             │
│      [     Share Now     ]     │
└──────────────────────────────┘
```

**3. Desktop Wireframe (centered modal)**

```
┌───────────────────────────────┐
│ Share to Group                 │
│ ◉ Physics Batch NEET 2026      │
│ ○ JEE Mathematics Sprint       │
│ ☐ Pin this to top               │
│         [ Share Now ]           │
└───────────────────────────────┘
```

**4. Header:** "Share to Group" label inside the sheet/modal.
**5. Navigation:** Opened only from a teacher's Notes/Quiz/Homework "Share" action (in Study Workspace #7 or Home Inline Study Block #3). Closes back to the calling screen on Share/Cancel.
**6. Main Content:** Radio list of the teacher's own groups + "Pin this to top" checkbox + Share Now button.
**7. Bottom Navigation:** Hidden behind sheet dim (mobile); untouched on desktop modal.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Mobile = bottom sheet. Desktop = centered modal dialog instead of a sheet.
**10. Popup placement:** This IS the popup on desktop.
**11. User Journey:** Study Workspace/Inline Study Block (teacher) → tap "Share" → Share to Group → pick group (+ optional pin) → "Share Now" → content appears in that group's Group Info "Recent Shared Content" (#11).
**12. Screen relationships:** Triggered from Study Workspace (#7) / Inline Study Block (#3); result appears inside Group Info (#11). Teacher-only — never shown to student accounts.

---

## 25. Popup — Plan Locked 🔒

**1. Purpose:** Explain that a feature needs a higher plan, without blocking the user from upgrading immediately.

**2. Mobile Wireframe**

```
┌────────────────────────┐
│         🔒              │
│   This feature needs    │
│     the ₹499+ plan      │
│                          │
│   [ Upgrade Plan ]       │
│   [ Maybe Later ]        │
└────────────────────────┘
```

**3. Desktop Wireframe:** Same card, centered modal, identical content.

**4. Header:** None — icon + short message act as the header.
**5. Navigation:** Can appear over any screen where a gated action is tapped (Study Workspace tabs, Home extra actions, Teacher Dashboard analytics, etc.). "Upgrade Plan" → Subscription (#21). "Maybe Later" dismisses.
**6. Main Content:** Lock icon + one-line explanation + two buttons.
**7. Bottom Navigation:** Hidden behind the dimmed background of whichever screen triggered it.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Not a sheet — center-anchored modal on both platforms.
**10. Popup placement:** This IS the popup — dimmed scrim + centered card.
**11. User Journey:** Any gated action tap → server checks plan tier first (per Credit Economy check order) → Plan Locked appears → "Upgrade Plan" → Subscription, or dismiss and stay put.
**12. Screen relationships:** Can be triggered from many screens (#3, #7, #19); leads to Subscription (#21).

---

## 26. Popup — Low Credits

**1. Purpose:** Explain that the user is out of credits for an action, and offer a quick path to top up.

**2. Mobile Wireframe**

```
┌────────────────────────┐
│         ●               │
│   You're out of         │
│   credits for this      │
│   action                │
│                          │
│  [ Buy More Credits ]    │
│  [ Cancel ]              │
└────────────────────────┘
```

**3. Desktop Wireframe:** Same card, centered modal, identical content.

**4. Header:** None — icon + message act as header.
**5. Navigation:** Appears after the plan-tier check passes but the credit-balance check fails (2nd step of Credit Economy's server check order). "Buy More Credits" → Subscription (#21) or Credits Detail (#15).
**6. Main Content:** Credit icon + one-line explanation + two buttons.
**7. Bottom Navigation:** Hidden behind dimmed background.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Not a sheet — center-anchored modal on both platforms.
**10. Popup placement:** This IS the popup.
**11. User Journey:** Gated action tap → plan OK but credits insufficient → Low Credits popup → "Buy More Credits" → Subscription/Credits Detail, or Cancel and stay put.
**12. Screen relationships:** Triggered from any credit-costing action (#3, #7, #19); leads to Subscription (#21) or Credits Detail (#15).

---

## 27. Popup — Logout Confirm

**1. Purpose:** Prevent accidental logout with a single confirm step.

**2. Mobile Wireframe**

```
┌────────────────────────┐
│   Log out of ExamSpark? │
│                          │
│   [ Logout ] [ Cancel ]  │
└────────────────────────┘
```

**3. Desktop Wireframe:** Same card, centered modal, identical content.

**4. Header:** None — the question itself is the header text.
**5. Navigation:** Opened only from Profile (#14) → "Logout". Confirming → Auth (#22). Cancel dismisses back to Profile.
**6. Main Content:** Confirmation question + two buttons.
**7. Bottom Navigation:** Hidden behind dimmed Profile background.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Not a sheet — center-anchored modal on both platforms.
**10. Popup placement:** This IS the popup.
**11. User Journey:** Profile → Logout → confirm → Auth screen (session cleared).
**12. Screen relationships:** Triggered only by Profile (#14); leads to Auth (#22) on confirm.

---

## 28. Popup — Report Group

**1. Purpose:** Let a student flag a group for inappropriate content/behaviour.

**2. Mobile Wireframe**

```
┌────────────────────────┐
│   Report this group?    │
│  Report this group for  │
│  inappropriate content  │
│  or behaviour?           │
│                          │
│  [ Report ] [ Cancel ]   │
└────────────────────────┘
```

**3. Desktop Wireframe:** Same card, centered modal, identical content.

**4. Header:** None — the question itself is the header text.
**5. Navigation:** Opened only from Group Info (#11) → "Report" button. Confirming shows a toast ("Report submitted") and closes; Cancel dismisses back to Group Info.
**6. Main Content:** Confirmation question + two buttons (future: reason picklist could expand this).
**7. Bottom Navigation:** Hidden behind dimmed Group Info background.
**8. Floating Action Button:** None.
**9. Bottom Sheet placement:** Not a sheet — center-anchored modal on both platforms.
**10. Popup placement:** This IS the popup.
**11. User Journey:** Group Info → "Report" → confirm → toast confirmation → back to Group Info.
**12. Screen relationships:** Triggered only by Group Info (#11); no further children.

---

## What This Document Does NOT Include (by design)

- No Dart/Flutter widgets or code
- No navigation/router implementation
- No colors, fonts, spacing, animation specs (Phase 3 — UI Polish)
- No backend/data wiring (Phase 4/5)

---

## Founder Approval Checklist

Please confirm before Phase 2 (AppShell + Flutter) starts:

- [ ] Full screen list (28 screens/states/popups) matches what you expect — nothing missing?
- [ ] Mobile layouts look right (bottom nav, bottom sheet, sticky input)
- [ ] Desktop layouts look right (side rail, split panel, dropdowns)
- [ ] All 12 points per screen are clear (Header/Nav/Content/Bottom bar/FAB/Sheet/Popup/Journey/Relationships)
- [ ] OK to proceed to Phase 2 — build `AppShell` (5-tab navigation) next

**Jab tak upar wala checklist confirm nahi hota, Phase 2 (AppShell / Flutter code) shuru nahi hoga.**

---

## Changelog

| Date | Change |
|------|--------|
| Jul 11, 2026 | v1 — 22 screens/states, Mobile + Desktop, lighter annotation format |
| Jul 11, 2026 | v2 — expanded to 28 screens/states/popups; every screen now follows the full 12-point template (Purpose → Screen relationships) per founder request; added Search Overlay, Notifications Panel, Help/FAQ, Credits Detail, Storage Detail, Library Size Detail |
