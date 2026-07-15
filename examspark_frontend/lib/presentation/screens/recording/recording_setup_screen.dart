import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/plan_tier_gating.dart';
import 'package:examspark_frontend/core/constants/subjects.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/router/app_navigation.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/audio_level_indicator.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/camera_preview_placeholder.dart';

class RecordingSetupScreen extends StatefulWidget {
  /// Forwarded to [RecorderScreen] so it can pre-select the matching
  /// upload tab (e.g. Home's "Image / Photo" attach option should land
  /// directly on the Upload Document/Photo tab, not the default Record tab).
  final String? initialInputMethod;

  const RecordingSetupScreen({super.key, this.initialInputMethod});

  @override
  State<RecordingSetupScreen> createState() => _RecordingSetupScreenState();
}

class _RecordingSetupScreenState extends State<RecordingSetupScreen> {
  static const _subjects = kSubjectOptions;

  final _topicController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  bool? _audioUnlocked;

  /// This screen used to always look like "starting a recording" (camera +
  /// mic preview, "Start Recording" button) even for a plain PDF/photo/audio
  /// upload — confusing since Home's "Upload" attach option routed here
  /// first. Only show the recording-specific preview widgets when the user
  /// actually picked Record.
  bool get _isUploadFlow =>
      widget.initialInputMethod == 'uploadAudio' ||
      widget.initialInputMethod == 'uploadDocument';

  bool get _needsAudioUnlock =>
      widget.initialInputMethod == null ||
      widget.initialInputMethod == 'record' ||
      widget.initialInputMethod == 'uploadAudio';

  @override
  void initState() {
    super.initState();
    if (_needsAudioUnlock) {
      _loadAudioUnlock();
    } else {
      _audioUnlocked = true;
    }
  }

  Future<void> _loadAudioUnlock() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _audioUnlocked = false);
      return;
    }
    try {
      final plan = await SupabaseClient.instance.getPlanTier(userId);
      final ok = PlanTierGating.isFeatureUnlocked(
        currentPlanId: plan,
        feature: GatedFeature.recordLecture,
      );
      if (mounted) setState(() => _audioUnlocked = ok);
    } catch (_) {
      if (mounted) setState(() => _audioUnlocked = false);
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsAudioUnlock && _audioUnlocked == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audio locked')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Audio locked',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  PlanTierGating.lockMessage(GatedFeature.recordLecture),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF and Photo upload stay available on Free / ₹199.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/subscription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('View Plans — unlock at ₹499'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isUploadFlow ? 'Upload Details' : 'Recording Setup')),
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
                        _isUploadFlow ? 'Add lecture details' : 'Prepare your lecture',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isUploadFlow
                            ? 'Tell us what this is about, then choose your file.'
                            : 'Set up your camera and enter lecture details before you start.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      if (!_isUploadFlow) ...[
                        const CameraPreviewPlaceholder(),
                        const SizedBox(height: 12),
                        const AudioLevelIndicator(),
                        const SizedBox(height: 24),
                      ],
                      Text('Subject', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSubject,
                        decoration: _inputDecoration(context, hint: 'Select a subject'),
                        items: _subjects
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSubject = v),
                        validator: (v) => v == null ? 'Please select a subject' : null,
                      ),
                      const SizedBox(height: AppTheme.elementSpacing),
                      Text('Lecture Topic', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _topicController,
                        decoration: _inputDecoration(
                          context,
                          hint: 'e.g. Introduction to Calculus',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Please enter a lecture topic'
                                : null,
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
                  onPressed: (_needsAudioUnlock && _audioUnlocked == null)
                      ? null
                      : _handleStartRecording,
                  icon: Icon(
                    _isUploadFlow ? Icons.arrow_forward : Icons.fiber_manual_record,
                    size: 20,
                  ),
                  label: Text(_isUploadFlow ? 'Continue' : 'Start Recording'),
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
    if (_needsAudioUnlock && _audioUnlocked == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PlanTierGating.lockMessage(GatedFeature.recordLecture))),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final nav = AppNavigation.key.currentState ?? Navigator.of(context, rootNavigator: true);
      nav.pushNamed(
        '/recorder',
        arguments: {
          'subject': _selectedSubject,
          'topic': _topicController.text.trim(),
          'initialInputMethod': widget.initialInputMethod,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open recorder: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }
}
