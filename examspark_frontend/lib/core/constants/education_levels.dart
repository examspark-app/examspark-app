/// Education level options shown on the student onboarding screen.
/// Stored as-is in `student_profiles.education_level` (TEXT, not an enum
/// column) so this list can grow without a migration.
const List<String> kEducationLevels = [
  'School (Class 6–8)',
  'School (Class 9–10)',
  'School (Class 11–12)',
  'Undergraduate',
  'Postgraduate',
  'Exam Prep (NEET/JEE/UPSC)',
  'Other',
];
