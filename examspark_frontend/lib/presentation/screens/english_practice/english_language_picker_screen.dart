import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
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
  static const violet = Color(0xFF5137ED);

  _PickerStep _step = _PickerStep.nativeLanguage;
  String? _nativeLanguage;
  String? _targetLanguage;

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

  // A small rotating palette so each language tile's avatar gets a
  // distinct, friendly colour without needing real flag art.
  static const List<Color> _avatarPalette = [
    Color(0xFF5137ED),
    Color(0xFFEF5DA8),
    Color(0xFF2FB4A6),
    Color(0xFFF2A93B),
    Color(0xFF5B8DEF),
    Color(0xFFE0655B),
    Color(0xFF8A5CF6),
    Color(0xFF3FB27F),
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
        .where(
          (l) =>
              l.label.toLowerCase().contains(q) ||
              l.englishName.toLowerCase().contains(q),
        )
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

  Future<void> _selectTarget(String language) async {
    setState(() {
      _targetLanguage = language.trim();
    });
    await _saveAndNavigate('qwen3');
  }

  Future<void> _saveAndNavigate(String model) async {
    if (_saving) return;
    final native = _nativeLanguage;
    final target = _targetLanguage;
    if (native == null ||
        native.trim().isEmpty ||
        target == null ||
        target.isEmpty) {
      setState(() {
        _step = _PickerStep.nativeLanguage;
        _resetStepUI();
      });
      return;
    }
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
              'Claude Premium is available on the ₹499 or ₹999 plan. Upgrade to use it for Chat.',
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
    setState(() => _saving = true);
    try {
      await LectureService.instance.setEnglishPracticePreference(
        nativeLanguage: native,
        targetLanguage: target,
      );
      if (!mounted) return;
      if (widget.returnToPrevious) {
        Navigator.of(
          context,
        ).pop<Map<String, String>>({'targetLanguage': target, 'model': model});
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EnglishPracticeScreen(
              textModel: model == 'gemini'
                  ? 'gemini'
                  : model == 'claude'
                  ? 'claude'
                  : 'qwen3',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save languages: $e')));
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
        await _selectTarget(trimmed);
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

  Color _avatarColorFor(int index) =>
      _avatarPalette[index % _avatarPalette.length];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryText = AppTheme.getPrimaryText(context);
    final subText = AppTheme.getSecondaryText(context);
    final cardBg = AppTheme.getCardBackground(context);
    final cardBorder = AppTheme.getCardBorder(context);
    final inputBg = AppTheme.getInputBackground(context);

    final showBack =
        _step != _PickerStep.nativeLanguage || widget.returnToPrevious;
    final stepIndex = _step == _PickerStep.nativeLanguage ? 1 : 2;
    const totalSteps = 2;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF241B57), const Color(0xFF15111F)]
                      : [const Color(0xFFEDE8FE), const Color(0xFFFAF7FF)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBack)
                        IconButton(
                          onPressed: _goBack,
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white : const Color(0xFF1E1B2C),
                          ),
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.06),
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                      const Spacer(),
                      _StepDots(current: stepIndex, total: totalSteps),
                      const Spacer(),
                      SizedBox(width: showBack ? 48 : 8),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: violet.withOpacity(isDark ? 0.24 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _step == _PickerStep.nativeLanguage
                          ? Icons.record_voice_over_rounded
                          : Icons.translate_rounded,
                      color: violet,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _stepTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stepSubtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: subText,
                      height: 1.45,
                    ),
                  ),
                  if (_step != _PickerStep.nativeLanguage &&
                      _nativeLanguage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: violet),
                          const SizedBox(width: 6),
                          Text(
                            'Speaks $_nativeLanguage',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: _saving
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: violet),
                          const SizedBox(height: 14),
                          Text(
                            'Setting things up…',
                            style: TextStyle(color: subText, fontSize: 13.5),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      children: [
                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: primaryText, fontSize: 14.5),
                            decoration: InputDecoration(
                              hintText: _searchHint,
                              hintStyle: TextStyle(color: subText, fontSize: 14.5),
                              prefixIcon: Icon(Icons.search_rounded, color: subText),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Language grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filtered.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.5,
                          ),
                          itemBuilder: (context, index) {
                            final lang = _filtered[index];
                            final color = _avatarColorFor(index);
                            return _LanguageTile(
                              option: lang,
                              color: color,
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              primaryText: primaryText,
                              subText: subText,
                              onTap: () => _select(lang.englishName),
                            );
                          },
                        ),

                        const SizedBox(height: 18),

                        // Custom / "type your own" section
                        if (!_showCustom)
                          InkWell(
                            onTap: () => setState(() => _showCustom = true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: violet.withOpacity(0.4),
                                  width: 1.2,
                                ),
                                color: violet.withOpacity(isDark ? 0.10 : 0.05),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined,
                                      color: violet, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Not listed? Type your own',
                                    style: TextStyle(
                                      color: violet,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                              color: cardBg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _customController,
                                  autofocus: true,
                                  style: TextStyle(
                                      color: primaryText, fontSize: 14.5),
                                  decoration: InputDecoration(
                                    hintText: _customHint,
                                    hintStyle:
                                        TextStyle(color: subText, fontSize: 13),
                                    filled: true,
                                    fillColor: inputBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: violet,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      final v = _customController.text.trim();
                                      if (v.isEmpty) return;
                                      _select(v);
                                    },
                                    child: Text(
                                      _step == _PickerStep.nativeLanguage
                                          ? 'Continue'
                                          : 'Start learning',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
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
          ],
        ),
      ),
    );
  }
}

/// Small dot-and-line progress indicator shown in the header.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});
  final int current;
  final int total;

  static const violet = Color(0xFF5137ED);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= total; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= current
                  ? violet
                  : violet.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (i != total) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// One selectable language card: coloured initial avatar, native-script
/// label, and the English name underneath.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.option,
    required this.color,
    required this.cardBg,
    required this.cardBorder,
    required this.primaryText,
    required this.subText,
    required this.onTap,
  });

  final _LangOption option;
  final Color color;
  final Color cardBg;
  final Color cardBorder;
  final Color primaryText;
  final Color subText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.englishName.isNotEmpty
                      ? option.englishName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      option.englishName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subText,
                        fontSize: 11,
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
}