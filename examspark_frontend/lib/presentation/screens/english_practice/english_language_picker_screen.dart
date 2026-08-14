import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';

/// One-time picker — student's native/local language, shown in its own
/// script so a non-English-comfortable student can read it easily.
class EnglishLanguagePickerScreen extends StatefulWidget {
  const EnglishLanguagePickerScreen({super.key});

  @override
  State<EnglishLanguagePickerScreen> createState() =>
      _EnglishLanguagePickerScreenState();
}

class _LangOption {
  final String label; // shown in its own script
  final String englishName; // for search matching
  const _LangOption(this.label, this.englishName);
}

class _EnglishLanguagePickerScreenState
    extends State<EnglishLanguagePickerScreen> {
  final _search = TextEditingController();
  final _customController = TextEditingController();
  bool _showCustom = false;
  bool _saving = false;

  static const List<_LangOption> _languages = [
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
    _LangOption('English', 'English'),
  ];

  List<_LangOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _languages;
    return _languages
        .where((l) =>
            l.label.toLowerCase().contains(q) ||
            l.englishName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _select(String language) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await LectureService.instance.setEnglishPracticeLanguage(language);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EnglishPracticeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save language: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your language')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI will explain and teach English in this language first.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search your language…',
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
                            label: const Text('My language is not listed'),
                          )
                        else ...[
                          TextField(
                            controller: _customController,
                            decoration: InputDecoration(
                              hintText: 'Type your language name',
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
                              child: const Text('Continue'),
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