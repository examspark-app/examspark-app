import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/router/app_navigation.dart';
import 'package:examspark_frontend/core/router/invite_deep_link.dart';
import 'package:examspark_frontend/core/services/fcm_push_service.dart';
import 'package:examspark_frontend/core/services/notification_inbox_controller.dart';
import 'package:examspark_frontend/core/services/pending_invite_store.dart';
import 'package:examspark_frontend/core/services/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/presentation/screens/auth/update_password_screen.dart';
import 'package:examspark_frontend/presentation/screens/home/guest_home_screen.dart';
import 'package:examspark_frontend/presentation/screens/legal/legal_consent_screen.dart';
import 'package:examspark_frontend/presentation/screens/onboarding/role_selection_screen.dart';
import 'package:examspark_frontend/presentation/screens/onboarding/student_onboarding_screen.dart';
import 'package:examspark_frontend/presentation/screens/profile/account_recovery_screen.dart';
import 'package:examspark_frontend/presentation/shell/app_shell.dart';

/// Routes guest / login / legal consent / onboarding / AppShell from
/// Supabase session.
///
/// Important: ignore [AuthChangeEvent.tokenRefreshed] for UI rebuilds.
/// On Chrome minimize/tab-switch Supabase refreshes the JWT often — rebuilding
/// [AppShell] was wiping Home chat, Library scroll, and Study Workspace
/// ("everything looks new" + jump back to Home).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isPasswordRecovery = false;
  StreamSubscription? _authSub;
  Timer? _signOutDebounce;
  String? _cachedUserId;
  Future<Map<String, dynamic>?>? _profileFuture;
  bool _onboardingHandledLocally = false;
  // Legal Consent (Task 2) — same "handled this session" pattern as
  // `_onboardingHandledLocally`, so accepting doesn't require refetching
  // the profile row to unblock AppShell.
  bool _legalHandledLocally = false;
  bool _roleChosenAsStudent = false;
  /// Snapshot used for build — not replaced on token refresh.
  bool _hasSession = false;
  /// Once true, never swap AppShell for a profile spinner again (minimize-safe).
  bool _shellReady = false;
  /// Invite link after Sign Up / Google — open group once shell is ready.
  bool _pendingInviteRouted = false;
  bool _updateCheckDone = false;

  @override
  void initState() {
    super.initState();
    if (!SupabaseClient.instance.isInitialized) return;

    _hasSession = SupabaseClient.instance.currentSession != null;
    final uid = SupabaseClient.instance.currentUser?.id;
    if (uid != null) {
      _cachedUserId = uid;
      _profileFuture = SupabaseClient.instance.getUserProfile(uid);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowUpdateDialog());
    _authSub = SupabaseClient.instance.authStateChanges.listen((state) {
      if (!mounted) return;

      if (SupabaseClient.instance.isPasswordRecoveryEvent(state)) {
        setState(() => _isPasswordRecovery = true);
        return;
      }

      // Auth noise on minimize / tab resume must NOT remount AppShell.
      if (state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        return;
      }

      final session = state.session ?? SupabaseClient.instance.currentSession;

      if (session == null) {
        // Brief null blips during web/mobile resume — keep AppShell mounted.
        // Founder Lock: Session Persistence — never flash GuestHome mid-session.
        _signOutDebounce?.cancel();
        _signOutDebounce = Timer(const Duration(milliseconds: 2500), () {
          if (!mounted) return;
          if (SupabaseClient.instance.currentSession != null) return;
          setState(() {
            _hasSession = false;
            _shellReady = false;
            _cachedUserId = null;
            _onboardingHandledLocally = false;
            _legalHandledLocally = false;
            _roleChosenAsStudent = false;
            _profileFuture = null;
          });
          SessionLiveSync.instance.stop();
        });
        return;
      }

      _signOutDebounce?.cancel();
      final userId = session.user.id;
      final userChanged = _cachedUserId != userId;
      final wasLoggedOut = !_hasSession;

      // Same logged-in user (Chrome minimize / tab resume often re-fires auth
      // events). Do NOT setState — rebuilding AuthGate was jumping UI back to
      // Home and wiping in-memory chat / tab position.
      if (!wasLoggedOut && !userChanged) {
        return;
      }

      setState(() {
        _hasSession = true;
        if (userChanged) {
          _cachedUserId = userId;
          _onboardingHandledLocally = false;
          _legalHandledLocally = false;
          _roleChosenAsStudent = false;
          _profileFuture = SupabaseClient.instance.getUserProfile(userId);
        }
      });
      // Register FCM token after login (phone). Start in-app + web desktop inbox.
      unawaited(FcmPushService.instance.registerTokenWithBackend());
      unawaited(NotificationInboxController.instance.start());
    });
  }

  @override
  void dispose() {
    _signOutDebounce?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  /// After founder SQL-deletes the user, JWT may still sit in Chrome.
  Future<void> _signOutStaleDeletedAccount() async {
    try {
      await SupabaseClient.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasSession = false;
      _shellReady = false;
      _cachedUserId = null;
      _onboardingHandledLocally = false;
      _legalHandledLocally = false;
      _roleChosenAsStudent = false;
      _profileFuture = null;
    });
    SessionLiveSync.instance.stop();
  }

  /// After Sign Up / Google / onboarding: open saved invite → group page.
  /// Skip when URL still has `/#/join/...` — [JoinInviteScreen] already owns that.
  Future<void> _maybeShowUpdateDialog() async {
    if (_updateCheckDone) return;
    _updateCheckDone = true;

    final info = await AppUpdateService.instance.checkForUpdate();
    if (info == null) return;

    BuildContext? ctx;
    for (var i = 0; i < 20; i++) {
      ctx = AppNavigation.key.currentContext;
      if (ctx != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (ctx == null || !ctx.mounted) return;

    showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(info['updateMessage'] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final uri = Uri.parse(AppUpdateService.playStoreUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _routePendingInviteIfNeeded() {
    if (_pendingInviteRouted) return;
    if (InviteDeepLink.joinCodeFromUri(Uri.base) != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _pendingInviteRouted) return;
      if (InviteDeepLink.joinCodeFromUri(Uri.base) != null) return;
      final code = await PendingInviteStore.peek();
      if (code == null) return;
      final nav = AppNavigation.key.currentState;
      if (nav == null) return;
      _pendingInviteRouted = true;
      nav.pushNamed('/join/$code');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseClient.instance.isInitialized) {
      return const GuestHomeScreen();
    }

    if (_isPasswordRecovery) {
      return UpdatePasswordScreen(
        onDone: () => setState(() => _isPasswordRecovery = false),
      );
    }

    if (!_hasSession) {
      return const GuestHomeScreen();
    }

    final userId = _cachedUserId ?? SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      return const GuestHomeScreen();
    }

    // Fast path once both gates are cleared this session — skips rebuilding
    // the FutureBuilder below (same shortcut the codebase already used for
    // onboarding alone; extended to also require legal consent).
    if (_onboardingHandledLocally && _legalHandledLocally) {
      _shellReady = true;
      _routePendingInviteIfNeeded();
      return AppShell(key: ValueKey('shell-$userId'));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        final waiting =
            profileSnapshot.connectionState != ConnectionState.done;
        // After shell once ready, never flash spinner (wipes chat / notes).
        if (waiting && !_shellReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = profileSnapshot.data;
        // SQL account delete / stale Chrome session: no public.users row → force logout
        // (otherwise app looks "logged in" or falls into guest Demo).
        if (!waiting && profile == null && !_shellReady) {
          unawaited(_signOutStaleDeletedAccount());
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Soft-delete (30-day recovery) — block AppShell until Recover.
        if (!waiting &&
            profile != null &&
            SupabaseClient.isAccountSoftDeleted(profile)) {
          _shellReady = false;
          return AccountRecoveryScreen(
            purgeAfter: SupabaseClient.parsePurgeAfter(profile),
            onRecovered: () {
              setState(() {
                _profileFuture =
                    SupabaseClient.instance.getUserProfile(userId);
                _onboardingHandledLocally = false;
                _shellReady = false;
              });
            },
            onSignedOut: () {
              setState(() {
                _hasSession = false;
                _shellReady = false;
                _cachedUserId = null;
                _profileFuture = null;
                _onboardingHandledLocally = false;
                _legalHandledLocally = false;
                _roleChosenAsStudent = false;
              });
              SessionLiveSync.instance.stop();
            },
          );
        }

        // `|| _legalHandledLocally` / `|| _onboardingHandledLocally`: once a
        // gate is accepted this session, trust the local flag immediately
        // instead of the (possibly stale, not-yet-refetched) cached profile
        // future — otherwise accepting one gate while the other is still
        // pending would re-show a screen the user just cleared.
        final legalAccepted = _legalHandledLocally ||
            (profile?['legal_accepted'] as bool? ?? false);
        final onboardingCompleted = _onboardingHandledLocally ||
            (profile?['onboarding_completed'] as bool? ?? true);

        // ===== TASK 2 — First Login Consent Screen =====
        // Runs before onboarding: new signups see this immediately after
        // Create Account, before role selection / Home. Existing users who
        // already accepted (`legal_accepted = true`) skip straight past.
        if (!legalAccepted && !_shellReady) {
          return LegalConsentScreen(
            userId: userId,
            onDone: () => setState(() => _legalHandledLocally = true),
          );
        }

        if (!onboardingCompleted && !_shellReady) {
          if (_roleChosenAsStudent) {
            return StudentOnboardingScreen(
              userId: userId,
              onDone: () => setState(() => _onboardingHandledLocally = true),
            );
          }
          return RoleSelectionScreen(
            userId: userId,
            onPickStudent: () => setState(() => _roleChosenAsStudent = true),
            onDone: () => setState(() => _onboardingHandledLocally = true),
          );
        }

        _shellReady = true;
        _routePendingInviteIfNeeded();
        return AppShell(key: ValueKey('shell-$userId'));
      },
    );
  }
}
