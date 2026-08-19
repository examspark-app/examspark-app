import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_language_picker_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_teaching_history_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/roleplay_screen.dart';

class _Message {
  const _Message(this.text, this.isUser);
  final String text;
  final bool isUser;
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
  final _player = AudioPlayer();
  final _messages = <_Message>[];
  List<String> _suggestions = const [
    'Correct my sentence',
    'Explain this grammar rule',
    'Help me write this',
    'Daily English conversation',
    'How to speak fluently',
  ];
  String? _sessionId;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  String _nativeLanguage = '';
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
    _player.dispose();
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
        _messages
          ..clear()
          ..add(_Message('${r['greeting'] ?? ''}', false));
        await _playReplyAudio(r);
        final s = List<String>.from(r['suggestions'] as List? ?? const []);
        if (s.isNotEmpty) _suggestions = s;
      } else {
        final r = await LectureService.instance.restoreEnglishPracticeSession(
          widget.sessionId!,
        );
        _sessionId = r['id'] as String?;
        _nativeLanguage =
            await LectureService.instance.getEnglishPracticeLanguage() ?? '';
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
        _messages.add(_Message('${r['reply'] ?? ''}', false));
        final s = List<String>.from(r['suggestions'] as List? ?? const []);
        if (s.isNotEmpty) _suggestions = s;
        _sending = false;
      });
      await _playReplyAudio(r);
      _bottom();
    } catch (_) {
      if (mounted)
        setState(() {
          _sending = false;
          _messages.add(
            const _Message('I could not send that. Please try again.', false),
          );
        });
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
        MaterialPageRoute(builder: (_) => const RoleplaySetupScreen()),
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
        _messages.add(_Message('${response['transcript'] ?? ''}', true));
        _messages.add(_Message('${response['reply'] ?? ''}', false));
        final suggestions = List<String>.from(
          response['suggestions'] as List? ?? const [],
        );
        if (suggestions.isNotEmpty) _suggestions = suggestions;
        _sending = false;
      });
      await _playReplyAudio(response);
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

  Future<void> _playReplyAudio(Map<String, dynamic> response) async {
    final encoded = response['audio_base64'] as String?;
    if (encoded == null || encoded.isEmpty) return;
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          UriData.fromBytes(
            Uint8List.fromList(base64Decode(encoded)),
            mimeType: response['audio_mime_type'] as String? ?? 'audio/mpeg',
          ).uri,
        ),
      );
      await _player.play();
    } catch (_) {
      // The message remains visible when device audio is unavailable.
    }
  }

  Future<void> _newChat() async {
    await _player.stop();
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EnglishPracticeScreen()),
    );
  }

  void _history() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EnglishTeachingHistoryScreen()),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FF),
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
                _tabs(),
              ],
            ),
    ),
  );
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.menu_rounded, size: 30),
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
        IconButton(
          onPressed: _newChat,
          icon: const Icon(Icons.add_comment_outlined, size: 26),
          tooltip: 'New Chat',
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
                color: m.isUser ? violet : Colors.white,
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
                  color: m.isUser ? Colors.white : const Color(0xFF15162D),
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
    final count = _suggestions.length > 5 ? 5 : _suggestions.length;
    final icons = [
      Icons.edit_outlined,
      Icons.menu_book_outlined,
      Icons.edit_note_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.record_voice_over_outlined,
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E5F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You can try asking me:',
            style: TextStyle(
              color: violet,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: () => _send(_suggestions[i]),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E1ED)),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(icons[i], color: violet),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          _suggestions[i],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
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
              fillColor: Colors.white,
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
