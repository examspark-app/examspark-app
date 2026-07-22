import 'dart:io';
import 'dart:typed_data';

Future<String> tempRecordingPath() async {
  final dir = Directory.systemTemp;
  return '${dir.path}/examspark_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

Future<Uint8List> readFileBytes(String path) {
  return File(path).readAsBytes();
}
