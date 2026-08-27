import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/avatar_colors.dart';
import 'package:examspark_frontend/core/constants/custom_field_option.dart';
import 'package:examspark_frontend/core/constants/education_levels.dart';
import 'package:examspark_frontend/core/constants/exam_boards.dart';
import 'package:examspark_frontend/core/constants/subjects.dart';
import 'package:examspark_frontend/core/constants/teaching_languages.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Student profile form — first-time after "I'm a Student", or Edit from Profile.
///
/// Two stages:
///  • Stage 1 (mandatory): Username, City, Preferred language. Cannot skip.
///    Completing only this and skipping Stage 2 still awards the base
///    onboarding credit reward (decided server-side in
///    `completeStudentOnboarding`).
///  • Stage 2 (optional): Age, Education level, Exam/board, Subjects.
///    Every field here is individually skippable, and the whole stage can
///    be skipped with one tap. Filling it out fully unlocks the larger
///    "complete profile" credit bonus, awarded server-side.
///
/// Teachers never use this (Teacher Dashboard path only).
class StudentOnboardingScreen extends StatefulWidget {
  const StudentOnboardingScreen({
    super.key,
    required this.userId,
    required this.onDone,
    this.isEditing = false,
  });

  final String userId;

  /// Called once saved, so `AuthGate` / Profile can continue.
  final VoidCallback onDone;

  /// Profile → Edit profile (load existing; both stages shown, nothing
  /// forced — editing an existing profile never re-locks Stage 2).
  final bool isEditing;

  @override
  State<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends State<StudentOnboardingScreen> {
  static const int _minAge = 10;
  static const int _maxAge = 60;
  static const int _defaultAge = 16;

  final _usernameController = TextEditingController();
  final _cityController = TextEditingController();
  late final FixedExtentScrollController _ageController;

  Color _avatarColor = kAvatarColors.first;
  int _selectedAge = _defaultAge;
  String? _educationLevel;
  String _examTarget = '';
  String _preferredLanguage = '';
  final _customExamController = TextEditingController();
  final _customLanguageController = TextEditingController();
  final _customSubjectController = TextEditingController();
  final Set<String> _selectedSubjects = {};

  bool _isSaving = false;
  bool _loadingExisting = false;

  /// 0 = mandatory basics, 1 = optional personalisation.
  /// Editing an existing profile opens straight into the full view so
  /// nothing feels re-locked.
  late int _stage = widget.isEditing ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _ageController = FixedExtentScrollController(
      initialItem: _defaultAge - _minAge,
    );
    if (widget.isEditing) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final bundle = await SupabaseClient.instance.fetchStudentOnboardingBundle(
        widget.userId,
      );
      final users = bundle['users'] as Map<String, dynamic>? ?? {};
      final sp = bundle['student_profiles'] as Map<String, dynamic>?;

      final username = (users['username'] as String?)?.trim() ?? '';
      if (username.isNotEmpty) _usernameController.text = username;
      _avatarColor = hexToColor(users['avatar_color'] as String?);

      final age = (sp?['age'] as num?)?.toInt();
      if (age != null && age >= _minAge && age <= _maxAge) {
        _selectedAge = age;
        final idx = age - _minAge;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ageController.hasClients) {
            _ageController.jumpToItem(idx);
          }
        });
      }

      _educationLevel = sp?['education_level'] as String?;
      _cityController.text = (sp?['city'] as String?)?.trim() ?? '';

      final examSplit = CustomFieldOption.split(
        sp?['exam_target'] as String?,
        ExamBoards.all,
      );
      _examTarget = examSplit.dropdown;
      _customExamController.text = examSplit.custom;

      final langSplit = CustomFieldOption.split(
        sp?['preferred_language'] as String?,
        TeachingLanguages.all,
      );
      _preferredLanguage = langSplit.dropdown;
      _customLanguageController.text = langSplit.custom;

      final subjects = sp?['subjects'];
      if (subjects is List) {
        _selectedSubjects
          ..clear()
          ..addAll(
            subjects.map((e) => e.toString()).where((s) => s.isNotEmpty),
          );
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Empty form OK — user can fill minimum.
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _cityController.dispose();
    _customExamController.dispose();
    _customLanguageController.dispose();
    _customSubjectController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _addCustomSubject() {
    final s = _customSubjectController.text.trim();
    if (s.isEmpty) return;
    setState(() {
      _selectedSubjects.add(s);
      _customSubjectController.clear();
    });
  }

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  /// Only the three Stage-1 fields are ever mandatory.
  String? _validateStage1() {
    if (_usernameController.text.trim().isEmpty) {
      return 'Enter a username';
    }
    if (_cityController.text.trim().isEmpty) {
      return 'Enter your city';
    }
    final lang = CustomFieldOption.resolve(
      _preferredLanguage.isEmpty ? null : _preferredLanguage,
      _customLanguageController.text,
    );
    if (lang == null || lang.isEmpty) {
      return 'Pick your preferred language';
    }
    if (_preferredLanguage == CustomFieldOption.label &&
        _customLanguageController.text.trim().isEmpty) {
      return 'Enter your language, or pick one from the list';
    }
    return null;
  }

  /// Stage 2 has no required fields — this only guards the "Custom…"
  /// text inputs, so a half-typed custom value can't be silently lost.
  String? _validateStage2() {
    if (_examTarget == CustomFieldOption.label &&
        _customExamController.text.trim().isEmpty) {
      return 'Enter your custom exam / board, or pick another option';
    }
    return null;
  }

  double get _profileCompletion {
    var complete = 1; // Stage 1 fields count together once reached.
    const total = 5; // username+city+language (as one), age, education, exam/subjects, done
    if (_selectedAge >= _minAge && _selectedAge <= _maxAge) complete++;
    if (_educationLevel?.trim().isNotEmpty == true) complete++;
    final exam = CustomFieldOption.resolve(
      _examTarget.isEmpty ? null : _examTarget,
      _customExamController.text,
    );
    if (exam?.isNotEmpty == true) complete++;
    if (_selectedSubjects.isNotEmpty) complete++;
    return complete / total;
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  void _continueToStage2() {
    final err = _validateStage1();
    if (err != null) {
      AppToast.showSnackBar(context, SnackBar(content: Text(err)));
      return;
    }
    setState(() => _stage = 1);
  }

  Future<void> _finish() async {
    final stage1Err = _validateStage1();
    if (stage1Err != null) {
      setState(() => _stage = 0);
      AppToast.showSnackBar(context, SnackBar(content: Text(stage1Err)));
      return;
    }
    final stage2Err = _validateStage2();
    if (stage2Err != null) {
      AppToast.showSnackBar(context, SnackBar(content: Text(stage2Err)));
      return;
    }

    await _save();
  }

  /// Skips every optional field. Still valid, since Stage 1 already
  /// guarantees username + city + language are set.
  Future<void> _skipRestAndFinish() async {
    setState(() {
      _educationLevel = null;
      _examTarget = '';
      _customExamController.clear();
      _selectedSubjects.clear();
    });
    await _save();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final exam = CustomFieldOption.resolve(
        _examTarget.isEmpty ? null : _examTarget,
        _customExamController.text,
      );
      final lang = CustomFieldOption.resolve(
        _preferredLanguage.isEmpty ? null : _preferredLanguage,
        _customLanguageController.text,
      );
      await SupabaseClient.instance.completeStudentOnboarding(
        userId: widget.userId,
        username: _usernameController.text.trim(),
        avatarColor: colorToHex(_avatarColor),
        age: _selectedAge,
        educationLevel: _educationLevel,
        subjects: _selectedSubjects.toList(),
        examTarget: exam,
        preferredLanguage: lang,
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
      );
      widget.onDone();
    } catch (e) {
      if (mounted) {
        AppToast.showSnackBar(
          context,
          SnackBar(content: Text('Could not save profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(
              title: const Text('Edit profile'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.isEditing) _stepIndicator(context),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _stage == 0
                    ? _stage1View(context)
                    : _stage2View(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Step indicator -----------------------------------------------------

  Widget _stepIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Row(
        children: [
          Expanded(
            child: _stepSegment(
              context,
              label: 'Basics',
              active: true,
              filled: true,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _stepSegment(
              context,
              label: 'Personalise',
              active: _stage == 1,
              filled: _stage == 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepSegment(
    BuildContext context, {
    required String label,
    required bool active,
    required bool filled,
  }) {
    final color = active
        ? AppTheme.accentColor
        : AppTheme.getCardBorder(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(height: 4, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? AppTheme.getPrimaryText(context)
                : AppTheme.getSecondaryText(context),
          ),
        ),
      ],
    );
  }

  // -- Stage 1: mandatory basics -------------------------------------------

  Widget _stage1View(BuildContext context) {
    final canContinue = _validateStage1() == null;
    return Column(
      key: const ValueKey('stage1'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Let's set you up",
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 24,
                    color: AppTheme.getPrimaryText(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Three quick things — everything after this is optional.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                Center(child: _avatarPicker(context)),
                const SizedBox(height: 32),
                _fieldLabel(context, 'Username'),
                const SizedBox(height: 8),
                _styledTextField(
                  context,
                  controller: _usernameController,
                  hint: 'e.g. rahul_2027',
                  icon: Icons.person_outline_rounded,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                _fieldLabel(context, 'City'),
                const SizedBox(height: 8),
                _styledTextField(
                  context,
                  controller: _cityController,
                  hint: 'e.g. Kolkata, Pune, London',
                  icon: Icons.location_city_outlined,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                _fieldLabel(context, 'Preferred language'),
                const SizedBox(height: 8),
                _styledDropdown(
                  context,
                  hint: 'Select language',
                  value: _preferredLanguage.isEmpty ? null : _preferredLanguage,
                  items: TeachingLanguages.withCustom,
                  onChanged: (v) => setState(() => _preferredLanguage = v ?? ''),
                ),
                if (_preferredLanguage == CustomFieldOption.label) ...[
                  const SizedBox(height: 12),
                  _styledTextField(
                    context,
                    controller: _customLanguageController,
                    hint: 'Type your language',
                    onChanged: (_) => setState(() {}),
                    capitalizeWords: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        _bottomBar(
          context,
          child: ElevatedButton(
            onPressed: canContinue ? _continueToStage2 : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  // -- Stage 2: optional personalisation -----------------------------------

  Widget _stage2View(BuildContext context) {
    return Column(
      key: const ValueKey('stage2'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
          child: Row(
            children: [
              if (!widget.isEditing)
                IconButton(
                  onPressed: () => setState(() => _stage = 0),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.getSecondaryText(context),
                  ),
                  tooltip: 'Back',
                ),
              Expanded(
                child: Text(
                  'Make it yours',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 22,
                    color: AppTheme.getPrimaryText(context),
                  ),
                ),
              ),
              if (!widget.isEditing)
                TextButton(
                  onPressed: _isSaving ? null : _skipRestAndFinish,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppTheme.getSecondaryText(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Optional — helps us tailor lessons and recommendations.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.getSecondaryText(context),
                height: 1.4,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(context, 'Age'),
                const SizedBox(height: 8),
                _buildAgePicker(context),
                const SizedBox(height: 28),
                _fieldLabel(context, 'Education level'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kEducationLevels.map((level) {
                    return _selectablePill(
                      context,
                      label: level,
                      selected: _educationLevel == level,
                      onTap: () => setState(() {
                        _educationLevel = _educationLevel == level
                            ? null
                            : level;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                _fieldLabel(context, 'Exam / board'),
                const SizedBox(height: 8),
                _styledDropdown(
                  context,
                  hint: 'Not preparing for one right now',
                  value: _examTarget.isEmpty ? null : _examTarget,
                  items: ExamBoards.withCustom,
                  allowClear: true,
                  onChanged: (v) => setState(() => _examTarget = v ?? ''),
                ),
                if (_examTarget == CustomFieldOption.label) ...[
                  const SizedBox(height: 12),
                  _styledTextField(
                    context,
                    controller: _customExamController,
                    hint: 'e.g. A-Levels, local board, SAT',
                    onChanged: (_) => setState(() {}),
                    capitalizeWords: true,
                  ),
                ],
                const SizedBox(height: 28),
                _fieldLabel(context, 'Subjects you\'re interested in'),
                const SizedBox(height: 4),
                Text(
                  'Presets or add your own below.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...kSubjectOptions.map((subject) {
                      final isSelected = _selectedSubjects.contains(subject);
                      return _selectablePill(
                        context,
                        label: subject,
                        selected: isSelected,
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedSubjects.remove(subject);
                          } else {
                            _selectedSubjects.add(subject);
                          }
                        }),
                      );
                    }),
                    ..._selectedSubjects
                        .where((s) => !kSubjectOptions.contains(s))
                        .map(
                          (s) => _selectablePill(
                            context,
                            label: s,
                            selected: true,
                            onTap: () =>
                                setState(() => _selectedSubjects.remove(s)),
                            trailingIcon: Icons.close_rounded,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _styledTextField(
                        context,
                        controller: _customSubjectController,
                        hint: 'Add a subject',
                        capitalizeWords: true,
                        onSubmitted: (_) => _addCustomSubject(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addCustomSubject,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _bottomBar(
          context,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _finish,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isEditing ? 'Save profile' : 'Finish setup'),
          ),
        ),
      ],
    );
  }

  // -- Shared building blocks ----------------------------------------------

  Widget _bottomBar(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.getCardBorder(context), width: 1),
        ),
      ),
      child: child,
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.getPrimaryText(context),
      ),
    );
  }

  /// Avatar with a thin progress ring showing overall completion —
  /// replaces a separate generic "completion card".
  Widget _avatarPicker(BuildContext context) {
    final initial = _usernameController.text.trim().isNotEmpty
        ? _usernameController.text.trim()[0].toUpperCase()
        : 'S';

    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _profileCompletion,
                  strokeWidth: 3,
                  backgroundColor: AppTheme.getCardBorder(context),
                  valueColor: AlwaysStoppedAnimation(AppTheme.accentColor),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _avatarColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          alignment: WrapAlignment.center,
          children: kAvatarColors.map((color) {
            final isSelected = color.toARGB32() == _avatarColor.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _avatarColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.getPrimaryText(context),
                          width: 2,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: .45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _styledTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    bool capitalizeWords = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textCapitalization: capitalizeWords
            ? TextCapitalization.words
            : TextCapitalization.none,
        style: TextStyle(color: AppTheme.getPrimaryText(context)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.getSecondaryText(context)),
          prefixIcon: icon != null
              ? Icon(icon, color: AppTheme.getSecondaryText(context), size: 20)
              : null,
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _styledDropdown(
    BuildContext context, {
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool allowClear = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: value,
          hint: Text(
            hint,
            style: TextStyle(color: AppTheme.getSecondaryText(context)),
          ),
          style: TextStyle(color: AppTheme.getPrimaryText(context)),
          dropdownColor: AppTheme.getCardBackground(context),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.getSecondaryText(context),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: [
            if (allowClear)
              const DropdownMenuItem(value: '', child: Text('Skip for now')),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _selectablePill(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentColor
              : AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accentColor : AppTheme.getCardBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && trailingIcon == null) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.getPrimaryText(context),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 5),
              Icon(trailingIcon, size: 15, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgePicker(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        border: Border.all(color: AppTheme.getCardBorder(context)),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListWheelScrollView.useDelegate(
            controller: _ageController,
            itemExtent: 38,
            diameterRatio: 1.7,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) =>
                setState(() => _selectedAge = _minAge + index),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: _maxAge - _minAge + 1,
              builder: (context, index) {
                final age = _minAge + index;
                final isSelected = age == _selectedAge;
                return Center(
                  child: Text(
                    '$age',
                    style: TextStyle(
                      fontSize: isSelected ? 21 : 15,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w400,
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.getSecondaryText(context),
                    ),
                  ),
                );
              },
            ),
          ),
          IgnorePointer(
            child: Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.accentColor.withValues(alpha: .35)),
                  bottom: BorderSide(color: AppTheme.accentColor.withValues(alpha: .35)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}