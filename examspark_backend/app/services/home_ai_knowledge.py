"""Build reusable Knowledge Object from a Home AI answer (Phase 4C).

Heuristic parse — no second LLM call. Chips reuse this structured context
instead of resending the full prior answer as a free-form prompt.
"""
from __future__ import annotations

import re
from typing import Any


_SECTION_HEADERS = (
    "direct answer",
    "easy explanation",
    "key points",
    "exam tip",
    "related topics",
    "source",
    "important formula",
    "formulas",
    "formula",
)


def _strip_md(text: str) -> str:
    t = text.strip()
    t = re.sub(r"^#+\s*", "", t)
    t = re.sub(r"\*\*(.+?)\*\*", r"\1", t)
    t = re.sub(r"\*(.+?)\*", r"\1", t)
    return t.strip()


def _split_sections(answer: str) -> dict[str, str]:
    """Split markdown-ish answer into named sections when headers exist."""
    lines = (answer or "").splitlines()
    sections: dict[str, list[str]] = {}
    current = "_body"
    sections[current] = []
    header_re = re.compile(r"^#{1,3}\s*(.+?)\s*$")
    bold_header_re = re.compile(r"^\*\*(.+?)\*\*\s*:?\s*$")
    for line in lines:
        h = None
        m = header_re.match(line.strip())
        if m:
            h = m.group(1).strip().lower()
        else:
            m2 = bold_header_re.match(line.strip())
            if m2:
                h = m2.group(1).strip().lower()
        if h:
            for name in _SECTION_HEADERS:
                if name in h:
                    current = name
                    sections.setdefault(current, [])
                    break
            else:
                current = "_body"
                sections.setdefault(current, [])
            continue
        sections.setdefault(current, []).append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items() if "\n".join(v).strip()}


def _bullets(text: str, *, limit: int = 8) -> list[str]:
    out: list[str] = []
    for line in (text or "").splitlines():
        s = line.strip()
        if re.match(r"^[-*•]\s+", s) or re.match(r"^\d+[.)]\s+", s):
            item = re.sub(r"^[-*•]\s+", "", s)
            item = re.sub(r"^\d+[.)]\s+", "", item)
            item = _strip_md(item)
            if item:
                out.append(item)
        if len(out) >= limit:
            break
    return out


def _formulas(text: str, *, limit: int = 6) -> list[str]:
    found: list[str] = []
    for m in re.finditer(r"\$\$([^$]+)\$\$", text or ""):
        found.append(m.group(1).strip())
    for m in re.finditer(r"\$([^$\n]+)\$", text or ""):
        f = m.group(1).strip()
        if f and f not in found:
            found.append(f)
    # Plain lines that look like equations
    for line in (text or "").splitlines():
        s = line.strip()
        if "=" in s and len(s) < 120 and not s.startswith("#"):
            clean = _strip_md(s.lstrip("-*• "))
            if clean and clean not in found and re.search(r"[a-zA-Z0-9].*=", clean):
                found.append(clean)
        if len(found) >= limit:
            break
    return found[:limit]


def build_knowledge_object(
    *,
    query: str,
    answer: str,
    visual_payload: dict[str, Any] | None = None,
    answer_source: str | None = None,
    confidence: str | None = None,
) -> dict[str, Any]:
    """Convert Home AI answer into reusable structured knowledge."""
    sections = _split_sections(answer)
    direct = sections.get("direct answer") or ""
    explanation = sections.get("easy explanation") or ""
    key_block = sections.get("key points") or ""
    formula_block = (
        sections.get("important formula")
        or sections.get("formulas")
        or sections.get("formula")
        or ""
    )

    key_points = _bullets(key_block) or _bullets(answer)
    formulas = _formulas(formula_block) or _formulas(answer)

    # Summary: Direct Answer, else first ~280 chars of answer
    summary = _strip_md(direct) if direct else ""
    if not summary:
        plain = re.sub(r"\s+", " ", _strip_md(answer))[:280].strip()
        summary = plain + ("…" if len(answer) > 280 else "")

    if not explanation:
        # Use body after summary, capped for chip reuse
        explanation = answer.strip()

    related = _bullets(sections.get("related topics") or "", limit=5)

    return {
        "summary": summary,
        "explanation": explanation[:4000],
        "key_points": key_points,
        "formulas": formulas,
        "concepts": key_points[:5],
        "examples": [],
        "related_topics": related,
        "exam_tip": _strip_md(sections.get("exam tip") or "")[:500] or None,
        "visual_payload": visual_payload,
        "metadata": {
            "query": query,
            "answer_source": answer_source,
            "confidence": confidence,
            "answer_chars": len(answer or ""),
        },
    }


def knowledge_to_source_text(knowledge: dict[str, Any], *, max_chars: int = 3500) -> str:
    """Compact source text for chip generators — never the raw mega chat paste."""
    meta = knowledge.get("metadata") or {}
    query = meta.get("query") or ""
    parts: list[str] = []
    if query:
        parts.append(f"Topic / Question:\n{query}")
    summary = (knowledge.get("summary") or "").strip()
    if summary:
        parts.append(f"Summary:\n{summary}")
    keys = knowledge.get("key_points") or []
    if keys:
        parts.append("Key points:\n" + "\n".join(f"- {k}" for k in keys[:10]))
    formulas = knowledge.get("formulas") or []
    if formulas:
        parts.append("Formulas:\n" + "\n".join(f"- {f}" for f in formulas[:6]))
    tip = knowledge.get("exam_tip")
    if tip:
        parts.append(f"Exam tip:\n{tip}")
    explanation = (knowledge.get("explanation") or "").strip()
    if explanation:
        # Cap explanation so we do not resend a huge wall
        cap = max(800, max_chars - sum(len(p) for p in parts) - 40)
        parts.append(f"Explanation:\n{explanation[:cap]}")
    text = "\n\n".join(parts).strip()
    return text[:max_chars]
