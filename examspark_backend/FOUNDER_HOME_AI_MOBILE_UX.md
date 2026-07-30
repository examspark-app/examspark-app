# ExamSpark Home AI Mobile UX Simplification (Founder Lock)

**Locked:** Jul 18, 2026  
**Scope:** UI / UX / interaction only  
**Do not:** remove backend APIs · change AI Ask logic · break existing `tool_type` rows

---

## Objective

Home AI = premium **AI Study Workspace** on mobile — not a generic chatbot.

## Layout (mobile-first)

```text
Question
  ↓
AI Answer Card
  ↓
Visual Card (only if visual_payload exists; collapsible)
  ↓
Primary chips (max 5, horizontal scroll) + More
  ↓
Chip content → bottom sheet (same session, no chat dump)
  ↓
Follow-up input
```

## Primary chips (fixed order)

1. Quiz  
2. Flashcards  
3. Visual  
4. Revision  
5. Learn More  

## More sheet (unique jobs only)

Important Questions · Memory · Mind Map · Common Mistakes · PYQs (stub)

## Removed from UI (duplicate content — Jul 18)

Honest audit: free KO derive was reprinting the **same paragraphs** with a new title.

| Chip | Why hidden |
|------|------------|
| **Cheat Sheet** | Same bullets/formulas as **Revision** |
| **5 Min** | Same points as **Revision**, only a timer frame |
| **Exam Booster** | Overlaps **Revision** + **Important Qs** (marks script) |
| **Teacher Tips** | Same answer/explanation wrapped as a “lesson plan” |

Backend still accepts these `tool_type`s (safe; no SQL delete). UI does not show them.

## Keep (different learning job)

| Chip | Job |
|------|-----|
| Quiz | MCQ only |
| Flashcards | Flip Q/A |
| Visual | Diagram card / flow |
| Revision | Compact exam notes |
| Learn More | Depth / analogy / bridge |
| Important Qs | Exam-paper questions |
| Memory | Mnemonics / cue scenes |
| Mind Map | Hierarchy |
| Common Mistakes | Trap + fix |

## Behaviour

- Chip tap → Phase 4C tool sheet (not a new chat bubble)
- Cached badge when already generated
- Credits unchanged: Ask paid · chips free from KO · Regenerate paid

## Code

- `examspark_frontend/.../home_study_chip_bar.dart`
- `examspark_frontend/.../home_ai_visual_card.dart`
- `examspark_frontend/.../ai_assistant_message.dart`
