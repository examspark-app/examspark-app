"""Visual safety net when the model skips <<VISUAL_JSON>>.

Only emits real educational diagrams — never a fake "Concept / Key relation" stub.
Founder Jul 26: Home/Ask — diagram only when student asks (not every answer).
"""
from __future__ import annotations

import re

_VISUAL_WORDS = re.compile(
    r"\b("
    # Direct visual requests (any subject)
    r"graph|diagram|parabola|timeline|flowchart|mind\s*map|"
    r"process\s*flow|draw|plot|visual|figure|sketch|chart|"
    r"show\s+(me\s+)?(a\s+)?(diagram|graph|figure|flowchart)|"
    r"make\s+(a\s+)?(diagram|graph|figure)|"
    r"diagram\s+(do|bana|banao)|"
    r"graph\s+(do|bana|banao)|"
    # Universal "shape" words — question patterns that benefit from a
    # visual regardless of subject (math/physics/chemistry/biology/
    # history/geography/economics/CS all ask questions shaped like this)
    r"process|cycle|mechanism|structure|steps?\s+of|stages?\s+of|"
    r"how\s+does|how\s+do|how\s+is|working\s+of|"
    r"types?\s+of|classification|hierarchy|"
    r"compare|comparison|difference\s+between|vs\.?|versus|"
    r"causes?\s+of|effects?\s+of|leads?\s+to|results?\s+in|"
    r"relationship\s+between|connection\s+between|"
    r"flow\s+of|sequence\s+of|order\s+of|"
    r"equation|formula|function|solve|"
    r"circuit|reaction|pathway|lifecycle|life\s+cycle"
    r")\b",
    re.IGNORECASE,
)

_POLY = re.compile(
    r"(?:y\s*=\s*)?"
    r"([+-]?\s*\d*)\s*x\s*\^\s*2"
    r"(?:\s*([+-])\s*(\d*)\s*x)?"
    r"(?:\s*([+-])\s*(\d+))?"
    r"(?:\s*=\s*0)?",
    re.IGNORECASE,
)

_PHOTOSYNTHESIS = re.compile(r"photosynth", re.IGNORECASE)
_WATER_CYCLE = re.compile(r"water\s*cycle", re.IGNORECASE)


def wants_visual(query: str) -> bool:
    """True only when the student asks for a visual — not topic auto-trigger."""
    q = query or ""
    return bool(_VISUAL_WORDS.search(q))


def visual_reminder_user_line(query: str) -> str:
    """Append to Home/Ask user message so visual JSON is hard to skip when needed."""
    if not wants_visual(query):
        return (
            "DIAGRAM RULE: Do NOT add <<VISUAL_JSON>> or any diagram/graph for this "
            "question. Text answer only — unless the student explicitly asked for a "
            "diagram/graph/figure."
        )
    return (
        "VISUAL REQUIRED for this question. After the markdown answer, on its own "
        "line output exactly <<VISUAL_JSON>> then a compact JSON object with "
        "REAL topic-specific content (not placeholders). "
        "Biology process → text_diagrams or process_flows with labelled steps "
        "(e.g. Sunlight → Chloroplast → Glucose + O2). "
        "NEVER use answer section titles (Direct Answer, Easy Explanation, Key Points, Source) "
        "as diagram boxes. "
        "Math parabola → graphs with y=x^2-5*x+6 style functions. "
        "Use explicit multiplication (5*x). Do not omit the visual block."
    )


def fallback_visual_payload(query: str, answer: str = "") -> dict | None:
    """Build a real visual ONLY when the student asked for one.

    Never invent a generic stub. Never auto-attach from topic alone.
    """
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
                        "☀️ Sunlight + CO₂ + H₂O\n"
                        "        ↓\n"
                        "🌿 Chloroplast (leaf)\n"
                        "   • Light reactions\n"
                        "   • Calvin cycle\n"
                        "        ↓\n"
                        "🍬 Glucose (C₆H₁₂O₆) + O₂"
                    ),
                }
            ],
            "process_flows": [
                {
                    "title": "Inputs → Outputs",
                    "content": (
                        "Inputs: CO₂ + H₂O + light\n"
                        "↓\n"
                        "Chloroplast reactions\n"
                        "↓\n"
                        "Outputs: glucose + O₂"
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
                        "🌊 Ocean / lake\n"
                        "   ↓ evaporation\n"
                        "☁️ Clouds\n"
                        "   ↓ condensation\n"
                        "🌧 Rain / precipitation\n"
                        "   ↓ collection\n"
                        "🌊 Back to water bodies"
                    ),
                }
            ],
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
