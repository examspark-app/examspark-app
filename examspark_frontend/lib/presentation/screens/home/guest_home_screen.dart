import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/guest_trial_store.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/auth/login_screen.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/bottom_input_bar.dart';
import 'package:examspark_frontend/presentation/widgets/signup_prompt_sheet.dart';

class _ChatBubble {
  final String text;
  final bool isUser;
  const _ChatBubble(this.text, this.isUser);
}

/// Anonymous visitor: exactly ONE free question, persisted on device so
/// refresh / reopen does not reset the trial (clearing site/app data can).
class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final List<_ChatBubble> _messages = [];
  bool _freeTrialUsed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadTrialFlag();
  }

  Future<void> _loadTrialFlag() async {
    final used = await GuestTrialStore.isFreePromptUsed();
    if (!mounted) return;
    setState(() {
      _freeTrialUsed = used;
      _ready = true;
      if (used && _messages.isEmpty) {
        _messages.add(const _ChatBubble(
          'You already used your free guest question on this device. '
          'Sign up to get 50 Free credits and keep chatting.',
          false,
        ));
      }
    });
  }

  Future<void> _handleSend(String text) async {
    if (_freeTrialUsed) {
      _promptSignUp();
      return;
    }
    setState(() {
      _messages.add(_ChatBubble(text, true));
      _messages.add(const _ChatBubble(
        'This is a placeholder AI reply — real Ask AI answers connect once you '
        'sign up. Free signup includes 50 credits. Audio unlock starts at ₹499.',
        false,
      ));
      _freeTrialUsed = true;
    });
    await GuestTrialStore.markFreePromptUsed();
  }

  void _handleRestrictedAction() {
    _promptSignUp();
  }

  void _promptSignUp() {
    showSignupPromptSheet(
      context,
      onCreateAccount: () => _openLogin(startInSignUp: true),
      onSignIn: () => _openLogin(startInSignUp: false),
    );
  }

  void _openLogin({required bool startInSignUp}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginScreen(startInSignUp: startInSignUp)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppTopBar(
        showLogo: true,
        trailing: [
          TextButton(
            onPressed: () => _openLogin(startInSignUp: false),
            child: const Text('Sign In'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_freeTrialUsed
                ? _buildWelcome(context)
                : _buildConversation(context),
          ),
          if (_freeTrialUsed) _buildSignUpBanner(context),
          BottomInputBar(
            onSend: _handleSend,
            onAttach: _handleRestrictedAction,
            onRecord: _handleRestrictedAction,
            onYoutube: _handleRestrictedAction,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.auto_awesome, size: 56, color: AppTheme.accentColor),
          const SizedBox(height: 16),
          Text(
            'Ask ExamSpark anything',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'One free question on this device (no account). Sign up for 50 Free '
            'credits. Clearing browser data may reset the trial — real guest AI '
            'will also be limited on the server later.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final bubble = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: bubble.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubble.isUser
                    ? AppTheme.accentColor
                    : AppTheme.getCardBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: bubble.isUser
                    ? null
                    : Border.all(color: AppTheme.getCardBorder(context)),
              ),
              child: Text(
                bubble.text,
                style: TextStyle(
                  color: bubble.isUser
                      ? Colors.white
                      : AppTheme.getPrimaryText(context),
                  height: 1.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignUpBanner(BuildContext context) {
    return InkWell(
      onTap: () => _openLogin(startInSignUp: true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppTheme.getAccentTint(context),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppTheme.accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Free guest question used on this device — sign up to continue',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentColor,
                    ),
              ),
            ),
            Text(
              'Sign Up',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
