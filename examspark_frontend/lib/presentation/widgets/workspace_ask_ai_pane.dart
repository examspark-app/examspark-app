import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/ai_answer_meta.dart';
import 'package:examspark_frontend/core/constants/student_copy.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_assistant_message.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_thinking_bubble.dart';
import 'package:url_launcher/url_launcher.dart';
/// Library / Study Workspace Ask AI — same FastAPI path as Notes result RAG modal.
// BAAD ME
class WorkspaceAskAiPane extends StatefulWidget {
  final String lectureId;
  final String? initialQuery;

  const WorkspaceAskAiPane({
    super.key,
    required this.lectureId,
    this.initialQuery,
  });

  @override
  State<WorkspaceAskAiPane> createState() => _WorkspaceAskAiPaneState();
}

class _AskMsg {
  final String text;
  final bool isUser;
  final String? trustLine;
  final bool animateReveal;
  final Map<String, dynamic>? visualPayload;
  final bool isSelectedQuote;

  const _AskMsg(
    this.text, {
    required this.isUser,
    this.trustLine,
    this.animateReveal = false,
    this.visualPayload,
    this.isSelectedQuote = false,
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
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(q);
      });
    }
  }
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
        final msg = studentSafeError(e, fallback: StudentCopy.askFailed);
        setState(() {
          _messages.add(_AskMsg(
            msg,
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
   Future<void> _sendSelectedText(
    String actionId,
    String selectedText,
  ) async {
    final text = selectedText.trim();
    if (text.isEmpty || _isSending) return;

      setState(() {
      _messages.add(
        _AskMsg(text, isUser: true, isSelectedQuote: true),
      );
      _isSending = true;
      _liveStreamText = null;
    });

    _scrollToBottom();

    try {
      final done = await LectureService.instance.selectAiStream(
        lectureId: widget.lectureId,
        selectedText: text,
        action: actionId,
        sourceSurface: 'ask_ai',
        conversationLanguage: _conversationLanguage,
        onToken: (delta) {
          if (!mounted) return;

          setState(() {
            _liveStreamText =
                (_liveStreamText ?? '') + delta;
          });

          _scrollToBottom();
        },
      );

      if (!mounted) return;

      _applySuccess(
        done,
        animateReveal: false,
      );
    } catch (e) {
      if (!mounted) return;

      final msg = studentSafeError(
        e,
        fallback: StudentCopy.askFailed,
      );

      setState(() {
        _messages.add(
          _AskMsg(
            msg,
            isUser: false,
            animateReveal: false,
          ),
        );
        _isSending = false;
        _liveStreamText = null;
      });

      _scrollToBottom();
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
      webSearchNote: result['web_search_note'] as String?,
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
        visualPayload: result['visual_payload'] is Map
            ? Map<String, dynamic>.from(result['visual_payload'] as Map)
            : null,
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
                        onSelectAi: (actionId, selectedText) async {
                        await _sendSelectedText(actionId, selectedText);
                       },
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
                      if (m.isSelectedQuote) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.getCardBackground(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border(
                                left: BorderSide(
                                  color: AppTheme.accentColor,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.format_quote_rounded,
                                      size: 14,
                                      color: AppTheme.accentColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Selected text',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  m.text,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.getPrimaryText(context),
                                    fontSize: 13.5,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
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
                    visualPayload: m.visualPayload,
                    onSelectAi: (actionId, selectedText) async {
                    await _sendSelectedText(actionId, selectedText);
                    },
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
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: GestureDetector(
            onTap: () {
              launchUrl(
                Uri.parse(
                  'https://sites.google.com/view/sonaxia/support',
                ),
                mode: LaunchMode.externalApplication,
              );
            },
            child: Text.rich(
              TextSpan(
                text: 'Sonaxia Ai can make mistakes. ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 11,
                    ),
                children: [
                  TextSpan(
                    text: 'Please double-check responses.',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
