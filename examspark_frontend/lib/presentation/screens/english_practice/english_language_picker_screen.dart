import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';

enum _PickerStep { nativeLanguage, targetLanguage }

class _LangOption {
  final String label;
  final String englishName;
  const _LangOption(this.label, this.englishName);
}

/// Two-step picker:
///   Step A — student's native / spoken language
///   Step B — the language they want to learn (target language)
///
/// Both steps use the same pattern: common chips with native-script labels,
/// a search bar, and an "Other / Type your own" free-text fallback so any
/// language not in the presets can still be entered freely.
class EnglishLanguagePickerScreen extends StatefulWidget {
  const EnglishLanguagePickerScreen({super.key, this.returnToPrevious = false});

  /// Lets an already-open Chat or Roleplay setup update its explanation
  /// language without replacing that screen.
  final bool returnToPrevious;

  @override
  State<EnglishLanguagePickerScreen> createState() =>
      _EnglishLanguagePickerScreenState();
}

class _EnglishLanguagePickerScreenState
    extends State<EnglishLanguagePickerScreen> {
  _PickerStep _step = _PickerStep.nativeLanguage;
  String? _nativeLanguage;

  final _search = TextEditingController();
  final _customController = TextEditingController();
  bool _showCustom = false;
  bool _saving = false;

  static const List<_LangOption> _nativeLanguages = [
    _LangOption('हिन्दी', 'Hindi'),
    _LangOption('বাংলা', 'Bengali'),
    _LangOption('தமிழ்', 'Tamil'),
    _LangOption('తెలుగు', 'Telugu'),
    _LangOption('मराठी', 'Marathi'),
    _LangOption('ગુજરાતી', 'Gujarati'),
    _LangOption('ಕನ್ನಡ', 'Kannada'),
    _LangOption('മലയാളം', 'Malayalam'),
    _LangOption('ਪੰਜਾਬੀ', 'Punjabi'),
    _LangOption('ଓଡ଼ିଆ', 'Odia'),
    _LangOption('অসমীয়া', 'Assamese'),
    _LangOption('اردو', 'Urdu'),
    _LangOption('বাংলা (বাংলাদেশ)', 'Bengali (Bangladesh)'),
    _LangOption('नेपाली', 'Nepali'),
    _LangOption('සිංහල', 'Sinhala'),
    _LangOption('မြန်မာ', 'Burmese'),
    _LangOption('ภาษาไทย', 'Thai'),
    _LangOption('Tiếng Việt', 'Vietnamese'),
    _LangOption('Bahasa Indonesia', 'Indonesian'),
    _LangOption('Bahasa Melayu', 'Malay'),
    _LangOption('العربية', 'Arabic'),
    _LangOption('فارسی', 'Persian'),
    _LangOption('தமிழ் (இலங்கை)', 'Tamil (Sri Lanka)'),
    _LangOption('English', 'English'),
  ];

  static const List<_LangOption> _targetLanguages = [
    _LangOption('English', 'English'),
    _LangOption('Español', 'Spanish'),
    _LangOption('Français', 'French'),
    _LangOption('Deutsch', 'German'),
    _LangOption('Italiano', 'Italian'),
    _LangOption('日本語', 'Japanese'),
    _LangOption('中文（简体）', 'Chinese (Simplified)'),
    _LangOption('中文（繁體）', 'Chinese (Traditional)'),
    _LangOption('한국어', 'Korean'),
    _LangOption('Português', 'Portuguese'),
    _LangOption('Русский', 'Russian'),
    _LangOption('العربية', 'Arabic'),
    _LangOption('Türkçe', 'Turkish'),
    _LangOption('Nederlands', 'Dutch'),
    _LangOption('Polski', 'Polish'),
    _LangOption('ภาษาไทย', 'Thai'),
    _LangOption('Tiếng Việt', 'Vietnamese'),
    _LangOption('Bahasa Indonesia', 'Indonesian'),
    _LangOption('हिन्दी', 'Hindi'),
    _LangOption('বাংলা', 'Bengali'),
    _LangOption('தமிழ்', 'Tamil'),
    _LangOption('తెలుగు', 'Telugu'),
    _LangOption('मराठी', 'Marathi'),
    _LangOption('ગુજરાતી', 'Gujarati'),
    _LangOption('ಕನ್ನಡ', 'Kannada'),
    _LangOption('മലയാളം', 'Malayalam'),
    _LangOption('ਪੰਜਾਬੀ', 'Punjabi'),
    _LangOption('ଓଡ଼ିଆ', 'Odia'),
    _LangOption('اردو', 'Urdu'),
    _LangOption('नेपाली', 'Nepali'),
  ];

  List<_LangOption> get _languages {
    switch (_step) {
      case _PickerStep.nativeLanguage:
        return _nativeLanguages;
      case _PickerStep.targetLanguage:
        return _targetLanguages;
    }
  }

  String get _stepTitle {
    switch (_step) {
      case _PickerStep.nativeLanguage:
        return 'What language do you speak?';
      case _PickerStep.targetLanguage:
        return 'What language do you want to learn?';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case _PickerStep.nativeLanguage:
        return 'This is the language you are most comfortable with. The AI will use it at first to explain things clearly.';
      case _PickerStep.targetLanguage:
        return 'Choose the language you want to practise. You can learn any language, not just English.';
    }
  }

  String get _searchHint {
    switch (_step) {
      case _PickerStep.nativeLanguage:
        return 'Search your native language…';
      case _PickerStep.targetLanguage:
        return 'Search a language to learn…';
    }
  }

  String get _customHint {
    switch (_step) {
      case _PickerStep.nativeLanguage:
        return 'Type your native language name (e.g. Bhojpuri, Konkani, Haryanvi)';
      case _PickerStep.targetLanguage:
        return 'Type any language you want to learn (e.g. Swahili, Dutch, Persian)';
    }
  }

  List<_LangOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _languages;
    return _languages
        .where((l) =>
            l.label.toLowerCase().contains(q) ||
            l.englishName.toLowerCase().contains(q))
        .toList();
  }

  void _resetStepUI() {
    _search.clear();
    _customController.clear();
    _showCustom = false;
  }

  Future<void> _selectNative(String language) async {
    setState(() {
      _nativeLanguage = language.trim();
      _step = _PickerStep.targetLanguage;
      _resetStepUI();
    });
  }

  Future<void> _saveAndNavigate(String targetLanguage) async {
    if (_saving) return;
    final native = _nativeLanguage;
    if (native == null || native.trim().isEmpty) {
      setState(() {
        _step = _PickerStep.nativeLanguage;
        _resetStepUI();
      });
      return;
    }
    setState(() => _saving = true);
    try {
      await LectureService.instance.setEnglishPracticePreference(
        nativeLanguage: native,
        targetLanguage: targetLanguage.trim(),
      );
      if (!mounted) return;
      if (widget.returnToPrevious) {
        Navigator.of(context).pop<String>(targetLanguage.trim());
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EnglishPracticeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save languages: $e')),
      );
    }
  }

  Future<void> _select(String language) async {
    final trimmed = language.trim();
    if (trimmed.isEmpty) return;
    switch (_step) {
      case _PickerStep.nativeLanguage:
        await _selectNative(trimmed);
        break;
      case _PickerStep.targetLanguage:
        await _saveAndNavigate(trimmed);
        break;
    }
  }

  void _goBack() {
    switch (_step) {
      case _PickerStep.nativeLanguage:
        if (widget.returnToPrevious) {
          Navigator.of(context).pop();
        }
        break;
      case _PickerStep.targetLanguage:
        setState(() {
          _step = _PickerStep.nativeLanguage;
          _resetStepUI();
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBack = _step == _PickerStep.targetLanguage || widget.returnToPrevious;
    final stepIndex = _step == _PickerStep.nativeLanguage ? 1 : 2;
    final totalSteps = 2;

    return Scaffold(
      appBar: AppBar(
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
                tooltip: 'Back',
              )
            : null,
        title: Text(_stepTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: stepIndex / totalSteps,
            minHeight: 3,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getAccentTint(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Step $stepIndex of $totalSteps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _stepSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                    height: 1.4,
                  ),
            ),
            if (_step == _PickerStep.targetLanguage &&
                _nativeLanguage != null) ...[
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    'Native language:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ),
                  Chip(
                    label: Text(_nativeLanguage!),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        for (final lang in _filtered)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                lang.label,
                                style: const TextStyle(fontSize: 16),
                              ),
                              subtitle: Text(lang.englishName),
                              onTap: () => _select(lang.englishName),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (!_showCustom)
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showCustom = true),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Other / Type your own'),
                          )
                        else ...[
                          TextField(
                            controller: _customController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: _customHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                final v = _customController.text.trim();
                                if (v.isEmpty) return;
                                _select(v);
                              },
                              child: Text(
                                _step == _PickerStep.nativeLanguage
                                    ? 'Continue'
                                    : 'Start learning',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
