import 'package:flutter/material.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';

/// Route target for "English Practice". The Practice shell renders first;
/// session resume happens asynchronously inside the screen.
class EnglishPracticeEntry extends StatefulWidget {
  const EnglishPracticeEntry({super.key});

  @override
  State<EnglishPracticeEntry> createState() => _EnglishPracticeEntryState();
}

class _EnglishPracticeEntryState extends State<EnglishPracticeEntry> {
  @override
  Widget build(BuildContext context) => const EnglishPracticeScreen(
    resumeLatest: true,
  );
}
