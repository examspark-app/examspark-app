import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/services/coupon_service.dart';
import 'package:examspark_frontend/core/services/teacher_setup_gate.dart';
import 'package:examspark_frontend/core/services/teacher_students_service.dart';
import 'package:examspark_frontend/core/services/ui_session_store.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/teacher_profile_setup_screen.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/get_verified_sheet.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_profile_card.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_setup_checklist_card.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_setup_gate_sheet.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_library_section.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_social_links_sheet.dart';
import 'package:examspark_frontend/presentation/screens/groups/group_dashboard_screen.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/create_group_disclaimer_sheet.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/create_study_group_sheet.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/group_invite_qr_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/buy_plan_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Teacher business dashboard — full spec: TEACHER_PLATFORM.md (founder saved Jul 2026).
///
/// Live cards: Students · Active today · Subscribers (paid, primary teacher) ·
/// Credits · Groups.
/// Upcoming placeholders: Est. Commission · Revenue · Analytics (Storage removed — account delete).
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key, this.openEditOnLoad = false});

  /// Set when arriving straight from the role-selection screen
  /// ("I'm a Teacher") — auto-opens full-page profile setup once loaded.
  final bool openEditOnLoad;

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int? _creditBalance;
  TeacherProfileModel? _teacherProfile;
  TeacherSetupGateStatus? _setupGate;
  List<ClassFolder> _classFolders = [];
  int _totalStudents = 0;
  bool _loadingClasses = true;
  int? _subscriberCount;
  List<Map<String, dynamic>> _students = [];
  bool _loadingStudents = true;
  String _studentSort = 'performance'; // performance | joinDate | active
  int _dailyActiveCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
    _loadClasses();
    _loadCredits();
    _loadSubscribers();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final payload = await TeacherStudentsService.instance.listStudentsPayload();
      if (!mounted) return;
      setState(() {
        _students = List<Map<String, dynamic>>.from(payload['students'] as List);
        _dailyActiveCount = (payload['daily_active_count'] as int?) ?? 0;
        _loadingStudents = false;
      });
      _sortStudents();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStudents = false);
    }
  }

  void _sortStudents() {
    final sorted = List<Map<String, dynamic>>.from(_students);
    if (_studentSort == 'joinDate') {
      sorted.sort((a, b) {
        final aj = (a['joined_at'] as String?) ?? '';
        final bj = (b['joined_at'] as String?) ?? '';
        return bj.compareTo(aj);
      });
    } else if (_studentSort == 'active') {
      sorted.sort((a, b) {
        final aa = a['active_today'] == true ? 1 : 0;
        final ba = b['active_today'] == true ? 1 : 0;
        if (aa != ba) return ba.compareTo(aa);
        final al = (a['last_active_at'] as String?) ?? '';
        final bl = (b['last_active_at'] as String?) ?? '';
        return bl.compareTo(al);
      });
    } else {
      sorted.sort((a, b) {
        final ap = a['overall_percent'];
        final bp = b['overall_percent'];
        final an = ap is num ? ap.toDouble() : -1.0;
        final bn = bp is num ? bp.toDouble() : -1.0;
        return bn.compareTo(an);
      });
    }
    setState(() => _students = sorted);
  }

  Future<void> _loadTeacherProfile() async {
    final profile = await GroupsRepository.instance.fetchOwnTeacherProfile();
    final gate = await TeacherSetupGate.evaluate(profile);
    if (!mounted) return;
    setState(() {
      _teacherProfile = profile;
      _setupGate = gate;
    });
    if (widget.openEditOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final gate = _setupGate;
        if (gate == null) {
          _openEditProfile();
          return;
        }
        if (!gate.profileGateComplete) {
          await _openEditProfile();
        } else if (!gate.hasVerified) {
          await _openGetVerified();
        } else if (!gate.hasTeacherPlan) {
          _openBuyTeacherPlan();
        }
      });
    }
  }

  Future<void> _refreshSetupGate() async {
    final gate = await TeacherSetupGate.evaluate(_teacherProfile);
    if (!mounted) return;
    setState(() => _setupGate = gate);
  }

  Future<void> _loadClasses() async {
    try {
      final rows = await ClassService.instance.getTeacherClasses();
      final classIds = rows.map((r) => r['id'] as String).toList();
      final counts = await ClassService.instance.getStudentCountsForClasses(classIds);
      final pending = await ClassService.instance.pendingCountsForClasses(classIds);

      if (!mounted) return;
      setState(() {
        _classFolders = rows
            .map(
              (r) => ClassFolder(
                id: r['id'] as String,
                name: r['name'] as String,
                subject: r['subject'] as String? ?? '',
                studentCount: counts[r['id']] ?? 0,
                joinCode: r['join_code'] as String? ?? '',
                pendingCount: pending[r['id'] as String] ?? 0,
                joinApprovalMode:
                    (r['join_approval_mode'] as String?) ?? 'auto',
                classLevel: r['class_level'] as String?,
                exam: r['exam'] as String?,
                language: r['language'] as String?,
              ),
            )
            .toList();
        _totalStudents = counts.values.fold(0, (sum, count) => sum + count);
        _loadingClasses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadCredits() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await SupabaseClient.instance.getUserProfile(userId);
      if (!mounted || profile == null) return;
      setState(() => _creditBalance = profile['credits_balance'] as int?);
    } catch (_) {
      // Supabase not configured yet — leave as placeholder dash.
    }
  }

  /// Subscribers count only — Est. Commission moved to "Upcoming" placeholder
  /// (no payout/commission system live yet).
  Future<void> _loadSubscribers() async {
    final subscribers = await GroupsRepository.instance.fetchSubscriberCount();
    if (!mounted) return;
    setState(() {
      _subscriberCount = subscribers;
    });
  }

  /// Manual refresh — this screen is not live Realtime yet.
  Future<void> _refreshDashboard() async {
    AppToast.showSnackBar(
      context,
      const SnackBar(content: Text('Refreshing dashboard…')),
    );
    await Future.wait([
      _loadTeacherProfile(),
      _loadClasses(),
      _loadCredits(),
      _loadSubscribers(),
      _loadStudents(),
      _refreshSetupGate(),
    ]);
    if (!mounted) return;
    AppToast.showSnackBar(
      context,
      const SnackBar(content: Text('Dashboard updated')),
    );
  }

  Future<void> _openEditProfile() async {
    final profile = _teacherProfile;
    if (profile == null) return;
    final saved = await Navigator.of(context).push<TeacherProfileModel>(
      MaterialPageRoute(
        builder: (_) => TeacherProfileSetupScreen(profile: profile),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      setState(() => _teacherProfile = saved);
      await _refreshSetupGate();
      if (!mounted) return;
      final gate = _setupGate;
      // Profile just saved complete → go straight to Get Verified (AI).
      if (gate != null && gate.profileGateComplete && !gate.hasVerified) {
        await _openGetVerified();
        return;
      }
      if (gate != null && gate.canBuyTeacherPlan && !gate.hasTeacherPlan) {
        AppToast.showSnackBar(
          context,
          const SnackBar(
            content: Text('Profile OK — opening Teacher plan (₹2,999)'),
          ),
        );
        _openBuyTeacherPlan();
        return;
      }
      AppToast.showSnackBar(
        context,
        const SnackBar(content: Text('Profile saved')),
      );
    } else {
      await _loadTeacherProfile();
    }
  }

  Future<void> _openSocialLinks() async {
    final profile = _teacherProfile;
    if (profile == null) return;
    final saved = await showTeacherSocialLinksSheet(
      context,
      profile: profile,
      onSave: GroupsRepository.instance.updateOwnTeacherProfile,
    );
    if (!mounted || saved == null) return;
    setState(() => _teacherProfile = saved);
    await _refreshSetupGate();
    if (!mounted) return;
    AppToast.showSnackBar(context,
      const SnackBar(content: Text('Social links saved — students see them on your profile')),
    );
  }

  void _openBuyTeacherPlan() {
    final gate = _setupGate;
    if (gate != null && !gate.canBuyTeacherPlan) {
      if (!gate.profileGateComplete) {
        final missing = gate.missingProfileLabels.join(', ');
        AppToast.showSnackBar(
          context,
          SnackBar(
            content: Text(
              'Teacher plan locked. Finish profile first ($missing), then Get Verified (AI).',
            ),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
        _openEditProfile();
        return;
      }
      if (!gate.hasVerified) {
        AppToast.showSnackBar(
          context,
          const SnackBar(
            content: Text(
              'Teacher plan locked until Get Verified (AI Trusted badge). Opening verify…',
            ),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
        _openGetVerified();
        return;
      }
    }
    Navigator.of(context).pushNamed('/subscription').then((_) {
      if (mounted) _refreshSetupGate();
    });
  }

  Future<void> _openGetVerified() async {
    final gate = _setupGate ??
        await TeacherSetupGate.evaluate(_teacherProfile);
    if (!mounted) return;
    if (!gate.profileGateComplete) {
      final missing = gate.missingProfileLabels.join(', ');
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            'Get Verified locked. Complete profile first: $missing',
          ),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
      await _openEditProfile();
      return;
    }
    final trusted = await showGetVerifiedSheet(context);
    if (!mounted) return;
    await _loadTeacherProfile();
    if (!mounted) return;
    if (trusted == true) {
      // AI verified → payment next.
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text('Trusted badge OK — opening Teacher plan (₹2,999)'),
        ),
      );
      _openBuyTeacherPlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTeacherPlan = _setupGate?.hasTeacherPlan == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingClasses ? null : _refreshDashboard,
            tooltip: 'Refresh dashboard',
          ),
          // Duplicate "Create Group" trigger removed — the floating
          // action button below is the single entry point for this action.
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateStudyGroup,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher public profile — photo, subject, qualification, stats
            _teacherProfile == null
                ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                : TeacherProfileCard(
                    profile: _teacherProfile!,
                    onEdit: _openEditProfile,
                    onEditSocialLinks: _openSocialLinks,
                    onGetVerified: _openGetVerified,
                  ),
            if (_setupGate != null) ...[
              const SizedBox(height: 12),
              TeacherSetupChecklistCard(
                status: _setupGate!,
                onEditProfile: _openEditProfile,
                onBuyPlan: _openBuyTeacherPlan,
                onGetVerified: _openGetVerified,
                onCreateGroup: _showCreateStudyGroup,
              ),
            ],
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Lock B: Teacher plan required for Record (same as Create Group).
                  final gate = _setupGate;
                  if (gate == null || !gate.hasTeacherPlan) {
                    AppToast.showSnackBar(
                      context,
                      const SnackBar(
                        content: Text(
                          'Teacher plan ₹2,999 required for Record. '
                          'When the plan month ends, Record + new Create Group stay locked until renew.',
                        ),
                        backgroundColor: Color(0xFFC62828),
                      ),
                    );
                    _openBuyTeacherPlan();
                    return;
                  }
                  Navigator.pushNamed(
                    context,
                    '/recorder',
                    arguments: {'teacherRecordOnly': true},
                  );
                },
                icon: const Icon(Icons.mic, size: 20),
                label: const Text('Record lecture'),
              ),
            ),
            // Only show the Teacher-plan requirement note when the plan is
            // NOT active — an active teacher shouldn't see a "locked" style
            // message next to a feature they already have full access to.
            if (!hasTeacherPlan) ...[
              const SizedBox(height: 8),
              Text(
                'Record + Create Group + Share workspace need active Teacher ₹2,999. '
                'Existing groups stay if the plan month ends.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
              ),
            ],
            const SizedBox(height: 20),

            // Business metric cards — placeholder data (Phase 4/5 wiring)
            _buildBusinessCards(),
            const SizedBox(height: 24),

            _buildStudentsSection(),
            const SizedBox(height: 24),

            const TeacherLibrarySection(),
            const SizedBox(height: 24),

            // Class folders header
            Text(
              'Your Classes',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Class folders list
            if (_loadingClasses)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_classFolders.isEmpty)
              Text(
                'No Study Groups yet — tap Create Group.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _classFolders.length,
                itemBuilder: (context, index) {
                  final folder = _classFolders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ClassFolderCard(
                      folder: folder,
                      onOpenDashboard: () => _openGroupDashboard(folder),
                      onShareInvite: () => _shareInviteCode(folder),
                      onShowQr: () => showGroupInviteQrSheet(
                        context,
                        invite: GroupInviteQrData.fromCode(
                          groupName: folder.name,
                          joinCode: folder.joinCode,
                        ),
                      ),
                      onGenerateCoupon: () => _generateCoupon(folder),
                      onOpenPending: () => _showPendingRequests(folder),
                      onDelete: () => _confirmDeleteGroup(folder),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Students',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            DropdownButton<String>(
              value: _studentSort,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: 'performance',
                  child: Text('Sort: performance'),
                ),
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Sort: active today'),
                ),
                DropdownMenuItem(
                  value: 'joinDate',
                  child: Text('Sort: join date'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _studentSort = v);
                _sortStudents();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Active today = opened your group in the last 24 hours. Quiz % on your shared lectures.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.getSecondaryText(context),
              ),
        ),
        if (!_loadingStudents && _students.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Active today: $_dailyActiveCount / ${_students.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
          ),
        ],
        const SizedBox(height: 12),
        if (_loadingStudents)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_students.isEmpty)
          Text(
            'No students joined yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = _students[index];
              return _StudentPerformanceTile(student: s);
            },
          ),
      ],
    );
  }

  Widget _buildBusinessCards() {
    final cards = [
      _MetricCard(icon: Icons.people_outline, label: 'Students', value: '$_totalStudents'),
      _MetricCard(
        icon: Icons.sensors,
        label: 'Active today',
        value: _loadingStudents ? '…' : '$_dailyActiveCount',
        tooltip: 'Students who opened one of your groups in the last 24 hours.',
      ),
      _MetricCard(
        icon: Icons.person_add_outlined,
        label: 'Subscribers',
        value: _subscriberCount == null ? '…' : '$_subscriberCount',
        tooltip:
            'Paid-plan students whose primary Group is yours (most recent join). '
            'Free joins are not counted.',
      ),
      _MetricCard(
        icon: Icons.handshake_outlined,
        label: 'Est. Commission',
        value: '—',
        isPlaceholder: true,
        tooltip: 'Upcoming — commission payout system not live yet.',
      ),
      _MetricCard(
        icon: Icons.bolt,
        label: 'Credits',
        value: _creditBalance == null ? '—' : '$_creditBalance',
      ),
      _MetricCard(
        icon: Icons.groups_outlined,
        label: 'Groups',
        value: '${_classFolders.length}',
      ),
      _MetricCard(
        icon: Icons.currency_rupee,
        label: 'Revenue',
        value: '—',
        isPlaceholder: true,
        tooltip: 'Upcoming — Razorpay / payout wiring later.',
      ),
      _MetricCard(
        icon: Icons.insights_outlined,
        label: 'Analytics',
        value: '—',
        isPlaceholder: true,
        tooltip: 'Upcoming — charts later. Per-group analytics already on Group open.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Overview',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 620
                    ? 3
                    : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: cards,
            );
          },
        ),
      ],
    );
  }

  Future<void> _showPendingRequests(ClassFolder folder) async {
    final rows = await ClassService.instance.listPendingJoinRequests(folder.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var items = List<Map<String, dynamic>>.from(rows);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending — ${folder.name}',
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accept or reject join requests. No chat.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'No pending requests',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final row = items[i];
                              final user = row['users'];
                              String name = 'Student';
                              if (user is Map) {
                                name = (user['username'] as String?)?.trim().isNotEmpty == true
                                    ? user['username'] as String
                                    : ((user['full_name'] as String?) ??
                                        (user['email'] as String?) ??
                                        'Student');
                              }
                              final reqId = row['id'] as String;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppTheme.getCardBorder(context),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.borderRadius,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          await ClassService.instance
                                              .rejectJoinRequest(reqId);
                                          setModal(() {
                                            items = items
                                                .where((e) => e['id'] != reqId)
                                                .toList();
                                          });
                                          _loadClasses();
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(content: Text('Reject failed: $e')),
                                          );
                                        }
                                      },
                                      child: const Text('Reject'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await ClassService.instance
                                              .acceptJoinRequest(reqId);
                                          setModal(() {
                                            items = items
                                                .where((e) => e['id'] != reqId)
                                                .toList();
                                          });
                                          _loadClasses();
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(content: Text('Accept failed: $e')),
                                          );
                                        }
                                      },
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) _loadClasses();
  }

  void _openGroupDashboard(ClassFolder folder) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDashboardScreen(
          classId: folder.id,
          name: folder.name,
          joinCode: folder.joinCode,
          subject: folder.subject,
          joinApprovalMode: folder.joinApprovalMode,
          classLevel: folder.classLevel,
          exam: folder.exam,
          language: folder.language,
        ),
      ),
    ).then((_) {
      if (mounted) _loadClasses();
    });
  }

  Future<void> _showCreateStudyGroup() async {
    // Always re-check (plan may have changed after Subscription screen).
    final gate = await TeacherSetupGate.evaluate(_teacherProfile);
    if (!mounted) return;
    setState(() => _setupGate = gate);
    if (!gate.canCreateGroup) {
      await showTeacherSetupGateSheet(
        context: context,
        status: gate,
        onCompleteProfile: _openEditProfile,
        onBuyPlan: _openBuyTeacherPlan,
        onGetVerified: _openGetVerified,
      );
      return;
    }

    final seen =
        await UiSessionStore.instance.hasAcknowledgedCreateGroupDisclaimer();
    if (!mounted) return;
    if (!seen) {
      final ok = await showCreateGroupDisclaimerSheet(context);
      if (!mounted) return;
      if (!ok) return;
      await UiSessionStore.instance.setCreateGroupDisclaimerAcknowledged();
      if (!mounted) return;
    }

    final created = await showCreateStudyGroupSheet(
      context,
      suggestedSubject: _teacherProfile?.subject,
      profile: _teacherProfile,
    );
    if (!mounted || created == null) return;
    final folder = ClassFolder(
      id: created.id,
      name: created.name,
      subject: created.subject,
      studentCount: 0,
      joinCode: created.joinCode,
      joinApprovalMode: created.joinApprovalMode,
      classLevel: created.classLevel,
      exam: created.exam,
      language: created.language,
    );
    setState(() {
      _classFolders.insert(0, folder);
    });
    AppToast.showSnackBar(context,
      SnackBar(
        content: Text('Study Group "${created.name}" ready · code ${created.joinCode}'),
        duration: const Duration(seconds: 2),
      ),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDashboardScreen(
          classId: folder.id,
          name: folder.name,
          joinCode: folder.joinCode,
          subject: folder.subject,
          joinApprovalMode: folder.joinApprovalMode,
          classLevel: folder.classLevel,
          exam: folder.exam,
          language: folder.language,
        ),
      ),
    );
    if (mounted) _loadClasses();
  }

  void _shareInviteCode(ClassFolder folder) {
    final inviteLink = AppBrand.inviteJoinUrl(folder.joinCode);
    Clipboard.setData(ClipboardData(text: inviteLink));
    AppToast.show(
      'Invite link copied: $inviteLink',
      isError: false,
      context: context,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _generateCoupon(ClassFolder folder) async {
    try {
      final result = await CouponService.instance.createCoupon(folder.id);
      final code = result['code'] as String? ?? '';
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Coupon created'),
          content: Text(
            'Code: $code\n'
            'Group: ${folder.name}\n'
            'Max students: ${result['max_redemptions'] ?? 100}\n\n'
            'Students redeem this for first-month free group access '
            '(uses their normal Free 50 credits/mo — no extra grant). '
            'No commission on coupon joins. Code copied.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(context,
        SnackBar(content: Text('Coupon failed: $e')),
      );
    }
  }

  Future<void> _confirmDeleteGroup(ClassFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this group?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folder.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (folder.subject.isNotEmpty) Text('Subject: ${folder.subject}'),
            if (folder.classLevel != null && folder.classLevel!.isNotEmpty)
              Text('Class: ${folder.classLevel}'),
            if (folder.exam != null && folder.exam!.isNotEmpty)
              Text('Board/Exam: ${folder.exam}'),
            if (folder.language != null && folder.language!.isNotEmpty)
              Text('Language: ${folder.language}'),
            Text('Students: ${folder.studentCount}'),
            Text('Join code: ${folder.joinCode}'),
            const SizedBox(height: 12),
            const Text(
              'This permanently removes the group, its students, pending '
              'requests, and shared lecture links. This cannot be undone.',
              style: TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ClassService.instance.deleteClass(folder.id);
      if (!mounted) return;
      setState(() {
        _classFolders.removeWhere((f) => f.id == folder.id);
      });
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('"${folder.name}" deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}

// ==================== METRIC CARD ====================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPlaceholder;
  final String? tooltip;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.isPlaceholder = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentColor, size: 20),
              if (isPlaceholder) ...[
                const Spacer(),
                Text(
                  'Upcoming',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    if (tooltip == null) return card;
    return Tooltip(message: tooltip!, child: card);
  }
}

Widget _buildTag(BuildContext context, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.getAccentTint(context),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
    ),
  );
}

// ==================== CLASS FOLDER CARD ====================

class _ClassFolderCard extends StatelessWidget {
  final ClassFolder folder;
  final VoidCallback onOpenDashboard;
  final VoidCallback onShareInvite;
  final VoidCallback onShowQr;
  final VoidCallback onGenerateCoupon;
  final VoidCallback onOpenPending;
  final VoidCallback onDelete;

  const _ClassFolderCard({
    required this.folder,
    required this.onOpenDashboard,
    required this.onShareInvite,
    required this.onShowQr,
    required this.onGenerateCoupon,
    required this.onOpenPending,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOpenDashboard,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.getAccentTint(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_outlined,
                    color: AppTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppTheme.getSecondaryText(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${folder.studentCount} Students',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                            ),
                          ),
                          if (folder.joinApprovalMode == 'approval') ...[
                            const SizedBox(width: 10),
                            Text(
                              'Approval on',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      if (folder.subject.isNotEmpty ||
                          (folder.classLevel != null && folder.classLevel!.isNotEmpty) ||
                          (folder.exam != null && folder.exam!.isNotEmpty) ||
                          (folder.language != null && folder.language!.isNotEmpty)) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (folder.subject.isNotEmpty) _buildTag(context, folder.subject),
                            if (folder.classLevel != null && folder.classLevel!.isNotEmpty)
                              _buildTag(context, folder.classLevel!),
                            if (folder.exam != null && folder.exam!.isNotEmpty)
                              _buildTag(context, folder.exam!),
                            if (folder.language != null && folder.language!.isNotEmpty)
                              _buildTag(context, folder.language!),
                          ],
                        ),
                      ],
                      Text(
                        'Tap for group dashboard',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: onShareInvite,
                  tooltip: 'Share Invite Link',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            color: AppTheme.getCardBorder(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenDashboard,
              icon: const Icon(Icons.dashboard_outlined, size: 16),
              label: const Text('Open group dashboard'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
                foregroundColor: AppTheme.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete group'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFC62828)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (folder.joinApprovalMode == 'approval' || folder.pendingCount > 0) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenPending,
                icon: const Icon(Icons.how_to_reg_outlined, size: 16),
                label: Text(
                  folder.pendingCount > 0
                      ? 'Pending requests (${folder.pendingCount})'
                      : 'Pending requests',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                  foregroundColor: folder.pendingCount > 0
                      ? AppTheme.accentColor
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShareInvite,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Share link'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowQr,
                  icon: const Icon(Icons.qr_code_2, size: 16),
                  label: const Text('QR'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGenerateCoupon,
              icon: const Icon(Icons.confirmation_number_outlined, size: 16),
              label: const Text('Generate Coupon (100 students)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== STUDENT PERFORMANCE TILE ====================

class _StudentPerformanceTile extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentPerformanceTile({required this.student});

  String _pct(dynamic v) {
    if (v is num) return '${v.round()}%';
    return '—';
  }

  String _lastActiveLabel() {
    if (student['active_today'] == true) return 'Active today';
    final raw = student['last_active_at'] as String?;
    if (raw == null || raw.isEmpty) return 'Not seen yet';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return 'Not seen yet';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = (student['username'] as String?) ?? 'Student';
    final coupon = student['joined_via_coupon'] == true;
    final groups = (student['group_names'] as List?)?.cast<String>() ?? const [];
    final groupLine = groups.isEmpty ? '' : groups.join(', ');
    final activeToday = student['active_today'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: activeToday
              ? AppTheme.accentColor.withValues(alpha: 0.45)
              : AppTheme.getCardBorder(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                _pct(student['overall_percent']),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: activeToday
                      ? AppTheme.getAccentTint(context)
                      : AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: activeToday
                        ? AppTheme.accentColor.withValues(alpha: 0.4)
                        : AppTheme.getCardBorder(context),
                  ),
                ),
                child: Text(
                  _lastActiveLabel(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: activeToday
                            ? AppTheme.accentColor
                            : AppTheme.getSecondaryText(context),
                      ),
                ),
              ),
              if (coupon)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.getAccentTint(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Coupon',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              if (groupLine.isNotEmpty)
                Text(
                  groupLine,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Week ${_pct(student['this_week_percent'])} · prev ${_pct(student['last_week_percent'])}'
            '  ·  Month ${_pct(student['this_month_percent'])} · prev ${_pct(student['last_month_percent'])}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
        ],
      ),
    );
  }
}

// ==================== CLASS FOLDER MODEL ====================

class ClassFolder {
  final String id;
  final String name;
  final String subject;
  final int studentCount;
  final String joinCode;
  final int pendingCount;
  final String joinApprovalMode;
  final String? classLevel;
  final String? exam;
  final String? language;

  ClassFolder({
    required this.id,
    required this.name,
    this.subject = '',
    required this.studentCount,
    required this.joinCode,
    this.pendingCount = 0,
    this.joinApprovalMode = 'auto',
    this.classLevel,
    this.exam,
    this.language,
  });
}

// ==================== SIMPLE JOIN DIALOG ====================

class SimpleJoinDialog extends StatefulWidget {
  const SimpleJoinDialog({super.key});

  @override
  State<SimpleJoinDialog> createState() => _SimpleJoinDialogState();
}

class _SimpleJoinDialogState extends State<SimpleJoinDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    if (_isLoading) return;
    final code = _codeController.text.trim().toUpperCase();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-character code';
      });
      return;
    }

    // Spinner set FIRST (before any await) so the button shows busy
    // feedback on the very first tap instead of sitting there doing
    // nothing while the group-limit check round-trips to the server —
    // that gap was making it look unresponsive and inviting a second tap.
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
    if (!eligibility.allowed) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showBuyPlanSheet(context, eligibility);
      return;
    }

    try {
      final result = await ClassService.instance.joinClassByCode(code);
      final status = (result['status'] as String?) ?? 'joined';

      if (mounted) {
        Navigator.pop(context, true);
        AppToast.showSnackBar(context,
          SnackBar(
            content: Text(
              status == 'pending'
                  ? 'Request sent — waiting for teacher approval'
                  : 'Successfully joined class!',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or expired join code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      title: const Text('Join a Class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the 6-character group code provided by your teacher',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              counterText: '',
              errorText: _errorMessage,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 120,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _joinClass,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Join Class'),
          ),
        ),
      ],
    );
  }
}

// ==================== HELPER FUNCTION ====================

/// Shows the SimpleJoinDialog as a bottom sheet
Future<bool?> showSimpleJoinDialog(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: const SimpleJoinDialog(),
    ),
  );
}

/// Redeem teacher coupon (first-month free group access; no extra credits).
Future<bool?> showRedeemCouponDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => const _RedeemCouponDialog(),
  );
}

class _RedeemCouponDialog extends StatefulWidget {
  const _RedeemCouponDialog();

  @override
  State<_RedeemCouponDialog> createState() => _RedeemCouponDialogState();
}

class _RedeemCouponDialogState extends State<_RedeemCouponDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter a valid coupon code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await CouponService.instance.redeemCoupon(code);
      if (!mounted) return;
      Navigator.pop(context, true);
      final classId = result['class_id'] as String?;
      AppToast.showSnackBar(context,
        SnackBar(
          content: Text(
            result['message'] as String? ??
                'Joined with coupon — first month free (no extra credits)',
          ),
        ),
      );
      if (classId != null && classId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          '/group_info',
          arguments: {'groupId': classId},
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redeem teacher coupon'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'First month free group access. '
            'Your Free 50 credits/month stay as-is — coupon does not add extra credits. '
            'Does not use your plan group limit.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Coupon code',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _redeem,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Redeem'),
        ),
      ],
    );
  }
}