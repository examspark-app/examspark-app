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
- Formula explained → include the formula (LaTeX $$...$$).
- Function exists → include Graph Data in visualPayload.
- Geometry discussed → include a simple text diagram.
- Calculations involved → include one worked example in visualPayload.examples.

--- Physics ---
- Forces, motion, electricity, optics, waves → formulas + simple text diagrams.
- Graphable relationships → include graph metadata in visualPayload.

--- Chemistry ---
- Include chemical equations (LaTeX) whenever relevant.
- Include reaction flow diagrams in visualPayload.process_flows.
- Include comparison tables in cleanNotes markdown where appropriate.
- Composition/percentage data (e.g. mixture ratios) → pie_charts.

--- Biology ---
- Labelled text diagrams for organs, cells, cycles, systems (text_diagrams).
- Process flows and classification trees when they improve understanding.

--- History ---
- Timelines, cause→effect flows, comparison tables when useful.

--- Geography ---
- Cycles, flow diagrams, hierarchy trees, comparison tables when useful.
- Maps as text descriptions only — never images.
- Numeric comparisons (rainfall, population, area, climate data) → bar_charts.
- Percentage/composition data (land use, resource distribution) → pie_charts.

--- Economics ---
- Demand/supply and graphable relationships → graph metadata.
- Comparison tables and process flows when useful.
- Category-vs-value data (GDP by sector, income comparison) → bar_charts.
- Percentage breakdowns (budget allocation, market share) → pie_charts.

--- Computer Science ---
- Algorithms → flowcharts (process_flows) or hierarchy trees.
- Code snippets in cleanNotes markdown fenced blocks when appropriate.

--- English ---
- Focus on explanations, examples, vocabulary tables, grammar patterns, memory tricks.
- Avoid unnecessary visuals.

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

# New — explicit markdown structure rule so the Flutter client's header /
# bold-highlight rendering (added Aug 2026: colored h1-h3, accent-colored
# **bold**, and the dark terminal-style diagram card) actually gets
# structured content to render instead of a single flat paragraph.
MARKDOWN_STRUCTURE_RULE = """
==================================================
ANSWER STRUCTURE — HEADERS & HIGHLIGHTS (mandatory)
==================================================
Structure every answer longer than 2-3 sentences using markdown headers and
bold highlights — the student app renders these with distinct colors and
spacing, so plain unstructured paragraphs look flat and are harder to scan.

- Use "## " for each major section of the answer (e.g. "## Core Idea",
  "## How It Works", "## Example", "## Common Mistakes"). Pick section
  names that fit the actual question — do not force sections that add
  no value for a short/simple answer.
- Use "**bold**" around the 3-6 most important terms, numbers, or phrases
  per answer — the exact words a student should remember for an exam.
  Do not bold entire sentences; bold single words or short phrases only.
- Keep bullet points ("- ") for lists of points, steps, or examples.
- A short factual answer (one sentence, a yes/no, a quick clarification)
  does NOT need headers — use headers only when the answer has more than
  one distinct part worth separating.
- Never use "#" (h1) — start at "##" (h2) or "###" (h3) so headers don't
  visually compete with the app's own screen titles.
"""

NOTES_LANGUAGE_RULE = """
==================================================
NOTES LANGUAGE LOCK — INPUT = OUTPUT (mandatory)
==================================================
Write ALL student-facing notes text in the SAME language as the SOURCE
(transcript / OCR / captions / lecture content). Input language = output language.

HARD RULES (never break):
- English source → English notes ONLY. Do NOT translate to Hindi / Hinglish / any other language.
- Hindi source → Hindi notes. Marathi → Marathi. Bengali → Bengali. Same for any language.
- Hinglish / mixed source → keep that same mix (do not "upgrade" to pure Hindi or pure English).
- NEVER invent a different language (e.g. never write Khmer/Thai/Chinese unless the source is that language).
- Do NOT "help Indian students" by translating English lectures into Hindi — that is wrong.
- Do NOT force English when the source is another language.

Qwen3 is multilingual. Supported:
- Indian languages (Hindi, Bengali, Tamil, Telugu, Marathi, Urdu, Gujarati,
  Kannada, Odia, Malayalam, Punjabi, Assamese, and others)
- World languages (English, Spanish, French, Arabic, Chinese, Japanese, Korean,
  Portuguese, German, Russian, Indonesian, Turkish, and others)
- Mixed styles (Hinglish, Banglish, Spanglish, etc.)

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
  "bar_charts": [ { "title": "Rainfall by Season (mm)", "data": [ { "label": "Winter", "value": 20 }, { "label": "Summer", "value": 150 } ] } ],
  "pie_charts": [ { "title": "Atmosphere Composition", "data": [ { "label": "Nitrogen", "value": 78 }, { "label": "Oxygen", "value": 21 } ] } ],
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
Bar/pie charts: use for comparisons, percentages, or category-vs-value data
(e.g. rainfall by season, population by state, composition %, survey results).
Values must be real numbers from the topic — never invented statistics.
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

# ============================================================================
# ASK_AI_VISUAL_EXTENSION — strengthened Aug 2026 for reliability.
#
# Why the extra reminders: long system prompts suffer from the "lost in
# the middle" effect — models pay more attention to instructions at the
# very start and very end of a prompt than to the middle. The core visual
# rule below sits in the middle, so we now (1) open with a mandatory
# self-check the model must run before finishing, and (2) close with a
# final reminder repeating the same check with a "default to including a
# visual when unsure" bias. This costs zero extra tokens/API calls — it's
# pure prompt-wording reinforcement, not a second model call.
# ============================================================================
VISUAL_AUTO_TRIGGER_RULES = """
==================================================
VISUAL AUTO-TRIGGER RULES (Home AI / Study AI)
==================================================

RULE 1 — SMART AUTO-TRIGGER
If the educational answer contains a concept that is significantly easier
to understand visually, automatically generate <<VISUAL_JSON>>.
The student does NOT need to ask for a diagram.
Trigger strongly for:
- Process, Cycle, Mechanism, Reaction, Classification, Comparison, Timeline,
  Cause & Effect, Structure, Spatial relationship, Formula relationship,
  Graphable mathematical relationship, Force/vector relationship, Motion/trajectory,
  Scientific system.

RULE 2 — SUBJECT-AWARE VISUAL TYPE
Choose the most specific and appropriate visual structure for the subject:
• Biology:
  - process_flow (Photosynthesis, Respiration, Digestion)
  - cycle (Cell cycle, Mitosis, Nitrogen cycle, Water cycle)
  - labelled_structure (Cell, Neuron, DNA, Flower, Organ)
  - system_diagram (Circulatory, Nervous, Endocrine)
  - comparison (Mitosis vs Meiosis, Prokaryote vs Eukaryote)
• Chemistry:
  - reaction_flow (Stepwise organic/inorganic synthesis, Haber process)
  - molecular_structure / atom_structure (Bohr model, Orbitals, Lewis dots)
  - bonding (Ionic vs Covalent, Hydrogen bonding)
  - apparatus & comparison (Acids vs Bases, Endothermic vs Exothermic)
• Physics:
  - free_body_diagram (Forces on mass: gravity, normal, friction, applied: F=ma)
  - gravity_diagram (Orbital paths, gravitational pull)
  - projectile_motion (Trajectory, angles, range, peak)
  - ray_diagram (Lenses, mirrors, focal length, refraction)
  - circuit (Series, parallel, Ohm's law, Kirchhoff's current/voltage)
  - wave (Wavelength, frequency, crest, trough, nodes)
  - formula_relationship & graph
• Math:
  - function_graph (Parabolas y=a*x^2+b*x+c, lines y=m*x+c, trig sin(x))
  - coordinate_graph & number_line (Inequalities, roots, intervals)
  - triangle & circle geometry (Angles, Pythagoras, chords, tangents)
  - probability_tree & statistics_chart (Bar charts, distributions)
  - formula_relationship
• History & Social Science:
  - timeline (Dates, periods, milestones, revolts, treaties)
  - cause_effect (Events leading to outcome, consequences)
  - event_sequence & comparison (Dynasties, policies, regimes)
• Computer Science:
  - flowchart (Start -> Decision -> Action -> End)
  - algorithm / state_machine (Step transitions)
  - binary_tree & linked_list (Node relationships, pointers)
  - architecture (Client -> API -> Database)

RULE 3 — SKIP (DO NOT GENERATE VISUAL FOR):
- "Hi", "Hello", "Hey", "Thanks", "Thank you", simple greetings
- Simple one-line factual answers (e.g. "Who invented X", "What is capital of Y")
- Trivial arithmetic (e.g. "2+2=4")
- Very short answers where visual adds zero learning value

RULE 4 — REAL EDUCATIONAL CONTENT ONLY
Every visual must be based on the actual question and answer.
Never generate generic placeholder diagrams, unrelated shapes, invented facts, invented values, or decorative visuals.
Use actual formulas, numbers, labels, relationships, steps, directions, and scientific concepts.

RULE 5 — MOST SPECIFIC VISUAL
Always choose the most specific supported visual type:
Gravity → gravity_diagram | Projectile → projectile_motion | F = ma → free_body_diagram
y = x² → function_graph | Triangle angle → triangle | Photosynthesis → process_flow
DNA → labelled_structure | Algorithm → flowchart

RULE 6 — EXISTING VISUAL SYSTEM COMPATIBILITY
Output must conform to the valid JSON structure under <<VISUAL_JSON>>:
{
  "graphs": [ { "function": "y=x^2-5*x+6", "x_range": [-2, 7], "label": "Parabola description" } ],
  "bar_charts": [ { "title": "...", "data": [ { "label": "...", "value": 10 } ] } ],
  "pie_charts": [ { "title": "...", "data": [ { "label": "...", "value": 20 } ] } ],
  "text_diagrams": [ { "title": "Specific Topic Diagram", "content": "Labelled ASCII / Unicode Diagram with arrows and emoji" } ],
  "process_flows": [ { "title": "Step Flow", "content": "Step 1\\n↓\\nStep 2\\n↓\\nStep 3" } ],
  "timelines": [ { "period": "Year/Epoch", "label": "Event" } ],
  "hierarchy_trees": [ { "label": "Root Category", "children": [ { "label": "Subcategory", "children": [] } ] } ],
  "highlight_boxes": [ { "kind": "important|exam_favourite|shortcut", "content": "Key takeaway / formula" } ],
  "memory_tricks": [], "exam_tips": [], "examples": []
}

RULE 7 — VISUAL TIMING & PLACEMENT
First, write the complete, natural student-facing markdown answer.
Only AFTER the full text answer has completed, output on its own line:
<<VISUAL_JSON>>
followed immediately by the single compact valid JSON object.

RULE 9 — VISUAL OUTPUT FORMAT
Return structured VISUAL_JSON only.
Do NOT return image-generation instructions, image URLs, base64 strings, or fake image markdown.
The client renderer produces the visual card from this JSON.

RULE 10 — QUALITY
Visuals must be clean, educational, readable, accurate, textbook-like, and uncluttered.
Math/Physics visuals: actual graphs, curves, vectors, arrows, formulas.
Conceptual subjects: process steps, labelled structures, clear hierarchy.
Do not force the same visual style on every subject.
"""

ASK_AI_VISUAL_EXTENSION = (
    SMART_SUBJECT_UNDERSTANDING
    + MARKDOWN_STRUCTURE_RULE
    + VISUAL_AUTO_TRIGGER_RULES
)

ASK_AI_STREAM_DELIMITER = "<<VISUAL_JSON>>"