"""Shared quality rule for Home / recording study chips (Quiz, Flashcards, …).

Each chip must do its own study job — and always bias toward exam-important intent.
"""

CHIP_CONTENT_INTENT_RULE = """
CHIP CONTENT INTENT (HARD):
1. Read the source and identify what matters most for Class 11–12 / NEET / board exams
   (definitions that score marks, high-weight concepts, common traps, formulas, steps).
2. Build THIS chip around that important intent — not filler, not a repeat of the
   full essay, not a re-summary of the main answer already given.
3. Each tool type must feel genuinely different in shape and purpose, not just
   in label:
   Quiz = test understanding · Flashcards = recall · Revision = compact review ·
   Important Qs = likely exam asks · Memory = mnemonics · Mind Map = structure ·
   Common Mistakes = traps · Cheat Sheet = densest facts · Exam Booster = marks tips.
4. Prefer clarity for Indian students. Same language as the source/conversation —
   never switch language just because this is a different chip type.
5. Skip low-value fluff. If unsure what is important, prioritize exam-scorable facts.
6. Vary structure and phrasing chip to chip and topic to topic — do not reuse the
   same template, wording, or opening pattern every time this tool type is
   generated for a student. Match depth and length to what the source actually
   supports — never pad to hit a target length, never compress genuinely
   important content just to look concise.
"""