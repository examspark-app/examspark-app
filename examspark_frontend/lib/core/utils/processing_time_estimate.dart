/// Honest processing-time ranges for the lecture pipeline (Whisper + notes + save).
///
/// Uses duration + optional file size — not fake progress. [typicalHigh] adds a
/// fixed buffer plus ~35% so Railway / Groq / OpenRouter spikes do not feel
/// like a broken UI.
class ProcessingTimeEstimate {
  const ProcessingTimeEstimate({
    required this.typicalLowSeconds,
    required this.typicalHighSeconds,
    required this.sourceKind,
  });

  final int typicalLowSeconds;
  final int typicalHighSeconds;
  final ProcessingSourceKind sourceKind;

  /// ~25% under base; [typicalHighSeconds] uses base × 1.35 + 45s fixed buffer.
  factory ProcessingTimeEstimate.fromInputs({
    required String? sourceType,
    int? durationMinutes,
    int? fileBytes,
  }) {
    final kind = _kindFromSource(sourceType);
    final mins = (durationMinutes ?? 2).clamp(1, 180);
    final bytes = fileBytes ?? 0;

    final baseSeconds = switch (kind) {
      ProcessingSourceKind.youtube => _youtubeBaseSeconds(mins),
      ProcessingSourceKind.document => _documentBaseSeconds(mins, bytes),
      ProcessingSourceKind.audio => _audioBaseSeconds(mins, bytes),
    };

    final low = (baseSeconds * 0.75).round().clamp(30, 7200);
    final high = (baseSeconds * 1.35 + 45).round().clamp(low + 15, 9000);

    return ProcessingTimeEstimate(
      typicalLowSeconds: low,
      typicalHighSeconds: high,
      sourceKind: kind,
    );
  }

  static ProcessingSourceKind _kindFromSource(String? sourceType) {
    final s = (sourceType ?? '').toLowerCase();
    if (s == 'youtube_link') return ProcessingSourceKind.youtube;
    if (s == 'pdf_upload' || s == 'image_upload') {
      return ProcessingSourceKind.document;
    }
    return ProcessingSourceKind.audio;
  }

  /// Captions + notes — no Whisper upload for long audio.
  static int _youtubeBaseSeconds(int mins) {
    return 50 + mins * 10;
  }

  static int _documentBaseSeconds(int mins, int bytes) {
    final upload = _uploadSeconds(bytes);
    return 40 + upload + mins * 6;
  }

  static int _audioBaseSeconds(int mins, int bytes) {
    final upload = _uploadSeconds(bytes);
    // Long audio is chunked (~12 min) on the server — sequential Whisper calls.
    final chunkCount = mins > 20 ? (mins / 12).ceil() : 1;
    final whisperPerMinute = 26;
    final whisper = chunkCount == 1
        ? 28 + mins * whisperPerMinute
        : (28 + mins * whisperPerMinute) * (0.65 + 0.35 * chunkCount);
    final notes = 52 + mins * 5;
    return (upload + whisper + notes).round();
  }

  static int _uploadSeconds(int bytes) {
    if (bytes <= 0) return 8;
    // ~400 KB/s effective upload to API (local or Railway — conservative).
    final sec = (bytes / (400 * 1024)).ceil();
    return sec.clamp(3, 120);
  }

  String get totalRangeLabel =>
      '${_formatMinutes(typicalLowSeconds)}–${_formatMinutes(typicalHighSeconds)}';

  String headlineForStage(ProcessingEstimateStage stage) {
    final longAudio = sourceKind == ProcessingSourceKind.audio &&
        typicalHighSeconds >= 8 * 60;
    return switch (stage) {
      ProcessingEstimateStage.preparing =>
        'This usually takes about $totalRangeLabel',
      ProcessingEstimateStage.transcribing => sourceKind == ProcessingSourceKind.document
          ? 'Reading your file — usually $totalRangeLabel total'
          : longAudio
              ? 'Large lecture — listening can take several minutes ($totalRangeLabel)'
              : 'Still processing — listening usually takes most of $totalRangeLabel',
      ProcessingEstimateStage.tools => 'Finalizing — saving your notes',
      ProcessingEstimateStage.notes => 'Still processing — writing your notes',
      ProcessingEstimateStage.done => 'Done',
      ProcessingEstimateStage.overEstimate => longAudio
          ? 'Still processing — large lectures often need a few extra minutes'
          : 'Still processing — large lectures can take a few extra minutes',
    };
  }

  /// Elapsed-aware line under the progress bar (never counts down to 0 aggressively).
  String elapsedLine({
    required Duration elapsed,
    required ProcessingEstimateStage stage,
  }) {
    if (stage == ProcessingEstimateStage.done) return 'Complete';
    if (stage == ProcessingEstimateStage.overEstimate) {
      return 'Still processing… This usually takes $totalRangeLabel';
    }
    final sec = elapsed.inSeconds;
    if (sec < typicalLowSeconds) {
      final remainHigh = typicalHighSeconds - sec;
      if (remainHigh <= 0) {
        return 'Still processing… This usually takes $totalRangeLabel';
      }
      return 'About ${_formatMinutes(remainHigh)} left (typical $totalRangeLabel)';
    }
    if (sec <= typicalHighSeconds) {
      return 'Still processing — within the usual $totalRangeLabel window';
    }
    return 'Still processing… This usually takes $totalRangeLabel';
  }

  static String _formatMinutes(int seconds) {
    if (seconds < 90) return '1 min';
    final mins = (seconds / 60).ceil();
    if (mins == 1) return '1 min';
    return '$mins min';
  }
}

enum ProcessingSourceKind { audio, youtube, document }

enum ProcessingEstimateStage {
  preparing,
  transcribing,
  tools,
  notes,
  done,
  overEstimate,
}

ProcessingEstimateStage estimateStageFromLectureStatus(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'splitting':
      return ProcessingEstimateStage.preparing;
    case 'transcribing':
      return ProcessingEstimateStage.transcribing;
    case 'indexing':
    case 'generating':
      return ProcessingEstimateStage.notes;
    case 'almost_done':
      return ProcessingEstimateStage.tools;
    case 'done':
      return ProcessingEstimateStage.done;
    default:
      return ProcessingEstimateStage.preparing;
  }
}
