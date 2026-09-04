"""Visual safety net when the model skips <<VISUAL_JSON>>.

Only emits real educational diagrams — never a fake "Concept / Key relation" stub.
Founder Jul 26: Home/Ask — diagram only when student asks (not every answer).
"""
from __future__ import annotations

import re

_SKIP_WORDS = re.compile(
    r"^(hi+|hello+|hey+|greetings|thanks+|thank\s*you|ok|okay|bye|good\s*(morning|evening|night|afternoon))[!.]*$",
    re.IGNORECASE,
)

_VISUAL_AUTO_TRIGGER_WORDS = re.compile(
    r"\b("
    # Direct visual requests (any subject)
    r"graph|diagram|parabola|timeline|flowchart|mind\s*map|"
    r"process\s*flow|draw|plot|visual|figure|sketch|chart|"
    r"show\s+(me\s+)?(a\s+)?(diagram|graph|figure|flowchart)|"
    r"make\s+(a\s+)?(diagram|graph|figure)|"
    r"diagram\s+(do|bana|banao)|graph\s+(do|bana|banao)|"
    # Rule 1 triggers: Process, Cycle, Mechanism, Reaction, Classification, Comparison,
    # Timeline, Cause & Effect, Structure, Spatial, Formula, Force, Trajectory, System
    r"process|cycle|mechanism|structure|steps?\s+of|stages?\s+of|"
    r"how\s+does|how\s+do|how\s+is|working\s+of|"
    r"types?\s+of|classification|hierarchy|"
    r"compare|comparison|difference\s+between|vs\.?|versus|"
    r"causes?\s+of|effects?\s+of|leads?\s+to|results?\s+in|"
    r"relationship\s+between|connection\s+between|"
    r"flow\s+of|sequence\s+of|order\s+of|"
    r"equation|formula|function|solve|"
    r"circuit|reaction|pathway|lifecycle|life\s+cycle|"
    # Biology concepts
    r"photosynth|respiration|mitosis|meiosis|mendel|genetics|dna|rna|"
    r"cell\s+division|nephron|heart|circulation|digest|nervous|neuron|"
    # Chemistry concepts
    r"bonding|molecular|orbitals?|acid|base|titration|synthesis|haber|"
    r"periodic|electron|covalent|ionic|"
    # Physics concepts
    r"newton|f\s*=\s*m\s*\*?\s*a|force|gravity|projectile|trajectory|"
    r"ohm|circuit|resistor|voltage|current|kirchhoff|ray|lens|mirror|"
    r"reflection|refraction|wave|frequency|optics|free\s*body|fbd|"
    # Math concepts
    r"quadratic|parabola|coordinate|number\s*line|triangle|circle|"
    r"pythagoras|geometry|tangent|sine|cosine|trig|probability|"
    # History & CS concepts
    r"revolt|revolution|war|timeline|dynasty|treaty|"
    r"algorithm|binary\s*tree|linked\s*list|data\s*structure|state\s*machine"
    r")\b",
    re.IGNORECASE,
)

_NEWTON_SECOND_LAW = re.compile(r"newton.*second|f\s*=\s*m\s*\*?\s*a|f\s*=\s*ma", re.IGNORECASE)
_OHMS_LAW = re.compile(r"ohm.*law|v\s*=\s*i\s*\*?\s*r|v\s*=\s*ir", re.IGNORECASE)
_PROJECTILE_MOTION = re.compile(r"projectile\s*motion|trajectory", re.IGNORECASE)
_MITOSIS = re.compile(r"mitosis|cell\s*division", re.IGNORECASE)
_GRAVITY = re.compile(r"gravitation|gravity\s*law|free\s*fall", re.IGNORECASE)
_PHOTOSYNTHESIS = re.compile(r"photosynth", re.IGNORECASE)
_WATER_CYCLE = re.compile(r"water\s*cycle|evaporation|precipitation", re.IGNORECASE)
_POLY = re.compile(
    r"([+-]?\d*)x\^2"
    r"(?:([+-])(\d*)x)?"
    r"(?:([+-])(\d+))?",
    re.IGNORECASE,
)


def wants_visual(query: str) -> bool:
    """Rule 1 & Rule 3: Auto-trigger when concept benefits visually; skip greetings/trivial."""
    q = (query or "").strip()
    if not q or len(q) <= 12 and _SKIP_WORDS.search(q):
        return False
    # Trivial 1-line check (e.g. "2+2", "hi")
    if re.match(r"^\d+\s*[\+\-\*\/]\s*\d+\s*=?$", q):
        return False
    return bool(_VISUAL_AUTO_TRIGGER_WORDS.search(q)) or len(q) > 40


def visual_reminder_user_line(query: str) -> str:
    """Append to Home/Ask user message following the 10 VISUAL AUTO-TRIGGER RULES."""
    if not wants_visual(query):
        return (
            "RULE 3 SKIP: Simple greeting or trivial query. Do NOT add <<VISUAL_JSON>>. "
            "Text answer only."
        )
    return (
        "VISUAL REQUIRED (RULE 1 & 2): This educational topic benefits from a visual. "
        "After the full markdown answer, on its own line output exactly <<VISUAL_JSON>> "
        "then a compact, valid JSON object matching the 10 VISUAL AUTO-TRIGGER RULES. "
        "Choose the most specific visual for the subject: "
        "Biology (process_flow, cycle, labelled_structure), "
        "Chemistry (reaction_flow, molecular_structure, comparison), "
        "Physics (free_body_diagram, gravity_diagram, projectile_motion, circuit, ray_diagram), "
        "Math (function_graph, coordinate_graph, triangle, number_line), "
        "History (timeline), CS (flowchart, binary_tree). "
        "Use actual formulas, numbers, labels, relationships, and arrows (e.g. A → B → C) — "
        "NEVER output generic section titles or placeholder stubs."
    )


def fallback_visual_payload(query: str, answer: str = "") -> dict | None:
    """Build a real visual following Rule 1 & Rule 4 (real educational content only)."""
    if not wants_visual(query):
        return None

    text = f"{query}\n{answer}"
    fn = _extract_quadratic_function(text)
    if fn is not None:
        return {
            "graphs": [
                {
                    "function": fn,
                    "x_range": [-2.0, 7.0],
                    "label": f"Graph of {fn}",
                }
            ]
        }

    topic = _topic_process_diagram(query, answer)
    if topic is not None:
        return topic

    from_answer = _diagram_from_answer_arrows(answer)
    if from_answer is not None:
        return from_answer

    return None


def _topic_process_diagram(query: str, answer: str) -> dict | None:
    blob = f"{query}\n{answer}"
    if _PHOTOSYNTHESIS.search(blob):
        return {
            "text_diagrams": [
                {
                    "title": "Photosynthesis process",
                    "content": (
                        "☀️ Sunlight + 6CO₂ + 6H₂O\n"
                        "        ↓\n"
                        "🌿 Chloroplast (Thylakoids & Stroma)\n"
                        "   • Light Reactions (Photolysis: H₂O → O₂ + ATP/NADPH)\n"
                        "   • Calvin Cycle (Dark Reactions: CO₂ Fixation)\n"
                        "        ↓\n"
                        "🍬 Glucose (C₆H₁₂O₆) + 6O₂"
                    ),
                }
            ],
            "process_flows": [
                {
                    "title": "Inputs → Outputs",
                    "content": (
                        "Inputs: CO₂ + H₂O + light energy\n"
                        "↓\n"
                        "Chloroplast chemical conversion\n"
                        "↓\n"
                        "Outputs: Glucose + O₂ released"
                    ),
                }
            ],
        }
    if _WATER_CYCLE.search(blob):
        return {
            "text_diagrams": [
                {
                    "title": "Water cycle",
                    "content": (
                        "🌊 Ocean / Lake (Surface Water)\n"
                        "   ↓ Evaporation & Transpiration (Plants)\n"
                        "☁️ Clouds (Condensation: Water vapor → Droplets)\n"
                        "   ↓ Precipitation (Rain / Snow / Hail)\n"
                        "⛰️ Surface Runoff & Infiltration (Groundwater)\n"
                        "🌊 Back to oceans / water bodies"
                    ),
                }
            ],
        }
    if _NEWTON_SECOND_LAW.search(blob):
        return {
            "text_diagrams": [
                {
                    "title": "Newton's Second Law (Free Body Diagram)",
                    "content": (
                        "           ↑ Normal Force (N)\n"
                        "           │\n"
                        "F_applied  │      [ Mass: m ]  ───→ Acceleration (a = F_net / m)\n"
                        "──────────►[=========]────────►\n"
                        "           │\n"
                        "           ↓ Gravity (W = m · g)\n\n"
                        "Core Equation: F_net = m · a\n"
                        "• F = Net Force (Newtons, N)\n"
                        "• m = Mass (kg)\n"
                        "• a = Acceleration (m/s²)"
                    ),
                }
            ]
        }
    if _OHMS_LAW.search(blob):
        return {
            "text_diagrams": [
                {
                    "title": "Ohm's Law & Circuit Relationship",
                    "content": (
                        "   ┌──[ + ]── Battery (V) ──[ - ]──┐\n"
                        "   │                               │\n"
                        "   │ → Current I (Amperes)         │\n"
                        "   │                               │\n"
                        "   └───▲▲▲▲── Resistor R (Ohms) ───┘\n\n"
                        "Formula Triangle:\n"
                        "       [  V  ]       V = I × R\n"
                        "       ───────       I = V / R\n"
                        "       [ I | R ]     R = V / I"
                    ),
                }
            ]
        }
    if _PROJECTILE_MOTION.search(blob):
        return {
            "text_diagrams": [
                {
                    "title": "Projectile Motion Trajectory",
                    "content": (
                        "  Height (y)\n"
                        "     ↑          Peak: v_y = 0\n"
                        "     │            ╭───●───╮\n"
                        "     │          ╭─         ─╮\n"
                        "     │    v₀  ╭─             ─╮\n"
                        "     │   ↗  ╭─                 ─╮\n"
                        "     │  ● ╭─                     ─● Landing\n"
                        "     └──┴───────────────────────────┴──→ Range (x)\n"
                        "        ←────── Range R = v₀²·sin(2θ)/g ──────→"
                    ),
                }
            ]
        }
    if _MITOSIS.search(blob):
        return {
            "text_diagrams": [
                {
                    "title": "Stages of Mitosis",
                    "content": (
                        "1. Prophase: Chromatin condenses, spindle forms\n"
                        "        ↓\n"
                        "2. Metaphase: Chromosomes align at equatorial plate\n"
                        "        ↓\n"
                        "3. Anaphase: Sister chromatids pulled to opposite poles\n"
                        "        ↓\n"
                        "4. Telophase: Nuclear membranes re-form\n"
                        "        ↓\n"
                        "Cytokinesis: Cytoplasm splits → 2 identical diploid cells"
                    ),
                }
            ]
        }
    if _GRAVITY.search(blob):
        return {
            "text_diagrams": [
                {
                    "title": "Universal Gravitation",
                    "content": (
                        "  Body 1 (m₁)               Body 2 (m₂)\n"
                        "     ( ● ) ─────── F ◄──► F ─────── ( ● )\n"
                        "       └─── Distance (r) ───┘\n\n"
                        "Law of Gravitation:\n"
                        "   F = G · (m₁ · m₂) / r²\n"
                        "• G = 6.674 × 10⁻¹¹ N·m²/kg²\n"
                        "• Force is inversely proportional to r²"
                    ),
                }
            ]
        }
    return None


def _diagram_from_answer_arrows(answer: str) -> dict | None:
    """If the model already wrote A → B → C in the answer, surface it as a diagram."""
    if not answer or ("→" not in answer and "->" not in answer):
        return None
    lines = []
    for raw in answer.splitlines():
        line = raw.strip().lstrip("•*- ").strip()
        if "→" in line or "->" in line:
            lines.append(line.replace("->", "→"))
        if len(lines) >= 6:
            break
    if len(lines) < 2:
        return None
    return {
        "text_diagrams": [
            {
                "title": "Process flow",
                "content": "\n↓\n".join(lines),
            }
        ]
    }


def _extract_quadratic_function(text: str) -> str | None:
    compact = text.replace(" ", "")
    match = _POLY.search(compact) or _POLY.search(text)
    if not match:
        return None

    a_raw, b_sign, b_raw, c_sign, c_raw = match.groups()
    a = _coeff(a_raw, default=1)
    b = 0
    c = 0
    if b_sign is not None:
        b = _coeff(b_raw, default=1)
        if b_sign == "-":
            b = -abs(b)
        else:
            b = abs(b)
    if c_sign is not None and c_raw is not None:
        c = int(c_raw)
        if c_sign == "-":
            c = -c

    if a == 1:
        expr = "x^2"
    elif a == -1:
        expr = "-x^2"
    else:
        expr = f"{a}*x^2"

    if b > 0:
        expr += f"+{b}*x"
    elif b < 0:
        expr += f"{b}*x"

    if c > 0:
        expr += f"+{c}"
    elif c < 0:
        expr += str(c)

    return f"y={expr}"


def _coeff(raw: str | None, *, default: int) -> int:
    if raw is None:
        return default
    s = raw.replace(" ", "").replace("+", "")
    if s in ("", "+"):
        return default
    if s == "-":
        return -default
    try:
        return int(s)
    except ValueError:
        return default


async def generate_retry_visual(
    query: str,
    answer: str,
    language: str | None = None,
) -> dict | None:
    """Generate or retrieve a visual payload specifically for a retry without regenerating text (Rule 8)."""
    fb = fallback_visual_payload(query, answer)
    if fb is not None:
        return fb

    try:
        from app.config import AIConfig
        from app.services.openai_chat_service import call_openai_chat
        from app.services.visual_stream_parser import split_answer_and_visual
        from app.constants.visual_notes_prompt import VISUAL_AUTO_TRIGGER_RULES

        if AIConfig.openai_configured():
            prompt = (
                f"Student Question: {query}\n\n"
                f"Educational Answer:\n{answer}\n\n"
                "According to the 10 VISUAL AUTO-TRIGGER RULES, generate ONLY the <<VISUAL_JSON>> "
                "followed by the compact valid JSON object for this educational concept. "
                "Do not repeat the explanation text or add markdown fences."
            )
            raw = await call_openai_chat(
                [
                    {"role": "system", "content": VISUAL_AUTO_TRIGGER_RULES},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.2,
                max_tokens=800,
            )
            _, visual = split_answer_and_visual(raw)
            if visual is not None:
                return visual
    except Exception as exc:
        logging.getLogger(__name__).warning("generate_retry_visual LLM call failed: %s", exc)

    return fb
