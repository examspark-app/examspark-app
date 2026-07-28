import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/legal_urls.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/legal/legal_webview_screen.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';

/// ============================================================
/// TASK 3 — Settings → Legal → Legal Center
/// ============================================================
/// Reached from Profile → Settings → Legal. Lists every policy document
/// plus Contact Us / About Sonaxia. Every tile opens `LegalWebViewScreen`
/// (Task 4) — URLs are read only from `LegalUrls` (Task 5), never
/// hardcoded here.
class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Legal Center'),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          Text(
            'Policies',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _card(context, [
            for (var i = 0; i < LegalUrls.corePolicies.length; i++) ...[
              if (i != 0) Divider(height: 1, color: AppTheme.getCardBorder(context)),
              _DocTile(doc: LegalUrls.corePolicies[i]),
            ],
          ]),
          const SizedBox(height: 24),
          Text(
            'Support',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _card(context, [
            for (var i = 0; i < LegalUrls.legalCenterExtras.length; i++) ...[
              if (i != 0) Divider(height: 1, color: AppTheme.getCardBorder(context)),
              _DocTile(doc: LegalUrls.legalCenterExtras[i]),
            ],
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(children: children),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc});

  final LegalDocument doc;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(doc.icon, color: AppTheme.accentColor),
      title: Text(doc.title),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppTheme.getSecondaryText(context),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LegalWebViewScreen(title: doc.title, url: doc.url),
        ),
      ),
    );
  }
}
