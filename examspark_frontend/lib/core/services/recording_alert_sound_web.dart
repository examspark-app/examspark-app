import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Flutter Web Audio via JS interop.
JSObject? _alertCtx;

Future<void> unlockRecordingAlertSound() async {
  try {
    final ctx = _ensureCtx();
    if (ctx == null) return;
    final state = ctx.getProperty<JSString?>('state'.toJS)?.toDart;
    if (state == 'suspended') {
      final resume = ctx.callMethod<JSAny?>('resume'.toJS);
      if (resume != null) {
        await (resume as JSPromise).toDart;
      }
    }
    _beep(ctx, freq: 440, whenOffset: 0, duration: 0.04, peak: 0.001);
  } catch (_) {}
}

Future<void> playRecordingAlertSound({bool urgent = false}) async {
  try {
    final ctx = _ensureCtx();
    if (ctx == null) return;
    final state = ctx.getProperty<JSString?>('state'.toJS)?.toDart;
    if (state == 'suspended') {
      final resume = ctx.callMethod<JSAny?>('resume'.toJS);
      if (resume != null) {
        await (resume as JSPromise).toDart;
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

JSObject? _ensureCtx() {
  if (_alertCtx != null) return _alertCtx;
  final g = globalContext;
  final ctor = (g.getProperty<JSAny?>('AudioContext'.toJS) ??
      g.getProperty<JSAny?>('webkitAudioContext'.toJS)) as JSFunction?;
  if (ctor == null) return null;
  _alertCtx = ctor.callAsConstructor<JSObject>();
  return _alertCtx;
}

void _beep(
  JSObject ctx, {
  required double freq,
  required double whenOffset,
  required double duration,
  double peak = 0.22,
}) {
  final currentTime =
      ctx.getProperty<JSNumber?>('currentTime'.toJS)?.toDartDouble ?? 0;
  final when = currentTime + whenOffset;
  final osc = ctx.callMethod<JSObject>('createOscillator'.toJS);
  final gain = ctx.callMethod<JSObject>('createGain'.toJS);
  osc.callMethod<JSAny?>('connect'.toJS, gain);
  final dest = ctx.getProperty<JSObject>('destination'.toJS);
  gain.callMethod<JSAny?>('connect'.toJS, dest);

  final freqParam = osc.getProperty<JSObject>('frequency'.toJS);
  freqParam.setProperty('value'.toJS, freq.toJS);

  final gainParam = gain.getProperty<JSObject>('gain'.toJS);
  gainParam.callMethod<JSAny?>(
    'setValueAtTime'.toJS,
    0.0001.toJS,
    when.toJS,
  );
  gainParam.callMethod<JSAny?>(
    'exponentialRampToValueAtTime'.toJS,
    peak.toJS,
    (when + 0.02).toJS,
  );
  gainParam.callMethod<JSAny?>(
    'exponentialRampToValueAtTime'.toJS,
    0.0001.toJS,
    (when + duration).toJS,
  );

  osc.callMethod<JSAny?>('start'.toJS, when.toJS);
  osc.callMethod<JSAny?>('stop'.toJS, (when + duration + 0.05).toJS);
}