import 'dart:async';

import 'package:flutter/material.dart';

/// Word-by-word typewriter reveal for AI answers (client-side; no streaming).
///
/// - ~30 ms per word, hard-capped so long answers finish within ~6 s
/// - Tap anywhere → skip to full text
/// - [onComplete] fires once (reveal finished or skipped)
class AiTypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final VoidCallback? onComplete;
  final Duration wordInterval;
  final Duration maxDuration;

  const AiTypewriterText({
    super.key,
    required this.text,
    this.style,
    this.onComplete,
    this.wordInterval = const Duration(milliseconds: 30),
    this.maxDuration = const Duration(seconds: 6),
  });

  @override
  State<AiTypewriterText> createState() => _AiTypewriterTextState();
}

class _AiTypewriterTextState extends State<AiTypewriterText>
    with AutomaticKeepAliveClientMixin {
  late final List<String> _tokens;
  int _visibleCount = 0;
  bool _done = false;
  Timer? _timer;

  @override
  bool get wantKeepAlive => !_done;

  @override
  void initState() {
    super.initState();
    _tokens = _tokenize(widget.text);
    if (_tokens.isEmpty) {
      _finish();
      return;
    }
    final intervalMs = _effectiveIntervalMs();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted || _done) return;
      setState(() {
        _visibleCount++;
        if (_visibleCount >= _tokens.length) {
          _finish();
        }
      });
    });
  }

  int _effectiveIntervalMs() {
    final base = widget.wordInterval.inMilliseconds.clamp(10, 200);
    if (_tokens.isEmpty) return base;
    final maxMs = widget.maxDuration.inMilliseconds;
    final needed = _tokens.length * base;
    if (needed <= maxMs) return base;
    return (maxMs / _tokens.length).ceil().clamp(8, base);
  }

  /// Split on whitespace but keep separators so layout (newlines) is preserved.
  List<String> _tokenize(String text) {
    if (text.isEmpty) return const [];
    final out = <String>[];
    final re = RegExp(r'\S+|\s+');
    for (final m in re.allMatches(text)) {
      out.add(m.group(0)!);
    }
    return out;
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _timer = null;
    _visibleCount = _tokens.length;
    // Defer so we never setState parent during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onComplete?.call();
    });
  }

  void _skip() {
    if (_done) return;
    setState(_finish);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visible = _done
        ? widget.text
        : _tokens.take(_visibleCount).join();

    final body = _done
        ? SelectableText(visible, style: widget.style)
        : Text(visible, style: widget.style);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _done ? null : _skip,
      child: body,
    );
  }
}
