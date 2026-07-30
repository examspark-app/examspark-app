"""Structured visual educational content — Smart Visual Notes Engine (Phase 5).

Stored in Supabase JSONB (`notes.visual_payload_json`, extras, Ask AI done events).
Rendered client-side: markdown, LaTeX, graphs, text diagrams — no image generation.
"""
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field

HighlightKind = Literal[
    "important",
    "faq",
    "exam_favourite",
    "shortcut",
    "memory_trick",
]


class GraphDataItem(BaseModel):
    function: str = ""
    x_range: list[float] = Field(default_factory=lambda: [-6.0, 6.0])
    y_range: Optional[list[float]] = None
    label: Optional[str] = None


class TextDiagram(BaseModel):
    title: Optional[str] = None
    content: str = ""


class TimelineItem(BaseModel):
    period: str = ""
    label: str = ""


class HierarchyNode(BaseModel):
    label: str = ""
    children: list[HierarchyNode] = Field(default_factory=list)


class HighlightBox(BaseModel):
    kind: HighlightKind = "important"
    content: str = ""


class VisualPayload(BaseModel):
    graphs: list[GraphDataItem] = Field(default_factory=list)
    text_diagrams: list[TextDiagram] = Field(default_factory=list)
    timelines: list[TimelineItem] = Field(default_factory=list)
    hierarchy_trees: list[HierarchyNode] = Field(default_factory=list)
    process_flows: list[TextDiagram] = Field(default_factory=list)
    highlight_boxes: list[HighlightBox] = Field(default_factory=list)
    memory_tricks: list[str] = Field(default_factory=list)
    exam_tips: list[str] = Field(default_factory=list)
    examples: list[str] = Field(default_factory=list)
    cheat_sheet: Optional[str] = None


HierarchyNode.model_rebuild()


def parse_visual_payload(raw: dict | None) -> VisualPayload | None:
    """Best-effort parse from AI JSON or DB row; returns None if empty/invalid."""
    if not raw or not isinstance(raw, dict):
        return None
    normalized = _normalize_visual_dict(raw)
    try:
        payload = VisualPayload.model_validate(normalized)
    except Exception:  # noqa: BLE001
        return None
    if not payload_has_content(payload):
        return None
    return payload


def _normalize_visual_dict(raw: dict) -> dict:
    """Accept camelCase keys from Qwen JSON."""
    out = dict(raw)
    pairs = [
        ("textDiagrams", "text_diagrams"),
        ("hierarchyTrees", "hierarchy_trees"),
        ("processFlows", "process_flows"),
        ("highlightBoxes", "highlight_boxes"),
        ("memoryTricks", "memory_tricks"),
        ("examTips", "exam_tips"),
        ("cheatSheet", "cheat_sheet"),
    ]
    for camel, snake in pairs:
        if camel in out and snake not in out:
            out[snake] = out.pop(camel)
    return out


def payload_has_content(payload: VisualPayload) -> bool:
    return bool(
        payload.graphs
        or payload.text_diagrams
        or payload.timelines
        or payload.hierarchy_trees
        or payload.process_flows
        or payload.highlight_boxes
        or payload.memory_tricks
        or payload.exam_tips
        or payload.examples
        or (payload.cheat_sheet or "").strip()
    )


def visual_payload_to_plain_text(payload: VisualPayload | None) -> str:
    """Flatten visuals for RAG embedding — never embed raw JSON."""
    if payload is None:
        return ""
    parts: list[str] = []
    for g in payload.graphs:
        label = g.label or g.function
        if label:
            parts.append(f"Graph: {label}")
    for d in payload.text_diagrams + payload.process_flows:
        title = d.title or "Diagram"
        if d.content.strip():
            parts.append(f"{title}:\n{d.content.strip()}")
    for t in payload.timelines:
        if t.period or t.label:
            parts.append(f"Timeline {t.period}: {t.label}")
    for tree in payload.hierarchy_trees:
        parts.append(_tree_to_text(tree, depth=0))
    for box in payload.highlight_boxes:
        parts.append(f"{box.kind}: {box.content}")
    for trick in payload.memory_tricks:
        parts.append(f"Memory trick: {trick}")
    for tip in payload.exam_tips:
        parts.append(f"Exam tip: {tip}")
    for ex in payload.examples:
        parts.append(f"Example: {ex}")
    if payload.cheat_sheet and payload.cheat_sheet.strip():
        parts.append(f"Cheat sheet:\n{payload.cheat_sheet.strip()}")
    return "\n\n".join(p for p in parts if p.strip())


def _tree_to_text(node: HierarchyNode, depth: int) -> str:
    indent = "  " * depth
    lines = [f"{indent}- {node.label}"]
    for child in node.children:
        lines.append(_tree_to_text(child, depth + 1))
    return "\n".join(lines)
