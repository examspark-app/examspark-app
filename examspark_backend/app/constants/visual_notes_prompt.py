"""Smart Visual Notes Engine — prompt blocks for Qwen3 single-call generation.

Visual Decision Engine:
- Include visuals only when educationally useful.
- Supports dynamic AI-generated whiteboards.
- No image generation.
- No Mermaid.
- No SVG.
- No second API call.
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
- Formula explained → include the formula in cleanNotes using LaTeX.
- Function exists → include a graph or dynamic whiteboard graph.
- Geometry discussed → include a labelled geometry whiteboard when useful.
- Calculations involved → include one worked example in visualPayload.examples.
- Coordinate relationships → use graph or whiteboard axes/points when useful.
- Algebraic relationships → use formula blocks and visual relationships.

--- Physics ---
- Forces, motion, electricity, optics, waves → formulas + diagrams.
- Free-body situations → prefer dynamic whiteboard arrows/vectors.
- Projectile motion → use trajectory + vectors + labels.
- Gravity/orbits → use circles, arrows, bodies, labels.
- Circuits → use a dynamic whiteboard circuit when useful.
- Waves → use labelled wave elements.
- Graphable relationships → include graph metadata or whiteboard graph.

--- Chemistry ---
- Include chemical equations in cleanNotes using LaTeX when relevant.
- Reaction sequences → prefer dynamic whiteboard process diagrams.
- Molecular / atomic structures → use labelled whiteboard diagrams.
- Bonding → use circles, labels, arrows, connections, and formulas.
- Reaction flow → use process_flows or whiteboard.
- Composition/percentage data → use pie_charts when appropriate.

--- Biology ---
- Labelled structures → prefer dynamic whiteboard diagrams.
- Cells, organs, systems, DNA, neurons → use labelled diagrams.
- Cycles → use arrows and connected stages.
- Processes → use process flows or whiteboard diagrams.
- Classification → use hierarchy trees.
- Comparison → use structured visual comparison when useful.

--- History ---
- Timelines for dates and events.
- Cause → effect relationships with arrows.
- Sequences and comparisons where useful.
- Dynamic whiteboard can be used for event relationships when it is
  clearer than a simple timeline.

--- Geography ---
- Cycles and physical processes → dynamic whiteboard or process flow.
- Spatial relationships → dynamic whiteboard when useful.
- Maps as text descriptions only — never images.
- Numeric comparisons → bar_charts.
- Percentage/composition data → pie_charts.
- Hierarchies → hierarchy_trees.

--- Economics ---
- Demand/supply → graphs or dynamic whiteboard axes/curves.
- Formula relationships → formulas + graph/whiteboard.
- Process relationships → arrows and boxes.
- Category-vs-value data → bar_charts.
- Percentage breakdowns → pie_charts.

--- Computer Science ---
- Algorithms → dynamic whiteboard flowcharts or process_flows.
- State transitions → dynamic whiteboard.
- Trees / linked lists → dynamic whiteboard or hierarchy trees.
- System architecture → boxes + arrows in whiteboard.
- Code snippets → cleanNotes markdown fenced code blocks.

--- English ---
- Focus on explanations, examples, vocabulary, grammar patterns,
  memory tricks and tables.
- Use visualPayload only when it significantly improves learning.
- Avoid decorative visuals.

General:
- Use empty arrays [] when a visual category is not needed.
- Omit whiteboard when no visual aid is educationally useful.
- Every whiteboard must explain something concrete.
- Never create decorative shapes just to make the UI look attractive.
"""


VISUAL_DECISION_RULE = SMART_SUBJECT_UNDERSTANDING


SUBJECT_RULES = ""


LATEX_AND_TABLES_RULE = """
==================================================
EQUATIONS & TABLES
==================================================
- Mathematics, Physics, Chemistry: include real formulas in cleanNotes
  using LaTeX, for example $$F = ma$$.
- Never invent formulas.
- Only include formulas that belong to the topic.
- Comparisons → markdown tables inside cleanNotes.
- Keep formulas mathematically accurate.
- Do not replace mathematical formulas with plain English when LaTeX
  is more appropriate.
"""


MARKDOWN_STRUCTURE_RULE = """
==================================================
ANSWER STRUCTURE — HEADERS & HIGHLIGHTS (mandatory)
==================================================
Structure every answer longer than 2-3 sentences using markdown headers and
bold highlights — the student app renders these with distinct colors and
spacing, so plain unstructured paragraphs look flat and are harder to scan.

- Use "## " for each major section of the answer.
- Use section names that fit the actual question.
- Do not force sections that add no value to a short/simple answer.
- Use "**bold**" around the 3-6 most important terms, numbers, or phrases
  per answer.
- Do not bold entire sentences.
- Keep bullet points ("- ") for lists of points, steps, or examples.
- A short factual answer does not need headers.
- Never use "#" (h1).
- Start at "##" (h2) or "###" (h3).
"""


NOTES_LANGUAGE_RULE = """
==================================================
NOTES LANGUAGE LOCK — INPUT = OUTPUT (mandatory)
==================================================
Write ALL student-facing notes text in the SAME language as the SOURCE
(transcript / OCR / captions / lecture content).

Input language = output language.

HARD RULES:
- English source → English notes ONLY.
- Hindi source → Hindi notes.
- Marathi → Marathi.
- Bengali → Bengali.
- Same for any language.
- Hinglish / mixed source → preserve the same mix.
- NEVER invent a different language.
- Do NOT translate an English lecture into Hindi automatically.
- Do NOT force English when the source is another language.

Scientific terms / formulas may stay in Latin script inside local-language
text.

Applies to notes, summary, flashcards, quiz, revision, mind map, important
questions, cheat sheets and memory tricks.

This rule does NOT control live Ask AI / Home AI chat replies.
Those follow the student's question language separately.
"""


# Alias used by Ask AI tools / chips / Study Workspace extras.
STUDY_CONTENT_LANGUAGE_RULE = NOTES_LANGUAGE_RULE


# ======================================================================
# LEGACY / STANDARD VISUAL PAYLOAD SCHEMA
# ======================================================================

VISUAL_PAYLOAD_JSON_SCHEMA = """
==================================================
visualPayload JSON SCHEMA
==================================================

Add key "visualPayload" with this structure.

All arrays are optional in the sense that they may be empty.
Use [] when a category is not needed.

{
  "graphs": [
    {
      "function": "y=x^2+5",
      "x_range": [-6, 6],
      "label": "Parabola"
    }
  ],

  "bar_charts": [
    {
      "title": "Rainfall by Season (mm)",
      "data": [
        { "label": "Winter", "value": 20 },
        { "label": "Summer", "value": 150 }
      ]
    }
  ],

  "pie_charts": [
    {
      "title": "Atmosphere Composition",
      "data": [
        { "label": "Nitrogen", "value": 78 },
        { "label": "Oxygen", "value": 21 }
      ]
    }
  ],

  "text_diagrams": [
    {
      "title": "Photosynthesis",
      "content": "Sunlight\\n↓\\nLeaf\\n↓\\nGlucose"
    }
  ],

  "timelines": [
    {
      "period": "1857",
      "label": "Revolt"
    }
  ],

  "hierarchy_trees": [
    {
      "label": "Animal Kingdom",
      "children": [
        {
          "label": "Mammals",
          "children": []
        }
      ]
    }
  ],

  "process_flows": [
    {
      "title": "Process",
      "content": "Input\\n↓\\nProcessing\\n↓\\nOutput"
    }
  ],

  "highlight_boxes": [
    {
      "kind": "important",
      "content": "Key formula"
    }
  ],

  "memory_tricks": [
    "..."
  ],

  "exam_tips": [
    "..."
  ],

  "examples": [
    "..."
  ],

  "cheat_sheet": "compact markdown cheat sheet"
}

Text diagrams:
- arrows
- spacing
- unicode
- optional emoji
- no SVG
- no images
- no image URLs

Graphs:
- metadata only
- Flutter renders the graph

Bar/pie charts:
- use for real comparison or composition data
- values must come from the topic
- never invent statistics
"""


# ======================================================================
# DYNAMIC AI WHITEBOARD SCHEMA
# ======================================================================

WHITEBOARD_JSON_SCHEMA = """
==================================================
DYNAMIC AI WHITEBOARD SCHEMA
==================================================

Use "whiteboard" when a real diagram would improve understanding.

The whiteboard is a structured scene rendered by the Flutter client.

DO NOT return an image.
DO NOT return SVG.
DO NOT return Mermaid.
DO NOT return base64.
DO NOT return HTML.
DO NOT return drawing code.

Return ONLY structured JSON data.

Schema:

{
  "whiteboard": {
    "title": "Newton's Second Law",
    "width": 1000,
    "height": 700,
    "background": "#FFFFFF",
    "elements": [
      {
        "type": "title",
        "x": 60,
        "y": 40,
        "text": "Newton's Second Law",
        "font_size": 32
      },
      {
        "type": "formula",
        "x": 100,
        "y": 120,
        "text": "F = ma",
        "font_size": 34
      },
      {
        "type": "circle",
        "x": 350,
        "y": 320,
        "radius": 65,
        "label": "Mass m"
      },
      {
        "type": "arrow",
        "x1": 415,
        "y1": 320,
        "x2": 570,
        "y2": 320,
        "label": "F"
      }
    ]
  }
}

==================================================
SUPPORTED WHITEBOARD ELEMENT TYPES
==================================================

1. title

{
  "type": "title",
  "x": 60,
  "y": 40,
  "text": "Topic title",
  "font_size": 32
}

Use for the main heading.

--------------------------------------------------

2. text

{
  "type": "text",
  "x": 80,
  "y": 100,
  "text": "Explanation",
  "font_size": 20
}

Use for short explanations.

--------------------------------------------------

3. label

{
  "type": "label",
  "x": 200,
  "y": 250,
  "text": "Velocity v"
}

Use for labels next to objects, arrows, points, curves,
organs, components, etc.

--------------------------------------------------

4. formula

{
  "type": "formula",
  "x": 120,
  "y": 150,
  "text": "F = ma",
  "font_size": 30
}

Use for important equations.

Prefer simple readable mathematical notation.

--------------------------------------------------

5. equation

{
  "type": "equation",
  "x": 120,
  "y": 150,
  "text": "v = u + at",
  "font_size": 28
}

Use when presenting a derived or related equation.

--------------------------------------------------

6. rectangle

{
  "type": "rectangle",
  "x": 120,
  "y": 200,
  "width": 220,
  "height": 100,
  "label": "Input"
}

Use for containers, organs, components, algorithm steps,
architecture components, process steps, etc.

--------------------------------------------------

7. rounded_box

{
  "type": "rounded_box",
  "x": 120,
  "y": 200,
  "width": 220,
  "height": 100,
  "label": "Decision"
}

Use for softer process/flow boxes.

--------------------------------------------------

8. circle

{
  "type": "circle",
  "x": 350,
  "y": 320,
  "radius": 60,
  "label": "Mass"
}

Use for particles, cells, atoms, nodes, objects, points,
masses, organs/components where circular representation is useful.

--------------------------------------------------

9. line

{
  "type": "line",
  "x1": 100,
  "y1": 300,
  "x2": 700,
  "y2": 300,
  "line_width": 3
}

Use for axes, boundaries, connectors, surfaces, baselines,
or simple geometric relationships.

--------------------------------------------------

10. arrow

{
  "type": "arrow",
  "x1": 350,
  "y1": 300,
  "x2": 520,
  "y2": 300,
  "label": "Force F"
}

Use for direction, force, flow, motion, causality,
reaction direction, process direction, pointer relationships.

Arrows should have meaningful labels when useful.

--------------------------------------------------

11. vector

{
  "type": "vector",
  "x1": 350,
  "y1": 300,
  "x2": 500,
  "y2": 220,
  "label": "v"
}

Use for physics vectors and directional quantities.

--------------------------------------------------

12. divider

{
  "type": "divider",
  "x1": 60,
  "y1": 420,
  "x2": 940,
  "y2": 420
}

Use sparingly to separate sections.

==================================================
WHITEBOARD POSITION RULES
==================================================

Canvas:
- width = normally 1000
- height = normally 700

Coordinate origin:
- top-left is (0,0)

General layout:
- Title around y = 40–70.
- Main diagram usually between y = 150 and y = 550.
- Supporting explanation near bottom.
- Keep important objects away from edges.
- Keep at least ~40 px margin where practical.

Clarity:
- Do not overlap unrelated objects.
- Do not place labels directly over important shapes.
- Keep arrows visible.
- Avoid crossing arrows when another layout can work.
- Use whitespace.
- Prefer fewer clear elements over many tiny elements.

==================================================
WHITEBOARD EDUCATIONAL RULE
==================================================

Every element must serve an educational purpose.

A good whiteboard normally contains:
- a title
- one central concept / object
- labels
- relationships
- arrows / vectors when relevant
- formula when relevant
- short annotations

Do NOT create random:
- circles
- boxes
- arrows
- lines
- decorations

Do NOT make the board visually busy.

==================================================
WHITEBOARD SUBJECT PATTERNS
==================================================

Physics — Free Body Diagram:

Recommended structure:
- circle or rectangle for object
- downward arrow labelled mg
- upward arrow labelled N
- horizontal arrow labelled friction/applied force
- optional formula F = ma

Physics — Projectile Motion:

Recommended structure:
- horizontal baseline
- projectile trajectory represented by several meaningful points/segments
- launch object
- velocity arrow
- gravity arrow downward
- labels for angle, height, range when relevant

Physics — Gravity:

Recommended structure:
- large body / planet
- smaller object
- arrows pointing toward attracting body
- distance label
- relevant formula

Physics — Ray Diagram:

Recommended structure:
- principal axis
- lens/mirror line
- object
- incident ray
- reflected/refracted ray
- image
- focal-point labels when relevant

Physics — Circuit:

Recommended structure:
- battery/power source represented by a simple labelled box
- resistor/components represented by boxes or symbols
- connecting lines
- current arrows
- labels

Math — Function Graph:

Use "graphs" whenever ordinary function plotting is enough.

Use whiteboard when the educational explanation benefits from:
- labelled axes
- roots
- vertex
- intercepts
- slope
- tangent
- geometric relationship

Math — Geometry:

Recommended:
- lines
- circles
- triangle-like structure using lines
- angle labels
- side labels
- formula
- theorem relationship

Biology — Cell:

Recommended:
- central large circular/rounded structure
- smaller labelled structures
- arrows from labels toward parts
- title

Biology — Process:

Recommended:
- boxes or labels for stages
- arrows connecting stages
- concise descriptions

Biology — Cycle:

Recommended:
- stages arranged spatially around a cycle
- arrows between stages
- avoid too many elements

Chemistry — Reaction:

Recommended:
- reactant box/label
- arrow
- product box/label
- conditions above arrow when relevant
- equation/formula

Chemistry — Atom:

Recommended:
- central nucleus representation
- electrons/energy shells where useful
- labels
- avoid overloading the board

Computer Science — Flowchart:

Recommended:
- Start
- process boxes
- decision boxes if needed
- arrows
- End

Computer Science — Architecture:

Recommended:
- Client box
- API/server box
- database box
- arrows showing communication flow

History — Cause/Effect:

Recommended:
- event box
- arrows
- causes
- outcome/effect
- dates where relevant

==================================================
WHEN TO USE WHITEBOARD VS OTHER VISUAL TYPES
==================================================

Use "graphs" when the main teaching point is a mathematical curve.

Use "bar_charts" when comparing category values.

Use "pie_charts" for composition/percentage data.

Use "timelines" for chronological events.

Use "hierarchy_trees" for parent-child classification.

Use "process_flows" for simple linear process sequences.

Use "text_diagrams" only when a simple text diagram is clearer.

Use "whiteboard" when spatial arrangement, labels, shapes, arrows,
vectors, formulas, or relationships materially improve understanding.

A response MAY contain both:
- whiteboard + graph
- whiteboard + examples
- whiteboard + timeline

But do not duplicate the same information unnecessarily.

==================================================
WHITEBOARD DATA ACCURACY
==================================================

Use only information supported by the question, transcript,
retrieved context, or answer.

Never invent:
- statistics
- measurements
- formulas
- scientific values
- historical dates
- labels not supported by the topic

Coordinates are layout metadata and may be chosen freely.

==================================================
WHITEBOARD FALLBACK
==================================================

When the exact visual structure is uncertain:
- prefer a simpler diagram
- use fewer elements
- use clear labels
- avoid speculative details

A simple correct diagram is better than a complicated incorrect diagram.
"""


# ======================================================================
# COMBINED VISUAL RULES
# ======================================================================

NOTES_OUTPUT_ORDER = """
==================================================
OUTPUT ORDER (in cleanNotes markdown + visualPayload)
==================================================
1. Summary section (also fill shortSummary)
2. Key Points (also fill keyPoints array)
3. Detailed Explanation in cleanNotes
4. Equations in cleanNotes using LaTeX if applicable
5. Optional visualPayload blocks
6. Dynamic whiteboard when it significantly improves understanding
7. Memory tricks, exam tips, examples in visualPayload arrays
8. cheat_sheet in visualPayload when useful for revision

Never add a visual merely to fill this order.
Skip any section that has no educational value.
"""


# ======================================================================
# NOTES SYSTEM EXTENSION
# ======================================================================

NOTES_SYSTEM_EXTENSION = (
    NOTES_LANGUAGE_RULE
    + SMART_SUBJECT_UNDERSTANDING
    + LATEX_AND_TABLES_RULE
    + VISUAL_PAYLOAD_JSON_SCHEMA
    + WHITEBOARD_JSON_SCHEMA
    + NOTES_OUTPUT_ORDER
)


# ======================================================================
# SHORT NOTES
# ======================================================================

SHORT_NOTES_SYSTEM_EXTENSION = (
    NOTES_LANGUAGE_RULE
    + LATEX_AND_TABLES_RULE
    + """
==================================================
SHORT LECTURE MODE
==================================================
This transcript is short. Keep notes compact and exam-useful.

- cleanNotes: brief Summary + Key Points + short Detailed Explanation
- keyPoints: 3–8 bullets
- shortSummary: 1–2 sentences
- importantTerms: only terms that actually appear (0–6)
- visualPayload: omit or use empty arrays unless one formula/diagram
  is genuinely essential
- Whiteboard is allowed only when one compact diagram significantly
  improves understanding
- Do NOT invent long cheat sheets
- Do NOT generate decorative visuals
"""
)


# ======================================================================
# MEDIUM NOTES
# ======================================================================

MEDIUM_NOTES_SYSTEM_EXTENSION = (
    NOTES_LANGUAGE_RULE
    + LATEX_AND_TABLES_RULE
    + """
==================================================
MEDIUM LECTURE MODE
==================================================
Balanced exam notes — clear, not encyclopedic.

- cleanNotes: Summary, Key Points, solid Detailed Explanation
- Skip filler digressions.
- Prefer 1–2 high-value visuals when they teach better than text.
- Prefer a dynamic whiteboard for labelled structures, spatial
  relationships, formulas, forces, processes, or flows.
- Keep cheat_sheet short or omit if not needed.
- Same JSON keys as always.
- Do not invent topics absent from the transcript.
"""
    + VISUAL_PAYLOAD_JSON_SCHEMA
    + WHITEBOARD_JSON_SCHEMA
)


# ~750 spoken chars/min (rough).
# Used only to pick prompt weight — not billing.
NOTES_CHARS_SHORT = 1800
NOTES_CHARS_MEDIUM = 15000


def notes_band_for_transcript(
    transcript_text: str,
    *,
    duration_minutes: int | None = None,
) -> str:
    """Return 'short' | 'medium' | 'long'.

    Prefer duration when provided (ffprobe / client);
    otherwise use transcript length.
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

    n = len(
        (transcript_text or "").strip()
    )

    if n < NOTES_CHARS_SHORT:
        return "short"

    if n < NOTES_CHARS_MEDIUM:
        return "medium"

    return "long"


# ======================================================================
# REVISION
# ======================================================================

REVISION_VISUAL_EXTENSION = (
    SMART_SUBJECT_UNDERSTANDING
    + LATEX_AND_TABLES_RULE
    + VISUAL_PAYLOAD_JSON_SCHEMA
    + WHITEBOARD_JSON_SCHEMA
    + """
==================================================
REVISION VISUAL RULE
==================================================
Add optional "visualPayload" to the same JSON response.

Keep revisionSheet as the main markdown revision content.

Use:
- whiteboard for compact concept diagrams
- graphs for mathematical relationships
- timelines for chronology
- hierarchy trees for classification
- process flows for sequences

Apply the same subject-understanding rule:
visuals only when they significantly help.
"""
)


# ======================================================================
# ASK AI VISUAL AUTO TRIGGERS
# ======================================================================

VISUAL_AUTO_TRIGGER_RULES = """
==================================================
VISUAL AUTO-TRIGGER RULES (Home AI / Study AI)
==================================================

Before finishing the answer, run this self-check:

1. Is there a concept in the answer that is meaningfully easier to
   understand visually?
2. Is there a specific visual structure that can teach it?
3. Can the visual be created from the actual question and answer?
4. Is it accurate and uncluttered?

If yes → generate <<VISUAL_JSON>>.

If no → do not generate a visual.

==================================================
RULE 1 — SMART AUTO-TRIGGER
==================================================

Automatically generate a visual when the educational answer contains:

- Process
- Cycle
- Mechanism
- Reaction
- Classification
- Comparison
- Timeline
- Cause & Effect
- Structure
- Spatial relationship
- Formula relationship
- Graphable mathematical relationship
- Force/vector relationship
- Motion/trajectory
- Scientific system
- Algorithm
- Architecture

The student does NOT need to explicitly ask for a diagram.

==================================================
RULE 2 — SUBJECT-AWARE VISUAL TYPE
==================================================

Choose the most specific appropriate visual.

Biology:
- process_flow
- cycle
- labelled_structure
- system_diagram
- comparison
- classification

Chemistry:
- reaction_flow
- molecular_structure
- atom_structure
- bonding
- apparatus
- comparison

Physics:
- free_body_diagram
- gravity_diagram
- projectile_motion
- ray_diagram
- circuit
- wave
- formula_relationship
- graph

Math:
- function_graph
- coordinate_graph
- number_line
- triangle
- circle
- probability_tree
- statistics_chart
- formula_relationship

History / Social Science:
- timeline
- cause_effect
- event_sequence
- comparison

Computer Science:
- flowchart
- algorithm
- state_machine
- binary_tree
- linked_list
- architecture

==================================================
RULE 3 — DYNAMIC WHITEBOARD PREFERENCE
==================================================

Prefer "whiteboard" over "text_diagrams" when the visual needs:

- spatial positioning
- multiple labels
- arrows
- vectors
- shapes
- formula placement
- connected components
- object relationships
- process boxes
- system architecture
- geometry
- scientific structures

Examples:

Gravity:
→ whiteboard

Projectile:
→ whiteboard + optional graph

Free-body diagram:
→ whiteboard

Lens/ray diagram:
→ whiteboard

Circuit:
→ whiteboard

Cell:
→ whiteboard

DNA structure:
→ whiteboard

Demand/supply:
→ graph or whiteboard

Simple three-step process:
→ process_flows may be enough

Simple chronology:
→ timeline may be enough

==================================================
RULE 4 — SKIP
==================================================

DO NOT generate visuals for:

- Hi
- Hello
- Hey
- Thanks
- Thank you
- Simple greetings
- Simple one-line factual answers
- Trivial arithmetic
- Very short answers where visual adds zero learning value

==================================================
RULE 5 — REAL EDUCATIONAL CONTENT ONLY
==================================================

Every visual must be based on the actual question and answer.

Never generate:

- generic placeholder diagrams
- unrelated shapes
- invented facts
- invented values
- decorative visuals
- random arrows
- random boxes

Use the actual:
- formulas
- numbers
- labels
- relationships
- steps
- directions
- scientific concepts
- historical events

==================================================
RULE 6 — MOST SPECIFIC VISUAL
==================================================

Always choose the most specific useful visual.

Examples:

Gravity
→ whiteboard gravity diagram

Projectile motion
→ whiteboard projectile diagram

F = ma
→ free-body whiteboard

y = x²
→ graph

Triangle angle
→ geometry whiteboard

Photosynthesis
→ process flow or whiteboard

DNA
→ labelled whiteboard

Algorithm
→ flowchart whiteboard

Client → API → Database
→ architecture whiteboard

==================================================
RULE 7 — VALID JSON
==================================================

Output must conform to the schemas in:
- VISUAL_PAYLOAD_JSON_SCHEMA
- WHITEBOARD_JSON_SCHEMA

The root visual payload can contain:

{
  "graphs": [],
  "bar_charts": [],
  "pie_charts": [],
  "text_diagrams": [],
  "timelines": [],
  "hierarchy_trees": [],
  "process_flows": [],
  "highlight_boxes": [],
  "memory_tricks": [],
  "exam_tips": [],
  "examples": [],
  "whiteboard": {
    "title": "...",
    "width": 1000,
    "height": 700,
    "elements": []
  }
}

The whiteboard key may be omitted when not needed.

==================================================
RULE 8 — VISUAL TIMING & PLACEMENT
==================================================

First write the complete natural student-facing markdown answer.

Only AFTER the complete answer has finished, output on its own line:

<<VISUAL_JSON>>

Immediately after that marker output the single compact valid JSON object.

Do not put explanatory prose after the JSON.

==================================================
RULE 9 — VISUAL OUTPUT FORMAT
==================================================

Return structured VISUAL_JSON only.

Do NOT return:

- image-generation instructions
- image URLs
- base64 strings
- fake image markdown
- SVG
- Mermaid
- HTML
- canvas JavaScript
- Python plotting code

The client renderer produces the visual card.

==================================================
RULE 10 — WHITEBOARD QUALITY
==================================================

Whiteboards must be:

- clean
- educational
- readable
- accurate
- textbook-like
- uncluttered

Use:
- meaningful positions
- consistent spacing
- clear labels
- useful arrows
- useful formulas
- simple shapes

Avoid:
- overlapping labels
- excessively small text
- unnecessary shapes
- crossing arrows
- decorative elements

A correct simple diagram is better than a complex incorrect one.

==================================================
RULE 11 — FINAL SELF-CHECK
==================================================

Before emitting <<VISUAL_JSON>>, check:

- Does the visual teach something?
- Is it specific to the question?
- Are all facts correct?
- Are formulas correct?
- Are labels meaningful?
- Are coordinates reasonable?
- Are objects separated enough to read?
- Is there any unnecessary decoration?

When unsure, prefer a simpler accurate visual.

==================================================
RULE 12 — DEFAULT WHEN VISUAL IS CLEARLY USEFUL
==================================================

When a concept is clearly easier to understand with a diagram,
prefer including a visual rather than leaving the answer text-only.

However, never invent information merely to populate the visual.
"""


# ======================================================================
# ASK AI EXTENSION
# ======================================================================

ASK_AI_VISUAL_EXTENSION = (
    SMART_SUBJECT_UNDERSTANDING
    + MARKDOWN_STRUCTURE_RULE
    + VISUAL_PAYLOAD_JSON_SCHEMA
    + WHITEBOARD_JSON_SCHEMA
    + VISUAL_AUTO_TRIGGER_RULES
)


# ======================================================================
# STREAM DELIMITER
# ======================================================================

ASK_AI_STREAM_DELIMITER = "<<VISUAL_JSON>>"