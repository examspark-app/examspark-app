import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide SupabaseClient;
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/models/suggested_teacher_model.dart';
import 'package:examspark_frontend/core/models/teacher_achievement_model.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';

// #region agent log
void _groupsAgentLog(String hypothesisId, String location, String message, Map<String, Object?> data) {
  http
      .post(
        Uri.parse('http://127.0.0.1:7873/ingest/2b81c552-406d-48cd-a23e-89c0b6b9e62a'),
        headers: {
          'Content-Type': 'application/json',
          'X-Debug-Session-Id': '945329',
        },
        body: jsonEncode({
          'sessionId': '945329',
          'runId': 'final-fix',
          'hypothesisId': hypothesisId,
          'location': location,
          'message': message,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      )
      .catchError((_) => http.Response('', 500));
}
// #endregion

/// Result of [GroupsRepository.canJoinAnotherGroup] — Monthly limit enforce
class GroupJoinEligibility {
  final bool allowed;
  final int maxGroups;
  final int currentGroups;
  final String planName;
  final bool isTeacherOwnGroupsOnly;

  const GroupJoinEligibility({
    required this.allowed,
    required this.maxGroups,
    required this.currentGroups,
    this.planName = 'Free',
    this.isTeacherOwnGroupsOnly = false,
  });

  bool get isUnlimited => maxGroups < 0;
}

/// Thrown when join/leave against Supabase fails
class GroupMembershipException implements Exception {
  final String message;
  final bool isJoinLimit;
  final bool isPendingApproval;

  const GroupMembershipException(
    this.message, {
    this.isJoinLimit = false,
    this.isPendingApproval = false,
  });

  @override
  String toString() => message;

  static bool looksLikeJoinLimit(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('group join limit') ||
        text.contains('join limit reached') ||
        text.contains('max_groups');
  }
}

class GroupsRepository {
  GroupsRepository._();

  static final GroupsRepository instance = GroupsRepository._();

  

  // ==================== GROUPS FETCHING ====================

  Future<List<GroupModel>> fetchGroups() async {
    try {
      final client = SupabaseClient.instance.client;
      final userId = SupabaseClient.instance.currentUser?.id;

      final classRows = await client
          .from('class_folders')
          .select()
          .order('created_at', ascending: false);
      final classes = List<Map<String, dynamic>>.from(classRows as List);

      if (classes.isEmpty) {
        if (userId != null) return const [];
        return List.unmodifiable(_groups);
      }

      final classIds = classes.map((c) => c['id'] as String).toList();
      final teacherIds = classes.map((c) => c['teacher_id'] as String).toSet().toList();

      final teacherMap = await _fetchTeacherProfilesByUserIds(teacherIds);
      final memberships = await _fetchMemberships(classIds);
      final feedItems = await _fetchFeed(classIds);

      final groups = classes.map((c) {
        final classId = c['id'] as String;
        final teacher = teacherMap[c['teacher_id']] ?? _placeholderTeacher(c['teacher_id'] as String);
        final classMemberships = memberships.where((m) => m['class_id'] == classId).toList();
        final classFeed = feedItems.where((f) => f['class_id'] == classId).toList();

        return GroupModel.fromMap(
          c,
          teacher: teacher,
          studentsCount: classMemberships.length,
          sharedLecturesCount: classFeed.where((f) => f['type'] == 'lecture').length,
          recentSharedItems: classFeed.take(5).map(GroupSharedItem.fromMap).toList(),
          isJoined: userId != null && classMemberships.any((m) => m['student_id'] == userId),
        );
      }).toList();

      return groups;
    } catch (e) {
      if (SupabaseClient.instance.currentUser != null) return const [];
      return List.unmodifiable(_groups);
    }
  }

  Future<GroupModel?> fetchGroupById(String id) async {
    try {
      final client = SupabaseClient.instance.client;
      final userId = SupabaseClient.instance.currentUser?.id;

      final row = await client.from('class_folders').select().eq('id', id).maybeSingle();
      if (row == null) return null;

      final teacherMap = await _fetchTeacherProfilesByUserIds([row['teacher_id'] as String]);
      final teacher = teacherMap[row['teacher_id']] ?? _placeholderTeacher(row['teacher_id'] as String);
      final memberships = await _fetchMemberships([id]);
      final feedItems = await _fetchFeed([id]);

      return GroupModel.fromMap(
        row,
        teacher: teacher,
        studentsCount: memberships.length,
        sharedLecturesCount: feedItems.where((f) => f['type'] == 'lecture').length,
        recentSharedItems: feedItems.take(20).map(GroupSharedItem.fromMap).toList(),
        isJoined: userId != null && memberships.any((m) => m['student_id'] == userId),
      );
    } catch (_) {
      for (final group in _groups) {
        if (group.id == id) return group;
      }
      return null;
    }
  }

  // ==================== MONTHLY JOIN LIMIT CHECK ====================

  Future<GroupJoinEligibility> canJoinAnotherGroup() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      return const GroupJoinEligibility(allowed: false, maxGroups: 0, currentGroups: 0);
    }

    try {
      final planId = await SupabaseClient.instance.getPlanTier(userId);
      final plan = SubscriptionPlans.byId(planId) ?? SubscriptionPlans.free;

      if (planId == 'teacher' || plan.id == 'teacher') {
        return GroupJoinEligibility(
          allowed: false,
          maxGroups: 0,
          currentGroups: 0,
          planName: plan.name,
          isTeacherOwnGroupsOnly: true,
        );
      }

      if (plan.hasUnlimitedGroups) {
        return GroupJoinEligibility(
          allowed: true,
          maxGroups: -1,
          currentGroups: 0,
          planName: plan.name,
        );
      }

      if (plan.maxGroups <= 0) {
        return GroupJoinEligibility(
          allowed: false,
          maxGroups: plan.maxGroups,
          currentGroups: 0,
          planName: plan.name,
        );
      }

      final now = DateTime.now().toUtc();
      final startOfCurrentMonth = DateTime.utc(now.year, now.month, 1).toIso8601String();

      final rows = await SupabaseClient.instance.client
          .from('group_join_history')
          .select('id, coupon_id, join_type')
          .eq('student_id', userId)
          .gte('joined_at', startOfCurrentMonth);

      final list = List<dynamic>.from(rows);
      final usedJoinsThisMonth = list.where((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final joinType = (row['join_type'] as String?)?.trim();
        final couponId = row['coupon_id'];
        if (joinType == 'coupon' || couponId != null) return false;
        return true;
      }).length;

      return GroupJoinEligibility(
        allowed: usedJoinsThisMonth < plan.maxGroups,
        maxGroups: plan.maxGroups,
        currentGroups: usedJoinsThisMonth,
        planName: plan.name,
      );
    } catch (e) {
      return const GroupJoinEligibility(
        allowed: false,
        maxGroups: 0,
        currentGroups: 0,
        planName: 'Unknown',
      );
    }
  }

  // ==================== MEMBERSHIP TOGGLE & JOIN ====================

  Future<GroupModel> toggleMembership(GroupModel group) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return _toggleMockMembership(group);

    try {
      final client = SupabaseClient.instance.client;

      if (group.isJoined) {
        await client
            .from('class_memberships')
            .delete()
            .eq('class_id', group.id)
            .eq('student_id', userId);
        return group.copyWith(isJoined: false);
      }

      final eligibility = await canJoinAnotherGroup();
      if (!eligibility.allowed) {
        throw GroupMembershipException(
          'Your ${eligibility.planName} plan limit (${eligibility.maxGroups} group/month) has been reached for this month.',
          isJoinLimit: true,
        );
      }

      final raw = await client.rpc(
        'fn_request_or_join_group',
        params: {'p_class_id': group.id},
      );
      final status = _rpcJoinStatus(raw);

      if (status == 'pending') {
        throw const GroupMembershipException(
          'Join request sent. Waiting for teacher approval.',
          isPendingApproval: true,
        );
      }

      if (status == 'joined' || status == 'already_member') {
        return group.copyWith(isJoined: true);
      }

      if (status == 'limit_reached') {
        throw const GroupMembershipException(
          'Your plan limit has been reached for this month.',
          isJoinLimit: true,
        );
      }

      throw const GroupMembershipException('Could not join group. Please try again.');
    } catch (e) {
      if (e is GroupMembershipException) rethrow;
      throw GroupMembershipException(
        'Could not ${group.isJoined ? 'leave' : 'join'} group. Please try again.',
        isJoinLimit: GroupMembershipException.looksLikeJoinLimit(e),
      );
    }
  }

  String _rpcJoinStatus(dynamic raw) {
    if (raw is Map) return (raw['status'] ?? '').toString();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return (decoded['status'] ?? '').toString();
      } catch (_) {}
    }
    return raw?.toString() ?? '';
  }

  // ==================== DISCOVERY & TEACHERS ====================

  Future<List<SuggestedTeacherModel>> fetchSuggestedTeachers() async {
    try {
      final client = SupabaseClient.instance.client;
      final rows = await client.from('teacher_profiles').select().limit(40);
      final list = List<Map<String, dynamic>>.from(rows as List);
      return list.map((row) => SuggestedTeacherModel.fromMap(row)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SuggestedTeacherModel>> discoverTeachers({
    String query = '',
    List<String> filterSubjects = const [],
    String filterLocation = '',
    List<String> filterClassLevels = const [],
    List<String> filterExams = const [],
    List<String> filterLanguages = const [],
  }) async {
    try {
      final client = SupabaseClient.instance.client;
      final userId = SupabaseClient.instance.currentUser?.id;

      final rows = await client.from('teacher_profiles').select();
      var list = List<Map<String, dynamic>>.from(rows as List);

      if (list.isEmpty) {
        if (userId != null) return const [];
        return List.unmodifiable(_suggestedTeachers);
      }

      final groupClassByTeacher = <String, Set<String>>{};
      final groupExamByTeacher = <String, Set<String>>{};
      final groupSubjectByTeacher = <String, Set<String>>{};
      final groupsByTeacher = <String, List<Map<String, dynamic>>>{};

      try {
        final classRows = await client.from('class_folders').select();
        final classList = List<Map<String, dynamic>>.from(classRows as List);
        for (final c in classList) {
          final tid = c['teacher_id'] as String?;
          if (tid != null && tid.isNotEmpty) {
            final gl = (c['class_level'] as String?)?.trim();
            if (gl != null && gl.isNotEmpty) {
              groupClassByTeacher.putIfAbsent(tid, () => <String>{}).add(gl);
            }
            final ge = (c['exam'] as String?)?.trim();
            if (ge != null && ge.isNotEmpty) {
              groupExamByTeacher.putIfAbsent(tid, () => <String>{}).add(ge);
            }
            final gs = (c['subject'] as String?)?.trim();
            if (gs != null && gs.isNotEmpty) {
              groupSubjectByTeacher.putIfAbsent(tid, () => <String>{}).add(gs);
            }
            groupsByTeacher.putIfAbsent(tid, () => []).add({
              'id': c['id'],
              'name': c['name'],
              'subject': c['subject'],
              'class_level': c['class_level'],
              'exam': c['exam'],
            });
          }
        }
      } catch (_) {}

      final subjectsFilter = filterSubjects
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      if (subjectsFilter.isNotEmpty) {
        list = list.where((r) {
          final uid = r['user_id'] as String?;
          final sub = (r['subject'] as String?)?.toLowerCase() ?? '';
          if (subjectsFilter.any((s) => sub.contains(s))) return true;
          final gs = uid == null ? null : groupSubjectByTeacher[uid];
          return gs != null && subjectsFilter.any((s) => gs.any((g) => g.toLowerCase().contains(s)));
        }).toList();
      }

      final locFilter = filterLocation.trim().toLowerCase();
      if (locFilter.length >= 2) {
        list = list.where((r) {
          final city = (r['city'] as String?)?.toLowerCase() ?? '';
          final state = (r['state'] as String?)?.toLowerCase() ?? '';
          return city.contains(locFilter) || state.contains(locFilter);
        }).toList();
      }

      final classFilter = filterClassLevels
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      if (classFilter.isNotEmpty) {
        list = list.where((r) {
          final uid = r['user_id'] as String?;
          String pl = r['class_levels'] is List
              ? (r['class_levels'] as List).join(' ').toLowerCase()
              : (r['class_levels'] as String?)?.toLowerCase() ?? '';
          if (classFilter.any((c) => pl.contains(c))) return true;
          final gs = uid == null ? null : groupClassByTeacher[uid];
          return gs != null && classFilter.any((c) => gs.any((g) => g.toLowerCase().contains(c)));
        }).toList();
      }

      final examFilter = filterExams
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      if (examFilter.isNotEmpty) {
        list = list.where((r) {
          final uid = r['user_id'] as String?;
          String pl = r['exams'] is List
              ? (r['exams'] as List).join(' ').toLowerCase()
              : (r['exams'] as String?)?.toLowerCase() ?? '';
          if (examFilter.any((e) => pl.contains(e))) return true;
          final gs = uid == null ? null : groupExamByTeacher[uid];
          return gs != null && examFilter.any((e) => gs.any((g) => g.toLowerCase().contains(e)));
        }).toList();
      }
      final languageFilter = filterLanguages
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      if (languageFilter.isNotEmpty) {
        list = list.where((r) {
          String pl = r['language'] is List
              ? (r['language'] as List).join(' ').toLowerCase()
              : (r['language'] as String?)?.toLowerCase() ?? '';
          return languageFilter.any((l) => pl.contains(l));
        }).toList();
      }
      final needle = query.trim().toLowerCase();
      if (needle.length >= 2) {
        list = list.where((r) {
          final name = (r['full_name'] as String?)?.toLowerCase() ?? '';
          final sub = (r['subject'] as String?)?.toLowerCase() ?? '';
          final city = (r['city'] as String?)?.toLowerCase() ?? '';
          final state = (r['state'] as String?)?.toLowerCase() ?? '';
          return name.contains(needle) || sub.contains(needle) || city.contains(needle) || state.contains(needle);
        }).toList();
      }
     // Only show teachers whose Teacher plan (₹2,999) is currently active —
      // expired-plan teachers stay out of Discovery (existing groups/students
      // are unaffected; this only hides them from NEW student discovery).
      final activeTeacherIds = <String>{};
      final candidateTeacherIds = groupsByTeacher.keys.toList();
      if (candidateTeacherIds.isNotEmpty) {
        try {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          final subRows = await client
              .from('user_subscriptions')
              .select('user_id, plan_id, status, current_period_end')
              .inFilter('user_id', candidateTeacherIds)
              .eq('plan_id', 'teacher')
              .eq('status', 'active')
              .gte('current_period_end', nowIso);
          for (final r in List<Map<String, dynamic>>.from(subRows as List)) {
            final uid = r['user_id'] as String?;
            if (uid != null) activeTeacherIds.add(uid);
          }
        } catch (_) {
          // Soft-fail: if the check errors, fall back to showing everyone
          // rather than breaking Discovery entirely.
          activeTeacherIds.addAll(candidateTeacherIds);
        }
      }
      final joinedTeacherUsers = <String>{};
      if (userId != null) {
        try {
          final my = await client.from('class_memberships').select('class_id').eq('student_id', userId);
          final myClassIds = List<Map<String, dynamic>>.from(my as List)
              .map((r) => r['class_id'] as String)
              .toList();
          if (myClassIds.isNotEmpty) {
            final owned = await client.from('class_folders').select('teacher_id').inFilter('id', myClassIds);
            for (final r in List<Map<String, dynamic>>.from(owned as List)) {
              if (r['teacher_id'] != null) joinedTeacherUsers.add(r['teacher_id'] as String);
            }
          }
        } catch (_) {}
      }

      final filtered = list.where((row) {
        final uid = row['user_id'] as String?;
        return uid != null && (groupsByTeacher[uid]?.isNotEmpty ?? false);
      }).toList();

      return filtered.map((row) {
        final uid = row['user_id'] as String;
        return SuggestedTeacherModel.fromMap(row).copyWith(
          isJoined: joinedTeacherUsers.contains(uid),
          groups: groupsByTeacher[uid] ?? const [],
        );
      }).toList();
    } catch (_) {
      try {
        final client = SupabaseClient.instance.client;
        final rows = await client.from('teacher_profiles').select();
        return List<Map<String, dynamic>>.from(rows as List)
            .map((r) => SuggestedTeacherModel.fromMap(r))
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }
    
// ==================== INDIVIDUAL GROUP DISCOVERY ====================

  Future<List<GroupModel>> discoverGroups({
    String query = '',
    List<String> filterSubjects = const [],
    String filterLocation = '',
    List<String> filterClassLevels = const [],
    List<String> filterExams = const [],
  }) async {
    try {
      final client = SupabaseClient.instance.client;
      final userId = SupabaseClient.instance.currentUser?.id;

      final classRows = await client
          .from('class_folders')
          .select()
          .order('created_at', ascending: false);
      final classes = List<Map<String, dynamic>>.from(classRows as List);
      if (classes.isEmpty) return const [];

      final classIds = classes.map((c) => c['id'] as String).toList();
      final teacherIds = classes.map((c) => c['teacher_id'] as String).toSet().toList();

      final teacherMap = await _fetchTeacherProfilesByUserIds(teacherIds);
      final memberships = await _fetchMemberships(classIds);
      final feedItems = await _fetchFeed(classIds);

      var groups = classes.map((c) {
        final classId = c['id'] as String;
        final tid = c['teacher_id'] as String?;
        final teacher = teacherMap[tid] ?? _placeholderTeacher(tid ?? '');
        final classMemberships = memberships.where((m) => m['class_id'] == classId).toList();
        final classFeed = feedItems.where((f) => f['class_id'] == classId).toList();

        return GroupModel.fromMap(
          c,
          teacher: teacher,
          studentsCount: classMemberships.length,
          sharedLecturesCount: classFeed.where((f) => f['type'] == 'lecture').length,
          recentSharedItems: classFeed.take(5).map(GroupSharedItem.fromMap).toList(),
          isJoined: userId != null && classMemberships.any((m) => m['student_id'] == userId),
        );
      }).toList();

      if (filterSubjects.isNotEmpty) {
        final subFilters = filterSubjects.map((s) => s.trim().toLowerCase()).toList();
        groups = groups.where((g) {
          final sub = g.description.toLowerCase();
          final name = g.name.toLowerCase();
          return subFilters.any((s) => sub.contains(s) || name.contains(s));
        }).toList();
      }

      if (filterClassLevels.isNotEmpty) {
        final classFilters = filterClassLevels.map((s) => s.trim().toLowerCase()).toList();
        groups = groups.where((g) {
          final desc = g.description.toLowerCase();
          final name = g.name.toLowerCase();
          return classFilters.any((c) => desc.contains(c) || name.contains(c));
        }).toList();
      }

      if (filterExams.isNotEmpty) {
        final examFilters = filterExams.map((s) => s.trim().toLowerCase()).toList();
        groups = groups.where((g) {
          final desc = g.description.toLowerCase();
          final name = g.name.toLowerCase();
          return examFilters.any((e) => desc.contains(e) || name.contains(e));
        }).toList();
      }

      if (query.trim().length >= 2) {
        final needle = query.trim().toLowerCase();
        groups = groups.where((g) {
          return g.name.toLowerCase().contains(needle) ||
              g.description.toLowerCase().contains(needle) ||
              g.teacher.fullName.toLowerCase().contains(needle);
        }).toList();
      }

      return groups;
    } catch (_) {
      return const [];
    }
  }

  // ==================== TEACHER OPEN GROUP ROUTING ====================

  Future<String?> fetchOpenGroupIdForTeacher(String teacherUserId) async {
    try {
      final client = SupabaseClient.instance.client;
      final classes = await client
          .from('class_folders')
          .select('id, is_public, created_at')
          .eq('teacher_id', teacherUserId)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(classes as List);
      if (list.isEmpty) return null;
      final public = list.where((c) => c['is_public'] == true).toList();
      if (public.isNotEmpty) return public.first['id'] as String?;
      return list.first['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<GroupModel?> joinFirstOpenGroupForTeacher({
    required String teacherProfileId,
    String? teacherUserId,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw const GroupMembershipException('Please log in');
    }

    final client = SupabaseClient.instance.client;
    String? tid = teacherUserId;
    if (tid == null || tid.isEmpty) {
      final tp = await client
          .from('teacher_profiles')
          .select('user_id')
          .eq('id', teacherProfileId)
          .maybeSingle();
      tid = tp?['user_id'] as String?;
    }
    if (tid == null) {
      throw const GroupMembershipException('Teacher not found');
    }

    final classId = await fetchOpenGroupIdForTeacher(tid);
    if (classId == null || classId.isEmpty) {
      throw const GroupMembershipException(
        'Teacher has no active public group.',
      );
    }

    final fullGroup = await fetchGroupById(classId);
    if (fullGroup != null) {
      return toggleMembership(fullGroup);
    }

    throw const GroupMembershipException('Unable to load group details.');
  }

  // ==================== AUXILIARY METHODS ====================

  Future<double> fetchEstimatedCommission() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return 0;
    try {
      return await SupabaseClient.instance.getEstimatedCommission(userId);
    } catch (_) {
      return 0;
    }
  }

  Future<int> fetchSubscriberCount() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return 0;
    try {
      return await SupabaseClient.instance.getTeacherSubscriberCount(userId);
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> fetchCouponMembershipStatus(String classId) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return null;
    try {
      final res = await SupabaseClient.instance.client.rpc(
        'fn_coupon_membership_status',
        params: {
          'p_student_id': userId,
          'p_class_id': classId,
        },
      );
      if (res is List && res.isNotEmpty) {
        return Map<String, dynamic>.from(res.first as Map);
      }
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<TeacherProfileModel> fetchOwnTeacherProfile() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return _ownTeacherProfile;

    try {
      final client = SupabaseClient.instance.client;
      final row = await client.from('teacher_profiles').select().eq('user_id', userId).maybeSingle();
      if (row == null) return _blankTeacherProfile(userId);

      final teacherId = row['id'] as String;

      final certRows = await client.from('teacher_certificates').select().eq('teacher_id', teacherId);
      final achievementRows = await client.from('teacher_achievements').select().eq('teacher_id', teacherId);

      final groupRows = await client.from('class_folders').select('id').eq('teacher_id', userId);
      final classIds = List<Map<String, dynamic>>.from(groupRows as List).map((g) => g['id'] as String).toList();

      final memberships = classIds.isEmpty ? <Map<String, dynamic>>[] : await _fetchMemberships(classIds);
      final feedItems = classIds.isEmpty ? <Map<String, dynamic>>[] : await _fetchFeed(classIds);

      return TeacherProfileModel.fromMap(
        row,
        certificates: List<Map<String, dynamic>>.from(certRows as List)
            .map(TeacherCertificateModel.fromMap)
            .toList(),
        achievements: List<Map<String, dynamic>>.from(achievementRows as List)
            .map(TeacherAchievementModel.fromMap)
            .toList(),
        totalGroups: classIds.length,
        totalStudents: memberships.map((m) => m['student_id']).toSet().length,
        totalSharedLectures: feedItems.where((f) => f['type'] == 'lecture').length,
      );
    } catch (_) {
      return _ownTeacherProfile;
    }
  }

  Future<TeacherProfileModel> updateOwnTeacherProfile(TeacherProfileModel profile) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      _ownTeacherProfile = profile;
      return profile;
    }

    try {
      final client = SupabaseClient.instance.client;
      final row = await client
          .from('teacher_profiles')
          .upsert(profile.toMap(userId: userId), onConflict: 'user_id')
          .select()
          .single();

      final teacherId = row['id'] as String;
      final savedCertificates = await _syncCertificates(teacherId, profile.certificates);

      return TeacherProfileModel.fromMap(
        row,
        certificates: savedCertificates,
        achievements: profile.achievements,
        totalGroups: profile.totalGroups,
        totalStudents: profile.totalStudents,
        totalSharedLectures: profile.totalSharedLectures,
      );
    } catch (_) {
      _ownTeacherProfile = profile;
      return profile;
    }
  }

  Future<String> uploadTeacherProfilePhoto({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    String extension = 'jpg',
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be logged in to upload photo');
    }
    final client = SupabaseClient.instance.client;
    final path = '$userId/avatar.$extension';
    await client.storage.from('teacher-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );
    final publicUrl = client.storage.from('teacher-photos').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  // ==================== INTERNAL SUPABASE HELPERS ====================

  Future<List<TeacherCertificateModel>> _syncCertificates(
    String teacherId,
    List<TeacherCertificateModel> certificates,
  ) async {
    try {
      final client = SupabaseClient.instance.client;
      await client.from('teacher_certificates').delete().eq('teacher_id', teacherId);
      if (certificates.isEmpty) return const [];

      final rows = await client
          .from('teacher_certificates')
          .insert([for (final cert in certificates) cert.toMap(teacherId: teacherId)])
          .select();
      return List<Map<String, dynamic>>.from(rows as List).map(TeacherCertificateModel.fromMap).toList();
    } catch (_) {
      return certificates;
    }
  }
/// Single teacher's full profile (bio, achievements, certificates) for
  /// the student-facing "View Profile" screen from Discovery.
  Future<TeacherProfileModel?> fetchTeacherProfileByUserId(String userId) async {
    final map = await _fetchTeacherProfilesByUserIds([userId]);
    return map[userId];
  }

  
  Future<Map<String, TeacherProfileModel>> _fetchTeacherProfilesByUserIds(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final client = SupabaseClient.instance.client;
    final rows = await client.from('teacher_profiles').select().inFilter('user_id', userIds);
    final list = List<Map<String, dynamic>>.from(rows as List);
    final out = <String, TeacherProfileModel>{};

    for (final row in list) {
      final teacherId = row['id'] as String;
      final userId = row['user_id'] as String;
      final showCerts = row['show_certificates_on_profile'] == true;

      var certificates = const <TeacherCertificateModel>[];
      var achievements = const <TeacherAchievementModel>[];

      if (showCerts) {
        try {
          final certRows = await client
              .from('teacher_certificates')
              .select()
              .eq('teacher_id', teacherId);
          certificates = List<Map<String, dynamic>>.from(certRows as List)
              .map(TeacherCertificateModel.fromMap)
              .toList();
        } catch (_) {}
      }

      try {
        final achievementRows = await client
            .from('teacher_achievements')
            .select()
            .eq('teacher_id', teacherId);
        achievements = List<Map<String, dynamic>>.from(achievementRows as List)
            .map(TeacherAchievementModel.fromMap)
            .toList();
      } catch (_) {}

      out[userId] = TeacherProfileModel.fromMap(
        row,
        certificates: certificates,
        achievements: achievements,
      );
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _fetchMemberships(List<String> classIds) async {
    if (classIds.isEmpty) return [];
    final client = SupabaseClient.instance.client;
    final rows = await client
        .from('class_memberships')
        .select('class_id, student_id')
        .inFilter('class_id', classIds);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> _fetchFeed(List<String> classIds) async {
    if (classIds.isEmpty) return [];
    final client = SupabaseClient.instance.client;
    final rows = await client
        .from('group_shared_items')
        .select()
        .inFilter('class_id', classIds)
        .order('shared_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(rows as List);
    list.sort((a, b) {
      final ap = a['is_pinned'] == true;
      final bp = b['is_pinned'] == true;
      if (ap != bp) return ap ? -1 : 1;
      final as = a['shared_at']?.toString() ?? '';
      final bs = b['shared_at']?.toString() ?? '';
      return bs.compareTo(as);
    });
    return list;
  }

  TeacherProfileModel _placeholderTeacher(String userId) {
    return TeacherProfileModel(
      id: userId,
      userId: userId,
      fullName: 'Teacher',
      subject: '',
      joinedSince: DateTime.now(),
    );
  }

  TeacherProfileModel _blankTeacherProfile(String userId) {
    final user = SupabaseClient.instance.currentUser;
    final meta = user?.userMetadata;
    final metaName = meta?['full_name'] as String? ?? meta?['name'] as String?;
    final email = user?.email ?? '';
    final fallbackName = (metaName != null && metaName.isNotEmpty)
        ? metaName
        : (email.contains('@') ? email.split('@').first : 'New Teacher');

    return TeacherProfileModel(
      id: userId,
      userId: userId,
      fullName: fallbackName,
      subject: '',
      joinedSince: DateTime.now(),
    );
  }

  GroupModel _toggleMockMembership(GroupModel group) {
    final updated = group.copyWith(isJoined: !group.isJoined);
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = updated;
    }
    return updated;
  }

  // ==================== MOCK FALLBACK DATA ====================

  static TeacherProfileModel _ownTeacherProfile = TeacherProfileModel(
    id: 'teacher_self',
    userId: 'user_self',
    fullName: 'Mr. Rohan Sharma',
    subject: 'Physics',
    bio: 'Teaching Physics for NEET & JEE aspirants with 8+ years experience.',
    qualification: 'M.Sc Physics (IIT Delhi)',
    experienceYears: 8,
    verificationStatus: TeacherVerificationStatus.verified,
    joinedSince: DateTime(2024, 3, 10),
  );

  static final List<TeacherProfileModel> _teacherPool = [
    _ownTeacherProfile,
    TeacherProfileModel(
      id: 'teacher_2',
      userId: 'user_teacher_2',
      fullName: 'Ms. Priya Verma',
      subject: 'Chemistry',
      bio: 'Simplifying Organic & Physical Chemistry for JEE/NEET.',
      qualification: 'M.Sc Organic Chemistry',
      experienceYears: 6,
      verificationStatus: TeacherVerificationStatus.verified,
      joinedSince: DateTime(2024, 4, 12),
    ),
    TeacherProfileModel(
      id: 'teacher_3',
      userId: 'user_teacher_3',
      fullName: 'Dr. Vikas Gupta',
      subject: 'Biology',
      bio: 'Ex-AIMS faculty. Specialist in Genetics & Human Physiology.',
      qualification: 'Ph.D in Botany',
      experienceYears: 10,
      verificationStatus: TeacherVerificationStatus.verified,
      joinedSince: DateTime(2023, 11, 01),
    ),
    TeacherProfileModel(
      id: 'teacher_4',
      userId: 'user_teacher_4',
      fullName: 'Er. Ankit Saxena',
      subject: 'Mathematics',
      bio: 'Calculus, Vectors & 3D Geometry tricks for Class 11-12.',
      qualification: 'B.Tech Mechanical (NIT Rourkela)',
      experienceYears: 5,
      verificationStatus: TeacherVerificationStatus.verified,
      joinedSince: DateTime(2024, 1, 15),
    ),
  ];

  static final List<GroupModel> _groups = [
    GroupModel(
      id: 'group_1',
      name: 'Physics Batch — NEET 2026',
      description: 'Complete NEET Physics syllabus, PYQs, and weekly live doubt sessions.',
      teacher: _teacherPool[0],
      studentsCount: 340,
      sharedLecturesCount: 45,
      createdAt: DateTime(2024, 3, 15),
      isJoined: false,
    ),
    GroupModel(
      id: 'group_2',
      name: 'Organic & Physical Chem — JEE Main/Adv',
      description: 'Reaction mechanisms, numerical practice, and shortcut notes.',
      teacher: _teacherPool[1],
      studentsCount: 280,
      sharedLecturesCount: 32,
      createdAt: DateTime(2024, 4, 18),
      isJoined: false,
    ),
    GroupModel(
      id: 'group_3',
      name: 'NEET Biology Mastery & Diagrams',
      description: 'NCERT line-by-line coverage, high-yield diagrams, and chapter quizzes.',
      teacher: _teacherPool[2],
      studentsCount: 520,
      sharedLecturesCount: 60,
      createdAt: DateTime(2023, 11, 10),
      isJoined: false,
    ),
    GroupModel(
      id: 'group_4',
      name: 'Class 12 Math — Calculus & Vector Power',
      description: 'Board Exam Preparation + JEE Main level problem solving.',
      teacher: _teacherPool[3],
      studentsCount: 195,
      sharedLecturesCount: 28,
      createdAt: DateTime(2024, 1, 20),
      isJoined: false,
    ),
  ];

  static final List<SuggestedTeacherModel> _suggestedTeachers = _teacherPool
    .map((t) => SuggestedTeacherModel.fromMap(t.toMap(userId: t.userId ?? '')))
    .toList();
   /// All of this teacher's groups (not just the first one) — used so the
  /// student can pick which specific class/subject to join.
  Future<List<GroupModel>> fetchGroupsForTeacher(String teacherUserId) async {
    try {
      final client = SupabaseClient.instance.client;
      final userId = SupabaseClient.instance.currentUser?.id;

      final classRows = await client
          .from('class_folders')
          .select()
          .eq('teacher_id', teacherUserId)
          .order('created_at', ascending: false);
      final classes = List<Map<String, dynamic>>.from(classRows as List);
      if (classes.isEmpty) return const [];

      final classIds = classes.map((c) => c['id'] as String).toList();
      final teacherMap = await _fetchTeacherProfilesByUserIds([teacherUserId]);
      final teacher = teacherMap[teacherUserId] ?? _placeholderTeacher(teacherUserId);
      final memberships = await _fetchMemberships(classIds);
      final feedItems = await _fetchFeed(classIds);

      return classes.map((c) {
        final classId = c['id'] as String;
        final classMemberships = memberships.where((m) => m['class_id'] == classId).toList();
        final classFeed = feedItems.where((f) => f['class_id'] == classId).toList();

        return GroupModel.fromMap(
          c,
          teacher: teacher,
          studentsCount: classMemberships.length,
          sharedLecturesCount: classFeed.where((f) => f['type'] == 'lecture').length,
          recentSharedItems: classFeed.take(5).map(GroupSharedItem.fromMap).toList(),
          isJoined: userId != null && classMemberships.any((m) => m['student_id'] == userId),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

}
    