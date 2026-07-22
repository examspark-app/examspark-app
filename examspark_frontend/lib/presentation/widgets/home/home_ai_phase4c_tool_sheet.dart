import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Phase 4C — open a study tool from response_id (no full-answer paste).
Future<void> showHomeAiPhase4cToolSheet(
  BuildContext context, {
  required String responseId,
  required String toolType,
  required String title,
  bool regenerate = false,
  void Function(int newBalance)? onCreditsUpdated,
  VoidCallback? onGenerated,
}) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return _Phase4cToolBody(
            responseId: responseId,
            toolType: toolType,
            title: title,
            regenerate: regenerate,
            scrollController: scrollController,
            onCreditsUpdated: onCreditsUpdated,
            onGenerated: onGenerated,
          );
        },
      );
    },
  );
}

class _Phase4cToolBody extends StatefulWidget {
  final String responseId;
  final String toolType;
  final String title;
  final bool regenerate;
  final ScrollController scrollController;
  final void Function(int newBalance)? onCreditsUpdated;
  final VoidCallback? onGenerated;

  const _Phase4cToolBody({
    required this.responseId,
    required this.toolType,
    required this.title,
    required this.regenerate,
    required this.scrollController,
    required this.onCreditsUpdated,
    required this.onGenerated,
  });

  @override
  State<_Phase4cToolBody> createState() => _Phase4cToolBodyState();
}

class _Phase4cToolBodyState extends State<_Phase4cToolBody> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    _run(regenerate: widget.regenerate);
  }

  Future<void> _run({required bool regenerate}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await LectureService.instance.homeAiGenerateTool(
        responseId: widget.responseId,
        toolType: widget.toolType,
        regenerate: regenerate,
      );
      if (!mounted) return;
      // If another request is generating, poll once after short wait
      if (result['status'] == 'generating') {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        final again = await LectureService.instance.homeAiGenerateTool(
          responseId: widget.responseId,
          toolType: widget.toolType,
          regenerate: false,
        );
        if (!mounted) return;
        _applyResult(again);
        return;
      }
      _applyResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyResult(Map<String, dynamic> result) {
    setState(() {
      _result = result;
      _cached = result['cached'] == true;
      _loading = false;
    });
    final balance = result['new_balance'];
    if (balance is int) {
      widget.onCreditsUpdated?.call(balance);
    }
    if (result['status'] == 'generated') {
      widget.onGenerated?.call();
    }
  }

  Map<String, dynamic>? get _payload {
    final p = _result?['payload'];
    if (p is Map) return Map<String, dynamic>.from(p);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                    if (_cached)
                      Text(
                        'Cached · free reopen',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                            ),
                      )
                    else if (_result?['derived'] == true)
                      Text(
                        'Free · from this answer (not a new AI write)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                            ),
                      )
                    else if (_result != null &&
                        (_result!['credits_charged'] is int) &&
                        (_result!['credits_charged'] as int) > 0)
                      Text(
                        'AI regenerated · credits charged',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                            ),
                      ),
                    if (!_loading && _error == null && _result?['derived'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Want a fresh AI version? Tap Regenerate (uses credits).',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_loading && _error == null)
                TextButton(
                  onPressed: () => _run(regenerate: true),
                  child: const Text('Regenerate'),
                ),              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Text(_error!, style: TextStyle(color: Colors.red.shade700))
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildPayload(context, _payload ?? const {}),
            ],
          ),
        ),
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                const Spacer(),
                if (_result?['credits_charged'] is int)
                  Text(
                    _cached
                        ? '0 credits (cached)'
                        : '${_result!['credits_charged']} credits',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPayload(BuildContext context, Map<String, dynamic> data) {
    if (widget.toolType == 'visual') {
      final vp = data['visual_payload'] ?? data['visualPayload'];
      final md = (data['markdown'] as String?) ?? '';
      return SmartEducationalContent(
        markdownBody: md.isNotEmpty ? md : '## Visual',
        visualPayload: vp is Map
            ? VisualPayloadData.fromJson(Map<String, dynamic>.from(vp))
            : null,
      );
    }
    final questions = data['questions'] as List?;
    if (questions != null && questions.isNotEmpty && widget.toolType == 'quiz') {
      final parsed = questions
          .whereType<Map>()
          .map((q) => MCQQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
      return SizedBox(height: 420, child: MCQQuizView(questions: parsed));
    }
    if (questions != null &&
        questions.isNotEmpty &&
        widget.toolType == 'important_questions') {
      return SizedBox(
        height: 420,
        child: ImportantQuestionsView(
          questions: questions
              .whereType<Map>()
              .map((q) => ImportantQuestion.fromJson(Map<String, dynamic>.from(q)))
              .toList(),
        ),
      );
    }
    final cards = data['cards'] as List?;
    if (cards != null && cards.isNotEmpty) {
      final parsed = cards
          .whereType<Map>()
          .map((c) => Flashcard.fromJson(Map<String, dynamic>.from(c)))
          .toList();
      return SizedBox(height: 320, child: FlashcardStackView(flashcards: parsed));
    }
    if (data['root'] is Map) {
      return MindMapView(
        title: (data['title'] as String?) ?? 'Mind Map',
        root: MindMapNodeData.fromJson(Map<String, dynamic>.from(data['root'] as Map)),
      );
    }
    final md = (data['markdown'] as String?) ??
        (data['revisionSheet'] as String?) ??
        (data['revision_sheet'] as String?) ??
        '';
    if (md.isNotEmpty) {
      final vp = data['visualPayload'] ?? data['visual_payload'];
      return SmartEducationalContent(
        markdownBody: md,
        visualPayload: vp is Map
            ? VisualPayloadData.fromJson(Map<String, dynamic>.from(vp))
            : null,
      );
    }
    final tricks = data['tricks'] as List?;
    if (tricks != null && tricks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in tricks.whereType<Map>())
            Card(
              child: ListTile(
                title: Text('${t['trigger'] ?? ''}'),
                subtitle: Text(
                  '${t['mnemonic'] ?? ''}\n${t['why_it_works'] ?? ''}',
                ),
                isThreeLine: true,
              ),
            ),
          if ((data['markdown'] as String?)?.isNotEmpty == true)
            SmartEducationalContent(markdownBody: data['markdown'] as String),
        ],
      );
    }
    return SelectableText(data.toString());
  }
}
