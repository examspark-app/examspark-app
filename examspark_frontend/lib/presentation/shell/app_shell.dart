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
    }
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
      showStudyWorkspaceSheet(
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
      ),
      LibraryTab(
        key: const ValueKey('tab-library'),
        onOpenWorkspace: (id, title, subject) =>
            _openStudyWorkspace(id, title, subject, fullPage: true),
        isActive: _selectedIndex == 1,
      ),
      GroupsTab(
        key: const ValueKey('tab-groups'),
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 2,
      ),
      ProgressTab(
        key: const ValueKey('tab-progress'),
        isActive: _selectedIndex == 3,
      ),
      ProfileTab(
        key: const ValueKey('tab-profile'),
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 4,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _goToTab,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              indicatorColor: AppTheme.getAccentTint(context),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'E',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(
                      d.selectedIcon,
                      color: AppTheme.accentColor,
                    ),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: AppTheme.getCardBorder(context)),
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

    return Scaffold(
      body: stack,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goToTab,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        indicatorColor: AppTheme.getAccentTint(context),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon, color: AppTheme.accentColor),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
