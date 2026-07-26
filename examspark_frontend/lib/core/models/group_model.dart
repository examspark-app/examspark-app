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
  /// Teacher's lecture id when this share points at generated content.
  final String? lectureId;
  /// Text body for announcements / short notes.
  final String? body;
  /// Teacher-selected chips students may open (null = legacy all tabs).
  final List<String>? sharedChips;

  const GroupSharedItem({
    required this.id,
    required this.title,
    required this.type,
    required this.sharedAt,
    this.isPinned = false,
    this.lectureId,
    this.body,
    this.sharedChips,
  });

  /// [map] comes from the `group_shared_items` table.
  factory GroupSharedItem.fromMap(Map<String, dynamic> map) {
    return GroupSharedItem(
      id: map['id'] as String,
      title: map['title'] as String,
      type: parseType(map['type'] as String?),
      sharedAt: map['shared_at'] != null
          ? DateTime.parse(map['shared_at'] as String)
          : DateTime.now(),
      isPinned: map['is_pinned'] as bool? ?? false,
      lectureId: map['lecture_id'] as String?,
      body: map['body'] as String?,
      sharedChips: _parseChips(map['shared_chips']),
    );
  }

  static List<String>? _parseChips(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    final out = <String>[];
    for (final e in raw) {
      final s = e?.toString().trim().toLowerCase();
      if (s != null && s.isNotEmpty) out.add(s);
    }
    return out;
  }

  /// Never default unknown types to [announcement] — that mislabeled
  /// lecture/notes shares as "Announcement" for students in the feed.
  static GroupSharedItemType parseType(String? raw) {
    final t = (raw ?? '').trim().toLowerCase();
    for (final v in GroupSharedItemType.values) {
      if (v.name == t) return v;
    }
    if (t.contains('quiz') || t.contains('mcq')) {
      return GroupSharedItemType.quiz;
    }
    if (t.contains('note')) return GroupSharedItemType.notes;
    if (t.contains('homework') || t.contains('assign')) {
      return GroupSharedItemType.homework;
    }
    if (t.contains('announce')) return GroupSharedItemType.announcement;
    // Safe study default — not announcement.
    return GroupSharedItemType.lecture;
  }

  GroupSharedItem copyWith({bool? isPinned, String? body}) {
    return GroupSharedItem(
      id: id,
      title: title,
      type: type,
      sharedAt: sharedAt,
      isPinned: isPinned ?? this.isPinned,
      lectureId: lectureId,
      body: body ?? this.body,
      sharedChips: sharedChips,
    );
  }

  /// Pinned first (WhatsApp-channel feel), then newest.
  static List<GroupSharedItem> sortedForFeed(Iterable<GroupSharedItem> items) {
    final list = items.toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.sharedAt.compareTo(a.sharedAt);
    });
    return list;
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
  /// Owner auth user id from `class_folders.teacher_id` (source of truth).
  final String teacherUserId;
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
    this.teacherUserId = '',
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

  /// True only for the group owner teacher — students never.
  bool isOwnedByUser(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (teacherUserId.isNotEmpty) return teacherUserId == userId;
    return teacher.userId == userId;
  }

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
    final tid = (map['teacher_id'] as String?) ?? teacher.userId ?? '';
    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      teacher: teacher,
      teacherUserId: tid,
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

  GroupModel copyWith({
    bool? isJoined,
    List<GroupSharedItem>? recentSharedItems,
  }) {
    return GroupModel(
      id: id,
      name: name,
      description: description,
      teacher: teacher,
      teacherUserId: teacherUserId,
      studentsCount: studentsCount,
      sharedLecturesCount: sharedLecturesCount,
      createdAt: createdAt,
      rules: rules,
      allowedContent: allowedContent,
      recentSharedItems: recentSharedItems ?? this.recentSharedItems,
      isJoined: isJoined ?? this.isJoined,
      joinCode: joinCode,
      allowDownloads: allowDownloads,
      isPublic: isPublic,
    );
  }
}
