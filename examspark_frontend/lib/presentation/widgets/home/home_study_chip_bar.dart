import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Founder Lock — Home AI Mobile UX (Jul 18, 2026).
/// Primary chips max 5; secondary tools live in More bottom sheet.
/// Credits: first open free (KO); Regenerate paid server-side.
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

/// Fixed primary row — Quiz → Flashcards → Revision → Learn More → Important Qs.
/// Visual is NOT a chip: it shows as Visual Card under the answer when available.
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
];

/// Secondary tools — More sheet (only unique jobs; duplicates of Revision/answer removed).
const kHomeMoreChips = <HomeStudyChipDef>[
  HomeStudyChipDef(
    label: 'Visual',
    toolType: 'visual',
    icon: Icons.visibility_outlined,
  ),
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
  HomeStudyChipDef(
    label: 'Common Mistakes',
    toolType: 'common_mistakes',
    icon: Icons.report_gmailerrorred_outlined,
  ),
];

/// Hidden from UI — same KO paragraphs as Revision / Learn More / Important Qs.
/// Backend APIs still accept these tool_types (no breaking change).
const kHomeHiddenDuplicateChips = <HomeStudyChipDef>[
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

/// All tool defs (lookup).
const kHomeStudyChips = <HomeStudyChipDef>[
  ...kHomePrimaryChips,
  ...kHomeMoreChips,
];

HomeStudyChipDef? homeChipByType(String toolType) {
  for (final c in kHomeStudyChips) {
    if (c.toolType == toolType) return c;
  }
  return null;
}

enum HomeChipUiState { ready, loading, generated, active }

/// Mobile-first: horizontal primary chips + More → grid sheet.
class HomeStudyChipBar extends StatelessWidget {
  final Map<String, HomeChipUiState> toolStates;
  final String? activeToolType;
  final List<String> recommended;
  final void Function(HomeStudyChipDef chip) onTap;
  final bool enabled;

  const HomeStudyChipBar({
    super.key,
    required this.toolStates,
    required this.onTap,
    this.activeToolType,
    this.recommended = const [],
    this.enabled = true,
  });

  HomeChipUiState _stateFor(String toolType) {
    if (activeToolType == toolType) return HomeChipUiState.active;
    return toolStates[toolType] ?? HomeChipUiState.ready;
  }

  Future<void> _openMoreSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = AppTheme.getCardBackground(ctx);
        final secondary = AppTheme.getSecondaryText(ctx);
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.getCardBorder(ctx)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: secondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'More study tools',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Free from this answer · AI only if you tap Regenerate',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    for (final chip in kHomeMoreChips)
                      _MoreGridTile(
                        chip: chip,
                        state: _stateFor(chip.toolType),
                        enabled: enabled &&
                            _stateFor(chip.toolType) != HomeChipUiState.loading,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onTap(chip);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppTheme.getSecondaryText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study tools',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: secondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final chip in kHomePrimaryChips) ...[
                _ChipPill(
                  chip: chip,
                  state: _stateFor(chip.toolType),
                  enabled: enabled &&
                      _stateFor(chip.toolType) != HomeChipUiState.loading,
                  onTap: () => onTap(chip),
                ),
                const SizedBox(width: 8),
              ],
              _MorePill(
                enabled: enabled,
                onTap: () => _openMoreSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MorePill extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _MorePill({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.getCardBackground(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.getCardBorder(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: AppTheme.getSecondaryText(context),
              ),
              const SizedBox(width: 6),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getPrimaryText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreGridTile extends StatelessWidget {
  final HomeStudyChipDef chip;
  final HomeChipUiState state;
  final bool enabled;
  final VoidCallback onTap;

  const _MoreGridTile({
    required this.chip,
    required this.state,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final generated = state == HomeChipUiState.generated ||
        state == HomeChipUiState.active;
    final loading = state == HomeChipUiState.loading;
    return Material(
      color: generated
          ? AppTheme.getAccentTint(context)
          : Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: generated
                  ? AppTheme.accentColor.withValues(alpha: 0.45)
                  : AppTheme.getCardBorder(context),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  chip.icon,
                  size: 22,
                  color: generated
                      ? AppTheme.accentColor
                      : AppTheme.getPrimaryText(context),
                ),
              const SizedBox(height: 8),
              Text(
                chip.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getPrimaryText(context),
                ),
              ),
              if (generated) ...[
                const SizedBox(height: 4),
                Text(
                  'Cached',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w600,
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
