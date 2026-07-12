import 'package:examspark_frontend/core/models/teacher_profile_model.dart';

/// Type of content shared inside a group feed — drives icon + label in the
/// "Recent Shared Content" section of the Group Info screen.
enum GroupSharedItemType { lecture, homework, notes, quiz, announcement }

/// One shared item inside a group (lecture, homework, pinned notes, etc).
class GroupSharedItem {
  final String id;
  final String title;
  final GroupSharedItemType type;
  final DateTime sharedAt;
  final bool isPinned;

  const GroupSharedItem({
    required this.id,
    required this.title,
    required this.type,
    required this.sharedAt,
    this.isPinned = false,
  });

  /// [map] comes from the `group_shared_items` table.
  factory GroupSharedItem.fromMap(Map<String, dynamic> map) {
    return GroupSharedItem(
      id: map['id'] as String,
      title: map['title'] as String,
      type: GroupSharedItemType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => GroupSharedItemType.announcement,
      ),
      sharedAt: map['shared_at'] != null
          ? DateTime.parse(map['shared_at'] as String)
          : DateTime.now(),
      isPinned: map['is_pinned'] as bool? ?? false,
    );
  }
}

/// A Study Community group — always owned by exactly ONE teacher.
/// This is NOT a chat group: no messaging, only study content.
///
/// Backed by the Supabase `class_folders` table (Phase 4) — `id` maps to
/// `class_folders.id`. `isJoined` is resolved per-request from
/// `class_memberships` (there is no single "joined" column on the group
/// itself since it depends on the current user).
class GroupModel {
  final String id;
  final String name;
  final String description;
  final TeacherProfileModel teacher;
  final int studentsCount;
  final int sharedLecturesCount;
  final DateTime createdAt;
  final List<String> rules;
  final List<String> allowedContent;
  final List<GroupSharedItem> recentSharedItems;
  final bool isJoined;
  final String joinCode;
  final bool allowDownloads;
  final bool isPublic;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.teacher,
    this.studentsCount = 0,
    this.sharedLecturesCount = 0,
    required this.createdAt,
    this.rules = const [],
    this.allowedContent = const [],
    this.recentSharedItems = const [],
    this.isJoined = false,
    this.joinCode = '',
    this.allowDownloads = false,
    this.isPublic = true,
  });

  /// [map] comes from the `class_folders` table. `teacher`, counts, and feed
  /// items are resolved via separate queries (teacher_profiles,
  /// class_memberships count, group_shared_items) and passed in here.
  factory GroupModel.fromMap(
    Map<String, dynamic> map, {
    required TeacherProfileModel teacher,
    int studentsCount = 0,
    int sharedLecturesCount = 0,
    List<String> rules = const [],
    List<String> allowedContent = const [],
    List<GroupSharedItem> recentSharedItems = const [],
    bool isJoined = false,
  }) {
    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      teacher: teacher,
      studentsCount: studentsCount,
      sharedLecturesCount: sharedLecturesCount,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      rules: rules,
      allowedContent: allowedContent,
      recentSharedItems: recentSharedItems,
      isJoined: isJoined,
      joinCode: map['join_code'] as String? ?? '',
      allowDownloads: map['allow_downloads'] as bool? ?? false,
      isPublic: map['is_public'] as bool? ?? true,
    );
  }

  GroupModel copyWith({bool? isJoined}) {
    return GroupModel(
      id: id,
      name: name,
      description: description,
      teacher: teacher,
      studentsCount: studentsCount,
      sharedLecturesCount: sharedLecturesCount,
      createdAt: createdAt,
      rules: rules,
      allowedContent: allowedContent,
      recentSharedItems: recentSharedItems,
      isJoined: isJoined ?? this.isJoined,
      joinCode: joinCode,
      allowDownloads: allowDownloads,
      isPublic: isPublic,
    );
  }
}
