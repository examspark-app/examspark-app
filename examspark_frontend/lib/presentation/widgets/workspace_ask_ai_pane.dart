import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/ai_answer_meta.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_assistant_message.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_thinking_bubble.dart';

/// Library / Study Workspace Ask AI — same FastAPI path as Notes result RAG modal.
class WorkspaceAskAiPane extends StatefulWidget {
  final String lectureId;

  const WorkspaceAskAiPane({super.key, required this.lectureId});

  @override
  State<WorkspaceAskAiPane> createState() => _WorkspaceAskAiPaneState();
}

class _AskMsg {
  final String text;
  final bool isUser;
  final String? trustLine;
  final bool animateReveal;

  const _AskMsg(
    this.text, {
    required this.isUser,
    this.trustLine,
    this.animateReveal = false,
  });
}

class _WorkspaceAskAiPaneState extends State<WorkspaceAskAiPane> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AskMsg> _messages = [];
  bool _isSending = false;
  String? _conversationLanguage;
  String? _liveStreamText;

  static const _chips = [
    'Explain the main idea in simple words',
    'What should I remember for revision?',
    'List important terms and definitions',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final query = (preset ?? _controller.text).trim();
    if (query.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_AskMsg(query, isUser: true));
      _controller.clear();
      _isSending = true;
      _liveStreamText = null;
    });
    _scrollToBottom();

    try {
      await _runStream(query);
    } catch (_) {
      if (!mounted) return;
      setState(() => _liveStreamText = null);
      try {
        await _runJson(query);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _messages.add(_AskMsg(
            'Ask AI failed: $e',
            isUser: false,
            animateReveal: false,
          ));
          _isSending = false;
          _liveStreamText = null;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _runStream(String query) async {
    final done = await LectureService.instance.askAiStream(
      lectureId: widget.lectureId,
      query: query,
      mode: 'normal',
      conversationLanguage: _conversationLanguage,
      onToken: (delta) {
        if (!mounted) return;
        setState(() {
          _liveStreamText = (_liveStreamText ?? '') + delta;
        });
        _scrollToBottom();
      },
    );
    if (!mounted) return;
    _applySuccess(done, animateReveal: false);
  }

  Future<void> _runJson(String query) async {
    final result = await LectureService.instance.askAi(
      lectureId: widget.lectureId,
      query: query,
      mode: 'normal',
      conversationLanguage: _conversationLanguage,
    );
    if (!mounted) return;
    _applySuccess(result, animateReveal: true);
  }

  void _applySuccess(Map<String, dynamic> result, {required bool animateReveal}) {
    final answer = (result['answer'] as String?)?.trim();
    final trust = AiAnswerMeta.trustLine(
      answerSource: result['answer_source'] as String?,
      confidence: result['confidence'] as String?,
    );
    final convLang = result['conversation_language'] as String?;
    final hasAnswer = answer != null && answer.isNotEmpty;
    setState(() {
      if (convLang != null && convLang.isNotEmpty) {
        _conversationLanguage = convLang;
      }
      _messages.add(_AskMsg(
        hasAnswer ? answer : 'No answer available',
        isUser: false,
        trustLine: trust,
        animateReveal: hasAnswer && animateReveal,
      ));
      _isSending = false;
      _liveStreamText = null;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty && !_isSending
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Ask about this lecture (notes + transcript).',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _chips
                          .map(
                            (c) => ActionChip(
                              label: Text(c, style: const TextStyle(fontSize: 12)),
                              onPressed: _isSending ? null : () => _send(c),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isSending && index == _messages.length) {
                      if (_liveStreamText != null &&
                          _liveStreamText!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AiAssistantMessage(
                            text: _liveStreamText!,
                            animate: false,
                          ),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: AiThinkingBubble(),
                      );
                    }
                    final m = _messages[index];
                    if (m.isUser) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            m.text,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AiAssistantMessage(
                        text: m.text,
                        trustLine: m.trustLine,
                        animate: m.animateReveal,
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.getCardBorder(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isSending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask about this lecture…',
                    filled: true,
                    fillColor: AppTheme.getCardBackground(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppTheme.getCardBorder(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isSending ? null : () => _send(),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
