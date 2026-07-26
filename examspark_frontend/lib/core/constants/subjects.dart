import 'package:examspark_frontend/core/constants/custom_field_option.dart';

/// Subjects — short global starter list + Custom… in UI.
/// Used by Create Group, Discover, recording, onboarding, teacher setup chips.
/// Keep one list so Discover / suggest stay consistent (founder Option A).

const List<String> kSubjectOptions = [
  // STEM
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'Computer Science',
  'Information Technology',
  'Statistics',
  'Engineering Basics',
  // Languages & humanities
  'English',
  'Hindi',
  'History',
  'Geography',
  'Political Science',
  'Sociology',
  'Psychology',
  'Philosophy',
  // Commerce
  'Economics',
  'Accountancy',
  'Business Studies',
  'Commerce',
  // Applied / school extras
  'Environmental Science',
  'Physical Education',
  'Art',
  'Music',
  'General Science',
  'Social Studies',
];

/// Alias — Discover + Create Group use the same presets (+ Custom… in UI).
const List<String> kDiscoverSubjectOptions = kSubjectOptions;

/// Dropdown items: presets + Custom…
List<String> get kSubjectOptionsWithCustom =>
    CustomFieldOption.presetsPlusCustom(kSubjectOptions);
