// Student-facing lecture errors — never show R2 / RAG / Whisper / SQL / Detail dumps.

import 'package:examspark_frontend/core/constants/student_copy.dart';

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
      'YouTube notes failed this time. Please Retry — or try another video.',
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
    'fastapi',
    'port 8000',
  ])) {
    return const LectureUserMessage(
      StudentCopy.connectionIssue,
      'N101',
    );
  }

  if (_containsAny(cleaned, const [
        'insufficient credits',
        'not enough credits',
        'credits',
      ]) &&
      _containsAny(cleaned, const [
        'insufficient',
        'required',
        'balance',
        'need',
      ])) {
    return const LectureUserMessage(
      StudentCopy.notEnoughCredits,
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
      StudentCopy.featureLocked,
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
      'Image notes failed this time. Please Retry.',
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

  if (_containsAny(cleaned, const [
    'literal_error',
    'conversation_language',
    'validation',
    'pydantic',
    'input should be',
  ])) {
    return const LectureUserMessage(
      StudentCopy.askFailed,
      'L101',
    );
  }

  // Never dump raw backend / technical Detail into the UI.
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
