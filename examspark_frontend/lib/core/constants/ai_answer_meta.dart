/// Formats server-derived answer_source + confidence for student trust UI.
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
      base = 'Source: $sourceLabel · Confidence: $confLabel';
    } else if (sourceLabel != null) {
      base = 'Source: $sourceLabel';
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
        return 'Notes';
      case 'PYQ':
        return 'PYQ';
      case 'KB':
        return 'Knowledge';
      case 'WEB':
        return 'Live web search (current events)';
      case 'VISION':
        return 'Photo / Diagram';
      case 'MIXED':
        return 'Mixed';
      case 'NO_MATCH':
        return 'No match in notes';
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
