import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/notification_inbox_controller.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/services/web_browser_notify.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/legal/legal_center_screen.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';
import 'package:examspark_frontend/presentation/widgets/auth_gate.dart';

/// Profile → Settings (Phase 2 careful).
/// Notification prefs + desktop browser alerts. Theme/language = pending.
/// Delete account = always last on this screen too.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kNotifyStudy = 'settings_notify_study';
  static const _kNotifyGroups = 'settings_notify_groups';

  bool _loading = true;
  bool _notifyStudy = true;
  bool _notifyGroups = true;
  String _browserPerm = 'default';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var perm = 'default';
    if (kIsWeb) {
      perm = await browserNotifyPermission();
    }
    if (!mounted) return;
    setState(() {
      _notifyStudy = prefs.getBool(_kNotifyStudy) ?? true;
      _notifyGroups = prefs.getBool(_kNotifyGroups) ?? true;
      _browserPerm = perm;
      _loading = false;
    });
  }

  Future<void> _setBool(String key, bool value, void Function(bool) apply) async {
    apply(value);
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _enableDesktopAlerts() async {
    final result =
        await NotificationInboxController.instance.enableDesktopBrowserAlerts();
    if (!mounted) return;
    setState(() => _browserPerm = result);
    final msg = switch (result) {
      'granted' =>
        'Desktop alerts ON — works when Sonaxia tab is open and you switch to another page.',
      'denied' => 'Blocked — Chrome → site settings → Notifications → Allow.',
      'unsupported' => 'Desktop alerts are for Chrome web.',
      _ => 'Permission: $result',
    };
    AppToast.showSnackBar(context, SnackBar(content: Text(msg)));
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
                      'After that they are permanently deleted.',
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
                TextButton(
                  onPressed: typedOk ? () => Navigator.pop(ctx, true) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error,
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
      SessionLiveSync.instance.stop();
      await SupabaseClient.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: const AppTopBar(title: 'Settings'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Controls in-app bell + Chrome desktop tray (when Sonaxia tab stays open).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _card([
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Study updates'),
                    subtitle: const Text('Lecture ready, plan expiry'),
                    value: _notifyStudy,
                    activeThumbColor: AppTheme.accentColor,
                    onChanged: (v) => _setBool(
                      _kNotifyStudy,
                      v,
                      (x) => _notifyStudy = x,
                    ),
                  ),
                  Divider(height: 1, color: AppTheme.getCardBorder(context)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Group updates'),
                    subtitle: const Text('New shares & announcements'),
                    value: _notifyGroups,
                    activeThumbColor: AppTheme.accentColor,
                    onChanged: (v) => _setBool(
                      _kNotifyGroups,
                      v,
                      (x) => _notifyGroups = x,
                    ),
                  ),
                  if (kIsWeb) ...[
                    Divider(height: 1, color: AppTheme.getCardBorder(context)),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Desktop browser alerts'),
                      subtitle: Text(
                        _browserPerm == 'granted'
                            ? 'Allowed — tray popup when you leave this tab'
                            : 'Allow Chrome notifications for another-tab alerts',
                      ),
                      trailing: TextButton(
                        onPressed: _browserPerm == 'granted'
                            ? null
                            : _enableDesktopAlerts,
                        child: Text(
                          _browserPerm == 'granted' ? 'On' : 'Enable',
                        ),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 24),
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Theme / language / about — pending (say start settings extras).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _card([
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Theme'),
                    subtitle: const Text('Follows your phone / browser (system)'),
                    trailing: Icon(
                      Icons.brightness_auto,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                // ===== TASK 3 — Settings → Legal =====
                Text(
                  'Legal',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Privacy, Terms, and every other Sonaxia policy in one place.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _card([
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.gavel_outlined,
                      color: AppTheme.getSecondaryText(context),
                    ),
                    title: const Text('Legal Center'),
                    subtitle: const Text('Policies, Contact Us, About Sonaxia'),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.getSecondaryText(context),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LegalCenterScreen()),
                    ),
                  ),
                ]),
                const SizedBox(height: 32),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                _card([
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_forever_outlined, color: err),
                    title: Text(
                      'Delete account',
                      style: TextStyle(color: err, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Last option — 30-day recovery window',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(children: children),
    );
  }
}
