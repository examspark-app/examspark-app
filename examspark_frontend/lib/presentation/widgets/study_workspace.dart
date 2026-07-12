import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/share_to_group_sheet.dart';

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
/// PLACEHOLDER DATA ONLY (Phase 2, UI architecture pass). Real content
/// wiring (RAG, generated extras, transcript fetch) is Phase 4/5 work —
/// see TECH_STACK.md RAG pipeline order. This does not touch or replace
/// `NotesResultScreen`'s live Supabase wiring; that screen keeps working
/// exactly as before via the existing `/notes_result` route.
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: StudyWorkspace._tabs.length, vsync: this);
    _loadShareEligibility();
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

  Widget _notesTab(BuildContext context) {
    const points = [
      'Newton\'s first law: an object stays at rest or in uniform motion unless acted on by a net force.',
      'Force = mass × acceleration (F = ma) — the second law.',
      'Every action has an equal and opposite reaction — the third law.',
    ];
    return _scrollableTab([
      _sectionLabel('CLEAN NOTES'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppTheme.accentColor),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5))),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _placeholderNote(context, 'Real notes are generated automatically once this lecture finishes processing.'),
    ]);
  }

  Widget _summaryTab(BuildContext context) {
    return _scrollableTab([
      _sectionLabel('SHORT SUMMARY'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: Text(
          'This lecture covers the fundamentals of classical mechanics — Newton\'s three laws of '
          'motion, with worked examples on force, mass and acceleration.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ),
      const SizedBox(height: 16),
      _placeholderNote(context, 'Sample summary shown for preview — actual content connects in Phase 4/5.'),
    ]);
  }

  Widget _transcriptTab(BuildContext context) {
    return _scrollableTab([
      _sectionLabel('CLEAN TRANSCRIPT'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: Text(
          '"...so today we\'re going to talk about Newton\'s laws of motion. The first law tells us '
          'that an object at rest stays at rest, unless a force acts on it..."',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, fontStyle: FontStyle.italic),
        ),
      ),
      const SizedBox(height: 16),
      _placeholderNote(context, 'Raw audio is deleted after processing — only this clean transcript is kept.'),
    ]);
  }

  Widget _flashcardsTab(BuildContext context) {
    final sample = [
      ('What is Newton\'s First Law?', 'An object remains at rest or in uniform motion unless acted upon by a net force.'),
      ('What is the formula for force?', 'F = m × a'),
    ];
    return _scrollableTab([
      _sectionLabel('FLASHCARDS PREVIEW'),
      const SizedBox(height: 10),
      for (final (q, a) in sample)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _placeholderCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
                const Divider(height: 20),
                Text(a, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: () => _showComingSoon(context, 'Flashcard generation'),
        icon: const Icon(Icons.style_outlined, size: 18),
        label: const Text('Generate Flashcards'),
      ),
    ]);
  }

  Widget _quizTab(BuildContext context) {
    return _scrollableTab([
      _sectionLabel('QUIZ PREVIEW'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q1. What does Newton\'s 2nd Law state?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            for (final opt in ['F = ma', 'E = mc²', 'V = IR', 'P = mv'])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_unchecked, size: 16, color: AppTheme.getSecondaryText(context)),
                    const SizedBox(width: 8),
                    Text(opt, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
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
    const points = [
      'Revise all three laws of motion before the test.',
      'Practice at least 5 numerical problems on F = ma.',
      'Remember: forces always act in pairs (3rd law).',
    ];
    return _scrollableTab([
      _sectionLabel('REVISION SHEET'),
      const SizedBox(height: 10),
      _placeholderCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _askAiTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _placeholderNote(
                context,
                'Ask AI answers using this lecture\'s Notes → Transcript → Teacher Shared content, '
                'in that order (RAG priority). Connects in Phase 4/5.',
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.getCardBorder(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Ask about this lecture… (5 credits)',
                    filled: true,
                    fillColor: AppTheme.getCardBackground(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppTheme.getCardBorder(context)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _showComingSoon(context, 'Ask AI'),
                style: IconButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
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

  Widget _placeholderNote(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 14, color: AppTheme.getSecondaryText(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
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
