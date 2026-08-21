import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_language_picker_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_teaching_history_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_drawer.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/roleplay_screen.dart';

class _Message {
  const _Message(this.text, this.isUser);
  final String text;
  final bool isUser;
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
  const EnglishPracticeScreen({super.key, this.sessionId});
  final String? sessionId;
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
  String? _sessionId;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  String _nativeLanguage = '';
  String _targetLanguage = 'English';
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    RecordingService.instance.releaseForScreen();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.sessionId == null) {
        final r = await LectureService.instance.startEnglishPractice();
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
        final s = List<String>.from(r['suggestions'] as List? ?? const []);
        if (s.isNotEmpty) _suggestions = s;
        final mcq = _PracticeMcq.fromJson(r['mcq']);
        if (mcq != null) _currentMcq = mcq;
      } else {
        final r = await LectureService.instance.restoreEnglishPracticeSession(
          widget.sessionId!,
        );
        _sessionId = r['id'] as String?;
        _nativeLanguage =
            await LectureService.instance.getEnglishPracticeLanguage() ?? '';
        _targetLanguage = '${r['target_language'] ?? 'English'}';
        _messages
          ..clear()
          ..addAll(
            (r['messages'] as List? ?? const []).map(
              (m) => _Message('${m['message'] ?? ''}', m['role'] == 'user'),
            ),
          );
      }
      if (mounted) {
        setState(() => _loading = false);
        _bottom();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = '$e';
        });
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
  });

  _bottom();

  try {
    final r = await LectureService.instance.sendEnglishPracticeMessage(
      sessionId: _sessionId!,
      message: value,
    );

    if (!mounted) return;

    setState(() {
      _messages.add(
        _Message('${r['reply'] ?? ''}', false),
      );

      final s = List<String>.from(
        r['suggestions'] as List? ?? const [],
      );

      if (s.isNotEmpty) {
        _suggestions = s;
      }

      final mcq = _PracticeMcq.fromJson(r['mcq']);
      if (mcq != null) {
        _currentMcq = mcq;
      }

      _sending = false;
    });

    _bottom();
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _sending = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst('Exception: ', ''),
        ),
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
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const EnglishLanguagePickerScreen(returnToPrevious: true),
      ),
    );
    if (!mounted || selected == null || selected.trim().isEmpty) return;
    // A Chat session stores its explanation language. Create a fresh session
    // so the next model turn immediately uses the newly selected language;
    // the previous conversation remains available in History.
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EnglishPracticeScreen()),
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (_sending || _sessionId == null) return;
    if (!_recording) {
      try {
        await RecordingService.instance.start();
        if (mounted) setState(() => _recording = true);
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
    });
    try {
      // When amplitude monitoring is available, reject silence locally before
      // an upload. On platforms without amplitude support the server performs
      // the same transcript validation before any credit/Qwen call.
      final detectedVoice = RecordingService.instance.heardAnyVoice;
      final canMeasureVoice = RecordingService.instance.amplitudeMonitoringActive;
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
        if (mcq != null) _currentMcq = mcq;
        _sending = false;
      });
      _bottom();
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _newChat() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EnglishLanguagePickerScreen()),
    );
  }

  void _history() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EnglishTeachingHistoryScreen()),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    drawer: const EnglishPracticeDrawer(),
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
        InkWell(
          onTap: _changeHelpLanguage,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.language_rounded),
                const SizedBox(width: 8),
                Text(
                  _nativeLanguage.isEmpty
                      ? 'English (US)'
                      : 'English · $_nativeLanguage',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _newChat,
          icon: const Icon(Icons.add_comment_outlined, size: 19),
          label: const Text('New Chat'),
        ),
        IconButton(
          onPressed: _history,
          icon: const Icon(Icons.history_rounded, size: 29),
        ),
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
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: violet,
                  ),
                ),
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
              child: Text(
                m.text,
                style: TextStyle(
                  color: m.isUser ? Colors.white : AppTheme.getPrimaryText(context),
                  fontSize: 16,
                  height: 1.45,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: violet.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      color: violet,
                      size: 15,
                    ),
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
              onTap: () => _send(mcq.options[i]),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                    color: AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFD5D1EC),
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
                        color: violet.withOpacity(.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        optionLetters[i],
                        style: TextStyle(
                          color: violet,
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
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 9),
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
