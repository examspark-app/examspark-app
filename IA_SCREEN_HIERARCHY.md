# ExamSpark — Information Architecture & Screen Hierarchy

> **Phase 1 deliverable** — Jul 2026 (Sonnet 5 / product architecture stage)
> **Status:** 🔒 **LOCKED** — founder approved Jul 11, 2026. No edits without founder approval.
> **Audience:** Founder (non-developer) + designers + Flutter implementers
> **Companion:** [`PRD.md`](PRD.md) · [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) · [`FEATURES.md`](FEATURES.md)

---

## How to Read This Document

Har screen **simple language** mein explain hai — coding ki zaroorat nahi.

**Product ek line mein:** ChatGPT jaisa home + lecture ke andar poori padhai (Study Workspace).

**5 bottom buttons (tabs):** Home · Library · Groups · Progress · Profile — **bas itne hi.**

---

## Part A — Information Architecture (Kya-kya hai app mein)

Socho app ek **school bag** jaisa hai:

| Section | Simple meaning |
|---------|----------------|
| **Home** | AI se baat karo, record karo, upload karo — sab yahi se shuru |
| **Library** | Tumhari saved lectures — folders mein organized |
| **Groups** | Teacher ki class — wahan shared notes/quiz aate hain (chat nahi) |
| **Progress** | Kitna padha, quiz score — tumhara progress |
| **Profile** | Plan, credits, settings, logout |
| **Study Workspace** | Ek lecture kholo → Notes, Quiz, Flashcards sab **ek hi jagah** tabs mein |

**Study Workspace bottom tab nahi hai** — ye lecture open hone par dikhta hai (Library, Groups, ya Home se).

---

## Part B — Navigation Flow (User kahan se kahan jata hai)

### Pehli baar app kholo (bina account)

```
App kholo → Home dikhe
→ Ek baar free Ask AI try karo
→ Answer aaye → "Account banao" popup
→ Sign up → @username mile
```

### Roz ka flow — Student

```
Home (sawal pucho) 
   YA
Library (purani lecture kholo)
   YA  
Groups (teacher ka shared content kholo)
        ↓
   Study Workspace (Notes / Quiz / Flashcards tabs)
        ↓
Progress (dekho kitna complete hua)
```

### Roz ka flow — Teacher

```
Home (lecture record karo)
        ↓
   Same conversation mein Notes ready dikhe
        ↓
Groups → Share to class
        ↓
Profile → Teacher Dashboard (students, revenue cards)
```

### Rule: Kam taps

| Kaam | Kitne tap (target) |
|------|-------------------|
| Ask AI | 1 (type + send) |
| Record | 1 (mic button) |
| Saved lecture kholo | 2 (Library → card) |
| Quiz shuru | 2 (Library → Quiz tab) |

---

## Part C — Screen Hierarchy (Kaun screen kiske andar hai)

### Level 0 — Hamesha dikhe

**Bottom Navigation (5 tabs)** — kabhi 6th mat add karo

### Level 1 — Tab screens (1 tap)

| Screen | Kya hai |
|--------|---------|
| Home | Chat + input bar |
| Library | Folders + lecture list |
| Groups | Group list |
| Progress | Stats |
| Profile | Account list |

### Level 2 — Full screens (2 tap, back se wapas)

| Screen | Kahan se khulta hai |
|--------|---------------------|
| Study Workspace | Library card · Group feed card · Home "expand" |
| Group Feed | Groups → group name tap |
| Folder inside Library | Library → Physics tap |
| Teacher Dashboard | Profile → Teacher Dashboard |
| Subscription detail | Profile → Subscription |
| Settings | Profile → Settings |
| Help | Profile → Help |

### Level 3 — Popups (naya page nahi)

| Popup | Kab dikhe |
|-------|-----------|
| Sign Up Gate | Pehli free Ask AI ke baad |
| Upload picker | Home → 📎 attachment |
| Share to Group | Teacher → Groups → Share |
| Plan locked 🔒 | Feature plan se band ho |
| Not enough credits | Credits khatam |
| Logout confirm | Profile → Logout |

### ❌ Ban hai (alag page mat banao)

- Alag Quiz page, alag Flashcards page
- Processing screen jump after record
- Teacher Portal / Student Portal alag apps jaisa
- 6th bottom tab (Dashboard, Settings, etc.)

---

## Part D — Har Screen — Simple Explanation

### 1. Splash / Loading

**Kya hai:** App start hote hi chhota logo — 1 second se kam.

**User kya kare:** Kuch nahi — automatic aage badhe.

---

### 2. Home (Main Chat Screen) ⭐

**Kya hai:** App ka dil. ChatGPT jaisa — beech mein conversation, neeche input.

**Upar (top bar):**
- Logo — app ka naam
- Search — library/groups mein dhundho
- Credits — kitne AI credits bache (● 1,245)
- Notification — alerts
- Profile photo — shortcut to Profile tab

**Neeche (input bar):**
- 📎 Attachment — PDF, photo, audio file
- Text box — sawal likho
- 🎤 Record — lecture record shuru
- ↑ Send — bhejo

**Bina login:** Ek free Ask AI.

**Record ke baad:** Naya page **nahi** — same chat mein neeche Notes/Summary cards dikhe.

**Simple analogy:** WhatsApp chat jaisa — lekin AI se padhai ke liye.

---

### 3. Inline Study Block (Home ke andar)

**Kya hai:** Lecture process hone ke baad AI message ke neeche chhota study area.

**Dikhega:**
- Tabs: Notes | Summary | Transcript
- Buttons: Flashcards, Quiz, Revision, Ask AI…

**"Open full workspace"** tap → bada Study Workspace khule.

---

### 4. Study Workspace ⭐ (Hero — sabse important)

**Kya hai:** Ek lecture ki **poori padhai ek jagah**. ChatGPT se yahi alag banata hai.

**Upar:** Lecture title, teacher name, date, subject

**Tabs (ek line mein):**
Notes · Summary · Transcript · Flashcards · Quiz · Revision · Ask AI

**Phone par:** Neeche se sheet upar slide karo (bottom sheet)

**Computer par:** Right side panel mein tabs

**User kya kare:** Tab tap karo — page change nahi, sirf content change.

**Simple analogy:** Ek kitab kholi — chapters tabs hain, alag kitab nahi kholni.

---

### 5. Library

**Kya hai:** Tumhari saved lectures ki almari.

**Sections:**
- **Recent** — abhi kya khola
- **Favorites** — star wali lectures
- **Folders** — Physics, Chemistry, Biology…
- **Search** — kuch bhi dhundho

**Har lecture card:**
```
Title
Teacher · Subject · Date    ⋮
```

**Tap card** → Study Workspace

**Auto-save:** Jo bhi AI banaye — automatically yahan aa jaye.

---

### 6. Groups

**Kya hai:** Teacher ki class — WhatsApp list jaisa feel, **lekin chat nahi**.

**Student dekhe:**
- Group list (Physics Batch, Chemistry…)
- Group kholo → feed (Lecture 12, Homework, Quiz…)
- Koi message box **nahi**
- Card tap → Study Workspace

**Teacher dekhe:**
- Same + **+ New Group** + **Share** button
- Pin important posts top par

**Rule:** Sirf teacher share kare. Student sirf invite link share kar sakta (content nahi).

---

### 7. Progress

**Kya hai:** Tumhara study report card.

**Dikhe sakta hai:**
- Kitni lectures complete
- Quiz scores
- Study streak (future)

**Teacher:** Chhota class snapshot + link to full Dashboard.

---

### 8. Profile

**Kya hai:** Account control center.

| Row | Matlab |
|-----|--------|
| **Subscription** | Kaunsa plan hai, upgrade |
| **Credits** | AI balance detail |
| **Storage** | Kitni space use ho rahi |
| **Library Size** | Kitni lectures saved |
| **Settings** | Notifications, teacher audio save toggle |
| **Help** | FAQ, support |
| **Teacher Dashboard** | Sirf teachers — business cards |
| **Logout** | Bahar niklo |

---

### 9. Teacher Dashboard

**Kya hai:** Teacher ka simple business view — Excel nahi, **sirf cards**.

**Cards:** Students · Subscribers · Revenue · Credits used · Storage · Groups · Analytics (4-5 lines)

**Entry:** Profile se — bottom tab nahi.

---

### 10. Auth (Login / Sign Up)

**Kya hai:** Email / Google se account.

**Kab:** Sign Up Gate ke baad ya Profile se logout ke baad.

---

### 11. Subscription / Plans

**Kya hai:** Free, ₹199, ₹499, ₹999, Teacher plans.

**Credits dikhe** — rupee per AI action **nahi**.

**Entry:** Profile → Subscription

---

### 12. Settings

**Kya hai:** Account preferences.

**Teacher extra:** ☐ Save Original Audio (default OFF)

---

### Popups (short)

| Popup | Simple meaning |
|-------|----------------|
| **Sign Up Gate** | "Account banao taaki save ho" |
| **Plan Locked** | "Yeh feature ₹499+ plan mein hai" |
| **Low Credits** | "Credits khatam — upgrade karo" |
| **Upload Picker** | PDF / Image / Audio choose karo |
| **Share Sheet** | Teacher: kaunsa group, kya share |

---

## Part E — Teacher Flow (Step by step)

```
1. Login as Teacher
2. Home → 🎤 Record lecture
3. Wait — same chat mein "Processing…" dikhe
4. Notes ready — inline cards dikhe
5. Groups tab → Physics Batch → Share
6. Students ko feed mein dikhe
7. Profile → Dashboard → dekho kitne students active
```

**Teacher kabhi nahi:** Student jaisa message nahi bhejta groups mein spam ke taur par — sirf content broadcast.

---

## Part F — Student Flow (Step by step)

```
1. Login / Sign up (ya pehle free Ask AI)
2. Home → sawal pucho YA Groups → join code
3. Groups → Physics Batch → Lecture 12 tap
4. Study Workspace → Quiz tab → quiz do
5. Flashcards tab → revise
6. Progress → score dekho
```

**Student kabhi nahi:** Notes/PDF share, upload, ya group mein message.

---

## Part G — Library Flow

```
1. Library tab
2. Physics folder (ya Search)
3. Lecture card tap
4. Study Workspace — default Notes tab
5. Transcript tab — teacher ki original explanation padho
6. Quiz tab — practice
```

Har lecture = ek library entry. Sab kuch usi lecture ke andar.

---

## Part H — Group Flow

**Teacher:**
```
Groups → + New Group → name do
→ Home se record → Share to group
→ Pin agar important ho
```

**Student:**
```
Groups → Join (code/link)
→ Feed scroll → card tap → Study Workspace
```

---

## Part I — Mobile vs Desktop Layout

| Element | Phone | Computer |
|---------|-------|----------|
| Bottom 5 tabs | ✅ Yes | ✅ Yes (or side rail optional) |
| Home input | Sticky bottom | Sticky bottom |
| Study Workspace | Bottom sheet (swipe up) | Right split panel |
| Conversation width | Full screen | Max ~768px centered |
| Teacher Dashboard | Scroll cards | 2×4 card grid |

**Design:** White background, black text, minimal — premium AI app, colorful school app nahi.

---

## Part J — Component Structure (Building blocks — no code yet)

Socho LEGO blocks — har screen in blocks se bane:

| Component | Use kahan |
|-----------|-------------|
| `AppShell` | 5 bottom tabs wrapper — poori app |
| `TopBar` | Logo, search, credits, bell, avatar |
| `BottomInputBar` | 📎 text 🎤 send |
| `ConversationList` | Home messages |
| `MessageBubble` | Ek message (user ya AI) |
| `LectureResultCard` | Home mein inline study |
| `StudyWorkspace` | **Sabse important** — shared everywhere |
| `WorkspaceTabBar` | Notes, Summary, Quiz… tabs |
| `WorkspaceContent` | Active tab ka content |
| `LectureCard` | Library / Group list item |
| `GroupFeedCard` | Group mein shared item |
| `ProfileRow` | Profile list item |
| `DashboardMetricCard` | Teacher number card |
| `CreditsPill` | Top bar credit display |

**Rule:** Ek component, kai jagah — duplicate UI nahi.

---

## Part K — Folder Structure (Flutter — plan only)

```
examspark_frontend/lib/
├── app/                 ← App start, theme, router shell
├── core/
│   ├── constants/       ← Credit costs, plan gating (already exists)
│   ├── theme/           ← Colors, typography
│   └── router/          ← Navigation (5-tab shell)
├── features/
│   ├── home/            ← Chat screen + input + inline result
│   ├── library/         ← Folders, search, favorites
│   ├── groups/          ← List + feed + share
│   ├── progress/        ← Stats
│   ├── profile/         ← Account rows
│   ├── workspace/       ← StudyWorkspace (SHARED)
│   ├── teacher/         ← Dashboard only
│   └── auth/            ← Login, signup gate
└── shared/widgets/      ← TopBar, BottomInputBar, cards
```

**Abhi move mat karo** — Phase 2 mein implement karte waqt gradually migrate karenge.

---

## Part L — Feature Placement (Quick reference)

| Feature | Primary home |
|---------|--------------|
| Record | Home 🎤 |
| Ask AI (general) | Home input |
| Ask AI (lecture) | Workspace tab |
| PDF/Image upload | Home 📎 |
| Notes, Quiz, Flashcards | Workspace tabs |
| Saved lectures | Library |
| Teacher content | Groups feed |
| Plan, credits | Profile |
| Analytics | Teacher Dashboard |
| Progress stats | Progress tab |

Full matrix: [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) §15

---

## Part M — What NOT to Build Yet

| ❌ Abhi nahi | Kyun |
|-------------|------|
| Supabase setup | UI lock pehle |
| SQL / database | UI lock pehle |
| RAG pipeline | UI lock pehle |
| Payments live | UI lock pehle |
| FastAPI deploy | UI lock pehle |

**Pehle:** IA + Screen Hierarchy ✅ (this doc) → Flutter UI skeleton → phir backend.

---

## Part N — Phase Gate

**Phase 1 (this doc):** ✅ Complete — ask founder before Phase 2.

**Phase 2 next:** Flutter UI screens, theme, responsive layouts.

Founder confirm kare: *"Phase 2 shuru karo"* — tab code likhenge.

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Phase 1 IA + Screen Hierarchy — founder-friendly glossary |
