import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class RecordingService {
  RecordingService._();

  static final RecordingService instance = RecordingService._();

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _elapsedSeconds = 0;

  int get elapsedSeconds => _elapsedSeconds;

  String get formattedDuration {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> get isSupported async {
    if (kIsWeb) return false;
    return _recorder.hasPermission();
  }

  Future<void> start() async {
    if (!await requestPermission()) {
      throw StateError('Microphone permission denied');
    }

    // Web: dart:io file paths don't exist in the browser, and Chrome/Firefox's
    // MediaRecorder doesn't reliably support aacLc — leave `path` empty so the
    // plugin keeps the recording as an in-memory blob (retrieved from stop()
    // as a blob: URL) and use opus, which browsers do support.
    await _recorder.start(
      RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc),
      path: kIsWeb ? '' : await _tempPath(),
    );

    _elapsedSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
    });
  }

  Future<String?> stop() async {
    _timer?.cancel();
    _timer = null;
    return _recorder.stop();
  }

  /// Works for a real file path (mobile/desktop) and a browser `blob:` URL
  /// (web) alike — [XFile] handles the platform difference internally.
  Future<Uint8List?> readRecordingBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await XFile(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) return file.bytes;
    if (file.path != null && !kIsWeb) {
      return File(file.path!).readAsBytes();
    }
    return null;
  }

  /// For the recorder's "Upload Document/Photo" tab — PDFs and images only,
  /// never audio (previously this mistakenly reused [pickAudioFile]).
  Future<Uint8List?> pickDocumentOrImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) return file.bytes;
    if (file.path != null && !kIsWeb) {
      return File(file.path!).readAsBytes();
    }
    return null;
  }

  Future<String> _tempPath() async {
    final dir = Directory.systemTemp;
    return '${dir.path}/examspark_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
  }
}
