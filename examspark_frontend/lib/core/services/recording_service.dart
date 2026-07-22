import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// dart:io is NOT available on Flutter web — conditional so Chrome does not
// fail library init with "Library not defined" on recording screens.
import 'recording_io_stub.dart'
    if (dart.library.io) 'recording_io_native.dart' as io_helper;

/// Student-facing copy when no voice is captured (also backend NO_SPEECH).
const String kMicCheckUserMessage =
    'No speech detected. Kindly check your microphone and try again.';

class RecordingService {
  RecordingService._();

  static final RecordingService instance = RecordingService._();

  /// dBFS-ish levels from [AudioRecorder]; voice usually well above this.
  static const double voiceThresholdDb = -40.0;

  /// First popup when mic may be off — recording never stops.
  static const int silenceFirstWarnAfterSeconds = 5;

  /// Repeat popup every this many seconds of continuous silence (after speech or after first warn).
  static const int silenceRepeatWarnAfterSeconds = 300;

  /// Lazy / re-creatable — screen dispose must NOT permanently kill the
  /// singleton recorder (leave Record tab used to leave a disposed
  /// AudioRecorder and show "already been disposed").
  AudioRecorder? _recorder;
  bool _recorderDisposed = false;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  int _elapsedSeconds = 0;

  /// Continuous silent seconds in the *current* stretch (resets on voice).
  int _consecutiveSilentSeconds = 0;

  double _peakDb = -160.0;

  /// Ever heard voice this take — used for final upload validation.
  bool _heardAnyVoice = false;

  /// True while the latest sample is above the voice threshold.
  bool _voiceActiveNow = false;

  /// Elapsed seconds when we last fired [ _onSilenceWarning ] (for 5‑min repeats).
  int? _lastSilenceWarnAtElapsed;
  bool _amplitudeSamplesReceived = false;
  VoidCallback? _onSilenceWarning;

  AudioRecorder get _activeRecorder {
    if (_recorder == null || _recorderDisposed) {
      _recorder = AudioRecorder();
      _recorderDisposed = false;
    }
    return _recorder!;
  }

  int get elapsedSeconds => _elapsedSeconds;

  /// True if amplitude crossed [voiceThresholdDb] at least once this take.
  bool get heardVoice => _heardAnyVoice;

  /// Alias kept for callers that prefer the clearer name.
  bool get heardAnyVoice => _heardAnyVoice;

  /// False on platforms where amplitude never reports (e.g. some web builds).
  bool get amplitudeMonitoringActive => _amplitudeSamplesReceived;

  double get peakDb => _peakDb;

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
    return _activeRecorder.hasPermission();
  }

  /// Callback when silence thresholds elapse (5s mic check, then every 5 min).
  void setSilenceWarningListener(VoidCallback? listener) {
    _onSilenceWarning = listener;
  }

  Future<void> start() async {
    if (!await requestPermission()) {
      throw StateError('Microphone permission denied');
    }

    _elapsedSeconds = 0;
    _consecutiveSilentSeconds = 0;
    _peakDb = -160.0;
    _heardAnyVoice = false;
    _voiceActiveNow = false;
    _lastSilenceWarnAtElapsed = null;
    _amplitudeSamplesReceived = false;

    // Web: no dart:io paths; leave `path` empty for in-memory blob + opus.
    await _activeRecorder.start(
      RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc),
      path: kIsWeb ? '' : await io_helper.tempRecordingPath(),
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      if (!_amplitudeSamplesReceived) {
        // Web often has no amplitude — time-based mic nudge only (no voice yet).
        if (!_heardAnyVoice &&
            _elapsedSeconds >= silenceFirstWarnAfterSeconds) {
          if (_lastSilenceWarnAtElapsed == null) {
            _lastSilenceWarnAtElapsed = _elapsedSeconds;
            _onSilenceWarning?.call();
          } else if (_elapsedSeconds - _lastSilenceWarnAtElapsed! >=
              silenceRepeatWarnAfterSeconds) {
            _lastSilenceWarnAtElapsed = _elapsedSeconds;
            _onSilenceWarning?.call();
          }
        }
        return;
      }
      if (_voiceActiveNow) {
        _consecutiveSilentSeconds = 0;
        return;
      }
      _consecutiveSilentSeconds++;
      if (shouldFireSilenceWarning(
        consecutiveSilentSeconds: _consecutiveSilentSeconds,
        heardAnyVoice: _heardAnyVoice,
        lastWarnAtElapsed: _lastSilenceWarnAtElapsed,
      )) {
        _lastSilenceWarnAtElapsed = _elapsedSeconds;
        _consecutiveSilentSeconds = 0;
        _onSilenceWarning?.call();
      }
    });

    await _amplitudeSub?.cancel();
    try {
      _amplitudeSub = _activeRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 300))
          .listen((amp) {
        _amplitudeSamplesReceived = true;
        final level = amp.current;
        if (level > _peakDb) _peakDb = level;
        if (level >= voiceThresholdDb) {
          if (!_voiceActiveNow) {
            _consecutiveSilentSeconds = 0;
          }
          _voiceActiveNow = true;
          _heardAnyVoice = true;
        } else {
          _voiceActiveNow = false;
        }
      });
    } catch (_) {
      // Some platforms (or web) may not support amplitude — backend guard remains.
    }
  }

  Future<String?> stop() async {
    _timer?.cancel();
    _timer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final recorder = _recorder;
    if (recorder == null || _recorderDisposed) return null;
    return recorder.stop();
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
      return io_helper.readFileBytes(file.path!);
    }
    return null;
  }

  /// Picked file bytes + original name (needed so FastAPI can route PDF vs image).
  Future<({Uint8List bytes, String name})?> pickDocumentOrImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null && !kIsWeb) {
      bytes = await io_helper.readFileBytes(file.path!);
    }
    if (bytes == null) return null;
    final name = file.name.isNotEmpty ? file.name : 'document.pdf';
    return (bytes: bytes, name: name);
  }

  /// Screen leave: stop timer + stop active recording. Do NOT dispose the
  /// shared [AudioRecorder] permanently — next visit recreates if needed.
  Future<void> releaseForScreen() async {
    _timer?.cancel();
    _timer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _onSilenceWarning = null;
    final recorder = _recorder;
    if (recorder == null || _recorderDisposed) return;
    try {
      if (await recorder.isRecording()) {
        await recorder.stop();
      }
    } catch (_) {
      // Already stopped / disposed mid-flight — ignore.
    }
  }

  /// Pure logic for silence popups — unit-tested.
  static bool shouldFireSilenceWarning({
    required int consecutiveSilentSeconds,
    required bool heardAnyVoice,
    required int? lastWarnAtElapsed,
    int firstWarnSeconds = silenceFirstWarnAfterSeconds,
    int repeatWarnSeconds = silenceRepeatWarnAfterSeconds,
  }) {
    if (!heardAnyVoice) {
      if (lastWarnAtElapsed == null) {
        return consecutiveSilentSeconds >= firstWarnSeconds;
      }
      return consecutiveSilentSeconds >= repeatWarnSeconds;
    }
    return consecutiveSilentSeconds >= repeatWarnSeconds;
  }

  /// Full teardown (app exit / tests only). Prefer [releaseForScreen] from UI.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_amplitudeSub?.cancel());
    _amplitudeSub = null;
    _onSilenceWarning = null;
    final recorder = _recorder;
    if (recorder != null && !_recorderDisposed) {
      try {
        recorder.dispose();
      } catch (_) {}
      _recorderDisposed = true;
    }
  }
}
