import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Structured visual payload from FastAPI (notes, Ask AI done event, revision).
class VisualPayloadData {
  final List<GraphDataItem> graphs;
  final List<TextDiagramData> textDiagrams;
  final List<TimelineItemData> timelines;
  final List<HierarchyNodeData> hierarchyTrees;
  final List<TextDiagramData> processFlows;
  final List<HighlightBoxData> highlightBoxes;
  final List<String> memoryTricks;
  final List<String> examTips;
  final List<String> examples;
  final String? cheatSheet;

  const VisualPayloadData({
    this.graphs = const [],
    this.textDiagrams = const [],
    this.timelines = const [],
    this.hierarchyTrees = const [],
    this.processFlows = const [],
    this.highlightBoxes = const [],
    this.memoryTricks = const [],
    this.examTips = const [],
    this.examples = const [],
    this.cheatSheet,
  });

  factory VisualPayloadData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VisualPayloadData();
    return VisualPayloadData(
      graphs: _list(json['graphs'])
          .map((e) => GraphDataItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      textDiagrams: _list(json['text_diagrams'] ?? json['textDiagrams'])
          .map((e) => TextDiagramData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      timelines: _list(json['timelines'])
          .map((e) => TimelineItemData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hierarchyTrees: _list(json['hierarchy_trees'] ?? json['hierarchyTrees'])
          .map((e) => HierarchyNodeData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      processFlows: _list(json['process_flows'] ?? json['processFlows'])
          .map((e) => TextDiagramData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      highlightBoxes: _list(json['highlight_boxes'] ?? json['highlightBoxes'])
          .map((e) => HighlightBoxData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      memoryTricks: _stringList(json['memory_tricks'] ?? json['memoryTricks']),
      examTips: _stringList(json['exam_tips'] ?? json['examTips']),
      examples: _stringList(json['examples']),
      cheatSheet: json['cheat_sheet']?.toString() ?? json['cheatSheet']?.toString(),
    );
  }

  bool get isEmpty =>
      graphs.isEmpty &&
      textDiagrams.isEmpty &&
      timelines.isEmpty &&
      hierarchyTrees.isEmpty &&
      processFlows.isEmpty &&
      highlightBoxes.isEmpty &&
      memoryTricks.isEmpty &&
      examTips.isEmpty &&
      examples.isEmpty &&
      (cheatSheet == null || cheatSheet!.trim().isEmpty);

  static List<dynamic> _list(dynamic raw) {
    if (raw is List) return raw;
    return const [];
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
}

class GraphDataItem {
  final String function;
  final List<double> xRange;
  final String? label;

  GraphDataItem({
    required this.function,
    required this.xRange,
    this.label,
  });

  factory GraphDataItem.fromJson(Map<String, dynamic> json) {
    final xr = json['x_range'] ?? json['xRange'];
    List<double> range = [-6, 6];
    if (xr is List && xr.length >= 2) {
      range = [
        (xr[0] as num).toDouble(),
        (xr[1] as num).toDouble(),
      ];
    }
    return GraphDataItem(
      function: json['function']?.toString() ?? '',
      xRange: range,
      label: json['label']?.toString(),
    );
  }
}

class TextDiagramData {
  final String? title;
  final String content;

  TextDiagramData({this.title, required this.content});

  factory TextDiagramData.fromJson(Map<String, dynamic> json) {
    return TextDiagramData(
      title: json['title']?.toString(),
      content: json['content']?.toString() ?? '',
    );
  }
}

class TimelineItemData {
  final String period;
  final String label;

  TimelineItemData({required this.period, required this.label});

  factory TimelineItemData.fromJson(Map<String, dynamic> json) {
    return TimelineItemData(
      period: json['period']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class HierarchyNodeData {
  final String label;
  final List<HierarchyNodeData> children;

  HierarchyNodeData({required this.label, required this.children});

  factory HierarchyNodeData.fromJson(Map<String, dynamic> json) {
    final raw = json['children'] as List? ?? [];
    return HierarchyNodeData(
      label: json['label']?.toString() ?? '',
      children: raw
          .whereType<Map>()
          .map((c) => HierarchyNodeData.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }
}

class HighlightBoxData {
  final String kind;
  final String content;

  HighlightBoxData({required this.kind, required this.content});

  factory HighlightBoxData.fromJson(Map<String, dynamic> json) {
    return HighlightBoxData(
      kind: json['kind']?.toString() ?? 'important',
      content: json['content']?.toString() ?? '',
    );
  }

  String get emoji {
    switch (kind) {
      case 'faq':
        return '⚠';
      case 'exam_favourite':
        return '🔥';
      case 'shortcut':
        return '💡';
      case 'memory_trick':
        return '🧠';
      default:
        return '⭐';
    }
  }
}

/// Renders markdown + LaTeX body and optional structured visual blocks.
class SmartEducationalContent extends StatelessWidget {
  final String markdownBody;
  final VisualPayloadData? visualPayload;
  final bool selectable;

  const SmartEducationalContent({
    super.key,
    required this.markdownBody,
    this.visualPayload,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (markdownBody.trim().isNotEmpty) {
      children.add(_MarkdownLatexBody(text: markdownBody, selectable: selectable));
    }

    final vp = visualPayload;
    if (vp != null && !vp.isEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      children.add(_VisualBlocks(payload: vp));
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _MarkdownLatexBody extends StatelessWidget {
  final String text;
  final bool selectable;

  const _MarkdownLatexBody({required this.text, required this.selectable});

  @override
  Widget build(BuildContext context) {
    final parts = _splitLatex(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part.isLatex) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Math.tex(
              part.content,
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        if (part.content.trim().isEmpty) return const SizedBox.shrink();
        return MarkdownBody(
          data: part.content,
          selectable: selectable,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        );
      }).toList(),
    );
  }

  static List<_TextPart> _splitLatex(String input) {
    final regex = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
    final parts = <_TextPart>[];
    var start = 0;
    for (final match in regex.allMatches(input)) {
      if (match.start > start) {
        parts.add(_TextPart(input.substring(start, match.start), false));
      }
      parts.add(_TextPart(match.group(1) ?? '', true));
      start = match.end;
    }
    if (start < input.length) {
      parts.add(_TextPart(input.substring(start), false));
    }
    if (parts.isEmpty) {
      parts.add(_TextPart(input, false));
    }
    return parts;
  }
}

class _TextPart {
  final String content;
  final bool isLatex;
  _TextPart(this.content, this.isLatex);
}

class _VisualBlocks extends StatelessWidget {
  final VisualPayloadData payload;

  const _VisualBlocks({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in payload.graphs) ...[
          _GraphChart(item: g),
          const SizedBox(height: 12),
        ],
        for (final d in payload.textDiagrams) ...[
          _TextDiagramCard(diagram: d),
          const SizedBox(height: 12),
        ],
        for (final f in payload.processFlows) ...[
          _TextDiagramCard(diagram: f, label: 'Process'),
          const SizedBox(height: 12),
        ],
        if (payload.timelines.isNotEmpty) ...[
          _TimelineList(items: payload.timelines),
          const SizedBox(height: 12),
        ],
        for (final tree in payload.hierarchyTrees) ...[
          _HierarchyTree(node: tree),
          const SizedBox(height: 12),
        ],
        for (final box in payload.highlightBoxes) ...[
          _HighlightCard(box: box),
          const SizedBox(height: 8),
        ],
        if (payload.memoryTricks.isNotEmpty) ...[
          _BulletSection(title: '💡 Memory Tricks', items: payload.memoryTricks),
          const SizedBox(height: 8),
        ],
        if (payload.examTips.isNotEmpty) ...[
          _BulletSection(title: '⚠ Exam Tips', items: payload.examTips),
          const SizedBox(height: 8),
        ],
        if (payload.examples.isNotEmpty) ...[
          _BulletSection(title: '📝 Examples', items: payload.examples),
          const SizedBox(height: 8),
        ],
        if (payload.cheatSheet != null && payload.cheatSheet!.trim().isNotEmpty) ...[
          _sectionLabel(context, 'CHEAT SHEET'),
          const SizedBox(height: 8),
          _MarkdownLatexBody(text: payload.cheatSheet!, selectable: true),
        ],
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _GraphChart extends StatelessWidget {
  final GraphDataItem item;

  const _GraphChart({required this.item});

  @override
  Widget build(BuildContext context) {
    final spots = _samplePoints(item.function, item.xRange[0], item.xRange[1]);
    if (spots.length < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.label != null && item.label!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item.label!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: true),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.accentColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<FlSpot> _samplePoints(String expr, double xMin, double xMax) {
    final fn = _parseExpression(expr);
    if (fn == null) return [];
    final spots = <FlSpot>[];
    const steps = 40;
    final step = (xMax - xMin) / steps;
    for (var i = 0; i <= steps; i++) {
      final x = xMin + step * i;
      final y = fn(x);
      if (y.isFinite) spots.add(FlSpot(x, y));
    }
    return spots;
  }

  static double Function(double)? _parseExpression(String raw) {
    final expr = _normalizeExpression(raw);
    if (expr.isEmpty) return null;
    try {
      final expression = GrammarParser().parse(expr);
      return (x) {
        try {
          final context = ContextModel()
            ..bindVariableName('x', Number(x));
          final value = RealEvaluator(context).evaluate(expression);
          return value.toDouble();
        } catch (_) {
          return double.nan;
        }
      };
    } catch (_) {
      return null;
    }
  }

  static String _normalizeExpression(String raw) {
    var expression = raw
        .trim()
        .toLowerCase()
        .replaceAll('−', '-')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll(RegExp(r'\s+'), '');
    if (expression.startsWith('y=')) {
      expression = expression.substring(2);
    }

    // Accept common AI notation such as 5x, 2(x+1), x(x-1), and )x.
    expression = expression.replaceAllMapped(
      RegExp(r'(\d|\))(?=x|\()'),
      (match) => '${match.group(1)}*',
    );
    expression = expression.replaceAllMapped(
      RegExp(r'(x|\))(?=\d|\()'),
      (match) => '${match.group(1)}*',
    );
    return expression;
  }
}

class _TextDiagramCard extends StatelessWidget {
  final TextDiagramData diagram;
  final String? label;

  const _TextDiagramCard({required this.diagram, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (diagram.title != null && diagram.title!.isNotEmpty)
            Text(
              diagram.title!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            )
          else if (label != null)
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          const SizedBox(height: 8),
          SelectableText(
            diagram.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  final List<TimelineItemData> items;

  const _TimelineList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Text(
            items[i].period.isNotEmpty ? items[i].period : items[i].label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (items[i].period.isNotEmpty && items[i].label.isNotEmpty)
            Text(items[i].label, style: Theme.of(context).textTheme.bodySmall),
          if (i < items.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('↓', style: Theme.of(context).textTheme.bodyLarge),
            ),
        ],
      ],
    );
  }
}

class _HierarchyTree extends StatelessWidget {
  final HierarchyNodeData node;
  final int depth;

  const _HierarchyTree({required this.node, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12.0 * depth, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            depth == 0 ? node.label : '├── ${node.label}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          for (final child in node.children)
            _HierarchyTree(node: child, depth: depth + 1),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final HighlightBoxData box;

  const _HighlightCard({required this.box});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.35)),
      ),
      child: Text('${box.emoji} ${box.content}'),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}
