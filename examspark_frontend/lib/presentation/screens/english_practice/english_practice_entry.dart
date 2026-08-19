import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_language_picker_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';

/// Route target for "English Practice" — decides picker vs chat based on
/// whether the student already has a saved native-language preference.
class EnglishPracticeEntry extends StatefulWidget {
  const EnglishPracticeEntry({super.key});

  @override
  State<EnglishPracticeEntry> createState() => _EnglishPracticeEntryState();
}

class _EnglishPracticeEntryState extends State<EnglishPracticeEntry> {
  bool _loading = true;
  bool _hasLanguage = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final lang = await LectureService.instance.getEnglishPracticeLanguage();
      if (!mounted) return;
      setState(() {
        _hasLanguage = lang != null && lang.trim().isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasLanguage = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _hasLanguage
        ? const EnglishPracticeScreen()
        : const EnglishLanguagePickerScreen();
  }
}
