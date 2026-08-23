import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/constants/ai_answer_meta.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/constants/plan_tier_gating.dart';
import 'package:examspark_frontend/core/constants/student_copy.dart';
import 'package:examspark_frontend/core/errors/lecture_user_message.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/home_ask_bridge.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/home_session_bridge.dart';
import 'package:examspark_frontend/core/services/notification_service.dart';
import 'package:examspark_frontend/core/services/notification_inbox_controller.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/services/ui_session_store.dart';
import 'package:examspark_frontend/core/theme/responsive.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_assistant_message.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_thinking_bubble.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/bottom_input_bar.dart';
import 'package:examspark_frontend/presentation/widgets/home/home_ai_history_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/home/home_ai_phase4c_tool_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/home/home_ai_tool_result_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/home/home_study_chip_bar.dart';
import 'package:examspark_frontend/presentation/widgets/home/web_camera_capture_export.dart';
import 'package:examspark_frontend/presentation/widgets/lecture_card.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_reading_utils.dart';
import 'package:examspark_frontend/presentation/screens/search/search_overlay_screen.dart';
import 'package:examspark_frontend/presentation/widgets/youtube_link_dialog.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';
import 'package:examspark_frontend/presentation/widgets/glow_guide_rotating_button.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

typedef OpenWorkspace =
    void Function(String lectureId, String title, String? subject);

/// Home = Chat Screen. Home AI Study Coach (retrieval rules + 5 credits).
/// When [openLectureId] is set (desktop Study Workspace open), Priority 1 RAG
/// uses that lecture's notes.
class HomeTab extends StatefulWidget {
  final OpenWorkspace onOpenWorkspace;
  final ValueChanged<int> onGoToTab;
  final VoidCallback? onOpenDrawer;

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
    this.onOpenDrawer,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _ChatBubble {
  final String id;
  final String text;
  final bool isUser;

  /// Show study-action chips under this AI reply (success answers only).
  final bool showStudyActions;

  /// Server trust line, e.g. "Source: Notes · Confidence: High".
  final String? trustLine;

  /// Typewriter reveal for AI success answers (off for errors / after stick).
  bool animateReveal;

  /// Once true, scroll rebuilds must not re-run typing animation.
  bool revealComplete;
  final Map<String, dynamic>? visualPayload;

  /// Phase 4C master response id (null until SQL migration / persist).
  final String? responseId;

  /// tool_type → Ready / Loading / Generated
  Map<String, HomeChipUiState> toolStates;
  String? activeToolType;

  /// Server-recommended tool types for this Knowledge Object.
  List<String> recommendedTools;

  /// Failed AI turn — show Retry instead of study chips.
  final bool isError;

  /// Text query to resend (Retry).
  final String? retryQuery;

  /// AI-suggested follow-up questions (sequential reveal chips).
  final List<String> suggestedQuestions;
  final String? practiceQuestion;

  /// In-memory photo for this session's user bubble (not persisted to disk).
  final Uint8List? imageBytes;
  final String? imageFilename;
  final String? imageUrl;

  /// Vision retry payload (session memory only).
  final Uint8List? retryVisionBytes;
  final String? retryVisionFilename;

  _ChatBubble(
    this.text,
    this.isUser, {
    String? id,
    this.showStudyActions = false,
    this.trustLine,
    this.animateReveal = false,
    this.revealComplete = false,
    this.visualPayload,
    this.responseId,
    Map<String, HomeChipUiState>? toolStates,
    List<String>? recommendedTools,
    this.isError = false,
    this.retryQuery,
    List<String>? suggestedQuestions,
    this.practiceQuestion,
    this.imageBytes,
    this.imageFilename,
    this.imageUrl,
    this.retryVisionBytes,
    this.retryVisionFilename,
  }) : id = id ?? UniqueKey().toString(),
       toolStates = toolStates ?? {},
       recommendedTools = recommendedTools ?? [],
       suggestedQuestions = suggestedQuestions ?? const [],
       activeToolType = null;
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  /// Survives AppShell remount within the same isolate (Founder Lock).
  static List<_ChatBubble>? _sessionMessages;
  static String? _sessionLanguage;
  static String? _sessionHomeAiId;

  int _creditsBalance = 0;
  String _userName = 'User';
  String _planTier = 'free';
  bool _isTeacher = false;
  List<Map<String, dynamic>> _recentLectures = [];
  final List<_ChatBubble> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  bool _isSending = false;

  /// Locked after first successful turn (HINDI/BENGALI/ENGLISH/HINGLISH).
  String? _conversationLanguage;
  String _visionModel = 'qwen-vl';
  String _textModel = 'qwen3';

  /// Phase 4D — active Study Session (Supabase).
  String? _homeAiSessionId;

  /// Live SSE tokens while waiting (null = still thinking).
  String? _liveStreamText;
  String? _replyQuote;
  Uint8List? _pendingAttachmentBytes;
  String? _pendingAttachmentName;
  Timer? _persistDebounce;

  bool _restoredDisk = false;
  bool _notificationsSheetOpen = false;
  bool _showQuote = false;
  String? _replySelection;
  String _preferredLanguage = 'English';
  String? _dailyQuote;
  Timer? _quoteTimer;
  bool get _audioUnlocked => _isTeacher
      ? PlanTierGating.isTeacherLiveRecordUnlocked(_planTier)
      : PlanTierGating.isStudentAudioUnlocked(_planTier);

  /// User chat bubble color — black/charcoal instead of the app's green
  /// accent, so the sent message reads as "professional AI chat" (black
  /// bubble) rather than a brand-colored pill. Adapts for dark mode so the
  /// bubble still stands out against the near-black dark background.
  /// Chat message bubble color — light grey (Claude.ai style) instead of
  /// solid black, so sent messages read as calm/neutral rather than a
  /// heavy black pill. Adapts for dark mode.
  Color _userBubbleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFECECEC)
        : const Color(0xFF2F2F2F);
  }

  /// Avatar circle stays dark/solid (unaffected by the bubble color change)
  /// so the white initial letter inside it stays readable.
  Color _avatarBgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF0D0D0D)
        : const Color(0xFF262626);
  }

  /// Bubble text color — must stay readable against the new light-grey
  /// bubble (was hardcoded white for the old black bubble).
  Color _userBubbleTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF1A1A1A)
        : Colors.white;
  }

  /// First name only, for the greeting banner — "Priya" not
  /// "priya.sharma@email.com" or "Priya Sharma".
  String get _greetingName {
    final raw = _userName.trim();
    if (raw.isEmpty || raw == 'User') return '';
    final beforeAt = raw.split('@').first;
    final firstWord = beforeAt.trim().split(RegExp(r'\s+')).first;
    if (firstWord.isEmpty) return '';
    return firstWord[0].toUpperCase() + firstWord.substring(1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_sessionMessages != null && _sessionMessages!.isNotEmpty) {
      _messages.addAll(_sessionMessages!);
      _conversationLanguage = _sessionLanguage;
      _homeAiSessionId = _sessionHomeAiId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(instant: true);
      });
    }
    SessionLiveSync.instance.addListener(_onSessionLive);
    HomeSessionBridge.instance.addListener(_onHomeSessionBridge);
    HomeAskBridge.instance.addListener(_onHomeAskBridge);
    NotificationInboxController.instance.addListener(_onInboxChanged);
    unawaited(NotificationInboxController.instance.start());
    _loadUserData();
    _applySessionLive();
    // In case Ask AI was queued before Home mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onHomeAskBridge();
    });
    _fetchDailyQuote();
    _quoteTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showQuote = true);
    });
  }

  Future<void> _fetchDailyQuote() async {
    if (!AppConfig.isApiConfigured) return;
    try {
      final res = await http.get(
        Uri.parse(
          '${AppConfig.resolvedApiBaseUrl}/api/v1/daily-quote?language=$_preferredLanguage',
        ),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) setState(() => _dailyQuote = data['quote'] as String?);
      }
    } catch (_) {}
  }

  void _onInboxChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _persistChatNow();
    }
  }

  Future<void> _restoreChatFromDisk() async {
    if (_restoredDisk) return;
    _restoredDisk = true;
    final storedSession = await UiSessionStore.instance.loadHomeSessionId();
    if (storedSession != null && storedSession.isNotEmpty) {
      _homeAiSessionId = storedSession;
      _sessionHomeAiId = storedSession;
    }
    if (_messages.isNotEmpty) return;
    final rows = await UiSessionStore.instance.loadHomeChat();
    if (!mounted || rows.isEmpty || _messages.isNotEmpty) return;
    final bubbles = <_ChatBubble>[];
    for (final row in rows) {
      final text = row['text'] as String? ?? '';
      if (text.isEmpty) continue;
      final isUser = row['isUser'] as bool? ?? false;
      final toolRaw = row['toolStates'];
      final toolStates = <String, HomeChipUiState>{};
      if (toolRaw is Map) {
        for (final e in toolRaw.entries) {
          final name = e.value?.toString() ?? 'ready';
          toolStates[e.key.toString()] = HomeChipUiState.values.firstWhere(
            (s) => s.name == name,
            orElse: () => HomeChipUiState.ready,
          );
        }
      }
      final rec = row['recommendedTools'];
      bubbles.add(
        _ChatBubble(
          text,
          isUser,
          id: row['id'] as String?,
          showStudyActions: row['showStudyActions'] as bool? ?? false,
          trustLine: row['trustLine'] as String?,
          animateReveal: false,
          revealComplete: true,
          visualPayload: row['visualPayload'] is Map
              ? Map<String, dynamic>.from(row['visualPayload'] as Map)
              : null,
          responseId: row['responseId'] as String?,
          imageUrl: row['imageUrl'] as String?,
          toolStates: toolStates,
          recommendedTools: rec is List
              ? rec.map((e) => e.toString()).toList()
              : const [],
        ),
      );
    }
    if (!mounted || bubbles.isEmpty || _messages.isNotEmpty) return;
    setState(() {
      _messages.addAll(bubbles);
      _sessionMessages = List<_ChatBubble>.from(_messages);
    });
    _scrollToBottom(instant: true);
  }

  void _schedulePersistChat() {
    _sessionMessages = List<_ChatBubble>.from(_messages);
    _sessionLanguage = _conversationLanguage;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: 400),
      _persistChatNow,
    );
  }

  Future<void> _persistChatNow() async {
    _sessionMessages = List<_ChatBubble>.from(_messages);
    _sessionLanguage = _conversationLanguage;
    _sessionHomeAiId = _homeAiSessionId;
    const maxKeep = 30;
    final trimmedMessages = _messages.length > maxKeep
        ? _messages.sublist(_messages.length - maxKeep)
        : _messages;
    final rows = trimmedMessages.map((m) {
      return <String, dynamic>{
        'id': m.id,
        'text': m.text,
        'isUser': m.isUser,
        'showStudyActions': m.showStudyActions,
        'trustLine': m.trustLine,
        'visualPayload': m.visualPayload,
        'responseId': m.responseId,
        'imageUrl': m.imageUrl,
        'recommendedTools': m.recommendedTools,
        'toolStates': {
          for (final e in m.toolStates.entries) e.key: e.value.name,
        },
      };
    }).toList();
    await UiSessionStore.instance.saveHomeChat(rows);
    await UiSessionStore.instance.saveHomeSessionId(_homeAiSessionId);
  }

  void _onHomeAskBridge() {
    final pendingSelection = HomeAskBridge.instance.takePendingSelection();

    final pendingQuestion = HomeAskBridge.instance.takePendingQuestion();

    if (!mounted) return;

    if (pendingSelection != null && pendingSelection.trim().isNotEmpty) {
      setState(() {
        _replySelection = pendingSelection.trim();
      });

      return;
    }

    if (pendingQuestion != null && pendingQuestion.trim().isNotEmpty) {
      _handleSend(pendingQuestion);
    }
  }

  /// Select text → Ask AI → next Home chat question + reply (no sheet).
  Future<void> _onHomeSelectAi(String actionId, String selectedText) async {
    final selected = selectedText.trim();
    if (selected.isEmpty) return;

    if (!mounted) return;

    setState(() {
      _replySelection = selected;
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _persistDebounce?.cancel();
    _persistChatNow();
    WidgetsBinding.instance.removeObserver(this);
    HomeAskBridge.instance.removeListener(_onHomeAskBridge);
    SessionLiveSync.instance.removeListener(_onSessionLive);
    HomeSessionBridge.instance.removeListener(_onHomeSessionBridge);
    NotificationInboxController.instance.removeListener(_onInboxChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadUserData();
      SessionLiveSync.instance.refreshAll();
    }
  }

  void _onHomeSessionBridge() {
    if (!mounted) return;
    if (HomeSessionBridge.instance.takePendingNewChat()) {
      _startNewChat();
    }
    final id = HomeSessionBridge.instance.takePendingRestoreSessionId();
    if (id != null && id.isNotEmpty) {
      _restoreStudySession(id);
    }
  }

  void _onSessionLive() {
    if (!mounted) return;
    _applySessionLive();
  }

  void _applySessionLive() {
    final sync = SessionLiveSync.instance;
    setState(() {
      _creditsBalance = sync.creditsBalance;
      if (sync.planId.isNotEmpty) {
        _planTier = sync.planId;
      }
    });
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (instant) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        return;
      }
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
      var plan = 'free';
      try {
        plan = await SupabaseClient.instance.getPlanTier(user.id);
      } catch (_) {}
      if (!mounted) return;
      var preferredLang = 'English';
      try {
        final bundle = await SupabaseClient.instance
            .fetchStudentOnboardingBundle(user.id);
        final sp = bundle['student_profiles'];
        if (sp is Map && sp['preferred_language'] is String) {
          final raw = (sp['preferred_language'] as String).trim();
          if (raw.isNotEmpty) preferredLang = raw;
        }
      } catch (_) {}

      setState(() {
        _creditsBalance = profile?['credits_balance'] as int? ?? 0;
        _userName = (profile?['full_name'] as String?) ?? user.email ?? 'User';
        _planTier = plan;
        _isTeacher = profile?['role'] == 'teacher';
        _recentLectures = lectures.take(5).toList();
        _preferredLanguage = preferredLang;
        _isRefreshing = false;
      });
    } catch (_) {
      // Non-fatal: home still works without profile/lecture data.
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String? _lastAiResponseId() {
    for (final msg in _messages.reversed) {
      if (!msg.isUser && msg.responseId != null && msg.responseId!.isNotEmpty) {
        return msg.responseId;
      }
    }
    return null;
  }

  bool _looksLikeFollowUp(String query) {
    final q = query.trim().toLowerCase();
    if (q.length <= 24 &&
        (q.startsWith('why') ||
            q.startsWith('how') ||
            q == 'explain more' ||
            q.contains('in hindi') ||
            q.contains('hindi mein') ||
            q.contains('more example') ||
            q.contains('simplify') ||
            q.contains('class '))) {
      return true;
    }
    return q.contains('explain in hindi') ||
        q.contains('more examples') ||
        q.contains('in detail');
  }

  Future<void> _handleSend(
    String text, {
    String? studyChip,
    bool isRetry = false,
  }) async {
    final rawText = text.trim();
    final replyContext = _replySelection?.trim();

    String query = rawText;

    if (!isRetry &&
        replyContext != null &&
        replyContext.isNotEmpty &&
        rawText.isNotEmpty) {
      query =
          '''
The user selected this text from the previous AI response:

"$replyContext"

The user's follow-up question is:

$rawText
''';
    }

    if (!isRetry && _pendingAttachmentBytes != null) {
      final bytes = _pendingAttachmentBytes!;
      final filename = _pendingAttachmentName ?? 'photo.jpg';

      _removePendingAttachment();

      await _sendHomeVision(
        bytes,
        filename,
        caption: rawText.isEmpty ? null : rawText,
      );

      return;
    }

    if (query.isEmpty || _isSending) return;

    final parentId = replyContext != null && replyContext.isNotEmpty
        ? _lastAiResponseId()
        : (_looksLikeFollowUp(query) ? _lastAiResponseId() : null);

    setState(() {
      _isSending = true;
      _liveStreamText = null;
      _replySelection = null;

      if (isRetry) {
        _removeTrailingErrorBubbles();
      } else {
        _messages.add(_ChatBubble(rawText, true));
      }
    });

    if (_messages.length >= 60 && !isRetry) {
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: const Text(
            'This chat is getting long. Starting a New Chat keeps things fast.',
          ),
          action: SnackBarAction(label: 'New Chat', onPressed: _startNewChat),
          duration: const Duration(seconds: 6),
        ),
      );
    }

    unawaited(_persistChatNow());
    _scrollToBottom();

    try {
      await _runHomeAiStream(
        query,
        studyChip: studyChip,
        parentResponseId: parentId,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _liveStreamText = null);

      try {
        await _runHomeAiJson(
          query,
          studyChip: studyChip,
          parentResponseId: parentId,
        );
      } catch (e) {
        if (!mounted) return;

        _addHomeAiErrorBubble(e, retryQuery: query);
      }
    }
  }

  void _removeTrailingErrorBubbles() {
    while (_messages.isNotEmpty &&
        !_messages.last.isUser &&
        _messages.last.isError) {
      _messages.removeLast();
    }
  }

  void _addHomeAiErrorBubble(
    Object error, {
    String? retryQuery,
    Uint8List? retryVisionBytes,
    String? retryVisionFilename,
  }) {
    final msg = studentSafeError(error, fallback: StudentCopy.homeFailed);
    setState(() {
      _messages.add(
        _ChatBubble(
          msg,
          false,
          animateReveal: false,
          revealComplete: true,
          isError: true,
          retryQuery: retryQuery,
          retryVisionBytes: retryVisionBytes,
          retryVisionFilename: retryVisionFilename,
        ),
      );
      _isSending = false;
      _liveStreamText = null;
    });
    unawaited(_persistChatNow());
    _scrollToBottom();
  }

  Future<void> _retryFailedBubble(_ChatBubble bubble) async {
    if (_isSending) return;
    if (bubble.retryVisionBytes != null &&
        bubble.retryVisionBytes!.isNotEmpty) {
      await _sendHomeVision(
        bubble.retryVisionBytes!,
        bubble.retryVisionFilename ?? 'photo.jpg',
        isRetry: true,
      );
      return;
    }
    final q = bubble.retryQuery?.trim();
    if (q == null || q.isEmpty) return;
    await _handleSend(q, isRetry: true);
  }

  Future<void> _runHomeAiStream(
    String query, {
    String? studyChip,
    String? parentResponseId,
  }) async {
    final done = await LectureService.instance.homeAiStream(
      query: query,
      lectureId: widget.openLectureId,
      conversationLanguage: _conversationLanguage,
      studyChip: studyChip,
      parentResponseId: parentResponseId,
      sessionId: _homeAiSessionId,
      textModel: _textModel,
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

  Future<void> _runHomeAiJson(
    String query, {
    String? studyChip,
    String? parentResponseId,
  }) async {
    final result = await LectureService.instance.homeAi(
      query: query,
      lectureId: widget.openLectureId,
      conversationLanguage: _conversationLanguage,
      studyChip: studyChip,
      parentResponseId: parentResponseId,
      sessionId: _homeAiSessionId,
      textModel: _textModel,
    );
    if (!mounted) return;
    _applyHomeAiSuccess(result, animateReveal: true);
  }

  void _applyHomeAiSuccess(
    Map<String, dynamic> result, {
    required bool animateReveal,
  }) {
    final answer = (result['answer'] as String?)?.trim();
    final status = (result['status'] as String? ?? 'SUCCESS').toUpperCase();
    final newBalance = result['new_balance'];
    final convLang = result['conversation_language'] as String?;
    final trust = AiAnswerMeta.trustLine(
      answerSource: result['answer_source'] as String?,
      confidence: result['confidence'] as String?,
      webSearchNote: result['web_search_note'] as String?,
    );
    final hasAnswer = answer != null && answer.isNotEmpty;
    final isSuccess = status == 'SUCCESS' && hasAnswer;
    final responseId = result['response_id'] as String?;
    final sessionId = result['session_id'] as String?;

    if (!isSuccess) {
      final errRaw = hasAnswer
          ? answer
          : (result['error']?.toString() ??
                result['message']?.toString() ??
                'Home AI could not answer. Please try again.');
      String? lastUser;
      Uint8List? visionBytes;
      String? visionName;
      for (var i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].isUser) {
          lastUser = _messages[i].text;
          visionBytes = _messages[i].imageBytes;
          visionName = _messages[i].imageFilename;
          break;
        }
      }
      _addHomeAiErrorBubble(
        errRaw,
        retryQuery: (visionBytes == null || visionBytes.isEmpty)
            ? lastUser
            : null,
        retryVisionBytes: visionBytes,
        retryVisionFilename: visionName,
      );
      return;
    }

    final suggestedQuestions =
        (result['suggested_questions'] as List?)
            ?.map((e) => e.toString())
            .where((q) => q.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final practiceQuestion = (result['practice_question'] as String?)?.trim();

    setState(() {
      if (convLang != null && convLang.isNotEmpty) {
        _conversationLanguage = convLang;
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        _homeAiSessionId = sessionId;
        _sessionHomeAiId = sessionId;
      }
      _messages.add(
        _ChatBubble(
          answer,
          false,
          showStudyActions: true,
          trustLine: trust,
          suggestedQuestions: suggestedQuestions,
          practiceQuestion: (practiceQuestion?.isNotEmpty ?? false)
              ? practiceQuestion
              : null,
          // Stream path already showed tokens live — never re-animate on scroll.
          animateReveal: animateReveal,
          revealComplete: !animateReveal,
          visualPayload: result['visual_payload'] is Map
              ? Map<String, dynamic>.from(result['visual_payload'] as Map)
              : null,
          responseId: responseId,
        ),
      );
      if (newBalance is int) {
        _creditsBalance = newBalance;
      }
      _isSending = false;
      _liveStreamText = null;
    });
    unawaited(_persistChatNow());
    _scrollToBottom();
    if (responseId != null && responseId.isNotEmpty) {
      _hydrateToolStates(responseId);
    }
  }

  Future<void> _hydrateToolStates(String responseId) async {
    try {
      final data = await LectureService.instance.homeAiToolStatuses(responseId);
      final tools = data['tools'];
      final recommended =
          (data['recommended'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      if (!mounted) return;
      setState(() {
        for (final msg in _messages) {
          if (msg.responseId != responseId) continue;
          if (recommended.isNotEmpty) {
            msg.recommendedTools = List<String>.from(recommended);
          }
          if (tools is! Map) continue;
          for (final entry in tools.entries) {
            final raw = entry.value;
            final status = raw is Map
                ? (raw['status'] as String?) ?? 'ready'
                : 'ready';
            if (status == 'generated') {
              msg.toolStates[entry.key.toString()] = HomeChipUiState.generated;
            } else if (status == 'generating') {
              msg.toolStates[entry.key.toString()] = HomeChipUiState.loading;
            } else if (status == 'stale') {
              // Knowledge updated — show as ready so user can reopen free.
              msg.toolStates[entry.key.toString()] = HomeChipUiState.ready;
            } else if (status == 'failed') {
              msg.toolStates[entry.key.toString()] = HomeChipUiState.ready;
            } else {
              msg.toolStates.putIfAbsent(
                entry.key.toString(),
                () => HomeChipUiState.ready,
              );
            }
          }
        }
      });
      unawaited(_persistChatNow());
    } catch (_) {
      // Soft-fail — chips still work via generate endpoint.
    }
  }

  void _handleRecord() {
    Posthog().capture(eventName: 'home_ai_record_tapped');
    if (!_audioUnlocked) {
      _showAudioLockedSheet();
      return;
    }
    Navigator.pushNamed(
      context,
      '/recorder',
      arguments: {if (_isTeacher) 'teacherRecordOnly': true},
    );
  }

  void _handleAttach() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _UploadOptionsSheet(
        audioLocked: !_audioUnlocked,
        hideAudioUpload: _isTeacher,
        onAudioLocked: () {
          Navigator.pop(sheetContext);
          _showAudioLockedSheet();
        },
        onHomeVisionCamera: () {
          Posthog().capture(eventName: 'home_ai_camera_tapped');
          Navigator.pop(sheetContext);
          _pickHomeVisionImage(fromCamera: true);
        },
        onHomeVisionGallery: () {
          Navigator.pop(sheetContext);
          _pickHomeVisionImage(fromCamera: false);
        },
        onOptionSelected: (inputMethod) {
          Navigator.pop(sheetContext);
          if (_isTeacher && inputMethod == 'uploadAudio') {
            Navigator.pushNamed(
              context,
              '/recorder',
              arguments: {
                'initialInputMethod': 'record',
                'teacherRecordOnly': true,
              },
            );
            return;
          }
          Navigator.pushNamed(
            context,
            '/recorder',
            arguments: {
              'initialInputMethod': inputMethod,
              if (_isTeacher) 'teacherRecordOnly': true,
            },
          );
        },
      ),
    );
  }

  Future<void> _pickHomeVisionImage({required bool fromCamera}) async {
    if (!AppConfig.isApiConfigured) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        const SnackBar(content: Text('API not configured — see API_SETUP.md')),
      );
      return;
    }
    if (!PlanTierGating.isFeatureUnlocked(
      currentPlanId: _planTier,
      feature: GatedFeature.diagramAnalysis,
    )) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            PlanTierGating.lockMessage(GatedFeature.diagramAnalysis),
          ),
        ),
      );
      return;
    }
    if (_creditsBalance < CreditCosts.homeAiVision) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            'Need ${CreditCosts.homeAiVision} credits for Photo / Image Ask.',
          ),
        ),
      );
      return;
    }
    if (_isSending) return;

    try {
      await _chooseVisionModel();
      if (!mounted) return;
      Uint8List? bytes;
      var filename = fromCamera ? 'camera.jpg' : 'photo.jpg';

      if (fromCamera) {
        if (kIsWeb) {
          // Desktop Chrome: getUserMedia asks permission (file picker alone does not).
          bytes = await captureWebCameraPhoto(context);
          if (bytes == null) return;
          filename = 'camera.jpg';
        } else {
          final picker = ImagePicker();
          final shot = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
            maxWidth: 2048,
          );
          if (shot == null) return;
          bytes = await shot.readAsBytes();
          filename = shot.name.isNotEmpty ? shot.name : 'camera.jpg';
        }
      } else if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final f = result.files.first;
        bytes = f.bytes;
        filename = f.name.isNotEmpty ? f.name : 'photo.jpg';
      } else {
        final picker = ImagePicker();
        final shot = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
        );
        if (shot == null) return;
        bytes = await shot.readAsBytes();
        filename = shot.name.isNotEmpty ? shot.name : 'photo.jpg';
      }

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        AppToast.showSnackBar(
          context,
          const SnackBar(content: Text('Could not read image. Try again.')),
        );
        return;
      }
      if (bytes.length > 8 * 1024 * 1024) {
        if (!mounted) return;
        AppToast.showSnackBar(
          context,
          const SnackBar(content: Text('Image too large (max 8 MB).')),
        );
        return;
      }

      setState(() {
        _pendingAttachmentBytes = bytes;
        _pendingAttachmentName = filename;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            fromCamera
                ? 'Camera unavailable here — try Upload Image. (${lectureUserMessage(e)})'
                : lectureUserMessage(e),
          ),
        ),
      );
    }
  }

  void _removePendingAttachment() {
    setState(() {
      _pendingAttachmentBytes = null;
      _pendingAttachmentName = null;
    });
  }

  Future<void> _sendHomeVision(
    Uint8List bytes,
    String filename, {
    bool isRetry = false,
    String? caption,
  }) async {
    final label = (caption != null && caption.isNotEmpty)
        ? caption
        : '📷 Photo Ask · $filename';
    setState(() {
      _isSending = true;
      _liveStreamText = null;
      if (isRetry) {
        _removeTrailingErrorBubbles();
      } else {
        _messages.add(
          _ChatBubble(label, true, imageBytes: bytes, imageFilename: filename),
        );
      }
    });
    unawaited(_persistChatNow());
    _scrollToBottom();

    try {
      final result = await LectureService.instance.homeAiVision(
        imageBytes: bytes,
        filename: filename,
        sessionId: _homeAiSessionId,
        visionModel: _visionModel,
      );
      if (!mounted) return;
      _applyHomeAiSuccess(result, animateReveal: true);
    } catch (e) {
      if (!mounted) return;
      _addHomeAiErrorBubble(
        e,
        retryVisionBytes: bytes,
        retryVisionFilename: filename,
      );
    }
  }

  Future<void> _chooseVisionModel() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Vision model'),
              subtitle: Text('Choose how Home image questions are solved.'),
            ),
            RadioListTile<String>(
              value: 'qwen-vl',
              groupValue: _visionModel,
              title: const Text('Qwen-VL'),
              subtitle: const Text('Default vision model'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
            RadioListTile<String>(
              value: 'gemini',
              groupValue: _visionModel,
              title: const Text('Gemini'),
              subtitle: const Text('Gemini 2.5 Flash vision'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _visionModel = selected);
  }

  void _showAudioLockedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                'Audio locked',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isTeacher
                    ? PlanTierGating.teacherLiveRecordLockMessage()
                    : PlanTierGating.lockMessage(GatedFeature.recordLecture),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/subscription');
                  },
                  child: Text(
                    _isTeacher ? 'Buy Teacher plan — ₹2,999' : 'View Plans',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleYoutube() {
    Posthog().capture(eventName: 'home_ai_youtube_tapped');
    showYoutubeLinkDialog(context, onSubmit: (url) => _startYoutubeNotes(url));
  }

  Future<void> _startYoutubeNotes(String url) async {
    if (!AppConfig.isApiConfigured) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        const SnackBar(content: Text('API not configured — see API_SETUP.md')),
      );
      return;
    }

    if (!PlanTierGating.isFeatureUnlocked(
      currentPlanId: _planTier,
      feature: GatedFeature.youtubeLink,
    )) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(PlanTierGating.lockMessage(GatedFeature.youtubeLink)),
        ),
      );
      return;
    }

    // Soft check: min YouTube band. Server charges 10/20/40 after duration.
    if (_creditsBalance < CreditCosts.youtubeUpTo30Min) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            'Need at least ${CreditCosts.youtubeUpTo30Min} credits for YouTube Notes '
            '(longer videos cost up to ${CreditCosts.youtube60To90Min}).',
          ),
        ),
      );
      return;
    }

    String? lectureId;
    try {
      lectureId = await LectureService.instance.createLecture(
        title: 'YouTube Notes',
        sourceType: 'youtube_link',
      );
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/processing',
        arguments: {
          'lectureId': lectureId,
          'retryYoutubeUrl': url,
          'retrySourceType': 'youtube_link',
        },
      );

      await LectureService.instance.invokeYoutubeProcessing(
        lectureId: lectureId,
        youtubeUrl: url,
      );
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (lectureId != null) {
        await LectureService.instance.markErrorUnlessDone(lectureId, msg);
      } else if (mounted) {
        AppToast.showSnackBar(
          context,
          SnackBar(content: Text(lectureUserMessage(e))),
        );
      }
    }
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

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _conversationLanguage = null;
      _homeAiSessionId = null;
      _liveStreamText = null;
      _isSending = false;
    });
    _sessionMessages = [];
    _sessionLanguage = null;
    _sessionHomeAiId = null;
    UiSessionStore.instance.saveHomeChat([]);
    UiSessionStore.instance.saveHomeSessionId(null);
  }

  Future<void> _openStudyHistory() async {
    final id = await showHomeAiHistorySheet(context);
    if (id == null || id.isEmpty || !mounted) return;
    await _restoreStudySession(id);
  }

  HomeChipUiState _chipStateFromServer(String? status, bool hasPayload) {
    final s = (status ?? '').toLowerCase();
    if (s == 'generated' || hasPayload) return HomeChipUiState.generated;
    if (s == 'generating') return HomeChipUiState.loading;
    return HomeChipUiState.ready;
  }

  Future<void> _restoreStudySession(String sessionId) async {
    // Optimistic: show a loading placeholder immediately so the screen
    // never looks empty/stuck while the real history fetches.
    setState(() {
      _messages
        ..clear()
        ..add(_ChatBubble('Loading chat…', false, revealComplete: true));
      _liveStreamText = null;
      _isSending = false;
    });
    _scrollToBottom(instant: true);

    try {
      final data = await LectureService.instance.homeAiRestoreSession(
        sessionId,
      );
      if (!mounted) return;
      final msgs = data['messages'];
      if (msgs is! List) {
        AppToast.showSnackBar(
          context,
          const SnackBar(content: Text('Session has no messages.')),
        );
        return;
      }
      final bubbles = <_ChatBubble>[];
      for (final raw in msgs) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final role = m['role'] as String? ?? '';
        final text = (m['message'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;
        if (role == 'user') {
          bubbles.add(
            _ChatBubble(
              text,
              true,
              id: m['id']?.toString(),
              imageUrl: m['image_url']?.toString(),
            ),
          );
          continue;
        }
        if (role != 'assistant') continue;
        final responseId = m['response_id'] as String?;
        final trust = AiAnswerMeta.trustLine(
          answerSource: m['answer_source'] as String?,
          confidence: m['confidence'] as String?,
        );
        final toolStates = <String, HomeChipUiState>{};
        var recommended = <String>[];
        final toolsWrap = m['tools'];
        if (toolsWrap is Map) {
          final tools = toolsWrap['tools'];
          if (tools is Map) {
            for (final e in tools.entries) {
              final info = e.value;
              if (info is Map) {
                toolStates[e.key.toString()] = _chipStateFromServer(
                  info['status']?.toString(),
                  info['has_payload'] == true,
                );
              }
            }
          }
          final rec = toolsWrap['recommended'];
          if (rec is List) {
            recommended = rec.map((e) => e.toString()).toList();
          }
        }
        bubbles.add(
          _ChatBubble(
            text,
            false,
            id: m['id']?.toString(),
            showStudyActions: responseId != null && responseId.isNotEmpty,
            trustLine: trust,
            animateReveal: false,
            revealComplete: true,
            visualPayload: m['visual_payload'] is Map
                ? Map<String, dynamic>.from(m['visual_payload'] as Map)
                : null,
            responseId: responseId,
            toolStates: toolStates,
            recommendedTools: recommended,
          ),
        );
      }
      final lang = data['conversation_language'] as String?;
      setState(() {
        _messages
          ..clear()
          ..addAll(bubbles);
        _homeAiSessionId = sessionId;
        _sessionHomeAiId = sessionId;
        if (lang != null && lang.isNotEmpty) {
          _conversationLanguage = lang;
        }
        _liveStreamText = null;
        _isSending = false;
      });
      _sessionMessages = List<_ChatBubble>.from(_messages);
      _sessionLanguage = _conversationLanguage;
      await _persistChatNow();
      _scrollToBottom(instant: true);
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text('Session restored · 0 credits · no AI call'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        showLogo: true,
        userName: _userName,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Menu',
          onPressed: widget.onOpenDrawer,
        ),
        onSearchTap: Responsive.isMobile(context)
            ? null
            : () => showAppSearchOverlay(
                context,
                onOpenLecture: widget.onOpenWorkspace,
              ),
        onNewChatTap: _startNewChat,
        onNotificationTap: _openNotifications,
        notificationUnreadCount:
            NotificationInboxController.instance.unreadCount,
        trailing: [
          GlowGuideRotatingButton(
            onTap: () => Navigator.pushNamed(context, '/glow-guide'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadUserData(showSpinner: false),
              child: _messages.isEmpty && !_isSending
                  ? _buildWelcome(context)
                  : _buildConversation(context),
            ),
          ),
          BottomInputBar(
            onSend: _handleSend,
            onAttach: _handleAttach,
            onRecord: _handleRecord,
            onYoutube: _handleYoutube,
            recordLocked: !_audioUnlocked,
            isSending: _isSending,
            attachmentBytes: _pendingAttachmentBytes,
            attachmentName: _pendingAttachmentName,
            attachmentIsImage: true,
            onRemoveAttachment: _removePendingAttachment,
            selectedModel: _textModel,
            onModelChanged: _changeTextModel,
            replyText: _replySelection,
            onClearReply: () {
              if (!mounted) return;
              setState(() {
                _replySelection = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _changeTextModel(String model) {
    if (_isSending || !mounted) return;
    setState(() => _textModel = model);
  }

  Widget _buildWelcome(BuildContext context) {
    final name = _greetingName;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (name.isNotEmpty) _buildGreetingBanner(context, name),
          const SizedBox(height: 24),
          Text(
            'Got a doubt? Ask away. 🧠',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _showQuote
                ? Padding(
                    key: const ValueKey('quote'),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _dailyQuote ??
                          'Keep going — you\'re closer than you think.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.getSecondaryText(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Text(
                    key: const ValueKey('sub'),
                    'Ask anything, or record a lecture for notes.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// Welcome banner/card — "Hi, {name}" greeting shown once above the
  /// empty-chat Home screen (not in the top app bar).
  Widget _buildGreetingBanner(BuildContext context, String name) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _avatarBgColor(context),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$timeGreeting, $name 👋',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome back to Sonaxia',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _defaultStudyActions = [
    'Learn More',
    'Flashcards',
    'Quiz',
    'Revision Sheet',
    'Mind Map',
    'Cheat Sheet',
    '5 Minute Revision',
    'Important Questions',
  ];

  /// Prefer topic-related chips; keep a stable Home set (no lecture required).
  List<String> _studyActionsFor(_ChatBubble bubble) {
    final query = (_questionBefore(bubble) ?? '').toLowerCase();
    if (query.contains('quiz') || query.contains('question')) {
      return ['Learn More', 'Quiz', 'Important Questions', 'Revision Sheet'];
    }
    if (query.contains('formula') ||
        query.contains('equation') ||
        query.contains('calculate')) {
      return ['Learn More', 'Cheat Sheet', 'Flashcards', 'Quiz'];
    }
    if (query.contains('compare') ||
        query.contains('difference') ||
        query.contains('vs')) {
      return ['Learn More', 'Revision Sheet', 'Flashcards', 'Quiz'];
    }
    if (query.contains('remember') || query.contains('memorize')) {
      return ['Learn More', 'Flashcards', 'Mind Map', 'Revision Sheet'];
    }
    return _defaultStudyActions;
  }

  String? _questionBefore(_ChatBubble aiBubble) {
    final idx = _messages.indexOf(aiBubble);
    if (idx <= 0) return _lastUserQuestion();
    for (var i = idx - 1; i >= 0; i--) {
      if (_messages[i].isUser) return _messages[i].text;
    }
    return _lastUserQuestion();
  }

  String? _lastUserQuestion() {
    for (final msg in _messages.reversed) {
      if (msg.isUser) return msg.text;
    }
    return null;
  }

  int _creditsForHomeChip(String label) {
    if (label == 'Mind Map' || label == 'Important Questions') {
      return CreditCosts.homeChipMindMap;
    }
    return CreditCosts.askAiNormal;
  }

  String _homeChipFollowUp({
    required String label,
    required String? question,
    required String answer,
  }) {
    final topic = (question != null && question.trim().isNotEmpty)
        ? question.trim()
        : 'the topic in your previous answer';
    final clip = answer.length > 1200
        ? '${answer.substring(0, 1200)}…'
        : answer;

    switch (label) {
      case 'Learn More':
        return 'Learn more about: $topic\n\n'
            'Expand with key points and one clear example. '
            'Base it on this prior answer:\n$clip';
      case 'Flashcards':
        return 'From this Home AI topic "$topic", create exactly 5 flashcards '
            '(Q/A). Base them on:\n$clip\n\n'
            'Format each as **Q:** … / **A:** …';
      case 'Quiz':
        return 'From this Home AI topic "$topic", create exactly 5 MCQ questions '
            'with 4 options and mark the correct answer + short explanation. '
            'Base them on:\n$clip';
      case 'Revision Sheet':
        return 'Make a short exam revision sheet for "$topic" based on:\n$clip';
      case 'Mind Map':
        return 'Create a text mind map (tree with → and indentation) for "$topic" '
            'based on:\n$clip';
      case 'Cheat Sheet':
        return 'Make a compact one-page cheat sheet for "$topic" based on:\n$clip';
      case '5 Minute Revision':
        return 'Write a 5-minute revision skim for "$topic" based on:\n$clip';
      case 'Important Questions':
        return 'Generate 8 important exam-style questions (with brief hints, '
            'not full answers) for "$topic" based on:\n$clip';
      default:
        return 'Continue helping with: $topic\n\nPrior answer:\n$clip';
    }
  }

  Future<void> _onPhase4cChip(HomeStudyChipDef chip, _ChatBubble bubble) async {
    final messenger = ScaffoldMessenger.of(context);

    final responseId = bubble.responseId;
    if (responseId == null || responseId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Study tools aren’t ready yet. Ask a new question, then try again.',
          ),
        ),
      );
      return;
    }

    // Founder lock: chips are free from Knowledge Object (Regenerate is paid inside sheet).
    setState(() {
      bubble.toolStates[chip.toolType] = HomeChipUiState.loading;
      bubble.activeToolType = chip.toolType;
    });

    await showHomeAiPhase4cToolSheet(
      context,
      responseId: responseId,
      toolType: chip.toolType,
      title: chip.label,
      onCreditsUpdated: (balance) {
        if (!mounted) return;
        setState(() => _creditsBalance = balance);
      },
      onGenerated: () {
        if (!mounted) return;
        setState(() {
          bubble.toolStates[chip.toolType] = HomeChipUiState.generated;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      bubble.activeToolType = null;
      if (bubble.toolStates[chip.toolType] == HomeChipUiState.loading) {
        bubble.toolStates[chip.toolType] = HomeChipUiState.ready;
      }
    });
  }

  Future<void> _onStudyAction(String label, _ChatBubble bubble) async {
    // Legacy fallback only when response_id missing (pre-SQL).
    try {
      final messenger = ScaffoldMessenger.of(context);

      final needed = _creditsForHomeChip(label);
      if (_creditsBalance < needed) {
        messenger.showSnackBar(
          SnackBar(content: Text('Need at least $needed credits for $label.')),
        );
        return;
      }

      final question = _questionBefore(bubble);
      final followUp = _homeChipFollowUp(
        label: label,
        question: question,
        answer: bubble.text,
      );

      await showHomeAiToolResultSheet(
        context,
        title: label,
        query: followUp,
        lectureId: widget.openLectureId,
        conversationLanguage: _conversationLanguage,
        studyChip: label == 'Mind Map'
            ? 'mind_map'
            : label == 'Important Questions'
            ? 'important_questions'
            : null,
        onCreditsUpdated: (balance) {
          if (!mounted) return;
          setState(() => _creditsBalance = balance);
        },
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      AppToast.showSnackBar(context, SnackBar(content: Text(msg)));
    }
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
              child: AiAssistantMessage(text: _liveStreamText!, animate: false),
            );
          }
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AiThinkingBubble(),
          );
        }
        final bubble = _messages[index];
        return Padding(
          key: ValueKey(bubble.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: bubble.isUser
              ? Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (bubble.imageBytes != null &&
                            bubble.imageBytes!.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => _showAttachedImage(
                              bubble.imageBytes!,
                              bubble.imageFilename,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 260,
                                    maxHeight: 220,
                                  ),
                                  child: Image.memory(
                                    bubble.imageBytes!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (bubble.imageUrl != null &&
                            bubble.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              bubble.imageUrl!,
                              width: 260,
                              height: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _CollapsibleUserText(
                          text: bubble.text,
                          textColor: _userBubbleTextColor(context),
                          bubbleColor: _userBubbleColor(context),
                        ),
                      ],
                    ),
                  ),
                )
              : bubble.isError
              ? _buildHomeAiErrorBubble(context, bubble)
              : AiAssistantMessage(
                  key: ValueKey('ai-${bubble.id}'),
                  text: bubble.text,
                  trustLine: bubble.trustLine,
                  onSelectAi: _onHomeSelectAi,
                  animate: bubble.animateReveal && !bubble.revealComplete,
                  visualPayload: bubble.visualPayload,
                  onRevealComplete: () {
                    if (!mounted) return;
                    setState(() {
                      bubble.revealComplete = true;
                      bubble.animateReveal = false;
                    });
                    _scrollToBottom();
                  },
                  trailing:
                      (bubble.showStudyActions ||
                          bubble.suggestedQuestions.isNotEmpty)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (bubble.showStudyActions)
                              (bubble.responseId != null &&
                                      bubble.responseId!.isNotEmpty
                                  ? HomeStudyChipBar(
                                      toolStates: bubble.toolStates,
                                      activeToolType: bubble.activeToolType,
                                      recommended: bubble.recommendedTools,
                                      onTap: (chip) =>
                                          _onPhase4cChip(chip, bubble),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final label in _studyActionsFor(
                                          bubble,
                                        ))
                                          ActionChip(
                                            label: Text(
                                              label,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            onPressed: () {
                                              _onStudyAction(label, bubble);
                                            },
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    )),
                            // Pehle add kiya tha (Column ke andar):
                            if (bubble.suggestedQuestions.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _SuggestedQuestionsRow(
                                questions: bubble.suggestedQuestions,
                                onTap: (q) => _handleSend(q),
                              ),
                            ],

                            // Iske turant baad, usi Column ke andar add karo:
                            if (bubble.practiceQuestion != null) ...[
                              const SizedBox(height: 10),
                              _PracticeQuestionBox(
                                question: bubble.practiceQuestion!,
                                onSubmit: (studentAnswer) {
                                  final wrapped =
                                      'PRACTICE ANSWER CHECK — you asked '
                                      'this practice question: "${bubble.practiceQuestion}" '
                                      '(based on your explanation: '
                                      '"${bubble.text.length > 600 ? bubble.text.substring(0, 600) : bubble.text}"). '
                                      'The student answered: "$studentAnswer". '
                                      'Judge it like a teacher per the '
                                      'JUDGING MODE rules.';
                                  _handleSend(wrapped);
                                },
                              ),
                            ],
                          ],
                        )
                      : null,
                ),
        );
      },
    );
  }

  Future<void> _showAttachedImage(Uint8List bytes, String? filename) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Close image',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (filename != null && filename.isNotEmpty)
              Positioned(
                left: 8,
                bottom: 8,
                child: Text(
                  filename,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeAiErrorBubble(BuildContext context, _ChatBubble bubble) {
    final canRetry =
        (bubble.retryQuery != null && bubble.retryQuery!.trim().isNotEmpty) ||
        (bubble.retryVisionBytes != null &&
            bubble.retryVisionBytes!.isNotEmpty);

    final isCreditError =
        bubble.text.trim().toLowerCase() ==
        "you don’t have enough credits for this action.";

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: AppTheme.getCardBackground(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.getCardBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bubble.text,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
              if (canRetry) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isSending
                        ? null
                        : isCreditError
                        ? () => Navigator.pushNamed(context, '/subscription')
                        : () => _retryFailedBubble(bubble),
                    icon: Icon(
                      isCreditError
                          ? Icons.workspace_premium_outlined
                          : Icons.refresh,
                      size: 18,
                    ),
                    label: Text(isCreditError ? 'View Plans' : 'Retry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    if (_notificationsSheetOpen) return;
    _notificationsSheetOpen = true;
    try {
      await NotificationInboxController.instance.refresh(
        showDesktopIfHidden: false,
      );
      final items = await NotificationService.instance.listNotifications();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('No notifications yet'))
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final n = items[i];
                              final title = n['title'] as String? ?? 'Group';
                              final body = n['body'] as String? ?? '';
                              final classId = n['class_id'] as String?;
                              final id = n['id'] as String?;
                              final unread = n['read_at'] == null;
                              return ListTile(
                                leading: Icon(
                                  () {
                                    final et = n['event_type'] as String? ?? '';
                                    if (et.startsWith('join_')) {
                                      return Icons.how_to_reg_outlined;
                                    }
                                    if (et == 'payment_success' ||
                                        et == 'payment_failed') {
                                      return Icons.payments_outlined;
                                    }
                                    if (et.startsWith('expiring_') ||
                                        et == 'expired') {
                                      return Icons.event_busy_outlined;
                                    }
                                    return Icons.groups_outlined;
                                  }(),
                                  color: unread ? AppTheme.accentColor : null,
                                ),
                                title: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                subtitle: Text(
                                  body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () async {
                                  if (id != null) {
                                    await NotificationService.instance.markRead(
                                      id,
                                    );
                                    await NotificationInboxController.instance
                                        .markReadLocally(id);
                                  }
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (classId == null || classId.isEmpty) {
                                    final eventType =
                                        n['event_type'] as String? ?? '';
                                    if (eventType.startsWith('expiring_') ||
                                        eventType == 'expired' ||
                                        eventType == 'payment_success' ||
                                        eventType == 'payment_failed') {
                                      Navigator.pushNamed(
                                        context,
                                        '/subscription',
                                      );
                                    }
                                    return;
                                  }
                                  final eventType =
                                      n['event_type'] as String? ?? '';
                                  if (eventType == 'join_pending_teacher') {
                                    Navigator.pushNamed(
                                      context,
                                      '/group_dashboard',
                                      arguments: {
                                        'classId': classId,
                                        'name': title,
                                      },
                                    );
                                  } else if (eventType.startsWith(
                                        'expiring_',
                                      ) ||
                                      eventType == 'expired' ||
                                      eventType == 'payment_success' ||
                                      eventType == 'payment_failed') {
                                    Navigator.pushNamed(
                                      context,
                                      '/subscription',
                                    );
                                  } else {
                                    Navigator.pushNamed(
                                      context,
                                      '/group_info',
                                      arguments: {'groupId': classId},
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (mounted) {
        await NotificationInboxController.instance.refresh(
          showDesktopIfHidden: false,
        );
      }
    } finally {
      _notificationsSheetOpen = false;
    }
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sonaxia',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.bolt_outlined),
                    title: const Text('Credits'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/credits/history');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: const Text('Recent chats'),
                    onTap: () {
                      Navigator.pop(context);
                      _openStudyHistory();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.visibility_outlined),
                    title: const Text('Vision model'),
                    subtitle: Text(
                      _visionModel == 'gemini' ? 'Gemini' : 'Qwen-VL',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _chooseVisionModel();
                    },
                  ),
                  if (_isTeacher)
                    ListTile(
                      leading: const Icon(Icons.school_rounded),
                      title: const Text('Teacher Dashboard'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/teacher');
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onGoToTab(4);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSending
                      ? null
                      : () {
                          Navigator.pop(context);
                          _startNewChat();
                        },
                  icon: const Icon(Icons.add_comment_rounded, size: 18),
                  label: const Text('New chat'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Text(
                'Sonaxia can make mistakes. Check important info.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>>? _recentSessions;
  bool _loadingSessions = false;

  Future<void> _loadRecentSessionsForDrawer() async {
    if (_loadingSessions) return;
    setState(() => _loadingSessions = true);
    try {
      final sessions = await LectureService.instance.homeAiListSessions(
        limit: 15,
      );
      if (!mounted) return;
      setState(() {
        _recentSessions = sessions;
        _loadingSessions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSessions = false);
    }
  }

  Widget _buildMobileDrawer(BuildContext context) {
    if (_recentSessions == null && !_loadingSessions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRecentSessionsForDrawer();
      });
    }
    final iconColor = AppTheme.getPrimaryText(context);

    return Drawer(
      width: 260,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sonaxia',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSending
                      ? null
                      : () {
                          Navigator.pop(context);
                          _startNewChat();
                        },
                  icon: const Icon(Icons.add_comment_rounded, size: 16),
                  label: const Text('New chat', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: iconColor,
                    ),
                    title: const Text(
                      'Library',
                      style: TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onGoToTab(1);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.groups_outlined,
                      size: 20,
                      color: iconColor,
                    ),
                    title: const Text('Groups', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onGoToTab(2);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.trending_up_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                    title: const Text(
                      'Progress',
                      style: TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onGoToTab(3);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.person_outline,
                      size: 20,
                      color: iconColor,
                    ),
                    title: const Text(
                      'Profile',
                      style: TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onGoToTab(4);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.bolt_outlined,
                      size: 20,
                      color: iconColor,
                    ),
                    title: const Text(
                      'Credits',
                      style: TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/credits/history');
                    },
                  ),
                  if (_isTeacher)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        Icons.school_rounded,
                        size: 20,
                        color: iconColor,
                      ),
                      title: const Text(
                        'Teacher Dashboard',
                        style: TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/teacher');
                      },
                    ),
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Text(
                      'RECENT CHATS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_loadingSessions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_recentSessions == null || _recentSessions!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'No chats yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                      ),
                    )
                  else
                    for (final s in _recentSessions!)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: iconColor,
                        ),
                        title: Text(
                          (s['title'] as String?)?.trim().isNotEmpty == true
                              ? s['title'] as String
                              : 'Untitled chat',
                          style: const TextStyle(fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          final id = s['id']?.toString();
                          if (id != null && id.isNotEmpty) {
                            await _restoreStudySession(id);
                          }
                        },
                      ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 10,
              ),
              child: Text(
                'Sonaxia can make mistakes. Check important info.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  fontSize: 10.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    AppToast.showSnackBar(
      context,
      SnackBar(content: Text('$feature — coming soon')),
    );
  }
}

class _UploadOptionsSheet extends StatelessWidget {
  /// Workspace flows (PDF / audio) — recording setup.
  final ValueChanged<String> onOptionSelected;

  /// Home AI — camera photo → chat answer (not workspace).
  final VoidCallback onHomeVisionCamera;

  /// Home AI — gallery / file image → chat answer (not workspace).
  final VoidCallback onHomeVisionGallery;
  final bool audioLocked;
  final VoidCallback? onAudioLocked;

  /// Teachers: no audio-file upload into lecture pipeline.
  final bool hideAudioUpload;

  const _UploadOptionsSheet({
    required this.onOptionSelected,
    required this.onHomeVisionCamera,
    required this.onHomeVisionGallery,
    this.audioLocked = false,
    this.onAudioLocked,
    this.hideAudioUpload = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.getCardBorder(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Add content',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Camera & Image → Home AI answer · ${CreditCosts.homeAiVision} credits',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getSecondaryText(context),
              ),
            ),
            const SizedBox(height: 10),
            _homeOption(
              context,
              Icons.photo_camera_outlined,
              'Camera',
              'Take photo → Home AI explains',
              onHomeVisionCamera,
            ),
            _homeOption(
              context,
              Icons.image_outlined,
              'Upload Image',
              'Pick photo/diagram → Home AI explains',
              onHomeVisionGallery,
            ),
            const Divider(height: 16),
            _option(
              context,
              Icons.picture_as_pdf_outlined,
              'PDF Document',
              'uploadDocument',
              subtitle: 'Creates Notes in Study Workspace',
            ),
            if (!hideAudioUpload)
              _option(
                context,
                Icons.mic_outlined,
                'Audio File',
                'uploadAudio',
                locked: audioLocked,
              ),
          ],
        ),
      ),
    );
  }

  Widget _homeOption(
    BuildContext context,
    IconData icon,
    String label,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      dense: true,
      leading: Icon(icon, color: AppTheme.getPrimaryText(context), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
    );
  }

  Widget _option(
    BuildContext context,
    IconData icon,
    String label,
    String inputMethod, {
    bool locked = false,
    String? subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      dense: true,
      leading: Icon(icon, color: AppTheme.getPrimaryText(context), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: locked ? const Icon(Icons.lock_outline, size: 18) : null,
      onTap: () {
        if (locked) {
          onAudioLocked?.call();
          return;
        }
        onOptionSelected(inputMethod);
      },
    );
  }
}

/// User's long question collapses to 2 lines with a "more" toggle —
/// keeps long pasted questions from pushing the chat down (Claude-style).
class _CollapsibleUserText extends StatefulWidget {
  final String text;
  final Color textColor;
  final Color bubbleColor;

  const _CollapsibleUserText({
    required this.text,
    required this.textColor,
    required this.bubbleColor,
  });

  @override
  State<_CollapsibleUserText> createState() => _CollapsibleUserTextState();
}

class _CollapsibleUserTextState extends State<_CollapsibleUserText> {
  bool _expanded = false;
  static const int _collapsedLines = 2;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: widget.textColor,
      fontSize: 15.5,
      height: 1.5,
      letterSpacing: 0.1,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.text, style: style);
        final tp = TextPainter(
          text: span,
          maxLines: _collapsedLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth - 32);
        final isOverflowing = tp.didExceedMaxLines;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.bubbleColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                widget.text,
                style: style,
                maxLines: _expanded ? null : _collapsedLines,
              ),
              if (isOverflowing) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                      color: widget.textColor.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// AI-suggested follow-up question chips — reveal one at a time
/// (teacher-style "ek baat, phir agli"), not all at once.
class _SuggestedQuestionsRow extends StatefulWidget {
  final List<String> questions;
  final ValueChanged<String> onTap;

  const _SuggestedQuestionsRow({required this.questions, required this.onTap});

  @override
  State<_SuggestedQuestionsRow> createState() => _SuggestedQuestionsRowState();
}

class _SuggestedQuestionsRowState extends State<_SuggestedQuestionsRow> {
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _revealNext();
  }

  void _revealNext() {
    if (!mounted || _visibleCount >= widget.questions.length) return;
    Future.delayed(Duration(milliseconds: _visibleCount == 0 ? 200 : 350), () {
      if (!mounted) return;
      setState(() => _visibleCount++);
      _revealNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _visibleCount; i++)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => widget.onTap(widget.questions[i]),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.getCardBorder(context)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.questions[i],
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Teacher-style practice check — question + answer box + submit.
class _PracticeQuestionBox extends StatefulWidget {
  final String question;
  final ValueChanged<String> onSubmit;

  const _PracticeQuestionBox({required this.question, required this.onSubmit});

  @override
  State<_PracticeQuestionBox> createState() => _PracticeQuestionBoxState();
}

class _PracticeQuestionBoxState extends State<_PracticeQuestionBox> {
  final TextEditingController _controller = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitted) return;
    setState(() => _submitted = true);
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school_outlined,
                size: 16,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Quick check',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: AppTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.question,
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          if (!_submitted)
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Type your answer…',
                isDense: true,
                filled: true,
                fillColor: AppTheme.getCardBackground(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  onPressed: _submit,
                ),
              ),
              onSubmitted: (_) => _submit(),
            )
          else
            Text(
              'Answer sent — check the reply below.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getSecondaryText(context),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
