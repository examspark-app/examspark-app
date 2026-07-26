import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/certificate_upload_rules.dart';
import 'package:examspark_frontend/core/constants/class_levels.dart';
import 'package:examspark_frontend/core/constants/exam_boards.dart';
import 'package:examspark_frontend/core/constants/teaching_languages.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';
import 'package:examspark_frontend/presentation/widgets/sheet_scaffold.dart';

/// Opens teacher profile edit (photo + fields). Used by Teacher Dashboard.
///
/// [requireMinimum]: cannot dismiss until Full Name + Subject saved
/// (no full skip). City / cert can still be skipped until Create Group.
Future<void> showTeacherProfileEditSheet(
  BuildContext context, {
  required TeacherProfileModel profile,
  required ValueChanged<TeacherProfileModel> onSave,
  bool requireMinimum = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isDismissible: !requireMinimum,
    enableDrag: !requireMinimum,
    builder: (ctx) => SheetScaffold(
      child: TeacherProfileEditSheet(
        profile: profile,
        onSave: onSave,
        requireMinimum: requireMinimum,
      ),
    ),
  );
}

/// Bottom sheet: edit teacher public profile + profile photo.
///
/// Soft minimum: Full Name + Teaching Subject (must save — no full skip).
/// Optional until Create Group: City, State, Qualification, Certificate.
class TeacherProfileEditSheet extends StatefulWidget {
  final TeacherProfileModel profile;
  final ValueChanged<TeacherProfileModel> onSave;
  final bool requireMinimum;

  const TeacherProfileEditSheet({
    super.key,
    required this.profile,
    required this.onSave,
    this.requireMinimum = false,
  });

  @override
  State<TeacherProfileEditSheet> createState() =>
      _TeacherProfileEditSheetState();
}

class _TeacherProfileEditSheetState extends State<TeacherProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bioController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _customLanguageController;
  late List<String> _languages;
  late List<String> _classLevels;
  late List<String> _exams;
  late List<TeacherCertificateModel> _certificates;
  bool _showCertificatesOnProfile = false;
  bool _isSaving = false;
  bool _isPickingCertificate = false;
  bool _isPickingPhoto = false;
  String? _photoUrl;
  Uint8List? _photoPreviewBytes;
  String _photoExtension = 'jpg';
  String _photoContentType = 'image/jpeg';
  final Map<String, Uint8List> _certificatePreviewBytes = {};

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.fullName);
    _subjectController = TextEditingController(text: p.subject);
    _bioController = TextEditingController(text: p.bio ?? '');
    _qualificationController = TextEditingController(text: p.qualification ?? '');
    _experienceController =
        TextEditingController(text: p.experienceYears.toString());
    _cityController = TextEditingController(text: p.city ?? '');
    _stateController = TextEditingController(text: p.state ?? '');
    _certificates = List.of(p.certificates);
    _languages = List.of(p.languagesList);
    _classLevels = List.of(p.classLevelsList);
    _exams = List.of(p.examsList);
    _customLanguageController = TextEditingController();
    _showCertificatesOnProfile = p.showCertificatesOnProfile;
    _photoUrl = p.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _bioController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _customLanguageController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) return;
    setState(() => _isPickingPhoto = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        showSheetSnackBar(
          context,
          'Could not read image — try another file',
        );
        return;
      }
      final name = (file.name).toLowerCase();
      final ext = name.endsWith('.png')
          ? 'png'
          : name.endsWith('.webp')
              ? 'webp'
              : 'jpg';
      setState(() {
        _photoPreviewBytes = bytes;
        _photoExtension = ext;
        _photoContentType = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
      });
    } catch (e) {
      if (!mounted) return;
      showSheetSnackBar(context, 'Could not pick photo: $e');
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _addCertificate() async {
    if (_isPickingCertificate) return;
    setState(() => _isPickingCertificate = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: CertificateUploadRules.allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final nameErr = CertificateUploadRules.validateFilename(file.name);
      if (nameErr != null) {
        if (!mounted) return;
        showSheetSnackBar(context, nameErr);
        return;
      }
      final defaultTitle = file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name;

      if (!mounted) return;
      final title = await _promptCertificateTitle(defaultTitle);
      if (title == null || title.trim().isEmpty) return;

      final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
      final isPdf = file.name.toLowerCase().endsWith('.pdf');
      if (!isPdf && file.bytes != null) {
        _certificatePreviewBytes[id] = file.bytes!;
      }

      setState(() {
        _certificates = [
          ..._certificates,
          TeacherCertificateModel(
            id: id,
            title: title.trim(),
            uploadedAt: DateTime.now(),
          ),
        ];
      });
    } catch (e) {
      if (!mounted) return;
      showSheetSnackBar(context, 'Could not add certificate: $e');
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
          '"${cert.title}" needs manual review. Email support@examspark.app '
          'with the certificate details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _save({bool skipOptionalRest = false}) async {
    final name = _nameController.text.trim();
    final subject = _subjectController.text.trim();
    final nameOk =
        name.isNotEmpty && name.toLowerCase() != 'new teacher';
    if (!nameOk || subject.isEmpty) {
      if (!mounted) return;
      showSheetSnackBar(
        context,
        'Minimum required: Full Name + Teaching Subject. '
        'Then you can skip City / Certificate for now.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      var photoUrl = _photoUrl;
      if (_photoPreviewBytes != null) {
        photoUrl = await GroupsRepository.instance.uploadTeacherProfilePhoto(
          bytes: _photoPreviewBytes!,
          contentType: _photoContentType,
          extension: _photoExtension,
        );
      }
      final updated = widget.profile.copyWith(
        fullName: name,
        subject: subject,
        bio: _bioController.text.trim(),
        qualification: _qualificationController.text.trim(),
        experienceYears: int.tryParse(_experienceController.text.trim()) ??
            widget.profile.experienceYears,
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        language: TeacherProfileModel.joinSubjects(_languages).isEmpty
            ? null
            : TeacherProfileModel.joinSubjects(_languages),
        classLevels: TeacherProfileModel.joinSubjects(_classLevels).isEmpty
            ? null
            : TeacherProfileModel.joinSubjects(_classLevels),
        exams: TeacherProfileModel.joinSubjects(_exams).isEmpty
            ? null
            : TeacherProfileModel.joinSubjects(_exams),
        certificates: _certificates,
        showCertificatesOnProfile: _showCertificatesOnProfile,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      widget.onSave(updated);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showSheetSnackBar(
        context,
        'Could not save: $e\n'
        'If bucket missing — see FOUNDER_TEACHER_PROFILE_PHOTO.md',
      );
    }
  }

  Widget _photoHeader(BuildContext context) {
    final name = _nameController.text.trim().isEmpty
        ? widget.profile.fullName
        : _nameController.text.trim();
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (_photoPreviewBytes != null)
              CircleAvatar(
                radius: 48,
                backgroundImage: MemoryImage(_photoPreviewBytes!),
              )
            else
              InitialsAvatar(name: name, photoUrl: _photoUrl, size: 96),
            Material(
              color: AppTheme.accentColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isPickingPhoto || _isSaving ? null : _pickPhoto,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _isPickingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isPickingPhoto || _isSaving ? null : _pickPhoto,
          child: Text(
            _photoUrl == null && _photoPreviewBytes == null
                ? 'Add profile photo'
                : 'Change photo',
          ),
        ),
        Text(
          'Shows on Groups list, Discover, and Group Info',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.getSecondaryText(context),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _photoHeader(context),
                const SizedBox(height: 16),
                Text(
                  'Minimum (required now): Full Name + Teaching Subject.\n'
                  'Then Skip rest OK — City, State, Qualification, Certificate '
                  'can wait until Create Group. No full empty skip.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
                const SizedBox(height: 20),
                _field('Full Name *', _nameController),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Original name must match your education certificate '
                    '(used in Get Verified).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
                ),
                const SizedBox(height: 14),
                _field('Teaching Subject *', _subjectController),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Multiple OK — comma-separated (e.g. Mathematics, Physics). '
                    'Group create can only pick from this list.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Class / levels (for Discover + Group)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in ClassLevels.all)
                      FilterChip(
                        label: Text(c),
                        selected: _classLevels.any(
                          (x) => x.toLowerCase() == c.toLowerCase(),
                        ),
                        onSelected: (on) {
                          setState(() {
                            if (on) {
                              if (!_classLevels.contains(c)) {
                                _classLevels = [..._classLevels, c];
                              }
                            } else {
                              _classLevels =
                                  _classLevels.where((x) => x != c).toList();
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Board / Exam (for Discover + Group)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in ExamBoards.all)
                      FilterChip(
                        label: Text(e),
                        selected: _exams.any(
                          (x) => x.toLowerCase() == e.toLowerCase(),
                        ),
                        onSelected: (on) {
                          setState(() {
                            if (on) {
                              if (!_exams.contains(e)) {
                                _exams = [..._exams, e];
                              }
                            } else {
                              _exams = _exams.where((x) => x != e).toList();
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _field('City (can skip for now)', _cityController, hint: 'e.g. Pune'),
                const SizedBox(height: 14),
                _field('State (can skip for now)', _stateController, hint: 'e.g. Maharashtra'),
                const SizedBox(height: 6),
                Text(
                  'City & State help students find you in Groups → Discover.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Teaching languages',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in TeachingLanguages.all)
                      FilterChip(
                        label: Text(l),
                        selected: _languages.any(
                          (x) => x.toLowerCase() == l.toLowerCase(),
                        ),
                        onSelected: (on) {
                          setState(() {
                            if (on) {
                              if (!_languages.contains(l)) {
                                _languages = [..._languages, l];
                              }
                            } else {
                              _languages =
                                  _languages.where((x) => x != l).toList();
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customLanguageController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Custom language…',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.borderRadius),
                          ),
                        ),
                        onSubmitted: (v) {
                          final t = v.trim();
                          if (t.isEmpty) return;
                          setState(() {
                            if (!_languages.any(
                              (x) => x.toLowerCase() == t.toLowerCase(),
                            )) {
                              _languages = [..._languages, t];
                            }
                            _customLanguageController.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final t = _customLanguageController.text.trim();
                        if (t.isEmpty) return;
                        setState(() {
                          if (!_languages.any(
                            (x) => x.toLowerCase() == t.toLowerCase(),
                          )) {
                            _languages = [..._languages, t];
                          }
                          _customLanguageController.clear();
                        });
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(
                  'Qualification (can skip for now)',
                  _qualificationController,
                  hint: 'e.g. M.Sc Physics',
                ),
                const SizedBox(height: 14),
                _field(
                  'Experience (years)',
                  _experienceController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _field('Short Bio', _bioController, maxLines: 3),
                const SizedBox(height: 20),
                Text(
                  'Certificates & Proof (optional for students)',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Profile certificates are optional. Get Verified (AI) is separate.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showCertificatesOnProfile,
                  onChanged: (v) =>
                      setState(() => _showCertificatesOnProfile = v),
                  title: const Text('Show certificates on profile'),
                  subtitle: Text(
                    _showCertificatesOnProfile
                        ? 'ON — students can see them'
                        : 'OFF — private (only you)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final cert in _certificates) _certificateTile(cert),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _isPickingCertificate ? null : _addCertificate,
                  icon: _isPickingCertificate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Add Certificate'),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _save(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Profile'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _save(skipOptionalRest: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Save minimum & skip rest for now'),
                  ),
                ),
                if (widget.requireMinimum) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Name + Subject required before you can leave this screen.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
                ],
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
      CertificateStatus.rejected =>
        ('Needs Review — Contact Support', Colors.red[700]!),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: cert.status == CertificateStatus.rejected
            ? () => _showContactSupport(cert)
            : null,
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
                    ? Image.memory(
                        bytes,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: AppTheme.getAccentTint(context),
                        child: const Icon(Icons.description_outlined),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
      ),
    );
  }
}
