import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/certificate_upload_rules.dart';
import 'package:examspark_frontend/core/constants/class_levels.dart';
import 'package:examspark_frontend/core/constants/custom_field_option.dart';
import 'package:examspark_frontend/core/constants/exam_boards.dart';
import 'package:examspark_frontend/core/constants/subjects.dart';
import 'package:examspark_frontend/core/constants/teaching_languages.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Full-screen teacher profile setup (not a half-cut sheet).
/// Subjects: search + suggest (no chip wall). Custom language listed first.
class TeacherProfileSetupScreen extends StatefulWidget {
  final TeacherProfileModel profile;

  const TeacherProfileSetupScreen({super.key, required this.profile});

  @override
  State<TeacherProfileSetupScreen> createState() =>
      _TeacherProfileSetupScreenState();
}

class _TeacherProfileSetupScreenState extends State<TeacherProfileSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _customLanguageController;
  late final TextEditingController _customClassController;
  late final TextEditingController _customExamController;
  late List<String> _subjects;
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
    _bioController = TextEditingController(text: p.bio ?? '');
    _qualificationController = TextEditingController(text: p.qualification ?? '');
    _experienceController =
        TextEditingController(text: p.experienceYears.toString());
    _cityController = TextEditingController(text: p.city ?? '');
    _stateController = TextEditingController(text: p.state ?? '');
    _subjects = List.of(p.subjectsList);
    _languages = List.of(p.languagesList);
    _classLevels = List.of(p.classLevelsList);
    _exams = List.of(p.examsList);
    _certificates = List.of(p.certificates);
    _customLanguageController = TextEditingController();
    _customClassController = TextEditingController();
    _customExamController = TextEditingController();
    _showCertificatesOnProfile = p.showCertificatesOnProfile;
    _photoUrl = p.photoUrl;
    for (final c in [
      _nameController,
      _qualificationController,
      _cityController,
      _stateController,
    ]) {
      c.addListener(_onFormChanged);
    }
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _qualificationController,
      _cityController,
      _stateController,
    ]) {
      c.removeListener(_onFormChanged);
    }
    _nameController.dispose();
    _bioController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _customLanguageController.dispose();
    _customClassController.dispose();
    _customExamController.dispose();
    super.dispose();
  }

  void _addToList(List<String> list, String raw, void Function(List<String>) setList) {
    final s = raw.trim();
    if (s.isEmpty || s == CustomFieldOption.label) return;
    if (list.any((x) => x.toLowerCase() == s.toLowerCase())) return;
    setList([...list, s]);
  }

  void _addSubject(String raw) {
    setState(() {
      _addToList(_subjects, raw, (v) => _subjects = v);
    });
  }

  void _removeSubject(String s) {
    setState(() => _subjects = _subjects.where((x) => x != s).toList());
  }

  void _addLanguage(String raw) {
    setState(() {
      _addToList(_languages, raw, (v) => _languages = v);
    });
  }

  void _removeLanguage(String s) {
    setState(() => _languages = _languages.where((x) => x != s).toList());
  }

  void _addClassLevel(String raw) {
    setState(() {
      _addToList(_classLevels, raw, (v) => _classLevels = v);
    });
  }

  void _removeClassLevel(String s) {
    setState(() => _classLevels = _classLevels.where((x) => x != s).toList());
  }

  void _addExam(String raw) {
    setState(() {
      _addToList(_exams, raw, (v) => _exams = v);
    });
  }

  void _removeExam(String s) {
    setState(() => _exams = _exams.where((x) => x != s).toList());
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
        AppToast.show('Could not read image', isError: true, context: context);
        return;
      }
      final name = file.name.toLowerCase();
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
      AppToast.show('Could not pick photo: $e', isError: true, context: context);
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
        AppToast.show(nameErr, isError: true, context: context);
        return;
      }
      final defaultTitle = file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name;
      if (!mounted) return;
      final title = await _promptTitle(defaultTitle);
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
      AppToast.show('Could not add certificate: $e', isError: true, context: context);
    } finally {
      if (mounted) setState(() => _isPickingCertificate = false);
    }
  }

  Future<String?> _promptTitle(String defaultTitle) {
    final c = TextEditingController(text: defaultTitle);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Certificate title'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. B.Ed'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String? _validate() {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.toLowerCase() == 'new teacher') {
      return 'Full Name required';
    }
    if (_subjects.isEmpty) return 'Add at least one Teaching Subject';
    if (_cityController.text.trim().isEmpty) return 'City required';
    if (_stateController.text.trim().isEmpty) return 'State required';
    if (_qualificationController.text.trim().isEmpty) {
      return 'Qualification required';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      AppToast.show(err, isError: true, context: context);
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
        fullName: _nameController.text.trim(),
        subject: TeacherProfileModel.joinSubjects(_subjects),
        bio: _bioController.text.trim(),
        qualification: _qualificationController.text.trim(),
        experienceYears: int.tryParse(_experienceController.text.trim()) ??
            widget.profile.experienceYears,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
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
      final saved =
          await GroupsRepository.instance.updateOwnTeacherProfile(updated);
      if (!mounted) return;
      AppToast.show(
        'Profile complete — next step: Get Verified (AI)',
        isError: false,
        context: context,
      );
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.show('Could not save: $e', isError: true, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final namePreview = _nameController.text.trim().isEmpty
        ? widget.profile.fullName
        : _nameController.text.trim();
    final incompleteMsg = _validate();
    final isComplete = incompleteMsg == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isComplete ? 'Teacher profile' : 'Complete teacher profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFF81C784)
                    : const Color(0xFFEF9A9A),
              ),
            ),
            child: Text(
              isComplete
                  ? 'Profile complete. Save → opens Get Verified (AI) → then Teacher plan. '
                      'Certificates on this page are optional for students.'
                  : 'Still needed: $incompleteMsg. Fill required fields — then Save opens Get Verified (AI).',
              style: TextStyle(
                color: isComplete
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFFB71C1C),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
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
                      InitialsAvatar(
                        name: namePreview,
                        photoUrl: _photoUrl,
                        size: 96,
                      ),
                    Material(
                      color: AppTheme.accentColor,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isPickingPhoto || _isSaving ? null : _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _isPickingPhoto || _isSaving ? null : _pickPhoto,
                  child: Text(
                    _photoUrl == null && _photoPreviewBytes == null
                        ? 'Add profile photo'
                        : 'Change photo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Full Name *',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use your original name exactly as on your education certificate '
            '(Get Verified matches this name).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Same spelling as on certificate',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Teaching subjects *',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search & pick, or type any custom subject (Custom first — no long chip list).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          const SizedBox(height: 8),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue tev) {
              final q = tev.text.trim().toLowerCase();
              if (q.isEmpty) {
                return kSubjectOptions.take(8);
              }
              return kSubjectOptions
                  .where((s) => s.toLowerCase().contains(q))
                  .where(
                    (s) => !_subjects
                        .any((x) => x.toLowerCase() == s.toLowerCase()),
                  )
                  .take(12);
            },
            onSelected: _addSubject,
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Search subject or type Custom…',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.borderRadius),
                        ),
                      ),
                      onSubmitted: (v) {
                        _addSubject(v);
                        controller.clear();
                        onFieldSubmitted();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      _addSubject(controller.text);
                      controller.clear();
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              final list = options.toList();
              if (list.isEmpty) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 220, maxWidth: 420),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final opt = list[i];
                        return ListTile(
                          dense: true,
                          title: Text(opt),
                          onTap: () => onSelected(opt),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          if (_subjects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _subjects)
                  InputChip(
                    label: Text(s),
                    onDeleted: () => _removeSubject(s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Teaching languages (optional)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add as many as you teach. Group create picks from this list.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
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
                    if (on) {
                      _addLanguage(l);
                    } else {
                      _removeLanguage(l);
                    }
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
                    _addLanguage(v);
                    _customLanguageController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  _addLanguage(_customLanguageController.text);
                  _customLanguageController.clear();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_languages
              .any((l) => !TeachingLanguages.all.contains(l))) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in _languages)
                  if (!TeachingLanguages.all.contains(l))
                    InputChip(
                      label: Text(l),
                      onDeleted: () => _removeLanguage(l),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Class / levels (optional)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'As many as you teach — Discover + Group use this list.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
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
                    if (on) {
                      _addClassLevel(c);
                    } else {
                      _removeClassLevel(c);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customClassController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Custom class / level…',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadius),
                    ),
                  ),
                  onSubmitted: (v) {
                    _addClassLevel(v);
                    _customClassController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  _addClassLevel(_customClassController.text);
                  _customClassController.clear();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_classLevels.any((c) => !ClassLevels.all.contains(c))) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _classLevels)
                  if (!ClassLevels.all.contains(c))
                    InputChip(
                      label: Text(c),
                      onDeleted: () => _removeClassLevel(c),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Board / Exam (optional)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'As many as you want — Discover filter uses this.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
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
                    if (on) {
                      _addExam(e);
                    } else {
                      _removeExam(e);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customExamController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Custom board / exam…',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadius),
                    ),
                  ),
                  onSubmitted: (v) {
                    _addExam(v);
                    _customExamController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  _addExam(_customExamController.text);
                  _customExamController.clear();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_exams.any((e) => !ExamBoards.all.contains(e))) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _exams)
                  if (!ExamBoards.all.contains(e))
                    InputChip(
                      label: Text(e),
                      onDeleted: () => _removeExam(e),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _field('City *', _cityController, hint: 'e.g. Pune'),
          const SizedBox(height: 14),
          _field('State *', _stateController, hint: 'e.g. Maharashtra'),
          const SizedBox(height: 14),
          _field('Qualification *', _qualificationController, hint: 'e.g. M.Sc Physics'),
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
            'Certificates (optional — students)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Simple PDF / photo for your profile if you want students to see it. '
            'This is NOT Get Verified. Trusted badge = separate AI Get Verified step.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showCertificatesOnProfile,
            onChanged: (v) => setState(() => _showCertificatesOnProfile = v),
            title: const Text('Show certificates on profile'),
            subtitle: Text(
              _showCertificatesOnProfile
                  ? 'ON — students can see uploaded certificates (e.g. Group Info)'
                  : 'OFF — certificates stay private (only you see them here)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
            activeColor: AppTheme.accentColor,
          ),
          const SizedBox(height: 8),
          for (final cert in _certificates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(cert.title),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _certificates =
                      _certificates.where((c) => c.id != cert.id).toList();
                }),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _isPickingCertificate ? null : _addCertificate,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Add profile certificate (optional)'),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save full profile'),
            ),
          ),
        ],
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
