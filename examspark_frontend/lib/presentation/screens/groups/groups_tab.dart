import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/teacher_dashboard_screen.dart' show showSimpleJoinDialog;
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/buy_plan_sheet.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/group_card.dart';

/// Groups tab — Study Community list embedded in AppShell.
/// Same GroupsRepository + GroupCard as the standalone `/groups` route,
/// just without its own AppBar back arrow (bottom nav replaces it).
class GroupsTab extends StatefulWidget {
  final ValueChanged<int> onGoToTab;
  /// When Groups becomes visible again [IndexedStack], reload list.
  final bool isActive;

  const GroupsTab({
    super.key,
    required this.onGoToTab,
    this.isActive = true,
  });

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  List<GroupModel> _groups = [];
  bool _isLoading = true;
  String? _updatingGroupId;
  int _lastMembershipsVersion = -1;

  @override
  void initState() {
    super.initState();
    _lastMembershipsVersion = SessionLiveSync.instance.membershipsVersion;
    SessionLiveSync.instance.addListener(_onSessionLive);
    _loadGroups();
  }

  @override
  void dispose() {
    SessionLiveSync.instance.removeListener(_onSessionLive);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GroupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadGroups();
      SessionLiveSync.instance.refreshAll();
    }
  }

  void _onSessionLive() {
    if (!mounted) return;
    final v = SessionLiveSync.instance.membershipsVersion;
    if (v != _lastMembershipsVersion) {
      _lastMembershipsVersion = v;
      _loadGroups();
    }
  }

  Future<void> _loadGroups() async {
    final groups = await GroupsRepository.instance.fetchGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _toggleJoin(GroupModel group) async {
    // Guard + spinner set FIRST (before any await) so the button shows
    // busy feedback on the very first tap instead of sitting there doing
    // nothing while the group-limit check round-trips to the server —
    // that gap was making it look unresponsive and inviting a second tap.
    if (_updatingGroupId != null) return;
    setState(() => _updatingGroupId = group.id);

    // Only newly joining is gated by the plan's group limit — leaving is
    // always allowed.
    if (!group.isJoined) {
      final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
      if (!eligibility.allowed) {
        if (!mounted) return;
        setState(() => _updatingGroupId = null);
        showBuyPlanSheet(context, eligibility);
        return;
      }
    }

    final wasJoined = group.isJoined;
    try {
      final updated = await GroupsRepository.instance.toggleMembership(group);
      if (!mounted) return;
      setState(() {
        _groups = _groups.map((g) => g.id == updated.id ? updated : g).toList();
        _updatingGroupId = null;
      });
      if (!wasJoined && updated.isJoined) {
        _openGroupInfo(updated);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated.isJoined ? 'Joined "${updated.name}"' : 'Left "${updated.name}"')),
      );
    } on GroupMembershipException catch (e) {
      if (!mounted) return;
      setState(() => _updatingGroupId = null);
      if (!wasJoined) {
        final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
        if (!mounted) return;
        if (!eligibility.allowed || e.isJoinLimit) {
          showBuyPlanSheet(context, eligibility);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openGroupInfo(GroupModel group) {
    Navigator.pushNamed(context, '/group_info', arguments: {'groupId': group.id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Groups',
        trailing: [
          TextButton.icon(
            onPressed: () => showSimpleJoinDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Join'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.screenPadding),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GroupCard(
                          group: group,
                          onTap: () => _openGroupInfo(group),
                          onJoinToggle: () => _toggleJoin(group),
                          isUpdating: _updatingGroupId == group.id,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: AppTheme.getSecondaryText(context)),
          const SizedBox(height: 16),
          Text(
            'No groups yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.getSecondaryText(context)),
          ),
          const SizedBox(height: 8),
          Text("Join a teacher's study community to get started", style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => showSimpleJoinDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Join a Group'),
          ),
        ],
      ),
    );
  }
}
