/// Shared rules for teacher certificate uploads (Get Verified + Edit Profile).
/// Allow: photo / scan / PDF of education cert. Block: screenshots.
class CertificateUploadRules {
  CertificateUploadRules._();

  static const allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'heic',
    'heif',
  ];

  /// OS / tool screenshot name patterns (case-insensitive).
  static final _screenshotName = RegExp(
    r'(screenshot|screen[_\s-]?shot|screen[_\s-]?capture|screenrecording|'
    r'snip(ping)?tool|capture\d*|img_\d{8}_\d+|screenshot_\d+)',
    caseSensitive: false,
  );

  static bool isAllowedExtension(String filename) {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot < 0) return false;
    return allowedExtensions.contains(lower.substring(dot + 1));
  }

  static bool looksLikeScreenshot(String filename) {
    final base = filename.split(RegExp(r'[/\\]')).last;
    return _screenshotName.hasMatch(base);
  }

  /// Returns null if OK, else user-facing error.
  static String? validateFilename(String filename) {
    if (filename.trim().isEmpty) return 'Choose a file';
    if (looksLikeScreenshot(filename)) {
      return 'Screenshots are not allowed. Upload a photo, scan, or PDF of your education certificate.';
    }
    if (!isAllowedExtension(filename)) {
      return 'Use JPG, PNG, WEBP, HEIC, or PDF only.';
    }
    return null;
  }

  static String contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
