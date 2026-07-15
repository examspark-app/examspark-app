import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
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
/// Responsive:
///   - Mobile/Tablet: bottom NavigationBar, Study Workspace opens as a
///     swipe-up bottom sheet.
///   - Desktop: side NavigationRail, Study Workspace opens as a persistent
///     right-side split panel next to the tab content.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _WorkspaceRequest {
  final String lectureId;
  final String title;
  final String? subject;
  const _WorkspaceRequest(this.lectureId, this.title, this.subject);
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  _WorkspaceRequest? _openWorkspace;

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.folder_outlined, selectedIcon: Icons.folder_rounded, label: 'Library'),
    (icon: Icons.groups_outlined, selectedIcon: Icons.groups_rounded, label: 'Groups'),
    (icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded, label: 'Progress'),
    (icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId != null) {
      SessionLiveSync.instance.start(userId);
    }
  }

  @override
  void dispose() {
    SessionLiveSync.instance.stop();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openStudyWorkspace(String lectureId, String title, String? subject) {
    if (Responsive.useSideNav(context)) {
      setState(() => _openWorkspace = _WorkspaceRequest(lectureId, title, subject));
    } else {
      showStudyWorkspaceSheet(context, lectureId: lectureId, title: title, subject: subject);
    }
  }

  void _closeStudyWorkspace() {
    setState(() => _openWorkspace = null);
  }

  List<Widget> _buildTabs() {
    return [
      HomeTab(
        onOpenWorkspace: _openStudyWorkspace,
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 0,
        openLectureId: _openWorkspace?.lectureId,
      ),
      LibraryTab(
        onOpenWorkspace: _openStudyWorkspace,
        isActive: _selectedIndex == 1,
      ),
      GroupsTab(
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 2,
      ),
      const ProgressTab(),
      ProfileTab(
        onGoToTab: _goToTab,
        isActive: _selectedIndex == 4,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();
    final content = IndexedStack(index: _selectedIndex, children: tabs);

    if (Responsive.useSideNav(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) {
                _goToTab(i);
                if (i != 0) _closeStudyWorkspace();
              },
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
                  child: const Text('E', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon, color: AppTheme.accentColor),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: AppTheme.getCardBorder(context)),
            Expanded(child: content),
            StudyWorkspaceSidePanel(
              lectureId: _openWorkspace?.lectureId,
              title: _openWorkspace?.title,
              subject: _openWorkspace?.subject,
              onClose: _closeStudyWorkspace,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
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
