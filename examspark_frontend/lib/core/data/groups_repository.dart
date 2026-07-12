import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/models/suggested_teacher_model.dart';
import 'package:examspark_frontend/core/models/teacher_achievement_model.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';

/// Result of [GroupsRepository.canJoinAnotherGroup] — founder-locked
/// Jul 12, 2026 group-join limits (free=0, ₹199=1, ₹499=3, ₹999=6,
/// teacher=unlimited). Client-side check only for now; real server-side
/// enforcement is Phase 5.
class GroupJoinEligibility {
  final bool allowed;
  final int maxGroups;
  final int currentGroups;
  final String planName;

  const GroupJoinEligibility({
    required this.allowed,
    required this.maxGroups,
    required this.currentGroups,
    this.planName = 'Free',
  });

  bool get isUnlimited => maxGroups < 0;
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
      if (classes.isEmpty) return List.unmodifiable(_groups);

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
    } catch (_) {
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
        recentSharedItems: feedItems.take(5).map(GroupSharedItem.fromMap).toList(),
        isJoined: userId != null && memberships.any((m) => m['student_id'] == userId),
      );
    } catch (_) {
      for (final group in _groups) {
        if (group.id == id) return group;
      }
      return null;
    }
  }

  /// Checks the founder-locked group-join limit for the caller's current
  /// plan (free=0, ₹199=1, ₹499=3, ₹999=6, teacher=unlimited) before a
  /// join goes through. Client-side only — fails OPEN (allows the join) if
  /// the check itself errors, so a missing/undeployed RPC never blocks
  /// joining; real server-side enforcement is Phase 5.
  Future<GroupJoinEligibility> canJoinAnotherGroup() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      return const GroupJoinEligibility(allowed: false, maxGroups: 0, currentGroups: 0);
    }

    try {
      final planId = await SupabaseClient.instance.getPlanTier(userId);
      final plan = SubscriptionPlans.byId(planId) ?? SubscriptionPlans.free;

      if (plan.hasUnlimitedGroups) {
        return GroupJoinEligibility(allowed: true, maxGroups: -1, currentGroups: 0, planName: plan.name);
      }

      final rows = await SupabaseClient.instance.client
          .from('class_memberships')
          .select('id')
          .eq('student_id', userId);
      final currentGroups = List<Map<String, dynamic>>.from(rows as List).length;

      return GroupJoinEligibility(
        allowed: currentGroups < plan.maxGroups,
        maxGroups: plan.maxGroups,
        currentGroups: currentGroups,
        planName: plan.name,
      );
    } catch (_) {
      return const GroupJoinEligibility(allowed: true, maxGroups: -1, currentGroups: 0);
    }
  }

  /// Joins (`INSERT`) or leaves (`DELETE`) `class_memberships` for the
  /// current student. Requires the student to be logged in.
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
      } else {
        await client.from('class_memberships').insert({
          'class_id': group.id,
          'student_id': userId,
        });
      }
      return group.copyWith(isJoined: !group.isJoined);
    } catch (_) {
      return _toggleMockMembership(group);
    }
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

  /// Note: `isJoined` here means "already a member of one of this teacher's
  /// groups" is intentionally left `false` — computing it accurately needs a
  /// per-teacher group lookup that isn't worth the round trip for a
  /// discovery row. Real membership state always lives on [GroupModel].
  Future<List<SuggestedTeacherModel>> fetchSuggestedTeachers() async {
    try {
      final client = SupabaseClient.instance.client;
      final rows = await client
          .from('teacher_profiles')
          .select()
          .eq('is_suggested', true)
          .limit(20);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isEmpty) return List.unmodifiable(_suggestedTeachers);

      return list.map((row) => SuggestedTeacherModel.fromMap(row)).toList();
    } catch (_) {
      return List.unmodifiable(_suggestedTeachers);
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
    return {
      for (final row in list) row['user_id'] as String: TeacherProfileModel.fromMap(row),
    };
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
    return List<Map<String, dynamic>>.from(rows as List);
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
      rules: const ['No spamming', 'Ask doubts using Ask AI, not group chat'],
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
      isJoined: true,
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
