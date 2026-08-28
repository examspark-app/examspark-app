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

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.startInSignUp = false,
    this.inviteJoinHint = false,
  });

  final bool startInSignUp;
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
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  static const Color _babyPink = Color(0xFFFF8FB1);

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
      if (mounted) setState(() => _isLoading = false);
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
          } catch (_) {}
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
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(email: email),
            ),
          );
        } else {
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseClient.instance.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        AppToast.showSnackBar(
          context,
          SnackBar(content: Text('Google sign-in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openResetPassword() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = AppTheme.getCardBackground(context) == AppTheme.lightCardBackground
        ? (isDark ? AppTheme.darkBackground : AppTheme.lightBackground)
        : (isDark ? AppTheme.darkBackground : AppTheme.lightBackground);
    final primaryText = AppTheme.getPrimaryText(context);
    final secondaryText = AppTheme.getSecondaryText(context);
    final fieldFill = AppTheme.getCardBackground(context);
    final fieldBorder = AppTheme.getCardBorder(context);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      borderSide: const BorderSide(color: _babyPink, width: 1.4),
    );
    final inputBorderDisabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      borderSide: BorderSide(color: fieldBorder, width: 1),
    );

    return Scaffold(
      backgroundColor: bg,
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
                      style: TextStyle(fontSize: 14, color: secondaryText),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.inviteJoinHint) ...[
                      const SizedBox(height: 8),
                      Text(
                        isLogin
                            ? 'Sign in to open your teacher\u2019s group'
                            : 'Create a free account to open your teacher\u2019s group',
                        style: TextStyle(fontSize: 13, color: secondaryText),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (!isLogin) ...[
                      TextFormField(
                        controller: _referralController,
                        textCapitalization: TextCapitalization.characters,
                        cursorColor: primaryText,
                        style: TextStyle(color: primaryText),
                        decoration: InputDecoration(
                          labelText: 'Referral code (optional)',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(
                            Icons.card_giftcard_outlined,
                            color: secondaryText,
                          ),
                          filled: true,
                          fillColor: fieldFill,
                          enabledBorder: inputBorderDisabled,
                          focusedBorder: inputBorder,
                          border: inputBorderDisabled,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Login / Sign Up segmented toggle — black & white,
                    // baby pink only on the active pill.
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: fieldFill,
                        border: Border.all(color: fieldBorder, width: 1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeTab(
                              label: 'Login',
                              isActive: isLogin,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                              onTap: () => _switchMode(_AuthMode.login),
                            ),
                          ),
                          Expanded(
                            child: _ModeTab(
                              label: 'Sign Up',
                              isActive: !isLogin,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
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
                      cursorColor: primaryText,
                      style: TextStyle(color: primaryText),
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) =>
                          _passwordFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: secondaryText),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: secondaryText,
                        ),
                        filled: true,
                        fillColor: fieldFill,
                        enabledBorder: inputBorderDisabled,
                        focusedBorder: inputBorder,
                        border: inputBorderDisabled,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      cursorColor: primaryText,
                      style: TextStyle(color: primaryText),
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) =>
                          isLogin ? _handleLogin() : _handleSignUp(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: secondaryText),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: secondaryText,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: secondaryText,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        filled: true,
                        fillColor: fieldFill,
                        enabledBorder: inputBorderDisabled,
                        focusedBorder: inputBorder,
                        border: inputBorderDisabled,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
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
                            foregroundColor: _babyPink,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 20),

                    const SizedBox(height: 12),
                    // Primary action button — solid black/white (theme-
                    // inverted), NOT baby pink. Baby pink is reserved for
                    // small accents only (active tab, links, focus border).
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (isLogin ? _handleLogin : _handleSignUp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryText,
                        foregroundColor: bg,
                        elevation: 0,
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
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: bg,
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
                            style: TextStyle(fontSize: 12.5, color: secondaryText),
                            children: [
                              const TextSpan(
                                text:
                                    'By creating an account, you agree to our ',
                              ),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: const TextStyle(
                                  color: _babyPink,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: _babyPink,
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
                          child: Divider(color: fieldBorder, thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: secondaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: fieldBorder, thickness: 1),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: fieldBorder, width: 1.2),
                        backgroundColor: fieldFill,
                        foregroundColor: primaryText,
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
                          style: TextStyle(fontSize: 13, color: secondaryText),
                          children: [
                            TextSpan(
                              text: isLogin
                                  ? 'New here? '
                                  : 'Already have an account? ',
                            ),
                            TextSpan(
                              text: isLogin ? 'Create an account' : 'Sign in',
                              style: const TextStyle(
                                color: _babyPink,
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
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color primaryText;
  final Color secondaryText;
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
          color: isActive
              ? const Color(0xFFFF8FB1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius - 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : secondaryText,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}