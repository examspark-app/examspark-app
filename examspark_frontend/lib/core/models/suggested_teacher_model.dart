/// Lightweight teacher card shown in discovery / suggested rows.
class SuggestedTeacherModel {
  final String id;
  final String? userId;
  final String name;
  final String? photoUrl;
  final String subject;
  final String? city;
  final String? state;
  final int? studentCount;
  final bool isVerified;
  final bool isJoined;
  /// Personalized match 0–100 (redistributed weights). Null if unscored.
  final int? matchScore;
  /// e.g. Subject, Exam, City — why this teacher was suggested.
  final List<String> matchedFactors;

  const SuggestedTeacherModel({
    required this.id,
    this.userId,
    required this.name,
    this.photoUrl,
    required this.subject,
    this.city,
    this.state,
    this.studentCount,
    this.isVerified = false,
    this.isJoined = false,
    this.matchScore,
    this.matchedFactors = const [],
  });

  String get matchesLabel {
    if (matchedFactors.isEmpty) return '';
    return 'Matches: ${matchedFactors.join(', ')}';
  }

  factory SuggestedTeacherModel.fromMap(
    Map<String, dynamic> map, {
    bool isJoined = false,
    int? studentCount,
    int? matchScore,
    List<String>? matchedFactors,
  }) {
    return SuggestedTeacherModel(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      name: map['full_name'] as String? ?? 'Teacher',
      photoUrl: map['photo_url'] as String?,
      subject: map['subject'] as String? ?? '',
      city: map['city'] as String?,
      state: map['state'] as String?,
      studentCount: studentCount,
      isVerified: map['verification_status'] == 'verified',
      isJoined: isJoined,
      matchScore: matchScore,
      matchedFactors: matchedFactors ?? const [],
    );
  }

  SuggestedTeacherModel copyWith({
    bool? isJoined,
    int? studentCount,
    int? matchScore,
    List<String>? matchedFactors,
  }) {
    return SuggestedTeacherModel(
      id: id,
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      subject: subject,
      city: city,
      state: state,
      studentCount: studentCount ?? this.studentCount,
      isVerified: isVerified,
      isJoined: isJoined ?? this.isJoined,
      matchScore: matchScore ?? this.matchScore,
      matchedFactors: matchedFactors ?? this.matchedFactors,
    );
  }
}
