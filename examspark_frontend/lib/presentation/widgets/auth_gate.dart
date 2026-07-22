import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/presentation/screens/auth/update_password_screen.dart';
import 'package:examspark_frontend/presentation/screens/home/guest_home_screen.dart';
import 'package:examspark_frontend/presentation/screens/onboarding/role_selection_screen.dart';
import 'package:examspark_frontend/presentation/screens/onboarding/student_onboarding_screen.dart';
import 'package:examspark_frontend/presentation/shell/app_shell.dart';

/// Routes guest / login / onboarding / AppShell from Supabase session.
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
  bool _roleChosenAsStudent = false;
  /// Snapshot used for build — not replaced on token refresh.
  bool _hasSession = false;
  /// Once true, never swap AppShell for a profile spinner again (minimize-safe).
  bool _shellReady = false;

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
          _roleChosenAsStudent = false;
          _profileFuture = SupabaseClient.instance.getUserProfile(userId);
        }
      });
    });
  }

  @override
  void dispose() {
    _signOutDebounce?.cancel();
    _authSub?.cancel();
    super.dispose();
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

    if (_onboardingHandledLocally) {
      _shellReady = true;
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
        final onboardingCompleted =
            profile?['onboarding_completed'] as bool? ?? true;

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
        return AppShell(key: ValueKey('shell-$userId'));
      },
    );
  }
}
