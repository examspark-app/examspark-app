import 'dart:async';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/services/pending_invite_store.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/buy_plan_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Deep link `/join/{code}` — create/sign-in if needed, then teacher group page.
class JoinInviteScreen extends StatefulWidget {
  final String joinCode;

  const JoinInviteScreen({super.key, required this.joinCode});

  @override
  State<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends State<JoinInviteScreen> {
  String? _error;
  bool _busy = true;
  String _status = 'Opening your teacher’s group…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final code = widget.joinCode.trim().toUpperCase();
    if (code.length < 4) {
      setState(() {
        _busy = false;
        _error = 'Invalid invite link';
      });
      return;
    }

    await PendingInviteStore.save(code);

    if (SupabaseClient.instance.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _busy = true;
        _status = 'Create an account (or sign in) to open this group…';
      });
      // New students: Sign Up tab first. After account → continue here.
      await Navigator.of(context).pushNamed(
        '/login',
        arguments: {
          'startInSignUp': true,
          'inviteJoinHint': true,
        },
      );
      if (!mounted) return;

      if (SupabaseClient.instance.currentUser == null) {
        // User may still be verifying email — wait briefly for session.
        setState(() => _status = 'Waiting for sign-in…');
        final signedIn = await _waitForSession(
          timeout: const Duration(minutes: 2),
        );
        if (!mounted) return;
        if (!signedIn) {
          setState(() {
            _busy = false;
            _error =
                'Create a free account or sign in, then tap Try again to open the group.';
          });
          return;
        }
      }
    }

    try {
      setState(() {
        _busy = true;
        _status = 'Opening your teacher’s group…';
      });

      final folder = await ClassService.instance.findClassByJoinCode(code);
      if (folder == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Group not found for this invite code';
        });
        return;
      }

      final classId = folder['id'] as String;
      final teacherId = folder['teacher_id'] as String?;
      final userIdNow = SupabaseClient.instance.currentUser?.id;

      if (userIdNow != null &&
          teacherId != null &&
          teacherId == userIdNow) {
        if (!mounted) return;
        await PendingInviteStore.clear();
        Navigator.of(context).pushReplacementNamed(
          '/group_dashboard',
          arguments: {
            'classId': classId,
            'name': folder['name'] as String? ?? 'Study Group',
            'joinCode': code,
            'subject': folder['subject'] as String? ?? '',
            'joinApprovalMode':
                (folder['join_approval_mode'] as String?) ?? 'auto',
          },
        );
        return;
      }

      final already = await ClassService.instance.isMemberOfClass(classId);

      if (!already) {
        final eligibility =
            await GroupsRepository.instance.canJoinAnotherGroup();
        if (!eligibility.allowed) {
          if (!mounted) return;
          setState(() => _busy = false);
          await showBuyPlanSheet(context, eligibility);
          return;
        }

        final result = await ClassService.instance.joinClassByCode(code);
        final status = (result['status'] as String?) ?? 'joined';
        if (!mounted) return;
        if (status == 'pending') {
          AppToast.show(
            'Request sent — waiting for teacher approval',
            isError: false,
            context: context,
          );
        }
      }

      if (!mounted) return;
      await PendingInviteStore.clear();
      Navigator.of(context).pushReplacementNamed(
        '/group_info',
        arguments: {'groupId': classId},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Covers: Sign Up → verify email → come back and Sign In on login screen.
  Future<bool> _waitForSession({required Duration timeout}) async {
    if (SupabaseClient.instance.currentUser != null) return true;
    if (!SupabaseClient.instance.isInitialized) return false;

    final done = Completer<bool>();
    late final StreamSubscription sub;
    Timer? timer;

    void finish(bool ok) {
      if (done.isCompleted) return;
      timer?.cancel();
      sub.cancel();
      done.complete(ok);
    }

    sub = SupabaseClient.instance.authStateChanges.listen((_) {
      if (SupabaseClient.instance.currentUser != null) {
        finish(true);
      }
    });
    timer = Timer(timeout, () => finish(false));

    // Also poll — some web auth paths update session without a loud event.
    while (!done.isCompleted) {
      if (SupabaseClient.instance.currentUser != null) {
        finish(true);
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join group'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: _busy
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_off,
                      size: 48,
                      color: AppTheme.getSecondaryText(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'Could not open group',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _busy = true;
                          _error = null;
                          _status = 'Opening your teacher’s group…';
                        });
                        _run();
                      },
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/home'),
                      child: const Text('Go to Home'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
