import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/home_ask_bridge.dart';
import 'package:examspark_frontend/core/services/open_workspace_bridge.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/services/ui_session_store.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/theme/responsive.dart';
import 'package:examspark_frontend/presentation/screens/groups/groups_tab.dart';
import 'package:examspark_frontend/presentation/screens/home/home_tab.dart';
import 'package:examspark_frontend/presentation/screens/library/library_tab.dart';
import 'package:examspark_frontend/presentation/screens/profile/profile_tab.dart';
import 'package:examspark_frontend/presentation/screens/progress/progress_tab.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace.dart';
import 'package:examspark_frontend/core/services/home_session_bridge.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/presentation/widgets/brand_mark.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_entry.dart';
/// The 5-tab app shell — single navigation root after login.
/// Home · Library · Groups · Progress · Profile — nothing more.
///
/// Study Workspace UX (founder Jul 18, 2026):
///   - **Home (desktop):** right split panel (conversation + workspace)
///   - **Library:** full-page workspace (not a squeezed side panel)
///   - **Mobile:** bottom sheet everywhere
///
/// Founder Lock — Session Persistence: tab + open workspace survive minimize.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _WorkspaceRequest {
  final String lectureId;
  final String title;
  final String? subject;

  /// Library / full-page mode — replaces tab content, not a narrow rail panel.
  final bool fullPage;
  const _WorkspaceRequest(
    this.lectureId,
    this.title,
    this.subject, {
    this.fullPage = false,
  });
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static int _persistedTabIndex = 0;
  static _WorkspaceRequest? _persistedWorkspace;

  late int _selectedIndex;
  _WorkspaceRequest? _openWorkspace;
  bool _restoredFromDisk = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isTeacher = false;
  List<Map<String, dynamic>>? _recentSessions;
  bool _loadingSessions = false;

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      label: 'Library',
    ),
    (
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'Groups',
    ),
    (
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Progress',
    ),
    (
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = _persistedTabIndex.clamp(0, _destinations.length - 1);
    _openWorkspace = _persistedWorkspace;
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId != null) {
      SessionLiveSync.instance.start(userId);
      _loadTeacherFlag(userId);
    }
    _loadRecentSessions();
    HomeAskBridge.instance.addListener(_onHomeAskFromAnywhere);
    OpenWorkspaceBridge.instance.addListener(_onOpenWorkspaceFromBridge);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFromDisk());
  }

  Future<void> _restoreFromDisk() async {
    if (_restoredFromDisk || !mounted) return;
    _restoredFromDisk = true;
    final store = UiSessionStore.instance;
    final tab = await store.loadTabIndex();
    final ws = await store.loadWorkspace();
    if (!mounted) return;

    if (tab != null && tab != _selectedIndex) {
      setState(() {
        _selectedIndex = tab.clamp(0, _destinations.length - 1);
        _persistedTabIndex = _selectedIndex;
      });
    }

    if (ws != null) {
      final id = ws['lectureId'] as String?;
      final title = ws['title'] as String? ?? 'Lecture';
      final subject = ws['subject'] as String?;
      final fullPage = ws['fullPage'] as bool? ?? (_selectedIndex == 1);
      if (id != null && id.isNotEmpty) {
        final req = _WorkspaceRequest(id, title, subject, fullPage: fullPage);
        _persistedWorkspace = req;
        if (Responsive.useSideNav(context)) {
          final same =
              _openWorkspace?.lectureId == id &&
              _openWorkspace?.fullPage == fullPage;
          if (!same) {
            setState(() => _openWorkspace = req);
          }
        } else if (_openWorkspace?.lectureId != id) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!mounted) return;
          showStudyWorkspaceSheet(
            context,
            lectureId: id,
            title: title,
            subject: subject,
          );
        }
      }
    }
  }

  Future<void> _loadTeacherFlag(String userId) async {
    try {
      final profile = await SupabaseClient.instance.getUserProfile(userId);
      if (!mounted) return;
      setState(() => _isTeacher = profile?['role'] == 'teacher');
    } catch (_) {}
  }

  Future<void> _loadRecentSessions() async {
    if (_loadingSessions) return;
    setState(() => _loadingSessions = true);
    try {
      final sessions = await LectureService.instance.homeAiListSessions(limit: 15);
      if (!mounted) return;
      setState(() {
        _recentSessions = sessions;
        _loadingSessions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSessions = false);
    }
  }
Future<void> _renameSession(Map<String, dynamic> s) async {
    final id = s['id']?.toString();
    if (id == null || id.isEmpty) return;
    final controller = TextEditingController(
      text: (s['title'] as String?) ?? '',
    );
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Chat title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty) return;
    try {
      await LectureService.instance.homeAiRenameSession(id, newTitle);
      if (!mounted) return;
      setState(() => s['title'] = newTitle);
    } catch (_) {}
  }

  Future<void> _togglePinSession(Map<String, dynamic> s) async {
    final id = s['id']?.toString();
    if (id == null || id.isEmpty) return;
    final currentlyPinned = s['pinned'] == true;
    try {
      await LectureService.instance.homeAiPinSession(id, !currentlyPinned);
      if (!mounted) return;
      setState(() {
        s['pinned'] = !currentlyPinned;
        _recentSessions?.sort((a, b) {
          final ap = a['pinned'] == true ? 1 : 0;
          final bp = b['pinned'] == true ? 1 : 0;
          return bp.compareTo(ap);
        });
      });
    } catch (_) {}
  }

  Future<void> _deleteSession(Map<String, dynamic> s) async {
    final id = s['id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This chat will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _recentSessions?.remove(s));
    try {
      await LectureService.instance.homeAiDeleteSession(id);
    } catch (_) {}
  }

  void _showChatOptions(Map<String, dynamic> s) {
    final pinned = s['pinned'] == true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _renameSession(s);
              },
            ),
            ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(pinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePinSession(s);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteSession(s);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Widget _buildAppDrawer(BuildContext context) {
    final iconColor = AppTheme.getPrimaryText(context);
    return Drawer(
      width: 260,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: BrandMark(tileSize: 30, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _goToTab(0);
                    HomeSessionBridge.instance.requestNewChat();
                  },
                  icon: const Icon(Icons.add_comment_rounded, size: 16),
                  label: const Text('New chat', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.home_outlined, size: 20, color: iconColor),
                    title: const Text('Home', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _goToTab(0);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.record_voice_over_outlined, size: 20, color: iconColor),
                    title: const Text('English Practice', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EnglishPracticeEntry(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.folder_outlined, size: 20, color: iconColor),
                    title: const Text('Library', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _goToTab(1);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.groups_outlined, size: 20, color: iconColor),
                    title: const Text('Groups', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _goToTab(2);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.trending_up_rounded, size: 20, color: iconColor),
                    title: const Text('Progress', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _goToTab(3);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.person_outline, size: 20, color: iconColor),
                    title: const Text('Profile', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      _goToTab(4);
                    },
                  ),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(Icons.bolt_outlined, size: 20, color: iconColor),
                    title: Text(
                      'Credits — ${SessionLiveSync.instance.creditsBalance}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/credits/history');
                    },
                  ),
                  if (_isTeacher)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(Icons.school_rounded, size: 20, color: iconColor),
                      title: const Text('Teacher Dashboard', style: TextStyle(fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/teacher');
                      },
                    ),
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Text(
                      'RECENT CHATS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                  if (_loadingSessions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_recentSessions == null || _recentSessions!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'No chats yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                            ),
                      ),
                    )
                  else
                    for (final s in _recentSessions!)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Icon(
                          s['pinned'] == true
                              ? Icons.push_pin_rounded
                              : Icons.chat_bubble_outline,
                          size: 18,
                          color: iconColor,
                        ),
                        title: Text(
                          (s['title'] as String?)?.trim().isNotEmpty == true
                              ? s['title'] as String
                              : 'Untitled chat',
                          style: const TextStyle(fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.more_vert_rounded, size: 18, color: iconColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showChatOptions(s),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _goToTab(0);
                          final id = s['id']?.toString();
                          if (id != null && id.isNotEmpty) {
                            HomeSessionBridge.instance.requestRestoreSession(id);
                          }
                        },
                      ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 10),
              child: Text(
                'Sonaxia can make mistakes. Check important info.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 10.5,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistUiSession() async {
    final store = UiSessionStore.instance;
    await store.saveTabIndex(_selectedIndex);
    final ws = _openWorkspace ?? _persistedWorkspace;
    if (ws != null) {
      await store.saveWorkspace(
        lectureId: ws.lectureId,
        title: ws.title,
        subject: ws.subject,
        fullPage: ws.fullPage,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _persistUiSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomeAskBridge.instance.removeListener(_onHomeAskFromAnywhere);
    OpenWorkspaceBridge.instance.removeListener(_onOpenWorkspaceFromBridge);
    super.dispose();
  }

  void _onHomeAskFromAnywhere() {
    if (!mounted) return;
    // Leaving workspace for Home Ask — keep notes cached; close full-page overlay.
    if (_openWorkspace?.fullPage == true) {
      _closeStudyWorkspace();
    }
    if (_selectedIndex == 0) return;
    setState(() {
      _selectedIndex = 0;
      _persistedTabIndex = 0;
    });
    UiSessionStore.instance.saveTabIndex(0);
  }

  void _onOpenWorkspaceFromBridge() {
    if (!mounted) return;
    final req = OpenWorkspaceBridge.instance.takePending();
    if (req == null) return;
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
        _persistedTabIndex = 0;
      });
      UiSessionStore.instance.saveTabIndex(0);
    }
    _openStudyWorkspace(
      req.lectureId,
      req.title,
      req.subject,
      fullPage: req.fullPage,
    );
  }

  void _goToTab(int index) {
    // Same tab + full-page workspace → back to Library list (not squeeze panel).
    if (index == _selectedIndex && _openWorkspace?.fullPage == true) {
      _closeStudyWorkspace();
      return;
    }
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
      _persistedTabIndex = index;
      // Leaving this tab closes workspace (list/chat stay in IndexedStack).
      if (_openWorkspace != null) {
        _openWorkspace = null;
        _persistedWorkspace = null;
      }
    });
    UiSessionStore.instance.saveTabIndex(index);
    UiSessionStore.instance.clearWorkspace();
  }

  void _openStudyWorkspace(
    String lectureId,
    String title,
    String? subject, {
    bool fullPage = false,
  }) {
    // Library → always full page on desktop (founder UX).
    final useFullPage = fullPage || _selectedIndex == 1;
    final req = _WorkspaceRequest(
      lectureId,
      title,
      subject,
      fullPage: useFullPage,
    );
    _persistedWorkspace = req;
    UiSessionStore.instance.saveWorkspace(
      lectureId: lectureId,
      title: title,
      subject: subject,
      fullPage: useFullPage,
    );
    if (Responsive.useSideNav(context)) {
      setState(() => _openWorkspace = req);
    } else {
      showStudyWorkspaceFullScreen(
        context,
        lectureId: lectureId,
        title: title,
        subject: subject,
      ).then((_) {
        if (!mounted) return;
        if (_persistedWorkspace?.lectureId != lectureId) return;
        _persistedWorkspace = null;
        UiSessionStore.instance.clearWorkspace();
      });
    }
  }

  void _closeStudyWorkspace() {
    _persistedWorkspace = null;
    UiSessionStore.instance.clearWorkspace();
    setState(() => _openWorkspace = null);
  }

  List<Widget> _buildTabs() {
    return [
      HomeTab(
        key: const ValueKey('tab-home'),
        onOpenWorkspace: (id, title, subject) =>
            _openStudyWorkspace(id, title, subject, fullPage: false),
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 0,
        openLectureId: _openWorkspace?.lectureId,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      LibraryTab(
        key: const ValueKey('tab-library'),
        onOpenWorkspace: (id, title, subject) =>
            _openStudyWorkspace(id, title, subject, fullPage: true),
        isActive: _selectedIndex == 1,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      GroupsTab(
        key: const ValueKey('tab-groups'),
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 2,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      ProgressTab(
        key: const ValueKey('tab-progress'),
        isActive: _selectedIndex == 3,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      ProfileTab(
        key: const ValueKey('tab-profile'),
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 4,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goToTab(0);
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final tabs = _buildTabs();
    final stack = IndexedStack(index: _selectedIndex, children: tabs);
    final ws = _openWorkspace;
    final showFullPage =
        ws != null && ws.fullPage && Responsive.useSideNav(context);
    final showSidePanel =
        ws != null && !ws.fullPage && Responsive.useSideNav(context);

    final mainContent = showFullPage
        ? StudyWorkspace(
            key: ValueKey('ws-full-${ws.lectureId}'),
            lectureId: ws.lectureId,
            title: ws.title,
            subject: ws.subject,
            onClose: _closeStudyWorkspace,
          )
        : stack;

    if (Responsive.useSideNav(context)) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: _buildAppDrawer(context),
        onDrawerChanged: (isOpened) {
          if (isOpened) _loadRecentSessions();
        },
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _goToTab,
              labelType: NavigationRailLabelType.none,
              minWidth: 80,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              indicatorColor: AppTheme.getAccentTint(context),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                child: Text(
                  'Sonaxia',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Tooltip(
                      message: d.label,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Icon(
                          d.icon,
                          color: AppTheme.getSecondaryText(context),
                          size: 26,
                        ),
                      ),
                    ),
                    selectedIcon: Tooltip(
                      message: d.label,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Icon(
                          d.selectedIcon,
                          color: AppTheme.getPrimaryText(context),
                          size: 26,
                        ),
                      ),
                    ),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppTheme.getCardBorder(context),
            ),
            Expanded(child: mainContent),
            if (showSidePanel)
              StudyWorkspaceSidePanel(
                lectureId: ws.lectureId,
                title: ws.title,
                subject: ws.subject,
                onClose: _closeStudyWorkspace,
              ),
          ],
        ),
      );
    }

    // Mobile — drawer-only navigation (ChatGPT style). No bottom tab bar.
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(context),
      onDrawerChanged: (isOpened) {
        if (isOpened) _loadRecentSessions();
      },
      body: stack,
    );
  }
}