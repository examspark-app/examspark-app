import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/home/home_tab.dart' show OpenWorkspace;
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/lecture_card.dart';

/// Library tab: Folders · Search · Recent → tap card → Study Workspace.
/// Uses real `LectureService` data (kept wired per Phase 2 rule) — no
/// fake placeholder lectures, so the founder always sees true progress.
class LibraryTab extends StatefulWidget {
  final OpenWorkspace onOpenWorkspace;
  /// When this tab becomes visible again (IndexedStack), reload history.
  final bool isActive;

  const LibraryTab({
    super.key,
    required this.onOpenWorkspace,
    this.isActive = true,
  });

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _lectures = [];
  int _creditsBalance = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LibraryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && !_isLoading) {
      setState(() => _isRefreshing = true);
    }
    final user = SupabaseClient.instance.currentUser;
    try {
      final lectures = await LectureService.instance.getLecturesForUser();
      int credits = 0;
      if (user != null) {
        final profile = await SupabaseClient.instance.getUserProfile(user.id);
        credits = profile?['credits_balance'] as int? ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _lectures = lectures;
        _creditsBalance = credits;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupBySubject(List<Map<String, dynamic>> lectures) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final lecture in lectures) {
      final subject = (lecture['subject'] as String?)?.trim();
      final key = (subject == null || subject.isEmpty) ? 'Uncategorized' : subject;
      map.putIfAbsent(key, () => []).add(lecture);
    }
    return map;
  }

  void _openLecture(Map<String, dynamic> lecture) {
    final id = lecture['id'] as String?;
    if (id == null) return;
    widget.onOpenWorkspace(id, lecture['title'] as String? ?? 'Lecture', lecture['subject'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _lectures
        : _lectures
            .where((l) => (l['title'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    final recent = filtered.take(5).toList();
    final folders = _groupBySubject(filtered);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Library',
        creditsBalance: _creditsBalance,
        trailing: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh history',
            onPressed: _isRefreshing ? null : () => _load(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                children: [
                  _searchField(context),
                  const SizedBox(height: 20),
                  if (_lectures.isEmpty) _buildEmptyState(context) else ...[
                    if (recent.isNotEmpty) ..._buildSection(context, 'Recent', recent),
                    const SizedBox(height: 8),
                    Text(
                      'FOLDERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final entry in folders.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FolderTile(name: entry.key, count: entry.value.length),
                      ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _searchField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search your library…',
          prefixIcon: Icon(Icons.search, color: AppTheme.getSecondaryText(context)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  List<Widget> _buildSection(BuildContext context, String label, List<Map<String, dynamic>> lectures) {
    return [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: AppTheme.getSecondaryText(context),
        ),
      ),
      const SizedBox(height: 12),
      for (final lecture in lectures)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LectureCard(
            title: lecture['title'] as String? ?? 'Untitled Lecture',
            subject: lecture['subject'] as String?,
            dateLabel: _formatDate(lecture['created_at']),
            onTap: () => _openLecture(lecture),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined, size: 56, color: AppTheme.getSecondaryText(context)),
          const SizedBox(height: 16),
          Text(
            'No lectures yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.getSecondaryText(context)),
          ),
          const SizedBox(height: 8),
          Text(
            'Record your first lecture from Home to see it here.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'Unknown';
    }
  }
}

class _FolderTile extends StatelessWidget {
  final String name;
  final int count;

  const _FolderTile({required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppTheme.getAccentTint(context), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(Icons.folder_outlined, color: AppTheme.accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
          ),
          Text('$count', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
