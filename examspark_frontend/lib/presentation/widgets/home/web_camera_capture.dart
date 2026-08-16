import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Chrome / Flutter Web:
/// Open camera with rear camera by default, allow front/rear switching,
/// and capture one JPEG frame.
Future<Uint8List?> captureWebCameraPhoto(
  BuildContext context,
) async {
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
  bool _switchingCamera = false;

  /// Start with rear camera for mobile web.
  bool _useFrontCamera = false;

  late final String _viewType;

  @override
  void initState() {
    super.initState();

    _viewType =
        'examspark-webcam-${DateTime.now().millisecondsSinceEpoch}';

    _start();
  }

  Future<void> _start() async {
    try {
      _error = null;

      final facingMode =
          _useFrontCamera ? 'user' : 'environment';

      final stream =
          await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': {
            'ideal': facingMode,
          },
          'width': {
            'ideal': 1920,
          },
          'height': {
            'ideal': 1080,
          },
        },
        'audio': false,
      });

      _stopTracks();

      _stream = stream;

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.display = 'block'
        ..srcObject = stream;

      _video = video;

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => video,
      );

      await video.play();

      if (!mounted) return;

      setState(() {
        _ready = true;
        _switchingCamera = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _ready = false;
        _switchingCamera = false;
        _error =
            'Camera permission blocked or webcam unavailable.\n'
            'Allow camera access in browser settings, or use Upload Image.';
      });
    }
  }

  void _stopTracks() {
    final tracks = _stream?.getTracks() ?? [];

    for (final track in tracks) {
      track.stop();
    }

    _stream = null;
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera) return;

    setState(() {
      _switchingCamera = true;
      _ready = false;
    });

    _stopTracks();

    _useFrontCamera = !_useFrontCamera;

    await _start();
  }

  Future<void> _capture() async {
    final video = _video;

    if (video == null) return;

    final width = video.videoWidth;
    final height = video.videoHeight;

    if (width <= 0 || height <= 0) {
      return;
    }

    final canvas = html.CanvasElement(
      width: width,
      height: height,
    );

    canvas.context2D.drawImageScaled(
      video,
      0,
      0,
      width,
      height,
    );

    final blob = await canvas.toBlob(
      'image/jpeg',
      0.85,
    );

    final reader = html.FileReader();

    final done = Completer<Uint8List?>();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;

      if (result is ByteBuffer) {
        done.complete(
          Uint8List.view(result),
        );
      } else if (result is List<int>) {
        done.complete(
          Uint8List.fromList(result),
        );
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

  void _cancel() {
    _stopTracks();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopTracks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraLabel =
        _useFrontCamera
            ? 'Front camera'
            : 'Back camera';

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 760,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                14,
                12,
                12,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Camera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Switch camera',
                    onPressed:
                        _ready &&
                                !_switchingCamera
                            ? _switchCamera
                            : null,
                    icon: const Icon(
                      Icons.flip_camera_ios,
                    ),
                    color: Colors.white,
                  ),

                  IconButton(
                    tooltip: 'Close',
                    onPressed: _cancel,
                    icon: const Icon(
                      Icons.close,
                    ),
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            // Camera preview
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  child:
                      _error != null
                          ? Container(
                              color:
                                  Colors.black87,
                              alignment:
                                  Alignment.center,
                              padding:
                                  const EdgeInsets
                                      .all(24),
                              child: Text(
                                _error!,
                                textAlign:
                                    TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme
                                      .getSecondaryText(
                                    context,
                                  ),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : !_ready
                              ? const ColoredBox(
                                  color:
                                      Colors.black87,
                                  child:
                                      Center(
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          Colors.white,
                                    ),
                                  ),
                                )
                              : HtmlElementView(
                                  viewType:
                                      _viewType,
                                ),
                ),
              ),
            ),

            // Bottom controls
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cameraLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: _cancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  FilledButton.icon(
                    onPressed:
                        _ready &&
                                !_switchingCamera
                            ? _capture
                            : null,
                    icon: const Icon(
                      Icons.camera_alt,
                    ),
                    label: const Text(
                      'Use photo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}