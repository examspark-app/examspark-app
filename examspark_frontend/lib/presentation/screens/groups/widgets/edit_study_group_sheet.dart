import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Result after teacher saves Study Group edits.
class EditedStudyGroup {
  final String id;
  final String name;
  final String subject;
  final String joinApprovalMode;

  const EditedStudyGroup({
    required this.id,
    required this.name,
    required this.subject,
    required this.joinApprovalMode,
  });
}

/// Edit Study Group — Subject/Class/Board/Language from Teacher Profile only
/// (Option A). Legacy values not on Profile stay selectable until changed.
Future<EditedStudyGroup?> showEditStudyGroupSheet(
  BuildContext context, {
  required String classId,
}) {
  return showModalBottomSheet<EditedStudyGroup>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EditStudyGroupSheet(classId: classId),
  );
}

class _EditStudyGroupSheet extends StatefulWidget {
  final String classId;

  const _EditStudyGroupSheet({required this.classId});

  @override
  State<_EditStudyGroupSheet> createState() => _EditStudyGroupSheetState();
}

class _EditStudyGroupSheetState extends State<_EditStudyGroupSheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  TeacherProfileModel? _profile;
  List<String> _subjectOptions = const [];
  List<String> _classOptions = const [];
  List<String> _examOptions = const [];
  List<String> _languageOptions = const [];

  String? _subject;
  String _classLevel = '';
  String _exam = '';
  String _language = '';
  String _joinApprovalMode = 'auto';
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<String> _withLegacy(List<String> profileOpts, String? stored) {
    final v = (stored ?? '').trim();
    if (v.isEmpty) return profileOpts;
    if (profileOpts.any((p) => p.toLowerCase() == v.toLowerCase())) {
      return profileOpts;
    }
    return [v, ...profileOpts];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ClassService.instance.getClassById(widget.classId),
        GroupsRepository.instance.fetchOwnTeacherProfile(),
      ]);
      if (!mounted) return;
      final row = results[0] as Map<String, dynamic>?;
      final profile = results[1] as TeacherProfileModel;
      if (row == null) {
        setState(() {
          _loading = false;
          _loadError = 'Group not found';
        });
        return;
      }

      final storedSubject = (row['subject'] as String?)?.trim() ?? '';
      final storedClass = (row['class_level'] as String?)?.trim() ?? '';
      final storedExam = (row['exam'] as String?)?.trim() ?? '';
      final storedLang = (row['language'] as String?)?.trim() ?? '';

      _nameController.text = (row['name'] as String?) ?? '';
      final subjectOpts = _withLegacy(profile.subjectsList, storedSubject);
      final classOpts = _withLegacy(profile.classLevelsList, storedClass);
      final examOpts = _withLegacy(profile.examsList, storedExam);
      final langOpts = _withLegacy(profile.languagesList, storedLang);

      final mode = (row['join_approval_mode'] as String?) ?? 'auto';

      setState(() {
        _profile = profile;
        _subjectOptions = subjectOpts;
        _classOptions = classOpts;
        _examOptions = examOpts;
        _languageOptions = langOpts;
        _subject = storedSubject.isEmpty ? null : storedSubject;
        _classLevel = storedClass;
        _exam = storedExam;
        _language = storedLang;
        _joinApprovalMode = mode == 'approval' ? 'approval' : 'auto';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final subject = (_subject ?? '').trim();
    if (subject.isEmpty) {
      AppToast.showSnackBar(
        context,
        const SnackBar(content: Text('Choose one subject from your Profile')),
      );
      return;
    }
    final profileSubjects = _profile?.subjectsList ?? const [];
    final allowed = profileSubjects.any(
          (s) => s.toLowerCase() == subject.toLowerCase(),
        ) ||
        // Allow saving current legacy once if still selected
        _subjectOptions.contains(subject);
    if (!allowed) {
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text('Subject must be on your Teacher Profile'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final row = await ClassService.instance.updateClass(
        classId: widget.classId,
        name: _nameController.text.trim(),
        subject: subject,
        classLevel: _classLevel.isEmpty ? null : _classLevel,
        exam: _exam.isEmpty ? null : _exam,
        language: _language.isEmpty ? null : _language,
        joinApprovalMode: _joinApprovalMode,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        EditedStudyGroup(
          id: row['id'] as String? ?? widget.classId,
          name: row['name'] as String? ?? _nameController.text.trim(),
          subject: row['subject'] as String? ?? subject,
          joinApprovalMode:
              (row['join_approval_mode'] as String?) ?? _joinApprovalMode,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      'Edit Study Group',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _loadError != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(_loadError!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: _buildForm(context),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final profileEmpty = (_profile?.subjectsList ?? const []).isEmpty;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject / Class / Board / Language from Teacher Profile. '
            'Values only on this group (not Profile) stay until you change them.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          if (profileEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Add subjects on Profile so new picks stay in sync with Discover.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB71C1C),
                  ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Group Name *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Group name required';
              if (v.trim().length < 3) return 'Name too short';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _subject != null && _subjectOptions.contains(_subject)
                ? _subject
                : null,
            decoration: InputDecoration(
              labelText: 'Subject *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
            items: _subjectOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _subject = v),
            validator: (v) => v == null ? 'Subject required' : null,
          ),
          const SizedBox(height: 12),
          _optionalDropdown(
            label: 'Class / level',
            value: _classLevel,
            options: _classOptions,
            emptyHint: 'Add class levels in Profile',
            onChanged: (v) => setState(() => _classLevel = v ?? ''),
          ),
          const SizedBox(height: 12),
          _optionalDropdown(
            label: 'Board / Exam',
            value: _exam,
            options: _examOptions,
            emptyHint: 'Add boards/exams in Profile',
            onChanged: (v) => setState(() => _exam = v ?? ''),
          ),
          const SizedBox(height: 12),
          _optionalDropdown(
            label: 'Language',
            value: _language,
            options: _languageOptions,
            emptyHint: 'Add languages in Profile',
            onChanged: (v) => setState(() => _language = v ?? ''),
          ),
          const SizedBox(height: 20),
          Text(
            'Free student joins',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'auto',
                label: Text('Auto'),
                icon: Icon(Icons.bolt_outlined, size: 16),
              ),
              ButtonSegment<String>(
                value: 'approval',
                label: Text('Approve'),
                icon: Icon(Icons.how_to_reg_outlined, size: 16),
              ),
            ],
            selected: {_joinApprovalMode},
            onSelectionChanged: (s) =>
                setState(() => _joinApprovalMode = s.first),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionalDropdown({
    required String label,
    required String value,
    required List<String> options,
    required String emptyHint,
    required ValueChanged<String?> onChanged,
  }) {
    if (options.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
        ),
        child: Text(
          emptyHint,
          style: TextStyle(color: AppTheme.getSecondaryText(context)),
        ),
      );
    }
    final safe = options.contains(value) ? value : '';
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: safe.isEmpty ? '' : safe,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('—')),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
      onChanged: onChanged,
    );
  }
}
