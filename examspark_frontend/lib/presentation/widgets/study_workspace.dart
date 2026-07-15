import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/share_to_group_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/workspace_ask_ai_pane.dart';

/// ExamSpark's core differentiator widget.
///
/// ChatGPT = conversation only. ExamSpark = conversation + Study Workspace.
/// One shared widget, used everywhere a lecture is opened:
///   - Mobile: opened as a swipe-up bottom sheet (`showStudyWorkspaceSheet`)
///   - Desktop: embedded directly as a right-side split panel
///
/// Canonical tabs: Notes · Summary · Transcript · Flashcards · Quiz ·
/// Revision · Ask AI.
///
/// Notes / Summary load real content via [LectureService.fetchLectureNotes]
/// (same R2 path as NotesResultScreen). Flashcards / Quiz / Revision stay
/// honest placeholders until Generate More is on FastAPI.
class StudyWorkspace extends StatefulWidget {
  final String lectureId;
  final String title;
  final String? subject;
  final VoidCallback? onClose;

  const StudyWorkspace({
    super.key,
    required this.lectureId,
    required this.title,
    this.subject,
    this.onClose,
  });

  static const List<_WorkspaceTab> _tabs = [
    _WorkspaceTab('Notes', Icons.description_outlined),
    _WorkspaceTab('Summary', Icons.summarize_outlined),
    _WorkspaceTab('Transcript', Icons.article_outlined),
    _WorkspaceTab('Flashcards', Icons.style_outlined),
    _WorkspaceTab('Quiz', Icons.quiz_outlined),
    _WorkspaceTab('Revision', Icons.assignment_outlined),
    _WorkspaceTab('Ask AI', Icons.chat_bubble_outline),
  ];

  @override
  State<StudyWorkspace> createState() => _StudyWorkspaceState();
}

class _WorkspaceTab {
  final String label;
  final IconData icon;
  const _WorkspaceTab(this.label, this.icon);
}

class _StudyWorkspaceState extends State<StudyWorkspace> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // "Share to Group" is only offered for the owning teacher's own
  // real-mic-recorded lectures (fake-teacher prevention) — resolved once on
  // load; fails closed (button stays hidden) if either fetch fails.
  bool _canShareToGroup = false;

  bool _notesLoading = true;
  bool _notesError = false;
  String? _notesErrorMessage;
  String _shortSummary = '';
  String _cleanNotes = '';
  List<dynamic> _keyPoints = [];
  List<dynamic> _importantTerms = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: StudyWorkspace._tabs.length, vsync: this);
    _loadShareEligibility();
    _loadNotes();
  }

  @override
  void didUpdateWidget(covariant StudyWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lectureId != widget.lectureId) {
      _canShareToGroup = false;
      _loadShareEligibility();
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    setState(() {
      _notesLoading = true;
      _notesError = false;
      _notesErrorMessage = null;
    });
    try {
      final data = await LectureService.instance.fetchLectureNotes(widget.lectureId);
      if (!mounted) return;
      setState(() {
        _shortSummary = (data['short_summary'] as String?)?.trim() ?? '';
        _cleanNotes = (data['clean_notes'] as String?)?.trim() ?? '';
        _keyPoints = (data['key_points'] as List?) ?? [];
        _importantTerms = (data['important_terms'] as List?) ?? [];
        _notesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notesLoading = false;
        _notesError = true;
        _notesErrorMessage = e.toString();
      });
    }
  }

  Future<void> _loadShareEligibility() async {
    try {
      final userId = SupabaseClient.instance.currentUser?.id;
      if (userId == null) return;
      final profile = await SupabaseClient.instance.getUserProfile(userId);
      final isTeacher = profile?['role'] == 'teacher';
      if (!isTeacher) return;

      final meta = await LectureService.instance.getLectureMeta(widget.lectureId);
      final isOwnLecture = meta?['user_id'] == userId;
      final isRecorded = meta?['source_type'] == 'recorded';
      if (!mounted) return;
      setState(() => _canShareToGroup = isOwnLecture && isRecorded);
    } catch (_) {
      // Fails closed — button simply stays hidden.
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.getCardBorder(context))),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.accentColor,
            unselectedLabelColor: AppTheme.getSecondaryText(context),
            indicatorColor: AppTheme.accentColor,
            indicatorSize: TabBarIndicatorSize.label,
            tabAlignment: TabAlignment.start,
            tabs: StudyWorkspace._tabs
                .map((t) => Tab(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon, size: 16),
                          const SizedBox(width: 6),
                          Text(t.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _notesTab(context),
              _summaryTab(context),
              _transcriptTab(context),
              _flashcardsTab(context),
              _quizTab(context),
              _revisionTab(context),
              _askAiTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.getCardBorder(context))),
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
            child: Icon(Icons.auto_stories_outlined, color: AppTheme.accentColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15),
                ),
                if (widget.subject != null && widget.subject!.isNotEmpty)
                  Text(
                    widget.subject!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (_canShareToGroup)
            IconButton(
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Share to Group',
              onPressed: () => showShareToGroupSheet(
                context,
                lectureId: widget.lectureId,
                lectureTitle: widget.title,
              ),
            ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }

  Widget _placeholderCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: child,
    );
  }

  Widget _scrollableTab(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _notesLoadingOrError() {
    if (_notesLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    if (_notesError) {
      return _scrollableTab([
        _placeholderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Could not load notes for this lecture.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_notesErrorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _notesErrorMessage!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadNotes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _emptyLine(String message) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.getSecondaryText(context),
            height: 1.5,
          ),
    );
  }

  Widget _notesTab(BuildContext context) {
    if (_notesLoading || _notesError) return _notesLoadingOrError();

    final children = <Widget>[
      _sectionLabel('CLEAN NOTES'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: _cleanNotes.isNotEmpty
            ? Text(
                _cleanNotes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              )
            : _emptyLine('No clean notes for this lecture yet.'),
      ),
    ];

    if (_keyPoints.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 20),
        _sectionLabel('KEY POINTS'),
        const SizedBox(height: 10),
        _placeholderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in _keyPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 6, color: AppTheme.accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.toString(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ]);
    }

    if (_importantTerms.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 20),
        _sectionLabel('IMPORTANT TERMS'),
        const SizedBox(height: 10),
        _placeholderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final raw in _importantTerms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Builder(
                    builder: (context) {
                      if (raw is Map) {
                        final term = raw['term']?.toString() ?? '';
                        final def = raw['definition']?.toString() ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              term,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
                            ),
                            if (def.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(def, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
                            ],
                          ],
                        );
                      }
                      return Text(raw.toString(), style: Theme.of(context).textTheme.bodyMedium);
                    },
                  ),
                ),
            ],
          ),
        ),
      ]);
    }

    return _scrollableTab(children);
  }

  Widget _summaryTab(BuildContext context) {
    if (_notesLoading || _notesError) return _notesLoadingOrError();

    return _scrollableTab([
      _sectionLabel('SHORT SUMMARY'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: _shortSummary.isNotEmpty
            ? Text(
                _shortSummary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              )
            : _emptyLine('No summary for this lecture yet.'),
      ),
    ]);
  }

  Widget _transcriptTab(BuildContext context) {
    return _scrollableTab([
      _sectionLabel('CLEAN TRANSCRIPT'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: _emptyLine(
          'Transcript is not loaded in this panel yet — use Notes / Summary '
          'from this lecture’s AI output (after processing finishes).',
        ),
      ),
    ]);
  }

  Widget _flashcardsTab(BuildContext context) {
    return _scrollableTab([
      _sectionLabel('FLASHCARDS'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: _emptyLine(
          'Flashcards are not generated here yet. Open this lecture’s notes '
          'result screen and use Generate More → Flashcards when that feature '
          'is wired to FastAPI.',
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _showComingSoon(context, 'Flashcard generation'),
        icon: const Icon(Icons.style_outlined, size: 18),
        label: const Text('Generate Flashcards'),
      ),
    ]);
  }

  Widget _quizTab(BuildContext context) {
    return _scrollableTab([
      _sectionLabel('QUIZ'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: _emptyLine(
          'Quiz / MCQ is not generated here yet. Use Generate More → MCQ on the '
          'notes result screen when that feature is wired to FastAPI.',
        ),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: () => _showComingSoon(context, 'Quiz'),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('Start Quiz (20 MCQ)'),
      ),
    ]);
  }

  Widget _revisionTab(BuildContext context) {
    return _scrollableTab([
      _sectionLabel('REVISION SHEET'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: _emptyLine(
          'Revision notes are not generated here yet. Use Generate More → '
          'Revision on the notes result screen when that feature is wired to FastAPI. '
          'For a quick revision now, open Ask AI and ask for a revision summary.',
        ),
      ),
    ]);
  }

  Widget _askAiTab(BuildContext context) {
    return WorkspaceAskAiPane(lectureId: widget.lectureId);
  }

  Widget _sectionLabel(String text) {
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

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }
}

/// Opens [StudyWorkspace] as a swipe-up bottom sheet (mobile pattern).
/// On desktop, embed [StudyWorkspace] directly in a side panel instead —
/// see `AppShell`.
Future<void> showStudyWorkspaceSheet(
  BuildContext context, {
  required String lectureId,
  required String title,
  String? subject,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final height = MediaQuery.of(sheetContext).size.height;
      return DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            height: height * 0.88,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getCardBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: StudyWorkspace(
                    lectureId: lectureId,
                    title: title,
                    subject: subject,
                    onClose: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Desktop-only split panel wrapper — animates open/closed width so the
/// conversation area smoothly makes room for the workspace.
class StudyWorkspaceSidePanel extends StatelessWidget {
  final String? lectureId;
  final String? title;
  final String? subject;
  final VoidCallback onClose;

  const StudyWorkspaceSidePanel({
    super.key,
    required this.lectureId,
    required this.title,
    this.subject,
    required this.onClose,
  });

  static const double panelWidth = 420;

  @override
  Widget build(BuildContext context) {
    final isOpen = lectureId != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: isOpen ? panelWidth : 0,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.getCardBorder(context))),
      ),
      child: isOpen
          ? ClipRect(
              child: OverflowBox(
                minWidth: panelWidth,
                maxWidth: panelWidth,
                alignment: Alignment.centerLeft,
                child: StudyWorkspace(
                  lectureId: lectureId!,
                  title: title ?? 'Lecture',
                  subject: subject,
                  onClose: onClose,
                ),
              ),
            )
          : null,
    );
  }
}
