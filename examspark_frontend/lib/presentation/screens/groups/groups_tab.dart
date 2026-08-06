import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/services/notification_service.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/teacher_dashboard_screen.dart'
    show showRedeemCouponDialog, showSimpleJoinDialog;
import 'package:examspark_frontend/presentation/screens/groups/teacher_discovery_screen.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/group_channel_row.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/core/services/open_workspace_bridge.dart';
import 'package:examspark_frontend/presentation/screens/search/search_overlay_screen.dart';

/// Groups tab — My Groups (channel list) + Discover (default Discover when zero joined).
class GroupsTab extends StatefulWidget {
  final ValueChanged<int> onGoToTab;
  final bool isActive;
  final VoidCallback? onOpenDrawer;

  const GroupsTab({
    super.key,
    required this.onGoToTab,
    this.isActive = true,
    this.onOpenDrawer,
  });

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab>
    with SingleTickerProviderStateMixin {
  List<GroupModel> _groups = [];
  Map<String, GroupUnreadInfo> _unread = {};
  bool _isLoading = true;
  int _lastMembershipsVersion = -1;
  late TabController _tabs;
  bool _defaultedDiscover = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _lastMembershipsVersion = SessionLiveSync.instance.membershipsVersion;
    SessionLiveSync.instance.addListener(_onSessionLive);
    _loadGroups();
  }

  @override
  void dispose() {
    SessionLiveSync.instance.removeListener(_onSessionLive);
    _tabs.dispose();
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
    final unread = await NotificationService.instance.unreadByClass();
    if (!mounted) return;
    final joined = groups.where((g) => g.isJoined).toList();
    setState(() {
      _groups = groups;
      _unread = unread;
      _isLoading = false;
    });
    if (!_defaultedDiscover && joined.isEmpty) {
      _defaultedDiscover = true;
      _tabs.index = 1; // Discover
    }
  }

  Future<void> _openGroupInfo(GroupModel group) async {
    await NotificationService.instance.markClassRead(group.id);
    if (!mounted) return;
    setState(() {
      _unread = Map<String, GroupUnreadInfo>.from(_unread)..remove(group.id);
    });
    await Navigator.pushNamed(
      context,
      '/group_info',
      arguments: {'groupId': group.id},
    );
    if (mounted) _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final joined = _groups.where((g) => g.isJoined).toList();

    return Scaffold(
      appBar: AppTopBar(
        title: 'Groups',
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Menu',
          onPressed: widget.onOpenDrawer,
        ),
        onSearchTap: () => showAppSearchOverlay(
          context,
          onOpenLecture: (id, title, subject) {
            OpenWorkspaceBridge.instance.open(
              lectureId: id,
              title: title,
              subject: subject,
              fullPage: true,
            );
          },
        ),
        trailing: [
          TextButton.icon(
            onPressed: () async {
              final ok = await showRedeemCouponDialog(context);
              if (ok == true) _loadGroups();
            },
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: const Text('Coupon'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor),
          ),
          TextButton.icon(
            onPressed: () async {
              final ok = await showSimpleJoinDialog(context);
              if (ok == true) _loadGroups();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Join'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.accentColor,
            tabs: const [
              Tab(text: 'My Groups'),
              Tab(text: 'Discover'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : joined.isEmpty
                        ? _buildEmptyState(context)
                        : RefreshIndicator(
                            onRefresh: _loadGroups,
                            child: ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                  child: Text(
                                    'Teacher posts only · no chat',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.getSecondaryText(
                                            context,
                                          ),
                                        ),
                                  ),
                                ),
                                for (final group in joined)
                                  GroupChannelRow(
                                    group: group,
                                    onTap: () => _openGroupInfo(group),
                                    unreadCount:
                                        _unread[group.id]?.count ?? 0,
                                    unreadPreview:
                                        _unread[group.id]?.lastPreview,
                                  ),
                              ],
                            ),
                          ),
                const TeacherDiscoveryScreen(embedded: true),
              ],
            ),
          ),
        ],
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Discover teachers or join with a code / coupon",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _tabs.animateTo(1),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Discover Teachers'),
          ),
        ],
      ),
    );
  }
}
