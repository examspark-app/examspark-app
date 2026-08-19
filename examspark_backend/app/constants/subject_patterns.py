"""Subject-wise teaching pattern detection for Ask AI + Home AI.

Detects subject from student query and returns a compact teaching-style
instruction injected into the user message (NOT the system prompt).

Pattern: detect_subject(query) -> subject key
         subject_teaching_hint(query) -> one-liner for LLM injection
"""
from __future__ import annotations

import re

# -- Regex patterns (order matters: specific first) --------------------------

_MATH = re.compile(
    r"(?i)\b("
    r"calculat|solve|equation|formula|integrat|differentiat|derivativ|"
    r"matrix|determinant|polynomial|quadratic|trigonometr|sin|cos|tan|"
    r"log|logarithm|arithmetic|geometric|progressi|permutation|combination|"
    r"probabilit|statistic|mean|median|mode|variance|proof|theorem|"
    r"algebra|geometry|coordinate|vector|scalar|limit|calculus|"
    r"x\s*=|find\s+the\s+value|lhs|rhs|lcm|hcf|factor"
    r")\b"
)

_PHYSICS = re.compile(
    r"(?i)\b("
    r"force|velocity|acceleration|momentum|energy|power|work|"
    r"current|voltage|resistance|ohm|capacitor|inductor|circuit|"
    r"wave|frequency|wavelength|amplitude|refraction|reflection|"
    r"gravity|gravitational|newton|thermodynamic|pressure|temperature|"
    r"motion|projectile|torque|friction|magnetic|electric\s+field|"
    r"optic|lens|mirror|photon|quantum|nuclear|radioactiv|"
    r"physics|numerica"
    r")\b"
)

_CHEMISTRY = re.compile(
    r"(?i)\b("
    r"reaction|compound|element|molecule|atom|bond|ionic|covalent|"
    r"oxidation|reduction|redox|acid|base|ph|buffer|solution|solubility|"
    r"mole|molarity|molality|titration|electrolysis|catalyst|"
    r"periodic\s+table|valency|electron|orbital|hybridization|"
    r"polymer|hydrocarbon|alkane|alkene|benzene|isomer|"
    r"chemistry|organic|inorganic|physical\s+chemistry|"
    r"enthalpy|entropy|equilibrium\s+constant|kp|kc"
    r")\b"
)

_BIOLOGY = re.compile(
    r"(?i)\b("
    r"cell|dna|rna|gene|chromosome|mitosis|meiosis|"
    r"photosynthesis|respiration|enzyme|protein|carbohydrate|lipid|"
    r"organ|tissue|blood|heart|lung|kidney|liver|brain|nerve|"
    r"evolution|adaptation|ecology|ecosystem|food\s+chain|"
    r"neet|botany|zoology|biology|microorganism|bacteria|virus|fungi|"
    r"hormone|immunity|antibiotic|vaccine|nutrition|digestion|"
    r"taxonomy|classification|kingdom|phylum|class|order|family|genus|species"
    r")\b"
)

_POLITICAL_SCIENCE = re.compile(
    r"(?i)\b("
    r"constitution|article|amendment|parliament|lok\s*sabha|rajya\s*sabha|"
    r"president|prime\s*minister|governor|chief\s*minister|"
    r"fundamental\s*right|directive\s*principle|federalism|judiciary|"
    r"supreme\s*court|high\s*court|election|voting|suffrage|"
    r"political\s*party|democracy|republic|sovereignty|"
    r"preamble|schedule|bill|act|ordinance|cabinet|council\s*of\s*ministers|"
    r"political\s*science|civics|polity|governance"
    r")\b"
)

_HISTORY = re.compile(
    r"(?i)\b("
    r"war|battle|revolution|dynasty|empire|kingdom|treaty|"
    r"century|decade|colonial|independence|partition|"
    r"mughal|british|french|american|russian|chinese|"
    r"gandhi|nehru|ambedkar|bose|tilak|"
    r"ancient|medieval|modern|history|historical|"
    r"civilizat|harappan|vedic|gupta|maurya|"
    r"world\s*war|cold\s*war|french\s*revolution|industrial\s*revolution"
    r")\b"
)

_ECONOMICS = re.compile(
    r"(?i)\b("
    r"demand|supply|price|market|inflation|deflation|gdp|gnp|"
    r"fiscal|monetary|policy|budget|tax|revenue|expenditure|"
    r"bank|interest\s*rate|repo\s*rate|crr|slr|"
    r"trade|export|import|balance\s*of\s*payment|forex|"
    r"microeconomics|macroeconomics|economics|elasticity|"
    r"unemployment|poverty|inequality|subsidy|privatization|"
    r"consumer|producer|surplus|equilibrium\s+price"
    r")\b"
)

_ENGLISH = re.compile(
    r"(?i)\b("
    r"poem|poet|prose|novel|story|chapter|stanza|verse|rhyme|"
    r"metaphor|simile|alliteration|imagery|symbol|theme|tone|"
    r"author|writer|character|protagonist|antagonist|plot|"
    r"grammar|tense|noun|verb|adjective|adverb|preposition|"
    r"comprehension|passage|paragraph|essay|letter|report|"
    r"english|literature|shakespeare|wordsworth"
    r")\b"
)

# -- Subject detection order (specific first) ---------------------------------

_SUBJECT_ORDER = [
    ("math",              _MATH),
    ("physics",           _PHYSICS),
    ("chemistry",         _CHEMISTRY),
    ("biology",           _BIOLOGY),
    ("political_science", _POLITICAL_SCIENCE),
    ("history",           _HISTORY),
    ("economics",         _ECONOMICS),
    ("english",           _ENGLISH),
]

# -- Teaching hints (compact, injected into user prompt) ---------------------

_TEACHING_HINTS: dict[str, str] = {
    "math": (
        "SUBJECT: Mathematics. "
        "Show numbered steps clearly. State the formula/rule used at each step. "
        "Show full working. Clearly state the final answer. "
        "If a graph/diagram helps, mention it."
    ),
    "physics": (
        "SUBJECT: Physics. "
        "State the relevant formula first. Define each variable with units. "
        "If numerical: substitute values step by step, final answer with unit. "
        "If conceptual: explain the physical intuition, then the law/equation."
    ),
    "chemistry": (
        "SUBJECT: Chemistry. "
        "Write the balanced equation if applicable. "
        "Explain mechanism or process step by step. "
        "Highlight key terms (oxidizing agent, catalyst, etc.). "
        "Add a memory trick only if it genuinely helps."
    ),
    "biology": (
        "SUBJECT: Biology/NEET. "
        "Classify first (Kingdom to relevant level) if applicable. "
        "Explain function/process clearly. "
        "Mention diagram cue if a labeled diagram would help. "
        "Use exam-useful bullet points for multi-part answers."
    ),
    "political_science": (
        "SUBJECT: Political Science/Civics. "
        "Give context first (why this provision exists). "
        "State the exact Article/Schedule/Act if in the notes. "
        "Explain its significance for exams."
    ),
    "history": (
        "SUBJECT: History. "
        "Follow order: background, cause, event, effect, significance. "
        "Name key figures, dates, and places from the notes. "
        "Keep exam-style writing — clear and factual."
    ),
    "economics": (
        "SUBJECT: Economics. "
        "Define the concept first. "
        "If a graph/diagram is relevant, mention its axes and curves. "
        "Give a real-world or Indian-economy example if present in notes."
    ),
    "english": (
        "SUBJECT: English Literature/Language. "
        "If poem/prose: quote the relevant line (from notes only), then interpret. "
        "Name the literary device if applicable. "
        "For grammar: state the rule, then give an example."
    ),
}


def detect_subject(query: str) -> str:
    """Detect subject key from student query. Returns 'general' if no match."""
    q = (query or "").strip()
    if not q:
        return "general"
    for subject, pattern in _SUBJECT_ORDER:
        if pattern.search(q):
            return subject
    return "general"


def subject_teaching_hint(query: str) -> str:
    """Return compact teaching-style instruction for LLM injection.
    Returns empty string for general queries — no forced instruction.
    """
    subject = detect_subject(query)
    return _TEACHING_HINTS.get(subject, "")
