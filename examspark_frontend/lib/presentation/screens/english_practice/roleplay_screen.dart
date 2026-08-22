import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/constants/roleplay_voice_config.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_drawer.dart';

const _violet = Color(0xFF5137ED);

class RoleplaySetupScreen extends StatefulWidget {
  const RoleplaySetupScreen({
    super.key,
    this.chatSessionId,
    this.nativeLanguage,
    this.targetLanguage,
  });
  final String? chatSessionId;
  final String? nativeLanguage;
  final String? targetLanguage;
  @override
  State<RoleplaySetupScreen> createState() => _RoleplaySetupScreenState();
}

class _RoleplaySetupScreenState extends State<RoleplaySetupScreen> {
  String? scenario;
  String _ttsProvider = 'fish';
  String _ttsVoiceKey = 'female';
  String _targetLanguage = 'English';
  bool _preferenceLoaded = false;
  bool _hasSavedPreference = false;
  bool _savingVoice = false;
  String _textModel = 'qwen3';

  @override
  void initState() {
    super.initState();
    _loadVoicePreference();
  }

  Future<void> _loadVoicePreference() async {
    try {
      final preference = await LectureService.instance
          .getEnglishRoleplayVoicePreference();
      if (!mounted) return;
      setState(() {
        _ttsProvider = preference['provider'] as String? ?? 'fish';
        _ttsVoiceKey = preference['voice_key'] as String? ?? 'female';
        _targetLanguage = widget.targetLanguage ??
          preference['language'] as String? ??
          'English';
        _hasSavedPreference = preference['preference_set'] == true;
        _preferenceLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _preferenceLoaded = true);
    }
  }

  Widget _premiumChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 9 : 11,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6F56FF), Color(0xFF3020BF)],
                )
              : null,
          color: selected ? null : const Color(0xFFF6F5FB),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE6E4F2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 15 : 17,
              color: selected ? Colors.white : const Color(0xFF6F56FF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12.5 : 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF3B3856),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveVoicePreference(
    String provider,
    String voiceKey,
    String language,
  ) async {
    if (_savingVoice) return;
    final previousProvider = _ttsProvider;
    final previousVoiceKey = _ttsVoiceKey;
    final previousLanguage = _targetLanguage;
    setState(() {
      _savingVoice = true;
      _ttsProvider = provider;
      _ttsVoiceKey = voiceKey;
      _targetLanguage = language;
    });
    try {
      final preference = await LectureService.instance
          .setEnglishRoleplayVoicePreference(
            provider: provider,
            voiceKey: voiceKey,
            language: language,
          );
      if (mounted) {
        setState(() {
          _ttsProvider = preference['provider'] as String? ?? provider;
          _ttsVoiceKey = preference['voice_key'] as String? ?? voiceKey;
          _targetLanguage = preference['language'] as String? ?? language;
          _hasSavedPreference = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _ttsProvider = previousProvider;
          _ttsVoiceKey = previousVoiceKey;
          _targetLanguage = previousLanguage;
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

  static const _roleplayLanguages = [
    'English',
    'Spanish',
    'French',
    'Japanese',
    'German',
    'Korean',
    'Italian',
    'Chinese (Mandarin)',
    'Portuguese',
    'Hindi',
    'Arabic',
    'Vietnamese',
    'Indonesian',
    'Russian',
    'Bengali',
    'Tamil',
  ];

  Future<void> _openVoiceSettings({bool forcePicker = false}) async {
    if (!_preferenceLoaded) await _loadVoicePreference();
    if (!mounted) return;
    final provider = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var selectedProvider = forcePicker ? 'fish' : _ttsProvider;
        var selectedVoiceKey = _ttsVoiceKey;
        var selectedLanguage = forcePicker ? 'English' : _targetLanguage;
        var selectedTextModel = _textModel;
        var query = '';
        final search = TextEditingController();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = _roleplayLanguages
                .where((language) => language.toLowerCase().contains(query))
                .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF6F56FF), Color(0xFF3020BF)],
                                ),
                              ),
                              child: const Icon(
                                Icons.graphic_eq_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Roleplay preferences',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Voice, tone and language',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF8B87A6),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF8B87A6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFEDEBF7)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.chatSessionId == null) ...[
                              const Text(
                                'AI MODEL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  letterSpacing: .6,
                                  color: Color(0xFF8B87A6),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final model in const [
                                    ('qwen3', 'Qwen3', Icons.auto_awesome_rounded),
                                    ('gemini', 'Gemini Flash', Icons.auto_awesome),
                                    ('claude', 'Claude Premium', Icons.psychology_rounded),
                                  ])
                                    _premiumChip(
                                      label: model.$2,
                                      icon: model.$3,
                                      selected: selectedTextModel == model.$1,
                                      onTap: () => setSheetState(
                                        () => selectedTextModel = model.$1,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 22),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(bottom: 22),
                                child: Text(
                                  'AI MODEL  ·  INHERITED FROM CHAT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    letterSpacing: .6,
                                    color: Color(0xFF8B87A6),
                                  ),
                                ),
                              ),
                            const Text(
                              'TTS PROVIDER',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                letterSpacing: .6,
                                color: Color(0xFF8B87A6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _premiumChip(
                                  label: 'Fish Voice',
                                  icon: Icons.waves_rounded,
                                  selected: selectedProvider == 'fish',
                                  onTap: () => setSheetState(() {
                                    selectedProvider = 'fish';
                                    selectedVoiceKey = 'female';
                                  }),
                                ),
                                _premiumChip(
                                  label: 'Qwen Voice',
                                  icon: Icons.record_voice_over_rounded,
                                  selected: selectedProvider == 'qwen',
                                  onTap: () => setSheetState(() {
                                    selectedProvider = 'qwen';
                                    selectedVoiceKey = 'female';
                                  }),
                                ),
                                _premiumChip(
                                  label: 'Gemini Voice',
                                  icon: Icons.auto_awesome_rounded,
                                  selected: selectedProvider == 'gemini',
                                  onTap: () => setSheetState(() {
                                    selectedProvider = 'gemini';
                                    selectedVoiceKey = 'warm';
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              selectedProvider == 'gemini' ? 'VOICE' : 'VOICE GENDER',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                letterSpacing: .6,
                                color: Color(0xFF8B87A6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (selectedProvider == 'gemini') ...[
                                  for (final voice in const [
                                    ('warm', 'Warm', Icons.wb_sunny_rounded),
                                    ('friendly', 'Friendly', Icons.emoji_emotions_rounded),
                                    ('upbeat', 'Upbeat', Icons.bolt_rounded),
                                  ])
                                    _premiumChip(
                                      label: voice.$2,
                                      icon: voice.$3,
                                      selected: selectedVoiceKey == voice.$1,
                                      onTap: () => setSheetState(
                                        () => selectedVoiceKey = voice.$1,
                                      ),
                                    ),
                                ] else ...[
                                  _premiumChip(
                                    label: 'Female',
                                    icon: Icons.face_3_rounded,
                                    selected: selectedVoiceKey == 'female',
                                    onTap: () => setSheetState(
                                      () => selectedVoiceKey = 'female',
                                    ),
                                  ),
                                  _premiumChip(
                                    label: 'Male',
                                    icon: Icons.face_rounded,
                                    selected: selectedVoiceKey == 'male',
                                    onTap: () => setSheetState(
                                      () => selectedVoiceKey = 'male',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (selectedProvider == 'fish') ...[
                              const SizedBox(height: 22),
                              const Text(
                                'LANGUAGE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  letterSpacing: .6,
                                  color: Color(0xFF8B87A6),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F5FB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: TextField(
                                  controller: search,
                                  onChanged: (value) => setSheetState(
                                    () => query = value.trim().toLowerCase(),
                                  ),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF8B87A6),
                                    ),
                                    hintText: 'Search language',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFB0ADC4),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final language in filtered)
                                    _premiumChip(
                                      label: language,
                                      icon: Icons.language_rounded,
                                      selected: selectedLanguage == language,
                                      onTap: () => setSheetState(
                                        () => selectedLanguage = language,
                                      ),
                                      compact: true,
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6F56FF), Color(0xFF3020BF)],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x445137ED),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      await _saveVoicePreference(
                                        selectedProvider,
                                        selectedVoiceKey,
                                        selectedLanguage,
                                      );
                                      if (widget.chatSessionId == null) {
                                        _textModel = selectedTextModel;
                                      }
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext, selectedProvider);
                                      }
                                    },
                                    child: const Center(
                                      child: Text(
                                        'Save and continue',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
          },
        );
      },
    );
    if (!mounted || provider == null || scenario == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleplayVoiceScreen(
          scenario: scenario!,
          targetLanguage: widget.targetLanguage ?? _targetLanguage,
          nativeLanguage: widget.nativeLanguage ?? 'English',
          chatSessionId: widget.chatSessionId,
          textModel: _textModel,
        ),
      ),
    );
  }

  Future<void> _openSelectedScenario() async {
    if (scenario == null) return;
    if (_hasSavedPreference) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoleplayVoiceScreen(
            scenario: scenario!,
            targetLanguage: widget.targetLanguage ?? _targetLanguage,
            nativeLanguage: widget.nativeLanguage ?? 'English',
            chatSessionId: widget.chatSessionId,
            textModel: _textModel,
          ),
        ),
      );
      return;
    }
    await _openVoiceSettings(forcePicker: true);
  }

  String _languageLabel(String language) {
    if (language == 'Bengali') return 'বাংলা';
    return language;
  }

  Future<void> _openLanguagePicker() async {
    final selectedLanguage = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            const Text(
              'Roleplay language',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final language in _roleplayLanguages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  language == _targetLanguage
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: language == _targetLanguage ? _violet : null,
                ),
                title: Text(_languageLabel(language)),
                subtitle: language == 'Bengali' ? const Text('Bengali') : null,
                onTap: () => Navigator.pop(sheetContext, language),
              ),
          ],
        ),
      ),
    );
    if (!mounted ||
        selectedLanguage == null ||
        selectedLanguage == _targetLanguage) {
      return;
    }
    await _saveVoicePreference(_ttsProvider, _ttsVoiceKey, selectedLanguage);
  }

  static const items = [
    ('🎉', 'Party'),
    ('🛒', 'Market'),
    ('🧑‍🤝‍🧑', 'Friends'),
    ('🍴', 'Restaurant'),
    ('💼', 'Interview'),
    ('✈️', 'Travel'),
    ('🏢', 'Office / Citizen'),
    ('💻', 'Online Client Meeting'),
    ('🧑‍💼', 'Job Interview'),
    ('📋', 'Job Test / Screening Chat'),
    ('🗳️', 'Citizenship Test'),
    ('🛂', 'Visa Interview'),
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
    if (value != null && value.isNotEmpty) {
      setState(() => scenario = value);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    drawer: const EnglishPracticeDrawer(),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded, size: 30),
                    tooltip: 'Open menu',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Roleplay',
                  style: TextStyle(
                    color: AppTheme.getPrimaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _openVoiceSettings(),
                  icon: const Icon(Icons.tune_rounded, size: 25),
                  tooltip: 'Roleplay voice',
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.getCardBackground(context),
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
            OutlinedButton.icon(
              onPressed: _savingVoice ? null : _openLanguagePicker,
              icon: const Icon(Icons.language_rounded, size: 20),
              label: const Text('Practice language'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _violet,
                side: const BorderSide(color: _violet),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: InkWell(
                onTap: scenario == null ? null : _openSelectedScenario,
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
                        'Start Roleplay',
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
          ],
        ),
      ),
    ),
  );
}

enum RoleplayVoiceState {
  idle,
  generatingOpeningText,
  showingOpeningText,
  generatingOpeningAudio,
  listening,
  userSpeaking,
  processing,
  generatingAiResponse,
  aiSpeaking,
  waitingForUser,
  stopping,
  stopped,
  error,
}

class RoleplayVoiceScreen extends StatefulWidget {
  const RoleplayVoiceScreen({
    super.key,
    required this.scenario,
    required this.targetLanguage,
    required this.nativeLanguage,
    this.chatSessionId,
    this.textModel = 'qwen3',
  });
  final String scenario;
  final String targetLanguage;
  final String nativeLanguage;
  final String? chatSessionId;
  final String textModel;
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
  bool _heardSpeech = false;
  bool _leaving = false;
  bool _stopping = false;
  bool _starting = false;
  bool _micEnabled = true;
  bool _inactivityPromptShown = false;
  int _sessionGeneration = 0;
  String? _listeningHint;
  String? _openingReply;

  bool get active =>
      state == RoleplayVoiceState.listening ||
      state == RoleplayVoiceState.userSpeaking;
  bool get processing => state == RoleplayVoiceState.processing;

  Future<Duration> _loadPlayableAudio(Uint8List bytes, String mimeType) async {
    if (bytes.isEmpty) {
      throw StateError('Roleplay audio was empty.');
    }
    await _player.setAudioSource(
      AudioSource.uri(UriData.fromBytes(bytes, mimeType: mimeType).uri),
    );
    var duration = _player.duration;
    if (duration == null || duration <= Duration.zero) {
      try {
        final loadedDuration = await _player.durationStream
            .where((value) => value != null)
            .cast<Duration>()
            .firstWhere((value) => value > Duration.zero)
            .timeout(const Duration(seconds: 5));
        duration = loadedDuration;
      } on TimeoutException {
        throw StateError('Roleplay audio loaded but has no playable duration.');
      }
    }
    if (duration <= Duration.zero) {
      throw StateError('Roleplay audio duration was invalid.');
    }
    return duration;
  }

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
    if (_leaving) return;
    _leaving = true;
    _sessionGeneration++;
    final id = sessionId;
    final durationSeconds = elapsed.inSeconds;
    final stoppingInProgress = _stopping;
    sessionId = null;
    if (mounted) {
      setState(() {
        state = RoleplayVoiceState.stopped;
        _listeningHint = null;
      });
    }
    if (stoppingInProgress) {
      unawaited(_stopResources());
    } else {
      unawaited(_finishExitCleanup(id, durationSeconds));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finishExitCleanup(String? id, int durationSeconds) async {
    await _stopResources();
    if (id != null) {
      await _endRoleplayOnServer(id, durationSeconds: durationSeconds);
    }
  }

  Future<void> _endRoleplayOnServer(
    String id, {
    int? durationSeconds,
  }) async {
    try {
      await LectureService.instance.endEnglishRoleplay(
        sessionId: id,
        durationSeconds: durationSeconds ?? elapsed.inSeconds,
      );
    } catch (_) {
      // Local cleanup and navigation still complete when the network is unavailable.
    }
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
        state = RoleplayVoiceState.stopping;
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
    if (mounted) {
      setState(() => state = RoleplayVoiceState.stopped);
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
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
    elapsed = Duration.zero;
    pulse.stop();
    RecordingService.instance.setVoiceActivityListener(null);
    try {
      await RecordingService.instance.releaseForScreen();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
  }

  void _onVoiceActivity(bool speaking) {
    if (!mounted || !active) return;
    if (speaking) {
      _heardSpeech = true;
      _inactivityPromptShown = false;
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
    if (!_inactivityPromptShown) {
      _inactivityPromptShown = true;
      setState(() => state = RoleplayVoiceState.generatingAiResponse);
      RecordingService.instance.setVoiceActivityListener(null);
      await RecordingService.instance.releaseForScreen();
      try {
        final result = await LectureService.instance.reengageEnglishRoleplay(
          sessionId: sessionId!,
        );
        final encoded = result['audio_base64'] as String? ?? '';
        if (encoded.isEmpty) throw StateError('Re-engagement voice was not generated.');
        final audio = base64Decode(encoded);
        await _loadPlayableAudio(
          audio,
          result['audio_mime_type'] as String? ?? 'audio/mpeg',
        );
        if (!mounted || _leaving || _stopping || sessionId == null) return;
        _openingReply = result['reply'] as String? ?? 'Are you still there?';
        setState(() => state = RoleplayVoiceState.aiSpeaking);
        pulse.repeat(reverse: true);
        await _player.play();
        await _player.processingStateStream.firstWhere(
          (processingState) => processingState == ProcessingState.completed,
        );
        if (mounted && !_leaving && !_stopping) {
          await _startListening();
        }
      } catch (error) {
        if (mounted && !_leaving && !_stopping) {
          setState(() => state = RoleplayVoiceState.error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$error')),
          );
        }
      }
      return;
    }
    await _endCurrentSession(
      message:
          'Roleplay stopped because no speech was detected for one minute.',
    );
  }

  Future<void> _startListening() async {
    if (_leaving || _starting || processing || active) return;
    _starting = true;
    final generation = _sessionGeneration;
    try {
      if (sessionId == null) {
        if (mounted)
          setState(() => state = RoleplayVoiceState.generatingOpeningText);
        final started = await LectureService.instance.startEnglishRoleplay(
          scenario: widget.scenario,
          nativeLanguage: widget.nativeLanguage,
          targetLanguage: widget.targetLanguage,
          chatSessionId: widget.chatSessionId,
          textModel: widget.textModel,
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
        if ((_openingReply ?? '').trim().isEmpty) {
          throw StateError('Roleplay opening text was empty.');
        }
        if (mounted)
          setState(() => state = RoleplayVoiceState.showingOpeningText);
        final encoded = started['audio_base64'] as String?;

        if (encoded == null || encoded.isEmpty) {
          throw StateError('AI voice was not generated. Please try again.');
        }

        final audioBytes = base64Decode(encoded);
        if (audioBytes.isEmpty) {
          throw StateError('AI voice returned empty audio. Please try again.');
        }

        if (mounted)
          setState(() => state = RoleplayVoiceState.generatingOpeningAudio);
        final openingMime =
            started['audio_mime_type'] as String? ?? 'audio/mpeg';
        final openingDuration = await _loadPlayableAudio(
          audioBytes,
          openingMime,
        );
        debugPrint(
          'ROLEPLAY_OPENING_AUDIO_READY bytes=${audioBytes.length} '
          'mime=${started['audio_mime_type']} duration=$openingDuration',
        );
        if (mounted) setState(() => state = RoleplayVoiceState.aiSpeaking);
        pulse.repeat(reverse: true);
        await _player.play();

        debugPrint(
          'ROLEPLAY_OPENING_AUDIO_PLAYING playing=${_player.playing} '
          'processingState=${_player.processingState}',
        );

        await _player.processingStateStream.firstWhere(
          (processingState) => processingState == ProcessingState.completed,
        );
      }
      // A moon tap can stop the session while the AI opening is playing.
      // Never start the recorder after that stopped session.
      if (_leaving ||
          _stopping ||
          generation != _sessionGeneration ||
          sessionId == null) {
        return;
      }
      if (mounted) setState(() => state = RoleplayVoiceState.waitingForUser);
      _heardSpeech = false;
      RecordingService.instance.setVoiceActivityListener(_onVoiceActivity);
      await RecordingService.instance.start();
      if (_leaving || _stopping || generation != _sessionGeneration) {
        await RecordingService.instance.releaseForScreen();
        return;
      }
      if (mounted) setState(() => state = RoleplayVoiceState.listening);
      _inactivityPromptShown = false;
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
      await _playJsonTurn(bytes, turnSessionId!);
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

  Future<void> _playJsonTurn(Uint8List bytes, String turnSessionId) async {
    if (mounted)
      setState(() => state = RoleplayVoiceState.generatingAiResponse);
    final result = await LectureService.instance.sendEnglishRoleplayAudio(
      sessionId: turnSessionId,
      audioBytes: bytes,
      filename: 'roleplay_turn.m4a',
    );
    final reply = (result['reply'] as String? ?? '').trim();
    final encoded = result['audio_base64'] as String?;
    if (reply.isEmpty) throw StateError('AI response text was empty.');
    if (encoded == null || encoded.isEmpty) {
      throw StateError('AI response voice was not generated.');
    }
    final audio = base64Decode(encoded);
    if (mounted) {
      setState(() {
        _openingReply = reply;
        state = RoleplayVoiceState.showingOpeningText;
      });
    }
    await _loadPlayableAudio(
      audio,
      result['audio_mime_type'] as String? ?? 'audio/mpeg',
    );
    if (_leaving || _stopping || sessionId != turnSessionId) return;
    if (mounted) setState(() => state = RoleplayVoiceState.aiSpeaking);
    pulse.repeat(reverse: true);
    await _player.play();
    await _player.processingStateStream.firstWhere(
      (processingState) => processingState == ProcessingState.completed,
    );
  }

  Future<void> toggle() async {
    if (state == RoleplayVoiceState.error) {
      await _startListening();
      return;
    }
    if (sessionId != null ||
        active ||
        processing ||
        state == RoleplayVoiceState.aiSpeaking) {
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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
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
                GestureDetector(
                  onTap: toggle,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFEFEFF),
                    ),
                    child: Icon(
                      active ? Icons.mic_rounded : Icons.nights_stay_rounded,
                      color: _violet,
                      size: 82,
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
