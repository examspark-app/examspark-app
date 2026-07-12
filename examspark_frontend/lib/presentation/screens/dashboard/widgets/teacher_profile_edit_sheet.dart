import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Bottom sheet form for a teacher to edit their public profile.
///
/// Certificate upload picks a real image and saves its title + a "Pending
/// Review" status to Postgres (`teacher_certificates` — metadata only).
/// The actual image bytes are kept in memory for this session's preview
/// only; real Cloudflare R2 storage + the AI real/fake document check are
/// Phase 5 work.
class TeacherProfileEditSheet extends StatefulWidget {
  final TeacherProfileModel profile;
  final ValueChanged<TeacherProfileModel> onSave;

  const TeacherProfileEditSheet({super.key, required this.profile, required this.onSave});

  @override
  State<TeacherProfileEditSheet> createState() => _TeacherProfileEditSheetState();
}

class _TeacherProfileEditSheetState extends State<TeacherProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bioController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _experienceController;
  late List<TeacherCertificateModel> _certificates;
  bool _isSaving = false;
  bool _isPickingCertificate = false;

  // Preview-only, this editing session — never persisted (no R2 yet).
  final Map<String, Uint8List> _certificatePreviewBytes = {};

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.fullName);
    _subjectController = TextEditingController(text: p.subject);
    _bioController = TextEditingController(text: p.bio ?? '');
    _qualificationController = TextEditingController(text: p.qualification ?? '');
    _experienceController = TextEditingController(text: p.experienceYears.toString());
    _certificates = List.of(p.certificates);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _bioController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _addCertificate() async {
    if (_isPickingCertificate) return;
    setState(() => _isPickingCertificate = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final defaultTitle = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;

      if (!mounted) return;
      final title = await _promptCertificateTitle(defaultTitle);
      if (title == null || title.trim().isEmpty) return;

      final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
      if (file.bytes != null) _certificatePreviewBytes[id] = file.bytes!;

      setState(() {
        _certificates = [
          ..._certificates,
          TeacherCertificateModel(id: id, title: title.trim(), uploadedAt: DateTime.now()),
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add certificate: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPickingCertificate = false);
    }
  }

  Future<String?> _promptCertificateTitle(String defaultTitle) {
    final controller = TextEditingController(text: defaultTitle);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Certificate title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. B.Ed Certification'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showContactSupport(TeacherCertificateModel cert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Needs Review'),
        content: Text(
          '"${cert.title}" needs manual review. Email support@examspark.app with the '
          'certificate details and our team will verify it manually.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = widget.profile.copyWith(
      fullName: _nameController.text.trim(),
      subject: _subjectController.text.trim(),
      bio: _bioController.text.trim(),
      qualification: _qualificationController.text.trim(),
      experienceYears: int.tryParse(_experienceController.text.trim()) ?? widget.profile.experienceYears,
      certificates: _certificates,
    );
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.getCardBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Edit Teacher Profile',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _field('Full Name', _nameController),
                const SizedBox(height: 14),
                _field('Teaching Subject', _subjectController),
                const SizedBox(height: 14),
                _field('Qualification', _qualificationController, hint: 'e.g. M.Sc Physics'),
                const SizedBox(height: 14),
                _field('Experience (years)', _experienceController, keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                _field('Short Bio', _bioController, maxLines: 3),
                const SizedBox(height: 20),
                Text('Certificates & Proof', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Real AI verification runs in a later update — for now, uploads are '
                  'marked "Pending Review".',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context)),
                ),
                const SizedBox(height: 10),
                for (final cert in _certificates) _certificateTile(cert),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _isPickingCertificate ? null : _addCertificate,
                  icon: _isPickingCertificate
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Add Certificate'),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Save Profile'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _certificateTile(TeacherCertificateModel cert) {
    final bytes = _certificatePreviewBytes[cert.id];
    final (statusLabel, statusColor) = switch (cert.status) {
      CertificateStatus.pending => ('Pending Review', Colors.amber[800]!),
      CertificateStatus.verified => ('Verified', Colors.green[700]!),
      CertificateStatus.rejected => ('Needs Review — Contact Support', Colors.red[700]!),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: cert.status == CertificateStatus.rejected ? () => _showContactSupport(cert) : null,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.getCardBorder(context)),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: bytes != null
                    ? Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover)
                    : Container(
                        width: 40,
                        height: 40,
                        color: AppTheme.getAccentTint(context),
                        alignment: Alignment.center,
                        child: Icon(Icons.description_outlined, size: 18, color: AppTheme.accentColor),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cert.title, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(statusLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: statusColor)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  _certificates.remove(cert);
                  _certificatePreviewBytes.remove(cert.id);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
      ),
    );
  }
}

/// Shows the edit sheet as a modal bottom sheet.
Future<void> showTeacherProfileEditSheet(
  BuildContext context, {
  required TeacherProfileModel profile,
  required ValueChanged<TeacherProfileModel> onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TeacherProfileEditSheet(profile: profile, onSave: onSave),
  );
}
