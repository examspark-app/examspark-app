import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Structured visual payload from FastAPI (notes, Ask AI done event, revision).
class VisualPayloadData {
  final List<GraphDataItem> graphs;
  final List<ChartDataItem> barCharts;   // 👈 naya
  final List<ChartDataItem> pieCharts;   // 👈 naya
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
    this.barCharts = const [],           // 👈 naya
    this.pieCharts = const [],           // 👈 naya
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
    if (json == null || json['show_visual'] == false) {
      return const VisualPayloadData();
    }

    final rawGraphs = List<dynamic>.from(_list(json['graphs']));
    final rawTextDiagrams = List<dynamic>.from(_list(json['text_diagrams'] ?? json['textDiagrams']));

    if (json['data'] is Map) {
      final d = Map<String, dynamic>.from(json['data'] as Map);
      final vType = (json['visual_type'] ?? '').toString().toLowerCase();
      final title = (json['title'] ?? '').toString();

      if ((vType.contains('graph') || d.containsKey('equation')) && rawGraphs.isEmpty) {
        final eq = (d['equation'] ?? d['function'] ?? '').toString();
        if (eq.isNotEmpty) {
          final xr = d['x_range'] is List ? (d['x_range'] as List) : [-3.0, 3.0];
          rawGraphs.add({
            'function': eq,
            'x_range': xr.map((e) => (e as num).toDouble()).toList(),
            'label': title.isNotEmpty ? title : 'Graph',
          });
        }
      }

      if ((vType.contains('diagram') || vType.contains('motion') || vType.contains('circuit')) && rawTextDiagrams.isEmpty) {
        rawTextDiagrams.add({
          'title': title.isNotEmpty ? title : vType,
          'content': title,
        });
      }
    }

    return VisualPayloadData(
      graphs: rawGraphs
          .map((e) => GraphDataItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      barCharts: _list(json['bar_charts'] ?? json['barCharts'])       // 👈 naya
          .map((e) => ChartDataItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      pieCharts: _list(json['pie_charts'] ?? json['pieCharts'])       // 👈 naya
          .map((e) => ChartDataItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),    
      textDiagrams: rawTextDiagrams
          .map((e) => TextDiagramData.fromJson(Map<String, dynamic>.from(e as Map)))
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
      barCharts.isEmpty &&        // 👈 naya
      pieCharts.isEmpty &&        // 👈 naya
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

  // FIX: Ye function ab `[...]` string brackets ko hata kar proper list banayega
  static List<String> _stringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (raw is String) {
      String cleaned = raw.trim();
      if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        return cleaned.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
      }
      if (cleaned.isNotEmpty) return [cleaned];
    }
    return const [];
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
class ChartDataItem {
  final String? title;
  final List<ChartSlice> slices;

  ChartDataItem({this.title, required this.slices});

  factory ChartDataItem.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List? ?? [];
    return ChartDataItem(
      title: json['title']?.toString(),
      slices: raw
          .whereType<Map>()
          .map((e) => ChartSlice.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ChartSlice {
  final String label;
  final double value;

  ChartSlice({required this.label, required this.value});

  factory ChartSlice.fromJson(Map<String, dynamic> json) {
    return ChartSlice(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );
  }
}
class TextDiagramData {
  final String? title;
  final String content;

  TextDiagramData({this.title, required this.content});

  factory TextDiagramData.fromJson(Map<String, dynamic> json) {
    String rawContent = json['content']?.toString() ?? '';
    // Strip markdown code blocks just in case AI wraps text diagram in backticks
    rawContent = rawContent.replaceAll(RegExp(r'^```[\s\S]*?\n'), '').replaceAll(RegExp(r'```$'), '').trim();
    
    return TextDiagramData(
      title: json['title']?.toString(),
      content: rawContent,
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
    final accent = AppTheme.accentColor;
    final primary = AppTheme.getPrimaryText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part.isLatex) {
          // FIX: Added Horizontal Scroll + Math Rendering for robust Math UI
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Math.tex(
                part.content.trim(),
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: primary,
                ),
              ),
            ),
          );
        }
        if (part.content.trim().isEmpty) return const SizedBox.shrink();
        return MarkdownBody(
          data: part.content,
          selectable: selectable,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: primary,
                ),
            strong: TextStyle(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
            h1: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.5,
            ),
            h2: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.5,
            ),
            h3: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.5,
            ),
            h1Padding: const EdgeInsets.only(top: 12, bottom: 6),
            h2Padding: const EdgeInsets.only(top: 12, bottom: 4),
            h3Padding: const EdgeInsets.only(top: 10, bottom: 4),
            listBullet: TextStyle(color: primary),
            blockquoteDecoration: BoxDecoration(
              color: AppTheme.getAccentTint(context),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
          ),
        );
      }).toList(),
    );
  }

  // FIX: Updated Regex to handle both $$...$$ (Block) and $...$ (Inline) math formulas
  static List<_TextPart> _splitLatex(String input) {
    final regex = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$', dotAll: true);
    final parts = <_TextPart>[];
    var start = 0;
    
    for (final match in regex.allMatches(input)) {
      if (match.start > start) {
        parts.add(_TextPart(input.substring(start, match.start), false));
      }
      final latexContent = match.group(1) ?? match.group(2) ?? '';
      parts.add(_TextPart(latexContent, true));
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
        for (final b in payload.barCharts) ...[      // 👈 naya
          _BarChartCard(item: b),
          const SizedBox(height: 12),
        ],
        for (final p in payload.pieCharts) ...[       // 👈 naya
          _PieChartCard(item: p),
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
          _BulletSection(title: 'Memory Tricks', icon: Icons.psychology, items: payload.memoryTricks),
          const SizedBox(height: 8),
        ],
        if (payload.examTips.isNotEmpty) ...[
          _BulletSection(title: 'Exam Tips', icon: Icons.lightbulb_outline, items: payload.examTips),
          const SizedBox(height: 8),
        ],
        if (payload.examples.isNotEmpty) ...[
          _BulletSection(title: 'Examples', icon: Icons.edit_note, items: payload.examples),
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
class _BarChartCard extends StatelessWidget {
  final ChartDataItem item;
  const _BarChartCard({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.slices.isEmpty) return const SizedBox.shrink();
    final maxY = item.slices.map((s) => s.value).reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxY > 0 ? maxY * 1.2 : 10.0;

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
          if (item.title != null && item.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item.title!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= item.slices.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            item.slices[i].label,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < item.slices.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: item.slices[i].value,
                          color: AppTheme.accentColor,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartCard extends StatelessWidget {
  final ChartDataItem item;
  const _PieChartCard({required this.item});

  static const _palette = [
    Color(0xFF7C4DFF),
    Color(0xFF00BFA5),
    Color(0xFFFF6D00),
    Color(0xFF2979FF),
    Color(0xFFD500F9),
    Color(0xFFFFAB00),
  ];

  @override
  Widget build(BuildContext context) {
    if (item.slices.isEmpty) return const SizedBox.shrink();
    final total = item.slices.fold<double>(0, (sum, s) => sum + s.value);

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
          if (item.title != null && item.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item.title!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sections: [
                      for (var i = 0; i < item.slices.length; i++)
                        PieChartSectionData(
                          value: item.slices[i].value,
                          color: _palette[i % _palette.length],
                          title: total > 0
                              ? '${(item.slices[i].value / total * 100).round()}%'
                              : '',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < item.slices.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.slices[i].label,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _TextDiagramCard extends StatelessWidget {
  final TextDiagramData diagram;
  final String? label;

  const _TextDiagramCard({required this.diagram, this.label});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                _dot(const Color(0xFFFF5F56)),
                const SizedBox(width: 6),
                _dot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 6),
                _dot(const Color(0xFF27C93F)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (diagram.title != null && diagram.title!.isNotEmpty)
                        ? diagram.title!
                        : (label ?? 'Diagram'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if ((diagram.title ?? '').toLowerCase().contains('free-body') ||
              (diagram.title ?? '').toLowerCase().contains('f = ma') ||
              (diagram.title ?? '').toLowerCase().contains('force diagram')) ...[
            Container(
              height: 175,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF141414),
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: CustomPaint(
                painter: _FreeBodyDiagramPainter(isDark: true),
              ),
            ),
          ] else if ((diagram.title ?? '').toLowerCase().contains('projectile') ||
              (diagram.title ?? '').toLowerCase().contains('trajectory') ||
              (diagram.title ?? '').toLowerCase().contains('velocity')) ...[
            Container(
              height: 185,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF141414),
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: CustomPaint(
                painter: _ProjectileTrajectoryPainter(isDark: true),
              ),
            ),
          ] else if ((diagram.title ?? '').toLowerCase().contains('gravity') ||
              (diagram.title ?? '').toLowerCase().contains('gravitation')) ...[
            Container(
              height: 185,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF141414),
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: CustomPaint(
                painter: _GravityDiagramPainter(isDark: true),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              diagram.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFE5E5E5),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _FreeBodyDiagramPainter extends CustomPainter {
  final bool isDark;
  _FreeBodyDiagramPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final lineColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
    const surfaceColor = Color(0xFF3B82F6);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final blockPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;

    final blockBorderPaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black87
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final surfacePaint = Paint()
      ..color = surfaceColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2 + 10;
    const blockW = 60.0;
    const blockH = 46.0;
    final blockRect = Rect.fromCenter(center: Offset(cx, cy), width: blockW, height: blockH);

    final surfaceY = blockRect.bottom;
    canvas.drawLine(Offset(cx - 95, surfaceY), Offset(cx + 95, surfaceY), surfacePaint);

    canvas.drawRect(blockRect, blockPaint);
    canvas.drawRect(blockRect, blockBorderPaint);

    _drawText(canvas, 'm', Offset(cx, cy), textColor, 16, FontWeight.bold);

    _drawArrow(canvas, Offset(cx, blockRect.top), Offset(cx, blockRect.top - 40), linePaint);
    _drawText(canvas, 'N', Offset(cx + 12, blockRect.top - 30), textColor, 13, FontWeight.w600);

    _drawArrow(canvas, Offset(cx, blockRect.bottom), Offset(cx, blockRect.bottom + 40), linePaint);
    _drawText(canvas, 'mg', Offset(cx + 14, blockRect.bottom + 30), textColor, 13, FontWeight.w600);

    _drawArrow(canvas, Offset(blockRect.right, cy), Offset(blockRect.right + 50, cy), linePaint);
    _drawText(canvas, 'F', Offset(blockRect.right + 36, cy - 14), textColor, 13, FontWeight.w600);

    final aY = blockRect.top - 18;
    _drawArrow(canvas, Offset(cx, aY), Offset(cx + 42, aY), linePaint);
    _drawText(canvas, 'a', Offset(cx + 22, aY - 14), textColor, 13, FontWeight.w600);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);
    final angle = (to - from).direction;
    const arrowSize = 6.0;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - arrowSize * math.cos(angle - 0.5), to.dy - arrowSize * math.sin(angle - 0.5))
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - arrowSize * math.cos(angle + 0.5), to.dy - arrowSize * math.sin(angle + 0.5));
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color, double fontSize, FontWeight weight) {
    final span = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight));
    final painter = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    painter.layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProjectileTrajectoryPainter extends CustomPainter {
  final bool isDark;
  _ProjectileTrajectoryPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final axisColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    const curveColor = Color(0xFF38BDF8);
    const vectorColor = Color(0xFFF59E0B);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final curvePaint = Paint()
      ..color = curveColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final vectorPaint = Paint()
      ..color = vectorColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = isDark ? Colors.white38 : Colors.black26
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const originX = 40.0;
    final originY = size.height - 35.0;
    final endX = size.width - 40.0;
    final peakX = (originX + endX) / 2;
    final peakY = originY - 95.0;

    // Y Axis (Height)
    canvas.drawLine(Offset(originX, originY + 10), const Offset(originX, 20), axisPaint);
    _drawArrowHead(canvas, const Offset(originX, 20), -math.pi / 2, axisPaint);
    _drawText(canvas, 'Height (y)', const Offset(originX + 34, 16), textColor, 11.5, FontWeight.w600);

    // X Axis (Range)
    canvas.drawLine(Offset(originX - 10, originY), Offset(size.width - 15, originY), axisPaint);
    _drawArrowHead(canvas, Offset(size.width - 15, originY), 0, axisPaint);
    _drawText(canvas, 'Range (x)', Offset(size.width - 35, originY + 16), textColor, 11.5, FontWeight.w600);

    // Parabolic trajectory
    final path = Path()
      ..moveTo(originX, originY)
      ..quadraticBezierTo(peakX, peakY - 15, endX, originY);
    canvas.drawPath(path, curvePaint);

    // Initial velocity vector v0
    final v0End = Offset(originX + 48, originY - 48);
    canvas.drawLine(Offset(originX, originY), v0End, vectorPaint);
    _drawArrowHead(canvas, v0End, -math.pi / 4, vectorPaint);
    _drawText(canvas, 'v₀', Offset(v0End.dx + 6, v0End.dy - 6), vectorColor, 13, FontWeight.bold);

    // Angle theta arc
    final arcRect = Rect.fromCircle(center: Offset(originX, originY), radius: 20);
    canvas.drawArc(arcRect, -math.pi / 4, math.pi / 4, false, axisPaint);
    _drawText(canvas, 'θ', Offset(originX + 24, originY - 10), textColor, 11, FontWeight.w600);

    // Peak dot and label
    final dotPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(Offset(peakX, peakY), 4.5, dotPaint);
    _drawText(canvas, 'Peak (vy = 0)', Offset(peakX, peakY - 14), textColor, 11.5, FontWeight.bold);

    // Dashed line from peak to ground (Hmax)
    for (double y = peakY; y < originY; y += 8) {
      canvas.drawLine(Offset(peakX, y), Offset(peakX, math.min(y + 4, originY)), dashPaint);
    }
    _drawText(canvas, 'H_max', Offset(peakX - 22, (peakY + originY) / 2), textColor, 10.5, FontWeight.w500);

    // Landing dot
    canvas.drawCircle(Offset(endX, originY), 4.0, dotPaint);
    _drawText(canvas, 'Landing', Offset(endX, originY + 16), textColor, 11, FontWeight.w600);
  }

  void _drawArrowHead(Canvas canvas, Offset to, double angle, Paint paint) {
    const arrowSize = 6.0;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - arrowSize * math.cos(angle - 0.5), to.dy - arrowSize * math.sin(angle - 0.5))
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - arrowSize * math.cos(angle + 0.5), to.dy - arrowSize * math.sin(angle + 0.5));
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color, double fontSize, FontWeight weight) {
    final span = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight));
    final painter = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    painter.layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GravityDiagramPainter extends CustomPainter {
  final bool isDark;
  _GravityDiagramPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    const m1Color = Color(0xFF3B82F6);
    const m2Color = Color(0xFF10B981);
    const forceColor = Color(0xFFF59E0B);
    final lineColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final forcePaint = Paint()
      ..color = forceColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final cy = size.height / 2 - 4;
    final m1Center = Offset(size.width * 0.25, cy);
    final m2Center = Offset(size.width * 0.75, cy);
    const m1Radius = 26.0;
    const m2Radius = 18.0;

    final m1Paint = Paint()..color = m1Color..style = PaintingStyle.fill;
    final m2Paint = Paint()..color = m2Color..style = PaintingStyle.fill;
    canvas.drawCircle(m1Center, m1Radius, m1Paint);
    canvas.drawCircle(m2Center, m2Radius, m2Paint);

    final borderPaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black87
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(m1Center, m1Radius, borderPaint);
    canvas.drawCircle(m2Center, m2Radius, borderPaint);

    _drawText(canvas, 'm₁', m1Center, Colors.white, 14, FontWeight.bold);
    _drawText(canvas, 'm₂', m2Center, Colors.white, 13, FontWeight.bold);

    final dLineY = cy + 42.0;
    canvas.drawLine(Offset(m1Center.dx, cy + m1Radius + 4), Offset(m1Center.dx, dLineY + 6), linePaint);
    canvas.drawLine(Offset(m2Center.dx, cy + m2Radius + 4), Offset(m2Center.dx, dLineY + 6), linePaint);
    canvas.drawLine(Offset(m1Center.dx, dLineY), Offset(m2Center.dx, dLineY), linePaint);

    _drawArrowHead(canvas, Offset(m1Center.dx, dLineY), math.pi, linePaint);
    _drawArrowHead(canvas, Offset(m2Center.dx, dLineY), 0, linePaint);
    _drawText(canvas, 'Distance (r)', Offset((m1Center.dx + m2Center.dx) / 2, dLineY + 14), textColor, 11.5, FontWeight.w600);

    final f1Start = Offset(m1Center.dx + m1Radius + 4, cy);
    final f1End = Offset(m1Center.dx + m1Radius + 38, cy);
    canvas.drawLine(f1Start, f1End, forcePaint);
    _drawArrowHead(canvas, f1End, 0, forcePaint);
    _drawText(canvas, 'F_grav →', Offset((f1Start.dx + f1End.dx) / 2, cy - 14), forceColor, 12, FontWeight.bold);

    final f2Start = Offset(m2Center.dx - m2Radius - 4, cy);
    final f2End = Offset(m2Center.dx - m2Radius - 38, cy);
    canvas.drawLine(f2Start, f2End, forcePaint);
    _drawArrowHead(canvas, f2End, math.pi, forcePaint);
    _drawText(canvas, '← F_grav', Offset((f2Start.dx + f2End.dx) / 2, cy - 14), forceColor, 12, FontWeight.bold);

    _drawText(canvas, 'F = G · (m₁ · m₂) / r²', Offset(size.width / 2, 16), textColor, 13, FontWeight.bold);
  }

  void _drawArrowHead(Canvas canvas, Offset to, double angle, Paint paint) {
    const arrowSize = 6.0;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - arrowSize * math.cos(angle - 0.5), to.dy - arrowSize * math.sin(angle - 0.5))
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - arrowSize * math.cos(angle + 0.5), to.dy - arrowSize * math.sin(angle + 0.5));
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color, double fontSize, FontWeight weight) {
    final span = TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight));
    final painter = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    painter.layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

// FIX: Pura _BulletSection ek clean aur professional Card Layout mein convert kar diya
class _BulletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _BulletSection({
    required this.title, 
    required this.icon, 
    required this.items
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.accentColor),
              const SizedBox(width: 6),
              Text(
                title, 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentColor,
                )
              ),
            ],
          ),
        ),
        for (final item in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getCardBackground(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4, right: 8),
                  child: Icon(Icons.circle, size: 6, color: Colors.grey),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}