import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/study_tool_copy.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Founder update Jul 26, 2026 — all study chips visible (no More sheet).
/// Credits: first open free (KO) on Home; Regenerate paid server-side.
class HomeStudyChipDef {
  final String label;
  final String toolType;
  final IconData icon;
  final int credits;

  const HomeStudyChipDef({
    required this.label,
    required this.toolType,
    required this.icon,
    this.credits = 0,
  });
}

/// Visible row — core study tools.
const kHomePrimaryChips = <HomeStudyChipDef>[
  HomeStudyChipDef(
    label: 'Quiz',
    toolType: 'quiz',
    icon: Icons.quiz_outlined,
  ),
  HomeStudyChipDef(
    label: 'Flashcards',
    toolType: 'flashcards',
    icon: Icons.style_outlined,
  ),
  HomeStudyChipDef(
    label: 'Revision',
    toolType: 'revision',
    icon: Icons.article_outlined,
  ),
  HomeStudyChipDef(
    label: 'Learn More',
    toolType: 'learn_more',
    icon: Icons.menu_book_outlined,
  ),
  HomeStudyChipDef(
    label: 'Important Qs',
    toolType: 'important_questions',
    icon: Icons.priority_high,
  ),
  HomeStudyChipDef(
    label: 'Common Mistakes',
    toolType: 'common_mistakes',
    icon: Icons.report_gmailerrorred_outlined,
  ),
];

/// Was under More — now shown outside (Jul 26).
const kHomeMoreChips = <HomeStudyChipDef>[
  HomeStudyChipDef(
    label: 'Memory',
    toolType: 'memory_tricks',
    icon: Icons.psychology_outlined,
  ),
  HomeStudyChipDef(
    label: 'Mind Map',
    toolType: 'mind_map',
    icon: Icons.account_tree_outlined,
  ),
];

/// Extra tools (recording adds these; Home can show via [showExtraCatalogChips]).
const kHomeExtraChips = <HomeStudyChipDef>[
  HomeStudyChipDef(
    label: 'Cheat Sheet',
    toolType: 'cheat_sheet',
    icon: Icons.fact_check_outlined,
  ),
  HomeStudyChipDef(
    label: 'Teacher Tips',
    toolType: 'teacher_tips',
    icon: Icons.school_outlined,
  ),
  HomeStudyChipDef(
    label: 'Exam Booster',
    toolType: 'exam_booster',
    icon: Icons.military_tech_outlined,
  ),
  HomeStudyChipDef(
    label: '5 Min',
    toolType: 'five_min_revision',
    icon: Icons.timer_outlined,
  ),
];

/// Legacy alias for [kHomeExtraChips].
const kHomeHiddenDuplicateChips = kHomeExtraChips;

/// All tool defs (lookup).
const kHomeStudyChips = <HomeStudyChipDef>[
  ...kHomePrimaryChips,
  ...kHomeMoreChips,
  ...kHomeExtraChips,
];

HomeStudyChipDef? homeChipByType(String toolType) {
  for (final c in kHomeStudyChips) {
    if (c.toolType == toolType) return c;
  }
  return null;
}

enum HomeChipUiState { ready, loading, generated, active }

/// All chips visible in a wrap — no More sheet.
class HomeStudyChipBar extends StatelessWidget {
  final Map<String, HomeChipUiState> toolStates;
  final String? activeToolType;
  final List<String> recommended;
  final void Function(HomeStudyChipDef chip) onTap;
  final bool enabled;
  /// Hint line under chips (Home vs recording).
  final String? moreHint;
  /// Extra tools for this surface — shown outside.
  final List<HomeStudyChipDef> extraMoreChips;
  /// When true, also show [kHomeExtraChips] outside.
  final bool showExtraCatalogChips;

  const HomeStudyChipBar({
    super.key,
    required this.toolStates,
    required this.onTap,
    this.activeToolType,
    this.recommended = const [],
    this.enabled = true,
    this.moreHint,
    this.extraMoreChips = const [],
    this.showExtraCatalogChips = false,
  });

  HomeChipUiState _stateFor(String toolType) {
    if (activeToolType == toolType) return HomeChipUiState.active;
    return toolStates[toolType] ?? HomeChipUiState.ready;
  }

  List<HomeStudyChipDef> get _visibleChips {
    final seen = <String>{};
    final out = <HomeStudyChipDef>[];
    void addAll(Iterable<HomeStudyChipDef> list) {
      for (final c in list) {
        if (seen.add(c.toolType)) out.add(c);
      }
    }

    addAll(kHomePrimaryChips);
    addAll(kHomeMoreChips);
    if (showExtraCatalogChips) addAll(kHomeExtraChips);
    addAll(extraMoreChips);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTheme.getSecondaryText(context);
    final chips = _visibleChips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          moreHint ?? StudyToolCopy.freeDbVsRegenerateAi,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: secondary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in chips)
              _ChipPill(
                chip: chip,
                state: _stateFor(chip.toolType),
                enabled: enabled &&
                    _stateFor(chip.toolType) != HomeChipUiState.loading,
                onTap: () => onTap(chip),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChipPill extends StatelessWidget {
  final HomeStudyChipDef chip;
  final HomeChipUiState state;
  final bool enabled;
  final VoidCallback onTap;

  const _ChipPill({
    required this.chip,
    required this.state,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state == HomeChipUiState.active;
    final isGenerated = state == HomeChipUiState.generated || isActive;
    final isLoading = state == HomeChipUiState.loading;
    final border = isActive
        ? AppTheme.accentColor
        : isGenerated
            ? AppTheme.accentColor.withValues(alpha: 0.55)
            : AppTheme.getCardBorder(context);
    final bg = isActive
        ? AppTheme.accentColor.withValues(alpha: 0.16)
        : isGenerated
            ? AppTheme.getAccentTint(context)
            : AppTheme.getCardBackground(context);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  chip.icon,
                  size: 16,
                  color: isActive || isGenerated
                      ? AppTheme.accentColor
                      : AppTheme.getSecondaryText(context),
                ),
              const SizedBox(width: 6),
              Text(
                chip.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: AppTheme.getPrimaryText(context),
                ),
              ),
              if (isGenerated && !isLoading) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Cached',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
