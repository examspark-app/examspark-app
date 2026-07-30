/// Category of a teacher achievement — controls icon + grouping in UI.
enum TeacherAchievementType { qualification, award, document }

/// One achievement/proof shown on the Teacher Profile — rendered only
/// if the teacher has actually uploaded something (never fabricated).
///
/// Backed by the Supabase `teacher_achievements` table (Phase 4).
class TeacherAchievementModel {
  final String id;
  final String title;
  final String? description;
  final TeacherAchievementType type;
  final String? imageUrl;

  const TeacherAchievementModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.imageUrl,
  });

  factory TeacherAchievementModel.fromMap(Map<String, dynamic> map) {
    return TeacherAchievementModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      type: TeacherAchievementType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TeacherAchievementType.award,
      ),
      imageUrl: map['image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String teacherId}) {
    return {
      'teacher_id': teacherId,
      'title': title,
      'description': description,
      'type': type.name,
      'image_url': imageUrl,
    };
  }
}
