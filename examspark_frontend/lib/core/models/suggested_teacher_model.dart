/// Lightweight teacher card shown in the horizontal "Suggested Teachers"
/// row — intentionally slimmer than [TeacherProfileModel] since it is used
/// only for discovery, not the full profile view.
class SuggestedTeacherModel {
  final String id;
  final String name;
  final String? photoUrl;
  final String subject;
  final bool isVerified;
  final bool isJoined;

  const SuggestedTeacherModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.subject,
    this.isVerified = false,
    this.isJoined = false,
  });

  /// [map] comes from the `teacher_profiles` table; [isJoined] is resolved
  /// separately via `class_memberships` since it depends on the current user.
  factory SuggestedTeacherModel.fromMap(
    Map<String, dynamic> map, {
    bool isJoined = false,
  }) {
    return SuggestedTeacherModel(
      id: map['id'] as String,
      name: map['full_name'] as String,
      photoUrl: map['photo_url'] as String?,
      subject: map['subject'] as String,
      isVerified: map['verification_status'] == 'verified',
      isJoined: isJoined,
    );
  }

  SuggestedTeacherModel copyWith({bool? isJoined}) {
    return SuggestedTeacherModel(
      id: id,
      name: name,
      photoUrl: photoUrl,
      subject: subject,
      isVerified: isVerified,
      isJoined: isJoined ?? this.isJoined,
    );
  }
}
