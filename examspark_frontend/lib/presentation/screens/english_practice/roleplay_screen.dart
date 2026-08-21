import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/constants/roleplay_voice_config.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_language_picker_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_teaching_history_screen.dart';

const _violet = Color(0xFF5137ED);

class RoleplaySetupScreen extends StatefulWidget {
  const RoleplaySetupScreen({super.key});
  @override
  State<RoleplaySetupScreen> createState() => _RoleplaySetupScreenState();
}

class _RoleplaySetupScreenState extends State<RoleplaySetupScreen> {
  String? scenario;
  String _nativeLanguage = '';
  String _ttsProvider = 'qwen';
  String _ttsVoiceKey = 'female';
  bool _savingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final language = await LectureService.instance.getEnglishPracticeLanguage();
    if (mounted && language != null) {
      setState(() => _nativeLanguage = language);
    }
  }

  Future<void> _changeLanguage() async {
    final language = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const EnglishLanguagePickerScreen(returnToPrevious: true),
      ),
    );
    if (mounted && language != null) setState(() => _nativeLanguage = language);
  }

  Future<void> _loadVoicePreference() async {
    try {
      final preference =
          await LectureService.instance.getEnglishRoleplayVoicePreference();
      if (!mounted) return;
      setState(() {
        _ttsProvider = preference['provider'] as String? ?? 'qwen';
        _ttsVoiceKey = preference['voice_key'] as String? ?? 'female';
      });
    } catch (_) {
      // Existing Qwen female defaults remain usable until a preference loads.
    }
  }

  Future<void> _saveVoicePreference(String provider, String voiceKey) async {
    if (_savingVoice) return;
    final previousProvider = _ttsProvider;
    final previousVoiceKey = _ttsVoiceKey;
    setState(() {
      _savingVoice = true;
      _ttsProvider = provider;
      _ttsVoiceKey = voiceKey;
    });
    try {
      final preference = await LectureService.instance
          .setEnglishRoleplayVoicePreference(
        provider: provider,
        voiceKey: voiceKey,
      );
      if (mounted) {
        setState(() {
          _ttsProvider = preference['provider'] as String? ?? provider;
          _ttsVoiceKey = preference['voice_key'] as String? ?? voiceKey;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _ttsProvider = previousProvider;
          _ttsVoiceKey = previousVoiceKey;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice settings are unavailable until the latest backend is deployed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingVoice = false);
    }
  }

  List<(String, String)> get _voiceOptions => _ttsProvider == 'gemini'
      ? const [('warm', 'Warm'), ('friendly', 'Friendly'), ('upbeat', 'Upbeat')]
      : const [('female', 'Female'), ('male', 'Male')];

  Future<void> _openVoiceSettings() async {
    await _loadVoicePreference();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Roleplay voice',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Qwen Voice'),
                      selected: _ttsProvider == 'qwen',
                      onSelected: _savingVoice
                          ? null
                          : (_) async {
                              await _saveVoicePreference('qwen', 'female');
                              setSheetState(() {});
                            },
                    ),
                    ChoiceChip(
                      label: const Text('Gemini Voice'),
                      selected: _ttsProvider == 'gemini',
                      onSelected: _savingVoice
                          ? null
                          : (_) async {
                              await _saveVoicePreference('gemini', 'warm');
                              setSheetState(() {});
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Voice', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _voiceOptions.map((option) => ChoiceChip(
                    label: Text(option.$2),
                    selected: _ttsVoiceKey == option.$1,
                    onSelected: _savingVoice || _ttsVoiceKey == option.$1
                        ? null
                        : (_) async {
                            await _saveVoicePreference(_ttsProvider, option.$1);
                            setSheetState(() {});
                          },
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  static const items = [
    ('🎉', 'Party'),
    ('🛒', 'Market'),
    ('🧑‍🤝‍🧑', 'Friends'),
    ('🍴', 'Restaurant'),
    ('💼', 'Interview'),
    ('✈️', 'Travel'),
  ];
  Future<void> custom() async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Custom Roleplay'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Describe the situation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, input.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) setState(() => scenario = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FF),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.menu_rounded, size: 30),
                ),
                const Spacer(),
                InkWell(
                  onTap: _changeLanguage,
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
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _openVoiceSettings,
                  icon: const Icon(Icons.tune_rounded, size: 25),
                  tooltip: 'Roleplay voice',
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnglishTeachingHistoryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 29),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    'Choose Roleplay Mode',
                    style: TextStyle(
                      color: _violet,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: items
                        .map(
                          (x) => ChoiceChip(
                            label: Text(
                              '${x.$1}  ${x.$2}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: scenario == x.$2,
                            onSelected: (_) => setState(() => scenario = x.$2),
                            selectedColor: const Color(0xFFE8E3FF),
                            side: BorderSide(
                              color: scenario == x.$2
                                  ? _violet
                                  : const Color(0xFFE2E1ED),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 11,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: custom,
                      icon: const Icon(Icons.add, color: _violet),
                      label: const Text(
                        'Custom Roleplay',
                        style: TextStyle(
                          color: _violet,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _violet),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: InkWell(
                onTap: scenario == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RoleplayVoiceScreen(scenario: scenario!),
                        ),
                      ),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5A42F5), Color(0xFF3324C9)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Tap to Start Roleplay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x665A3AFF),
                              blurRadius: 30,
                              spreadRadius: 18,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: _violet,
                          size: 74,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        scenario == null
                            ? 'Choose a scenario to begin'
                            : '$scenario roleplay ready',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Auto listening  ·  Speak naturally',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Chat Mode'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(backgroundColor: _violet),
                      child: const Text('Roleplay Mode'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

enum RoleplayVoiceState {
  idle,
  listening,
  userSpeaking,
  processing,
  aiSpeaking,
  stopped,
  error,
}

class RoleplayVoiceScreen extends StatefulWidget {
  const RoleplayVoiceScreen({super.key, required this.scenario});
  final String scenario;
  @override
  State<RoleplayVoiceScreen> createState() => _RoleplayVoiceScreenState();
}

class _RoleplayVoiceScreenState extends State<RoleplayVoiceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: .94,
    upperBound: 1.06,
  );
  Timer? timer;
  Timer? _speechEndTimer;
  Timer? _sessionInactivityTimer;
  Timer? _firstSpeechPromptTimer;
  Timer? _dismissSpeechPromptTimer;
  Duration elapsed = Duration.zero;
  RoleplayVoiceState state = RoleplayVoiceState.idle;
  bool showTimer = true;
  String? sessionId;
  final _player = AudioPlayer();
  final _streamAudioQueue = <Map<String, dynamic>>[];
  Completer<void>? _streamPlaybackDone;
  bool _streamPlaying = false;
  bool _streamFinished = false;
  bool _streamAudioStarted = false;
  bool _heardSpeech = false;
  bool _leaving = false;
  bool _stopping = false;
  bool _starting = false;
  bool _micEnabled = true;
  int _sessionGeneration = 0;
  String? _listeningHint;
  String? _openingReply;

  bool get active =>
      state == RoleplayVoiceState.listening ||
      state == RoleplayVoiceState.userSpeaking;
  bool get processing => state == RoleplayVoiceState.processing;
  @override
  void dispose() {
    _leaving = true;
    _sessionGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    _speechEndTimer?.cancel();
    _sessionInactivityTimer?.cancel();
    _firstSpeechPromptTimer?.cancel();
    _dismissSpeechPromptTimer?.cancel();
    RecordingService.instance.setVoiceActivityListener(null);
    RecordingService.instance.releaseForScreen();
    pulse.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startListening());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.hidden) {
      _stopForBackground();
    }
  }

  Future<void> _leave() async {
    _leaving = true;
    _sessionGeneration++;
    await _stopResources();
    final id = sessionId;
    if (id != null) {
      try {
        await LectureService.instance.endEnglishRoleplay(
          sessionId: id,
          durationSeconds: elapsed.inSeconds,
        );
      } catch (_) {
        // The server retains the active session if the network is unavailable.
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _stopForBackground() async {
    await _endCurrentSession();
  }

  Future<void> _endCurrentSession({String? message}) async {
    if (_leaving || _stopping) return;
    _stopping = true;
    _sessionGeneration++;
    final id = sessionId;
    // A moon tap must feel instant. In-flight STT/TTS cannot restart because
    // its captured session id no longer matches this null value.
    sessionId = null;
    if (mounted) {
      setState(() {
        state = RoleplayVoiceState.stopped;
        _listeningHint = null;
      });
    }
    await _stopResources();
    if (id != null) {
      try {
        await LectureService.instance.endEnglishRoleplay(
          sessionId: id,
          durationSeconds: elapsed.inSeconds,
        );
      } catch (_) {
        // Local audio cleanup still completes when the final network call fails.
      }
    }
    if (mounted && message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    _stopping = false;
  }

  Future<void> _stopResources() async {
    _speechEndTimer?.cancel();
    _sessionInactivityTimer?.cancel();
    _firstSpeechPromptTimer?.cancel();
    _dismissSpeechPromptTimer?.cancel();
    timer?.cancel();
    timer = null;
    RecordingService.instance.setVoiceActivityListener(null);
    try {
      await RecordingService.instance.releaseForScreen();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    _streamAudioQueue.clear();
    _streamPlaying = false;
    _streamFinished = true;
    if (_streamPlaybackDone != null && !_streamPlaybackDone!.isCompleted) {
      _streamPlaybackDone!.complete();
    }
  }

  void _onVoiceActivity(bool speaking) {
    if (!mounted || !active) return;
    if (speaking) {
      _heardSpeech = true;
      _speechEndTimer?.cancel();
      _sessionInactivityTimer?.cancel();
      _firstSpeechPromptTimer?.cancel();
      _dismissSpeechPromptTimer?.cancel();
      setState(() {
        state = RoleplayVoiceState.userSpeaking;
        _listeningHint = null;
      });
    } else if (_heardSpeech) {
      setState(() => state = RoleplayVoiceState.listening);
      _speechEndTimer?.cancel();
      _speechEndTimer = Timer(
        RoleplayVoiceConfig.endOfTurnSilence,
        _finishTurn,
      );
    }
  }

  void _armSessionInactivityTimer() {
    _sessionInactivityTimer?.cancel();
    _sessionInactivityTimer = Timer(
      RoleplayVoiceConfig.sessionInactivityTimeout,
      _autoStopForInactivity,
    );
  }

  void _armFirstSpeechPrompt() {
    _firstSpeechPromptTimer?.cancel();
    _dismissSpeechPromptTimer?.cancel();
    _firstSpeechPromptTimer = Timer(
      RoleplayVoiceConfig.firstSpeechPromptDelay,
      () {
        if (!mounted || !active || _heardSpeech) return;
        setState(() => _listeningHint = 'Please speak…');
        _dismissSpeechPromptTimer = Timer(
          RoleplayVoiceConfig.speechPromptVisibleFor,
          () {
            if (mounted) setState(() => _listeningHint = null);
          },
        );
      },
    );
  }

  Future<void> _autoStopForInactivity() async {
    if (!mounted || !active) return;
    await _endCurrentSession(
      message: 'Roleplay stopped because no speech was detected for one minute.',
    );
  }

  Future<void> _startListening() async {
    if (_leaving || _starting || processing || active) return;
    _starting = true;
    final generation = _sessionGeneration;
    try {
      if (sessionId == null) {
        final started = await LectureService.instance.startEnglishRoleplay(
          scenario: widget.scenario,
          nativeLanguage:
              await LectureService.instance.getEnglishPracticeLanguage() ?? 'English',
        );
        final startedSessionId = started['session_id'] as String?;
        if (startedSessionId == null ||
            _leaving ||
            _stopping ||
            generation != _sessionGeneration) {
          if (startedSessionId != null) {
            await LectureService.instance.endEnglishRoleplay(
              sessionId: startedSessionId,
              durationSeconds: 0,
            );
          }
          return;
        }
        sessionId = startedSessionId;
        _openingReply = started['opening_reply'] as String?;
        final encoded = started['audio_base64'] as String?;

        if (encoded == null || encoded.isEmpty) {
          throw StateError('AI voice was not generated. Please try again.');
        }

        final audioBytes = base64Decode(encoded);
        if (audioBytes.isEmpty) {
          throw StateError('AI voice returned empty audio. Please try again.');
        }

        if (mounted) {
          setState(() => state = RoleplayVoiceState.aiSpeaking);
        }

        pulse.repeat(reverse: true);

        await _player.setAudioSource(
          AudioSource.uri(
            UriData.fromBytes(
              audioBytes,
              mimeType: started['audio_mime_type'] as String? ?? 'audio/mpeg',
            ).uri,
          ),
        );

        await _player.play();

        await _player.processingStateStream.firstWhere(
          (processingState) => processingState == ProcessingState.completed,
        );
      }
      // A moon tap can stop the session while the AI opening is playing.
      // Never start the recorder after that stopped session.
      if (_leaving || _stopping || generation != _sessionGeneration || sessionId == null) {
        return;
      }
      _heardSpeech = false;
      RecordingService.instance.setVoiceActivityListener(_onVoiceActivity);
      await RecordingService.instance.start();
      if (_leaving || _stopping || generation != _sessionGeneration) {
        await RecordingService.instance.releaseForScreen();
        return;
      }
      if (mounted) setState(() => state = RoleplayVoiceState.listening);
      _armSessionInactivityTimer();
      _armFirstSpeechPrompt();
      timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => elapsed += const Duration(seconds: 1));
      });
      pulse.repeat(reverse: true);
    } catch (e) {
      if (_leaving || _stopping || generation != _sessionGeneration) return;
      final failedSessionId = sessionId;
      sessionId = null;
      if (failedSessionId != null) {
        try {
          await LectureService.instance.endEnglishRoleplay(
            sessionId: failedSessionId,
            durationSeconds: elapsed.inSeconds,
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() => state = RoleplayVoiceState.error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _finishTurn() async {
    if (!active || processing) return;
    final turnSessionId = sessionId;
    _speechEndTimer?.cancel();
    if (!_heardSpeech && !RecordingService.instance.heardAnyVoice) return;
    setState(() => state = RoleplayVoiceState.processing);
    pulse.stop();
    RecordingService.instance.setVoiceActivityListener(null);
    try {
      final path = await RecordingService.instance.stop();
      final bytes = await RecordingService.instance.readRecordingBytes(path);
      // Roleplay microphone files are one-turn input only. The byte buffer is
      // enough for the API call; never retain the original device recording.
      await RecordingService.instance.discardTemporaryRecording(path);
      if (bytes == null) {
        throw StateError('No speech was recorded. Please try again.');
      }
      if (_leaving || _stopping || sessionId != turnSessionId) return;
      try {
        await _playStreamedTurn(bytes, turnSessionId!);
      } catch (error) {
        if (_leaving || _stopping || sessionId != turnSessionId) return;
        final canFallback = error is! RoleplayStreamException ||
            error.canFallback;
        if (!canFallback || _streamAudioStarted) {
          // A partly heard streamed reply must never be replayed through the
          // JSON fallback. Stop its player before surfacing the normal error
          // state, so the moon cannot resume listening mid-response.
          await _player.stop();
          rethrow;
        }
        await _playFallbackTurn(bytes, turnSessionId!);
      }
      // A manual stop may happen while STT/TTS is processing. Do not let the
      // old in-flight turn restart the microphone after its session was ended.
      if (mounted &&
          !_leaving &&
          !_stopping &&
          _micEnabled &&
          sessionId == turnSessionId) {
        await _startListening();
      }
    } catch (e) {
      if (mounted && !_leaving && !_stopping && sessionId == turnSessionId) {
        setState(() => state = RoleplayVoiceState.error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _playStreamedTurn(Uint8List bytes, String turnSessionId) async {
    _streamAudioQueue.clear();
    _streamPlaybackDone = Completer<void>();
    _streamPlaying = false;
    _streamFinished = false;
    _streamAudioStarted = false;
    await LectureService.instance.streamEnglishRoleplayAudio(
      sessionId: turnSessionId,
      audioBytes: bytes,
      filename: 'roleplay_turn.m4a',
      onAudioChunk: _enqueueStreamAudio,
    );
    _streamFinished = true;
    _completeStreamPlaybackIfReady();
    await _streamPlaybackDone!.future;
  }

  Future<void> _enqueueStreamAudio(Map<String, dynamic> event) async {
    if (_leaving || _stopping || sessionId == null) return;
    final encoded = event['audio_base64'] as String? ?? '';
    if (encoded.isEmpty) {
      throw const RoleplayStreamException(
        'Voice stream returned an empty audio chunk.',
        canFallback: true,
      );
    }
    _streamAudioQueue.add({
      'bytes': base64Decode(encoded),
      'mime': event['audio_mime_type'] as String? ?? 'audio/mpeg',
    });
    if (!_streamPlaying) {
      _streamPlaying = true;
      unawaited(_playQueuedStreamAudio());
    }
  }

  Future<void> _playQueuedStreamAudio() async {
    try {
        while (_streamAudioQueue.isNotEmpty &&
          !_leaving &&
          !_stopping &&
          sessionId != null) {
        final chunk = _streamAudioQueue.removeAt(0);
        _streamAudioStarted = true;
        if (mounted) setState(() => state = RoleplayVoiceState.aiSpeaking);
        pulse.repeat(reverse: true);
        await _player.setAudioSource(
          AudioSource.uri(
            UriData.fromBytes(
              chunk['bytes'] as Uint8List,
              mimeType: chunk['mime'] as String,
            ).uri,
          ),
        );
        await _player.play();
      }
    } catch (error, stackTrace) {
      if (_streamPlaybackDone != null && !_streamPlaybackDone!.isCompleted) {
        _streamPlaybackDone!.completeError(error, stackTrace);
      }
    } finally {
      _streamPlaying = false;
      _completeStreamPlaybackIfReady();
    }
  }

  void _completeStreamPlaybackIfReady() {
    if (_streamFinished &&
        !_streamPlaying &&
        _streamAudioQueue.isEmpty &&
        _streamPlaybackDone != null &&
        !_streamPlaybackDone!.isCompleted) {
      _streamPlaybackDone!.complete();
    }
  }

  Future<void> _playFallbackTurn(Uint8List bytes, String turnSessionId) async {
    final result = await LectureService.instance.sendEnglishRoleplayAudio(
      sessionId: turnSessionId,
      audioBytes: bytes,
      filename: 'roleplay_turn.m4a',
    );
    final audio = base64Decode(result['audio_base64'] as String);
    await _player.setAudioSource(
      AudioSource.uri(
        UriData.fromBytes(
          audio,
          mimeType: result['audio_mime_type'] as String? ?? 'audio/mpeg',
        ).uri,
      ),
    );
    if (mounted) setState(() => state = RoleplayVoiceState.aiSpeaking);
    pulse.repeat(reverse: true);
    await _player.play();
  }

  Future<void> toggle() async {
    if (state == RoleplayVoiceState.error) {
      await _startListening();
      return;
    }
    if (sessionId != null || active || processing || state == RoleplayVoiceState.aiSpeaking) {
      unawaited(_endCurrentSession(message: 'Roleplay stopped.'));
    } else {
      await _startListening();
    }
  }

  Future<void> _toggleMic() async {
    if (_starting || processing) return;
    final enabled = !_micEnabled;
    setState(() => _micEnabled = enabled);
    if (!enabled) {
      _speechEndTimer?.cancel();
      _sessionInactivityTimer?.cancel();
      RecordingService.instance.setVoiceActivityListener(null);
      await RecordingService.instance.releaseForScreen();
      if (mounted && active) setState(() => state = RoleplayVoiceState.idle);
      return;
    }
    if (sessionId != null && state != RoleplayVoiceState.aiSpeaking) {
      await _startListening();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF190A5C),
    body: SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 8,
            child: IconButton(
              onPressed: _leave,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 8,
            child: TextButton.icon(
              onPressed: _leave,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              label: const Text(
                'Exit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _openingReply ?? widget.scenario,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 45),
                ScaleTransition(
                  scale: pulse,
                  child: GestureDetector(
                    onTap: toggle,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFEFEFF),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF9A6DFF),
                            blurRadius: 35,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(
                        active ? Icons.mic_rounded : Icons.nights_stay_rounded,
                        color: _violet,
                        size: 100,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                GestureDetector(
                  onTap: () => setState(() => showTimer = !showTimer),
                  child: Text(
                    showTimer
                        ? '${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:${elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}'
                        : 'Tap to show time',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _listeningHint ??
                    (!_micEnabled
                      ? 'Microphone off'
                      : state == RoleplayVoiceState.aiSpeaking
                          ? 'AI is speaking…'
                          : active
                              ? 'Listening… speak naturally'
                              : state == RoleplayVoiceState.error
                                ? 'Tap the moon to retry'
                                : 'Starting conversation…'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 80),
                TextButton.icon(
                  onPressed: sessionId == null ? null : _toggleMic,
                  icon: Icon(
                    _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _micEnabled ? 'Mic ON' : 'Mic OFF',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  active
                      ? 'Listening automatically\nTap the moon to stop the session'
                      : 'I’ll listen and reply',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
