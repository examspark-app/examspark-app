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
import 'package:examspark_frontend/presentation/screens/english_practice/sonia_chat_screen.dart';
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

  static const List<(String, IconData, String)> _modeItems = [
    ('Party', Icons.celebration_outlined, '🎉'),
    ('Market', Icons.storefront_outlined, '🛒'),
    ('Friends', Icons.people_outline, '🧑‍🤝‍🧑'),
    ('Restaurant', Icons.restaurant_outlined, '🍴'),
    ('Interview', Icons.work_outline, '💼'),
    ('Travel', Icons.flight_takeoff_outlined, '✈️'),
    ('Office / Citizen', Icons.apartment_outlined, '🏢'),
    ('Online Client Meeting', Icons.video_call_outlined, '💻'),
    ('Job Interview', Icons.badge_outlined, '🧑‍💼'),
    ('Job Test / Screening Chat', Icons.assignment_outlined, '📋'),
    ('Citizenship Test', Icons.how_to_vote_outlined, '🗳️'),
    ('Visa Interview', Icons.airplane_ticket_outlined, '🛂'),
  ];

  static const List<(String, String, String, String, IconData)> _textModels = [
    (
      'qwen3',
      'Qwen3 Turbo',
      'v3 · Fast & smart',
      'Great for daily roleplays',
      Icons.auto_awesome_rounded,
    ),
    (
      'gemini',
      'Gemini Flash 2.0',
      'v2.0 · Balanced',
      'Crisp, natural English',
      Icons.psychology_alt_outlined,
    ),
    (
      'claude',
      'Claude Sonnet',
      'v4 · Premium',
      'Best for interviews',
      Icons.psychology_rounded,
    ),
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

  String _modelLabel() {
    final m = _textModels.cast<(String, String, String, String, IconData)>().firstWhere(
      (e) => e.$1 == _textModel,
      orElse: () => _textModels.first as (String, String, String, String, IconData),
    );
    return '${m.$2}  ·  ${m.$3}';
  }

  Future<void> _onEnter() async {
    if (scenario == null || scenario!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a roleplay mode first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_textModel.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an AI model first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _openSelectedScenario();
  }
  Future<void> _onChatWithSonia() async {
    if (scenario == null || scenario!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a roleplay mode first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoniaChatScreen(
          scenario: scenario!,
          targetLanguage: widget.targetLanguage ?? _targetLanguage,
          nativeLanguage: widget.nativeLanguage ?? 'English',
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final cardBg = AppTheme.getCardBackground(context);
    final primaryText = AppTheme.getPrimaryText(context);
    final subText = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black45;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const EnglishPracticeDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded, size: 28),
                      tooltip: 'Open menu',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Roleplay',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _savingVoice ? null : _openLanguagePicker,
                    icon: const Icon(Icons.language_rounded, size: 24),
                    tooltip: 'Practice language',
                  ),
                  IconButton(
                    onPressed: _savingVoice ? null : _openVoiceSettings,
                    icon: const Icon(Icons.tune_rounded, size: 24),
                    tooltip: 'Voice settings',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1) TTS Voice Provider + Gender selector (permanently ABOVE mode select)
              _buildTtsVoiceCard(cardBg, primaryText, subText),
              const SizedBox(height: 18),

              // 2) Scenario / Mode chips section
              _buildScenariosCard(cardBg, primaryText, subText),
              const SizedBox(height: 22),

              // 3) Sonia persona card + Enter
              _buildPersonaAndEnter(cardBg, primaryText, subText),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelRow(Color cardBg, Color primaryText, Color subText) {
    final active = _textModels.cast<(String, String, String, String, IconData)>().firstWhere(
      (e) => e.$1 == _textModel,
      orElse: () => _textModels.first as (String, String, String, String, IconData),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE6E4F2),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6F56FF), Color(0xFF3020BF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(active.$5, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active.$2,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${active.$3}  ·  ${active.$4}',
                  style: TextStyle(
                    color: subText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _textModel = v),
            itemBuilder: (ctx) {
              return _textModels.map((m) {
                return PopupMenuItem<String>(
                  value: m.$1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m.$5, size: 18, color: _violet),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.$2,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            m.$3,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F5FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE6E4F2),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: _violet,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _violet,
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

    Widget _buildTtsVoiceCard(Color cardBg, Color primaryText, Color subText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _savingVoice ? null : _openVoiceSettings,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFEBE9F5),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF6F56FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: _violet,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Engine',
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_providerLabel(_ttsProvider)} · ${_voiceLabel(_ttsVoiceKey)} · $_targetLanguage',
                    style: TextStyle(
                      color: subText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subText),
          ],
        ),
      ),
    );
  }

  String _providerLabel(String key) {
    switch (key) {
      case 'fish':
        return 'Fish Voice';
      case 'qwen':
        return 'Qwen Voice';
      case 'gemini':
        return 'Gemini Voice';
      default:
        return key;
    }
  }

  String _voiceLabel(String key) {
    switch (key) {
      case 'female':
        return 'Female';
      case 'male':
        return 'Male';
      case 'warm':
        return 'Warm';
      case 'friendly':
        return 'Friendly';
      case 'upbeat':
        return 'Upbeat';
      default:
        return key;
    }
  }

  Widget _buildScenariosCard(Color cardBg, Color primaryText, Color subText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEBE9F5),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF6F56FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.theater_comedy_outlined,
                  color: _violet,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Roleplay Mode',
                      style: TextStyle(
                        color: _violet,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pick a situation. Tap again to deselect.',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cardWidth = (constraints.maxWidth - 10) / 2;
              final items = _modeItems;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                children: List.generate(items.length, (index) {
                  final x = items[index];
                  final label = x.$1;
                  final icon = x.$2;
                  final emoji = x.$3;
                  final selected = scenario == label;
                  return SizedBox(
                    width: cardWidth,
                    child: _modeButton(
                      label: label,
                      icon: icon,
                      emoji: emoji,
                      selected: selected,
                      onTap: () => setState(() {
                        scenario = (scenario == label) ? null : label;
                      }),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: custom,
              icon: const Icon(Icons.add_rounded, color: _violet),
              label: const Text(
                'Custom Roleplay',
                style: TextStyle(
                  color: _violet,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _violet,
                side: const BorderSide(color: _violet, width: 1.1),
                backgroundColor: const Color(0xFFF6F5FB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6F56FF), Color(0xFF3020BF)],
                )
              : null,
          color: selected ? null : const Color(0xFFF6F5FB),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE6E4F2),
            width: 0.8,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x335137ED),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.14)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : _violet,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF3A3659),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 4, right: 2),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaAndEnter(Color cardBg, Color primaryText, Color subText) {
    final isReady = scenario != null && scenario!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6348FF), Color(0xFF3020BF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335A3AFF),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Persona row
          Row(
            children: [
              // Sonia avatar (local asset first, falls back to network URL)
              SizedBox(
                width: 72,
                height: 72,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55FFFFFF),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/sonia_avatar.png',
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                      errorBuilder: (_, __, ___) => Image.network(
                        'https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=Professional%20friendly%20Indian%20female%20english%20tutor%20portrait%20called%20Sonia%20headshot%20warm%20smile%20clean%20studio%20light%20soft%20pink%20background&image_size=square_hd',
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Text(
                          'Sonia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF9DF3C4),
                          size: 18,
                        ),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your English buddy',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scenario selected preview + hint
          if (isReady) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.theater_comedy_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenario!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Ready — Sonia will open the scene.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.75),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Pick a roleplay mode first, then tap Enter.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          // Big Enter button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _onEnter,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.mic_rounded,
                          size: 22,
                          color: _violet,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Enter',
                          style: TextStyle(
                            color: _violet,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _violet.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Auto listening  ·  Speak naturally',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _onChatWithSonia,
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 19),
              label: const Text(
                'Chat with Sonia',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54, width: 1.1),
                backgroundColor: Colors.white.withOpacity(0.10),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  with SingleTickerProviderStateMixin, WidgetsBindingObserver 
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF190A5C) : const Color(0xFFF0EBFF);
    final primaryText = isDark ? Colors.white : const Color(0xFF2A1F66);
    final subText = isDark ? Colors.white70 : const Color(0xFF594AA8);
    final callActive = active || state == RoleplayVoiceState.aiSpeaking;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _leave,
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: subText, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    widget.scenario,
                    style: TextStyle(color: subText, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _leave,
                    child: Text('Exit', style: TextStyle(color: primaryText, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            // Middle — photo + wave + reply text (scrollable to always fit)
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sonia avatar with animated wave ring
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (context, child) {
                          final scale = callActive ? pulse.value : 1.0;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              if (callActive)
                                Transform.scale(
                                  scale: scale + 0.12,
                                  child: Container(
                                    width: 168,
                                    height: 168,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (state == RoleplayVoiceState.aiSpeaking
                                              ? _violet
                                              : const Color(0xFF40A85C))
                                          .withOpacity(0.18),
                                    ),
                                  ),
                                ),
                              Transform.scale(
                                scale: callActive ? scale : 1.0,
                                child: Container(
                                  width: 148,
                                  height: 148,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: callActive
                                          ? (state == RoleplayVoiceState.aiSpeaking
                                              ? _violet
                                              : const Color(0xFF40A85C))
                                          : Colors.white24,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _violet.withOpacity(isDark ? 0.30 : 0.15),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/sonia_avatar.png',
                                      fit: BoxFit.cover,
                                      width: 148,
                                      height: 148,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          _openingReply ?? widget.scenario,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: primaryText, fontSize: 15, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => setState(() => showTimer = !showTimer),
                        child: Text(
                          showTimer
                              ? '${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:${elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}'
                              : 'Tap to show time',
                          style: TextStyle(color: subText, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _listeningHint ??
                            (!_micEnabled
                                ? 'Microphone off'
                                : state == RoleplayVoiceState.aiSpeaking
                                ? 'Sonia is speaking…'
                                : active
                                ? 'Listening… speak naturally'
                                : state == RoleplayVoiceState.error
                                ? 'Tap End Call, then retry'
                                : 'Connecting…'),
                        style: TextStyle(color: subText, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom — call controls (mobile call style)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _callControlButton(
                    icon: _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: _micEnabled ? 'Mute' : 'Muted',
                    bg: Colors.white.withOpacity(0.12),
                    fg: primaryText,
                    onTap: sessionId == null ? null : _toggleMic,
                  ),
                  _callControlButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    bg: const Color(0xFFE05252),
                    fg: Colors.white,
                    big: true,
                    onTap: _leave,
                  ),
                  _callControlButton(
                    icon: Icons.refresh_rounded,
                    label: 'Retry',
                    bg: Colors.white.withOpacity(0.12),
                    fg: primaryText,
                    onTap: state == RoleplayVoiceState.error ? _startListening : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callControlButton({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    VoidCallback? onTap,
    bool big = false,
  }) {
    final size = big ? 64.0 : 52.0;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
              child: Icon(icon, color: fg, size: big ? 28 : 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
