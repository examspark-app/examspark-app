import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/router/app_navigation.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// First screen a brand-new user sees after signup — chooses Student or
/// Teacher. Student continues to [StudentOnboardingScreen] (profile
/// details). Teacher is routed straight to the Teacher Dashboard's
/// existing "Edit Teacher Profile" sheet — that flow already covers
/// profile creation, so it isn't duplicated here.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
    required this.userId,
    required this.onPickStudent,
    required this.onDone,
  });

  final String userId;

  /// Switches `AuthGate` to show the student profile-details screen next.
  final VoidCallback onPickStudent;

  /// Tells `AuthGate` onboarding is fully handled (teacher path / skip) so
  /// it moves straight to `AppShell`.
  final VoidCallback onDone;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _pickTeacher() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseClient.instance.chooseTeacherRole(widget.userId);
      widget.onDone();
      // AuthGate rebuilds into AppShell on the next frame — push the
      // Teacher Dashboard on top of it, with its edit sheet auto-opened.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNavigation.key.currentState?.pushNamed(
          '/teacher',
          arguments: {'openEdit': true},
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not continue as teacher: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skip() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseClient.instance.skipStudentOnboarding(widget.userId);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not skip: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _skip,
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'E',
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Who are you joining as?',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This decides what your account can do — you can\'t switch later without contacting support.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _RoleCard(
                    icon: Icons.school_outlined,
                    title: 'I\'m a Student',
                    subtitle: 'Record lectures, get notes, flashcards, quizzes & join teacher groups',
                    isLoading: _isLoading,
                    onTap: widget.onPickStudent,
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.co_present_outlined,
                    title: 'I\'m a Teacher',
                    subtitle: 'Create groups, share notes & lectures, manage students',
                    isLoading: _isLoading,
                    onTap: _pickTeacher,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          border: Border.all(color: AppTheme.getCardBorder(context)),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppTheme.getAccentTint(context), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, color: AppTheme.accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.getSecondaryText(context)),
          ],
        ),
      ),
    );
  }
}
