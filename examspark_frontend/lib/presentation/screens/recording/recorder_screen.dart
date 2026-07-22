import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType, HapticFeedback;
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/constants/plan_tier_gating.dart';
import 'package:examspark_frontend/core/constants/subjects.dart';
import 'package:examspark_frontend/core/errors/lecture_user_message.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Recording flow: subject/topic + planned duration → record / upload
///
/// Shared by both the Home tab's "Record" action and the Teacher
/// Dashboard's recording flow — warnings (duration reached, start/stop
/// errors, network problems) and call-interruption auto-save below apply
/// to both automatically since they're the same screen.
/// Transcription quality is automatic on the server (no student model choice).
class RecorderScreen extends StatefulWidget {
  final String? subject;
  final String? topic;

  /// Pre-selects the Record/Upload Audio/Upload Document tab on screen 2 —
  /// set when opened from Home's attach sheet (e.g. "Image / Photo" should
  /// land straight on Upload Document/Photo, not the default Record tab).
  /// Matches [InputMethod].name ('record' / 'uploadAudio' / 'uploadDocument').
  final String? initialInputMethod;

  const RecorderScreen({super.key, this.subject, this.topic, this.initialInputMethod});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> with WidgetsBindingObserver {
  InputMethod _selectedInputMethod = InputMethod.record;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _recordingDuration = '00:00';
  int _currentScreen = 1;
  String? _recordingPath;
  /// null = still loading plan; false = Record + Upload Audio locked.
  bool? _audioUnlocked;

  /// Planned duration bucket in minutes, chosen on the Setup screen —
  /// founder rule: warn (sound + banner) once this is reached, never
  /// auto-stop the recording.
  int _plannedDurationMinutes = 30;
  bool _durationWarningShown = false;

  /// Subject + topic collected on setup (merged from old Recording Setup page).
  final _setupFormKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  String? _selectedSubject;

  /// Set when a call/app-switch interrupts an active recording — the
  /// recording is stopped + saved immediately (before the interruption
  /// takes over), then a recovery prompt offers to process it once the app
  /// resumes.
  bool _autoSavedFromInterruption = false;

  /// Prevents stacking multiple silence / recovery dialogs.
  bool _silenceDialogVisible = false;
  bool _recoveryDialogVisible = false;

  final _recordingService = RecordingService.instance;
  final _lectureService = LectureService.instance;

  bool get _audioTabLocked =>
      _audioUnlocked == false &&
      (_selectedInputMethod == InputMethod.record ||
          _selectedInputMethod == InputMethod.uploadAudio);

  String? get _effectiveSubject {
    final s = _selectedSubject?.trim();
    if (s != null && s.isNotEmpty) return s;
    final w = widget.subject?.trim();
    if (w != null && w.isNotEmpty) return w;
    return null;
  }

  String? get _effectiveTopic {
    final t = _topicController.text.trim();
    if (t.isNotEmpty) return t;
    final w = widget.topic?.trim();
    if (w != null && w.isNotEmpty) return w;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialInputMethod != null) {
      _selectedInputMethod = InputMethod.values.firstWhere(
        (m) => m.name == widget.initialInputMethod,
        orElse: () => InputMethod.record,
      );
    }
    final incomingSubject = widget.subject?.trim();
    if (incomingSubject != null && incomingSubject.isNotEmpty) {
      _selectedSubject = kSubjectOptions.contains(incomingSubject)
          ? incomingSubject
          : 'Other';
    }
    final incomingTopic = widget.topic?.trim();
    if (incomingTopic != null && incomingTopic.isNotEmpty) {
      _topicController.text = incomingTopic;
    }
    _loadAudioUnlock();
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
      // Fail closed — hide Record/Upload Audio until we know the plan.
      if (mounted) setState(() => _audioUnlocked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _topicController.dispose();
    // Stop active recording only — never permanently dispose the shared
    // RecordingService singleton (that caused "Record has already been disposed").
    unawaited(_recordingService.releaseForScreen());
    super.dispose();
  }

  /// Auto-save on call interruption — founder rule: stop + save the
  /// recording BEFORE the interruption takes over (not after), for both
  /// Home and Teacher Dashboard recording flows.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) &&
        _isRecording &&
        !_autoSavedFromInterruption) {
      _autoSaveOnInterruption();
    } else if (state == AppLifecycleState.resumed && _autoSavedFromInterruption) {
      Future.microtask(_showAutoSaveRecoveryDialog);
    }
  }

  Future<void> _autoSaveOnInterruption() async {
    _autoSavedFromInterruption = true;
    try {
      final path = await _recordingService.stop();
      _recordingPath = path;
    } catch (_) {
      // Best-effort — nothing more we can do if stop() itself fails
      // mid-interruption; the recovery dialog will surface that on resume.
    }
    if (mounted) setState(() => _isRecording = false);
  }

  void _showAutoSaveRecoveryDialog() {
    if (!mounted || !_autoSavedFromInterruption) return;
    if (_recoveryDialogVisible) return;
    _recoveryDialogVisible = true;
    _playWarningSound();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Recording auto-saved'),
        content: const Text(
          'Looks like something interrupted your recording (a call, or switching apps). '
          'We saved what was recorded so far — process it now, or discard it and start over?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _discardAutoSaved();
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finishFromAutoSave();
            },
            child: const Text('Process Now'),
          ),
        ],
      ),
    ).whenComplete(() {
      _recoveryDialogVisible = false;
    });
  }

  void _discardAutoSaved() {
    setState(() {
      _autoSavedFromInterruption = false;
      _recordingPath = null;
      _recordingDuration = '00:00';
      _durationWarningShown = false;
    });
  }

  Future<void> _finishFromAutoSave() async {
    setState(() {
      _autoSavedFromInterruption = false;
      _isProcessing = true;
    });
    try {
      final bytes = await _recordingService.readRecordingBytes(_recordingPath);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('No audio was captured before the interruption');
      }
      await _startProcessingWithAudio(bytes);
    } catch (e) {
      if (mounted) {
        _playWarningSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not process the auto-saved recording: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  void _playWarningSound() {
    void play() {
      SystemSound.play(SystemSoundType.alert);
      if (kIsWeb) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
      }
    }

    play();
    WidgetsBinding.instance.addPostFrameCallback((_) => play());
  }

  void _showDurationWarningBanner() {
    if (!mounted) return;
    _playWarningSound();
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.amber[50],
        leading: Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
        content: Text(
          'You\'ve reached your planned duration ($_plannedDurationMinutes min). '
          'You can keep recording, or tap stop to finish now.',
          style: TextStyle(color: Colors.amber[900]),
        ),
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentScreen == 1 ? 'Setup Recording' : 'Record Lecture'),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: _currentScreen == 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentScreen = 1),
              )
            : null,
      ),
      backgroundColor: Colors.grey[50],
      body: _currentScreen == 1 ? _buildSetupScreen() : _buildRecordingScreen(),
    );
  }

  // Screen 1: Recording Setup Screen
  Widget _buildSetupScreen() {
    return Form(
      key: _setupFormKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lecture details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add subject and topic, then choose planned duration before recording.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Subject',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: InputDecoration(
                hintText: 'Select a subject',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                for (final s in kSubjectOptions)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => _selectedSubject = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Please select a subject' : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Lecture Topic',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _topicController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Introduction to Calculus',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Please enter a lecture topic';
                if (t.length < 3) return 'Topic is too short';
                return null;
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Planned Duration',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'We\'ll warn you when you reach this — recording never auto-stops. '
              'Up to 3 hours supported.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildDurationChip(30, '≤30 min'),
                _buildDurationChip(60, '30–60 min'),
                _buildDurationChip(90, '60–90 min'),
                _buildDurationChip(180, '90–180 (up to 3 hr)'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.payments_outlined,
                      color: Colors.green[800], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recording cost: about ${CreditCosts.recordCreditsPerMinute} credit '
                      'per minute — you are charged for the actual length '
                      '(up to ${CreditCosts.recordMaxMinutes ~/ 60} hours). '
                      'Summary included.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.green[900]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Audio Source Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recording uses your device\'s microphone for reliable audio capture',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!(_setupFormKey.currentState?.validate() ?? false)) {
                    return;
                  }
                  setState(() => _currentScreen = 2);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _plannedDurationMinutes == minutes;
    return GestureDetector(
      onTap: () => setState(() => _plannedDurationMinutes = minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey[300]!),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // Screen 2: Recording / Upload Screen
  Widget _buildRecordingScreen() {
    return Column(
      children: [
        // Input Method Tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              _buildInputMethodTab(
                method: InputMethod.record,
                icon: Icons.mic,
                label: 'Record',
              ),
              const SizedBox(width: 8),
              _buildInputMethodTab(
                method: InputMethod.uploadAudio,
                icon: Icons.audio_file,
                label: 'Upload Audio',
              ),
              const SizedBox(width: 8),
              _buildInputMethodTab(
                method: InputMethod.uploadDocument,
                icon: Icons.description,
                label: 'Upload Document/Photo',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Content based on selected method
        Expanded(
          child: _buildInputMethodContent(),
        ),
      ],
    );
  }

  Widget _buildInputMethodTab({
    required InputMethod method,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedInputMethod == method;
    final locked = _audioUnlocked == false &&
        (method == InputMethod.record || method == InputMethod.uploadAudio);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedInputMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black87 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                locked ? Icons.lock_outline : icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputMethodContent() {
    if (_audioUnlocked == null &&
        (_selectedInputMethod == InputMethod.record ||
            _selectedInputMethod == InputMethod.uploadAudio)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_audioTabLocked) {
      return _buildAudioLockedPanel();
    }
    switch (_selectedInputMethod) {
      case InputMethod.record:
        return _buildRecordingContent();
      case InputMethod.uploadAudio:
        return _buildUploadAudioContent();
      case InputMethod.uploadDocument:
        return _buildUploadDocumentContent();
    }
  }

  Widget _buildAudioLockedPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 36, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            const Text(
              'Audio locked',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              PlanTierGating.lockMessage(GatedFeature.recordLecture),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Record + Upload Audio need ₹499+. PDF / Photo stay available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('View Plans — unlock at ₹499'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(
                () => _selectedInputMethod = InputMethod.uploadDocument,
              ),
              child: const Text('Upload PDF / Photo instead'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Recording Button
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Colors.black87,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : Colors.black87).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 15,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Timer
          Text(
            _recordingDuration,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            _isRecording ? 'Recording in progress...' : 'Tap to start recording',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          if (_isRecording) ...[
            const SizedBox(height: 32),
            // Waveform Animation Placeholder
            Container(
              height: 60,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text(
                  '🎵 Waveform',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadAudioContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload Audio File',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'MP3, WAV, M4A',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleAudioUpload,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadDocumentContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload Document/Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF, JPG, PNG',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleDocumentUpload,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isProcessing) return;

    if (!_isRecording) {
      try {
        _recordingService.setSilenceWarningListener(_onSilenceWhileRecording);
        await _recordingService.start();
        setState(() {
          _isRecording = true;
          _durationWarningShown = false;
        });
        _tickDuration();
      } catch (e) {
        // "Recording na ho tab bhi warning aye" — sound + visible error,
        // not just a quiet snackbar.
        if (mounted) {
          _playWarningSound();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lectureUserMessage(e)),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
      return;
    }

    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    try {
      _recordingPath = await _recordingService.stop();
      _recordingService.setSilenceWarningListener(null);

      // Fail closed before FastAPI when amplitude proves silence (mic off).
      // If amplitude never reports (some web builds), backend guard handles it.
      if (_recordingService.amplitudeMonitoringActive &&
          !_recordingService.heardVoice &&
          _recordingService.elapsedSeconds >= 3) {
        throw StateError(kMicCheckUserMessage);
      }

      final bytes = await _recordingService.readRecordingBytes(_recordingPath);
      if (bytes == null || bytes.isEmpty) {
        throw StateError(kMicCheckUserMessage);
      }
      await _startProcessingWithAudio(bytes);
    } catch (e) {
      if (mounted) {
        _playWarningSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lectureUserMessage(e)),
            backgroundColor: Colors.red[700],
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  void _onSilenceWhileRecording() {
    if (!mounted || !_isRecording) return;

    _playWarningSound();

    if (_silenceDialogVisible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Still no voice detected — recording continues. Check your mic.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    _silenceDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.mic_off_outlined, color: Colors.amber[800]),
            const SizedBox(width: 8),
            const Expanded(child: Text('Still recording')),
          ],
        ),
        content: const Text(
          'Recording is still running in the background.\n\n'
          'If we don’t hear you: check your microphone. '
          'If you’re just pausing, tap Continue — we’ll remind you again after about 5 minutes of silence.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Continue Recording'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_isRecording) {
                unawaited(_toggleRecording());
              }
            },
            child: const Text('Stop & Process'),
          ),
        ],
      ),
    ).whenComplete(() {
      _silenceDialogVisible = false;
    });
  }

  void _tickDuration() {
    if (!_isRecording) return;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRecording) return;
      setState(() {
        _recordingDuration = _recordingService.formattedDuration;
      });
      // Warn once the planned duration is reached — never auto-stops.
      if (!_durationWarningShown && _recordingService.elapsedSeconds >= _plannedDurationMinutes * 60) {
        _durationWarningShown = true;
        _showDurationWarningBanner();
      }
      _tickDuration();
    });
  }

  Future<void> _startProcessingWithAudio(
    List<int> audioBytes, {
    String? filename,
    String? apiSourceTypeOverride,
  }) async {
    final title = _effectiveTopic?.isNotEmpty == true
        ? _effectiveTopic!
        : _effectiveSubject ?? 'New Lecture';

    // Only a real mic recording is eligible for "Share to Group" later —
    // uploaded audio/documents stay personal-only (fake-teacher prevention).
    final sourceType = switch (_selectedInputMethod) {
      InputMethod.record => 'recorded',
      InputMethod.uploadAudio => 'uploaded_audio',
      InputMethod.uploadDocument => 'uploaded_document',
    };

    // FastAPI source_type: recording / audio_upload / pdf_upload / image_upload
    final apiSourceType = apiSourceTypeOverride ??
        switch (_selectedInputMethod) {
          InputMethod.record => 'recording',
          InputMethod.uploadAudio => 'audio_upload',
          InputMethod.uploadDocument => 'pdf_upload',
        };

    // Client soft-gate (matches server Rule 6). Server still enforces.
    if (!await _ensureFeatureUnlockedForSource(apiSourceType)) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    final resolvedFilename = filename ??
        switch (apiSourceType) {
          'image_upload' => 'image.jpg',
          'pdf_upload' => 'document.pdf',
          _ => 'audio.webm',
        };

    final lectureId = await _lectureService.createLecture(
      title: title,
      subject: _effectiveSubject,
      topic: _effectiveTopic,
      highAccuracy: false,
      sourceType: sourceType,
    );

    if (!mounted) return;

    final fileBytesForRetry = Uint8List.fromList(audioBytes);
    // Record: bill actual elapsed. Upload (elapsed often 0): use planned bucket.
    final elapsedMin = (_recordingService.elapsedSeconds / 60).ceil();
    final durationMinutesForRetry = (elapsedMin > 0 ? elapsedMin : _plannedDurationMinutes)
        .clamp(1, CreditCosts.recordMaxMinutes);

    // Pass the same bytes/args /processing needs so its Retry button can
    // actually resend this request instead of just resetting the UI.
    Navigator.pushReplacementNamed(
      context,
      '/processing',
      arguments: {
        'lectureId': lectureId,
        'retryFileBytes': fileBytesForRetry,
        'retryFilename': resolvedFilename,
        'retrySourceType': apiSourceType,
        'retryHighAccuracy': false,
        'retryDurationMinutes': durationMinutesForRetry,
      },
    );

    try {
      await _lectureService.invokeProcessing(
        lectureId: lectureId,
        fileBytes: fileBytesForRetry,
        highAccuracy: false,
        sourceType: apiSourceType,
        durationMinutes: durationMinutesForRetry,
        filename: resolvedFilename,
      );
    } catch (e) {
      // Dropped long HTTP while server may still finish — poll before sticky error.
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (LectureService.isLikelyProcessNetworkFailure(e)) {
        final recovered =
            await _lectureService.recoverAfterProcessNetworkBlip(lectureId);
        if (recovered) return;
      }
      await _lectureService.markErrorUnlessDone(lectureId, msg);
    }
  }

  /// Soft client check before upload — server returns 403 FEATURE_LOCKED too.
  Future<bool> _ensureFeatureUnlockedForSource(String apiSourceType) async {
    final feature = switch (apiSourceType) {
      'recording' || 'audio_upload' => GatedFeature.recordLecture,
      'image_upload' => GatedFeature.diagramAnalysis,
      'pdf_upload' => GatedFeature.pdfAnalysis,
      _ => null,
    };
    if (feature == null) return true;

    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return false;

    try {
      final plan = await SupabaseClient.instance.getPlanTier(userId);
      if (PlanTierGating.isFeatureUnlocked(
        currentPlanId: plan,
        feature: feature,
      )) {
        return true;
      }
    } catch (_) {
      // Fail closed for audio; for other features prefer server check.
      if (feature == GatedFeature.recordLecture) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(PlanTierGating.lockMessage(GatedFeature.recordLecture)),
            ),
          );
        }
        return false;
      }
      return true;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PlanTierGating.lockMessage(feature))),
      );
    }
    return false;
  }

  Future<void> _handleAudioUpload() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _recordingService.pickAudioFile();
      if (bytes == null) {
        setState(() => _isProcessing = false);
        return;
      }
      await _startProcessingWithAudio(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lectureUserMessage(e))),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDocumentUpload() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final picked = await _recordingService.pickDocumentOrImageFile();
      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }
      final lower = picked.name.toLowerCase();
      final isImage = lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png');
      await _startProcessingWithAudio(
        picked.bytes,
        filename: picked.name,
        apiSourceTypeOverride: isImage ? 'image_upload' : 'pdf_upload',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lectureUserMessage(e))),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

}

enum InputMethod {
  record,
  uploadAudio,
  uploadDocument,
}
