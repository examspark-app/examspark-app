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
import 'package:examspark_frontend/core/errors/lecture_user_message.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/home_ask_bridge.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/services/ui_session_store.dart';
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
  /// In-memory photo for this session's user bubble (not persisted to disk).
  final Uint8List? imageBytes;
  final String? imageFilename;
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
    this.imageBytes,
    this.imageFilename,
    this.retryVisionBytes,
    this.retryVisionFilename,
  })  : id = id ?? UniqueKey().toString(),
        toolStates = toolStates ?? {},
        recommendedTools = recommendedTools ?? [],
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
  List<Map<String, dynamic>> _recentLectures = [];
  final List<_ChatBubble> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  bool _isSending = false;
  /// Locked after first successful turn (HINDI/BENGALI/ENGLISH/HINGLISH).
  String? _conversationLanguage;
  /// Phase 4D — active Study Session (Supabase).
  String? _homeAiSessionId;
  /// Live SSE tokens while waiting (null = still thinking).
  String? _liveStreamText;
  Timer? _persistDebounce;
  bool _restoredDisk = false;

  bool get _audioUnlocked => PlanTierGating.isFeatureUnlocked(
        currentPlanId: _planTier,
        feature: GatedFeature.recordLecture,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_sessionMessages != null && _sessionMessages!.isNotEmpty) {
      _messages.addAll(_sessionMessages!);
      _conversationLanguage = _sessionLanguage;
      _homeAiSessionId = _sessionHomeAiId;
    }
    SessionLiveSync.instance.addListener(_onSessionLive);
    HomeAskBridge.instance.addListener(_onHomeAskBridge);
    _loadUserData();
    _applySessionLive();
    // In case Ask AI was queued before Home mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreChatFromDisk();
      _onHomeAskBridge();
    });
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
    final storedSession =
        await UiSessionStore.instance.loadHomeSessionId();
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
    _scrollToBottom();
  }

  void _schedulePersistChat() {
    _sessionMessages = List<_ChatBubble>.from(_messages);
    _sessionLanguage = _conversationLanguage;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), _persistChatNow);
  }

  Future<void> _persistChatNow() async {
    _sessionMessages = List<_ChatBubble>.from(_messages);
    _sessionLanguage = _conversationLanguage;
    _sessionHomeAiId = _homeAiSessionId;
    final rows = _messages.map((m) {
      return <String, dynamic>{
        'id': m.id,
        'text': m.text,
        'isUser': m.isUser,
        'showStudyActions': m.showStudyActions,
        'trustLine': m.trustLine,
        'visualPayload': m.visualPayload,
        'responseId': m.responseId,
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
    final pending = HomeAskBridge.instance.takePending();
    if (pending == null || pending.isEmpty) return;
    if (!mounted) return;
    _handleSend(pending);
  }

  /// Select text → Ask AI → next Home chat question + reply (no sheet).
  Future<void> _onHomeSelectAi(String actionId, String selectedText) async {
    final selected = selectedText.trim();
    if (selected.isEmpty) return;

    if (_creditsBalance < CreditCosts.askAiNormal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need at least ${CreditCosts.askAiNormal} credits (Home AI).',
          ),
        ),
      );
      return;
    }

    final prompt = homeAskPromptFromSelection(selected, actionId: actionId);
    if (prompt.isEmpty) return;
    await _handleSend(prompt);
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _persistChatNow();
    WidgetsBinding.instance.removeObserver(this);
    HomeAskBridge.instance.removeListener(_onHomeAskBridge);
    SessionLiveSync.instance.removeListener(_onSessionLive);
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
      var plan = 'free';
      try {
        plan = await SupabaseClient.instance.getPlanTier(user.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _creditsBalance = profile?['credits_balance'] as int? ?? 0;
        _userName = (profile?['full_name'] as String?) ?? user.email ?? 'User';
        _planTier = plan;
        _recentLectures = lectures.take(5).toList();
        _isRefreshing = false;
      });
    } catch (_) {
      // Non-fatal: home still works without profile/lecture data.
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String? _lastAiResponseId() {
    for (final msg in _messages.reversed) {
      if (!msg.isUser &&
          msg.responseId != null &&
          msg.responseId!.isNotEmpty) {
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
    final query = text.trim();
    if (query.isEmpty || _isSending) return;

    final parentId =
        _looksLikeFollowUp(query) ? _lastAiResponseId() : null;

    setState(() {
      _isSending = true;
      _liveStreamText = null;
      if (isRetry) {
        _removeTrailingErrorBubbles();
      } else {
        _messages.add(_ChatBubble(query, true));
      }
    });
    _schedulePersistChat();
    _scrollToBottom();

    try {
      await _runHomeAiStream(
        query,
        studyChip: studyChip,
        parentResponseId: parentId,
      );
    } catch (_) {
      // Stream failed — fall back to JSON + typewriter (existing path).
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
        _addHomeAiErrorBubble(
          e,
          retryQuery: query,
        );
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
    var raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (raw.trim().toLowerCase() == 'not found') {
      raw =
          'Home AI API not found. Restart the FastAPI server, then try again.';
    }
    final msg = lectureUserMessage(raw);
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
    _schedulePersistChat();
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
        retryQuery: (visionBytes == null || visionBytes.isEmpty) ? lastUser : null,
        retryVisionBytes: visionBytes,
        retryVisionFilename: visionName,
      );
      return;
    }

    setState(() {
      if (convLang != null && convLang.isNotEmpty) {
        _conversationLanguage = convLang;
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        _homeAiSessionId = sessionId;
        _sessionHomeAiId = sessionId;
      }
      _messages.add(_ChatBubble(
        answer,
        false,
        showStudyActions: true,
        trustLine: trust,
        // Stream path already showed tokens live — never re-animate on scroll.
        animateReveal: animateReveal,
        revealComplete: !animateReveal,
        visualPayload: result['visual_payload'] is Map
            ? Map<String, dynamic>.from(result['visual_payload'] as Map)
            : null,
        responseId: responseId,
      ));
      if (newBalance is int) {
        _creditsBalance = newBalance;
      }
      _isSending = false;
      _liveStreamText = null;
    });
    _schedulePersistChat();
    _scrollToBottom();
    if (responseId != null && responseId.isNotEmpty) {
      _hydrateToolStates(responseId);
    }
  }

  Future<void> _hydrateToolStates(String responseId) async {
    try {
      final data =
          await LectureService.instance.homeAiToolStatuses(responseId);
      final tools = data['tools'];
      final recommended = (data['recommended'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
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
      _schedulePersistChat();
    } catch (_) {
      // Soft-fail — chips still work via generate endpoint.
    }
  }

  void _handleRecord() {
    if (!_audioUnlocked) {
      _showAudioLockedSheet();
      return;
    }
    Navigator.pushNamed(context, '/recorder');
  }

  void _handleAttach() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _UploadOptionsSheet(
        audioLocked: !_audioUnlocked,
        onAudioLocked: () {
          Navigator.pop(sheetContext);
          _showAudioLockedSheet();
        },
        onHomeVisionCamera: () {
          Navigator.pop(sheetContext);
          _pickHomeVisionImage(fromCamera: true);
        },
        onHomeVisionGallery: () {
          Navigator.pop(sheetContext);
          _pickHomeVisionImage(fromCamera: false);
        },
        onOptionSelected: (inputMethod) {
          Navigator.pop(sheetContext);
          Navigator.pushNamed(
            context,
            '/recorder',
            arguments: {'initialInputMethod': inputMethod},
          );
        },
      ),
    );
  }

  Future<void> _pickHomeVisionImage({required bool fromCamera}) async {
    if (!AppConfig.isApiConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API not configured — see API_SETUP.md')),
      );
      return;
    }
    if (!PlanTierGating.isFeatureUnlocked(
      currentPlanId: _planTier,
      feature: GatedFeature.diagramAnalysis,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PlanTierGating.lockMessage(GatedFeature.diagramAnalysis)),
        ),
      );
      return;
    }
    if (_creditsBalance < CreditCosts.homeAiVision) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read image. Try again.')),
        );
        return;
      }
      if (bytes.length > 8 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large (max 8 MB).')),
        );
        return;
      }

      await _sendHomeVision(bytes, filename);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _sendHomeVision(
    Uint8List bytes,
    String filename, {
    bool isRetry = false,
  }) async {
    final label = '📷 Photo Ask · $filename';
    setState(() {
      _isSending = true;
      _liveStreamText = null;
      if (isRetry) {
        _removeTrailingErrorBubbles();
      } else {
        _messages.add(
          _ChatBubble(
            label,
            true,
            imageBytes: bytes,
            imageFilename: filename,
          ),
        );
      }
    });
    _schedulePersistChat();
    _scrollToBottom();

    try {
      final result = await LectureService.instance.homeAiVision(
        imageBytes: bytes,
        filename: filename,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(PlanTierGating.lockMessage(GatedFeature.recordLecture)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/subscription');
                  },
                  child: const Text('View Plans'),
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
    showYoutubeLinkDialog(
      context,
      onSubmit: (url) => _startYoutubeNotes(url),
    );
  }

  Future<void> _startYoutubeNotes(String url) async {
    if (!AppConfig.isApiConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API not configured — see API_SETUP.md')),
      );
      return;
    }

    if (!PlanTierGating.isFeatureUnlocked(
      currentPlanId: _planTier,
      feature: GatedFeature.youtubeLink,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PlanTierGating.lockMessage(GatedFeature.youtubeLink))),
      );
      return;
    }

    // Soft check: min YouTube band. Server charges 10/20/40 after duration.
    if (_creditsBalance < CreditCosts.youtubeUpTo30Min) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
    try {
      final data =
          await LectureService.instance.homeAiRestoreSession(sessionId);
      if (!mounted) return;
      final msgs = data['messages'];
      if (msgs is! List) {
        ScaffoldMessenger.of(context).showSnackBar(
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
          bubbles.add(_ChatBubble(text, true, id: m['id']?.toString()));
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
            showStudyActions:
                responseId != null && responseId.isNotEmpty,
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
      _scrollToBottom();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session restored · 0 credits · no AI call'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
        creditsBalance: _creditsBalance,
        userName: _userName,
        onSearchTap: () => _showComingSoon('Search'),
        onNotificationTap: () => _showComingSoon('Notifications'),
        onCreditsTap: () => Navigator.pushNamed(context, '/credits/history'),
        onProfileTap: () => widget.onGoToTab(4),
        trailing: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Study History',
            onPressed: _isSending ? null : _openStudyHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: _isSending ? null : _startNewChat,
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh library',
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
            recordLocked: !_audioUnlocked,
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
                  dateLabel: formatOpenedAtLabel(
                    lecture['last_opened_at'] ?? lecture['created_at'],
                  ),
                  onTap: () => _openLecture(lecture),
                ),
              ),
          ],
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
    // Same set for every Home reply — actions always run against THIS reply's topic.
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
    final clip = answer.length > 1200 ? '${answer.substring(0, 1200)}…' : answer;

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
            'Phase 4C SQL not ready — run home_ai_phase4c_migration.sql, restart backend, ask again.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
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
          key: ValueKey(bubble.id),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (bubble.imageBytes != null &&
                              bubble.imageBytes!.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 8),
                          ],
                          SelectableText(
                            bubble.text,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : bubble.isError
                  ? _buildHomeAiErrorBubble(context, bubble)
                  : AiAssistantMessage(
                      key: ValueKey('ai-${bubble.id}'),
                      text: bubble.text,
                      trustLine: bubble.trustLine,
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
                      trailing: bubble.showStudyActions
                          ? (bubble.responseId != null &&
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
                                    for (final label
                                        in _studyActionsFor(bubble))
                                      ActionChip(
                                        label: Text(
                                          label,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () {
                                          _onStudyAction(label, bubble);
                                        },
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ))
                          : null,
                    ),
        );
      },
    );
  }

  Widget _buildHomeAiErrorBubble(BuildContext context, _ChatBubble bubble) {
    final canRetry = (bubble.retryQuery != null &&
            bubble.retryQuery!.trim().isNotEmpty) ||
        (bubble.retryVisionBytes != null &&
            bubble.retryVisionBytes!.isNotEmpty);
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
                    Icons.wifi_off_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bubble.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                    ),
                  ),
                ],
              ),
              if (canRetry) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        _isSending ? null : () => _retryFailedBubble(bubble),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
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

  const _UploadOptionsSheet({
    required this.onOptionSelected,
    required this.onHomeVisionCamera,
    required this.onHomeVisionGallery,
    this.audioLocked = false,
    this.onAudioLocked,
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
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
      subtitle: locked
          ? const Text('₹499+ Plan', style: TextStyle(fontSize: 12))
          : (subtitle != null
              ? Text(subtitle, style: const TextStyle(fontSize: 12))
              : null),
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
