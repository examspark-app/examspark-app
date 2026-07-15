/// Formats server-derived answer_source + confidence for student trust UI.
class AiAnswerMeta {
  AiAnswerMeta._();

  static String? trustLine({
    String? answerSource,
    String? confidence,
  }) {
    final sourceLabel = _sourceLabel(answerSource);
    final confLabel = _confidenceLabel(confidence);
    if (sourceLabel == null && confLabel == null) return null;
    if (sourceLabel != null && confLabel != null) {
      return 'Source: $sourceLabel · Confidence: $confLabel';
    }
    if (sourceLabel != null) return 'Source: $sourceLabel';
    return 'Confidence: $confLabel';
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
        return 'Web Search';
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
