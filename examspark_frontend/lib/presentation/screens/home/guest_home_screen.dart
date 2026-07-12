import 'package:flutter/material.dart';
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

/// What an anonymous visitor sees before signing in — PRODUCT_VISION.md
/// Core User Flow #1: "Anonymous try → One Ask AI → Sign up → @username +
/// Library". Mirrors `HomeTab`'s chat layout (Home = Chat Screen UX rule)
/// but allows exactly ONE free question; every action after that opens
/// [showSignupPromptSheet] instead of `LoginScreen` directly, so people
/// get a taste of the product before being asked to commit.
class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final List<_ChatBubble> _messages = [];
  bool _freeTrialUsed = false;

  void _handleSend(String text) {
    if (_freeTrialUsed) {
      _promptSignUp();
      return;
    }
    setState(() {
      _messages.add(_ChatBubble(text, true));
      _messages.add(const _ChatBubble(
        'This is a placeholder AI reply — real Ask AI answers connect once the RAG '
        'pipeline is wired (Phase 4/5). Sign up to keep chatting and unlock recording, '
        'notes, flashcards and quizzes.',
        false,
      ));
      _freeTrialUsed = true;
    });
  }

  void _handleRestrictedAction() {
    // Recording / attachments are not part of the one free question —
    // they go straight to the signup prompt.
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
            child: _messages.isEmpty ? _buildWelcome(context) : _buildConversation(context),
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Try one free question — no account needed. Sign up to record lectures, '
            'get notes, flashcards, quizzes and join teacher groups.',
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
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubble.isUser ? AppTheme.accentColor : AppTheme.getCardBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: bubble.isUser ? null : Border.all(color: AppTheme.getCardBorder(context)),
              ),
              child: Text(
                bubble.text,
                style: TextStyle(
                  color: bubble.isUser ? Colors.white : AppTheme.getPrimaryText(context),
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
                'Free question used — sign up to keep chatting',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.accentColor),
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
