import 'package:flutter/material.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_language_picker_screen.dart';

/// Route target for "English Practice". Every new entry starts with an
/// explicit native/target language choice; saved preferences still provide
/// the active defaults to the backend after selection.
class EnglishPracticeEntry extends StatefulWidget {
  const EnglishPracticeEntry({super.key});

  @override
  State<EnglishPracticeEntry> createState() => _EnglishPracticeEntryState();
}

class _EnglishPracticeEntryState extends State<EnglishPracticeEntry> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => const EnglishLanguagePickerScreen();
}
