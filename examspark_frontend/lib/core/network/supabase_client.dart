import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Standardized Supabase client for authentication and Edge Function integration
class SupabaseClient {
  SupabaseClient._();

  static final SupabaseClient instance = SupabaseClient._();

  late final supabase.SupabaseClient _client;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_isInitialized) return;

    await supabase.Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    _client = supabase.Supabase.instance.client;
    _isInitialized = true;
  }

  supabase.SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('SupabaseClient not initialized. Call initialize() first.');
    }
    return _client;
  }

  supabase.User? get currentUser {
    if (!_isInitialized) return null;
    return client.auth.currentUser;
  }

  supabase.Session? get currentSession {
    if (!_isInitialized) return null;
    return client.auth.currentSession;
  }

  Stream<supabase.AuthState> get authStateChanges {
    if (!_isInitialized) {
      return const Stream<supabase.AuthState>.empty();
    }
    return client.auth.onAuthStateChange;
  }

  /// Google OAuth.
  /// Web: redirects the SAME browser tab to Google, then back — never opens
  /// a new tab (that was the earlier bug causing a "white page" on the old
  /// tab while a second tab reloaded the app from scratch).
  /// Mobile: opens the external browser/app, as required by OAuth on native.
  Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: _oauthRedirectUrl(),
      authScreenLaunchMode: kIsWeb
          ? supabase.LaunchMode.platformDefault
          : supabase.LaunchMode.externalApplication,
    );
  }

  String? _oauthRedirectUrl() {
    if (kIsWeb) return Uri.base.origin;
    return null;
  }

  Future<supabase.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<supabase.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Sends a "reset your password" email. Web: the link brings the user
  /// back to this app's origin, where [authStateChanges] fires a
  /// `passwordRecovery` event (handled in `AuthGate`) so they can set a
  /// new password without being dropped straight into the app.
  Future<void> resetPasswordForEmail(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: _oauthRedirectUrl(),
    );
  }

  /// Sets a new password. Valid right after `signInWithPassword`/
  /// `signUp`, or during an active password-recovery session
  /// (see [resetPasswordForEmail]).
  Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
  }

  /// Re-sends the signup verification email (e.g. "I didn't get the email").
  Future<void> resendSignUpEmail(String email) async {
    await client.auth.resend(type: supabase.OtpType.signup, email: email);
  }

  /// True when the latest auth event is a password-recovery link landing
  /// back in the app (from [resetPasswordForEmail]'s email link).
  bool isPasswordRecoveryEvent(supabase.AuthState state) {
    return state.event == supabase.AuthChangeEvent.passwordRecovery;
  }

  Future<Map<String, dynamic>> invokeEdgeFunction({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    final response = await client.functions.invoke(
      functionName,
      body: body,
    );

    if (response.status != 200) {
      throw Exception('Edge Function error: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return response;
  }

  /// Legacy direct update — kept only for backward compatibility, not called
  /// anywhere in the app. Blocked at the database layer as of Phase 4
  /// (`trg_protect_credits_balance` in schema.sql) unless run with the
  /// service-role key. Use [deductCredits] for all new code.
  @Deprecated('Use deductCredits(), which enforces server-side checks via fn_deduct_credits()')
  Future<void> updateCredits(String userId, int newBalance) async {
    await client
        .from('users')
        .update({'credits_balance': newBalance})
        .eq('id', userId);
  }

  /// Server-enforced credit deduction (CREDIT_ECONOMY.md: "Deduct credits
  /// server-side only"). Calls the `fn_deduct_credits` Postgres function
  /// (see `examspark_backend/schema.sql`), which atomically checks the
  /// balance, deducts it, and logs a `credit_transactions` row — throws if
  /// the balance is insufficient. Returns the new balance.
  Future<int> deductCredits({
    required String userId,
    required int amount,
    required String description,
    String? lectureId,
    String? action,
  }) async {
    final response = await client.rpc('fn_deduct_credits', params: {
      'p_user_id': userId,
      'p_amount': amount,
      'p_description': description,
      'p_lecture_id': lectureId,
      'p_action': action,
    });
    return response as int;
  }

  /// Reads the caller's current active plan tier via `fn_user_plan_tier`
  /// (defaults to `'free'`) — used for client soft-gating
  /// (`plan_tier_gating.dart`). FastAPI enforces the same Rule 6 server-side
  /// (Session 5 — 403 FEATURE_LOCKED).
  Future<String> getPlanTier(String userId) async {
    final response = await client.rpc('fn_user_plan_tier', params: {
      'p_user_id': userId,
    });
    return response as String? ?? 'free';
  }

  /// Display-only estimate of a teacher's recurring commission (30% of
  /// every attributed student's active paid plan — CREDIT_ECONOMY.md
  /// §Teacher Commission) via `fn_teacher_estimated_commission`. Returns
  /// rupees (not paise). No real payout — Phase 5.
  Future<double> getEstimatedCommission(String teacherUserId) async {
    final response = await client.rpc('fn_teacher_estimated_commission', params: {
      'p_teacher_id': teacherUserId,
    });
    if (response == null) return 0;
    return (response as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getCreditTransactions(String userId) async {
    final response = await client
        .from('credit_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Saves the student onboarding screen's answers: `username`/`avatar_color`
  /// go on `users`, `age`/`education_level`/`subjects` go on
  /// `student_profiles` (upsert — the row may not exist yet). Marks
  /// `onboarding_completed = true` on `users` so `AuthGate` stops showing
  /// the onboarding screen on future logins.
  Future<void> completeStudentOnboarding({
    required String userId,
    String? username,
    String? avatarColor,
    int? age,
    String? educationLevel,
    List<String> subjects = const [],
  }) async {
    await client.from('users').update({
      'username': ?username,
      'avatar_color': ?avatarColor,
      'onboarding_completed': true,
    }).eq('id', userId);

    await client.from('student_profiles').upsert({
      'user_id': userId,
      'age': age,
      'education_level': educationLevel,
      'subjects': subjects,
    }, onConflict: 'user_id');
  }

  /// "Skip for now" on the onboarding screen — just flips the gate flag so
  /// `AuthGate` sends the student straight into the app next time.
  Future<void> skipStudentOnboarding(String userId) async {
    await client.from('users').update({'onboarding_completed': true}).eq('id', userId);
  }

  /// "I'm a Teacher" on the role-selection screen. Every signup defaults to
  /// `role = 'student'` (see `auth_user_bootstrap.sql`) — this flips it to
  /// `'teacher'` and marks onboarding done, since teachers set up their
  /// profile from the Teacher Dashboard's "Edit Teacher Profile" sheet
  /// instead of the student onboarding form.
  Future<void> chooseTeacherRole(String userId) async {
    await client.from('users').update({
      'role': 'teacher',
      'onboarding_completed': true,
    }).eq('id', userId);
  }

  Stream<Map<String, dynamic>> userProfileStream(String userId) {
    return client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((event) => event.first);
  }
}
