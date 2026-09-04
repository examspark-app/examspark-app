import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Helper to resolve subject-specific icons and dark/light adaptive colors
/// for Library items, folders, and cards across ExamSpark.
class SubjectThemeHelper {
  /// Returns a tuple of (IconData, Color) for a given subject string.
  /// Automatically adapts color scheme based on Dark / Light mode.
  static (IconData, Color) getSubjectIconAndColor(
    String? subjectName,
    BuildContext context,
  ) {
    final s = (subjectName ?? '').trim().toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (s.contains('bio') ||
        s.contains('life') ||
        s.contains('botany') ||
        s.contains('zoology') ||
        s.contains('med') ||
        s.contains('health') ||
        s.contains('anat')) {
      return (
        Icons.biotech_rounded,
        isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
      );
    } else if (s.contains('physic') ||
        s.contains('astronomy') ||
        s.contains('astro') ||
        s.contains('mechanic')) {
      return (
        Icons.science_rounded,
        isDark ? const Color(0xFF42A5F5) : const Color(0xFF1565C0),
      );
    } else if (s.contains('chem') || s.contains('lab') || s.contains('organic')) {
      return (
        Icons.science_outlined,
        isDark ? const Color(0xFFFF7043) : const Color(0xFFD84315),
      );
    } else if (s.contains('math') ||
        s.contains('calc') ||
        s.contains('alg') ||
        s.contains('stat') ||
        s.contains('geom') ||
        s.contains('trig')) {
      return (
        Icons.functions_rounded,
        isDark ? const Color(0xFFAB47BC) : const Color(0xFF7B1FA2),
      );
    } else if (s.contains('info') ||
        s.contains('tech') ||
        s.contains('computer') ||
        s.contains('cs') ||
        s.contains('code') ||
        s.contains('it') ||
        s.contains('program') ||
        s.contains('soft')) {
      return (
        Icons.laptop_chromebook_rounded,
        isDark ? const Color(0xFF26A69A) : const Color(0xFF00695C),
      );
    } else if (s.contains('histor') ||
        s.contains('civic') ||
        s.contains('social') ||
        s.contains('politi') ||
        s.contains('ancient')) {
      return (
        Icons.history_edu_rounded,
        isDark ? const Color(0xFFFFA726) : const Color(0xFFE65100),
      );
    } else if (s.contains('eng') ||
        s.contains('lit') ||
        s.contains('read') ||
        s.contains('gram') ||
        s.contains('lang') ||
        s.contains('hindi') ||
        s.contains('bengali') ||
        s.contains('spanish')) {
      return (
        Icons.translate_rounded,
        isDark ? const Color(0xFFEC407A) : const Color(0xFFC2185B),
      );
    } else if (s.contains('geo') ||
        s.contains('earth') ||
        s.contains('env') ||
        s.contains('map')) {
      return (
        Icons.public_rounded,
        isDark ? const Color(0xFF9CCC65) : const Color(0xFF33691E),
      );
    } else if (s.contains('econ') ||
        s.contains('busin') ||
        s.contains('account') ||
        s.contains('finan') ||
        s.contains('commer') ||
        s.contains('trade')) {
      return (
        Icons.trending_up_rounded,
        isDark ? const Color(0xFFFFCA28) : const Color(0xFFF57F17),
      );
    } else if (s.contains('art') ||
        s.contains('design') ||
        s.contains('music') ||
        s.contains('draw') ||
        s.contains('paint')) {
      return (
        Icons.palette_rounded,
        isDark ? const Color(0xFFFF4081) : const Color(0xFFAD1457),
      );
    }

    return (
      Icons.description_outlined,
      AppTheme.accentColor,
    );
  }
}
