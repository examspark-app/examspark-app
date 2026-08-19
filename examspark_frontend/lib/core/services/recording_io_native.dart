import 'dart:io';
import 'dart:typed_data';

Future<String> tempRecordingPath() async {
  final dir = Directory.systemTemp;
  return '${dir.path}/examspark_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

Future<Uint8List> readFileBytes(String path) {
  return File(path).readAsBytes();
}

/// Best-effort removal for privacy-sensitive, one-turn temporary recordings.
Future<void> deleteTemporaryFile(String path) async {
  if (path.trim().isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Cleanup must not prevent the already-buffered audio from being processed.
  }
}
