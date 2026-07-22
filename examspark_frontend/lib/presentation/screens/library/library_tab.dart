import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/home/home_tab.dart' show OpenWorkspace;
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/lecture_card.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_reading_utils.dart';

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
  /// null = root Library (folders list). Non-null = open subject folder.
  String? _openFolderName;

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

  /// Same title + subject + calendar day → keep newest only (retry spam).
  List<Map<String, dynamic>> _dedupeLectures(List<Map<String, dynamic>> lectures) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final lecture in lectures) {
      final title = ((lecture['title'] as String?) ?? '').trim().toLowerCase();
      final subject = ((lecture['subject'] as String?) ?? '').trim().toLowerCase();
      final created = (lecture['created_at'] as String?) ?? '';
      final day = created.length >= 10 ? created.substring(0, 10) : created;
      final key = '$title|$subject|$day';
      if (title.isEmpty) {
        out.add(lecture);
        continue;
      }
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(lecture);
    }
    return out;
  }

  void _closeFolder() {
    setState(() => _openFolderName = null);
  }

  void _openFolder(String name) {
    setState(() => _openFolderName = name);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && !_isLoading) {
      setState(() => _isRefreshing = true);
    }
    final user = SupabaseClient.instance.currentUser;
    try {
      final lectures = await LectureService.instance.getLecturesForUser();
      final deduped = _dedupeLectures(lectures);
      int credits = 0;
      if (user != null) {
        final profile = await SupabaseClient.instance.getUserProfile(user.id);
        credits = profile?['credits_balance'] as int? ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _lectures = deduped;
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

    // Subject folder open: show only that folder's lectures (IA: Library → Physics tap).
    if (_openFolderName != null) {
      final folderLectures =
          _groupBySubject(_lectures)[_openFolderName!] ?? const <Map<String, dynamic>>[];
      return Scaffold(
        appBar: AppTopBar(
          title: _openFolderName!,
          creditsBalance: _creditsBalance,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to Library',
            onPressed: _closeFolder,
          ),
          trailing: [
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
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
                    Text(
                      '${folderLectures.length} lecture${folderLectures.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (folderLectures.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No lectures in this folder.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.getSecondaryText(context),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final lecture in folderLectures)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LectureCard(
                            title: lecture['title'] as String? ?? 'Untitled Lecture',
                            subject: lecture['subject'] as String?,
                            dateLabel: formatOpenedAtLabel(
                              lecture['last_opened_at'] ?? lecture['created_at'],
                            ),
                            onTap: () => _openLecture(lecture),
                          ),
                        ),
                  ],
                ),
              ),
      );
    }

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
                        child: _FolderTile(
                          name: entry.key,
                          count: entry.value.length,
                          onTap: () => _openFolder(entry.key),
                        ),
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
            dateLabel: formatOpenedAtLabel(
              lecture['last_opened_at'] ?? lecture['created_at'],
            ),
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
}

class _FolderTile extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;

  const _FolderTile({
    required this.name,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
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
                decoration: BoxDecoration(
                  color: AppTheme.getAccentTint(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.folder_outlined, color: AppTheme.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
                ),
              ),
              Text('$count', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.getSecondaryText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
