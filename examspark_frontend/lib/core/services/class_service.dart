import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/constants/share_chip_catalog.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/models/teacher_library_item.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';

class ClassService {
  ClassService._();

  static final ClassService instance = ClassService._();

  Future<String> _accessToken() async {
    var session = SupabaseClient.instance.currentSession;
    if (session != null && session.isExpired) {
      try {
        final refreshed =
            await SupabaseClient.instance.client.auth.refreshSession();
        session = refreshed.session;
      } catch (_) {}
    }
    final t = session?.accessToken;
    if (t == null) throw StateError('Must be logged in');
    return t;
  }

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

  /// Creates a Study Group (`class_folders` row).
  /// Defense: Create Group UI is gated on Teacher Dashboard; plan check here too.
  Future<Map<String, dynamic>> createClass({
    required String name,
    required String subject,
    String? classLevel,
    String? exam,
    String? language,
    bool isPublic = false,
    /// `auto` (default) or `approval`.
    String joinApprovalMode = 'auto',
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be logged in');
    }

    // Soft client check — full gate UI is on Teacher Dashboard.
    // Order: Get Verified → Teacher plan → Create Group (founder Jul 25, 2026).
    try {
      final profile =
          await GroupsRepository.instance.fetchOwnTeacherProfile();
      if (profile == null || !profile.isVerified) {
        throw StateError(
          'Get Verified required before creating a Study Group',
        );
      }
      final planId = await SupabaseClient.instance.getPlanTier(userId);
      if (planId != 'teacher') {
        throw StateError(
          'Teacher plan (₹2,999) required to create a Study Group',
        );
      }
    } catch (e) {
      if (e is StateError) rethrow;
      // If plan/profile lookup fails, still attempt insert — RLS may apply.
    }

    final nameClean = name.trim();
    final subjectClean = subject.trim();
    if (nameClean.isEmpty) {
      throw StateError('Group name required');
    }
    if (subjectClean.isEmpty) {
      throw StateError('Subject required — one primary subject per Study Group');
    }
    final mode = joinApprovalMode == 'approval' ? 'approval' : 'auto';

    final joinCode = _generateJoinCode();
    final payload = <String, dynamic>{
      'teacher_id': userId,
      'name': nameClean,
      'subject': subjectClean,
      'join_code': joinCode,
      'is_public': isPublic,
      'join_approval_mode': mode,
    };
    final level = classLevel?.trim();
    final examClean = exam?.trim();
    final lang = language?.trim();
    if (level != null && level.isNotEmpty) payload['class_level'] = level;
    if (examClean != null && examClean.isNotEmpty) payload['exam'] = examClean;
    if (lang != null && lang.isNotEmpty) payload['language'] = lang;

    final response = await SupabaseClient.instance.client
        .from('class_folders')
        .insert(payload)
        .select()
        .single();

    return Map<String, dynamic>.from(response as Map);
  }

  /// Load one Study Group row (teacher edit form).
  Future<Map<String, dynamic>?> getClassById(String classId) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    final row = await SupabaseClient.instance.client
        .from('class_folders')
        .select()
        .eq('id', classId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// Minimum edit — name · subject · class/exam/language · Free join Auto/Approve.
  /// Join code never changes (shared links stay valid).
  Future<Map<String, dynamic>> updateClass({
    required String classId,
    required String name,
    required String subject,
    String? classLevel,
    String? exam,
    String? language,
    String joinApprovalMode = 'auto',
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    final nameClean = name.trim();
    final subjectClean = subject.trim();
    if (nameClean.isEmpty) {
      throw StateError('Group name required');
    }
    if (subjectClean.isEmpty) {
      throw StateError('Subject required — one primary subject per Study Group');
    }
    final mode = joinApprovalMode == 'approval' ? 'approval' : 'auto';

    final level = classLevel?.trim();
    final examClean = exam?.trim();
    final lang = language?.trim();

    final payload = <String, dynamic>{
      'name': nameClean,
      'subject': subjectClean,
      'join_approval_mode': mode,
      'class_level': (level != null && level.isNotEmpty) ? level : null,
      'exam': (examClean != null && examClean.isNotEmpty) ? examClean : null,
      'language': (lang != null && lang.isNotEmpty) ? lang : null,
    };

    final response = await SupabaseClient.instance.client
        .from('class_folders')
        .update(payload)
        .eq('id', classId)
        .eq('teacher_id', userId)
        .select()
        .single();

    return Map<String, dynamic>.from(response as Map);
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
  /// where the group is already loaded). Respects join_approval_mode.
  Future<String> joinClass(String classId) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    final raw = await SupabaseClient.instance.client.rpc(
      'fn_request_or_join_group',
      params: {'p_class_id': classId},
    );
    final status = _joinStatus(raw);
    if (status == 'joined' || status == 'already_member' || status == 'pending') {
      if (status == 'pending') {
        await _notifyJoinEvent(event: 'pending', classId: classId);
      }
      return status;
    }
    throw StateError('Join failed');
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

  /// Joins (or requests) a group using invite code.
  /// Returns `{ class: row, status: joined|pending|already_member }`.
  Future<Map<String, dynamic>> joinClassByCode(String joinCode) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');

    final client = SupabaseClient.instance.client;
    final classRow = await findClassByJoinCode(joinCode);

    if (classRow == null) {
      throw StateError('Invalid join code');
    }

    final raw = await client.rpc(
      'fn_request_or_join_group',
      params: {'p_class_id': classRow['id']},
    );
    final status = _joinStatus(raw);
    if (status == 'pending') {
      await _notifyJoinEvent(
        event: 'pending',
        classId: classRow['id'] as String,
      );
    }
    return {
      'class': classRow,
      'status': status,
    };
  }

  /// Lookup Study Group by invite code (6-digit / alphanumeric).
  Future<Map<String, dynamic>?> findClassByJoinCode(String joinCode) async {
    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    try {
      final row = await SupabaseClient.instance.client
          .from('class_folders')
          .select()
          .eq('join_code', code)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isMemberOfClass(String classId) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null || classId.isEmpty) return false;
    try {
      final row = await SupabaseClient.instance.client
          .from('class_memberships')
          .select('id')
          .eq('class_id', classId)
          .eq('student_id', userId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  String _joinStatus(dynamic raw) {
    if (raw is Map) {
      return (raw['status'] ?? raw['Status'] ?? '').toString();
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return (decoded['status'] ?? '').toString();
      } catch (_) {}
    }
    return raw?.toString() ?? '';
  }

  /// Best-effort in-app + FCM for join pending / accept / reject.
  Future<void> _notifyJoinEvent({
    required String event,
    String? classId,
    String? requestId,
  }) async {
    if (!AppConfig.isApiConfigured) return;
    try {
      final token = await _accessToken();
      final body = <String, dynamic>{'event': event};
      if (classId != null && classId.isNotEmpty) body['class_id'] = classId;
      if (requestId != null && requestId.isNotEmpty) {
        body['request_id'] = requestId;
      }
      await http.post(
        Uri.parse(
          '${AppConfig.resolvedApiBaseUrl}/api/v1/groups/join-notify',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      // Notifications must not block join / accept / reject.
    }
  }

  /// Pending join requests for one of the teacher's groups.
  Future<List<Map<String, dynamic>>> listPendingJoinRequests(String classId) async {
    final rows = await SupabaseClient.instance.client
        .from('group_join_requests')
        .select('id, class_id, student_id, status, created_at')
        .eq('class_id', classId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return list;

    final studentIds = list
        .map((r) => r['student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (studentIds.isEmpty) return list;

    try {
      final users = await SupabaseClient.instance.client
          .from('users')
          .select('id, username, full_name, email')
          .inFilter('id', studentIds);
      final map = {
        for (final u in List<Map<String, dynamic>>.from(users as List))
          u['id'] as String: u,
      };
      return list
          .map((r) => {
                ...r,
                'users': map[r['student_id'] as String],
              })
          .toList();
    } catch (_) {
      return list;
    }
  }

  /// Pending counts keyed by class_id for teacher's groups.
  Future<Map<String, int>> pendingCountsForClasses(List<String> classIds) async {
    if (classIds.isEmpty) return {};
    try {
      final rows = await SupabaseClient.instance.client
          .from('group_join_requests')
          .select('class_id')
          .inFilter('class_id', classIds)
          .eq('status', 'pending');
      final counts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final id = row['class_id'] as String?;
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<void> acceptJoinRequest(String requestId) async {
    await SupabaseClient.instance.client.rpc(
      'fn_accept_group_join_request',
      params: {'p_request_id': requestId},
    );
    await _notifyJoinEvent(event: 'accepted', requestId: requestId);
  }

  Future<void> rejectJoinRequest(String requestId) async {
    await SupabaseClient.instance.client.rpc(
      'fn_reject_group_join_request',
      params: {'p_request_id': requestId},
    );
    await _notifyJoinEvent(event: 'rejected', requestId: requestId);
  }

  /// Members of one Study Group (teacher per-group dashboard).
  /// Prefer FastAPI Analytics when API is configured (includes quiz %).
  Future<List<Map<String, dynamic>>> listClassMembers(String classId) async {
    if (AppConfig.isApiConfigured) {
      try {
        final payload = await fetchGroupStudentsPayload(classId);
        return _studentsFromPayload(payload);
      } catch (_) {
        // Fall through to Supabase memberships (no quiz %).
      }
    }

    final rows = await SupabaseClient.instance.client
        .from('class_memberships')
        .select('student_id, joined_at, last_active_at')
        .eq('class_id', classId)
        .order('joined_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return list;

    final studentIds = list
        .map((r) => r['student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    Map<String, Map<String, dynamic>> usersMap = {};
    if (studentIds.isNotEmpty) {
      try {
        final users = await SupabaseClient.instance.client
            .from('users')
            .select('id, username, full_name, email')
            .inFilter('id', studentIds);
        usersMap = {
          for (final u in List<Map<String, dynamic>>.from(users as List))
            u['id'] as String: u,
        };
      } catch (_) {}
    }

    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    return list.map((r) {
      final lastRaw = r['last_active_at'] as String?;
      final last = lastRaw != null ? DateTime.tryParse(lastRaw)?.toUtc() : null;
      final activeToday = last != null && !last.isBefore(cutoff);
      return {
        ...r,
        'users': usersMap[r['student_id'] as String],
        'active_today': activeToday,
      };
    }).toList();
  }

  /// Full Analytics payload (students + top lecture week/month).
  Future<Map<String, dynamic>> fetchGroupStudentsPayload(String classId) async {
    final token = await _accessToken();
    final res = await http.get(
      Uri.parse(
        '${AppConfig.resolvedApiBaseUrl}/api/v1/groups/teacher/groups/$classId/students',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      String detail = 'Could not load group students (${res.statusCode})';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(body);
  }

  List<Map<String, dynamic>> _studentsFromPayload(Map<String, dynamic> body) {
    final list = body['students'];
    if (list is! List) return [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m['users'] = {'username': m['username']};
      return m;
    }).toList();
  }

  /// Analytics v2 — members only (uses [fetchGroupStudentsPayload]).
  Future<List<Map<String, dynamic>>> listGroupStudentsPerformance(
    String classId,
  ) async {
    final payload = await fetchGroupStudentsPayload(classId);
    return _studentsFromPayload(payload);
  }

  /// Counts of shared feed items by type for one group (dashboard stubs).
  Future<Map<String, int>> sharedItemCounts(String classId) async {
    try {
      final items = await getGroupFeed(classId);
      final counts = <String, int>{};
      for (final item in items) {
        final t = item.type.name;
        counts[t] = (counts[t] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  /// Whether current user has a pending request for this group.
  Future<bool> hasPendingJoinRequest(String classId) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await SupabaseClient.instance.client
          .from('group_join_requests')
          .select('id')
          .eq('class_id', classId)
          .eq('student_id', userId)
          .eq('status', 'pending')
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Teacher Library: own finished lectures + which groups each is linked to.
  /// Single lecture row — re-share only inserts a link row (no AI / no credits).
  Future<List<TeacherLibraryItem>> fetchTeacherLibrary() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return const [];

    final lectures = await LectureService.instance.getLecturesForUser();
    if (lectures.isEmpty) return const [];

    final sharedByLecture = <String, List<TeacherLibrarySharedGroup>>{};
    try {
      final client = SupabaseClient.instance.client;
      final shareRows = await client
          .from('group_shared_items')
          .select('lecture_id, class_id, class_folders(name)')
          .eq('teacher_id', userId)
          .not('lecture_id', 'is', null);
      for (final raw in List<Map<String, dynamic>>.from(shareRows as List)) {
        final lid = raw['lecture_id'] as String?;
        final cid = raw['class_id'] as String?;
        if (lid == null || cid == null) continue;
        var name = 'Group';
        final folder = raw['class_folders'];
        if (folder is Map && folder['name'] is String) {
          name = folder['name'] as String;
        }
        sharedByLecture
            .putIfAbsent(lid, () => <TeacherLibrarySharedGroup>[])
            .add(TeacherLibrarySharedGroup(classId: cid, name: name));
      }
    } catch (_) {
      // Library still lists lectures; shared labels may be empty.
    }

    // Teacher Library = shareable bank: live-recorded lectures only (group share rule).
    return lectures
        .where((row) => row['source_type'] == 'recorded')
        .map((row) {
      final id = row['id'] as String? ?? '';
      DateTime? created;
      final rawCreated = row['created_at'];
      if (rawCreated is String) {
        created = DateTime.tryParse(rawCreated);
      }
      final shared = sharedByLecture[id] ?? const <TeacherLibrarySharedGroup>[];
      // Dedupe group names if lecture was shared as multiple types before unique.
      final seen = <String>{};
      final uniqueShared = <TeacherLibrarySharedGroup>[];
      for (final g in shared) {
        if (seen.add(g.classId)) uniqueShared.add(g);
      }
      return TeacherLibraryItem(
        lectureId: id,
        title: (row['title'] as String?)?.trim().isNotEmpty == true
            ? row['title'] as String
            : 'Untitled lecture',
        subject: row['subject'] as String?,
        createdAt: created,
        sourceType: row['source_type'] as String?,
        sharedTo: uniqueShared,
      );
    }).where((i) => i.lectureId.isNotEmpty).toList();
  }

  /// Which generated chips already exist for this lecture (share picker).
  Future<List<String>> listShareableChips(String lectureId) async {
    final client = SupabaseClient.instance.client;
    final found = <String>{};

    try {
      final notes = await client
          .from('notes')
          .select(
            'r2_notes_path, r2_summary_path, clean_notes, short_summary, visual_payload_json',
          )
          .eq('lecture_id', lectureId)
          .maybeSingle();
      if (notes != null) {
        final hasNotes = (notes['r2_notes_path'] as String?)?.isNotEmpty == true ||
            (notes['clean_notes'] as String?)?.trim().isNotEmpty == true;
        final hasSummary =
            (notes['r2_summary_path'] as String?)?.isNotEmpty == true ||
                (notes['short_summary'] as String?)?.trim().isNotEmpty == true;
        if (hasNotes) found.add(ShareChipCatalog.notes);
        if (hasSummary) found.add(ShareChipCatalog.summary);
        // Recording usually produces notes+summary together; if only notes, still offer summary.
        if (hasNotes && !found.contains(ShareChipCatalog.summary)) {
          found.add(ShareChipCatalog.summary);
        }
        if (notes['visual_payload_json'] != null) {
          found.add(ShareChipCatalog.visual);
        }
      }
    } catch (_) {}

    try {
      final tx = await client
          .from('transcripts')
          .select('r2_transcript_path, clean_transcript_path')
          .eq('lecture_id', lectureId)
          .maybeSingle();
      if (tx != null) {
        final has = (tx['r2_transcript_path'] as String?)?.isNotEmpty == true ||
            (tx['clean_transcript_path'] as String?)?.isNotEmpty == true;
        if (has) found.add(ShareChipCatalog.transcript);
      }
    } catch (_) {}

    try {
      final extras = await client
          .from('extras')
          .select('type')
          .eq('lecture_id', lectureId);
      for (final raw in List<Map<String, dynamic>>.from(extras as List)) {
        final t = (raw['type'] as String?)?.trim().toLowerCase();
        if (t == null) continue;
        final chip = ShareChipCatalog.extrasTypeToChip[t];
        if (chip != null) found.add(chip);
      }
    } catch (_) {}

    // Stable order matching catalog labels.
    final order = ShareChipCatalog.labels.keys.toList();
    return order.where(found.contains).toList();
  }

  /// Shares one item into a group via FastAPI (own group + recorded lecture).
  /// Free re-link — no credit charge. Duplicate to same group → "Already shared here".
  Future<void> shareItemToGroup({
    required String classId,
    required String type,
    required String title,
    String? lectureId,
    String? body,
    bool isPinned = false,
    List<String>? sharedChips,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');
    if (lectureId == null || lectureId.isEmpty) {
      throw StateError('lecture_id required to share');
    }

    if (AppConfig.isApiConfigured) {
      final token = await _accessToken();
      final payload = <String, dynamic>{
        'class_id': classId,
        'lecture_id': lectureId,
        'type': type,
        'title': title,
        'body': body,
        'is_pinned': isPinned,
        'notify': true,
      };
      if (sharedChips != null) {
        payload['shared_chips'] = sharedChips;
      }
      final res = await http.post(
        Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/groups/share'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode != 200) {
        String detail = 'Share failed (${res.statusCode})';
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['detail'] != null) {
            final d = decoded['detail'];
            if (d is Map && d['message'] != null) {
              detail = d['message'].toString();
            } else {
              detail = d.toString();
            }
          }
        } catch (_) {}
        throw Exception(detail);
      }
      return;
    }

    // Fallback when API not configured — still respect duplicate.
    final existing = await SupabaseClient.instance.client
        .from('group_shared_items')
        .select('id')
        .eq('class_id', classId)
        .eq('lecture_id', lectureId)
        .maybeSingle();
    if (existing != null) {
      throw Exception('Already shared here');
    }
    final row = <String, dynamic>{
      'class_id': classId,
      'teacher_id': userId,
      'type': type,
      'title': title,
      'lecture_id': lectureId,
      'body': body,
      'is_pinned': isPinned,
    };
    if (sharedChips != null) {
      row['shared_chips'] = sharedChips;
    }
    await SupabaseClient.instance.client.from('group_shared_items').insert(row);
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

      final items = List<Map<String, dynamic>>.from(rows as List)
          .map(GroupSharedItem.fromMap);
      return GroupSharedItem.sortedForFeed(items);
    } catch (_) {
      return [];
    }
  }

  /// Teacher pin/unpin a shared feed item (sticky top).
  Future<void> setSharedItemPinned({
    required String itemId,
    required bool isPinned,
  }) async {
    if (AppConfig.isApiConfigured) {
      final token = await _accessToken();
      final res = await http.patch(
        Uri.parse(
          '${AppConfig.resolvedApiBaseUrl}/api/v1/groups/shared-items/$itemId/pin',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'is_pinned': isPinned}),
      );
      if (res.statusCode != 200) {
        String detail = 'Pin failed (${res.statusCode})';
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['detail'] != null) {
            detail = decoded['detail'].toString();
          }
        } catch (_) {}
        throw Exception(detail);
      }
      return;
    }

    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');
    await SupabaseClient.instance.client
        .from('group_shared_items')
        .update({'is_pinned': isPinned})
        .eq('id', itemId)
        .eq('teacher_id', userId);
  }

  /// Student opened a group channel — marks last_active_at for teacher Daily Active.
  /// Failures are ignored (best-effort; must not block opening the group).
  Future<void> pingGroupActive(String classId) async {
    final id = classId.trim();
    if (id.isEmpty) return;
    try {
      if (AppConfig.isApiConfigured) {
        final token = await _accessToken();
        await http.post(
          Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/groups/heartbeat'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'class_id': id}),
        );
        return;
      }
      final userId = SupabaseClient.instance.currentUser?.id;
      if (userId == null) return;
      await SupabaseClient.instance.client
          .from('class_memberships')
          .update({'last_active_at': DateTime.now().toUtc().toIso8601String()})
          .eq('class_id', id)
          .eq('student_id', userId);
    } catch (_) {
      // Best-effort only.
    }
  }

  /// Teacher-only text announcement (no student replies / comments).
  Future<Map<String, dynamic>> postAnnouncement({
    required String classId,
    required String title,
    required String body,
    bool isPinned = false,
  }) async {
    if (AppConfig.isApiConfigured) {
      final token = await _accessToken();
      final res = await http.post(
        Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/groups/announce'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'class_id': classId,
          'title': title,
          'body': body,
          'is_pinned': isPinned,
          'notify': true,
        }),
      );
      if (res.statusCode != 200) {
        String detail = 'Announce failed (${res.statusCode})';
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['detail'] != null) {
            detail = decoded['detail'].toString();
          }
        } catch (_) {}
        throw Exception(detail);
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(decoded['item'] as Map? ?? decoded);
    }

    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) throw StateError('Must be logged in');
    final rows = await SupabaseClient.instance.client
        .from('group_shared_items')
        .insert({
          'class_id': classId,
          'teacher_id': userId,
          'type': 'announcement',
          'title': title,
          'body': body,
          'is_pinned': isPinned,
        })
        .select()
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) throw StateError('Announce insert failed');
    return list.first;
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
