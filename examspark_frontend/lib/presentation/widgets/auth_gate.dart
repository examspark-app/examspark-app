import 'dart:async';
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/presentation/screens/auth/update_password_screen.dart';
import 'package:examspark_frontend/presentation/screens/home/guest_home_screen.dart';
import 'package:examspark_frontend/presentation/screens/onboarding/role_selection_screen.dart';
import 'package:examspark_frontend/presentation/screens/onboarding/student_onboarding_screen.dart';
import 'package:examspark_frontend/presentation/shell/app_shell.dart';

/// Routes to the guest chat preview, Login (pushed on top when the guest
/// tries a 2nd question or taps Sign In), the "set new password" screen,
/// the role-selection / student onboarding screens, or the 5-tab AppShell
/// based on Supabase auth session. Listens to [authStateChanges] so a
/// Google OAuth redirect (or a password-reset email link) is picked up
/// automatically when the user returns from the browser.
///
/// PRODUCT_VISION.md Core User Flow #1: "Anonymous try → One Ask AI →
/// Sign up → @username + Library" — [GuestHomeScreen] is that anonymous
/// try; it pushes [LoginScreen] itself once the free question is used.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isPasswordRecovery = false;
  StreamSubscription? _authSub;
  String? _cachedUserId;
  Future<Map<String, dynamic>?>? _profileFuture;
  bool _onboardingHandledLocally = false;
  bool _roleChosenAsStudent = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseClient.instance.isInitialized) {
      _authSub = SupabaseClient.instance.authStateChanges.listen((state) {
        if (SupabaseClient.instance.isPasswordRecoveryEvent(state) && mounted) {
          setState(() => _isPasswordRecovery = true);
        }
      });
    }
  }

  @override
  void dispose() {
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

    return StreamBuilder(
      stream: SupabaseClient.instance.authStateChanges,
      builder: (context, snapshot) {
        final session = SupabaseClient.instance.currentSession;
        if (session == null) {
          _cachedUserId = null;
          _onboardingHandledLocally = false;
          _roleChosenAsStudent = false;
          return const GuestHomeScreen();
        }

        final userId = session.user.id;
        if (_cachedUserId != userId) {
          _cachedUserId = userId;
          _onboardingHandledLocally = false;
          _roleChosenAsStudent = false;
          _profileFuture = SupabaseClient.instance.getUserProfile(userId);
        }

        if (_onboardingHandledLocally) {
          return const AppShell();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final profile = profileSnapshot.data;
            // Fail open into the app if the profile row/columns aren't
            // there yet (e.g. onboarding migration not run) instead of
            // blocking login.
            final onboardingCompleted = profile?['onboarding_completed'] as bool? ?? true;

            if (!onboardingCompleted) {
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

            return const AppShell();
          },
        );
      },
    );
  }
}
