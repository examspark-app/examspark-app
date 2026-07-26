/// Class / level for Create Group — Class 6 → University + Custom…
/// (founder global Option A — Jul 26, 2026).
class ClassLevels {
  ClassLevels._();

  static const List<String> all = [
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    'College',
    'University',
  ];

  static List<String> optionsFor(String? current) {
    final c = (current ?? '').trim();
    if (c.isEmpty || all.contains(c)) return all;
    return [c, ...all];
  }
}
