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
          'runId': 'post-fix',
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

/// Result of [GroupsRepository.canJoinAnotherGroup] — founder-locked
/// group-join caps: free=0, ₹199=1, ₹499=3, ₹999=6, teacher=0 (own only).
class GroupJoinEligibility {
  final bool allowed;
  final int maxGroups;
  final int currentGroups;
  final String planName;
  /// Teacher ₹2,999 — cannot join others; manage own Groups only.
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

/// Thrown when join/leave against Supabase fails (no mock "success").
class GroupMembershipException implements Exception {
  final String message;
  final bool isJoinLimit;
  /// True when teacher requires approval — request submitted, not joined yet.
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

/// Real Supabase-backed repository (Phase 4).
///
/// Backing tables: `class_folders` (= "Groups" in the UI), `class_memberships`
/// (= join/leave), `group_shared_items` (= group feed), `teacher_profiles`,
/// `teacher_certificates`, `teacher_achievements`.
///
/// Every method tries a real query first and falls back to the in-memory
/// mock data below if the user is logged out, Supabase isn't configured yet
/// (Phase 4 SQL not run), or the query fails for any reason — so the UI
/// keeps working throughout setup.
class GroupsRepository {
  GroupsRepository._();

  static final GroupsRepository instance = GroupsRepository._();

  Future<List<GroupModel>> fetchGroups() async {
    try {
      final client = SupabaseClient.instance.client;
      final userId = SupabaseClient.instance.currentUser?.id;

      final classRows = await client
          .from('class_folders')
          .select()
          .order('created_at', ascending: false);
      final classes = List<Map<String, dynamic>>.from(classRows as List);

      // Logged-in: NEVER show mock groups (fake ids break Join INSERT).
      if (classes.isEmpty) {
        // #region agent log
        _groupsAgentLog('H', 'groups_repository.dart:fetchGroups', 'empty class_folders', {
          'loggedIn': userId != null,
        });
        // #endregion
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

      // #region agent log
      _groupsAgentLog('F', 'groups_repository.dart:fetchGroups', 'real groups ok', {
        'count': groups.length,
        'joinedCount': groups.where((g) => g.isJoined).length,
        'sampleId': groups.isNotEmpty ? groups.first.id : '',
      });
      // #endregion
      return groups;
    } catch (e) {
      // #region agent log
      _groupsAgentLog('F', 'groups_repository.dart:fetchGroups', 'fetchGroups failed', {
        'error': e.toString(),
        'loggedIn': SupabaseClient.instance.currentUser != null,
      });
      // #endregion
      // Logged-in: empty list (not mock). Guest/demo may still see mock.
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
          recentSharedItems: feedItems
              .take(20)
              .map(GroupSharedItem.fromMap)
              .toList(),
        isJoined: userId != null && memberships.any((m) => m['student_id'] == userId),
      );
    } catch (_) {
      for (final group in _groups) {
        if (group.id == id) return group;
      }
      return null;
    }
  }

  /// Checks group-join limit before join. Teacher plan → never join others.
  /// Server also enforces via `fn_enforce_group_join_limit` + join RPC.
  Future<GroupJoinEligibility> canJoinAnotherGroup() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      return const GroupJoinEligibility(allowed: false, maxGroups: 0, currentGroups: 0);
    }

    try {
      final planId = await SupabaseClient.instance.getPlanTier(userId);
      final plan = SubscriptionPlans.byId(planId) ?? SubscriptionPlans.free;

      // Teacher ₹2,999 — own Groups / dashboard only. No student join.
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

      // Free / max 0 — never join (no count round-trip needed).
      if (plan.maxGroups <= 0) {
        return GroupJoinEligibility(
          allowed: false,
          maxGroups: plan.maxGroups,
          currentGroups: 0,
          planName: plan.name,
        );
      }

      final rows = await SupabaseClient.instance.client
          .from('class_memberships')
          .select('id, coupon_id, join_type')
          .eq('student_id', userId);
      final list = List<dynamic>.from(rows);
      // Paid path slots only — coupon joins do not consume 1/3/6.
      final currentGroups = list.where((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final joinType = (row['join_type'] as String?)?.trim();
        final couponId = row['coupon_id'];
        if (joinType == 'coupon' || couponId != null) return false;
        return true;
      }).length;

      // #region agent log
      _groupsAgentLog('G', 'groups_repository.dart:canJoinAnotherGroup', 'eligibility ok', {
        'planId': planId,
        'maxGroups': plan.maxGroups,
        'currentGroups': currentGroups,
        'allowed': currentGroups < plan.maxGroups,
      });
      // #endregion

      return GroupJoinEligibility(
        allowed: currentGroups < plan.maxGroups,
        maxGroups: plan.maxGroups,
        currentGroups: currentGroups,
        planName: plan.name,
      );
    } catch (e) {
      // #region agent log
      _groupsAgentLog('G', 'groups_repository.dart:canJoinAnotherGroup', 'eligibility failed', {
        'error': e.toString(),
      });
      // #endregion
      // Fail closed — never allow silent over-join when plan/RPC fails.
      return const GroupJoinEligibility(
        allowed: false,
        maxGroups: 0,
        currentGroups: 0,
        planName: 'Unknown',
      );
    }
  }

  /// Joins (`INSERT`) or leaves (`DELETE`) `class_memberships` for the
  /// current student. Logged-out only uses mock; logged-in never fakes success.
  Future<GroupModel> toggleMembership(GroupModel group) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return _toggleMockMembership(group);

    // Reject fake mock ids (e.g. group_1) — UUID required for class_memberships.
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRe.hasMatch(group.id)) {
      // #region agent log
      _groupsAgentLog('H', 'groups_repository.dart:toggleMembership', 'reject non-uuid group id', {
        'groupId': group.id,
      });
      // #endregion
      throw const GroupMembershipException(
        'No groups yet. Create a group or join with an invite link.',
      );
    }

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
      throw const GroupMembershipException('Could not join group. Please try again.');
    } catch (e) {
      // #region agent log
      _groupsAgentLog('H', 'groups_repository.dart:toggleMembership', 'membership failed', {
        'error': e.toString(),
        'groupId': group.id,
        'wasJoined': group.isJoined,
      });
      // #endregion
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

  /// Display-only estimate of the CURRENT teacher's recurring commission
  /// (30% of every attributed student's active paid plan —
  /// CREDIT_ECONOMY.md §Teacher Commission). Fails safe to `0` if the
  /// migration hasn't been run yet or the caller isn't logged in — never
  /// blocks the dashboard from rendering.
  Future<double> fetchEstimatedCommission() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return 0;

    try {
      return await SupabaseClient.instance.getEstimatedCommission(userId);
    } catch (_) {
      return 0;
    }
  }

  /// Paid subscribers attributed to this teacher (same primary-teacher
  /// rule as commission). Fails safe to `0` if SQL not run yet.
  Future<int> fetchSubscriberCount() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return 0;

    try {
      return await SupabaseClient.instance.getTeacherSubscriberCount(userId);
    } catch (_) {
      return 0;
    }
  }

  /// Teachers with active Teacher ₹2,999 (`plan_id=teacher` + period not ended).
  /// Discover / Suggest / Search must hide everyone else (founder Jul 25, 2026).
  Future<Set<String>> _activeTeacherPlanUserIds() async {
    try {
      final client = SupabaseClient.instance.client;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await client
          .from('user_subscriptions')
          .select('user_id')
          .eq('plan_id', 'teacher')
          .eq('status', 'active')
          .gte('current_period_end', nowIso);
      final out = <String>{};
      for (final r in List<Map<String, dynamic>>.from(rows as List)) {
        final id = r['user_id'] as String?;
        if (id != null && id.isNotEmpty) out.add(id);
      }
      return out;
    } catch (_) {
      // Fail closed — do not show unpaid teachers in discovery.
      return {};
    }
  }

  /// Note: `isJoined` here means "already a member of one of this teacher's
  /// groups" is intentionally left `false` — computing it accurately needs a
  /// per-teacher group lookup that isn't worth the round trip for a
  /// discovery row. Real membership state always lives on [GroupModel].
  Future<List<SuggestedTeacherModel>> fetchSuggestedTeachers() async {
    try {
      final client = SupabaseClient.instance.client;
      final activeTeachers = await _activeTeacherPlanUserIds();
      if (activeTeachers.isEmpty) return const [];

      final rows = await client
          .from('teacher_profiles')
          .select()
          .eq('is_suggested', true)
          .limit(40);
      var list = List<Map<String, dynamic>>.from(rows as List)
          .where((r) => activeTeachers.contains(r['user_id'] as String?))
          .toList();
      if (list.isEmpty) return const [];

      final userId = SupabaseClient.instance.currentUser?.id;
      final scoreByUser = <String, int>{};
      final factorsByUser = <String, List<String>>{};
      if (userId != null) {
        try {
          final scoreRows = await client.rpc(
            'fn_teacher_suggestion_scores',
            params: {
              'p_student_id': userId,
              'p_threshold': 0.35,
            },
          );
          for (final raw
              in List<Map<String, dynamic>>.from(scoreRows as List)) {
            final tid = raw['teacher_user_id'] as String?;
            if (tid == null) continue;
            final ms = raw['match_score'];
            scoreByUser[tid] = ms is num ? ms.round() : 0;
            final factors = raw['matched_factors'];
            if (factors is List) {
              factorsByUser[tid] = factors
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
          }
          list.sort((a, b) {
            final ua = a['user_id'] as String? ?? '';
            final ub = b['user_id'] as String? ?? '';
            return (scoreByUser[ub] ?? 0).compareTo(scoreByUser[ua] ?? 0);
          });
        } catch (_) {}
      }

      return list.take(20).map((row) {
        final uid = row['user_id'] as String?;
        return SuggestedTeacherModel.fromMap(
          row,
          matchScore: uid == null ? null : scoreByUser[uid],
          matchedFactors:
              uid == null ? const [] : (factorsByUser[uid] ?? const []),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Discovery: active Teacher plan + ≥1 group.
  /// [filterSubjects] / [filterLocation] / [filterClassLevels] / [filterExams]
  /// = hard AND filters (Option A — City · Subject · Class · Board).
  Future<List<SuggestedTeacherModel>> discoverTeachers({
    String query = '',
    List<String> filterSubjects = const [],
    String filterLocation = '',
    List<String> filterClassLevels = const [],
    List<String> filterExams = const [],
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    List<SuggestedTeacherModel> emptyOrMock() {
      if (userId != null) return const [];
      return List.unmodifiable(_suggestedTeachers);
    }

    try {
      final client = SupabaseClient.instance.client;
      final activeTeachers = await _activeTeacherPlanUserIds();
      if (activeTeachers.isEmpty) return emptyOrMock();

      // Only teachers with at least one created class_folders row.
      final classRows = await client
          .from('class_folders')
          .select(
            'id, teacher_id, is_public, created_at, language, class_level, exam, subject',
          );
      final classList = List<Map<String, dynamic>>.from(classRows as List);
      if (classList.isEmpty) return emptyOrMock();

      final teacherIdsWithGroups = <String>{};
      final groupClassByTeacher = <String, Set<String>>{};
      final groupExamByTeacher = <String, Set<String>>{};
      final groupSubjectByTeacher = <String, Set<String>>{};
      for (final c in classList) {
        final tid = c['teacher_id'] as String?;
        if (tid != null &&
            tid.isNotEmpty &&
            activeTeachers.contains(tid)) {
          teacherIdsWithGroups.add(tid);
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
        }
      }
      if (teacherIdsWithGroups.isEmpty) return emptyOrMock();

      final rows = await client.from('teacher_profiles').select().limit(80);
      var list = List<Map<String, dynamic>>.from(rows as List).where((r) {
        final uid = r['user_id'] as String?;
        return uid != null && teacherIdsWithGroups.contains(uid);
      }).toList();
      if (list.isEmpty) return emptyOrMock();

      // ---- Hard filters (AND) — before search / score ----
      final subjectsFilter = filterSubjects
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (subjectsFilter.isNotEmpty) {
        list = list.where((r) {
          final uid = r['user_id'] as String?;
          final sub = (r['subject'] as String?)?.toLowerCase() ?? '';
          if (subjectsFilter.any((s) => sub.contains(s.toLowerCase()))) {
            return true;
          }
          final gs = uid == null ? null : groupSubjectByTeacher[uid];
          if (gs == null) return false;
          return subjectsFilter.any(
            (s) => gs.any((g) => g.toLowerCase().contains(s.toLowerCase())),
          );
        }).toList();
      }

      final locFilter = filterLocation.trim();
      if (locFilter.length >= 2) {
        final locLower = locFilter.toLowerCase();
        final fuzzyLocIds = <String>{};
        try {
          final fuzzyRows = await client.rpc(
            'fn_teacher_discover_fuzzy',
            params: {
              'p_query': locFilter,
              'p_threshold': 0.35,
            },
          );
          for (final raw
              in List<Map<String, dynamic>>.from(fuzzyRows as List)) {
            final id = raw['id'] as String?;
            if (id != null) fuzzyLocIds.add(id);
          }
        } catch (_) {}

        list = list.where((r) {
          final city = (r['city'] as String?)?.toLowerCase() ?? '';
          final state = (r['state'] as String?)?.toLowerCase() ?? '';
          if (city.contains(locLower) || state.contains(locLower)) {
            return true;
          }
          final id = r['id'] as String?;
          // Fuzzy hit only counts if teacher has a location to match.
          return id != null &&
              fuzzyLocIds.contains(id) &&
              (city.isNotEmpty || state.isNotEmpty);
        }).toList();
      }

      final classFilter = filterClassLevels
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (classFilter.isNotEmpty) {
        list = list.where((r) {
          final uid = r['user_id'] as String?;
          final pl = (r['class_levels'] as String?)?.toLowerCase() ?? '';
          if (classFilter.any((c) => pl.contains(c.toLowerCase()))) {
            return true;
          }
          final gs = uid == null ? null : groupClassByTeacher[uid];
          if (gs == null) return false;
          return classFilter.any(
            (c) => gs.any((g) => g.toLowerCase() == c.toLowerCase()),
          );
        }).toList();
      }

      final examFilter = filterExams
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (examFilter.isNotEmpty) {
        list = list.where((r) {
          final uid = r['user_id'] as String?;
          final pl = (r['exams'] as String?)?.toLowerCase() ?? '';
          if (examFilter.any((e) => pl.contains(e.toLowerCase()))) {
            return true;
          }
          final gs = uid == null ? null : groupExamByTeacher[uid];
          if (gs == null) return false;
          return examFilter.any(
            (e) => gs.any((g) => g.toLowerCase() == e.toLowerCase()),
          );
        }).toList();
      }

      if (list.isEmpty) return const [];

      String? prefSubject;
      String? prefCity;
      String? prefState;
      if (userId != null) {
        try {
          final sp = await client
              .from('student_profiles')
              .select('subjects, city, state')
              .eq('user_id', userId)
              .maybeSingle();
          if (sp != null) {
            final subjects = sp['subjects'];
            if (subjects is List && subjects.isNotEmpty) {
              prefSubject = subjects.first.toString().toLowerCase();
            }
            prefCity = (sp['city'] as String?)?.toLowerCase();
            prefState = (sp['state'] as String?)?.toLowerCase();
          }
        } catch (_) {}
      }

      final needle = query.trim();
      Map<String, double> fuzzySim = {};
      if (needle.length >= 2) {
        try {
          final fuzzyRows = await client.rpc(
            'fn_teacher_discover_fuzzy',
            params: {
              'p_query': needle,
              'p_threshold': 0.35,
            },
          );
          final matched = <String>{};
          for (final raw
              in List<Map<String, dynamic>>.from(fuzzyRows as List)) {
            final id = raw['id'] as String?;
            if (id == null) continue;
            matched.add(id);
            final sim = raw['sim'];
            if (sim is num) fuzzySim[id] = sim.toDouble();
          }
          if (matched.isNotEmpty) {
            list =
                list.where((r) => matched.contains(r['id'] as String?)).toList();
          } else {
            final q = needle.toLowerCase();
            list = list.where((r) {
              final blob = [
                r['full_name'],
                r['subject'],
                r['city'],
                r['state'],
                r['language'],
              ].whereType<String>().join(' ').toLowerCase();
              return blob.contains(q);
            }).toList();
          }
        } catch (_) {
          final q = needle.toLowerCase();
          list = list.where((r) {
            final blob = [
              r['full_name'],
              r['subject'],
              r['city'],
              r['state'],
              r['language'],
            ].whereType<String>().join(' ').toLowerCase();
            return blob.contains(q);
          }).toList();
        }
      }

      if (list.isEmpty) return const [];

      // Personalized match scores (Subject 40 / Exam 30 / City 15 / Language 15,
      // redistributed when student fields missing).
      final scoreByUser = <String, int>{};
      final factorsByUser = <String, List<String>>{};
      if (userId != null) {
        try {
          final scoreRows = await client.rpc(
            'fn_teacher_suggestion_scores',
            params: {
              'p_student_id': userId,
              'p_threshold': 0.35,
            },
          );
          for (final raw
              in List<Map<String, dynamic>>.from(scoreRows as List)) {
            final tid = raw['teacher_user_id'] as String?;
            if (tid == null) continue;
            final ms = raw['match_score'];
            scoreByUser[tid] = ms is num ? ms.round() : 0;
            final factors = raw['matched_factors'];
            if (factors is List) {
              factorsByUser[tid] = factors
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
          }
        } catch (_) {
          // Migration not run — keep legacy soft ranking below.
        }
      }

      int score(Map<String, dynamic> r) {
        final uid = r['user_id'] as String?;
        if (uid != null && scoreByUser.containsKey(uid)) {
          // Primary: personalized 0–100. Tie-break with search similarity.
          var s = scoreByUser[uid]! * 10;
          final id = r['id'] as String?;
          if (id != null && fuzzySim.containsKey(id)) {
            s += (fuzzySim[id]! * 20).round();
          }
          if (r['is_suggested'] == true) s += 5;
          return s;
        }
        // Guest / no RPC: light legacy prefs.
        var s = 0;
        final id = r['id'] as String?;
        if (id != null && fuzzySim.containsKey(id)) {
          s += (fuzzySim[id]! * 200).round();
        }
        final sub = (r['subject'] as String?)?.toLowerCase() ?? '';
        final city = (r['city'] as String?)?.toLowerCase() ?? '';
        final state = (r['state'] as String?)?.toLowerCase() ?? '';
        if (prefSubject != null && sub.contains(prefSubject)) s += 100;
        if (prefCity != null && prefCity.isNotEmpty && city == prefCity) s += 40;
        if (prefState != null && prefState.isNotEmpty && state == prefState) {
          s += 20;
        }
        if (r['is_suggested'] == true) s += 10;
        return s;
      }

      list.sort((a, b) => score(b).compareTo(score(a)));

      final teacherUserIds = list
          .map((r) => r['user_id'] as String?)
          .whereType<String>()
          .toList();
      final counts = <String, int>{};
      final classIds = classList
          .where((c) => teacherUserIds.contains(c['teacher_id']))
          .map((c) => c['id'] as String)
          .toList();
      final teacherByClass = {
        for (final c in classList)
          if (c['id'] is String && c['teacher_id'] is String)
            c['id'] as String: c['teacher_id'] as String,
      };
      if (classIds.isNotEmpty) {
        try {
          final mem = await client
              .from('class_memberships')
              .select('class_id')
              .inFilter('class_id', classIds);
          for (final m in List<Map<String, dynamic>>.from(mem as List)) {
            final tid = teacherByClass[m['class_id']];
            if (tid != null) counts[tid] = (counts[tid] ?? 0) + 1;
          }
        } catch (_) {}
      }

      final joinedTeacherUsers = <String>{};
      if (userId != null) {
        try {
          final my = await client
              .from('class_memberships')
              .select('class_id')
              .eq('student_id', userId);
          final myClassIds = List<Map<String, dynamic>>.from(my as List)
              .map((r) => r['class_id'] as String)
              .toList();
          if (myClassIds.isNotEmpty) {
            final owned = await client
                .from('class_folders')
                .select('teacher_id')
                .inFilter('id', myClassIds);
            for (final r in List<Map<String, dynamic>>.from(owned as List)) {
              joinedTeacherUsers.add(r['teacher_id'] as String);
            }
          }
        } catch (_) {}
      }

      return list
          .map((row) {
            final uid = row['user_id'] as String?;
            return SuggestedTeacherModel.fromMap(
              row,
              isJoined: uid != null && joinedTeacherUsers.contains(uid),
              studentCount: uid == null ? null : counts[uid],
              matchScore: uid == null ? null : scoreByUser[uid],
              matchedFactors:
                  uid == null ? const [] : (factorsByUser[uid] ?? const []),
            );
          })
          .toList();
    } catch (_) {
      return emptyOrMock();
    }
  }

  /// Prefer public group for Discover join/open; else newest any.
  /// Returns null if teacher has no active Teacher plan (hidden from Discover).
  Future<String?> fetchOpenGroupIdForTeacher(String teacherUserId) async {
    try {
      final active = await _activeTeacherPlanUserIds();
      if (!active.contains(teacherUserId)) return null;

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

  /// Join the teacher's open class (prefer public), then return full [GroupModel].
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
        'This teacher is not on Discover right now '
        '(Teacher plan ₹2,999 must be active).',
      );
    }

    try {
      final raw = await client.rpc(
        'fn_request_or_join_group',
        params: {'p_class_id': classId},
      );
      String status = '';
      if (raw is Map) {
        status = (raw['status'] ?? '').toString();
      } else if (raw is String) {
        try {
          final d = jsonDecode(raw);
          if (d is Map) status = (d['status'] ?? '').toString();
        } catch (_) {
          status = raw;
        }
      }
      if (status == 'pending') {
        throw const GroupMembershipException(
          'Join request sent. Waiting for teacher approval.',
          isPendingApproval: true,
        );
      }
      if (status != 'joined' && status != 'already_member') {
        throw const GroupMembershipException('Could not join group');
      }
    } catch (e) {
      if (e is GroupMembershipException) rethrow;
      throw GroupMembershipException(
        e.toString().contains('Group join limit')
            ? 'Group join limit reached'
            : 'Could not join: $e',
        isJoinLimit: e.toString().contains('Group join limit'),
      );
    }

    final full = await fetchGroupById(classId);
    if (full != null) return full.copyWith(isJoined: true);
    return GroupModel(
      id: classId,
      name: 'Group',
      description: '',
      teacher: TeacherProfileModel(
        id: teacherProfileId,
        userId: tid,
        fullName: 'Teacher',
        subject: '',
        joinedSince: DateTime.now(),
      ),
      teacherUserId: tid,
      createdAt: DateTime.now(),
      isJoined: true,
    );
  }

  /// Coupon lock / urgency for current user's membership in this group.
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
      // A genuinely new teacher (just picked "I'm a Teacher" on the role
      // selection screen) has no row yet — pre-fill their real name
      // instead of the "Mr. Rohan Sharma" mock, so the edit sheet doesn't
      // look like someone else's profile.
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

  /// Upload teacher avatar to Supabase Storage bucket `teacher-photos`,
  /// return public URL. Path: `{userId}/avatar.jpg`.
  /// Founder must create the bucket once — see FOUNDER_TEACHER_PROFILE_PHOTO.md.
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
    // Cache-bust so Groups/Discover refresh the new image immediately.
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Persists the edit sheet's certificate list to `teacher_certificates`
  /// (title + review `status` only — Postgres metadata rule; `file_url`
  /// stays null until Phase 5 wires Cloudflare R2 upload). Simple
  /// replace-all sync since certificate lists are short. Non-fatal on
  /// failure — the profile itself has already been saved by this point.
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

  // ==================== SUPABASE HELPERS ====================

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

      // Certificates: only fetch when teacher opted to show (RLS also enforces).
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
    // Pinned first, then newest (WhatsApp-channel feel).
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

  /// Minimal fallback when a group's teacher has no `teacher_profiles` row
  /// yet (e.g. teacher hasn't completed onboarding) — keeps the group card
  /// renderable instead of throwing.
  TeacherProfileModel _placeholderTeacher(String userId) {
    return TeacherProfileModel(
      id: userId,
      userId: userId,
      fullName: 'Teacher',
      subject: '',
      joinedSince: DateTime.now(),
    );
  }

  /// Blank starting point for the CURRENT user's own edit sheet, used when
  /// they've just picked "I'm a Teacher" and have no `teacher_profiles`
  /// row yet. Unlike [_placeholderTeacher] (for OTHER teachers' cards),
  /// this pre-fills their real name so the form doesn't look pre-owned by
  /// someone else.
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

  // ==================== MOCK DATA (fallback only) ====================

  static TeacherProfileModel _ownTeacherProfile = TeacherProfileModel(
    id: 'teacher_self',
    fullName: 'Mr. Rohan Sharma',
    subject: 'Physics',
    bio: 'Teaching Physics for NEET & JEE aspirants for over 8 years.',
    qualification: 'M.Sc Physics, B.Ed',
    experienceYears: 8,
    verificationStatus: TeacherVerificationStatus.verified,
    joinedSince: DateTime(2024, 3, 10),
    totalStudents: 205,
    totalGroups: 3,
    totalSharedLectures: 42,
    certificates: [
      TeacherCertificateModel(
        id: 'c1',
        title: 'M.Sc Physics Degree',
        uploadedAt: DateTime(2024, 3, 12),
      ),
      TeacherCertificateModel(
        id: 'c2',
        title: 'B.Ed Certification',
        uploadedAt: DateTime(2024, 3, 12),
      ),
    ],
    achievements: [
      TeacherAchievementModel(
        id: 'a1',
        title: 'Best Faculty Award 2023',
        description: 'Awarded by Aakash Coaching Network',
        type: TeacherAchievementType.award,
      ),
    ],
  );

  static final List<TeacherProfileModel> _teacherPool = [
    _ownTeacherProfile,
    TeacherProfileModel(
      id: 'teacher_2',
      fullName: 'Ms. Priya Verma',
      subject: 'Chemistry',
      bio: 'Simplifying Organic Chemistry for NEET aspirants.',
      qualification: 'M.Sc Chemistry',
      experienceYears: 6,
      verificationStatus: TeacherVerificationStatus.verified,
      joinedSince: DateTime(2024, 6, 1),
      totalStudents: 140,
      totalGroups: 2,
      totalSharedLectures: 30,
      certificates: [
        TeacherCertificateModel(
          id: 'c3',
          title: 'M.Sc Chemistry Degree',
          uploadedAt: DateTime(2024, 6, 2),
        ),
      ],
    ),
    TeacherProfileModel(
      id: 'teacher_3',
      fullName: 'Mr. Aditya Rao',
      subject: 'Mathematics',
      bio: 'JEE Mains & Advanced Mathematics mentor.',
      qualification: 'B.Tech, M.Sc Mathematics',
      experienceYears: 5,
      verificationStatus: TeacherVerificationStatus.pending,
      joinedSince: DateTime(2025, 1, 15),
      totalStudents: 88,
      totalGroups: 1,
      totalSharedLectures: 18,
    ),
  ];

  static final List<GroupModel> _groups = [
    GroupModel(
      id: 'group_1',
      name: 'Physics Batch — NEET 2026',
      description: 'Complete NEET Physics coverage with weekly tests and revision notes.',
      teacher: _teacherPool[0],
      studentsCount: 120,
      sharedLecturesCount: 24,
      createdAt: DateTime(2024, 3, 15),
      rules: [
        'Be respectful in the community',
        'No sharing of notes outside the group',
        'Attend weekly quizzes for progress tracking',
      ],
      allowedContent: const ['Notes', 'Quiz', 'Homework', 'Announcements'],
      recentSharedItems: [
        GroupSharedItem(
          id: 's1',
          title: 'Lecture 12 — Electromagnetism',
          type: GroupSharedItemType.lecture,
          sharedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        GroupSharedItem(
          id: 's2',
          title: 'Unit Test — Revision Notes',
          type: GroupSharedItemType.notes,
          sharedAt: DateTime.now().subtract(const Duration(days: 2)),
          isPinned: true,
        ),
        GroupSharedItem(
          id: 's3',
          title: 'Homework — Chapter 4',
          type: GroupSharedItemType.homework,
          sharedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    ),
    GroupModel(
      id: 'group_2',
      name: 'Organic Chemistry Mastery',
      description: 'Weekly organic chemistry sessions for Class 12 & NEET.',
      teacher: _teacherPool[1],
      studentsCount: 95,
      sharedLecturesCount: 16,
      createdAt: DateTime(2024, 7, 5),
      rules: const ['No spamming', 'Read shared notes · use Quiz when shared'],
      allowedContent: const ['Notes', 'Quiz'],
      recentSharedItems: [
        GroupSharedItem(
          id: 's4',
          title: 'Pinned Announcement — Test on Friday',
          type: GroupSharedItemType.announcement,
          sharedAt: DateTime.now().subtract(const Duration(hours: 12)),
          isPinned: true,
        ),
      ],
      // Never pretends joined — fallback mock must not look like a real membership.
      isJoined: false,
    ),
    GroupModel(
      id: 'group_3',
      name: 'JEE Mathematics Sprint',
      description: 'Fast-paced problem solving for JEE Mains & Advanced.',
      teacher: _teacherPool[2],
      studentsCount: 60,
      sharedLecturesCount: 10,
      createdAt: DateTime(2025, 1, 20),
      rules: const ['Practice daily', 'Submit homework on time'],
      allowedContent: const ['Homework', 'Quiz'],
    ),
  ];

  static final List<SuggestedTeacherModel> _suggestedTeachers = _teacherPool
      .map(
        (t) => SuggestedTeacherModel(
          id: t.id,
          name: t.fullName,
          subject: t.subject,
          isVerified: t.isVerified,
        ),
      )
      .toList();
}
