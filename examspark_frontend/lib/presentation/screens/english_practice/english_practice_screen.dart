import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class _Bubble {
  final String text;
  final bool isUser;
  const _Bubble(this.text, this.isUser);
}

/// Standalone AI English conversation practice — chat UI.
/// Assumes native language preference is already set (see
/// EnglishLanguagePickerScreen / EnglishPracticeEntry).
class EnglishPracticeScreen extends StatefulWidget {
  final String? sessionId;
  const EnglishPracticeScreen({super.key, this.sessionId});

  @override
  State<EnglishPracticeScreen> createState() => _EnglishPracticeScreenState();
}

class _EnglishPracticeScreenState extends State<EnglishPracticeScreen> {
  final List<_Bubble> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _sessionId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.sessionId != null) {
        final data = await LectureService.instance
            .restoreEnglishPracticeSession(widget.sessionId!);
        final msgs = ((data['messages'] as List?) ?? [])
            .map((m) => _Bubble(
                  (m['message'] ?? '').toString(),
                  m['role'] == 'user',
                ))
            .toList();
        if (!mounted) return;
        setState(() {
          _sessionId = data['id'] as String?;
          _messages
            ..clear()
            ..addAll(msgs);
          _loading = false;
        });
        _scrollToBottom();
        return;
      }
      final data = await LectureService.instance.startEnglishPractice();
      if (!mounted) return;
      setState(() {
        _sessionId = data['session_id'] as String?;
        _messages.add(_Bubble((data['greeting'] as String?) ?? '', false));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _sessionId == null) return;
    _controller.clear();
    setState(() {
      _messages.add(_Bubble(text, true));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final result = await LectureService.instance.sendEnglishPracticeMessage(
        sessionId: _sessionId!,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_Bubble((result['reply'] as String?) ?? '', false));
        _sending = false;
      });
      _scrollToBottom();

      if (result['session_ended'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This conversation is complete — starting a fresh one.',
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _messages.clear();
          _sessionId = null;
        });
        _start();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(
          _Bubble('⚠️ ${e.toString().replaceFirst('Exception: ', '')}', false),
        );
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('English Practice')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _start,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding:
                            const EdgeInsets.all(AppTheme.screenPadding),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (_sending && i == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final m = _messages[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Align(
                              alignment: m.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 0.8,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: m.isUser
                                        ? AppTheme.accentColor
                                        : AppTheme.getCardBackground(context),
                                    borderRadius: BorderRadius.circular(14),
                                    border: m.isUser
                                        ? null
                                        : Border.all(
                                            color: AppTheme.getCardBorder(
                                              context,
                                            ),
                                          ),
                                  ),
                                  child: SelectableText(
                                    m.text,
                                    style: TextStyle(
                                      color: m.isUser
                                          ? Colors.white
                                          : AppTheme.getPrimaryText(context),
                                      height: 1.4,
                                    ),
                                    contextMenuBuilder: (context, state) {
                                      final sel = state.textEditingValue.selection;
                                      final selected = sel
                                          .textInside(state.textEditingValue.text)
                                          .trim();
                                      final items = state.contextMenuButtonItems.toList();
                                      if (selected.isNotEmpty) {
                                        items.add(
                                          ContextMenuButtonItem(
                                            label: 'Ask about this',
                                            onPressed: () {
                                              state.hideToolbar();
                                              _controller.text = selected;
                                              _send();
                                            },
                                          ),
                                        );
                                      }
                                      return AdaptiveTextSelectionToolbar.buttonItems(
                                        anchors: state.contextMenuAnchors,
                                        buttonItems: items,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_loading && _error == null,
                      decoration: InputDecoration(
                        hintText: 'Type your answer…',
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.accentColor,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                      ),
                      onPressed: (_loading || _error != null) ? null : _send,
                    ),
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