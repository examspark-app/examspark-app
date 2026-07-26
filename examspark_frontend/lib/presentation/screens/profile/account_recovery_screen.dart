import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Shown when `users.deleted_at` is set — Library kept until [purgeAfter].
class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({
    super.key,
    required this.purgeAfter,
    required this.onRecovered,
    required this.onSignedOut,
  });

  final DateTime? purgeAfter;
  final VoidCallback onRecovered;
  final VoidCallback onSignedOut;

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  bool _busy = false;

  String get _deadlineLabel {
    final d = widget.purgeAfter;
    if (d == null) return '30 days from delete request';
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$day/$m/$y';
  }

  Future<void> _recover() async {
    setState(() => _busy = true);
    try {
      await SupabaseClient.instance.recoverAccount();
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        const SnackBar(content: Text('Account recovered — welcome back')),
      );
      widget.onRecovered();
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            e.toString().contains('recovery_window_closed')
                ? 'Recovery window closed. Account data is scheduled for permanent delete.'
                : 'Could not recover: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await SupabaseClient.instance.signOut();
      widget.onSignedOut();
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Could not sign out: $e')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.delete_outline,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Account scheduled for delete',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your Library and account data are kept until $_deadlineLabel. '
                'Tap Recover to cancel delete and keep everything. '
                'After that date, data is permanently removed.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _recover,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Recover account'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Sign out'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
