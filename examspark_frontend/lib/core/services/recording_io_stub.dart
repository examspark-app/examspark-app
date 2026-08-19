import 'package:flutter/foundation.dart';

/// Web stub — dart:io is unavailable in the browser.
Future<String> tempRecordingPath() async {
  throw UnsupportedError('Temp recording path is not used on web.');
}

Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError('File path reads are not available on web.');
}

/// Web recordings are browser-managed blobs rather than local file paths.
Future<void> deleteTemporaryFile(String path) async {}
