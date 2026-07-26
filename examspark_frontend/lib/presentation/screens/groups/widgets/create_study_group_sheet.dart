import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/group_invite_qr_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Result of a successful Study Group create (form v1).
class CreatedStudyGroup {
  final String id;
  final String name;
  final String subject;
  final String joinCode;
  final bool isPublic;
  final String joinApprovalMode;

  const CreatedStudyGroup({
    required this.id,
    required this.name,
    required this.subject,
    required this.joinCode,
    required this.isPublic,
    this.joinApprovalMode = 'auto',
  });

  String get shareLink => AppBrand.inviteJoinUrl(joinCode);
}

/// Create Study Group — Subject/Class/Board/Language from Teacher Profile only
/// (Option A — Jul 26, 2026).
Future<CreatedStudyGroup?> showCreateStudyGroupSheet(
  BuildContext context, {
  String? suggestedSubject,
  TeacherProfileModel? profile,
}) {
  return showModalBottomSheet<CreatedStudyGroup>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CreateStudyGroupSheet(
      suggestedSubject: suggestedSubject,
      initialProfile: profile,
    ),
  );
}

class _CreateStudyGroupSheet extends StatefulWidget {
  final String? suggestedSubject;
  final TeacherProfileModel? initialProfile;

  const _CreateStudyGroupSheet({
    this.suggestedSubject,
    this.initialProfile,
  });

  @override
  State<_CreateStudyGroupSheet> createState() => _CreateStudyGroupSheetState();
}

class _CreateStudyGroupSheetState extends State<_CreateStudyGroupSheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  TeacherProfileModel? _profile;
  bool _loadingProfile = true;
  String? _profileError;

  String? _subject;
  String _classLevel = '';
  String _exam = '';
  String _language = '';
  static const bool _isPublic = true;
  String _joinApprovalMode = 'auto';
  bool _creating = false;
  CreatedStudyGroup? _created;

  List<String> get _subjects => _profile?.subjectsList ?? const [];
  List<String> get _classes => _profile?.classLevelsList ?? const [];
  List<String> get _exams => _profile?.examsList ?? const [];
  List<String> get _languages => _profile?.languagesList ?? const [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final p =
          widget.initialProfile ??
          await GroupsRepository.instance.fetchOwnTeacherProfile();
      if (!mounted) return;
      final subjects = p.subjectsList;
      String? subject;
      final suggested = (widget.suggestedSubject ?? '').trim();
      if (suggested.isNotEmpty) {
        final tokens = TeacherProfileModel.parseSubjects(suggested);
        final first = tokens.isNotEmpty ? tokens.first : suggested;
        for (final s in subjects) {
          if (s.toLowerCase() == first.toLowerCase()) {
            subject = s;
            break;
          }
        }
      }
      subject ??= subjects.isNotEmpty ? subjects.first : null;
      setState(() {
        _profile = p;
        _subject = subject;
        if (p.languagesList.length == 1) {
          _language = p.languagesList.first;
        }
        _loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_creating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final subject = (_subject ?? '').trim();
    if (subject.isEmpty) {
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text('Add subjects in Profile, then pick one here'),
        ),
      );
      return;
    }
    if (!_subjects.any((s) => s.toLowerCase() == subject.toLowerCase())) {
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text('Subject must be one from your Teacher Profile'),
        ),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final row = await ClassService.instance.createClass(
        name: _nameController.text.trim(),
        subject: subject,
        classLevel: _classLevel.isEmpty ? null : _classLevel,
        exam: _exam.isEmpty ? null : _exam,
        language: _language.isEmpty ? null : _language,
        isPublic: _isPublic,
        joinApprovalMode: _joinApprovalMode,
      );
      if (!mounted) return;
      final created = CreatedStudyGroup(
        id: row['id'] as String,
        name: row['name'] as String? ?? _nameController.text.trim(),
        subject: row['subject'] as String? ?? subject,
        joinCode: row['join_code'] as String? ?? '',
        isPublic: row['is_public'] as bool? ?? _isPublic,
        joinApprovalMode:
            (row['join_approval_mode'] as String?) ?? _joinApprovalMode,
      );
      setState(() {
        _created = created;
        _creating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      AppToast.showSnackBar(
        context,
        SnackBar(content: Text('Could not create group: $e')),
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
                      _created == null ? 'Create Study Group' : 'Group ready',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _created),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _created == null
                    ? _buildForm(context)
                    : _buildSuccess(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    if (_loadingProfile) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_profileError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_profileError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadProfile, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_subjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Add at least one Teaching Subject in Teacher Profile first. '
          'Group Subject can only be picked from your Profile.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB71C1C),
              ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject / Class / Board / Language come from your Teacher Profile only. '
            'To add more options, edit Profile first.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Basic',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Group Name *',
              hintText: 'e.g. NEET Biology Batch A',
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
            value: _subject != null && _subjects.contains(_subject)
                ? _subject
                : null,
            decoration: InputDecoration(
              labelText: 'Subject * (from Profile)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
            items: _subjects
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _subject = v),
            validator: (v) => v == null ? 'Subject required' : null,
          ),
          const SizedBox(height: 20),
          Text(
            'Academic (from Profile)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          _profileDropdown(
            label: 'Class / level',
            value: _classLevel,
            options: _classes,
            emptyHint: 'Add class levels in Profile',
            onChanged: (v) => setState(() => _classLevel = v ?? ''),
          ),
          const SizedBox(height: 12),
          _profileDropdown(
            label: 'Board / Exam',
            value: _exam,
            options: _exams,
            emptyHint: 'Add boards/exams in Profile',
            onChanged: (v) => setState(() => _exam = v ?? ''),
          ),
          const SizedBox(height: 12),
          _profileDropdown(
            label: 'Language',
            value: _language,
            options: _languages,
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
          const SizedBox(height: 4),
          Text(
            'Your choice for Free plan students using invite code / link. '
            'Paid students join instantly either way.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
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
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              setState(() => _joinApprovalMode = s.first);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _creating ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Group'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileDropdown({
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

  Widget _buildSuccess(BuildContext context) {
    final created = _created!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 48),
        const SizedBox(height: 12),
        Text(
          created.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          created.subject,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.getSecondaryText(context)),
        ),
        const SizedBox(height: 16),
        SelectableText(
          'Invite code: ${created.joinCode}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        SelectableText(
          created.shareLink,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Center(
          child: QrImageView(
            data: created.shareLink,
            size: 160,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: created.shareLink));
            AppToast.showSnackBar(
              context,
              const SnackBar(content: Text('Invite link copied')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy invite link'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => showGroupInviteQrSheet(
            context,
            invite: GroupInviteQrData.fromCode(
              groupName: created.name,
              joinCode: created.joinCode,
            ),
          ),
          child: const Text('Larger QR'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, created),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
