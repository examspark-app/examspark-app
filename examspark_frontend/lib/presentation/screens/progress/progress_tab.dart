import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/progress_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';

/// Progress tab — student learning coach (Slice 1 live).
/// Personal only — never Home AI chats, private notes, or conversation history.
class ProgressTab extends StatefulWidget {
  final bool isActive;

  const ProgressTab({
    super.key,
    this.isActive = true,
  });

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  bool _loading = true;
  String? _error;
  ProgressSnapshot _data = ProgressSnapshot.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProgressTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await ProgressService.instance.load();
      if (!mounted) return;
      setState(() {
        _data = snap;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load progress. Pull to refresh or try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Progress'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _data.lectureCount == 0 && _data.recent.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
    }

    if (_error != null && _data.lectureCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          const SizedBox(height: 80),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final streakLabel =
        _data.streakDays == 1 ? '1 day' : '${_data.streakDays} days';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Study Streak',
                value: streakLabel,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _StatCard(
                icon: Icons.schedule_outlined,
                label: 'Study Time',
                value: '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.verified_outlined,
                label: 'Topics Mastered',
                value: '${_data.topicsMastered}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.insights_outlined,
                label: 'Learning Score',
                value: _data.learningScorePercent != null
                    ? '${_data.learningScorePercent}%'
                    : '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionLabel(text: 'AI INSIGHTS'),
        const SizedBox(height: 12),
        if (_data.strongSubject != null)
          _InsightCard(
            icon: Icons.check_circle_outline,
            title: 'Strong Subject',
            primary: _data.strongSubject!,
            secondary: _data.strongCount == 1
                ? '1 lecture saved'
                : '${_data.strongCount} lectures saved',
          )
        else
          const _InsightCard(
            icon: Icons.check_circle_outline,
            title: 'Strong Subject',
            primary: 'Not enough data yet',
            secondary: 'Save lectures with a subject',
          ),
        if (_data.weakSubject != null)
          _InsightCard(
            icon: Icons.warning_amber_outlined,
            title: 'Needs Improvement',
            primary: _data.weakSubject!,
            secondary: _data.weakCount == 1
                ? '1 lecture saved'
                : '${_data.weakCount} lectures saved',
          )
        else
          const _InsightCard(
            icon: Icons.warning_amber_outlined,
            title: 'Needs Improvement',
            primary: 'Add another subject',
            secondary: 'Compare subjects after more lectures',
          ),
        _InsightCard(
          icon: Icons.flag_outlined,
          title: 'Recommended Next',
          primary: _data.recommendPrimary ?? 'Continue studying',
          secondary: _data.recommendSecondary ?? 'Open Library',
        ),
        const SizedBox(height: 24),
        const _SectionLabel(text: 'WEEKLY PROGRESS'),
        const SizedBox(height: 12),
        _WeeklyProgressCard(
          values: _data.weeklyCounts,
          labels: _data.weeklyLabels,
        ),
        const SizedBox(height: 24),
        const _SectionLabel(text: 'RECENT ACTIVITY'),
        const SizedBox(height: 12),
        if (_data.recent.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No study activity yet. Record a lecture or finish a quiz.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final item in _data.recent)
            _ActivityTile(
              icon: item.icon,
              title: item.title,
              line2: item.line2,
              line3: item.line3,
            ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _data.learningScorePercent == null
                ? 'Learning Score appears after you finish a Study Workspace quiz. '
                    'Study Time not tracked yet.'
                : 'Learning Score = average of your recent quiz finishes. '
                    'Study Time not tracked yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: AppTheme.getSecondaryText(context),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentColor, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String primary;
  final String secondary;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.getAccentTint(context),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppTheme.accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    primary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    secondary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  final List<int> values;
  final List<String> labels;

  const _WeeklyProgressCard({
    required this.values,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.fold<int>(1, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 days · lectures saved or opened',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 88,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: values[i] == 0
                                  ? 0.08
                                  : (values[i] / maxVal).clamp(0.12, 1.0),
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withValues(
                                    alpha: values[i] == 0 ? 0.25 : 0.85,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line2;
  final String? line3;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.line2,
    this.line3,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.getAccentTint(context),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppTheme.accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 14,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(line2, style: Theme.of(context).textTheme.bodySmall),
                  if (line3 != null) ...[
                    const SizedBox(height: 2),
                    Text(line3!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
