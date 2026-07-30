/// One reusable lecture in the Teacher Library (single source of truth).
class TeacherLibraryItem {
  final String lectureId;
  final String title;
  final String? subject;
  final DateTime? createdAt;
  final String? sourceType;
  /// Groups this lecture is already linked to (not copies).
  final List<TeacherLibrarySharedGroup> sharedTo;

  const TeacherLibraryItem({
    required this.lectureId,
    required this.title,
    this.subject,
    this.createdAt,
    this.sourceType,
    this.sharedTo = const [],
  });

  Set<String> get sharedClassIds =>
      sharedTo.map((g) => g.classId).toSet();

  String get sharedToLabel {
    if (sharedTo.isEmpty) return 'Not shared to any group yet';
    return 'Shared to: ${sharedTo.map((g) => g.name).join(', ')}';
  }
}

class TeacherLibrarySharedGroup {
  final String classId;
  final String name;

  const TeacherLibrarySharedGroup({
    required this.classId,
    required this.name,
  });
}
