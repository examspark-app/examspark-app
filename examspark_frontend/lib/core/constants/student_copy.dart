/// Student-facing copy — no RAG / database / FastAPI / SQL / R2 jargon.
class StudentCopy {
  StudentCopy._();

  static const savedFree =
      'Saved · free to reopen · Regenerate AI = new result (credits)';

  static const recordingPaidFirst =
      'First generate uses credits · Reopen free · Regenerate AI = new result (credits)';

  static const regenerateButton = 'Regenerate AI';

  static String creditsFooter({required bool fromSaved, int? charged}) {
    if (fromSaved) return '0 credits · already saved';
    if (charged != null) return '$charged credits · AI generate';
    return 'Credits · AI generate';
  }

  static const tryAgain = 'Something went wrong. Please try again.';
  static const tryAgainShort = 'Please try again.';
  static const serverBusy =
      'Server is busy or offline. Wait a moment, then try again.';
  static const connectionIssue =
      'Connection issue. Check your internet and try again.';
  static const notEnoughCredits =
      'You don’t have enough credits for this action.';
  static const featureLocked =
      'This feature is locked on your current plan.';
  static const askFailed =
      'We couldn’t answer that right now. Please try again.';
  static const homeFailed =
      'We couldn’t complete this request. Please try again.';
  static const toolReady = 'Ready · 0 credits (saved)';
}

/// Strip / map technical error text before showing in UI.
String studentSafeError(Object? error, {String fallback = StudentCopy.tryAgain}) {
  var raw = (error ?? '').toString();
  raw = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
  raw = raw.replaceFirst(RegExp(r'^StateError:\s*'), '');
  raw = raw.trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') return fallback;

  final lower = raw.toLowerCase();

  if (_any(lower, const [
    'literal_error',
    'conversation_language',
    'validation',
    'input should be',
    'pydantic',
    'field required',
    'type_error',
  ])) {
    return StudentCopy.askFailed;
  }
  if (_any(lower, const [
    'fastapi',
    'not found',
    '404',
    'api not found',
  ]) &&
      _any(lower, const ['home ai', 'ask ai', 'api', 'route', 'not found'])) {
    return StudentCopy.serverBusy;
  }
  if (_any(lower, const [
    'timeout',
    'timed out',
    '120s',
    'restart the fastapi',
    'port 8000',
  ])) {
    return StudentCopy.serverBusy;
  }
  if (_any(lower, const [
    'ssl',
    'network',
    'connection',
    'socket',
    'failed host lookup',
    'clientexception',
  ])) {
    return StudentCopy.connectionIssue;
  }
  if (_any(lower, const ['insufficient credits', 'not enough credits']) ||
      (lower.contains('credits') &&
          _any(lower, const ['insufficient', 'required', 'balance', 'need']))) {
    return StudentCopy.notEnoughCredits;
  }
  if (_any(lower, const [
    'feature_locked',
    'upgrade your plan',
    'not included in your plan',
  ])) {
    return StudentCopy.featureLocked;
  }

  // Already student-friendly (short, no tech jargon)?
  if (!_looksTechnical(lower) && raw.length <= 160 && !raw.contains('{')) {
    return raw.startsWith('🔒') ? raw : raw;
  }

  return fallback;
}

bool _looksTechnical(String lower) {
  const bad = [
    'rag',
    'r2',
    'fastapi',
    'supabase',
    'openrouter',
    'whisper',
    'groq',
    'embedding',
    'pgvector',
    'sql',
    'migration',
    'literal_error',
    'pydantic',
    'traceback',
    'stack',
    'httpx',
    'status_code',
    'loc',
    "['body'",
    'railway',
    'cloudflare',
    'sse',
    'json',
    'uuid',
    'rpc',
    'detail:',
  ];
  for (final b in bad) {
    if (lower.contains(b)) return true;
  }
  return false;
}

bool _any(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n)) return true;
  }
  return false;
}
