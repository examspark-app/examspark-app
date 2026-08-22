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
/// No Skip: minimum = username · education · language · ≥1 subject.
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

  /// Profile → Edit profile (load existing; Save closes).
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
  late final FixedExtentScrollController _ageController;
  Color _avatarColor = kAvatarColors.first;
  int _selectedAge = _defaultAge;
  String? _educationLevel;
  String _examTarget = '';
  String _preferredLanguage = '';
  final _cityController = TextEditingController();
  final _customExamController = TextEditingController();
  final _customLanguageController = TextEditingController();
  final _customSubjectController = TextEditingController();
  final Set<String> _selectedSubjects = {};
  bool _isSaving = false;
  bool _loadingExisting = false;

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

  String? _validateMinimum() {
    if (_usernameController.text.trim().isEmpty) {
      return 'Enter a username';
    }
    if (_educationLevel == null || _educationLevel!.trim().isEmpty) {
      return 'Pick your education level';
    }
    final lang = CustomFieldOption.resolve(
      _preferredLanguage.isEmpty ? null : _preferredLanguage,
      _customLanguageController.text,
    );
    if (lang == null || lang.isEmpty) {
      return 'Pick a preferred language (or Custom…)';
    }
    if (_selectedSubjects.isEmpty) {
      return 'Pick at least one subject';
    }
    final exam = CustomFieldOption.resolve(
      _examTarget.isEmpty ? null : _examTarget,
      _customExamController.text,
    );
    if (exam == null || exam.isEmpty) {
      return 'Pick your exam or board';
    }
    if (_cityController.text.trim().isEmpty) {
      return 'Enter your city';
    }
    if (_examTarget == CustomFieldOption.label &&
        _customExamController.text.trim().isEmpty) {
      return 'Enter custom exam / board, or pick another option';
    }
    return null;
  }

  double get _profileCompletion {
    var complete = 0;
    if (_usernameController.text.trim().isNotEmpty) complete++;
    if (_selectedAge >= _minAge && _selectedAge <= _maxAge) complete++;
    if (_educationLevel?.trim().isNotEmpty == true) complete++;
    final language = CustomFieldOption.resolve(
      _preferredLanguage.isEmpty ? null : _preferredLanguage,
      _customLanguageController.text,
    );
    if (language?.isNotEmpty == true) complete++;
    if (_selectedSubjects.isNotEmpty) complete++;
    final exam = CustomFieldOption.resolve(
      _examTarget.isEmpty ? null : _examTarget,
      _customExamController.text,
    );
    if (exam?.isNotEmpty == true) complete++;
    if (_cityController.text.trim().isNotEmpty) complete++;
    return complete / 7;
  }

  Future<void> _finish() async {
    final err = _validateMinimum();
    if (err != null) {
      AppToast.showSnackBar(context, SnackBar(content: Text(err)));
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final initial = _usernameController.text.trim().isNotEmpty
        ? _usernameController.text.trim()[0].toUpperCase()
        : 'S';

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
            if (!widget.isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tell us about yourself',
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 22),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.isEditing
                      ? 'Keep your learning profile up to date. Required fields are marked *.'
                      : 'Add a few details so Sonaxia can personalise your learning. Required fields are marked *.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _completionCard(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: _avatarColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        spacing: 10,
                        children: kAvatarColors.map((color) {
                          final isSelected =
                              color.toARGB32() == _avatarColor.toARGB32();
                          return GestureDetector(
                            onTap: () => setState(() => _avatarColor = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: AppTheme.getPrimaryText(context),
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Username *',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g. rahul_2027',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text('Age *', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your age to help us tailor examples and difficulty.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAgePicker(context),
                    const SizedBox(height: 28),

                    Text(
                      'Education level *',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kEducationLevels.map((level) {
                        final isSelected = _educationLevel == level;
                        return ChoiceChip(
                          label: Text(level),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _educationLevel = level),
                          selectedColor: AppTheme.accentColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.getPrimaryText(context),
                          ),
                          backgroundColor: AppTheme.getCardBackground(context),
                          side: BorderSide(
                            color: AppTheme.getCardBorder(context),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Exam / board *',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose the exam or board you are preparing for.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _examTarget.isEmpty ? '' : _examTarget,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Skip exam for now'),
                        ),
                        ...ExamBoards.withCustom.map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _examTarget = v ?? ''),
                    ),
                    if (_examTarget == CustomFieldOption.label) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customExamController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Custom exam / board',
                          hintText: 'e.g. A-Levels, local board, SAT',
                          filled: true,
                          fillColor: AppTheme.getCardBackground(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.borderRadius,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    Text(
                      'Preferred language *',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _preferredLanguage.isEmpty
                          ? null
                          : _preferredLanguage,
                      decoration: InputDecoration(
                        hintText: 'Select language',
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                        ),
                      ),
                      items: [
                        ...TeachingLanguages.withCustom.map(
                          (l) => DropdownMenuItem(value: l, child: Text(l)),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _preferredLanguage = v ?? ''),
                    ),
                    if (_preferredLanguage == CustomFieldOption.label) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customLanguageController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Custom language',
                          filled: true,
                          fillColor: AppTheme.getCardBackground(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.borderRadius,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    Text(
                      'City *',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Kolkata / Pune / London',
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Subjects you\'re interested in *',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick at least one — presets or Custom below.',
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
                          final isSelected = _selectedSubjects.contains(
                            subject,
                          );
                          return FilterChip(
                            label: Text(subject),
                            selected: isSelected,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _selectedSubjects.add(subject);
                              } else {
                                _selectedSubjects.remove(subject);
                              }
                            }),
                            selectedColor: AppTheme.accentColor,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.getPrimaryText(context),
                            ),
                            backgroundColor: AppTheme.getCardBackground(
                              context,
                            ),
                            side: BorderSide(
                              color: AppTheme.getCardBorder(context),
                            ),
                          );
                        }),
                        ..._selectedSubjects
                            .where((s) => !kSubjectOptions.contains(s))
                            .map(
                              (s) => InputChip(
                                label: Text(s),
                                onDeleted: () =>
                                    setState(() => _selectedSubjects.remove(s)),
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customSubjectController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Custom subject — type & Add',
                              filled: true,
                              fillColor: AppTheme.getCardBackground(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.borderRadius,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _addCustomSubject(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addCustomSubject,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finish,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
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
                    : Text(widget.isEditing ? 'Save profile' : 'Finish Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completionCard(BuildContext context) {
    final percent = (_profileCompletion * 100).round();
    final complete = percent == 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getAccentTint(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complete ? 'Full profile setup' : 'Profile setup progress',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _profileCompletion,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .65),
              color: AppTheme.accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Great! Your profile is ready for a personalised experience.'
                : 'Complete the required details for better recommendations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildAgePicker(BuildContext context) {
    return Container(
      height: 120,
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
            itemExtent: 40,
            diameterRatio: 1.6,
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
                      fontSize: isSelected ? 22 : 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.getAccentTint(context),
                    width: 1,
                  ),
                  bottom: BorderSide(
                    color: AppTheme.getAccentTint(context),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
