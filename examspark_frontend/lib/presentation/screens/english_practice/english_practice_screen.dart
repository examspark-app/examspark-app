import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_language_picker_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_drawer.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/roleplay_screen.dart';
import 'package:examspark_frontend/presentation/widgets/ai_model_selector.dart';
import 'package:examspark_frontend/presentation/widgets/glow_guide_rotating_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
class _Message {
  const _Message(this.text, this.isUser, {this.imageUrl});
  final String text;
  final bool isUser;
  final String? imageUrl;
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
    final subText = AppTheme.getSecondaryText(context);
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
                    color: subText,
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

class _EnglishPracticeScreenState extends State<EnglishPracticeScreen>
  with TickerProviderStateMixin {
  static const violet = Color(0xFF5137ED);

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  List<Map<String, String>> _suggestions = const [];
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
  String _selectedTextModel = 'qwen3';
  static const _modelPrefsKey = 'english_practice_preferred_model';

  bool _voiceActive = false;
  late AnimationController _waveController;
  final Random _random = Random();

    @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat();
    RecordingService.instance.setVoiceActivityListener((active) {
      if (mounted) {
        setState(() => _voiceActive = active);
      }
    });
    _loadSavedModelThenStart();
  }

  Future<void> _loadSavedModelThenStart() async {
    // Explicit textModel argument (e.g. from language picker) always wins.
    // Otherwise fall back to the user's last-saved preference.
    if (widget.textModel != 'qwen3') {
      _selectedTextModel = widget.textModel;
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_modelPrefsKey);
        if (saved == 'qwen3' || saved == 'gemini' || saved == 'claude') {
          _selectedTextModel = saved!;
        }
      } catch (_) {
        // Local pref read failed — default 'qwen3' is already set.
      }
    }
    if (mounted) setState(() {});
    await _load(initial: true);
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _voiceTurnLimitTimer?.cancel();
    _waveController.dispose();
    RecordingService.instance.setVoiceActivityListener(null);
    RecordingService.instance.releaseForScreen();
    super.dispose();
  }

  Future<void> _startFreshPracticeSession() async {
    final r = await LectureService.instance.startEnglishPractice(
      model: _selectedTextModel,
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
            _suggestions = (r['suggestions'] as List? ?? const [])
          .whereType<Map>()
          .map((s) => {
                'text': (s['text'] ?? '').toString(),
                'pronunciation': (s['pronunciation'] ?? '').toString(),
              })
          .where((s) => s['text']!.trim().isNotEmpty)
          .toList();
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
      final savedModel = '${r['text_model'] ?? ''}';
      if (savedModel == 'qwen3' ||
          savedModel == 'gemini' ||
          savedModel == 'claude') {
        _selectedTextModel = savedModel;
      }
      _messages
        ..clear()
        ..addAll(
          (r['messages'] as List? ?? const []).map(
            (m) => _Message(
              '${m['message'] ?? ''}',
              m['role'] == 'user',
              imageUrl: m['image_url']?.toString(),
            ),
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
    MarkdownStyleSheet _markdownStyle(BuildContext context, Color primaryText) {
    final secondary = AppTheme.getSecondaryText(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const baseFontSize = 15.5;
    const baseHeight = 1.65;

    return MarkdownStyleSheet(
      p: TextStyle(
        color: primaryText,
        fontSize: baseFontSize,
        height: baseHeight,
        fontWeight: FontWeight.w400,
      ),
      h1: TextStyle(
        color: primaryText,
        fontSize: 21,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      h2: TextStyle(
        color: primaryText,
        fontSize: 18.5,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      h3: TextStyle(
        color: primaryText,
        fontSize: 16.5,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      h1Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h2Padding: const EdgeInsets.only(top: 10, bottom: 5),
      h3Padding: const EdgeInsets.only(top: 8, bottom: 4),
      strong: TextStyle(
        color: primaryText,
        fontWeight: FontWeight.w700,
        fontSize: baseFontSize,
        height: baseHeight,
      ),
      em: TextStyle(
        color: primaryText,
        fontStyle: FontStyle.italic,
        fontSize: baseFontSize,
        height: baseHeight,
      ),
      listBullet: TextStyle(
        color: primaryText,
        fontSize: baseFontSize,
        height: baseHeight,
      ),
      listIndent: 18,
      listBulletPadding: const EdgeInsets.only(right: 8),
      blockSpacing: 8,
      code: TextStyle(
        color: primaryText,
        fontSize: baseFontSize - 1,
        fontFamily: 'monospace',
        backgroundColor: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: violet, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      tableHead: TextStyle(
        color: primaryText,
        fontWeight: FontWeight.w700,
        fontSize: baseFontSize - 1.5,
      ),
      tableBody: TextStyle(
        color: primaryText,
        fontSize: baseFontSize - 1.5,
        height: 1.4,
      ),
      tableBorder: TableBorder.all(
        color: AppTheme.getCardBorder(context),
        width: 1,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.getCardBorder(context))),
      ),
    );
  }
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
     model: _selectedTextModel,
   );

      if (!mounted) return;

      setState(() {
        _messages.add(_Message('${r['reply'] ?? ''}', false));

                final s = (r['suggestions'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => {
                  'text': (item['text'] ?? '').toString(),
                  'pronunciation': (item['pronunciation'] ?? '').toString(),
                })
            .where((item) => item['text']!.trim().isNotEmpty)
            .toList();

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

  Future<void> _pickPhoto() async {
    if (_sending || _sessionId == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    try {
      setState(() => _sending = true);
      final result = await LectureService.instance.englishPracticePhoto(
        sessionId: _sessionId!, imageBytes: bytes, filename: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_Message('Photo: ${result['reply'] ?? ''}', false));
        _sending = false;
      });
      _bottom();
    } catch (error) {
      if (mounted) setState(() => _sending = false);
      if (mounted) setState(() => _error = '$error');
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
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EnglishPracticeScreen(
          textModel: selected['model'] == 'gemini'
              ? 'gemini'
              : selected['model'] == 'claude'
              ? 'claude'
              : 'qwen3',
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_sending || _sessionId == null || _recording) return;
    try {
      await RecordingService.instance.start();
      if (mounted) {
        setState(() => _recording = true);
        _voiceTurnLimitTimer?.cancel();
        _voiceTurnLimitTimer = Timer(const Duration(seconds: 40), () {
          if (mounted && _recording && !_sending) {
            _stopRecording();
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
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _sending = true;
      _processingVoice = true;
    });
    _voiceTurnLimitTimer?.cancel();
    _voiceTurnLimitTimer = null;
    try {
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
                final suggestions = (response['suggestions'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => {
                  'text': (item['text'] ?? '').toString(),
                  'pronunciation': (item['pronunciation'] ?? '').toString(),
                })
            .where((item) => item['text']!.trim().isNotEmpty)
            .toList();
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
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final drawerBg = isDark ? const Color(0xFF141417) : const Color(0xFFF7F5F9);
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: scaffoldBg,
        canvasColor: scaffoldBg,
      ),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        drawer: EnglishPracticeDrawer(
          nativeLanguage: _nativeLanguage,
          targetLanguage: _targetLanguage,
          onChangeLanguage: _changeHelpLanguage,
          onNewChat: _newChat,
          backgroundColor: drawerBg,
        ),
        body: SafeArea(
          child: _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: const AlwaysStoppedAnimation<Color>(violet),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Opening chat…',
                        style: TextStyle(
                          color: AppTheme.getSecondaryText(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _error != null
              ? Center(
                  child: ElevatedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              : Column(
                  children: [
                    _header(isDark),
                    Expanded(child: _chat(isDark)),
                    if (_recording) _soundWaveBar(isDark),
                    _suggestionPanel(isDark),
                    _input(isDark),
                    _practiceMcqPanel(isDark),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    final primaryText = AppTheme.getPrimaryText(context);
    final subText = AppTheme.getSecondaryText(context);
    final divider = AppTheme.getCardBorder(context);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(bottom: BorderSide(color: divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu_rounded, size: 26, color: subText),
              tooltip: 'Open menu',
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'English Practice',
            style: TextStyle(
              color: primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
                    const Spacer(),
          FilledButton(
            onPressed: _roleplay,
            style: FilledButton.styleFrom(
              backgroundColor: violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Roleplay',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/glow-guide'),
            style: FilledButton.styleFrom(
              backgroundColor: violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 14),
            label: const Text(
              'Skin Care',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chat(bool isDark) {
    final cardBg = AppTheme.getCardBackground(context);
    final cardBorder = AppTheme.getCardBorder(context);
    final primaryText = AppTheme.getPrimaryText(context);
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          itemCount: _messages.length + (_sending ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _messages.length)
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ChatProcessingIndicator(voice: _processingVoice),
                ),
              );
            final m = _messages[i];
                                    if (!m.isUser) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                child: SelectionArea(
                  child: MarkdownBody(
                    data: m.text,
                    selectable: false,
                    styleSheet: _markdownStyle(context, primaryText),
                    softLineBreak: true,
                  ),
                ),
              );
            }
            return Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .76,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: violet,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: violet.withOpacity(isDark ? 0.22 : 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          m.imageUrl!,
                          width: 220,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                      const SizedBox(height: 8),
                    SelectionArea(
                      child: Text(
                        m.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _soundWaveBar(bool isDark) => AnimatedBuilder(
    animation: _waveController,
    builder: (context, _) {
      final intensity = _voiceActive ? 1.0 : 0.35;
      final subText = isDark ? Colors.white60 : Colors.black54;
      final idleBar = isDark ? Colors.white24 : Colors.black26;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_rounded,
              color: Colors.redAccent.shade200,
              size: 16,
            ),
            const SizedBox(width: 8),
            for (var i = 0; i < 24; i++) ...[
              Container(
                width: 3,
                height: 8 +
                    (_random.nextDouble() * 14 * intensity) +
                    (_voiceActive ? sin((i * 0.6) + _waveController.value * 12).abs() * 10 : 0),
                decoration: BoxDecoration(
                  color: _voiceActive
                      ? HSLColor.fromAHSL(1, (i * 12 + 280) % 360, 0.7, 0.6).toColor()
                      : idleBar,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 2),
            ],
            const SizedBox(width: 6),
            Text(
              RecordingService.instance.formattedDuration,
              style: TextStyle(
                color: subText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _suggestionPanel(bool isDark) {
  if (_suggestions.isEmpty) return const SizedBox.shrink();
  final suggestion = _suggestions.first;
  final text = suggestion['text'] ?? '';
  final pronunciation = suggestion['pronunciation'] ?? '';
  if (text.trim().isEmpty) return const SizedBox.shrink();

  final cardBg = AppTheme.getCardBackground(context);
  final cardBorder = AppTheme.getCardBorder(context);
  final inputBg = AppTheme.getInputBackground(context);
  final primaryText = AppTheme.getPrimaryText(context);
  final subText = AppTheme.getSecondaryText(context);

  return Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cardBorder),
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Box 1 — target/practice language phrase (tappable to send)
        InkWell(
          onTap: () => _send(text),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .43,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: violet, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: primaryText,
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
        // Box 2 — native-language pronunciation guide (read-only)
        if (pronunciation.trim().isNotEmpty)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .43,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.record_voice_over_outlined, color: subText, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pronunciation,
                    style: TextStyle(
                      color: subText,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

  Widget _practiceMcqPanel(bool isDark) {
    final mcq = _currentMcq;
    if (mcq == null || _sending) return const SizedBox.shrink();
    final selectedIndex = _mcqSelectedIndex;
    final optionLetters = ['A', 'B', 'C'];
    final cardBg = AppTheme.getCardBackground(context);
    final cardBorder = AppTheme.getCardBorder(context);
    final inputBg = AppTheme.getInputBackground(context);
    final primaryText = AppTheme.getPrimaryText(context);
    final subText = AppTheme.getSecondaryText(context);
    final correctBg = isDark ? const Color(0xFF1B3A26) : const Color(0xFFE6F6EA);
    final correctBorder = const Color(0xFF40A85C);
    final correctLetterBg = isDark ? const Color(0xFF26603A) : const Color(0xFFC8ECD4);
    final correctLetter = isDark ? const Color(0xFF7BD99C) : const Color(0xFF26603A);
    final wrongBg = isDark ? const Color(0xFF3A1B1B) : const Color(0xFFFBE9E9);
    final wrongBorder = const Color(0xFFE05252);
    final wrongLetterBg = isDark ? const Color(0xFF602626) : const Color(0xFFF5CCCC);
    final wrongLetter = isDark ? const Color(0xFFFF8A8A) : const Color(0xFFA42121);
    final feedbackSub = isDark ? Colors.white54 : Colors.black54;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: violet.withOpacity(isDark ? .22 : .12),
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
                        color: violet.withOpacity(isDark ? .95 : 1),
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
                    color: subText,
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
                fontWeight: FontWeight.w600,
                color: primaryText,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 11),
          for (var i = 0; i < mcq.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            InkWell(
              onTap: () => _answerMcq(i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selectedIndex == null
                      ? inputBg
                      : i == mcq.correctOption
                      ? correctBg
                      : i == selectedIndex
                      ? wrongBg
                      : inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedIndex == null
                        ? cardBorder
                        : i == mcq.correctOption
                        ? correctBorder
                        : i == selectedIndex
                        ? wrongBorder
                        : cardBorder,
                    width: i == mcq.correctOption || i == selectedIndex ? 1.3 : 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedIndex == null
                            ? violet.withOpacity(isDark ? .18 : .12)
                            : i == mcq.correctOption
                            ? correctLetterBg
                            : i == selectedIndex
                            ? wrongLetterBg
                            : violet.withOpacity(isDark ? .18 : .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        optionLetters[i],
                        style: TextStyle(
                          color: selectedIndex == null
                              ? violet
                              : i == mcq.correctOption
                              ? correctLetter
                              : i == selectedIndex
                              ? wrongLetter
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
                          fontWeight: FontWeight.w500,
                          color: primaryText,
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
                              ? correctBorder
                              : wrongBorder,
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
                      ? correctBorder
                      : wrongBorder,
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
                color: feedbackSub,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _input(bool isDark) {
    final inputBg = AppTheme.getInputBackground(context);
    final cardBorder = AppTheme.getCardBorder(context);
    final primaryText = AppTheme.getPrimaryText(context);
    final subText = AppTheme.getSecondaryText(context);
    final shadowColor = isDark ? Colors.black : const Color(0xFF3A2B7B);
    final shadowOpacity = isDark ? 0.25 : 0.06;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: _recording ? Colors.redAccent.withOpacity(0.5) : cardBorder,
            width: _recording ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(shadowOpacity),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: _text,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.newline,
                minLines: 1,
                maxLines: 10,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 15.5,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: subText, fontSize: 15.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  isCollapsed: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _smallIconBtn(
                  Icons.add_rounded,
                  _pickPhoto,
                  tooltip: 'Attach photo',
                  subText: subText,
                ),
                const SizedBox(width: 2),
                AiModelSelector(
                  selectedModel: _selectedTextModel,
                  onSelected: _changeTextModel,
                ),
                const Spacer(),
                _pressHoldMicBtn(isDark, subText),
                const SizedBox(width: 6),
                _sendBtn(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallIconBtn(IconData icon, VoidCallback? tap, {String? tooltip, Color? subText}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: subText ?? Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );

  Widget _pressHoldMicBtn(bool isDark, Color subText) => Listener(
    onPointerDown: (_) {
      unawaited(_startRecording());
    },
    onPointerUp: (_) {
      unawaited(_stopRecording());
    },
    onPointerCancel: (_) {
      unawaited(_stopRecording());
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: _recording
            ? Colors.redAccent.withOpacity(0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(_recording ? 11 : 10),
            decoration: BoxDecoration(
              color: _recording
                  ? Colors.redAccent.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _recording
                    ? Colors.redAccent.withOpacity(0.6)
                    : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Icon(
              _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: _recording ? Colors.redAccent.shade200 : subText,
              size: 22,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _sendBtn() => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Material(
      color: violet,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _sending ? null : () => _send(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_upward_rounded,
            color: _sending ? Colors.white54 : Colors.white,
            size: 22,
          ),
        ),
      ),
    ),
  );

  Future<void> _changeTextModel(String model) async {
    if (model == _selectedTextModel) return;
    if (model == 'claude') {
      final user = SupabaseClient.instance.currentUser;
      final plan = user == null
          ? 'free'
          : await SupabaseClient.instance.getPlanTier(user.id);
      if (plan != 'plan_499' && plan != 'plan_999') {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Premium model'),
            content: const Text(
              'Claude Premium is available on the ₹499 or ₹999 plan.',
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
                child: const Text('View plans'),
              ),
            ],
          ),
        );
        return;
      }
    }
    if (!mounted) return;

    // Mid-chat switch — no new session, no forced dialog. The next message
    // uses the new model; the backend also remembers it on this session.
    setState(() => _selectedTextModel = model);
    unawaited(_savePreferredModel(model));
  }

    Future<void> _savePreferredModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelPrefsKey, model);
    } catch (_) {
      // Non-critical — worst case the preference just doesn't persist.
    }
  }
}   // ← यह नया brace class को close करता है
