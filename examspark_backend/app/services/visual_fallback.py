"""Visual safety net when the model skips <<VISUAL_JSON>>.

Only emits real educational diagrams — never a fake "Concept / Key relation" stub.
"""
from __future__ import annotations

import re

_VISUAL_WORDS = re.compile(
    r"\b(graph|diagram|parabola|timeline|flowchart|mind\s*map|"
    r"process\s*flow|draw|plot|visual|figure|sketch)\b",
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
    """True when a diagram clearly helps — keywords OR known school topics."""
    q = query or ""
    if _VISUAL_WORDS.search(q):
        return True
    # Topic auto-visual (no need to say "diagram")
    if _PHOTOSYNTHESIS.search(q) or _WATER_CYCLE.search(q):
        return True
    if re.search(
        r"\b(newton|cell\s*division|mitosis|meiosis|water\s*cycle|"
        r"digestive|respiration|food\s*chain|circuit|atom|"
        r"periodic\s*table|blood\s*flow|heart)\b",
        q,
        re.IGNORECASE,
    ):
        return True
    return False


def visual_reminder_user_line(query: str) -> str:
    """Append to Home/Ask user message so visual JSON is hard to skip."""
    if not wants_visual(query):
        return (
            "After the markdown answer, if a graph/diagram/timeline would clearly "
            "help understanding, append on its own line: <<VISUAL_JSON>> then one "
            "compact JSON object. Use explicit * in graph functions (5*x). "
            "Diagram content must be topic-specific — never placeholder labels "
            "like Concept / Key relation / Result / Direct Answer / Easy Explanation."
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
    """Build a real visual when topic is known. Never invent a generic stub.

    Runs for known topics even when the user did not type 'diagram'.
    """
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

    # Only parse arrows from answer when user/topic asked for visual
    if wants_visual(query):
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
    if not answer or "→" not in answer and "->" not in answer:
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
