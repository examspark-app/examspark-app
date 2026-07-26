/// Shared "Custom…" option for global-friendly fields (Language / Exam / Class / Subject).
/// Presets stay short; free text stores as-is so fuzzy Discover / suggest still match.
class CustomFieldOption {
  CustomFieldOption._();

  static const label = 'Custom…';

  static bool isCustom(String? value) => value == label;

  /// Dropdown items: **Custom… first**, then short presets (founder Jul 26).
  static List<String> presetsPlusCustom(List<String> presets) =>
      [label, ...presets];

  /// Dropdown selection → stored value (null if empty / incomplete custom).
  static String? resolve(String? selected, String customText) {
    final s = (selected ?? '').trim();
    if (s.isEmpty) return null;
    if (isCustom(s)) {
      final t = customText.trim();
      return t.isEmpty ? null : t;
    }
    return s;
  }

  /// Load stored value into dropdown + optional custom text field.
  static ({String dropdown, String custom}) split(
    String? stored,
    List<String> presets,
  ) {
    final v = (stored ?? '').trim();
    if (v.isEmpty) return (dropdown: '', custom: '');
    if (presets.contains(v)) return (dropdown: v, custom: '');
    return (dropdown: label, custom: v);
  }
}
