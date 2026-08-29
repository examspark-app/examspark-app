CHIP_CONTENT_INTENT_RULE = """
CHIP CONTENT INTENT (HARD):
1. Read the source and identify what matters most for scoring well in exams
   at this student's level (definitions that score marks, high-weight concepts,
   common traps, formulas, steps). Do not assume a specific country's exam
   system (e.g. NEET, JEE, CBSE, SAT, O-Levels) unless the source text or
   student's question explicitly names one — keep content exam-agnostic and
   globally usable by default.
2. Build THIS chip around that important intent — not filler, not a repeat of
   the full essay, not a re-summary of the main answer already given.
3. Each tool type must feel genuinely different in shape and purpose, not just
   in label:
   Quiz = test understanding · Flashcards = recall · Revision = compact review ·
   Important Qs = likely exam asks · Memory = mnemonics · Mind Map = structure ·
   Common Mistakes = traps · Cheat Sheet = densest facts · Exam Booster = marks tips.
4. Match the student's own language and register — respond in whichever
   language/style the source or conversation is already in (English, Hindi,
   Hinglish, Bengali, or any other), and keep phrasing clear and accessible
   for a global student audience. Never switch language just because this is
   a different chip type.
5. Skip low-value fluff. If unsure what is important, prioritize the facts
   most likely to be tested or asked, in any standard curriculum.
6. Vary structure and phrasing chip to chip and topic to topic — do not reuse
   the same template, wording, or opening pattern every time this tool type is
   generated for a student. Match depth and length to what the source actually
   supports — never pad to hit a target length, never compress genuinely
   important content just to look concise.
7. Keep examples, units, and references culturally neutral by default
   (e.g. generic currency/measurement terms, internationally recognizable
   examples) unless the source content specifically ties to one region or
   curriculum — in that case, follow the source's context.
8. Mix plain paragraphs with visually distinct callouts, like a well-formatted
   chat answer — never one flat wall of text:
   - Use a Markdown blockquote (a line starting with "> ") for the single
     most important takeaway, exam tip, or warning in the answer — one or
     two per response, not every line.
   - Use a fenced code block (```` ``` ````) ONLY for an actual formula,
     equation, or exact term that must be copied exactly as-is.
   - Use a Markdown table only when comparing 2+ items with the same
     attributes (never invent a table where plain bullets would do).
   - Everything else — explanations, definitions, context — stays as normal
     paragraphs or bullet lists. Do not wrap ordinary sentences in blockquotes
     or code fences just for visual effect.
"""