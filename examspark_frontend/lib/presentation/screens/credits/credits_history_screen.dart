import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_history_display.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Read-only ledger of credit spend / grants from `credit_transactions`.
class CreditsHistoryScreen extends StatefulWidget {
  const CreditsHistoryScreen({super.key});

  @override
  State<CreditsHistoryScreen> createState() => _CreditsHistoryScreenState();
}

class _CreditsHistoryScreenState extends State<CreditsHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String _filter = CreditHistoryDisplay.filterAll;
  String _renewLabel = '—';
  int _monthSpent = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please log in to see credit history.';
          _rows = [];
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final txs = await SupabaseClient.instance.getCreditTransactions(userId);
      final renew = await _fetchRenewLabel(userId);
      if (!mounted) return;
      setState(() {
        _rows = txs;
        _monthSpent = CreditHistoryDisplay.monthSpentCredits(txs);
        _renewLabel = renew;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load credit history. Please try again.';
      });
    }
  }

  Future<String> _fetchRenewLabel(String userId) async {
    try {
      final planId = await SupabaseClient.instance.getPlanTier(userId);
      if (planId == 'free') return 'Free plan';

      final row = await SupabaseClient.instance.client
          .from('user_subscriptions')
          .select('current_period_end')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('current_period_end', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return 'Active';
      final raw = row['current_period_end'] as String?;
      if (raw == null || raw.isEmpty) return 'Active';
      final end = DateTime.tryParse(raw)?.toLocal();
      if (end == null) return 'Active';
      final days = end.difference(DateTime.now()).inDays;
      if (days < 0) return 'Renewal due';
      if (days == 0) return 'Renews today';
      if (days == 1) return 'Renews in 1 day';
      return 'Renews in $days days';
    } catch (_) {
      return '—';
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _rows
        .where(
          (r) => CreditHistoryDisplay.matchesFilter(
            r['action'] as String?,
            _filter,
          ),
        )
        .toList();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{
      for (final s in CreditHistoryDisplay.sectionOrder) s: [],
    };
    for (final row in _filtered) {
      final dt = CreditHistoryDisplay.parseCreatedAt(row['created_at']);
      final key = dt == null
          ? 'Earlier'
          : CreditHistoryDisplay.sectionBucket(dt);
      map.putIfAbsent(key, () => []).add(row);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Credits History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBody()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _summaryHeader()),
                      SliverToBoxAdapter(child: _filterChips()),
                      if (_filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _emptyState(),
                        )
                      else
                        ..._sectionSlivers(),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryHeader() {
    final spentLabel = _monthSpent.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Month',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '$spentLabel Credits Used',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _renewLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    const chips = [
      (CreditHistoryDisplay.filterAll, 'All'),
      (CreditHistoryDisplay.filterRecordings, 'Recordings'),
      (CreditHistoryDisplay.filterStudyTools, 'Study Tools'),
      (CreditHistoryDisplay.filterAskAi, 'Ask AI'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in chips) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.$2),
                  selected: _filter == c.$1,
                  onSelected: (_) => setState(() => _filter = c.$1),
                  selectedColor: Colors.black87,
                  labelStyle: TextStyle(
                    color: _filter == c.$1 ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  showCheckmark: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No usage yet — your credit history will appear here once you start using AI features.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.getSecondaryText(context),
                height: 1.4,
              ),
        ),
      ),
    );
  }

  List<Widget> _sectionSlivers() {
    final grouped = _grouped;
    final out = <Widget>[];
    for (final section in CreditHistoryDisplay.sectionOrder) {
      final items = grouped[section] ?? [];
      if (items.isEmpty) continue;
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              section,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
            ),
          ),
        ),
      );
      out.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final row = items[index];
                return Column(
                  children: [
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: AppTheme.getCardBorder(context),
                      ),
                    _historyRow(row),
                  ],
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      );
    }
    return out;
  }

  void _openRowDestination(Map<String, dynamic> row) {
    if (!CreditHistoryDisplay.canOpenStudyWorkspace(row)) {
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      if (amount > 0) {
        Navigator.pushNamed(context, '/subscription');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This use was from Home chat — open Home to see it. '
            'No extra credits on tap.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final lectureId = CreditHistoryDisplay.lectureIdFromRow(row)!;
    final lecture = CreditHistoryDisplay.lectureFromRow(row);
    final title = (lecture?['title'] as String?)?.trim();
    final topic = (lecture?['topic'] as String?)?.trim();
    final subject = (lecture?['subject'] as String?)?.trim();
    final action = row['action'] as String?;
    final tab = CreditHistoryDisplay.workspaceTabIndexForAction(action);

    Navigator.pushNamed(
      context,
      '/study_workspace',
      arguments: {
        'lectureId': lectureId,
        'title': (title != null && title.isNotEmpty)
            ? title
            : ((topic != null && topic.isNotEmpty) ? topic : 'Lecture'),
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        'initialTabIndex': tab,
      },
    );
  }

  Widget _historyRow(Map<String, dynamic> row) {
    final amount = (row['amount'] as num?)?.toInt() ?? 0;
    final isCredit = amount > 0;
    final action = row['action'] as String?;
    final description = row['description'] as String?;
    final lecture = CreditHistoryDisplay.lectureFromRow(row);
    final label = CreditHistoryDisplay.featureLabel(action, description);
    final contextLine = CreditHistoryDisplay.contextLine(
      description: description,
      lecture: lecture,
    );
    final dt = CreditHistoryDisplay.parseCreatedAt(row['created_at']);
    final when = dt != null ? CreditHistoryDisplay.formatTimeLabel(dt) : '—';
    final amountLabel = isCredit
        ? '+$amount Credits'
        : '-${amount.abs()} Credits';
    final tappable = CreditHistoryDisplay.canOpenStudyWorkspace(row) || isCredit;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CreditHistoryDisplay.featureIcon(action),
              size: 20,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amountLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isCredit
                                ? Colors.green.shade700
                                : AppTheme.accentColor,
                          ),
                    ),
                  ],
                ),
                if (contextLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contextLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  when,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
              ],
            ),
          ),
          if (tappable) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 22,
              color: Colors.grey.shade500,
            ),
          ],
        ],
      ),
    );

    return Material(
      color: AppTheme.getCardBackground(context),
      child: tappable
          ? InkWell(
              onTap: () => _openRowDestination(row),
              child: content,
            )
          : content,
    );
  }
}
