"""Derive Home AI chip payloads from Knowledge Object — no LLM call.

Founder lock: chips stay FREE after Ask. But each tool must feel like a
*different study job* — not the same essay with a new title.
"""
from __future__ import annotations

import hashlib
import re
from typing import Any


def _points(knowledge: dict[str, Any]) -> list[str]:
    pts = knowledge.get("key_points") or knowledge.get("concepts") or []
    out = [str(p).strip() for p in pts if str(p).strip()]
    if out:
        return out
    summary = (knowledge.get("summary") or "").strip()
    if summary:
        return [summary]
    expl = (knowledge.get("explanation") or "").strip()
    if expl:
        parts = [s.strip() for s in expl.replace("!", ".").split(".") if s.strip()]
        return parts[:6]
    return []


def _topic(knowledge: dict[str, Any]) -> str:
    meta = knowledge.get("metadata") or {}
    q = (meta.get("query") or "").strip()
    if q:
        # Prefer noun phrase: strip leading "what is/are"
        q2 = re.sub(
            r"^(what\s+is|what\s+are|define|explain|describe)\s+",
            "",
            q,
            flags=re.I,
        ).strip(" ?.")
        q2 = q2 or q
        return q2 if len(q2) < 80 else q2[:77] + "…"
    return (knowledge.get("summary") or "Topic").strip()[:80] or "Topic"


def _short(text: str, n: int = 140) -> str:
    t = (text or "").strip()
    if len(t) <= n:
        return t
    return t[: n - 1].rstrip() + "…"


def _keyword(point: str) -> str:
    """Pick a memorable word/phrase from a key point for cloze / stems."""
    stop = {
        "the",
        "a",
        "an",
        "and",
        "or",
        "of",
        "to",
        "in",
        "on",
        "for",
        "is",
        "are",
        "was",
        "were",
        "with",
        "that",
        "this",
        "from",
        "using",
        "into",
        "needs",
        "need",
        "makes",
        "make",
        "happens",
        "happen",
        "produces",
        "produce",
    }
    words = re.findall(r"[A-Za-z0-9][A-Za-z0-9\-]*", point)
    juicy = [w for w in words if w.lower() not in stop and len(w) > 3]
    if juicy:
        # Prefer capitalized / longer
        juicy.sort(key=lambda w: (w[0].isupper(), len(w)), reverse=True)
        return juicy[0]
    return words[0] if words else "idea"


def _stable_shuffle(items: list[str], seed: str) -> list[str]:
    """Deterministic shuffle so same KO → same quiz options (cache-friendly)."""
    scored = []
    for i, item in enumerate(items):
        h = hashlib.md5(f"{seed}:{i}:{item}".encode()).hexdigest()
        scored.append((h, item))
    scored.sort(key=lambda x: x[0])
    return [x[1] for x in scored]


def _letter(i: int) -> str:
    return chr(ord("A") + i)


def derive_tool_payload(
    tool_type: str,
    knowledge: dict[str, Any],
    *,
    pyq_matches: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Build structured chip payload from KO only — unique job per tool."""
    key = (tool_type or "").strip().lower()
    topic = _topic(knowledge)
    points = _points(knowledge)
    summary = (knowledge.get("summary") or "").strip()
    explanation = (knowledge.get("explanation") or summary or "").strip()
    formulas = [str(f).strip() for f in (knowledge.get("formulas") or []) if str(f).strip()]
    tip = (knowledge.get("exam_tip") or "").strip()
    related = [str(r).strip() for r in (knowledge.get("related_topics") or []) if str(r).strip()]
    visual = knowledge.get("visual_payload")

    if key == "flashcards":
        return _derive_flashcards(topic, points, summary, explanation, formulas, tip)

    if key == "quiz":
        return _derive_quiz(topic, points, summary, explanation, formulas)

    if key == "revision":
        return _derive_revision(topic, points, summary, formulas, tip, visual)

    if key == "five_min_revision":
        return _derive_five_min(topic, points, summary, tip)

    if key == "cheat_sheet":
        return _derive_cheat_sheet(topic, points, formulas, tip)

    if key == "mind_map":
        return _derive_mind_map(topic, points, summary, formulas, related)

    if key == "important_questions":
        exam_focus = knowledge.get("exam_focus")
        if not isinstance(exam_focus, list):
            exam_focus = []
        return _derive_important_questions(
            topic, points, summary, tip, formulas, exam_focus=exam_focus
        )

    if key == "memory_tricks":
        return _derive_memory(topic, points, formulas)

    if key == "learn_more":
        return _derive_learn_more(topic, points, summary, explanation, formulas, related)

    if key == "visual":
        return _derive_visual(topic, points, summary, visual)

    if key == "exam_booster":
        return _derive_exam_booster(topic, points, tip, formulas)

    if key == "common_mistakes":
        return _derive_common_mistakes(topic, points, formulas)

    if key == "teacher_tips":
        return _derive_teacher_tips(topic, points, summary, tip)

    raise ValueError(f"Cannot derive tool_type={tool_type}")


def _derive_flashcards(
    topic: str,
    points: list[str],
    summary: str,
    explanation: str,
    formulas: list[str],
    tip: str,
) -> dict[str, Any]:
    """Active recall — front is a question, back is the answer (never same text)."""
    cards: list[dict[str, str]] = []

    # Card 1 — definition
    cards.append(
        {
            "front": f"In one line: what is {topic}?",
            "back": summary or _short(explanation, 220) or topic,
        }
    )

    # Point cards — ask WHY / WHAT / WHERE style, not "Recall: point"
    stems = (
        "Why does this matter for {topic}?",
        "True or false — fix it: “{snippet}” (say the correct version)",
        "Fill the blank: {cloze}",
        "Name the idea: {hint}…",
    )
    for i, p in enumerate(points[:8]):
        kw = _keyword(p)
        if re.search(re.escape(kw), p, flags=re.I):
            cloze = re.sub(re.escape(kw), "______", p, count=1, flags=re.I)
        else:
            cloze = f"______ — related to {topic}"
        stem = stems[i % len(stems)]
        front = stem.format(
            topic=topic,
            snippet=_short(p, 70),
            cloze=_short(cloze, 100),
            hint=_short(p, 40).rsplit(" ", 1)[0] if len(p) > 40 else p[:20],
        )
        back = p
        if i == 0 and tip:
            back = f"{p}\n\nExam tip: {tip}"
        cards.append({"front": front, "back": back})

    for f in formulas[:3]:
        cards.append(
            {
                "front": f"Write / recall the formula linked to {topic}.",
                "back": f"`{f}`\n\nSay what each symbol means once.",
            }
        )
        cards.append(
            {
                "front": f"What does this formula represent?\n`{_short(f, 60)}`",
                "back": summary or f"Core relation for {topic}.",
            }
        )

    if len(cards) < 4 and explanation:
        cards.append(
            {
                "front": f"Explain {topic} to a Class 8 student in 2 sentences.",
                "back": _short(explanation, 400),
            }
        )

    # Dedup fronts
    seen: set[str] = set()
    unique: list[dict[str, str]] = []
    for c in cards:
        if c["front"] in seen:
            continue
        seen.add(c["front"])
        unique.append(c)
    return {"cards": unique[:15], "source": "knowledge_object", "credits": 0, "format": "active_recall"}


def _derive_quiz(
    topic: str,
    points: list[str],
    summary: str,
    explanation: str,
    formulas: list[str],
) -> dict[str, Any]:
    """MCQ with shuffled answers + varied stems — not “which statement matches” × N."""
    questions: list[dict[str, Any]] = []
    pool = points[:8] or ([summary] if summary else [topic])
    filler_wrong = [
        f"A definition that belongs to a different chapter, not {topic}",
        f"The opposite process / reverse of {topic}",
        f"A lab safety rule unrelated to {topic}",
        f"A date / name from world history (distractor)",
        f"A formula from a different unit than {topic}",
    ]

    # Q-type 0: best definition
    if summary or pool:
        correct = summary or pool[0]
        opts = _stable_shuffle(
            [correct, filler_wrong[0], filler_wrong[1], filler_wrong[2]],
            f"def:{topic}",
        )
        ci = opts.index(correct)
        questions.append(
            {
                "question": f"Which option best defines {topic}?",
                "options": [_short(o, 160) for o in opts],
                "correctAnswer": _letter(ci),
                "explanation": f"Definition: {_short(correct, 200)}",
            }
        )

    # Per-point: "which is true about X"
    for i, p in enumerate(pool[:5]):
        correct = p
        others = [x for j, x in enumerate(pool) if j != i][:2]
        while len(others) < 2:
            others.append(filler_wrong[(i + len(others)) % len(filler_wrong)])
        wrong3 = filler_wrong[(i + 3) % len(filler_wrong)]
        opts = _stable_shuffle([correct, others[0], others[1], wrong3], f"true:{i}:{topic}")
        ci = opts.index(correct)
        questions.append(
            {
                "question": f"Which statement about {topic} is correct?",
                "options": [_short(o, 160) for o in opts],
                "correctAnswer": _letter(ci),
                "explanation": f"Key idea: {_short(correct, 180)}",
            }
        )

    # Odd-one-out if enough points
    if len(pool) >= 3:
        odd = filler_wrong[0]
        opts = _stable_shuffle([pool[0], pool[1], pool[2], odd], f"odd:{topic}")
        ci = opts.index(odd)
        questions.append(
            {
                "question": f"Odd one out — which does NOT belong with {topic}?",
                "options": [_short(o, 160) for o in opts],
                "correctAnswer": _letter(ci),
                "explanation": f"The outsider is not a key point of {topic}.",
            }
        )

    # Formula match
    if formulas:
        f = formulas[0]
        opts = _stable_shuffle(
            [
                f,
                "E = mc² (wrong context)",
                "F = ma (wrong context)",
                "a² + b² = c² (wrong context)",
            ],
            f"form:{topic}",
        )
        ci = opts.index(f)
        questions.append(
            {
                "question": f"Which formula / relation belongs with {topic}?",
                "options": [_short(o, 160) for o in opts],
                "correctAnswer": _letter(ci),
                "explanation": f"Linked formula: {f}",
            }
        )

    # Application / use
    if explanation or summary:
        correct = f"Apply {topic}: {_short(summary or explanation, 100)}"
        opts = _stable_shuffle(
            [
                correct,
                f"Ignore {topic} and memorize only the name",
                "Copy a random Wikipedia paragraph",
                "Skip diagrams and write only adjectives",
            ],
            f"app:{topic}",
        )
        ci = opts.index(correct)
        questions.append(
            {
                "question": f"In an exam answer on {topic}, what should you do?",
                "options": [_short(o, 160) for o in opts],
                "correctAnswer": _letter(ci),
                "explanation": "Examiners reward clear definition + mechanism + example.",
            }
        )

    return {
        "questions": questions[:10],
        "source": "knowledge_object",
        "credits": 0,
        "format": "mcq_varied",
    }


def _derive_revision(
    topic: str,
    points: list[str],
    summary: str,
    formulas: list[str],
    tip: str,
    visual: Any,
) -> dict[str, Any]:
    """Condensed sheet — checklist + traps, NOT full explanation dump."""
    lines = [
        f"# Revision — {topic}",
        "",
        "## 10-second core",
        summary or (points[0] if points else topic),
        "",
        "## Must-say bullets (exam keywords)",
    ]
    for p in points[:6]:
        lines.append(f"- {_short(p, 120)}")
    if formulas:
        lines += ["", "## Write these once (closed book)"]
        for f in formulas[:4]:
            lines.append(f"- `{f}`")
    lines += [
        "",
        "## Cover & recall",
        f"1. Close notes. Say: what is {topic}?",
        "2. List 3 bullets without peeking.",
        "3. Open — tick what you missed.",
        "",
        "## Trap to avoid",
        f"- Writing a long story instead of structured points on {topic}",
    ]
    if tip:
        lines += ["", "## Scoring tip", tip]
    sheet = "\n".join(lines)
    out: dict[str, Any] = {
        "revisionSheet": sheet,
        "source": "knowledge_object",
        "format": "condensed_checklist",
    }
    if isinstance(visual, dict):
        out["visualPayload"] = visual
    return out


def _derive_five_min(topic: str, points: list[str], summary: str, tip: str) -> dict[str, Any]:
    """Timed drill — different job from full revision sheet."""
    lines = [
        f"# 5-Minute Drill — {topic}",
        "",
        "| Clock | Do this |",
        "|-------|---------|",
        f"| 0:00–0:30 | Say definition aloud: {_short(summary or topic, 80)} |",
        f"| 0:30–2:00 | Rapid-fire 3 points: {'; '.join(_short(p, 40) for p in points[:3]) or topic} |",
        f"| 2:00–3:30 | Teach {topic} to an imaginary friend (no notes) |",
        "| 3:30–4:30 | Write 5 keywords only |",
        "| 4:30–5:00 | Peek → circle what you forgot |",
        "",
        "## Pass rule",
        "You pass this drill if you can list 3 bullets without looking.",
    ]
    if tip:
        lines += ["", "## Last 10 seconds", tip]
    return {
        "revisionSheet": "\n".join(lines),
        "source": "knowledge_object",
        "format": "timed_drill",
    }


def _derive_cheat_sheet(
    topic: str, points: list[str], formulas: list[str], tip: str
) -> dict[str, Any]:
    """Ultra-compact — one glance, not a mini-essay."""
    facts = [_short(p, 70) for p in points[:6]]
    mistakes = [
        f"Mixing {topic} with a look-alike term",
        "Skipping units / conditions",
        "No one-line ‘why’ after the definition",
    ]
    md = [
        f"# Cheat Sheet — {topic}",
        "",
        "| Need | Write |",
        "|------|-------|",
        f"| 1-line def | {_short(points[0] if points else topic, 90)} |",
    ]
    for i, p in enumerate(facts[1:4], 2):
        md.append(f"| Bullet {i} | {p} |")
    if formulas:
        md += ["", "## Formulas (copy once)"]
        for f in formulas[:4]:
            md.append(f"- `{f}`")
    md += ["", "## Don’t"]
    for m in mistakes:
        md.append(f"- {m}")
    if tip:
        md += ["", f"**Tip:** {tip}"]
    return {
        "markdown": "\n".join(md),
        "formulas": formulas,
        "quick_facts": facts,
        "mistakes": mistakes,
        "memory_tricks": [],
        "source": "knowledge_object",
        "format": "one_glance_table",
    }


def _derive_mind_map(
    topic: str,
    points: list[str],
    summary: str,
    formulas: list[str],
    related: list[str],
) -> dict[str, Any]:
    """Tree by role — Definition / Mechanism / Result / Link — not flat same list."""
    buckets: dict[str, list[str]] = {
        "Definition": [],
        "Mechanism / How": [],
        "Result / Why it matters": [],
        "Links": [],
    }
    if summary:
        buckets["Definition"].append(_short(summary, 80))
    for i, p in enumerate(points):
        if i == 0 and not buckets["Definition"]:
            buckets["Definition"].append(_short(p, 80))
        elif i % 3 == 1:
            buckets["Mechanism / How"].append(_short(p, 80))
        else:
            buckets["Result / Why it matters"].append(_short(p, 80))
    for r in related[:4]:
        buckets["Links"].append(_short(r, 60))
    if formulas:
        buckets["Mechanism / How"].append("Formulas: " + "; ".join(_short(f, 40) for f in formulas[:2]))

    children = []
    for label, items in buckets.items():
        if not items:
            continue
        children.append(
            {
                "label": label,
                "children": [{"label": it, "children": []} for it in items[:5]],
            }
        )
    if not children:
        children = [{"label": _short(summary or topic, 80), "children": []}]
    return {
        "title": topic,
        "root": {"label": _short(topic, 60), "children": children},
        "source": "knowledge_object",
        "format": "role_tree",
    }


def _derive_important_questions(
    topic: str,
    points: list[str],
    summary: str,
    tip: str,
    formulas: list[str],
    exam_focus: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Exam paper voice — bias toward high weightage PYQ chapter tags when present."""
    focus = [m for m in (exam_focus or []) if isinstance(m, dict)]
    focus_sorted = sorted(
        focus,
        key=lambda m: int(m.get("weightage_stars") or 0),
        reverse=True,
    )
    qs: list[dict[str, Any]] = [
        {
            "question": f"Define {topic}. (2 marks)",
            "type": "short_answer",
            "marks": 2,
            "hint": _short(summary or (points[0] if points else topic), 100),
            "model_angle": "1 definition line + 1 condition/context",
        },
        {
            "question": f"Explain the working / process behind {topic}. (3–5 marks)",
            "type": "long_answer",
            "marks": 5,
            "hint": "Use 3 sequenced bullets from key points",
            "model_angle": " → ".join(_short(p, 40) for p in points[:3]) or summary,
        },
        {
            "question": f"Give one reason why {topic} is important / used. (2 marks)",
            "type": "short_answer",
            "marks": 2,
            "hint": tip or (points[-1] if points else None),
            "model_angle": "Start with ‘Because…’ then one concrete use",
        },
        {
            "question": f"State any two points about {topic} that examiners look for.",
            "type": "short_answer",
            "marks": 2,
            "hint": "; ".join(_short(p, 50) for p in points[:2]),
            "model_angle": "Keywords, not a paragraph",
        },
    ]
    if formulas:
        qs.append(
            {
                "question": f"Write the relation/formula for {topic} and name each term. (3 marks)",
                "type": "short_answer",
                "marks": 3,
                "hint": formulas[0],
                "model_angle": "Formula + symbol meaning",
            }
        )
    if len(points) >= 2:
        qs.append(
            {
                "question": f"Differentiate / contrast: how is “{_short(points[0], 40)}” different from “{_short(points[1], 40)}” in the context of {topic}?",
                "type": "short_answer",
                "marks": 3,
                "hint": "Two columns: Point A vs Point B",
                "model_angle": "Table beats essay",
            }
        )

    # High weightage chapters get exam-focus questions (chance bias, metadata only).
    for m in focus_sorted[:3]:
        chapter = (m.get("chapter") or "").strip()
        exam = (m.get("exam") or "Exam").strip()
        year = m.get("year")
        stars = int(m.get("weightage_stars") or 0)
        if not chapter:
            continue
        marks = 5 if stars >= 4 else 3
        qs.append(
            {
                "question": (
                    f"[{exam} {year} focus · {chapter}] "
                    f"Write a {marks}-mark answer linking {topic} to “{chapter}” "
                    f"(mechanism + one exam trap)."
                ),
                "type": "long_answer" if marks >= 5 else "short_answer",
                "marks": marks,
                "hint": f"Stay on {chapter}; do not invent paper wording",
                "model_angle": f"weightage {stars}/5 → prioritize this angle",
                "exam_focus": f"{exam} {year} · {chapter}",
            }
        )

    focus_lines = []
    for m in focus_sorted[:5]:
        exam = (m.get("exam") or "").strip()
        year = m.get("year")
        chapter = (m.get("chapter") or "").strip()
        subject = (m.get("subject") or "").strip()
        if not exam:
            continue
        bit = f"{exam} {year}".strip()
        if subject:
            bit += f" · {subject}"
        if chapter:
            bit += f" · {chapter}"
        focus_lines.append(bit)

    return {
        "questions": qs[:8],
        "source": "knowledge_object",
        "format": "exam_paper",
        "exam_focus": focus_lines,
    }


def _derive_memory(topic: str, points: list[str], formulas: list[str]) -> dict[str, Any]:
    """Story / scene mnemonics — not “first letters of the same sentence”."""
    tricks: list[dict[str, str]] = []
    scenes = (
        "Imagine a tiny classroom poster with only this idea in huge font.",
        "Picture a friend interrupting you mid-tea to ask only this fact.",
        "Link it to a door you walk through every day — touch the door, recall the fact.",
        "Make a 3-second comic: before → action → after.",
        "Whisper it as a password you must say before opening your notes app.",
    )
    for i, p in enumerate(points[:5]):
        kw = _keyword(p)
        tricks.append(
            {
                "trigger": f"Cue word: **{kw}**",
                "mnemonic": (
                    f"{scenes[i % len(scenes)]} "
                    f"When you see “{kw}”, unlock: {_short(p, 100)}"
                ),
                "why_it_works": "One cue word + one scene beats re-reading the paragraph.",
            }
        )
    if formulas:
        tricks.append(
            {
                "trigger": f"Formula cue for {topic}",
                "mnemonic": (
                    f"Draw the formula `{_short(formulas[0], 50)}` with your finger in the air once, "
                    "then hide hands and rewrite from memory."
                ),
                "why_it_works": "Muscle memory + eyes closed = exam speed.",
            }
        )
    if not tricks:
        tricks = [
            {
                "trigger": topic,
                "mnemonic": f"One movie scene that proves “{topic}” in real life — pause and name 2 details.",
                "why_it_works": "Images stick longer than paragraphs.",
            }
        ]
    md = f"## Memory Gym — {topic}\n\n" + "\n".join(
        f"- {t['trigger']}: {t['mnemonic']}" for t in tricks
    )
    return {
        "tricks": tricks,
        "markdown": md,
        "source": "knowledge_object",
        "format": "cue_scene",
    }


def _derive_learn_more(
    topic: str,
    points: list[str],
    summary: str,
    explanation: str,
    formulas: list[str],
    related: list[str],
) -> dict[str, Any]:
    """Depth angles — miss / analogy / bridge — not paste of Easy Explanation."""
    sections = [
        {
            "title": "What most students miss",
            "body": (
                f"They memorize the name “{topic}” but skip the mechanism. "
                f"Hold this: {_short(summary or (points[0] if points else topic), 200)}"
            ),
        },
        {
            "title": "Analogy (make it sticky)",
            "body": (
                f"Think of {topic} like a simple machine with inputs → process → output. "
                f"Map your key points onto that machine:\n"
                + "\n".join(f"- {_short(p, 100)}" for p in points[:4])
            ),
        },
        {
            "title": "If the examiner goes deeper",
            "body": _short(explanation, 900)
            or "Add one condition, one exception, and one real-world use.",
        },
    ]
    if formulas:
        sections.append(
            {
                "title": "Formula story",
                "body": "\n".join(
                    f"- `{f}` → say what changes if one term doubles." for f in formulas[:3]
                ),
            }
        )
    if related:
        sections.append(
            {
                "title": "Bridge to next topics",
                "body": "\n".join(f"- After {topic}, revise: {r}" for r in related[:5]),
            }
        )
    else:
        sections.append(
            {
                "title": "Bridge to next topics",
                "body": f"- Prerequisites of {topic}\n- Applications of {topic}\n- Common confusions with look-alike chapters",
            }
        )
    md = f"# Learn More — {topic}\n\n"
    for s in sections:
        md += f"## {s['title']}\n\n{s['body']}\n\n"
    return {
        "markdown": md.strip(),
        "sections": sections,
        "source": "knowledge_object",
        "format": "depth_angles",
    }


def _derive_visual(
    topic: str, points: list[str], summary: str, visual: Any
) -> dict[str, Any]:
    if isinstance(visual, dict) and visual:
        return {
            "visual_payload": visual,
            "markdown": f"## Visual — {topic}\n\nUse the diagram below; don’t re-read the essay.",
            "source": "knowledge_object",
            "format": "smart_visual",
        }

    # Prefer real topic diagrams — never turn answer section titles into boxes.
    from app.services.visual_fallback import fallback_visual_payload

    _SECTIONISH = {
        "direct answer",
        "easy explanation",
        "key points",
        "exam tip",
        "related topics",
        "source",
        "important formula",
        "formulas",
        "formula",
    }
    clean_pts = [
        p
        for p in points
        if p.strip().lower().rstrip(":") not in _SECTIONISH
        and len(p.strip()) > 3
    ]

    fb = fallback_visual_payload(topic, summary or " ".join(clean_pts[:4]))
    if fb:
        return {
            "visual_payload": fb,
            "markdown": f"## Visual — {topic}",
            "source": "knowledge_object",
            "format": "smart_visual",
        }

    steps = clean_pts[:5] or ([summary] if summary else [])
    if len(steps) < 2:
        return {
            "markdown": (
                f"## Visual — {topic}\n\n"
                "No diagram for this topic yet. Ask again with "
                "“draw a diagram of …” or open Regenerate."
            ),
            "source": "knowledge_object",
            "format": "no_visual",
        }

    arrows = "\n    ↓\n".join(f"[ {_short(s, 36)} ]" for s in steps)
    return {
        "visual_payload": {
            "process_flows": [
                {
                    "title": f"{topic} flow",
                    "content": "\n↓\n".join(steps),
                }
            ]
        },
        "markdown": f"## Visual — {topic}\n\n```\n{arrows}\n```\n",
        "source": "knowledge_object",
        "format": "flow_boxes",
    }


def _derive_exam_booster(
    topic: str, points: list[str], tip: str, formulas: list[str]
) -> dict[str, Any]:
    """Marks machine — what to write under time pressure."""
    md = [
        f"# Exam Booster — {topic}",
        "",
        "## 2-mark script (memorize order)",
        f"1. Definition of {topic}",
        f"2. One condition / one example",
        "",
        "## 5-mark skeleton",
        f"1. Definition",
        f"2. Mechanism (2–3 bullets)",
        f"3. One diagram cue / flow",
        f"4. Closing ‘so what’ line",
        "",
        "## Keyword bank (underline these)",
    ]
    for p in points[:6]:
        kw = _keyword(p)
        md.append(f"- **{kw}** ← {_short(p, 90)}")
    if formulas:
        md += ["", "## Formula = free marks"]
        for f in formulas[:3]:
            md.append(f"- Write `{f}` then label symbols")
    md += [
        "",
        "## Time cuts",
        "- Don’t write a story introduction",
        "- Prefer numbered points over paragraphs",
        "- If stuck: definition → any 2 keywords → move on",
    ]
    if tip:
        md += ["", "## Teacher scoring tip", tip]
    return {
        "markdown": "\n".join(md),
        "source": "knowledge_object",
        "format": "marks_script",
    }


def _derive_common_mistakes(
    topic: str, points: list[str], formulas: list[str]
) -> dict[str, Any]:
    """Topic-tied traps + fixes — not 3 generic life tips."""
    mistakes: list[dict[str, str]] = [
        {
            "mistake": f"Treating “{topic}” as only a name to memorize",
            "fix": f"Always add mechanism: {_short(points[0] if points else topic, 100)}",
        },
        {
            "mistake": "Dumping every fact in one paragraph",
            "fix": "Use numbered bullets the examiner can tick",
        },
    ]
    if len(points) >= 2:
        mistakes.append(
            {
                "mistake": f"Confusing “{_short(points[0], 50)}” with “{_short(points[1], 50)}”",
                "fix": "Make a 2-column contrast before the exam",
            }
        )
    if len(points) >= 3:
        mistakes.append(
            {
                "mistake": f"Forgetting “{_keyword(points[2])}” under time pressure",
                "fix": f"Cue card: {_short(points[2], 80)}",
            }
        )
    if formulas:
        mistakes.append(
            {
                "mistake": "Writing the formula with no conditions / units / meaning",
                "fix": f"After `{_short(formulas[0], 50)}`, add one line: what it means",
            }
        )
    md = [f"# Common Mistakes — {topic}", ""]
    for i, m in enumerate(mistakes, 1):
        md.append(f"### {i}. {m['mistake']}")
        md.append(f"**Fix:** {m['fix']}")
        md.append("")
    return {
        "markdown": "\n".join(md),
        "mistakes": [m["mistake"] for m in mistakes],
        "fixes": [m["fix"] for m in mistakes],
        "source": "knowledge_object",
        "format": "trap_and_fix",
    }


def _derive_teacher_tips(
    topic: str, points: list[str], summary: str, tip: str
) -> dict[str, Any]:
    """How to teach / learn — pedagogy, not re-paste of explanation."""
    md = [
        f"# Teacher Tips — {topic}",
        "",
        "## Lesson order (steal this)",
        f"1. Hook (30s): Why should I care about {topic}?",
        f"2. One-line definition: {_short(summary or topic, 100)}",
        "3. Build with 3 bricks (your key points)",
    ]
    for i, p in enumerate(points[:3], 1):
        md.append(f"   - Brick {i}: {_short(p, 90)}")
    md += [
        "4. Student teaches back in 60 seconds",
        "5. Exit ticket: one MCQ + one keyword",
        "",
        "## Board / copy habits",
        "- Left side: definition + diagram cue",
        "- Right side: 3 bullets + 1 tip",
        "- Red underline: examiner keywords only",
        "",
        "## If a student is stuck",
        f"Ask: “What are the inputs and outputs of {topic}?” — then fill gaps.",
    ]
    if tip:
        md += ["", "## From your answer’s exam tip", tip]
    return {
        "markdown": "\n".join(md),
        "source": "knowledge_object",
        "format": "lesson_plan",
    }


def recommend_tool_types(knowledge: dict[str, Any], query: str = "") -> list[str]:
    """Dynamic recommended chips from topic signals."""
    text = " ".join(
        [
            query,
            str((knowledge.get("metadata") or {}).get("query") or ""),
            knowledge.get("summary") or "",
            " ".join(knowledge.get("key_points") or []),
        ]
    ).lower()

    rec = ["flashcards", "quiz", "revision"]

    if any(w in text for w in ("photo", "cycle", "process", "flow", "biology", "cell", "reaction")):
        rec = ["visual", "flashcards", "quiz", "memory_tricks"]
    elif any(w in text for w in ("history", "war", "empire", "year", "century", "timeline")):
        rec = ["visual", "important_questions", "revision", "memory_tricks"]
    elif any(w in text for w in ("math", "equation", "formula", "derivative", "integral", "algebra")):
        rec = ["quiz", "flashcards", "revision", "mind_map"]
    elif any(w in text for w in ("grammar", "tense", "noun", "verb", "english", "sentence")):
        rec = ["quiz", "flashcards", "memory_tricks", "learn_more"]
    elif any(w in text for w in ("network", "code", "program", "api", "computer", "algorithm")):
        rec = ["mind_map", "quiz", "learn_more", "revision"]
    elif any(w in text for w in ("map", "climate", "river", "geography", "continent")):
        rec = ["visual", "flashcards", "important_questions", "revision"]

    if knowledge.get("visual_payload") and "visual" not in rec:
        rec = ["visual"] + [t for t in rec if t != "visual"]

    if any(w in text for w in ("exam", "neet", "jee", "board", "marks", "important")):
        if "important_questions" not in rec:
            rec = rec[:3] + ["important_questions"]

    seen: set[str] = set()
    out: list[str] = []
    for t in rec:
        if t not in seen:
            seen.add(t)
            out.append(t)
    return out[:4]
