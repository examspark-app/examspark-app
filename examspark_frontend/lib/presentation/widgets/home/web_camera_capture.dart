import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Chrome / Flutter Web: ask webcam permission and capture one JPEG frame.
Future<Uint8List?> captureWebCameraPhoto(BuildContext context) async {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WebCameraDialog(),
  );
}

class _WebCameraDialog extends StatefulWidget {
  const _WebCameraDialog();

  @override
  State<_WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<_WebCameraDialog> {
  html.MediaStream? _stream;
  html.VideoElement? _video;
  String? _error;
  bool _ready = false;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'examspark-webcam-${DateTime.now().millisecondsSinceEpoch}';
    _start();
  }

  Future<void> _start() async {
    try {
      final stream = await html.window.navigator.mediaDevices!
          .getUserMedia({'video': true, 'audio': false});
      _stream = stream;
      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..srcObject = stream;
      _video = video;
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => video,
      );
      await video.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Camera permission blocked or webcam unavailable.\nUse Upload Image, or allow camera in browser site settings.';
      });
    }
  }

  void _stopTracks() {
    final tracks = _stream?.getTracks() ?? [];
    for (final t in tracks) {
      t.stop();
    }
    _stream = null;
  }

  Future<void> _capture() async {
    final video = _video;
    if (video == null) return;
    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w <= 0 || h <= 0) return;
    final canvas = html.CanvasElement(width: w, height: h);
    canvas.context2D.drawImageScaled(video, 0, 0, w, h);
    final blob = await canvas.toBlob('image/jpeg', 0.85);
    final reader = html.FileReader();
    final done = Completer<Uint8List?>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        done.complete(Uint8List.view(result));
      } else if (result is List<int>) {
        done.complete(Uint8List.fromList(result));
      } else {
        done.complete(null);
      }
    });
    reader.readAsArrayBuffer(blob);
    final bytes = await done.future;
    _stopTracks();
    if (!mounted) return;
    Navigator.of(context).pop(bytes);
  }

  @override
  void dispose() {
    _stopTracks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Camera'),
      content: SizedBox(
        width: 360,
        height: 280,
        child: _error != null
            ? Center(
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.getSecondaryText(context)),
                ),
              )
            : !_ready
                ? const Center(child: CircularProgressIndicator())
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: HtmlElementView(viewType: _viewType),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _stopTracks();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        if (_error == null)
          FilledButton(
            onPressed: _ready ? _capture : null,
            child: const Text('Use photo'),
          ),
      ],
    );
  }
}
