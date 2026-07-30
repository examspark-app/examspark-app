/// Student onboarding data — filled on the "Tell us about yourself" screen
/// shown right after signup. `username`/`avatarColor` live on `users`
/// (shared with teachers); `age`/`educationLevel`/`subjects` live on the
/// `student_profiles` table (Phase 4 `student_onboarding_migration.sql`).
class StudentProfileModel {
  final String userId;
  final String? username;
  final String? avatarColor;
  final int? age;
  final String? educationLevel;
  final List<String> subjects;
  final bool onboardingCompleted;

  const StudentProfileModel({
    required this.userId,
    this.username,
    this.avatarColor,
    this.age,
    this.educationLevel,
    this.subjects = const [],
    this.onboardingCompleted = false,
  });

  /// [usersMap] is a row from `users` (username, avatar_color,
  /// onboarding_completed). [studentProfileMap] is the matching row from
  /// `student_profiles`, if one exists yet (null before onboarding).
  factory StudentProfileModel.fromMaps(
    Map<String, dynamic> usersMap, {
    Map<String, dynamic>? studentProfileMap,
  }) {
    return StudentProfileModel(
      userId: usersMap['id'] as String,
      username: usersMap['username'] as String?,
      avatarColor: usersMap['avatar_color'] as String?,
      onboardingCompleted: usersMap['onboarding_completed'] as bool? ?? false,
      age: (studentProfileMap?['age'] as num?)?.toInt(),
      educationLevel: studentProfileMap?['education_level'] as String?,
      subjects: studentProfileMap?['subjects'] != null
          ? List<String>.from(studentProfileMap!['subjects'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toUsersMap() {
    return {
      'username': username,
      'avatar_color': avatarColor,
      'onboarding_completed': onboardingCompleted,
    };
  }

  Map<String, dynamic> toStudentProfileMap() {
    return {
      'user_id': userId,
      'age': age,
      'education_level': educationLevel,
      'subjects': subjects,
    };
  }

  StudentProfileModel copyWith({
    String? username,
    String? avatarColor,
    int? age,
    String? educationLevel,
    List<String>? subjects,
    bool? onboardingCompleted,
  }) {
    return StudentProfileModel(
      userId: userId,
      username: username ?? this.username,
      avatarColor: avatarColor ?? this.avatarColor,
      age: age ?? this.age,
      educationLevel: educationLevel ?? this.educationLevel,
      subjects: subjects ?? this.subjects,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
