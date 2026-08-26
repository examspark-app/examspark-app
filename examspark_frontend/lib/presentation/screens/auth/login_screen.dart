import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/legal_urls.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/pending_referral_store.dart';
import 'package:examspark_frontend/core/services/device_identifier.dart';
import 'package:examspark_frontend/presentation/screens/auth/email_verification_screen.dart';
import 'package:examspark_frontend/presentation/screens/auth/reset_password_screen.dart';
import 'package:examspark_frontend/presentation/screens/legal/legal_webview_screen.dart';
import 'package:examspark_frontend/presentation/widgets/brand_mark.dart';
import 'package:examspark_frontend/presentation/widgets/google_logo.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

enum _AuthMode { login, signUp }

/// Secure entry portal. One screen, two clear modes (Login / Sign Up)
/// switched with a segmented toggle — old users and new users each get an
/// unambiguous primary action, plus Google sign-in and password reset.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.startInSignUp = false,
    this.inviteJoinHint = false,
  });

  /// Opens straight on the "Sign Up" tab — used when pushed from
  /// [GuestHomeScreen]'s "Create Free Account" prompt so the user doesn't
  /// have to tap the toggle themselves.
  final bool startInSignUp;

  /// Invite deep link: show “create account to open group” under the title.
  final bool inviteJoinHint;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  late _AuthMode _mode;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late final TapGestureRecognizer _switchModeRecognizer;
  // Task 1 — Signup Consent: tap recognizers for the "Terms & Conditions"
  // and "Privacy Policy" links shown below the Create Account button.
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInSignUp ? _AuthMode.signUp : _AuthMode.login;
    _switchModeRecognizer = TapGestureRecognizer()
      ..onTap = () => _switchMode(
        _mode == _AuthMode.login ? _AuthMode.signUp : _AuthMode.login,
      );
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () =>
          _openLegalDoc('Terms & Conditions', LegalUrls.termsAndConditions);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegalDoc('Privacy Policy', LegalUrls.privacyPolicy);
    PendingReferralStore.peek().then((code) {
      if (mounted && code != null && _mode == _AuthMode.signUp) {
        _referralController.text = code;
      }
    });
  }

  /// When this screen was pushed on top of something else (e.g.
  /// `GuestHomeScreen`) rather than being `AuthGate`'s current root
  /// content, pop it after a successful login/signup so the root's now-
  /// updated content (onboarding / AppShell) becomes visible again.
  void _popIfPushed() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _switchModeRecognizer.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_mode == mode || _isLoading) return;
    setState(() => _mode = mode);
  }

  // Task 1 — opens Terms & Conditions / Privacy Policy inside the in-app
  // WebView (Task 4). Never opens an external browser, except on Web
  // platform, where `LegalWebViewScreen` itself opens a new tab.
  void _openLegalDoc(String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalWebViewScreen(title: title, url: url),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseClient.instance.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        // AuthGate listens to authStateChanges and shows AppShell automatically.
        _popIfPushed();
      }
    } catch (e) {
      if (mounted) {
        final errorText = e.toString().toLowerCase();
        final isInvalidCredentials =
            errorText.contains('invalid_credentials') ||
            errorText.contains('invalid login credentials');
        AppToast.showSnackBar(
          context,
          SnackBar(
            content: Text(
              isInvalidCredentials
                  ? 'Incorrect email or password. Please check your credentials and try again.'
                  : 'Login failed. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    try {
      final deviceId = await getDeviceIdentifier();
      if (deviceId != null &&
          !await LectureService.instance.checkDeviceAccountLimit(deviceId)) {
        throw StateError('Maximum accounts reached for this device.');
      }
      final response = await SupabaseClient.instance.signUpWithEmail(
        email: email,
        password: _passwordController.text,
        referralCode: _referralController.text,
      );

      if (mounted) {
        if (response.session != null &&
            _referralController.text.trim().isNotEmpty) {
          try {
            await LectureService.instance.redeemReferral(
              _referralController.text.trim(),
            );
            await PendingReferralStore.clear();
          } catch (_) {
            // Referral redemption is non-blocking for account creation.
          }
        }
        if (response.session != null) {
          final deviceId = await getDeviceIdentifier();
          if (deviceId != null) {
            try {
              await LectureService.instance.registerDeviceAccount(deviceId);
            } catch (_) {}
          }
        }
        if (response.session == null) {
          // Email confirmation required — no session yet. Take the user to
          // a real confirmation page instead of a snackbar they can miss.
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(email: email),
            ),
          );
        } else {
          // Session came back immediately (email confirmations off in
          // Supabase settings) — AuthGate picks it up; pop back to reveal it.
          _popIfPushed();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showSnackBar(
          context,
          SnackBar(content: Text('Sign up failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await SupabaseClient.instance.signInWithGoogle();
      // Web: browser redirects to Google then back — AuthGate handles the rest.
    } catch (e) {
      if (mounted) {
        AppToast.showSnackBar(
          context,
          SnackBar(content: Text('Google sign-in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openResetPassword() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
  }

  static const Color _babyPink = Color(0xFFFFC1D9);
  static const Color _babyPinkDeep = Color(0xFFF48FB1);
  static const Color _babyPinkBg = Color(0xFFFFF5F9);
  static const Color _textOnPink = Color(0xFF4A1230);

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      borderSide: const BorderSide(color: _babyPinkDeep, width: 1.2),
    );
    final inputBorderDisabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      borderSide: BorderSide(
        color: _babyPink.withValues(alpha: 0.65),
        width: 1,
      ),
    );

    return Scaffold(
      backgroundColor: _babyPinkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    const BrandHero(),
                    const SizedBox(height: 6),
                    Text(
                      isLogin ? 'Welcome back' : 'Create your account',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _textOnPink.withValues(alpha: 0.75),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.inviteJoinHint) ...[
                      const SizedBox(height: 8),
                      Text(
                        isLogin
                            ? 'Sign in to open your teacher’s group'
                            : 'Create a free account to open your teacher’s group',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _textOnPink.withValues(alpha: 0.65),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (!isLogin) ...[
                      TextFormField(
                        controller: _referralController,
                        textCapitalization: TextCapitalization.characters,
                        cursorColor: _babyPinkDeep,
                        decoration: InputDecoration(
                          labelText: 'Referral code (optional)',
                          labelStyle: TextStyle(
                            color: _textOnPink.withValues(alpha: 0.7),
                          ),
                          prefixIcon: const Icon(
                            Icons.card_giftcard_outlined,
                            color: _babyPinkDeep,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: inputBorderDisabled,
                          focusedBorder: inputBorder,
                          border: inputBorderDisabled,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _babyPink, width: 1.2),
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _babyPinkDeep.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeTab(
                              label: 'Login',
                              isActive: isLogin,
                              onTap: () => _switchMode(_AuthMode.login),
                            ),
                          ),
                          Expanded(
                            child: _ModeTab(
                              label: 'Sign Up',
                              isActive: !isLogin,
                              onTap: () => _switchMode(_AuthMode.signUp),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      cursorColor: _babyPinkDeep,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) =>
                          _passwordFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(
                          color: _textOnPink.withValues(alpha: 0.7),
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: _babyPinkDeep,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: inputBorderDisabled,
                        focusedBorder: inputBorder,
                        border: inputBorderDisabled,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your email';
                        if (!value.contains('@'))
                          return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      cursorColor: _babyPinkDeep,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) =>
                          isLogin ? _handleLogin() : _handleSignUp(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(
                          color: _textOnPink.withValues(alpha: 0.7),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: _babyPinkDeep,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _babyPinkDeep,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: inputBorderDisabled,
                        focusedBorder: inputBorder,
                        border: inputBorderDisabled,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your password';
                        if (value.length < 6)
                          return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    if (isLogin) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _openResetPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: _babyPinkDeep,
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 20),

                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (isLogin ? _handleLogin : _handleSignUp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _babyPinkDeep,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: _babyPinkDeep.withValues(alpha: 0.3),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isLogin ? 'Sign In' : 'Create Account'),
                    ),

                    if (!isLogin) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _textOnPink.withValues(alpha: 0.7),
                                ),
                            children: [
                              const TextSpan(
                                text:
                                    'By creating an account, you agree to our ',
                              ),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: const TextStyle(
                                  color: _babyPinkDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: _babyPinkDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: _privacyRecognizer,
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: _babyPink.withValues(alpha: 0.7),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'or',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _textOnPink.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: _babyPink.withValues(alpha: 0.7),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const GoogleLogo(size: 20),
                      label: Text(
                        isLogin
                            ? 'Continue with Google'
                            : 'Sign up with Google',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textOnPink,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _babyPinkDeep, width: 1.3),
                        backgroundColor: Colors.white,
                        foregroundColor: _babyPinkDeep,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _textOnPink.withValues(alpha: 0.7),
                              ),
                          children: [
                            TextSpan(
                              text: isLogin
                                  ? "New here? "
                                  : 'Already have an account? ',
                            ),
                            TextSpan(
                              text: isLogin ? 'Create an account' : 'Sign in',
                              style: const TextStyle(
                                color: _babyPinkDeep,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: _switchModeRecognizer,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF48FB1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius - 2),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFF48FB1).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF4A1230).withValues(alpha: 0.6),
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}
