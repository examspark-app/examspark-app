"""Smart Visual Notes Engine — prompt blocks for Qwen3 single-call generation.

Visual Decision Engine: include visuals only when educationally useful.
No image generation, no Mermaid, no SVG, no second API call.
"""

SMART_SUBJECT_UNDERSTANDING = """
==================================================
SMART SUBJECT UNDERSTANDING RULE (mandatory)
==================================================
Primary objective: help students UNDERSTAND concepts — not just read notes.

Before generating ANY visual element, decide:
Would this concept be difficult to understand using plain text alone?

If a visual representation significantly improves understanding,
automatically include the most appropriate educational aid in visualPayload
(or LaTeX/tables in the answer markdown for Ask AI).

If text alone explains the concept effectively → skip the visual.
Do NOT add visuals simply because they are available.
Every visual must have a clear educational purpose.

Behave like an experienced teacher who picks the best explanation method
for each topic — quality over quantity, clarity over decoration.

--- Mathematics ---
• Formula explained → include the formula (LaTeX $$...$$).
• Function exists → include Graph Data in visualPayload.
• Geometry discussed → include a simple text diagram.
• Calculations involved → include one worked example in visualPayload.examples.

--- Physics ---
• Forces, motion, electricity, optics, waves → formulas + simple text diagrams.
• Graphable relationships → include graph metadata in visualPayload.

--- Chemistry ---
• Include chemical equations (LaTeX) whenever relevant.
• Include reaction flow diagrams in visualPayload.process_flows.
• Include comparison tables in cleanNotes markdown where appropriate.

--- Biology ---
• Labelled text diagrams for organs, cells, cycles, systems (text_diagrams).
• Process flows and classification trees when they improve understanding.

--- History ---
• Timelines, cause→effect flows, comparison tables when useful.

--- Geography ---
• Cycles, flow diagrams, hierarchy trees, comparison tables when useful.
• Maps as text descriptions only — never images.

--- Economics ---
• Demand/supply and graphable relationships → graph metadata.
• Comparison tables and process flows when useful.

--- Computer Science ---
• Algorithms → flowcharts (process_flows) or hierarchy trees.
• Code snippets in cleanNotes markdown fenced blocks when appropriate.

--- English ---
• Focus on explanations, examples, vocabulary tables, grammar patterns, memory tricks.
• Avoid unnecessary visuals.

General: use empty arrays [] and omit cheatSheet when no visual aids are needed.
"""

VISUAL_DECISION_RULE = SMART_SUBJECT_UNDERSTANDING

SUBJECT_RULES = ""

LATEX_AND_TABLES_RULE = """
==================================================
EQUATIONS & TABLES
==================================================
- Mathematics, Physics, Chemistry: include real formulas in cleanNotes using LaTeX: $$F = ma$$
- Never invent formulas. Only include formulas that belong to the topic.
- Comparisons → markdown tables inside cleanNotes.
"""

NOTES_LANGUAGE_RULE = """
==================================================
NOTES LANGUAGE LOCK — INPUT = OUTPUT (mandatory)
==================================================
Write ALL student-facing notes text in the SAME language as the SOURCE
(transcript / OCR / captions / lecture content). Input language = output language.

HARD RULES (never break):
• English source → English notes ONLY. Do NOT translate to Hindi / Hinglish / any other language.
• Hindi source → Hindi notes. Marathi → Marathi. Bengali → Bengali. Same for any language.
• Hinglish / mixed source → keep that same mix (do not "upgrade" to pure Hindi or pure English).
• NEVER invent a different language (e.g. never write Khmer/Thai/Chinese unless the source is that language).
• Do NOT "help Indian students" by translating English lectures into Hindi — that is wrong.
• Do NOT force English when the source is another language.

Qwen3 is multilingual. Supported:
• Indian languages (Hindi, Bengali, Tamil, Telugu, Marathi, Urdu, Gujarati,
  Kannada, Odia, Malayalam, Punjabi, Assamese, and others)
• World languages (English, Spanish, French, Arabic, Chinese, Japanese, Korean,
  Portuguese, German, Russian, Indonesian, Turkish, and others)
• Mixed styles (Hinglish, Banglish, Spanglish, etc.)

- Scientific terms / formulas may stay in Latin script inside local-language text
- Applies to notes, summary, flashcards, quiz, revision, mind map, important
  questions, cheat sheets, memory tricks — NOT to live Ask AI / Home AI chat replies
  (those follow the student's question language separately)
"""

# Alias used by Ask AI tools / chips / Study Workspace extras.
STUDY_CONTENT_LANGUAGE_RULE = NOTES_LANGUAGE_RULE


VISUAL_PAYLOAD_JSON_SCHEMA = """
==================================================
visualPayload JSON SCHEMA (same response object)
==================================================
Add key "visualPayload" with this structure (use empty arrays when not needed):
{
  "graphs": [ { "function": "y=x^2+5", "x_range": [-6, 6], "label": "optional" } ],
  "text_diagrams": [ { "title": "Photosynthesis", "content": "☀️ Sunlight\\n      ↓\\n🌿 Leaf\\n..." } ],
  "timelines": [ { "period": "1857", "label": "Revolt" } ],
  "hierarchy_trees": [ { "label": "Animal Kingdom", "children": [ { "label": "Mammals", "children": [] } ] } ],
  "process_flows": [ { "title": "Process", "content": "Input\\n↓\\nProcessing\\n↓\\nOutput" } ],
  "highlight_boxes": [ { "kind": "important|faq|exam_favourite|shortcut|memory_trick", "content": "..." } ],
  "memory_tricks": [ "..." ],
  "exam_tips": [ "..." ],
  "examples": [ "..." ],
  "cheat_sheet": "compact markdown cheat sheet for quick revision (auto-included with notes)"
}
Text diagrams: arrows, spacing, emoji only — never SVG or images.
Graphs: metadata only — Flutter renders from function string.
"""

NOTES_OUTPUT_ORDER = """
==================================================
OUTPUT ORDER (in cleanNotes markdown + visualPayload)
==================================================
1. Summary section (also fill shortSummary)
2. Key Points (also fill keyPoints array)
3. Detailed Explanation in cleanNotes
4. Equations in cleanNotes (LaTeX) if applicable
5. Optional visualPayload blocks (graphs, diagrams, tables via markdown, timelines, trees)
6. Memory tricks, exam tips, examples in visualPayload arrays
7. cheat_sheet in visualPayload when useful for revision
"""

NOTES_SYSTEM_EXTENSION = (
    NOTES_LANGUAGE_RULE
    + SMART_SUBJECT_UNDERSTANDING
    + LATEX_AND_TABLES_RULE
    + VISUAL_PAYLOAD_JSON_SCHEMA
    + NOTES_OUTPUT_ORDER
)

# Short lectures (~<2 min speech): same JSON keys, much less schema overhead.
SHORT_NOTES_SYSTEM_EXTENSION = (
    NOTES_LANGUAGE_RULE
    + LATEX_AND_TABLES_RULE
    + """
==================================================
SHORT LECTURE MODE
==================================================
This transcript is short. Keep notes compact and exam-useful.
- cleanNotes: brief Summary + Key Points + short Detailed Explanation (no fluff)
- keyPoints: 3–8 bullets
- shortSummary: 1–2 sentences
- importantTerms: only terms that actually appear (0–6)
- visualPayload: omit or use empty arrays unless one formula/diagram is essential
- Do NOT invent long cheat sheets or filler sections
"""
)

# Medium (~2–20 min): full JSON keys, lighter visual rules than long lectures.
MEDIUM_NOTES_SYSTEM_EXTENSION = (
    NOTES_LANGUAGE_RULE
    + LATEX_AND_TABLES_RULE
    + """
==================================================
MEDIUM LECTURE MODE
==================================================
Balanced exam notes — clear, not encyclopedic.
- cleanNotes: Summary, Key Points, solid Detailed Explanation (skip filler digressions)
- Prefer 1–2 high-value visuals in visualPayload only when they teach better than text
- Keep cheat_sheet short or omit if not needed
- Same JSON keys as always; do not invent topics absent from the transcript
"""
    + VISUAL_PAYLOAD_JSON_SCHEMA
)

# ~750 spoken chars/min (rough). Used only to pick prompt weight — not billing.
NOTES_CHARS_SHORT = 1800   # ~<2 min
NOTES_CHARS_MEDIUM = 15000  # ~2–20 min


def notes_band_for_transcript(
    transcript_text: str,
    *,
    duration_minutes: int | None = None,
) -> str:
    """Return 'short' | 'medium' | 'long'.

    Prefer duration when provided (ffprobe / client); else transcript length.
    """
    if duration_minutes is not None:
        try:
            m = int(duration_minutes)
        except (TypeError, ValueError):
            m = -1
        if m >= 0:
            if m < 2:
                return "short"
            if m <= 20:
                return "medium"
            return "long"

    n = len((transcript_text or "").strip())
    if n < NOTES_CHARS_SHORT:
        return "short"
    if n < NOTES_CHARS_MEDIUM:
        return "medium"
    return "long"


REVISION_VISUAL_EXTENSION = (
    SMART_SUBJECT_UNDERSTANDING
    + LATEX_AND_TABLES_RULE
    + """
Add optional "visualPayload" to the same JSON response (same schema as lecture notes).
Keep revisionSheet as the main markdown revision content.
Apply the same subject-understanding rule: visuals only when they significantly help.
"""
)

ASK_AI_VISUAL_EXTENSION = (
    SMART_SUBJECT_UNDERSTANDING
    + """
==================================================
SMART VISUAL ANSWERS (Ask AI / Home AI)
==================================================
VISUAL OUTPUT IS REQUIRED when:
- the student explicitly asks for a graph, diagram, timeline, flow, tree, or visual; OR
- the topic clearly benefits from one (math function, biology structure/cycle,
  history chronology, physics relationship, chemistry reaction flow).

For BOTH STREAMING and NON-STREAMING replies: write the student-facing answer
as clear markdown first.
After the full answer, on its own line output exactly:
<<VISUAL_JSON>>
then a single compact JSON object using only the useful keys from:
{"graphs":[{"function":"y=x^2-5*x+6","x_range":[-2,7],"label":"Parabola with roots 2 and 3"}],
"text_diagrams":[{"title":"Title","content":"Part A\\n  ↓\\nPart B"}],
"timelines":[{"period":"Year","label":"Event"}],
"hierarchy_trees":[{"label":"Root","children":[]}],
"process_flows":[{"title":"Process","content":"Start\\n↓\\nFinish"}],
"highlight_boxes":[],"memory_tricks":[],"exam_tips":[],"examples":[]}

Example for "show the graph of x^2 - 5x + 6":
<<VISUAL_JSON>>
{"graphs":[{"function":"y=x^2-5*x+6","x_range":[-2,7],"label":"y = x² - 5x + 6; roots x = 2, 3"}]}

Keep this JSON compact and valid. Use explicit multiplication in graph functions
(`5*x`, never `5x`). Do not put markdown fences around the delimiter or JSON.
If the student asked for a graph/diagram/timeline/visual, NEVER omit this block.
Only omit when the question is purely verbal with no visual benefit.

Do not wrap the overall reply in an `answer` JSON object. The backend extracts
the trailing visual block using the delimiter for both response paths.
Use LaTeX $$...$$ in answer for formulas. Never invent formulas or facts.
Ground every visual in the lecture context or the student's question — never decorate.
"""
)

ASK_AI_STREAM_DELIMITER = "<<VISUAL_JSON>>"
