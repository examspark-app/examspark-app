class SuggestedTeacherModel {
  final String id;
  final String name;
  final String subject;
  final String? city;
  final String? state;
  final String? photoUrl;
  final int? matchScore;
  final String matchesLabel;
  final int? studentCount;
  final bool isJoined;
  final String? userId;
  final List<dynamic> groups;
  final bool isVerified;

  const SuggestedTeacherModel({
    required this.id,
    required this.name,
    this.subject = '',
    this.city,
    this.state,
    this.photoUrl,
    this.matchScore,
    this.matchesLabel = '',
    this.studentCount,
    this.isJoined = false,
    this.userId,
    this.groups = const [],
    this.isVerified = false,
  });

  factory SuggestedTeacherModel.fromJson(Map<String, dynamic> json) {
    return SuggestedTeacherModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      photoUrl: json['photo_url']?.toString() ?? json['photoUrl']?.toString(),
      matchScore: json['match_score'] ?? json['matchScore'],
      matchesLabel: json['matches_label']?.toString() ?? json['matchesLabel']?.toString() ?? '',
      studentCount: json['student_count'] ?? json['studentCount'],
      isJoined: json['is_joined'] ?? json['isJoined'] ?? false,
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      groups: json['groups'] ?? json['class_folders'] ?? [],
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
    );
  }

  factory SuggestedTeacherModel.fromMap(Map<String, dynamic> map) {
    return SuggestedTeacherModel.fromJson(map);
  }

  SuggestedTeacherModel copyWith({
    String? id,
    String? name,
    String? subject,
    String? city,
    String? state,
    String? photoUrl,
    int? matchScore,
    String? matchesLabel,
    int? studentCount,
    bool? isJoined,
    String? userId,
    List<dynamic>? groups,
    bool? isVerified,
  }) {
    return SuggestedTeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      city: city ?? this.city,
      state: state ?? this.state,
      photoUrl: photoUrl ?? this.photoUrl,
      matchScore: matchScore ?? this.matchScore,
      matchesLabel: matchesLabel ?? this.matchesLabel,
      studentCount: studentCount ?? this.studentCount,
      isJoined: isJoined ?? this.isJoined,
      userId: userId ?? this.userId,
      groups: groups ?? this.groups,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}