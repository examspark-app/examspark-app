import 'dart:js_util' as js_util;

/// Flutter Web: [SystemSound] is silent in Chrome desktop.
/// Web Audio via JS interop (dart:html has no AudioContext type on this SDK).

Object? _alertCtx;

Future<void> unlockRecordingAlertSound() async {
  try {
    final ctx = _ensureCtx();
    if (ctx == null) return;
    if (js_util.getProperty(ctx, 'state') == 'suspended') {
      final resume = js_util.callMethod(ctx, 'resume', []);
      if (resume != null) {
        await js_util.promiseToFuture(resume);
      }
    }
    _beep(ctx, freq: 440, whenOffset: 0, duration: 0.04, peak: 0.001);
  } catch (_) {}
}

Future<void> playRecordingAlertSound({bool urgent = false}) async {
  try {
    final ctx = _ensureCtx();
    if (ctx == null) return;
    if (js_util.getProperty(ctx, 'state') == 'suspended') {
      final resume = js_util.callMethod(ctx, 'resume', []);
      if (resume != null) {
        await js_util.promiseToFuture(resume);
      }
    }
    if (urgent) {
      _beep(ctx, freq: 920, whenOffset: 0, duration: 0.16, peak: 0.35);
      _beep(ctx, freq: 920, whenOffset: 0.2, duration: 0.16, peak: 0.35);
      _beep(ctx, freq: 720, whenOffset: 0.4, duration: 0.2, peak: 0.35);
    } else {
      _beep(ctx, freq: 880, whenOffset: 0, duration: 0.18, peak: 0.28);
      _beep(ctx, freq: 660, whenOffset: 0.22, duration: 0.18, peak: 0.28);
    }
  } catch (_) {}
}

Object? _ensureCtx() {
  if (_alertCtx != null) return _alertCtx;
  final g = js_util.globalThis;
  final ctor = js_util.getProperty(g, 'AudioContext') ??
      js_util.getProperty(g, 'webkitAudioContext');
  if (ctor == null) return null;
  _alertCtx = js_util.callConstructor(ctor, []);
  return _alertCtx;
}

void _beep(
  Object ctx, {
  required double freq,
  required double whenOffset,
  required double duration,
  double peak = 0.22,
}) {
  final currentTime = (js_util.getProperty(ctx, 'currentTime') as num?)?.toDouble() ?? 0;
  final when = currentTime + whenOffset;
  final osc = js_util.callMethod(ctx, 'createOscillator', []);
  final gain = js_util.callMethod(ctx, 'createGain', []);
  js_util.callMethod(osc, 'connect', [gain]);
  final dest = js_util.getProperty(ctx, 'destination');
  js_util.callMethod(gain, 'connect', [dest]);

  final freqParam = js_util.getProperty(osc, 'frequency');
  js_util.setProperty(freqParam, 'value', freq);

  final gainParam = js_util.getProperty(gain, 'gain');
  js_util.callMethod(gainParam, 'setValueAtTime', [0.0001, when]);
  js_util.callMethod(gainParam, 'exponentialRampToValueAtTime', [peak, when + 0.02]);
  js_util.callMethod(
    gainParam,
    'exponentialRampToValueAtTime',
    [0.0001, when + duration],
  );

  js_util.callMethod(osc, 'start', [when]);
  js_util.callMethod(osc, 'stop', [when + duration + 0.05]);
}
