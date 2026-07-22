import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/select_ai/select_ai_toolbar.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Shows Select AI result: streamed answer + optional quiz/flashcards/visuals.
Future<void> showSelectAiResultSheet(
  BuildContext context, {
  required String lectureId,
  required String selectedText,
  required String action,
  required String sourceSurface,
}) async {
  if (action == 'copy') {
    await Clipboard.setData(ClipboardData(text: selectedText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied.')),
      );
    }
    return;
  }

  String? followupQuery;
  if (action == 'ask_followup') {
    followupQuery = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Ask about selection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Your question…',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Ask'),
            ),
          ],
        );
      },
    );
    if (followupQuery == null || followupQuery.isEmpty) return;
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return _SelectAiResultBody(
            lectureId: lectureId,
            selectedText: selectedText,
            action: action,
            sourceSurface: sourceSurface,
            followupQuery: followupQuery,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _SelectAiResultBody extends StatefulWidget {
  final String lectureId;
  final String selectedText;
  final String action;
  final String sourceSurface;
  final String? followupQuery;
  final ScrollController scrollController;

  const _SelectAiResultBody({
    required this.lectureId,
    required this.selectedText,
    required this.action,
    required this.sourceSurface,
    required this.followupQuery,
    required this.scrollController,
  });

  @override
  State<_SelectAiResultBody> createState() => _SelectAiResultBodyState();
}

class _SelectAiResultBodyState extends State<_SelectAiResultBody> {
  String _liveText = '';
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _done;
  Map<String, dynamic>? _visualPayload;
  Map<String, dynamic>? _structured;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final done = await LectureService.instance.selectAiStream(
        lectureId: widget.lectureId,
        selectedText: widget.selectedText,
        action: widget.action,
        sourceSurface: widget.sourceSurface,
        followupQuery: widget.followupQuery,
        onToken: (delta) {
          if (!mounted) return;
          setState(() => _liveText += delta);
        },
      );
      if (!mounted) return;
      setState(() {
        _done = done;
        _liveText = (done['answer'] as String?)?.trim().isNotEmpty == true
            ? (done['answer'] as String)
            : _liveText;
        final vp = done['visual_payload'];
        _visualPayload =
            vp is Map ? Map<String, dynamic>.from(vp) : null;
        final sr = done['structured_result'];
        _structured = sr is Map ? Map<String, dynamic>.from(sr) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _title {
    for (final a in kSelectAiMenuActions) {
      if (a.id == widget.action) return a.label;
    }
    return 'Select AI';
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
                child: Text(
                  _title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
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
              else ...[
                if (_liveText.isNotEmpty || _loading)
                  SmartEducationalContent(
                    markdownBody: _liveText.isEmpty && _loading
                        ? '…'
                        : _liveText,
                    visualPayload: _visualPayload != null
                        ? VisualPayloadData.fromJson(_visualPayload)
                        : null,
                  ),
                if (_loading && _liveText.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_structured != null) ...[
                  const SizedBox(height: 16),
                  _structuredView(_structured!),
                ],
              ],
            ],
          ),
        ),
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Bookmark coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bookmark_border, size: 16),
                  label: const Text('Save Response'),
                ),
                const Spacer(),
                if (_done?['credits_charged'] is int)
                  Text(
                    '${_done!['credits_charged']} credits',
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

  Widget _structuredView(Map<String, dynamic> data) {
    final questions = data['questions'] as List?;
    if (questions != null && questions.isNotEmpty) {
      final parsed = questions
          .whereType<Map>()
          .map((q) => MCQQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
      return SizedBox(
        height: 360,
        child: MCQQuizView(questions: parsed),
      );
    }
    final cards = data['cards'] as List?;
    if (cards != null && cards.isNotEmpty) {
      final parsed = cards
          .whereType<Map>()
          .map((c) => Flashcard.fromJson(Map<String, dynamic>.from(c)))
          .toList();
      return SizedBox(
        height: 280,
        child: FlashcardStackView(flashcards: parsed),
      );
    }
    return const SizedBox.shrink();
  }
}
