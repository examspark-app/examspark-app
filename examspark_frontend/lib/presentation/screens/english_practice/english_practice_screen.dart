import 'dart:async';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_language_picker_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_drawer.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/roleplay_screen.dart';

class _Message {
  const _Message(this.text, this.isUser);
  final String text;
  final bool isUser;
}

class _ChatProcessingIndicator extends StatefulWidget {
  const _ChatProcessingIndicator({required this.voice});

  final bool voice;

  @override
  State<_ChatProcessingIndicator> createState() =>
      _ChatProcessingIndicatorState();
}

class _ChatProcessingIndicatorState extends State<_ChatProcessingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5137ED);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final activeDot = (_controller.value * 3).floor();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.voice
                      ? Icons.graphic_eq_rounded
                      : Icons.auto_awesome_rounded,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.voice ? 'Converting speech' : 'Thinking',
                  style: TextStyle(
                    color: AppTheme.getSecondaryText(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: AnimatedScale(
                      scale: activeDot == i ? 1.35 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: activeDot == i ? 1 : .45,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PracticeMcq {
  const _PracticeMcq({
    required this.question,
    required this.options,
    required this.correctOption,
  });
  final String question;
  final List<String> options;
  final int correctOption;

  static _PracticeMcq? fromJson(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final question = data['question']?.toString().trim() ?? '';
    final rawOptions = data['options'];
    final correct = data['correct_option'];
    if (question.isEmpty) return null;
    if (rawOptions is! List) return null;
    final options = rawOptions
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (options.length != 3) return null;
    if (correct is! int || correct < 0 || correct > 2) return null;
    return _PracticeMcq(
      question: question,
      options: options,
      correctOption: correct,
    );
  }
}

class EnglishPracticeScreen extends StatefulWidget {
  const EnglishPracticeScreen({
    super.key,
    this.sessionId,
    this.resumeLatest = false,
    this.textModel = 'qwen3',
  });
  final String? sessionId;
  final bool resumeLatest;
  final String textModel;

  static bool shouldResumeLatestSession({
    required bool resumeLatest,
    required String? sessionId,
    required int requestId,
    required int activeRequestId,
    bool cancelled = false,
  }) {
    return !cancelled &&
        resumeLatest &&
        sessionId == null &&
        requestId == activeRequestId;
  }

  @override
  State<EnglishPracticeScreen> createState() => _EnglishPracticeScreenState();
}

class _EnglishPracticeScreenState extends State<EnglishPracticeScreen> {
  static const violet = Color(0xFF5137ED);
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  List<String> _suggestions = const [];
  _PracticeMcq? _currentMcq;
  int? _mcqSelectedIndex;
  String? _sessionId;
  bool _loading = false;
  int _latestSessionRequestId = 0;
  bool _sending = false;
  bool _recording = false;
  bool _processingVoice = false;
  Timer? _voiceTurnLimitTimer;
  String _nativeLanguage = '';
  String _targetLanguage = 'English';
  String? _error;
  bool _longChatPromptShown = false;
  bool _resumeCancelled = false;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _voiceTurnLimitTimer?.cancel();
    RecordingService.instance.releaseForScreen();
    super.dispose();
  }

  Future<void> _startFreshPracticeSession() async {
    final r = await LectureService.instance.startEnglishPractice(
      model: widget.textModel,
    );
    if (!mounted) return;
    setState(() {
      _sessionId = r['session_id'] as String?;
      _nativeLanguage = '${r['native_language'] ?? ''}';
      _targetLanguage = '${r['target_language'] ?? 'English'}';
      final greeting = '${r['greeting'] ?? ''}'.trim();
      _messages
        ..clear()
        ..add(
          _Message(
            greeting.isEmpty
                ? 'Welcome! Let’s begin with a small English practice step.'
                : greeting,
            false,
          ),
        );
      _suggestions = List<String>.from(r['suggestions'] as List? ?? const []);
      final mcq = _PracticeMcq.fromJson(r['mcq']);
      if (mcq != null) _currentMcq = mcq;
      _loading = false;
    });
    _bottom();
  }

  Future<void> _openNewChatSetup() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EnglishLanguagePickerScreen()),
    );
  }

  Future<void> _restoreExistingSession(String sessionId) async {
    final r = await LectureService.instance.restoreEnglishPracticeSession(
      sessionId,
    );
    if (!mounted) {
      return;
    }
    final language = await LectureService.instance.getEnglishPracticeLanguage();
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionId = r['id'] as String?;
      _nativeLanguage = language ?? '';
      _targetLanguage = '${r['target_language'] ?? 'English'}';
      _messages
        ..clear()
        ..addAll(
          (r['messages'] as List? ?? const []).map(
            (m) => _Message('${m['message'] ?? ''}', m['role'] == 'user'),
          ),
        );
      _loading = false;
    });
    _bottom();
  }

  void _invalidatePendingResume() {
    _resumeCancelled = true;
    _latestSessionRequestId++;
  }

  Future<void> _load({bool initial = false}) async {
    if (mounted) {
      setState(() {
        if (!initial) _loading = true;
        _error = null;
      });
    }
    try {
      if (initial && widget.resumeLatest && widget.sessionId == null) {
        _resumeCancelled = false;
        final requestId = ++_latestSessionRequestId;
        final sessionId = await LectureService.instance
            .getLatestActiveEnglishPracticeSession();
        if (!mounted) {
          return;
        }
        if (!EnglishPracticeScreen.shouldResumeLatestSession(
          resumeLatest: widget.resumeLatest,
          sessionId: widget.sessionId,
          requestId: requestId,
          activeRequestId: _latestSessionRequestId,
          cancelled: _resumeCancelled,
        )) {
          return;
        }
        if (sessionId == null) {
          await _openNewChatSetup();
          return;
        }
        await _restoreExistingSession(sessionId);
        return;
      }

      var sessionId = widget.sessionId;
      if (sessionId == null && widget.resumeLatest) {
        sessionId = await LectureService.instance
            .getLatestActiveEnglishPracticeSession();
      }
      if (sessionId == null) {
        await _startFreshPracticeSession();
      } else {
        await _restoreExistingSession(sessionId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients)
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
  });
  Future<void> _send([String? prompt]) async {
    final value = (prompt ?? _text.text).trim();
    if (value.isEmpty || _sending || _sessionId == null) return;

    _text.clear();

    setState(() {
      _messages.add(_Message(value, true));
      _currentMcq = null;
      _sending = true;
      _processingVoice = false;
    });

    _bottom();

    try {
      final r = await LectureService.instance.sendEnglishPracticeMessage(
        sessionId: _sessionId!,
        message: value,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(_Message('${r['reply'] ?? ''}', false));

        final s = List<String>.from(r['suggestions'] as List? ?? const []);

        if (s.isNotEmpty) {
          _suggestions = s;
        }

        final mcq = _PracticeMcq.fromJson(r['mcq']);
        _currentMcq = mcq;
        _mcqSelectedIndex = null;

        _sending = false;
        _processingVoice = false;
        if (r['suggest_new_chat'] == true && !_longChatPromptShown) {
          _longChatPromptShown = true;
        }
      });

      if (r['suggest_new_chat'] == true && mounted) {
        _showLongChatPrompt();
      }

      _bottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _processingVoice = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _roleplay() async {
    final user = SupabaseClient.instance.currentUser;
    if (user == null) return;

    try {
      final profile = await SupabaseClient.instance.getUserProfile(user.id);
      final balance = (profile?['credits_balance'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (balance < CreditCosts.roleplayMinimumCredits) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Credits needed for Roleplay'),
            content: Text(
              'You need at least ${CreditCosts.roleplayMinimumCredits} credits to start Roleplay. You currently have $balance credits.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushNamed(context, '/subscription');
                },
                child: const Text('Purchase credits'),
              ),
            ],
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoleplaySetupScreen(
            chatSessionId: _sessionId,
            nativeLanguage: _nativeLanguage,
            targetLanguage: _targetLanguage,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check your credits. Please try again.'),
        ),
      );
    }
  }

  Future<void> _changeHelpLanguage() async {
    if (_nativeLanguage.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Language?'),
        content: const Text(
          'Changing your language will create a new chat. Your current conversation will stay in History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create New Chat'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final selected = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const EnglishLanguagePickerScreen(returnToPrevious: true),
      ),
    );
    if (!mounted || selected == null) return;
    // A Chat session stores its explanation language. Create a fresh session
    // so the next model turn immediately uses the newly selected language;
    // the previous conversation remains available in History.
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EnglishPracticeScreen(
          textModel: selected['model'] == 'gemini' ? 'gemini' : 'qwen3',
        ),
      ),
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (_sending || _sessionId == null) return;
    if (!_recording) {
      try {
        await RecordingService.instance.start();
        if (mounted) {
          setState(() => _recording = true);
          _voiceTurnLimitTimer?.cancel();
          _voiceTurnLimitTimer = Timer(const Duration(seconds: 60), () {
            if (mounted && _recording && !_sending) {
              _toggleVoiceInput();
            }
          });
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Microphone could not start: $error')),
          );
        }
      }
      return;
    }

    setState(() {
      _recording = false;
      _sending = true;
      _processingVoice = true;
    });
    _voiceTurnLimitTimer?.cancel();
    _voiceTurnLimitTimer = null;
    try {
      // When amplitude monitoring is available, reject silence locally before
      // an upload. On platforms without amplitude support the server performs
      // the same transcript validation before any credit/Qwen call.
      final detectedVoice = RecordingService.instance.heardAnyVoice;
      final canMeasureVoice =
          RecordingService.instance.amplitudeMonitoringActive;
      final path = await RecordingService.instance.stop();
      final audio = await RecordingService.instance.readRecordingBytes(path);
      await RecordingService.instance.discardTemporaryRecording(path);
      if (canMeasureVoice && !detectedVoice) {
        throw StateError('No speech detected. Please try again.');
      }
      if (audio == null || audio.isEmpty) {
        throw StateError('No speech was recorded. Please try again.');
      }
      final response = await LectureService.instance.sendEnglishPracticeAudio(
        sessionId: _sessionId!,
        audioBytes: audio,
        filename: 'english_chat_turn.m4a',
      );
      if (!mounted) return;
      setState(() {
        _currentMcq = null;
        _messages.add(_Message('${response['transcript'] ?? ''}', true));
        _messages.add(_Message('${response['reply'] ?? ''}', false));
        final suggestions = List<String>.from(
          response['suggestions'] as List? ?? const [],
        );
        if (suggestions.isNotEmpty) _suggestions = suggestions;
        final mcq = _PracticeMcq.fromJson(response['mcq']);
        _currentMcq = mcq;
        _mcqSelectedIndex = null;
        _sending = false;
        _processingVoice = false;
      });
      if (response['suggest_new_chat'] == true &&
          !_longChatPromptShown &&
          mounted) {
        _longChatPromptShown = true;
        _showLongChatPrompt();
      }
      _bottom();
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _processingVoice = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showLongChatPrompt() async {
    final startNew = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a fresh chat?'),
        content: const Text(
          'This conversation is getting long. Your learning memory will carry into a new chat, but this transcript will stay in History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep chatting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('New Chat'),
          ),
        ],
      ),
    );
    if (startNew == true && mounted) {
      await _newChat();
    }
  }

  Future<void> _answerMcq(int index) async {
    final mcq = _currentMcq;
    if (mcq == null || _mcqSelectedIndex != null || _sending) return;
    setState(() => _mcqSelectedIndex = index);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || _currentMcq != mcq || _mcqSelectedIndex != index) return;
    await _send(mcq.options[index]);
  }

  Future<void> _newChat() async {
    if (!mounted) return;
    _invalidatePendingResume();
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EnglishLanguagePickerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    drawer: EnglishPracticeDrawer(
      nativeLanguage: _nativeLanguage,
      targetLanguage: _targetLanguage,
      onChangeLanguage: _changeHelpLanguage,
      onNewChat: _newChat,
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: violet))
          : _error != null
          ? Center(
              child: ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            )
          : Column(
              children: [
                _header(),
                Expanded(child: _chat()),
                _suggestionPanel(),
                _input(),
                _practiceMcqPanel(),
                _tabs(),
              ],
            ),
    ),
  );
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 30),
            tooltip: 'Open menu',
          ),
        ),
        const Spacer(),
      ],
    ),
  );
  Widget _chat() => Stack(
    children: [
      ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
        itemCount: _messages.length + (_sending ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _messages.length)
            return Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ChatProcessingIndicator(voice: _processingVoice),
              ),
            );
          final m = _messages[i];
          return Align(
            alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .76,
              ),
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: m.isUser ? violet : AppTheme.getCardBackground(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(m.isUser ? 20 : 6),
                  bottomRight: Radius.circular(m.isUser ? 6 : 20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SelectionArea(
                child: Text(
                  m.text,
                  style: TextStyle(
                    color: m.isUser
                        ? Colors.white
                        : AppTheme.getPrimaryText(context),
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      Positioned(
        right: 20,
        bottom: 0,
        child: InkWell(
          onTap: _roleplay,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 94,
            height: 94,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6F56FF), Color(0xFF3020BF)],
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nights_stay_rounded, color: Colors.white, size: 36),
                Text(
                  'Roleplay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Widget _suggestionPanel() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    final count = _suggestions.length > 2 ? 2 : _suggestions.length;
    final icons = [
      Icons.edit_outlined,
      Icons.menu_book_outlined,
      Icons.edit_note_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.record_voice_over_outlined,
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E5F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < count; i++)
                InkWell(
                  onTap: () => _send(_suggestions[i]),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .43,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E1ED)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Icon(icons[i], color: violet, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _suggestions[i],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _practiceMcqPanel() {
    final mcq = _currentMcq;
    if (mcq == null || _sending) return const SizedBox.shrink();
    final selectedIndex = _mcqSelectedIndex;
    final optionLetters = ['A', 'B', 'C'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8D1FF)),
        gradient: const LinearGradient(
          colors: [Color(0xFFF6F3FF), Color(0xFFEFE9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5137ED),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: violet.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz_outlined, color: violet, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      'Practice Question',
                      style: TextStyle(
                        color: violet,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _currentMcq = null),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    Icons.close_rounded,
                    color: const Color(0xFF948FB0),
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              mcq.question,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.getPrimaryText(context),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 11),
          for (var i = 0; i < mcq.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            InkWell(
              onTap: () => _answerMcq(i),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selectedIndex == null
                      ? AppTheme.getCardBackground(context)
                      : i == mcq.correctOption
                      ? const Color(0xFFE7F7EC)
                      : i == selectedIndex
                      ? const Color(0xFFFFE8E8)
                      : AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selectedIndex == null
                        ? const Color(0xFFD5D1EC)
                        : i == mcq.correctOption
                        ? const Color(0xFF40A85C)
                        : i == selectedIndex
                        ? const Color(0xFFE05252)
                        : const Color(0xFFD5D1EC),
                    width: i == mcq.correctOption || i == selectedIndex
                        ? 1.5
                        : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedIndex == null
                            ? violet.withOpacity(.10)
                            : i == mcq.correctOption
                            ? const Color(0x2640A85C)
                            : i == selectedIndex
                            ? const Color(0x26E05252)
                            : violet.withOpacity(.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        optionLetters[i],
                        style: TextStyle(
                          color: selectedIndex == null
                              ? violet
                              : i == mcq.correctOption
                              ? const Color(0xFF23813B)
                              : i == selectedIndex
                              ? const Color(0xFFB42323)
                              : violet,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        mcq.options[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getPrimaryText(context),
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (selectedIndex != null &&
                        (i == selectedIndex || i == mcq.correctOption))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          i == mcq.correctOption
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: i == mcq.correctOption
                              ? const Color(0xFF23813B)
                              : const Color(0xFFB42323),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
          if (selectedIndex != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                selectedIndex == mcq.correctOption
                    ? 'Correct! Your answer is right.'
                    : 'Not quite. The highlighted green sentence is correct.',
                style: TextStyle(
                  color: selectedIndex == mcq.correctOption
                      ? const Color(0xFF23813B)
                      : const Color(0xFFB42323),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (selectedIndex != null) const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              'Tap an option above, or type your own answer below · Always optional',
              style: TextStyle(
                color: AppTheme.getSecondaryText(context).withOpacity(.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        _circle(
          _recording ? Icons.stop_rounded : Icons.mic_none_rounded,
          _toggleVoiceInput,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _text,
            onSubmitted: (_) => _send(),
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              filled: true,
              fillColor: AppTheme.getCardBackground(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _circle(Icons.send_rounded, _send),
      ],
    ),
  );
  Widget _circle(IconData icon, VoidCallback tap) => Material(
    color: violet,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: tap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(icon, color: Colors.white, size: 27),
      ),
    ),
  );
  Widget _tabs() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: violet, width: 3)),
            ),
            child: const Column(
              children: [
                Text(
                  '☁  Chat Mode',
                  style: TextStyle(color: violet, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Learn & Improve',
                  style: TextStyle(color: violet, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: _roleplay,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    '♧  Roleplay Mode',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Speak & Practice',
                    style: TextStyle(color: Color(0xFF73738A), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
