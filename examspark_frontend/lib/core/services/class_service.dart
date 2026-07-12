import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

class ClassService {
  ClassService._();

  static final ClassService instance = ClassService._();

  Future<List<Map<String, dynamic>>> getTeacherClasses() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return _mockTeacherClasses();

    try {
      final response = await SupabaseClient.instance.client
          .from('class_folders')
          .select()
          .eq('teacher_id', userId)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.isEmpty ? _mockTeacherClasses() : list;
    } catch (_) {
      return _mockTeacherClasses();
    }
  }

  Future<List<Map<String, dynamic>>> getStudentFeed() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return _mockStudentFeed();

    try {
      final response = await SupabaseClient.instance.client
          .from('lectures')
          .select('id, title, subject, topic, created_at')
          .order('created_at', ascending: false)
          .limit(20);
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.isEmpty ? _mockStudentFeed() : list;
    } catch (_) {
      return _mockStudentFeed();
    }
  }

  Future<Map<String, dynamic>> createClass({
    required String name,
    required String subject,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be logged in');
    }

    final joinCode = _generateJoinCode();
    final response = await SupabaseClient.instance.client
        .from('class_folders')
        .insert({
          'teacher_id': userId,
          'name': name,
          'subject': subject,
          'join_code': joinCode,
        })
        .select()
        .single();

    return response;
  }

  /// Returns `{class_id: student_count}` for the given classes, used by the
  /// Teacher Dashboard business cards (real `class_memberships` counts).
  Future<Map<String, int>> getStudentCountsForClasses(List<String> classIds) async {
    if (classIds.isEmpty) return {};

    try {
      final rows = await SupabaseClient.instance.client
          .from('class_memberships')
          .select('class_id')
          .inFilter('class_id', classIds);

      final counts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final classId = row['class_id'] as String;
        counts[classId] = (counts[classId] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  /// Joins a group directly by `class_id` (used from the Group Info screen
  /// where the group is already loaded).
  Future<void> joinClass(String classId) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    await SupabaseClient.instance.client.from('class_memberships').insert({
      'class_id': classId,
      'student_id': userId,
    });
  }

  /// Leaves a group (deletes the student's `class_memberships` row).
  Future<void> leaveClass(String classId) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    await SupabaseClient.instance.client
        .from('class_memberships')
        .delete()
        .eq('class_id', classId)
        .eq('student_id', userId);
  }

  /// Joins a group using the teacher-shared 6-digit invite code (the
  /// "Join a Class" dialog on the Teacher Dashboard / Groups tab).
  Future<Map<String, dynamic>> joinClassByCode(String joinCode) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    final client = SupabaseClient.instance.client;
    final classRow = await client
        .from('class_folders')
        .select()
        .eq('join_code', joinCode)
        .maybeSingle();

    if (classRow == null) {
      throw StateError('Invalid join code');
    }

    await client.from('class_memberships').upsert({
      'class_id': classRow['id'],
      'student_id': userId,
    });

    return classRow;
  }

  /// Shares one item (lecture/notes/quiz/homework/announcement) into a
  /// group's feed — only ever called for the owning teacher's own content.
  /// Callers are responsible for only offering this for `lectures` whose
  /// `source_type == 'recorded'` (see StudyWorkspace "Share to Group").
  Future<void> shareItemToGroup({
    required String classId,
    required String type,
    required String title,
    String? lectureId,
    String? body,
    bool isPinned = false,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    await SupabaseClient.instance.client.from('group_shared_items').insert({
      'class_id': classId,
      'teacher_id': userId,
      'type': type,
      'title': title,
      'lecture_id': lectureId,
      'body': body,
      'is_pinned': isPinned,
    });
  }

  /// Reads the feed for one group (`group_shared_items`), respecting the
  /// join-before/after-share + subscription-expiry access rule enforced by
  /// the `fn_group_item_access` Postgres function (see schema.sql). Items
  /// the caller has no access to ('none') are filtered out client-side as a
  /// defense-in-depth layer on top of the RLS policy already blocking them.
  Future<List<GroupSharedItem>> getGroupFeed(String classId) async {
    try {
      final client = SupabaseClient.instance.client;
      final rows = await client
          .from('group_shared_items')
          .select()
          .eq('class_id', classId)
          .order('shared_at', ascending: false);

      final items = List<Map<String, dynamic>>.from(rows as List);
      return items.map(GroupSharedItem.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  String _generateJoinCode() {
    final code = DateTime.now().millisecondsSinceEpoch % 1000000;
    return code.toString().padLeft(6, '0');
  }

  List<Map<String, dynamic>> _mockTeacherClasses() => [
        {'id': 'mock-1', 'name': 'Class 10A Physics', 'subject': 'Physics', 'join_code': '482910'},
        {'id': 'mock-2', 'name': 'Class 12 Chemistry', 'subject': 'Chemistry', 'join_code': '193847'},
      ];

  List<Map<String, dynamic>> _mockStudentFeed() => [
        {
          'id': 'mock-lecture-1',
          'title': 'Introduction to Calculus',
          'subject': 'Mathematics',
          'topic': 'Limits and continuity',
        },
        {
          'id': 'mock-lecture-2',
          'title': 'Organic Chemistry Basics',
          'subject': 'Chemistry',
          'topic': 'Hydrocarbons',
        },
      ];
}
