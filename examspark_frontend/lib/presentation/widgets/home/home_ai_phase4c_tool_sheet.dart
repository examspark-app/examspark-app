import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/study_tool_copy.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Phase 4C — open a study tool from response_id (no full-answer paste).
///
/// All 11 Home AI study chips (Important Qs, Quiz, Memory, Mind Map,
/// Flashcards, Revision Sheet, Cheat Sheet, Teacher Tips, Exam Booster,
/// etc.) call this one function — so opening it full-page instead of as
/// a popup sheet fixes all of them at once. Name and parameters are
/// unchanged, so no call site needs to change.
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
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _Phase4cToolPage(
        responseId: responseId,
        toolType: toolType,
        title: title,
        regenerate: regenerate,
        onCreditsUpdated: onCreditsUpdated,
        onGenerated: onGenerated,
      ),
    ),
  );
}

class _Phase4cToolPage extends StatefulWidget {
  final String responseId;
  final String toolType;
  final String title;
  final bool regenerate;
  final void Function(int newBalance)? onCreditsUpdated;
  final VoidCallback? onGenerated;

  const _Phase4cToolPage({
    required this.responseId,
    required this.toolType,
    required this.title,
    required this.regenerate,
    required this.onCreditsUpdated,
    required this.onGenerated,
  });

  @override
  State<_Phase4cToolPage> createState() => _Phase4cToolPageState();
}

class _Phase4cToolPageState extends State<_Phase4cToolPage> {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 17)),
        actions: [
          if (!_loading && _error == null)
            TextButton(
              onPressed: () => _run(regenerate: true),
              child: const Text(StudyToolCopy.regenerateButton),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  StudyToolCopy.freeDbVsRegenerateAi,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                        height: 1.35,
                      ),
                ),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    )
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildPayload(context, _payload ?? const {}),
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
                          fromDatabase: _cached || _result?['derived'] == true,
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
        ),
      ),
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
      return MCQQuizView(questions: parsed);
    }
    if (questions != null &&
        questions.isNotEmpty &&
        widget.toolType == 'important_questions') {
      return ImportantQuestionsView(
        questions: questions
            .whereType<Map>()
            .map((q) => ImportantQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList(),
      );
    }
    final cards = data['cards'] as List?;
    if (cards != null && cards.isNotEmpty) {
      final parsed = cards
          .whereType<Map>()
          .map((c) => Flashcard.fromJson(Map<String, dynamic>.from(c)))
          .toList();
      return FlashcardStackView(flashcards: parsed);
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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SmartEducationalContent(
          markdownBody: md,
          visualPayload: vp is Map
              ? VisualPayloadData.fromJson(Map<String, dynamic>.from(vp))
              : null,
        ),
      );
    }
    final tricks = data['tricks'] as List?;
    if (tricks != null && tricks.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
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
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(data.toString()),
    );
  }
}