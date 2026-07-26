import 'package:examspark_frontend/core/constants/custom_field_option.dart';

/// Exam / board — short starter (India + common global) + Custom… in UI.
/// Full world boards are NOT listed — Custom avoids “my country missing” barrier.
class ExamBoards {
  ExamBoards._();

  static const List<String> all = [
    'School',
    'CBSE',
    'ICSE',
    'State Board',
    'WB Board',
    'NEET',
    'JEE',
    'CUET',
    'SSC',
    'UPSC',
    'IGCSE',
    'IB',
    'A-Levels',
    'SAT',
    'ACT',
    'AP',
  ];

  static List<String> get withCustom =>
      CustomFieldOption.presetsPlusCustom(all);

  static List<String> optionsFor(String? current) {
    final c = (current ?? '').trim();
    if (c.isEmpty || all.contains(c) || c == CustomFieldOption.label) {
      return withCustom;
    }
    return [c, ...withCustom];
  }
}
