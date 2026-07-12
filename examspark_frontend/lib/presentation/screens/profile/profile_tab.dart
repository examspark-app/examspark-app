import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';
import 'package:examspark_frontend/presentation/widgets/profile_row.dart';
import 'package:examspark_frontend/presentation/widgets/auth_gate.dart';

/// Profile tab. Rows: Subscription · Credits · Storage · Library Size ·
/// Settings · Help · Logout — Teacher Dashboard row for teachers.
/// Per UX rule: Settings/Subscription/Teacher Dashboard all live under
/// Profile — never separate bottom tabs.
class ProfileTab extends StatefulWidget {
  final ValueChanged<int> onGoToTab;

  const ProfileTab({super.key, required this.onGoToTab});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _creditsBalance = 0;
  String _userName = 'User';
  String _userEmail = '';
  // Defaults to showing the row until we know for sure — avoids hiding
  // Teacher Dashboard from an actual teacher just because the profile
  // fetch is still in flight or failed.
  bool _isTeacher = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = SupabaseClient.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await SupabaseClient.instance.getUserProfile(user.id);
      if (!mounted) return;
      setState(() {
        _creditsBalance = profile?['credits_balance'] as int? ?? 0;
        _userName = (profile?['full_name'] as String?) ?? (user.email?.split('@').first ?? 'User');
        _userEmail = user.email ?? '';
        _isTeacher = (profile?['role'] as String?) == 'teacher';
      });
    } catch (_) {
      // Non-fatal.
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
          _card([
            ProfileRow(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscription',
              trailingText: 'Free Plan',
              onTap: () => Navigator.pushNamed(context, '/subscription'),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.bolt,
              label: 'Credits',
              trailingText: '$_creditsBalance',
              onTap: () => Navigator.pushNamed(context, '/subscription'),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.cloud_outlined,
              label: 'Storage',
              trailingText: '128 MB',
              onTap: () => _showPlaceholderSheet(
                'Storage',
                'You are using a placeholder storage estimate. Real usage syncs once Cloudflare R2 storage is wired (Phase 4/5).',
              ),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.folder_outlined,
              label: 'Library Size',
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
              onTap: () => _showPlaceholderSheet('Settings', 'Theme, notifications and account settings are coming soon.'),
            ),
            _divider(context),
            ProfileRow(
              icon: Icons.help_outline,
              label: 'Help',
              onTap: () => _showPlaceholderSheet('Help & Support', 'Need help? Support chat and FAQs are coming soon.'),
            ),
          ]),
          const SizedBox(height: 16),
          _card([
            ProfileRow(
              icon: Icons.logout,
              label: 'Logout',
              iconColor: Theme.of(context).colorScheme.error,
              labelColor: Theme.of(context).colorScheme.error,
              onTap: _confirmLogout,
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
