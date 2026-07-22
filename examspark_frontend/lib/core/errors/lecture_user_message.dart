// Student-facing lecture errors — never show R2 / RAG / Whisper / SSL / pipeline.

class LectureUserMessage {
  final String message;
  final String code;

  const LectureUserMessage(this.message, this.code);

  String get display => '$message ($code)';
}

/// Map raw exceptions / backend strings to a simple message + support code.
LectureUserMessage mapLectureUserError(Object? error) {
  final raw = (error ?? '').toString().toLowerCase();
  final cleaned = raw
      .replaceFirst(RegExp(r'^exception:\s*'), '')
      .replaceFirst(RegExp(r'^stateerror:\s*'), '')
      .trim();

  if (_containsAny(cleaned, const [
        'private',
        'age-restricted',
        'age restricted',
        'region-locked',
        'region locked',
        'unavailable for audio',
        'could not access this video',
        'captions',
        'no captions',
        'subtitles',
        'youtube',
        'whisper fallback failed',
        'http error 403',
        '403',
        'forbidden',
      ]) &&
      _containsAny(cleaned, const [
        'private',
        'age',
        'region',
        'unavailable',
        'caption',
        'subtitle',
        'access',
        'forbidden',
        '403',
        'whisper',
        'download',
      ])) {
    return const LectureUserMessage(
      'YouTube notes failed this time (captions or audio download). '
      'Please Retry — non-CC videos still use Whisper download like before.',
      'V101',
    );
  }

  if (_containsAny(cleaned, const [
    'ssl',
    'bad record mac',
    'timeout',
    'timed out',
    'network',
    'connection',
    'socket',
    'failed host lookup',
    'clientexception',
  ])) {
    return const LectureUserMessage(
      'The connection was interrupted. Check your internet and try again.',
      'N101',
    );
  }

  if (_containsAny(cleaned, const [
    'insufficient credits',
    'not enough credits',
    'credits',
  ]) &&
      _containsAny(cleaned, const ['insufficient', 'required', 'balance', 'need'])) {
    return const LectureUserMessage(
      'You don’t have enough credits for this action.',
      'C101',
    );
  }

  if (_containsAny(cleaned, const [
    'feature_locked',
    '🔒',
    'upgrade your plan',
    'not included in your plan',
    'locked',
  ])) {
    return const LectureUserMessage(
      'This feature is locked on your current plan.',
      'P101',
    );
  }

  if (_containsAny(cleaned, const [
    'little extractable text',
    'scan',
    'image-only pdf',
    'pdf',
  ]) &&
      _containsAny(cleaned, const [
        'text',
        'scan',
        'pdf',
        'extract',
      ])) {
    return const LectureUserMessage(
      'We couldn’t read this PDF. Try a text-based PDF or upload a clear image.',
      'D101',
    );
  }

  if (_containsAny(cleaned, const [
    'qwen3-vl',
    'cannot identify image',
    'image_upload',
    'vision model',
  ]) ||
      (_containsAny(cleaned, const ['image', 'diagram', 'photo']) &&
          _containsAny(cleaned, const [
            'couldn’t read',
            'could not read',
            'failed to read',
            'unclear',
            'vision',
            'ocr',
          ]))) {
    return const LectureUserMessage(
      'Image notes failed this time. Please Retry — if it keeps failing, tell us the backend log line.',
      'I101',
    );
  }

  if (_containsAny(cleaned, const [
    'no speech',
    'check your mic',
    'check your microphone',
    'microphone',
    'kindly check',
  ])) {
    return const LectureUserMessage(
      'No speech detected. Kindly check your mic and try again.',
      'A101',
    );
  }

  if (_containsAny(cleaned, const [
    'whisper',
    'transcrib',
    'audio',
    'groq',
  ])) {
    return const LectureUserMessage(
      'We couldn’t convert the audio. Please try again.',
      'A101',
    );
  }

  if (_containsAny(cleaned, const [
    'delete',
    'couldn’t delete',
    'could not delete',
  ])) {
    return const LectureUserMessage(
      'We couldn’t delete this lecture. Please try again.',
      'L102',
    );
  }

  // Keep raw hint so Retry failures are diagnosable (not a silent dead-end).
  final hint = cleaned
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final short = hint.length > 120 ? '${hint.substring(0, 117)}…' : hint;
  if (short.isNotEmpty && short != 'null' && short != 'exception:') {
    return LectureUserMessage(
      'We couldn’t finish this lecture. Detail: $short',
      'L101',
    );
  }
  return const LectureUserMessage(
    'We couldn’t finish this lecture. Please try again.',
    'L101',
  );
}

String lectureUserMessage(Object? error) => mapLectureUserError(error).display;

bool _containsAny(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n)) return true;
  }
  return false;
}
