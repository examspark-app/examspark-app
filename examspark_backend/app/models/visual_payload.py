"""Structured visual educational content — Smart Visual Notes Engine (Phase 5).

Stored in Supabase JSONB (`notes.visual_payload_json`, extras, Ask AI done events).
Rendered client-side: markdown, LaTeX, graphs, text diagrams, and AI whiteboards.

Backward compatible with the existing visual payload schema.
"""

from __future__ import annotations

from typing import Any, Literal, Optional

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
    x_range: list[float] = Field(
        default_factory=lambda: [-6.0, 6.0]
    )
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
    children: list[HierarchyNode] = Field(
        default_factory=list
    )


class HighlightBox(BaseModel):
    kind: HighlightKind = "important"
    content: str = ""


class ChartSlice(BaseModel):
    label: str = ""
    value: float = 0.0


class ChartItem(BaseModel):
    title: Optional[str] = None
    data: list[ChartSlice] = Field(
        default_factory=list
    )


# ---------------------------------------------------------------------------
# AI WHITEBOARD
# ---------------------------------------------------------------------------

class WhiteboardElement(BaseModel):
    """One drawable element on the AI-generated educational whiteboard."""

    type: str = "text"

    # Position
    x: float = 0.0
    y: float = 0.0

    # Optional size
    width: Optional[float] = None
    height: Optional[float] = None

    # Generic text content
    text: Optional[str] = None
    content: Optional[str] = None
    label: Optional[str] = None

    # Line / arrow coordinates
    x1: Optional[float] = None
    y1: Optional[float] = None
    x2: Optional[float] = None
    y2: Optional[float] = None

    # Circle
    radius: Optional[float] = None

    # Drawing properties
    color: Optional[str] = None
    fill: Optional[str] = None
    stroke: Optional[str] = None

    font_size: Optional[float] = None
    line_width: Optional[float] = None

    # Optional point collection for custom shapes / polygons.
    points: list[dict[str, Any]] = Field(
        default_factory=list
    )

    # Future-compatible custom properties.
    # Unknown AI properties can be preserved here when needed.
    extra: dict[str, Any] = Field(
        default_factory=dict
    )


class WhiteboardData(BaseModel):
    """Complete AI-generated whiteboard scene."""

    title: Optional[str] = None

    # Canvas size used by the Flutter renderer.
    width: float = 1000.0
    height: float = 700.0

    background: Optional[str] = None

    elements: list[WhiteboardElement] = Field(
        default_factory=list
    )


class VisualPayload(BaseModel):
    """Structured visual payload returned by Ask AI."""

    # New dynamic whiteboard renderer.
    whiteboard: Optional[WhiteboardData] = None

    # Existing visual systems.
    graphs: list[GraphDataItem] = Field(
        default_factory=list
    )
    bar_charts: list[ChartItem] = Field(
        default_factory=list
    )
    pie_charts: list[ChartItem] = Field(
        default_factory=list
    )
    text_diagrams: list[TextDiagram] = Field(
        default_factory=list
    )
    timelines: list[TimelineItem] = Field(
        default_factory=list
    )
    hierarchy_trees: list[HierarchyNode] = Field(
        default_factory=list
    )
    process_flows: list[TextDiagram] = Field(
        default_factory=list
    )
    highlight_boxes: list[HighlightBox] = Field(
        default_factory=list
    )
    memory_tricks: list[str] = Field(
        default_factory=list
    )
    exam_tips: list[str] = Field(
        default_factory=list
    )
    examples: list[str] = Field(
        default_factory=list
    )
    cheat_sheet: Optional[str] = None


HierarchyNode.model_rebuild()


def parse_visual_payload(
    raw: dict | None,
) -> VisualPayload | None:
    """Best-effort parse from AI JSON or DB row.

    Returns None when the payload is missing, invalid, or empty.
    """

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
    """Accept legacy schema, camelCase keys, and newer contract schemas."""

    if raw.get("show_visual") is False:
        return {}

    out = dict(raw)

    # -----------------------------------------------------------------------
    # camelCase -> snake_case
    # -----------------------------------------------------------------------

    pairs = [
        ("textDiagrams", "text_diagrams"),
        ("hierarchyTrees", "hierarchy_trees"),
        ("processFlows", "process_flows"),
        ("highlightBoxes", "highlight_boxes"),
        ("memoryTricks", "memory_tricks"),
        ("examTips", "exam_tips"),
        ("cheatSheet", "cheat_sheet"),
        ("barCharts", "bar_charts"),
        ("pieCharts", "pie_charts"),
        ("whiteBoard", "whiteboard"),
        ("whiteBoardData", "whiteboard"),
    ]

    for camel, snake in pairs:
        if camel in out and snake not in out:
            out[snake] = out.pop(camel)

    # -----------------------------------------------------------------------
    # Support generic contract:
    #
    # {
    #   "show_visual": true,
    #   "visual_type": "...",
    #   "data": {...}
    # }
    # -----------------------------------------------------------------------

    data = out.get("data")

    if isinstance(data, dict):
        v_type = str(
            out.get("visual_type") or ""
        ).lower()

        title = out.get("title") or v_type.replace(
            "_",
            " ",
        ).title()

        # -------------------------------------------------------------------
        # Graph conversion
        # -------------------------------------------------------------------

        if (
            "graph" in v_type
            or "equation" in data
            or "function" in data
        ) and "graphs" not in out:
            eq = (
                data.get("equation")
                or data.get("function")
                or ""
            )

            if eq:
                xr = data.get("x_range") or [
                    -3.0,
                    3.0,
                ]

                if (
                    isinstance(xr, (list, tuple))
                    and len(xr) >= 2
                ):
                    try:
                        x_start = float(xr[0])
                        x_end = float(xr[1])
                    except (TypeError, ValueError):
                        x_start = -3.0
                        x_end = 3.0
                else:
                    x_start = -3.0
                    x_end = 3.0

                out["graphs"] = [
                    {
                        "function": str(eq),
                        "x_range": [
                            x_start,
                            x_end,
                        ],
                        "label": title,
                    }
                ]

        # -------------------------------------------------------------------
        # Diagram / motion / circuit conversion
        # -------------------------------------------------------------------

        if (
            "diagram" in v_type
            or "motion" in v_type
            or "circuit" in v_type
        ) and "text_diagrams" not in out:
            lines: list[str] = []

            formulas = data.get("formulas") or []

            if isinstance(formulas, list):
                for formula in formulas:
                    lines.append(
                        f"Formula: {formula}"
                    )

            forces = (
                data.get("forces")
                or data.get("arrows")
                or []
            )

            if isinstance(forces, list):
                for force in forces:
                    if isinstance(force, dict):
                        lbl = (
                            force.get("label")
                            or force.get("name")
                            or ""
                        )
                        dir_str = (
                            force.get("direction")
                            or ""
                        )

                        description = (
                            f"• {lbl} ({dir_str})"
                            .strip()
                        )

                        if description != "• ()":
                            lines.append(
                                description
                            )

                    elif force is not None:
                        lines.append(
                            f"• {force}"
                        )

            content = (
                "\n".join(lines)
                if lines
                else title
            )

            out["text_diagrams"] = [
                {
                    "title": title,
                    "content": content,
                }
            ]

    # -----------------------------------------------------------------------
    # Whiteboard normalization
    #
    # Supports:
    #   "whiteboard": {...}
    #
    # Also supports:
    #   "whiteboard": {
    #       "elements": [...]
    #   }
    #
    # And a couple of common AI aliases.
    # -----------------------------------------------------------------------

    whiteboard = out.get("whiteboard")

    if isinstance(whiteboard, dict):
        normalized_whiteboard = dict(
            whiteboard
        )

        # CamelCase compatibility.
        if (
            "backgroundColor"
            in normalized_whiteboard
            and "background"
            not in normalized_whiteboard
        ):
            normalized_whiteboard["background"] = (
                normalized_whiteboard.pop(
                    "backgroundColor"
                )
            )

        if (
            "board_width"
            in normalized_whiteboard
            and "width"
            not in normalized_whiteboard
        ):
            normalized_whiteboard["width"] = (
                normalized_whiteboard.pop(
                    "board_width"
                )
            )

        if (
            "board_height"
            in normalized_whiteboard
            and "height"
            not in normalized_whiteboard
        ):
            normalized_whiteboard["height"] = (
                normalized_whiteboard.pop(
                    "board_height"
                )
            )

        elements = normalized_whiteboard.get(
            "elements"
        )

        if isinstance(elements, list):
            normalized_elements: list[dict] = []

            for element in elements:
                if not isinstance(element, dict):
                    continue

                item = dict(element)

                # -----------------------------------------------------------
                # Common aliases
                # -----------------------------------------------------------

                if (
                    "fontSize"
                    in item
                    and "font_size"
                    not in item
                ):
                    item["font_size"] = item.pop(
                        "fontSize"
                    )

                if (
                    "lineWidth"
                    in item
                    and "line_width"
                    not in item
                ):
                    item["line_width"] = item.pop(
                        "lineWidth"
                    )

                if (
                    "backgroundColor"
                    in item
                    and "fill"
                    not in item
                ):
                    item["fill"] = item.pop(
                        "backgroundColor"
                    )

                if (
                    "borderColor"
                    in item
                    and "stroke"
                    not in item
                ):
                    item["stroke"] = item.pop(
                        "borderColor"
                    )

                if (
                    "radiusPx"
                    in item
                    and "radius"
                    not in item
                ):
                    item["radius"] = item.pop(
                        "radiusPx"
                    )

                # -----------------------------------------------------------
                # Preserve unknown properties instead of failing validation.
                # -----------------------------------------------------------

                known_keys = {
                    "type",
                    "x",
                    "y",
                    "width",
                    "height",
                    "text",
                    "content",
                    "label",
                    "x1",
                    "y1",
                    "x2",
                    "y2",
                    "radius",
                    "color",
                    "fill",
                    "stroke",
                    "font_size",
                    "line_width",
                    "points",
                    "extra",
                }

                extra = item.get("extra")

                if not isinstance(extra, dict):
                    extra = {}

                for key in list(item.keys()):
                    if key not in known_keys:
                        extra[key] = item[key]
                        item.pop(key, None)

                item["extra"] = extra

                normalized_elements.append(item)

            normalized_whiteboard[
                "elements"
            ] = normalized_elements

        out["whiteboard"] = normalized_whiteboard

    return out


def payload_has_content(
    payload: VisualPayload,
) -> bool:
    """Return True when at least one visual section has content."""

    return bool(
        (
            payload.whiteboard is not None
            and bool(payload.whiteboard.elements)
        )
        or payload.graphs
        or payload.bar_charts
        or payload.pie_charts
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


def visual_payload_to_plain_text(
    payload: VisualPayload | None,
) -> str:
    """Flatten visuals for RAG embedding — never embed raw JSON."""

    if payload is None:
        return ""

    parts: list[str] = []

    # -----------------------------------------------------------------------
    # Whiteboard
    # -----------------------------------------------------------------------

    if payload.whiteboard:
        wb = payload.whiteboard

        if wb.title and wb.title.strip():
            parts.append(
                f"Whiteboard: {wb.title.strip()}"
            )

        for element in wb.elements:
            text = (
                element.text
                or element.content
                or element.label
                or ""
            ).strip()

            if text:
                parts.append(
                    f"Whiteboard element: {text}"
                )

    # -----------------------------------------------------------------------
    # Graphs
    # -----------------------------------------------------------------------

    for graph in payload.graphs:
        label = graph.label or graph.function

        if label:
            parts.append(
                f"Graph: {label}"
            )

    # -----------------------------------------------------------------------
    # Bar + pie charts
    # -----------------------------------------------------------------------

    for chart in (
        payload.bar_charts
        + payload.pie_charts
    ):
        if chart.title or chart.data:
            values = ", ".join(
                f"{item.label}: {item.value}"
                for item in chart.data
            )

            parts.append(
                f"Chart {chart.title or ''}: {values}"
                .strip()
            )

    # -----------------------------------------------------------------------
    # Text diagrams + process flows
    # -----------------------------------------------------------------------

    for diagram in (
        payload.text_diagrams
        + payload.process_flows
    ):
        title = diagram.title or "Diagram"

        if diagram.content.strip():
            parts.append(
                f"{title}:\n"
                f"{diagram.content.strip()}"
            )

    # -----------------------------------------------------------------------
    # Timelines
    # -----------------------------------------------------------------------

    for timeline in payload.timelines:
        if timeline.period or timeline.label:
            parts.append(
                f"Timeline {timeline.period}: "
                f"{timeline.label}"
            )

    # -----------------------------------------------------------------------
    # Hierarchy
    # -----------------------------------------------------------------------

    for tree in payload.hierarchy_trees:
        parts.append(
            _tree_to_text(
                tree,
                depth=0,
            )
        )

    # -----------------------------------------------------------------------
    # Highlight boxes
    # -----------------------------------------------------------------------

    for box in payload.highlight_boxes:
        parts.append(
            f"{box.kind}: {box.content}"
        )

    # -----------------------------------------------------------------------
    # Memory tricks
    # -----------------------------------------------------------------------

    for trick in payload.memory_tricks:
        parts.append(
            f"Memory trick: {trick}"
        )

    # -----------------------------------------------------------------------
    # Exam tips
    # -----------------------------------------------------------------------

    for tip in payload.exam_tips:
        parts.append(
            f"Exam tip: {tip}"
        )

    # -----------------------------------------------------------------------
    # Examples
    # -----------------------------------------------------------------------

    for example in payload.examples:
        parts.append(
            f"Example: {example}"
        )

    # -----------------------------------------------------------------------
    # Cheat sheet
    # -----------------------------------------------------------------------

    if (
        payload.cheat_sheet
        and payload.cheat_sheet.strip()
    ):
        parts.append(
            "Cheat sheet:\n"
            f"{payload.cheat_sheet.strip()}"
        )

    return "\n\n".join(
        part
        for part in parts
        if part.strip()
    )


def _tree_to_text(
    node: HierarchyNode,
    depth: int,
) -> str:
    """Flatten hierarchy recursively into readable text."""

    indent = "  " * depth

    lines = [
        f"{indent}- {node.label}"
    ]

    for child in node.children:
        lines.append(
            _tree_to_text(
                child,
                depth + 1,
            )
        )

    return "\n".join(lines)