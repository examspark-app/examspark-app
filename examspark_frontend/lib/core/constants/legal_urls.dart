import 'package:flutter/material.dart';

/// ============================================================
/// TASK 5 — Central URL Manager
/// ============================================================
/// Single source of truth for every legal / policy link in the app.
/// No screen should ever hardcode a URL string — everything routes
/// through here so a founder can swap placeholder links for live ones
/// later by editing ONLY this file.
///
/// TASK 6 — Future Ready:
/// Replace the placeholder URLs below with the final production URLs
/// (e.g. https://sonaxia.com/privacy) whenever they're ready. Every
/// screen that shows a legal document — the Signup consent line, the
/// First Login Legal Consent screen, and Settings → Legal Center —
/// reads from this file, so a single edit here updates the whole app.
class LegalUrls {
  LegalUrls._();

 static const String privacyPolicy =
    'https://sites.google.com/view/sonaxia/privacy-policy';

static const String termsAndConditions =
    'https://sites.google.com/view/sonaxia/terms-conditions';

static const String aiDataPolicy =
    'https://sites.google.com/view/sonaxia/ai-data-policy';

static const String cancellationRefundPolicy =
    'https://sites.google.com/view/sonaxia/cancellation-refund-policy';

static const String communityGuidelines =
    'https://sites.google.com/view/sonaxia/community-guidelines';

static const String copyrightPolicy =
    'https://sites.google.com/view/sonaxia/copyright-dmca-policy';

static const String contactUs =
    'https://sites.google.com/view/sonaxia';

static const String aboutSonaxia =
    'https://sites.google.com/view/sonaxia';

static const String paymentBusinessInfo =
    'https://sites.google.com/view/sonaxia/payment-business-info';    

  /// The 6 core policy documents. Shown on:
  /// - First Login Legal Consent screen (Task 2)
  /// - Legal Center → "Policies" section (Task 3)
  static const List<LegalDocument> corePolicies = [
    LegalDocument(
      title: 'Privacy Policy',
      icon: Icons.privacy_tip_outlined,
      url: privacyPolicy,
    ),
    LegalDocument(
      title: 'Terms & Conditions',
      icon: Icons.description_outlined,
      url: termsAndConditions,
    ),
    LegalDocument(
      title: 'AI & Data Policy',
      icon: Icons.smart_toy_outlined,
      url: aiDataPolicy,
    ),
    LegalDocument(
      title: 'Cancellation & Refund Policy',
      icon: Icons.currency_rupee_outlined,
      url: cancellationRefundPolicy,
    ),
    LegalDocument(
      title: 'Community Guidelines',
      icon: Icons.groups_outlined,
      url: communityGuidelines,
    ),
    LegalDocument(
      title: 'Copyright Policy',
      icon: Icons.copyright_outlined,
      url: copyrightPolicy,
    ),
  ];

  /// Legal Center (Task 3) shows the 6 core policies plus these two.
  static const List<LegalDocument> legalCenterExtras = [
    LegalDocument(
      title: 'Contact Us',
      icon: Icons.mail_outline,
      url: contactUs,
    ),
    LegalDocument(
      title: 'About Sonaxia',
      icon: Icons.info_outline,
      url: aboutSonaxia,
    ),
    LegalDocument(
      title: 'Business & Payment Info',
      icon: Icons.storefront_outlined,
      url: paymentBusinessInfo,
    ),
  ];
}

/// Metadata for one legal/policy document tile (icon + title + URL).
/// Defined once here and reused by both the Legal Consent screen and
/// the Legal Center so the list of documents never has to be duplicated.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.icon,
    required this.url,
  });

  final String title;
  final IconData icon;
  final String url;
}
