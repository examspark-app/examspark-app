"""Shared quality rule for Home / recording study chips (Quiz, Flashcards, …).

Each chip must do its own study job — and always bias toward exam-important intent.
"""

CHIP_CONTENT_INTENT_RULE = """
CHIP CONTENT INTENT (HARD):
1. Read the source and identify what matters most for Class 11–12 / NEET / board exams
   (definitions that score marks, high-weight concepts, common traps, formulas, steps).
2. Build THIS chip around that important intent — not filler, not repeat of the full essay.
3. Each tool type must feel different:
   Quiz = test understanding · Flashcards = recall · Revision = compact review ·
   Important Qs = likely exam asks · Memory = mnemonics · Mind Map = structure ·
   Common Mistakes = traps · Cheat Sheet = densest facts · Exam Booster = marks tips.
4. Prefer clarity for Indian students. Same language as the source.
5. Skip low-value fluff. If unsure what is important, prioritize exam-scorable facts.
"""
