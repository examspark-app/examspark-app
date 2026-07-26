import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/group_invite_qr_sheet.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/edit_study_group_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Per-group teacher dashboard (Create Group v4 + Analytics v1).
/// Members · Pending · Invite/QR · Analytics summary · activity · Assignments stub.
class GroupDashboardScreen extends StatefulWidget {
  final String classId;
  final String name;
  final String joinCode;
  final String subject;
  final String joinApprovalMode;

  const GroupDashboardScreen({
    super.key,
    required this.classId,
    required this.name,
    required this.joinCode,
    this.subject = '',
    this.joinApprovalMode = 'auto',
  });

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  bool _loading = true;
  /// Analytics v3 — quiz % / active summary window.
  bool _windowIsWeek = true;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pending = [];
  Map<String, int> _sharedCounts = {};
  Map<String, dynamic>? _topLectureAll;
  Map<String, dynamic>? _topLectureWeek;
  Map<String, dynamic>? _topLectureMonth;
  late String _joinApprovalMode;
  late String _name;
  late String _subject;

  @override
  void initState() {
    super.initState();
    _joinApprovalMode = widget.joinApprovalMode;
    _name = widget.name;
    _subject = widget.subject;
    _load();
  }

  Future<void> _openEdit() async {
    final edited = await showEditStudyGroupSheet(
      context,
      classId: widget.classId,
    );
    if (!mounted || edited == null) return;
    setState(() {
      _name = edited.name;
      _subject = edited.subject;
      _joinApprovalMode = edited.joinApprovalMode;
    });
    AppToast.show(
      'Group updated',
      isError: false,
      context: context,
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> members = [];
      Map<String, dynamic>? topAll;
      Map<String, dynamic>? topWeek;
      Map<String, dynamic>? topMonth;

      try {
        final payload = await ClassService.instance
            .fetchGroupStudentsPayload(widget.classId);
        final list = payload['students'];
        if (list is List) {
          members = list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            m['users'] = {'username': m['username']};
            return m;
          }).toList();
        }
        topAll = _asMap(payload['top_lecture']);
        topWeek = _asMap(payload['top_lecture_week']);
        topMonth = _asMap(payload['top_lecture_month']);
      } catch (_) {
        members =
            await ClassService.instance.listClassMembers(widget.classId);
      }

      final pending =
          await ClassService.instance.listPendingJoinRequests(widget.classId);
      final counts =
          await ClassService.instance.sharedItemCounts(widget.classId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _pending = pending;
        _sharedCounts = counts;
        _topLectureAll = topAll;
        _topLectureWeek = topWeek;
        _topLectureMonth = topMonth;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showSnackBar(context, 
        SnackBar(content: Text('Could not load group: $e')),
      );
    }
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  Map<String, dynamic>? get _topLectureForWindow {
    final windowed = _windowIsWeek ? _topLectureWeek : _topLectureMonth;
    return windowed ?? _topLectureAll;
  }

  int get _activeToday =>
      _members.where((m) => m['active_today'] == true).length;

  int get _activeInWindow {
    if (_windowIsWeek) {
      return _members.where((m) {
        if (m['active_this_week'] == true) return true;
        // Fallback if API older / Supabase-only path
        return _lastActiveInDays(m, 7);
      }).length;
    }
    return _members.where((m) {
      if (m['active_this_month'] == true) return true;
      return _lastActiveInCalendarMonth(m);
    }).length;
  }

  bool _lastActiveInDays(Map<String, dynamic> row, int days) {
    final raw = row['last_active_at'] as String?;
    if (raw == null) return false;
    final last = DateTime.tryParse(raw)?.toUtc();
    if (last == null) return false;
    return !last.isBefore(
      DateTime.now().toUtc().subtract(Duration(days: days)),
    );
  }

  bool _lastActiveInCalendarMonth(Map<String, dynamic> row) {
    final raw = row['last_active_at'] as String?;
    if (raw == null) return false;
    final last = DateTime.tryParse(raw)?.toLocal();
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year && last.month == now.month;
  }

  String _windowQuizPct(Map<String, dynamic> row) {
    final key =
        _windowIsWeek ? 'this_week_percent' : 'this_month_percent';
    final v = row[key] ?? row['overall_percent'];
    if (v is num) return '${v.round()}%';
    return '—';
  }

  String? _windowAvgQuizPct() {
    final key =
        _windowIsWeek ? 'this_week_percent' : 'this_month_percent';
    final vals = <double>[];
    for (final m in _members) {
      final v = m[key] ?? m['overall_percent'];
      if (v is num) vals.add(v.toDouble());
    }
    if (vals.isEmpty) return null;
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    return '${avg.round()}%';
  }

  String _studentLabel(Map<String, dynamic> row) {
    final direct = (row['username'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final user = row['users'];
    if (user is Map) {
      final username = (user['username'] as String?)?.trim();
      if (username != null && username.isNotEmpty) return username;
      final full = (user['full_name'] as String?)?.trim();
      if (full != null && full.isNotEmpty) return full;
      final email = (user['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) return email;
    }
    return 'Student';
  }

  String _lastActiveLabel(Map<String, dynamic> row) {
    if (row['active_today'] == true) return 'Active today';
    final raw = row['last_active_at'] as String?;
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

  void _copyInvite() {
    final link = AppBrand.inviteJoinUrl(widget.joinCode);
    Clipboard.setData(ClipboardData(text: link));
    AppToast.showSnackBar(context, 
      SnackBar(content: Text('Invite link copied: $link')),
    );
  }

  void _showQr() {
    showGroupInviteQrSheet(
      context,
      invite: GroupInviteQrData.fromCode(
        groupName: _name,
        joinCode: widget.joinCode,
      ),
    );
  }

  Future<void> _accept(String requestId) async {
    try {
      await ClassService.instance.acceptJoinRequest(requestId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(context, 
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  Future<void> _reject(String requestId) async {
    try {
      await ClassService.instance.rejectJoinRequest(requestId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(context, 
        SnackBar(content: Text('Reject failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTheme.getSecondaryText(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            tooltip: 'Edit group',
            onPressed: _loading ? null : _openEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                children: [
                  Text(
                    _subject.isEmpty
                        ? 'Study Group dashboard — not a chat'
                        : '$_subject · Study Group dashboard — not a chat',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _joinApprovalMode == 'approval'
                        ? 'Join: Approve (Free → Pending; paid skip)'
                        : 'Join: Auto (default)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit group'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _metricRow(context),
                  const SizedBox(height: 16),
                  _inviteCard(context),
                  const SizedBox(height: 16),
                  _analyticsV1Card(context),
                  const SizedBox(height: 16),
                  _stubCards(context),
                  const SizedBox(height: 20),
                  _sectionTitle(context, 'Pending requests'),
                  const SizedBox(height: 8),
                  if (_pending.isEmpty)
                    Text(
                      'No pending requests',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: secondary),
                    )
                  else
                    ..._pending.map(_pendingTile),
                  const SizedBox(height: 20),
                  _sectionTitle(
                    context,
                    'Members (${_members.length})',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active today: $_activeToday / ${_members.length}  ·  '
                    'Quiz % = ${_windowIsWeek ? 'this week' : 'this month'} '
                    '(shared lectures)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_members.isEmpty)
                    Text(
                      'No students joined yet — share invite code or QR.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: secondary),
                    )
                  else
                    ..._members.map(_memberTile),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/group_info',
                          arguments: {'groupId': widget.classId},
                        );
                      },
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Open group feed'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
    );
  }

  Widget _metricRow(BuildContext context) {
    final cards = [
      _MiniMetric(
        label: 'Members',
        value: '${_members.length}',
        icon: Icons.people_outline,
      ),
      _MiniMetric(
        label: 'Active today',
        value: '$_activeToday',
        icon: Icons.sensors,
      ),
      _MiniMetric(
        label: 'Pending',
        value: '${_pending.length}',
        icon: Icons.how_to_reg_outlined,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _inviteCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            'Code: ${widget.joinCode}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyInvite,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showQr,
                  icon: const Icon(Icons.qr_code_2, size: 16),
                  label: const Text('QR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Analytics v1+v3 — live counts + Week/Month window for active + avg quiz %.
  Widget _analyticsV1Card(BuildContext context) {
    final notes = _sharedCounts['notes'] ?? 0;
    final quiz = _sharedCounts['quiz'] ?? 0;
    final secondary = AppTheme.getSecondaryText(context);
    final windowLabel = _windowIsWeek ? 'This week' : 'This month';
    final avgQuiz = _windowAvgQuizPct() ?? '—';
    final tiles = [
      _MiniMetric(
        label: 'Members',
        value: '${_members.length}',
        icon: Icons.people_outline,
      ),
      _MiniMetric(
        label: 'Active ($windowLabel)',
        value: '$_activeInWindow',
        icon: Icons.sensors,
      ),
      _MiniMetric(
        label: 'Avg quiz ($windowLabel)',
        value: avgQuiz,
        icon: Icons.percent,
      ),
      _MiniMetric(
        label: 'Shared (notes · quiz)',
        value: '$notes · $quiz',
        icon: Icons.share_outlined,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 18, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: true, label: Text('Week')),
                  ButtonSegment<bool>(value: false, label: Text('Month')),
                ],
                selected: {_windowIsWeek},
                onSelectionChanged: (s) {
                  setState(() => _windowIsWeek = s.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This group · $windowLabel (shared lectures quiz %)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: secondary,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 8),
              Expanded(child: tiles[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: 8),
              Expanded(child: tiles[3]),
            ],
          ),
          const SizedBox(height: 12),
          _topLectureRow(context, secondary),
        ],
      ),
    );
  }

  Widget _topLectureRow(BuildContext context, Color secondary) {
    final top = _topLectureForWindow;
    final title = (top?['title'] as String?)?.trim();
    final attempts = top?['attempt_count'];
    final unique = top?['unique_students'];
    final hasTop = title != null && title.isNotEmpty && attempts is num;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top lecture (${_windowIsWeek ? 'this week' : 'this month'})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            hasTop ? title : 'No quiz attempts yet on shared lectures',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            hasTop
                ? '$attempts attempts · $unique students'
                    '  ·  by quiz attempts (not open-count yet)'
                : 'Share a quiz → students attempt → title appears here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: secondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _stubCards(BuildContext context) {
    final lecture = _sharedCounts['lecture'] ?? 0;
    final announcement = _sharedCounts['announcement'] ?? 0;
    final stubs = [
      (
        'Lectures shared',
        lecture > 0 ? '$lecture' : '0',
        lecture == 0,
        Icons.menu_book_outlined,
      ),
      (
        'Announcements',
        announcement > 0 ? '$announcement' : '0',
        announcement == 0,
        Icons.campaign_outlined,
      ),
      (
        'Assignments',
        'Soon',
        true,
        Icons.assignment_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Group activity'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.55,
              children: [
                for (final s in stubs)
                  _StubCard(
                    label: s.$1,
                    value: s.$2,
                    placeholder: s.$3 && s.$2 == 'Soon',
                    icon: s.$4,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _pendingTile(Map<String, dynamic> row) {
    final reqId = row['id'] as String;
    final name = _studentLabel(row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.getCardBorder(context)),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => _reject(reqId),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () => _accept(reqId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(Map<String, dynamic> row) {
    final name = _studentLabel(row);
    final active = row['active_today'] == true;
    final coupon = row['joined_via_coupon'] == true;
    final secondary = AppTheme.getSecondaryText(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          border: Border.all(
            color: active
                ? AppTheme.accentColor.withValues(alpha: 0.45)
                : AppTheme.getCardBorder(context),
          ),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.getAccentTint(context),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (coupon) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Coupon',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lastActiveLabel(row),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: active ? AppTheme.accentColor : secondary,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              _windowQuizPct(row),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.accentColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _StubCard extends StatelessWidget {
  final String label;
  final String value;
  final bool placeholder;
  final IconData icon;

  const _StubCard({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: placeholder
                ? AppTheme.getSecondaryText(context)
                : AppTheme.accentColor,
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: placeholder
                      ? AppTheme.getSecondaryText(context)
                      : null,
                ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
        ],
      ),
    );
  }
}
