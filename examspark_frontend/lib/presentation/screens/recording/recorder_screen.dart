import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';

/// Recording flow: quality choice → record / upload
///
/// Shared by both the Home tab's "Record" action and the Teacher
/// Dashboard's recording flow — warnings (duration reached, start/stop
/// errors, network problems) and call-interruption auto-save below apply
/// to both automatically since they're the same screen.
class RecorderScreen extends StatefulWidget {
  final String? subject;
  final String? topic;

  const RecorderScreen({super.key, this.subject, this.topic});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> with WidgetsBindingObserver {
  bool _useHighAccuracy = false;
  InputMethod _selectedInputMethod = InputMethod.record;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _recordingDuration = '00:00';
  int _currentScreen = 1;
  String? _recordingPath;

  /// Planned duration bucket in minutes, chosen on the Setup screen —
  /// founder rule: warn (sound + banner) once this is reached, never
  /// auto-stop the recording.
  int _plannedDurationMinutes = 30;
  bool _durationWarningShown = false;

  /// Set when a call/app-switch interrupts an active recording — the
  /// recording is stopped + saved immediately (before the interruption
  /// takes over), then a recovery prompt offers to process it once the app
  /// resumes.
  bool _autoSavedFromInterruption = false;

  final _recordingService = RecordingService.instance;
  final _lectureService = LectureService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingService.dispose();
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
    );
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
    SystemSound.play(SystemSoundType.alert);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Transcription Quality',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the transcription mode that best fits your recording environment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Option A: Fast (Recommended)
          _buildQualityOption(
            title: 'Fast (Recommended)',
            subtitle: 'Best for clear classroom audio',
            isSelected: !_useHighAccuracy,
            onTap: () => setState(() => _useHighAccuracy = false),
            icon: Icons.speed,
          ),
          const SizedBox(height: 16),
          
          // Option B: High Accuracy
          _buildQualityOption(
            title: 'High Accuracy (Noisy Audio)',
            subtitle: 'Best for noisy rooms or unclear speech',
            isSelected: _useHighAccuracy,
            onTap: () => setState(() => _useHighAccuracy = true),
            icon: Icons.high_quality,
          ),
          const SizedBox(height: 24),

          const Text(
            'Planned Duration',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'We\'ll warn you when you reach this — recording never auto-stops.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDurationChip(30, '≤30 min'),
              const SizedBox(width: 10),
              _buildDurationChip(60, '30–60 min'),
              const SizedBox(width: 10),
              _buildDurationChip(90, '60–90 min'),
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
                Icon(Icons.payments_outlined, color: Colors.green[800], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recording cost (per session): '
                    '≤30 min ${CreditCosts.recordUpTo30Min} · '
                    '30–60 min ${CreditCosts.record30To60Min} · '
                    '60–90 min ${CreditCosts.record60To90Min} credits. '
                    'Summary included.',
                    style: TextStyle(fontSize: 13, color: Colors.green[900]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
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
                    'Recording uses your device\'s external microphone for reliable audio capture',
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
              onPressed: () => setState(() => _currentScreen = 2),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black87,
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
    );
  }

  Widget _buildQualityOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black87 : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _plannedDurationMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _plannedDurationMinutes = minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputMethodContent() {
    switch (_selectedInputMethod) {
      case InputMethod.record:
        return _buildRecordingContent();
      case InputMethod.uploadAudio:
        return _buildUploadAudioContent();
      case InputMethod.uploadDocument:
        return _buildUploadDocumentContent();
    }
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
            SnackBar(content: Text('Could not start recording: $e'), backgroundColor: Colors.red[700]),
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
      final bytes = await _recordingService.readRecordingBytes(_recordingPath);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('No audio captured');
      }
      await _startProcessingWithAudio(bytes);
    } catch (e) {
      if (mounted) {
        _playWarningSound();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e'), backgroundColor: Colors.red[700]),
        );
        setState(() => _isProcessing = false);
      }
    }
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

  Future<void> _startProcessingWithAudio(List<int> audioBytes) async {
    final title = widget.topic?.isNotEmpty == true
        ? widget.topic!
        : widget.subject ?? 'New Lecture';

    // Only a real mic recording is eligible for "Share to Group" later —
    // uploaded audio/documents stay personal-only (fake-teacher prevention).
    final sourceType = switch (_selectedInputMethod) {
      InputMethod.record => 'recorded',
      InputMethod.uploadAudio => 'uploaded_audio',
      InputMethod.uploadDocument => 'uploaded_document',
    };

    final lectureId = await _lectureService.createLecture(
      title: title,
      subject: widget.subject,
      topic: widget.topic,
      highAccuracy: _useHighAccuracy,
      sourceType: sourceType,
    );

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/processing',
      arguments: {'lectureId': lectureId},
    );

    try {
      await _lectureService.invokeProcessing(
        lectureId: lectureId,
        audioBytes: Uint8List.fromList(audioBytes),
        highAccuracy: _useHighAccuracy,
      );
    } catch (_) {
      // Network problem (or edge function failure) after we've already
      // navigated to /processing — mark the lecture 'error' so its
      // realtime listener (ProcessingScreen) shows the retry UI instead of
      // spinning forever.
      await _lectureService.updateStatus(lectureId, 'error');
    }
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
          SnackBar(content: Text('Upload failed: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDocumentUpload() async {
    await _handleAudioUpload();
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transcription Quality'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fast (Recommended):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Best for clear classroom audio'),
              const SizedBox(height: 12),
              const Text(
                'High Accuracy (Noisy Audio):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Best for noisy rooms or unclear speech'),
              const SizedBox(height: 16),
              Text(
                'Cost is per session (not per minute): '
                '≤30 min ${CreditCosts.recordUpTo30Min}, '
                '30–60 min ${CreditCosts.record30To60Min}, '
                '60–90 min ${CreditCosts.record60To90Min} credits.',
              ),
            ],
          ),
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
}

enum InputMethod {
  record,
  uploadAudio,
  uploadDocument,
}
