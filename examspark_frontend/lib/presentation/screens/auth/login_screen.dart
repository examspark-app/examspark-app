import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/auth/email_verification_screen.dart';
import 'package:examspark_frontend/presentation/screens/auth/reset_password_screen.dart';
import 'package:examspark_frontend/presentation/widgets/google_logo.dart';

enum _AuthMode { login, signUp }

/// Secure entry portal. One screen, two clear modes (Login / Sign Up)
/// switched with a segmented toggle — old users and new users each get an
/// unambiguous primary action, plus Google sign-in and password reset.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.startInSignUp = false});

  /// Opens straight on the "Sign Up" tab — used when pushed from
  /// [GuestHomeScreen]'s "Create Free Account" prompt so the user doesn't
  /// have to tap the toggle themselves.
  final bool startInSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  late _AuthMode _mode;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late final TapGestureRecognizer _switchModeRecognizer;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInSignUp ? _AuthMode.signUp : _AuthMode.login;
    _switchModeRecognizer = TapGestureRecognizer()
      ..onTap = () => _switchMode(_mode == _AuthMode.login ? _AuthMode.signUp : _AuthMode.login);
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
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _switchModeRecognizer.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_mode == mode || _isLoading) return;
    setState(() => _mode = mode);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
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
      final response = await SupabaseClient.instance.signUpWithEmail(
        email: email,
        password: _passwordController.text,
      );

      if (mounted) {
        if (response.session == null) {
          // Email confirmation required — no session yet. Take the user to
          // a real confirmation page instead of a snackbar they can miss.
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)),
          );
        } else {
          // Session came back immediately (email confirmations off in
          // Supabase settings) — AuthGate picks it up; pop back to reveal it.
          _popIfPushed();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Center(
                      child: Semantics(
                        label: 'ExamSpark app logo',
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'E',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ExamSpark',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLogin ? 'Welcome back' : 'Create your account',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Login / Sign Up segmented toggle — makes the two
                    // flows unmistakably distinct for old vs. new users.
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardBackground(context),
                        border: Border.all(color: AppTheme.getCardBorder(context)),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
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
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!value.contains('@')) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => isLogin ? _handleLogin() : _handleSignUp(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    if (isLogin) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _openResetPassword,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 20),

                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : (isLogin ? _handleLogin : _handleSignUp),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isLogin ? 'Sign In' : 'Create Account'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppTheme.getCardBorder(context))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: Theme.of(context).textTheme.bodySmall),
                        ),
                        Expanded(child: Divider(color: AppTheme.getCardBorder(context))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const GoogleLogo(size: 20),
                      label: Text(isLogin ? 'Continue with Google' : 'Sign up with Google'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall,
                          children: [
                            TextSpan(text: isLogin ? "New here? " : 'Already have an account? '),
                            TextSpan(
                              text: isLogin ? 'Create an account' : 'Sign in',
                              style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.w600),
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
  const _ModeTab({required this.label, required this.isActive, required this.onTap});

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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius - 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppTheme.getSecondaryText(context),
          ),
        ),
      ),
    );
  }
}