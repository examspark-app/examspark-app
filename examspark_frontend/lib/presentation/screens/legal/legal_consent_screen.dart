import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/legal_urls.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/legal/legal_webview_screen.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// ============================================================
/// TASK 2 — First Login Consent Screen
/// ============================================================
/// Shown once, right after signup (and on first login for any existing
/// account that hasn't accepted yet) — see the `legal_accepted` check
/// in `AuthGate`, which shows this screen instead of `AppShell` until
/// it's completed. Once accepted it sets `legal_accepted = true` on the
/// `users` row (same update-then-flag pattern `AuthGate` already uses
/// for `onboarding_completed` / `chooseTeacherRole`) and is never shown
/// again — existing users who already accepted go straight to Home.
///
/// No back / close button by design — like `RoleSelectionScreen` and
/// `StudentOnboardingScreen`, this is a gate the user must complete.
class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({
    super.key,
    required this.userId,
    required this.onDone,
  });

  final String userId;
  final VoidCallback onDone;

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _agreed = false;
  bool _submitting = false;

  void _openDoc(LegalDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalWebViewScreen(title: doc.title, url: doc.url),
      ),
    );
  }

  Future<void> _continue() async {
    if (!_agreed || _submitting) return;
    setState(() => _submitting = true);
    try {
      await SupabaseClient.instance.acceptLegalPolicies(widget.userId);
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Could not save: $e')),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Icon(Icons.shield_outlined, size: 48, color: AppTheme.accentColor),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Sonaxia',
                    style: Theme.of(context).textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Before continuing, please review our legal documents.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.getCardBackground(context),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(color: AppTheme.getCardBorder(context)),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < LegalUrls.corePolicies.length; i++) ...[
                          if (i != 0)
                            Divider(height: 1, color: AppTheme.getCardBorder(context)),
                          _PolicyTile(
                            doc: LegalUrls.corePolicies[i],
                            onTap: () => _openDoc(LegalUrls.corePolicies[i]),
                          ),
                        ],
                        Divider(height: 1, color: AppTheme.getCardBorder(context)),
                        _PolicyTile(
                          doc: const LegalDocument(
                            title: 'Business & Payment Info',
                            icon: Icons.storefront_outlined,
                            url: LegalUrls.paymentBusinessInfo,
                          ),
                          onTap: () => _openDoc(
                            const LegalDocument(
                              title: 'Business & Payment Info',
                              icon: Icons.storefront_outlined,
                              url: LegalUrls.paymentBusinessInfo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    onTap: _submitting ? null : () => setState(() => _agreed = !_agreed),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            activeColor: AppTheme.accentColor,
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _agreed = v ?? false),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'I have read and agree to all legal policies.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _agreed && !_submitting ? _continue : null,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Continue'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({required this.doc, required this.onTap});

  final LegalDocument doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(doc.icon, color: AppTheme.accentColor),
      title: Text(doc.title, style: Theme.of(context).textTheme.bodyMedium),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppTheme.getSecondaryText(context),
      ),
      onTap: onTap,
    );
  }
}
