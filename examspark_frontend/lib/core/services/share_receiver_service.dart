import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Listens for photos, PDFs, and audio files shared into the app from
/// outside (Gallery, WhatsApp, Gmail, Files app, etc). Video is ignored —
/// this app only accepts image / pdf / audio for note generation.
class ShareReceiverService {
  ShareReceiverService._();

  static final ShareReceiverService instance = ShareReceiverService._();

  StreamSubscription? _subscription;

  /// Called whenever one or more valid (image/pdf/audio) files arrive.
  /// main.dart sets this to trigger navigation.
  void Function(List<SharedMediaFile> files)? onFilesReceived;

  /// The most recently received valid files — RecorderScreen can read this
  /// when it's opened because of a share (initialInputMethod == 'shared').
  List<SharedMediaFile> pendingFiles = [];

  Future<void> start() async {
    // Warm start: app already open, user shares into it.
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => _handleIncoming(files),
      onError: (err) {
        // Swallow errors — sharing is a nice-to-have, must never crash the app.
      },
    );

    // Cold start: app was closed, user shared and it launched the app.
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      _handleIncoming(initial);
    }
  }

  void _handleIncoming(List<SharedMediaFile> files) {
    final accepted = files.where(_isAllowed).toList();
    if (accepted.isEmpty) return;

    pendingFiles = accepted;
    onFilesReceived?.call(accepted);

    // Tell the plugin we've consumed this share so it doesn't refire.
    ReceiveSharingIntent.instance.reset();
  }

  /// Only image, pdf, and audio are allowed — video is rejected.
  bool _isAllowed(SharedMediaFile file) {
    if (file.type == SharedMediaType.video) return false;

    if (file.type == SharedMediaType.image) return true;

    if (file.type == SharedMediaType.file) {
      final mime = file.mimeType?.toLowerCase() ?? '';
      final path = file.path.toLowerCase();
      final isPdf = mime == 'application/pdf' || path.endsWith('.pdf');
      final isAudio = mime.startsWith('audio/') ||
          path.endsWith('.mp3') ||
          path.endsWith('.m4a') ||
          path.endsWith('.wav') ||
          path.endsWith('.aac');
      return isPdf || isAudio;
    }

    return false;
  }

  /// Clears the stored files once RecorderScreen has consumed them, so the
  /// same share isn't picked up again if the user backs out and returns.
  void clearPending() {
    pendingFiles = [];
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}