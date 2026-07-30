import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:examspark_frontend/core/constants/certificate_upload_rules.dart';
import 'package:examspark_frontend/core/services/teacher_verification_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';
import 'package:examspark_frontend/presentation/widgets/home/web_camera_capture_export.dart';

/// Get Verified — mandatory before Create Group (Trusted badge ≥90%).
Future<bool?> showGetVerifiedSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _GetVerifiedSheet(),
  );
}

class _GetVerifiedSheet extends StatefulWidget {
  const _GetVerifiedSheet();

  @override
  State<_GetVerifiedSheet> createState() => _GetVerifiedSheetState();
}

class _GetVerifiedSheetState extends State<_GetVerifiedSheet> {
  Uint8List? _bytes;
  String? _filename;
  bool _busy = false;
  Map<String, dynamic>? _result;

  bool get _isPdf => (_filename ?? '').toLowerCase().endsWith('.pdf');

  /// After a failed / non-trusted result, AI stay blocked until new photo/file.
  bool get _blockedUntilNewUpload =>
      _result != null && _result!['trusted'] != true;

  bool get _canRunAi =>
      !_busy && _bytes != null && !_blockedUntilNewUpload;

  void _applyPickedBytes(Uint8List bytes, String name, {String? extensionHint}) {
    var finalName = name;
    final lower = finalName.toLowerCase();
    final looksPdf = lower.endsWith('.pdf') ||
        (extensionHint?.toLowerCase() == 'pdf') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46);
    if (looksPdf && !lower.endsWith('.pdf')) {
      finalName = '$finalName.pdf';
    }
    final err = CertificateUploadRules.validateFilename(finalName);
    if (err != null) {
      AppToast.showSnackBar(context, SnackBar(content: Text(err)));
      return;
    }
    setState(() {
      _bytes = bytes;
      _filename = finalName;
      _result = null;
    });
  }

  Future<void> _pickUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: CertificateUploadRules.allowedExtensions,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    var name = f.name;
    if (!name.contains('.') && f.extension != null && f.extension!.isNotEmpty) {
      name = '$name.${f.extension}';
    }
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text(
            'Could not read file. Try a smaller PDF (<10 MB) or JPG/PNG.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    _applyPickedBytes(bytes, name, extensionHint: f.extension);
  }

  Future<void> _pickCamera() async {
    try {
      Uint8List? bytes;
      var filename = 'certificate_camera.jpg';
      if (kIsWeb) {
        bytes = await captureWebCameraPhoto(context);
        if (bytes == null) return;
      } else {
        final picker = ImagePicker();
        final shot = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2048,
        );
        if (shot == null) return;
        bytes = await shot.readAsBytes();
        if (shot.name.isNotEmpty) filename = shot.name;
      }
      if (bytes.isEmpty) {
        if (!mounted) return;
        AppToast.showSnackBar(
          context,
          const SnackBar(content: Text('Could not capture photo. Try again.')),
        );
        return;
      }
      if (!mounted) return;
      _applyPickedBytes(bytes, filename);
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Camera unavailable: $e')),
      );
    }
  }

  Future<void> _submit() async {
    // One fail on this file → no more AI calls until Change file.
    if (!_canRunAi) return;
    setState(() => _busy = true);
    try {
      final out = await TeacherVerificationService.instance.verifyCertificate(
        imageBytes: _bytes!,
        filename: _filename ?? 'certificate.jpg',
      );
      if (!mounted) return;
      final trusted = out['trusted'] == true;
      setState(() {
        _result = out;
        _busy = false;
      });
      AppToast.show(
        trusted
            ? 'Trusted Teacher Badge unlocked'
            : ((out['message'] as String?) ??
                'Not verified yet — try a clearer cert'),
        isError: !trusted,
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyVerifyError(e);
      setState(() {
        _busy = false;
        _result = {
          'trusted': false,
          'verification_score': 0,
          'message': msg,
          'contact_support': true,
        };
      });
      AppToast.show(msg, isError: true, context: context);
    }
  }

  /// Hide raw Exception:/ClientException noise — not a UI glitch.
  String _friendlyVerifyError(Object e) {
    final s = e.toString();
    if (s.contains('Cannot reach backend') ||
        s.contains('Failed to fetch') ||
        s.contains('ClientException')) {
      return 'Cannot reach the server. Start the app backend, tap Change file, then Run again.';
    }
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse(
      'mailto:support@examspark.app?subject=Teacher%20verification%20help',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final trusted = _result?['trusted'] == true;
    final score = _result?['verification_score'];

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.getCardBorder(context),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Get Verified',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, trusted),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    'Required before Create Group. Take a photo with the camera '
                    'or upload PDF / JPG / PNG of a real education certificate '
                    '(photocopy OK). '
                    'Minimum: Class 12 / 12th pass or higher '
                    '(diploma, degree, B.Ed…). Class 10 or below not allowed. '
                    'No screenshots. No Aadhaar/PAN/Passport. '
                    'Score ≥90% → Trusted Teacher Badge. '
                    'Usually ~10–40 seconds after Run (large files take longer). '
                    'After a successful Trusted badge, you do not need to run AI again.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (_bytes != null) ...[
                    if (_isPdf)
                      Container(
                        height: 120,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.getCardBackground(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.getCardBorder(context),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              _filename ?? 'certificate.pdf',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _bytes!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 640,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _filename ?? 'certificate',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickCamera,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            _bytes == null ? 'Camera' : 'Retake',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _pickUpload,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(
                            _bytes == null ? 'Upload' : 'Change file',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_blockedUntilNewUpload) ...[
                    const SizedBox(height: 8),
                    Text(
                      'AI will not run again on this same file (saves credits). '
                      'Use Camera or Change file with a new certificate, then Run.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canRunAi ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _blockedUntilNewUpload
                                  ? 'Add a new photo or file to retry AI'
                                  : 'Run soft verification',
                            ),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: trusted
                            ? AppTheme.getAccentTint(context)
                            : AppTheme.getCardBackground(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.borderRadius),
                        border: Border.all(
                          color: AppTheme.getCardBorder(context),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trusted
                                ? 'Trusted Teacher Badge'
                                : 'Not verified yet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (score != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Confidence: ${score is num ? score.toStringAsFixed(0) : score}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            (_result!['message'] as String?) ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_result!['contact_support'] == true) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _contactSupport,
                              icon: const Icon(Icons.mail_outline),
                              label: const Text('Contact Support'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
