import 'package:examspark_frontend/core/constants/custom_field_option.dart';

/// Teaching / group / student preferred languages.
/// Short world starter list + Custom… in UI (not India-only wall).
class TeachingLanguages {
  TeachingLanguages._();

  static const List<String> all = [
    'English',
    'Hindi',
    'Bengali',
    'Tamil',
    'Telugu',
    'Marathi',
    'Gujarati',
    'Kannada',
    'Malayalam',
    'Punjabi',
    'Urdu',
    'Odia',
    'Assamese',
    'Nepali',
    'Sinhala',
    'Arabic',
    'French',
    'Spanish',
    'Portuguese',
    'German',
    'Chinese',
    'Japanese',
    'Korean',
    'Russian',
    'Turkish',
    'Indonesian',
    'Mixed',
  ];

  /// Presets + Custom… for dropdowns.
  static List<String> get withCustom =>
      CustomFieldOption.presetsPlusCustom(all);

  /// If stored value is missing from [all], still show it once (legacy / custom).
  static List<String> optionsFor(String? current) {
    final c = (current ?? '').trim();
    if (c.isEmpty || all.contains(c) || c == CustomFieldOption.label) {
      return withCustom;
    }
    return [c, ...withCustom];
  }
}
