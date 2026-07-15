import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/ai_answer_meta.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_assistant_message.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_thinking_bubble.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/bottom_input_bar.dart';
import 'package:examspark_frontend/presentation/widgets/lecture_card.dart';
import 'package:examspark_frontend/presentation/widgets/youtube_link_dialog.dart';

typedef OpenWorkspace = void Function(String lectureId, String title, String? subject);

/// Home = Chat Screen. Home AI Study Coach (retrieval rules + 5 credits).
/// When [openLectureId] is set (desktop Study Workspace open), Priority 1 RAG
/// uses that lecture's notes.
class HomeTab extends StatefulWidget {
  final OpenWorkspace onOpenWorkspace;
  final ValueChanged<int> onGoToTab;
  /// When Home becomes visible again (IndexedStack), reload recent history.
  final bool isActive;
  /// Open Study Workspace lecture — passed to Home AI as Priority 1 RAG.
  final String? openLectureId;

  const HomeTab({
    super.key,
    required this.onOpenWorkspace,
    required this.onGoToTab,
    this.isActive = true,
    this.openLectureId,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _ChatBubble {
  final String text;
  final bool isUser;
  /// Show study-action chips under this AI reply (success answers only).
  final bool showStudyActions;
  /// Server trust line, e.g. "Source: Notes · Confidence: High".
  final String? trustLine;
  /// Typewriter reveal for AI success answers (off for errors).
  final bool animateReveal;
  const _ChatBubble(
    this.text,
    this.isUser, {
    this.showStudyActions = false,
    this.trustLine,
    this.animateReveal = false,
  });
}

class _HomeTabState extends State<HomeTab> {
  int _creditsBalance = 0;
  String _userName = 'User';
  List<Map<String, dynamic>> _recentLectures = [];
  final List<_ChatBubble> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  bool _isSending = false;
  /// Locked after first successful turn (HINDI/BENGALI/ENGLISH/HINGLISH).
  String? _conversationLanguage;
  /// Live SSE tokens while waiting (null = still thinking).
  String? _liveStreamText;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadUserData();
    }
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

  Future<void> _loadUserData({bool showSpinner = false}) async {
    final user = SupabaseClient.instance.currentUser;
    if (user == null) return;
    if (showSpinner) setState(() => _isRefreshing = true);
    try {
      final profile = await SupabaseClient.instance.getUserProfile(user.id);
      final lectures = await LectureService.instance.getLecturesForUser();
      if (!mounted) return;
      setState(() {
        _creditsBalance = profile?['credits_balance'] as int? ?? 0;
        _userName = (profile?['full_name'] as String?) ?? user.email ?? 'User';
        _recentLectures = lectures.take(5).toList();
        _isRefreshing = false;
      });
    } catch (_) {
      // Non-fatal: home still works without profile/lecture data.
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _handleSend(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _liveStreamText = null;
      _messages.add(_ChatBubble(query, true));
    });
    _scrollToBottom();

    try {
      await _runHomeAiStream(query);
    } catch (_) {
      // Stream failed — fall back to JSON + typewriter (existing path).
      if (!mounted) return;
      setState(() => _liveStreamText = null);
      try {
        await _runHomeAiJson(query);
      } catch (e) {
        if (!mounted) return;
        var msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.trim().toLowerCase() == 'not found') {
          msg =
              'Home AI API not found. Restart the FastAPI server, then try again.';
        }
        setState(() {
          _messages.add(_ChatBubble(msg, false, animateReveal: false));
          _isSending = false;
          _liveStreamText = null;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _runHomeAiStream(String query) async {
    final done = await LectureService.instance.homeAiStream(
      query: query,
      lectureId: widget.openLectureId,
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
    _applyHomeAiSuccess(done, animateReveal: false);
  }

  Future<void> _runHomeAiJson(String query) async {
    final result = await LectureService.instance.homeAi(
      query: query,
      lectureId: widget.openLectureId,
      conversationLanguage: _conversationLanguage,
    );
    if (!mounted) return;
    _applyHomeAiSuccess(result, animateReveal: true);
  }

  void _applyHomeAiSuccess(
    Map<String, dynamic> result, {
    required bool animateReveal,
  }) {
    final answer = (result['answer'] as String?)?.trim();
    final status = result['status'] as String? ?? 'SUCCESS';
    final newBalance = result['new_balance'];
    final convLang = result['conversation_language'] as String?;
    final trust = AiAnswerMeta.trustLine(
      answerSource: result['answer_source'] as String?,
      confidence: result['confidence'] as String?,
    );
    final hasAnswer = answer != null && answer.isNotEmpty;
    setState(() {
      if (convLang != null && convLang.isNotEmpty) {
        _conversationLanguage = convLang;
      }
      _messages.add(_ChatBubble(
        hasAnswer
            ? answer
            : 'Home AI returned an empty answer. Please try again.',
        false,
        showStudyActions: hasAnswer,
        trustLine: trust,
        animateReveal: hasAnswer && animateReveal,
      ));
      if (status == 'SUCCESS' && newBalance is int) {
        _creditsBalance = newBalance;
      }
      _isSending = false;
      _liveStreamText = null;
    });
    _scrollToBottom();
  }

  void _handleRecord() {
    Navigator.pushNamed(context, '/recording_setup');
  }

  void _handleAttach() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _UploadOptionsSheet(
        onOptionSelected: (inputMethod) {
          Navigator.pushNamed(
            context,
            '/recording_setup',
            arguments: {'initialInputMethod': inputMethod},
          );
        },
      ),
    );
  }

  void _handleYoutube() {
    showYoutubeLinkDialog(
      context,
      onSubmit: (url) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'YouTube Notes — coming soon (backend pipeline in Phase 5)',
            ),
          ),
        );
      },
    );
  }

  void _openLecture(Map<String, dynamic> lecture) {
    final id = lecture['id'] as String?;
    if (id == null) return;
    widget.onOpenWorkspace(
      id,
      lecture['title'] as String? ?? 'Lecture',
      lecture['subject'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        showLogo: true,
        creditsBalance: _creditsBalance,
        userName: _userName,
        onSearchTap: () => _showComingSoon('Search'),
        onNotificationTap: () => _showComingSoon('Notifications'),
        onCreditsTap: () => widget.onGoToTab(4),
        onProfileTap: () => widget.onGoToTab(4),
        trailing: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh history',
            onPressed: _isRefreshing
                ? null
                : () => _loadUserData(showSpinner: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isSending
                ? _buildWelcome(context)
                : _buildConversation(context),
          ),
          BottomInputBar(
            onSend: _handleSend,
            onAttach: _handleAttach,
            onRecord: _handleRecord,
            onYoutube: _handleYoutube,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: Icon(
              Icons.auto_awesome,
              size: 56,
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask an education question (5 credits) or record a lecture',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Home AI helps with study doubts. Lecture notes live in Study Workspace.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (_recentLectures.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Continue where you left off',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            for (final lecture in _recentLectures)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LectureCard(
                  title: lecture['title'] as String? ?? 'Untitled Lecture',
                  subject: lecture['subject'] as String?,
                  dateLabel: _formatDate(lecture['created_at']),
                  onTap: () => _openLecture(lecture),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static const _studyActions = [
    'Learn More',
    'Flashcards',
    'Quiz',
    'PYQs',
    'Revision Sheet',
    'Mind Map',
    'Cheat Sheet',
    '5 Minute Revision',
    'Important Questions',
  ];

  void _onStudyAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label — generate on click not wired to FastAPI yet.',
        ),
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    final itemCount = _messages.length + (_isSending ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (_isSending && index == _messages.length) {
          if (_liveStreamText != null && _liveStreamText!.isNotEmpty) {
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
        final bubble = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: bubble.isUser
              ? Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(
                        bubble.text,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                )
              : AiAssistantMessage(
                  text: bubble.text,
                  trustLine: bubble.trustLine,
                  animate: bubble.animateReveal,
                  onRevealComplete: _scrollToBottom,
                  trailing: bubble.showStudyActions
                      ? Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final label in _studyActions)
                              ActionChip(
                                label: Text(
                                  label,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () => _onStudyAction(label),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        )
                      : null,
                ),
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }
}

class _UploadOptionsSheet extends StatelessWidget {
  /// Called with an [InputMethod] name ('uploadDocument' / 'uploadAudio')
  /// once the sheet closes — routes into the already-working upload flow
  /// inside RecorderScreen instead of a dead-end "coming soon" message.
  final ValueChanged<String> onOptionSelected;

  const _UploadOptionsSheet({required this.onOptionSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add content',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _option(
              context,
              Icons.picture_as_pdf_outlined,
              'PDF Document',
              'uploadDocument',
            ),
            _option(
              context,
              Icons.image_outlined,
              'Image / Photo',
              'uploadDocument',
            ),
            _option(context, Icons.mic_outlined, 'Audio File', 'uploadAudio'),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    IconData icon,
    String label,
    String inputMethod,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.getAccentTint(context),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppTheme.accentColor, size: 20),
      ),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        onOptionSelected(inputMethod);
      },
    );
  }
}
