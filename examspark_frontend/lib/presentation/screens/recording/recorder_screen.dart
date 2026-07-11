import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/recording_service.dart';

/// Recording flow: quality choice → record / upload
class RecorderScreen extends StatefulWidget {
  final String? subject;
  final String? topic;

  const RecorderScreen({super.key, this.subject, this.topic});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  bool _useHighAccuracy = false;
  InputMethod _selectedInputMethod = InputMethod.record;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _recordingDuration = '00:00';
  int _currentScreen = 1;
  String? _recordingPath;

  final _recordingService = RecordingService.instance;
  final _lectureService = LectureService.instance;

  @override
  void dispose() {
    _recordingService.dispose();
    super.dispose();
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
        });
        _tickDuration();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start recording: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
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
      _tickDuration();
    });
  }

  Future<void> _startProcessingWithAudio(List<int> audioBytes) async {
    final title = widget.topic?.isNotEmpty == true
        ? widget.topic!
        : widget.subject ?? 'New Lecture';

    final lectureId = await _lectureService.createLecture(
      title: title,
      subject: widget.subject,
      topic: widget.topic,
      highAccuracy: _useHighAccuracy,
    );

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/processing',
      arguments: {'lectureId': lectureId},
    );

    await _lectureService.invokeProcessing(
      lectureId: lectureId,
      audioBytes: Uint8List.fromList(audioBytes),
      highAccuracy: _useHighAccuracy,
    );
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
