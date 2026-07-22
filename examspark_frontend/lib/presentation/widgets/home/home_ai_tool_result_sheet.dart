import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Runs Home AI in a bottom sheet — does NOT add messages to the Home chat.
/// Used for Select AI + study chips (interim until Phase 4C response_id tools).
Future<void> showHomeAiToolResultSheet(
  BuildContext context, {
  required String title,
  required String query,
  String? lectureId,
  String? conversationLanguage,
  String? studyChip,
  void Function(int newBalance)? onCreditsUpdated,
}) async {
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
          return _HomeAiToolResultBody(
            title: title,
            query: query,
            lectureId: lectureId,
            conversationLanguage: conversationLanguage,
            studyChip: studyChip,
            scrollController: scrollController,
            onCreditsUpdated: onCreditsUpdated,
          );
        },
      );
    },
  );
}

class _HomeAiToolResultBody extends StatefulWidget {
  final String title;
  final String query;
  final String? lectureId;
  final String? conversationLanguage;
  final String? studyChip;
  final ScrollController scrollController;
  final void Function(int newBalance)? onCreditsUpdated;

  const _HomeAiToolResultBody({
    required this.title,
    required this.query,
    required this.lectureId,
    required this.conversationLanguage,
    required this.studyChip,
    required this.scrollController,
    required this.onCreditsUpdated,
  });

  @override
  State<_HomeAiToolResultBody> createState() => _HomeAiToolResultBodyState();
}

class _HomeAiToolResultBodyState extends State<_HomeAiToolResultBody> {
  String _liveText = '';
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _done;
  Map<String, dynamic>? _visualPayload;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      Map<String, dynamic> done;
      try {
        done = await LectureService.instance.homeAiStream(
          query: widget.query,
          lectureId: widget.lectureId,
          conversationLanguage: widget.conversationLanguage,
          studyChip: widget.studyChip,
          onToken: (delta) {
            if (!mounted) return;
            setState(() => _liveText += delta);
          },
        );
      } catch (_) {
        done = await LectureService.instance.homeAi(
          query: widget.query,
          lectureId: widget.lectureId,
          conversationLanguage: widget.conversationLanguage,
          studyChip: widget.studyChip,
        );
      }
      if (!mounted) return;
      final answer = (done['answer'] as String?)?.trim();
      setState(() {
        _done = done;
        if (answer != null && answer.isNotEmpty) {
          _liveText = answer;
        }
        final vp = done['visual_payload'];
        _visualPayload = vp is Map ? Map<String, dynamic>.from(vp) : null;
        _loading = false;
      });
      final balance = done['new_balance'];
      if (balance is int) {
        widget.onCreditsUpdated?.call(balance);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
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
                  widget.title,
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
                    markdownBody:
                        _liveText.isEmpty && _loading ? '…' : _liveText,
                    visualPayload: _visualPayload != null
                        ? VisualPayloadData.fromJson(_visualPayload)
                        : null,
                  ),
                if (_loading && _liveText.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ],
          ),
        ),
        if (!_loading && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
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
}
