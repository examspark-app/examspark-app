import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/home/home_tab.dart'
    show OpenWorkspace;

/// Universal search overlay (Phase 1B Screen #4 / Phase 2 Slice 3).
/// Lectures (Library) + Groups (joined or owned). No auth rewrite.
Future<void> showAppSearchOverlay(
  BuildContext context, {
  required OpenWorkspace onOpenLecture,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SearchOverlayScreen(onOpenLecture: onOpenLecture),
    ),
  );
}

class SearchOverlayScreen extends StatefulWidget {
  final OpenWorkspace onOpenLecture;

  const SearchOverlayScreen({super.key, required this.onOpenLecture});

  @override
  State<SearchOverlayScreen> createState() => _SearchOverlayScreenState();
}

class _SearchOverlayScreenState extends State<SearchOverlayScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _loading = true;
  List<Map<String, dynamic>> _lectures = [];
  List<GroupModel> _groups = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = SupabaseClient.instance.currentUser?.id;
    final lectures = await LectureService.instance.getLecturesForUser();
    final groups = await GroupsRepository.instance.fetchGroups();
    final searchable = groups.where((g) {
      if (g.isJoined) return true;
      if (uid != null && g.teacherUserId == uid) return true;
      return false;
    }).toList();
    if (!mounted) return;
    setState(() {
      _lectures = lectures;
      _groups = searchable;
      _loading = false;
    });
  }

  bool _matches(String haystack, String q) {
    if (q.isEmpty) return true;
    return haystack.toLowerCase().contains(q);
  }

  List<Map<String, dynamic>> get _filteredLectures {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _lectures.take(12).toList();
    return _lectures.where((l) {
      final title = (l['title'] as String?) ?? '';
      final subject = (l['subject'] as String?) ?? '';
      final topic = (l['topic'] as String?) ?? '';
      return _matches(title, q) || _matches(subject, q) || _matches(topic, q);
    }).toList();
  }

  List<GroupModel> get _filteredGroups {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _groups.take(12).toList();
    return _groups.where((g) {
      return _matches(g.name, q) ||
          _matches(g.description, q) ||
          _matches(g.teacher.fullName, q) ||
          _matches(g.teacher.subject, q);
    }).toList();
  }

  void _openLecture(Map<String, dynamic> lecture) {
    final id = lecture['id'] as String?;
    if (id == null) return;
    final title = lecture['title'] as String? ?? 'Lecture';
    final subject = lecture['subject'] as String?;
    Navigator.of(context).pop();
    widget.onOpenLecture(id, title, subject);
  }

  Future<void> _openGroup(GroupModel group) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.pushNamed(
      '/group_info',
      arguments: {'groupId': group.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final lectures = _filteredLectures;
    final groups = _filteredGroups;
    final q = _query.trim();
    final empty = !_loading && lectures.isEmpty && groups.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 60),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardBackground(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.getCardBorder(context)),
                      ),
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.6,
                        ),
                        controller: _controller,
                        focusNode: _focus,
                        onChanged: (v) => setState(() => _query = v),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search lectures & groups…',
                          hintStyle: const TextStyle(
                            fontSize: 18,
                            height: 1.6,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppTheme.getSecondaryText(context),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        ),
                      ),
                    ),
                  ),
                  if (q.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Clear',
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                        _focus.requestFocus();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : empty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              q.isEmpty
                                  ? 'No lectures or groups yet.'
                                  : 'No results for “$q”.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.getSecondaryText(context),
                                  ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            if (lectures.isNotEmpty) ...[
                              _sectionLabel(context, 'Lectures'),
                              const SizedBox(height: 8),
                              for (final lecture in lectures)
                                _ResultTile(
                                  icon: Icons.description_outlined,
                                  title: lecture['title'] as String? ?? 'Untitled',
                                  subtitle: [
                                    if ((lecture['subject'] as String?)?.isNotEmpty ==
                                        true)
                                      lecture['subject'] as String,
                                  ].join(' · '),
                                  onTap: () => _openLecture(lecture),
                                ),
                              const SizedBox(height: 16),
                            ],
                            if (groups.isNotEmpty) ...[
                              _sectionLabel(context, 'Groups'),
                              const SizedBox(height: 8),
                              for (final group in groups)
                                _ResultTile(
                                  icon: Icons.groups_outlined,
                                  title: group.name,
                                  subtitle: [
                                    if (group.teacher.fullName.isNotEmpty)
                                      group.teacher.fullName,
                                    if (group.teacher.subject.isNotEmpty)
                                      group.teacher.subject,
                                  ].join(' · '),
                                  onTap: () => _openGroup(group),
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: AppTheme.getSecondaryText(context),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
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
                  child: Icon(icon, color: AppTheme.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 14,
                            ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.getSecondaryText(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}