import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ShareReceiverService {
  ShareReceiverService._();

  static final ShareReceiverService instance = ShareReceiverService._();

  StreamSubscription? _subscription;

  Future<void> start() async {
    // Step 3 me implementation aayega.
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}