import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/study_tool_copy.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Study Workspace — Home-style chip sheet, but generate from **recording notes**.
Future<void> showLectureStudyToolSheet(
  BuildContext context, {
  required String lectureId,
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
          return _LectureToolBody(
            lectureId: lectureId,
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

class _LectureToolBody extends StatefulWidget {
  final String lectureId;
  final String toolType;
  final String title;
  final bool regenerate;
  final ScrollController scrollController;
  final void Function(int newBalance)? onCreditsUpdated;
  final VoidCallback? onGenerated;

  const _LectureToolBody({
    required this.lectureId,
    required this.toolType,
    required this.title,
    required this.regenerate,
    required this.scrollController,
    required this.onCreditsUpdated,
    required this.onGenerated,
  });

  @override
  State<_LectureToolBody> createState() => _LectureToolBodyState();
}

class _LectureToolBodyState extends State<_LectureToolBody> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;
  bool _cached = false;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _run(regenerate: widget.regenerate);
  }

  Future<void> _run({required bool regenerate}) async {
    if (_inFlight) return;
    _inFlight = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await LectureService.instance.lectureGenerateStudyTool(
        lectureId: widget.lectureId,
        toolType: widget.toolType,
        regenerate: regenerate,
      );
      if (!mounted) return;
      _applyResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _inFlight = false;
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
                    Text(widget.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      StudyToolCopy.recordingPaidFirstGenerate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              if (!_loading && _error == null)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => _run(regenerate: true),
                  child: const Text(StudyToolCopy.regenerateButton),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
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
                    StudyToolCopy.creditsFooter(
                      fromDatabase: _cached,
                      charged: _result!['credits_charged'] as int?,
                    ),
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
    if (questions != null &&
        questions.isNotEmpty &&
        widget.toolType == 'quiz') {
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
              .map((q) =>
                  ImportantQuestion.fromJson(Map<String, dynamic>.from(q)))
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
      return SizedBox(
        height: 320,
        child: FlashcardStackView(flashcards: parsed),
      );
    }
    if (data['root'] is Map) {
      return MindMapView(
        title: (data['title'] as String?) ?? 'Mind Map',
        root: MindMapNodeData.fromJson(
          Map<String, dynamic>.from(data['root'] as Map),
        ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '• ${t['mnemonic'] ?? t['trigger'] ?? t}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      );
    }
    return Text(
      'No content in this chip yet.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
