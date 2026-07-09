import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/audio_level_indicator.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/camera_preview_placeholder.dart';

/// Screen 1: Recording Setup — configure subject & topic before recording.
class RecordingSetupScreen extends StatefulWidget {
  const RecordingSetupScreen({super.key});

  @override
  State<RecordingSetupScreen> createState() => _RecordingSetupScreenState();
}

class _RecordingSetupScreenState extends State<RecordingSetupScreen> {
  static const _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'History',
    'English',
    'Economics',
    'Other',
  ];

  final _topicController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedSubject;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Setup'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prepare your lecture',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up your camera and enter lecture details before you start.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      const CameraPreviewPlaceholder(),
                      const SizedBox(height: 12),
                      const AudioLevelIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'Subject',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSubject,
                        decoration: _inputDecoration(context, hint: 'Select a subject'),
                        items: _subjects
                            .map(
                              (subject) => DropdownMenuItem(
                                value: subject,
                                child: Text(subject),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _selectedSubject = value),
                        validator: (value) =>
                            value == null ? 'Please select a subject' : null,
                      ),
                      const SizedBox(height: AppTheme.elementSpacing),
                      Text(
                        'Lecture Topic',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _topicController,
                        decoration: _inputDecoration(
                          context,
                          hint: 'e.g. Introduction to Calculus',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a lecture topic';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _handleStartRecording,
                  icon: const Icon(Icons.fiber_manual_record, size: 20),
                  label: const Text('Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.getCardBackground(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        borderSide: BorderSide(color: AppTheme.getCardBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        borderSide: BorderSide(color: AppTheme.getCardBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        borderSide: const BorderSide(color: AppTheme.accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  void _handleStartRecording() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Starting recording: $_selectedSubject — ${_topicController.text.trim()}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
