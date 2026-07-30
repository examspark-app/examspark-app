/// Formats server-derived answer_source + confidence for student trust UI.
/// Labels stay short and non-technical (no RAG / DB words).
class AiAnswerMeta {
  AiAnswerMeta._();

  static String? trustLine({
    String? answerSource,
    String? confidence,
    String? webSearchNote,
  }) {
    final sourceLabel = _sourceLabel(answerSource);
    final confLabel = _confidenceLabel(confidence);
    String? base;
    if (sourceLabel != null && confLabel != null) {
      base = 'From: $sourceLabel · Confidence: $confLabel';
    } else if (sourceLabel != null) {
      base = 'From: $sourceLabel';
    } else if (confLabel != null) {
      base = 'Confidence: $confLabel';
    }
    final note = (webSearchNote ?? '').trim();
    if (note.isNotEmpty) {
      return base == null ? note : '$base\n$note';
    }
    return base;
  }

  static String? _sourceLabel(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'RAG':
        return 'Your notes';
      case 'PYQ':
        return 'Exam focus';
      case 'KB':
        return 'Study knowledge';
      case 'WEB':
        return 'Live web (current events)';
      case 'VISION':
        return 'Your photo';
      case 'MIXED':
        return 'Notes + extras';
      case 'NO_MATCH':
        return 'Not found in notes';
      default:
        return null;
    }
  }

  static String? _confidenceLabel(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'HIGH':
        return 'High';
      case 'MEDIUM':
        return 'Medium';
      case 'LOW':
        return 'Low';
      default:
        return null;
    }
  }
}
