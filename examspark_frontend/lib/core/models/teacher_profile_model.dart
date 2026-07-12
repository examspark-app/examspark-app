import 'package:examspark_frontend/core/models/teacher_achievement_model.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';

/// Verification state shown as a badge on the teacher's public profile.
enum TeacherVerificationStatus { verified, pending, unverified }

/// Full public Teacher Profile — shown in the Teacher Dashboard (edit mode
/// for the teacher) and inside the Group Info screen (read-only, for
/// students browsing/joining a group).
///
/// Backed by the Supabase `teacher_profiles` table (Phase 4). `id` is the
/// `teacher_profiles.id` primary key; `userId` is the owning `auth.users.id`
/// (`users.id`) used for ownership checks — e.g. "is this my own profile".
class TeacherProfileModel {
  final String id;
  final String? userId;
  final String fullName;
  final String? photoUrl;
  final String subject;
  final String? bio;
  final String? qualification;
  final int experienceYears;
  final TeacherVerificationStatus verificationStatus;
  final DateTime joinedSince;
  final int totalStudents;
  final int totalGroups;
  final int totalSharedLectures;
  final List<TeacherCertificateModel> certificates;
  final List<TeacherAchievementModel> achievements;

  const TeacherProfileModel({
    required this.id,
    this.userId,
    required this.fullName,
    this.photoUrl,
    required this.subject,
    this.bio,
    this.qualification,
    this.experienceYears = 0,
    this.verificationStatus = TeacherVerificationStatus.unverified,
    required this.joinedSince,
    this.totalStudents = 0,
    this.totalGroups = 0,
    this.totalSharedLectures = 0,
    this.certificates = const [],
    this.achievements = const [],
  });

  bool get isVerified => verificationStatus == TeacherVerificationStatus.verified;

  /// [map] comes from the `teacher_profiles` table. Certificates/achievements
  /// are fetched separately (`teacher_certificates`/`teacher_achievements`
  /// filtered by `teacher_id = map['id']`) and passed in here since Supabase
  /// nested-select shape varies by query.
  factory TeacherProfileModel.fromMap(
    Map<String, dynamic> map, {
    List<TeacherCertificateModel> certificates = const [],
    List<TeacherAchievementModel> achievements = const [],
    int totalStudents = 0,
    int totalGroups = 0,
    int totalSharedLectures = 0,
  }) {
    return TeacherProfileModel(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      fullName: map['full_name'] as String,
      photoUrl: map['photo_url'] as String?,
      subject: map['subject'] as String,
      bio: map['bio'] as String?,
      qualification: map['qualification'] as String?,
      experienceYears: (map['experience_years'] as num?)?.toInt() ?? 0,
      verificationStatus: TeacherVerificationStatus.values.firstWhere(
        (s) => s.name == map['verification_status'],
        orElse: () => TeacherVerificationStatus.unverified,
      ),
      joinedSince: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      totalStudents: totalStudents,
      totalGroups: totalGroups,
      totalSharedLectures: totalSharedLectures,
      certificates: certificates,
      achievements: achievements,
    );
  }

  Map<String, dynamic> toMap({required String userId}) {
    return {
      'user_id': userId,
      'full_name': fullName,
      'photo_url': photoUrl,
      'subject': subject,
      'bio': bio,
      'qualification': qualification,
      'experience_years': experienceYears,
      'verification_status': verificationStatus.name,
    };
  }

  /// Controls whether the "Teacher Achievements" section renders at all —
  /// spec rule: "Only if uploaded."
  bool get hasAchievements => certificates.isNotEmpty || achievements.isNotEmpty;

  TeacherProfileModel copyWith({
    String? fullName,
    String? photoUrl,
    String? subject,
    String? bio,
    String? qualification,
    int? experienceYears,
    TeacherVerificationStatus? verificationStatus,
    int? totalStudents,
    int? totalGroups,
    int? totalSharedLectures,
    List<TeacherCertificateModel>? certificates,
    List<TeacherAchievementModel>? achievements,
  }) {
    return TeacherProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      subject: subject ?? this.subject,
      bio: bio ?? this.bio,
      qualification: qualification ?? this.qualification,
      experienceYears: experienceYears ?? this.experienceYears,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      joinedSince: joinedSince,
      totalStudents: totalStudents ?? this.totalStudents,
      totalGroups: totalGroups ?? this.totalGroups,
      totalSharedLectures: totalSharedLectures ?? this.totalSharedLectures,
      certificates: certificates ?? this.certificates,
      achievements: achievements ?? this.achievements,
    );
  }
}
