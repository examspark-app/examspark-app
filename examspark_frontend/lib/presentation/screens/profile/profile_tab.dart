import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/onboarding/student_onboarding_screen.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';
import 'package:examspark_frontend/presentation/widgets/profile_row.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';
import 'package:examspark_frontend/presentation/widgets/auth_gate.dart';

/// Profile tab. Rows: Edit profile (students) · Subscription · Credits ·
/// Library Size · Settings · Help · Logout · **Delete account (always last)** —
/// Teacher Dashboard row for teachers only (no “Become Teacher” for students).
class ProfileTab extends StatefulWidget {
  final ValueChanged<int> onGoToTab;
  final bool isActive;

  const ProfileTab({
    super.key,
    required this.onGoToTab,
    this.isActive = true,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _creditsBalance = 0;
  String _planId = 'free';
  String _userName = 'User';
  String _userEmail = '';
  int _libraryLectureCount = 0;
  // Defaults to showing the row until we know for sure — avoids hiding
  // Teacher Dashboard from an actual teacher just because the profile
  // fetch is still in flight or failed.
  bool _isTeacher = true;

  String get _planLabel {
    final def = SubscriptionPlans.byId(_planId);
    return def != null ? '${def.name} Plan' : 'Free Plan';
  }

  @override
  void initState() {
    super.initState();
    SessionLiveSync.instance.addListener(_onSessionLive);
    _load();
    _applySessionLive();
  }

  @override
  void dispose() {
    SessionLiveSync.instance.removeListener(_onSessionLive);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
      SessionLiveSync.instance.refreshAll();
    }
  }

  void _onSessionLive() {
    if (!mounted) return;
    _applySessionLive();
  }

  void _applySessionLive() {
    final sync = SessionLiveSync.instance;
    setState(() {
      _creditsBalance = sync.creditsBalance;
      _planId = sync.planId;
    });
  }

  Future<void> _load() async {
    final user = SupabaseClient.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await SupabaseClient.instance.getUserProfile(user.id);
      var plan = 'free';
      try {
        plan = await SupabaseClient.instance.getPlanTier(user.id);
      } catch (_) {}
      var lectureCount = 0;
      try {
        final lectures = await LectureService.instance.getLecturesForUser();
        lectureCount = lectures.length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _creditsBalance = profile?['credits_balance'] as int? ?? 0;
        _planId = plan;
        _userName = (profile?['username'] as String?)?.trim().isNotEmpty == true
            ? (profile!['username'] as String)
            : ((profile?['full_name'] as String?) ??
                (user.email?.split('@').first ?? 'User'));
        _userEmail = user.email ?? '';
        _isTeacher = (profile?['role'] as String?) == 'teacher';
        _libraryLectureCount = lectureCount;
      });
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _openStudentProfileEdit() async {
    final user = SupabaseClient.instance.currentUser;
    if (user == null) return;
    final nav = Navigator.of(context);
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => StudentOnboardingScreen(
          userId: user.id,
          isEditing: true,
          onDone: () {
            nav.pop();
            _load();
            if (!mounted) return;
            AppToast.showSnackBar(
              context,
              const SnackBar(content: Text('Profile saved')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            final typedOk =
                controller.text.trim().toUpperCase() == 'DELETE';
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              title: const Text('Delete account?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Library and data stay recoverable for 30 days. '
                      'After that they are permanently deleted. '
                      'Teachers: groups stop for you; students keep history until purge.',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type DELETE to confirm',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (_) => setDialog(() {}),
                      decoration: const InputDecoration(
                        hintText: 'DELETE',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: typedOk ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete account'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseClient.instance.requestAccountDelete();
      await SessionLiveSync.instance.stop();
      if (!mounted) return;
      // Remount AuthGate → AccountRecoveryScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access your lectures.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SessionLiveSync.instance.stop();
      await SupabaseClient.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  void _showPlaceholderSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 10),
              Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          Row(
            children: [
              InitialsAvatar(name: _userName, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                    if (_userEmail.isNotEmpty)
                      Text(_userEmail, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!_isTeacher) ...[
            _card([
              ProfileRow(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: _openStudentProfileEdit,
              ),
            ]),
            const SizedBox(height: 16),
          ],
          _card([
            ProfileRow(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscription',
              trailingText: _planLabel,
              onTap: () => Navigator.pushNamed(context, '/subscription'),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.bolt,
              label: 'Credits',
              trailingText: '$_creditsBalance',
              onTap: () => Navigator.pushNamed(context, '/credits/history'),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.folder_outlined,
              label: 'Library Size',
              trailingText: '$_libraryLectureCount',
              onTap: () => widget.onGoToTab(1),
            ),
          ]),
          if (_isTeacher) ...[
            const SizedBox(height: 16),
            _card([
              ProfileRow(
                icon: Icons.school_outlined,
                label: 'Teacher Dashboard',
                onTap: () => Navigator.pushNamed(context, '/teacher'),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          _card([
            ProfileRow(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.help_outline,
              label: 'Help',
              onTap: () => Navigator.pushNamed(context, '/help'),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.logout,
              label: 'Logout',
              iconColor: Theme.of(context).colorScheme.error,
              labelColor: Theme.of(context).colorScheme.error,
              onTap: _confirmLogout,
            ),
            _divider(context),
            // Always last row on Profile — every role.
            ProfileRow(
              icon: Icons.delete_forever_outlined,
              label: 'Delete account',
              iconColor: Theme.of(context).colorScheme.error,
              labelColor: Theme.of(context).colorScheme.error,
              onTap: _confirmDeleteAccount,
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(height: 1, color: AppTheme.getCardBorder(context));
  }
}
