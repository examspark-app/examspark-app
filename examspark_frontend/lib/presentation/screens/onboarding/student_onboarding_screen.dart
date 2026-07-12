import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/avatar_colors.dart';
import 'package:examspark_frontend/core/constants/education_levels.dart';
import 'package:examspark_frontend/core/constants/subjects.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// "Tell us about yourself" — shown once, right after a student's first
/// login (gated by `users.onboarding_completed` in `AuthGate`). Teachers
/// never see this; they set up their profile from the Teacher Dashboard.
class StudentOnboardingScreen extends StatefulWidget {
  const StudentOnboardingScreen({super.key, required this.userId, required this.onDone});

  final String userId;

  /// Called once onboarding is saved or skipped, so `AuthGate` can move on
  /// to `AppShell` without waiting for a full profile re-fetch.
  final VoidCallback onDone;

  @override
  State<StudentOnboardingScreen> createState() => _StudentOnboardingScreenState();
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
  final Set<String> _selectedSubjects = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ageController = FixedExtentScrollController(initialItem: _defaultAge - _minAge);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseClient.instance.completeStudentOnboarding(
        userId: widget.userId,
        username: _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
        avatarColor: colorToHex(_avatarColor),
        age: _selectedAge,
        educationLevel: _educationLevel,
        subjects: _selectedSubjects.toList(),
      );
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseClient.instance.skipStudentOnboarding(widget.userId);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not skip: ${e.toString()}')),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tell us about yourself',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _skip,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'This helps us personalize your learning experience.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar preview + colour picker
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(color: _avatarColor, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        spacing: 10,
                        children: kAvatarColors.map((color) {
                          final isSelected = color.toARGB32() == _avatarColor.toARGB32();
                          return GestureDetector(
                            onTap: () => setState(() => _avatarColor = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: AppTheme.getPrimaryText(context), width: 2)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text('Username', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g. rahul_2027',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: AppTheme.getCardBackground(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text('How old are you?', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    _buildAgePicker(context),
                    const SizedBox(height: 28),

                    Text('Education level', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kEducationLevels.map((level) {
                        final isSelected = _educationLevel == level;
                        return ChoiceChip(
                          label: Text(level),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _educationLevel = level),
                          selectedColor: AppTheme.accentColor,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.getPrimaryText(context)),
                          backgroundColor: AppTheme.getCardBackground(context),
                          side: BorderSide(color: AppTheme.getCardBorder(context)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    Text('Subjects you\'re interested in', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kSubjectOptions.map((subject) {
                        final isSelected = _selectedSubjects.contains(subject);
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
                          labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.getPrimaryText(context)),
                          backgroundColor: AppTheme.getCardBackground(context),
                          side: BorderSide(color: AppTheme.getCardBorder(context)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finish,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Finish Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ChatGPT/iOS-style scroll wheel age picker — no Cupertino import needed,
  /// `ListWheelScrollView` keeps it visually consistent with the rest of
  /// the (Material) app.
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
            onSelectedItemChanged: (index) => setState(() => _selectedAge = _minAge + index),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.accentColor : AppTheme.getSecondaryText(context),
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
                  top: BorderSide(color: AppTheme.getAccentTint(context), width: 1),
                  bottom: BorderSide(color: AppTheme.getAccentTint(context), width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
