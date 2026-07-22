/// Client-side reading-time helpers for Study Workspace (no backend).
library;

const int kWordsPerMinute = 230;

int countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// Estimated reading minutes (minimum 1 when there is any text).
int estimatedReadingMinutes(String text) {
  final words = countWords(text);
  if (words == 0) return 0;
  final mins = (words / kWordsPerMinute).ceil();
  return mins < 1 ? 1 : mins;
}

String formatReadingTime(int minutes) {
  if (minutes <= 0) return '—';
  if (minutes == 1) return '1 min';
  return '$minutes min';
}

String formatCreatedDate(DateTime? dt) {
  if (dt == null) return '';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year}';
}

/// Library / Recent label — e.g. `3:45pm` (today) or `21/7 · 3:45pm`.
String formatOpenedAtLabel(dynamic raw) {
  final dt = parseCreatedAt(raw)?.toLocal();
  if (dt == null) return '';
  final time = _formatAmPm(dt);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return time;
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == yesterday) return 'Yesterday · $time';
  return '${dt.day}/${dt.month} · $time';
}

String _formatAmPm(DateTime dt) {
  var hour = dt.hour % 12;
  if (hour == 0) hour = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour >= 12 ? 'pm' : 'am';
  return '$hour:$minute$suffix';
}

DateTime? parseCreatedAt(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}
