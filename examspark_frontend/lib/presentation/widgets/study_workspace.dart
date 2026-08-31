import 'dart:async';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/constants/share_chip_catalog.dart';
import 'package:examspark_frontend/core/constants/study_tool_copy.dart';
import 'package:examspark_frontend/core/constants/student_copy.dart';
import 'package:examspark_frontend/core/errors/lecture_user_message.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/session_live_sync.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/select_ai/selectable_study_text.dart';
import 'package:examspark_frontend/presentation/widgets/home/home_study_chip_bar.dart';
import 'package:examspark_frontend/presentation/widgets/lecture_study_tool_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_empty_state.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_lecture_cache.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_reading_utils.dart';
import 'package:examspark_frontend/presentation/widgets/workspace_ask_ai_pane.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

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
/// Phase 4B perf: load lecture content once into [WorkspaceLectureCache],
/// then tab switches are instant (no duplicate GET / spinner).
class StudyWorkspace extends StatefulWidget {
  final String lectureId;
  final String title;
  final String? subject;
  final VoidCallback? onClose;
  /// Opens directly on Notes / Quiz / Ask AI, etc. (0–6) in the **visible** tab list.
  final int? initialTabIndex;
  /// Shared group content: hide Share / Generate / Delete for non-owners.
  final bool readOnly;
  /// When set (group share chips), only these tabs/extras are shown.
  /// Null = owner / legacy full workspace (Ask AI hidden if [readOnly]).
  final List<String>? allowedChips;

  const StudyWorkspace({
    super.key,
    required this.lectureId,
    required this.title,
    this.subject,
    this.onClose,
    this.initialTabIndex,
    this.readOnly = false,
    this.allowedChips,
  });

  static const List<_WorkspaceTab> _allTabs = [
    _WorkspaceTab(ShareChipCatalog.notes, 'Notes', Icons.description_outlined),
    _WorkspaceTab(ShareChipCatalog.summary, 'Summary', Icons.summarize_outlined),
    _WorkspaceTab(
        ShareChipCatalog.transcript, 'Transcript', Icons.article_outlined),
    _WorkspaceTab(
        ShareChipCatalog.flashcards, 'Flashcards', Icons.style_outlined),
    _WorkspaceTab(ShareChipCatalog.quiz, 'Quiz', Icons.quiz_outlined),
    _WorkspaceTab(
        ShareChipCatalog.revision, 'Revision', Icons.assignment_outlined),
    _WorkspaceTab('ask_ai', 'Ask AI', Icons.chat_bubble_outline),
  ];

  static const List<_WorkspaceTab> _extraShareTabs = [
    _WorkspaceTab(
      ShareChipCatalog.importantQuestions,
      'Important Qs',
      Icons.help_outline,
    ),
    _WorkspaceTab(ShareChipCatalog.mindMap, 'Mind Map', Icons.account_tree_outlined),
    _WorkspaceTab(
      ShareChipCatalog.fiveMinRevision,
      '5 Min',
      Icons.timer_outlined,
    ),
    _WorkspaceTab(ShareChipCatalog.visual, 'Visual', Icons.image_outlined),
    _WorkspaceTab(ShareChipCatalog.learnMore, 'Learn More', Icons.menu_book_outlined),
    _WorkspaceTab(ShareChipCatalog.memoryTricks, 'Memory', Icons.psychology_outlined),
    _WorkspaceTab(
      ShareChipCatalog.commonMistakes,
      'Mistakes',
      Icons.report_gmailerrorred_outlined,
    ),
    _WorkspaceTab(ShareChipCatalog.cheatSheet, 'Cheat Sheet', Icons.fact_check_outlined),
    _WorkspaceTab(ShareChipCatalog.teacherTips, 'Tips', Icons.school_outlined),
    _WorkspaceTab(ShareChipCatalog.examBooster, 'Exam', Icons.military_tech_outlined),
  ];

  @override
  State<StudyWorkspace> createState() => _StudyWorkspaceState();
}

class _WorkspaceTab {
  final String key;
  final String label;
  final IconData icon;
  const _WorkspaceTab(this.key, this.label, this.icon);
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _StudyWorkspaceState extends State<StudyWorkspace> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<_WorkspaceTab> _visibleTabs;
  late WorkspaceLectureSnapshot _snap;

  String? _metaSubject;
  DateTime? _createdAt;
  String? _lectureStatus;

  /// Spinner only on first fetch for that slice — never on tab revisit.
  bool _notesLoading = false;
  bool _notesError = false;
  String? _notesErrorMessage;
  int _notesLoadGen = 0;
  bool _notesLoadInFlight = false;
  String _shortSummary = '';
  String _cleanNotes = '';
  List<dynamic> _keyPoints = [];
  List<dynamic> _importantTerms = [];
  VisualPayloadData? _visualPayload;

  bool _transcriptLoading = false;
  bool _transcriptFetched = false;
  String _transcript = '';
  int _transcriptWordCount = 0;
  final TextEditingController _transcriptSearchController =
      TextEditingController();
  String _transcriptQuery = '';

  bool _flashcardsLoading = false;
  bool _flashcardsFetched = false;
  bool _flashcardsGenerating = false;
  String? _flashcardsError;
  List<Flashcard> _flashcards = [];

  bool _quizLoading = false;
  bool _quizFetched = false;
  bool _quizGenerating = false;
  String? _quizError;
  List<MCQQuestion> _quizQuestions = [];

  bool _revisionLoading = false;
  bool _revisionFetched = false;
  bool _revisionGenerating = false;
  String? _revisionError;
  String _revisionSheet = '';
  VisualPayloadData? _revisionVisualPayload;

  bool _refreshing = false;
  bool _deletingLecture = false;

  /// Home-style chips on recording (owner only) — generate from notes.
  final Map<String, HomeChipUiState> _chipStates = {};
  String? _activeChipType;

  @override
  void initState() {
    super.initState();
    _visibleTabs = _resolveVisibleTabs();
    _tabController = TabController(length: _visibleTabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      unawaited(_onTabChanged());
    });
    _hydrateFromCache(widget.lectureId);
    _bootstrapFromDiskThenOpen();
    _applyInitialTabIfNeeded();
  }

  List<_WorkspaceTab> _resolveVisibleTabs() {
    final allowed = widget.allowedChips;
    if (allowed == null) {
      // Owner / legacy: full workspace; Ask AI only when not read-only.
      if (widget.readOnly) {
        return StudyWorkspace._allTabs
            .where((t) => t.key != 'ask_ai')
            .toList();
      }
      return List<_WorkspaceTab>.from(StudyWorkspace._allTabs);
    }
    final set = allowed
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != 'ask_ai')
        .toSet();
    final out = <_WorkspaceTab>[];
    for (final t in StudyWorkspace._allTabs) {
      if (t.key == 'ask_ai') continue; // never share Ask AI to group students
      if (set.contains(t.key)) out.add(t);
    }
    for (final t in StudyWorkspace._extraShareTabs) {
      if (set.contains(t.key)) out.add(t);
    }
    if (out.isEmpty) {
      out.add(StudyWorkspace._allTabs.first); // Notes fallback
    }
    return out;
  }

  void _applyInitialTabIfNeeded() {
    final start = widget.initialTabIndex;
    if (start == null || start < 0 || start >= _tabController.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tabController.index == start) {
        unawaited(_onTabChanged());
        return;
      }
      _tabController.index = start;
      unawaited(_onTabChanged());
    });
  }

  Future<void> _bootstrapFromDiskThenOpen() async {
    // Phase 4E P0: disk → paint → then network (or silent sync).
    if (!_snap.hasUsableNotes) {
      final disk = await WorkspaceLectureCache.instance.loadFromDisk(widget.lectureId);
      if (disk != null && mounted) {
        _hydrateFromCache(widget.lectureId);
        setState(() {});
      }
    }
    if (!mounted) return;
    _openLectureSession(force: false);
  }

  @override
  void didUpdateWidget(covariant StudyWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lectureId != widget.lectureId) {
      _transcriptQuery = '';
      _transcriptSearchController.clear();
      _hydrateFromCache(widget.lectureId);
      // Paint cached notes immediately — don't wait for network.
      if (mounted) setState(() {});
      _openLectureSession(force: false);
    }
  }

  void _hydrateFromCache(String lectureId) {
    _snap = WorkspaceLectureCache.instance.getOrCreate(lectureId);
    _metaSubject = _snap.metaSubject;
    _createdAt = _snap.createdAt;
    _lectureStatus = _snap.lectureStatus;

    _notesError = _snap.notesError && !_snap.hasUsableNotes;
    _shortSummary = _snap.shortSummary;
    _cleanNotes = _snap.cleanNotes;
    _keyPoints = List<dynamic>.from(_snap.keyPoints);
    _importantTerms = List<dynamic>.from(_snap.importantTerms);
    _visualPayload = _snap.visualPayload;
    _notesLoading = !_snap.notesFetched;

    _transcript = _snap.transcript;
    _transcriptWordCount = _snap.transcriptWordCount;
    _transcriptFetched = _snap.transcriptFetched;
    _transcriptLoading = !_snap.transcriptFetched;

    _flashcards = List<Flashcard>.from(_snap.flashcards);
    _flashcardsError = _snap.flashcardsError;
    _flashcardsFetched = _snap.flashcardsFetched;
    _flashcardsLoading = !_snap.flashcardsFetched;

    _quizQuestions = List<MCQQuestion>.from(_snap.quizQuestions);
    _quizError = _snap.quizError;
    _quizFetched = _snap.quizFetched;
    _quizLoading = !_snap.quizFetched;

    _revisionSheet = _snap.revisionSheet;
    _revisionVisualPayload = _snap.revisionVisualPayload;
    _revisionError = _snap.revisionError;
    _revisionFetched = _snap.revisionFetched;
    _revisionLoading = !_snap.revisionFetched;
  }

  void _persistCache() {
    WorkspaceLectureCache.instance.put(widget.lectureId, _snap);
  }

  /// First open: Notes + meta only. Extras load when user opens that tab (P1).
  Future<void> _openLectureSession({required bool force}) async {
    // Library time stamp — bump when student opens / works in this lecture.
    unawaited(LectureService.instance.markLectureOpened(widget.lectureId));

    if (force) {
      WorkspaceLectureCache.instance.invalidate(widget.lectureId);
      _hydrateFromCache(widget.lectureId);
      if (mounted) setState(() {});
    }

    await Future.wait([
      _loadShareEligibility(force: force),
      _loadNotes(force: force),
    ]);
    // Warm RAG before Ask AI so first question is faster (idempotent, free).
    if (!widget.readOnly) {
      unawaited(LectureService.instance.warmLectureRagIndex(widget.lectureId));
      unawaited(_loadChipStates());
    }
  }

  Future<void> _loadChipStates() async {
    try {
      final data =
          await LectureService.instance.lectureListStudyTools(widget.lectureId);
      final tools = data['tools'];
      if (tools is! Map) return;
      if (!mounted) return;
      setState(() {
        _chipStates.clear();
        for (final e in tools.entries) {
          final key = e.key.toString();
          final v = e.value;
          if (v is Map && v['has_payload'] == true) {
            _chipStates[key] = HomeChipUiState.generated;
          } else {
            _chipStates[key] = HomeChipUiState.ready;
          }
        }
      });
    } catch (_) {
      // Soft-fail — chips still open and generate on tap.
    }
  }

  Future<void> _onRecordingChip(HomeStudyChipDef chip) async {
    if (widget.readOnly) return;
    setState(() {
      _chipStates[chip.toolType] = HomeChipUiState.loading;
      _activeChipType = chip.toolType;
    });
    await showLectureStudyToolSheet(
      context,
      lectureId: widget.lectureId,
      toolType: chip.toolType,
      title: chip.label,
      onCreditsUpdated: (_) {
        unawaited(SessionLiveSync.instance.refreshAll());
      },
      onGenerated: () {
        if (!mounted) return;
        setState(() {
          _chipStates[chip.toolType] = HomeChipUiState.generated;
        });
        // Refresh tab caches for tools that also live as tabs.
        if (chip.toolType == 'flashcards') {
          unawaited(_loadFlashcards(force: true));
        } else if (chip.toolType == 'quiz') {
          unawaited(_loadQuiz(force: true));
        } else if (chip.toolType == 'revision') {
          unawaited(_loadRevision(force: true));
        }
      },
    );
    if (!mounted) return;
    setState(() {
      if (_chipStates[chip.toolType] == HomeChipUiState.loading) {
        _chipStates[chip.toolType] = HomeChipUiState.ready;
      }
      _activeChipType = null;
    });
    unawaited(_loadChipStates());
  }
void _handleTabTap(int index) {
  if (index < 0 || index >= _visibleTabs.length) return;

  if (_tabController.index != index) {
    _tabController.index = index;
  }

  unawaited(_onTabChanged());
}

  
  Future<void> _onTabChanged() async {
    if (!mounted) return;
    final i = _tabController.index;
    if (i < 0 || i >= _visibleTabs.length) return;
    final key = _visibleTabs[i].key;
    if (key == ShareChipCatalog.transcript) await _loadTranscript(force: false);
    if (key == ShareChipCatalog.flashcards) await _loadFlashcards(force: false);
    if (key == ShareChipCatalog.quiz) await _loadQuiz(force: false);
    if (key == ShareChipCatalog.revision) await _loadRevision(force: false);
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _openLectureSession(force: true);
      // Refresh whatever tab is open.
      await _onTabChanged();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _confirmDeleteLecture() async {
    if (_deletingLecture) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Delete lecture?'),
        content: const Text(
          'Delete this lecture permanently? Notes, transcript, quiz and '
          'flashcards will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingLecture = true);
    try {
      await LectureService.instance.deleteLecture(widget.lectureId);
      await WorkspaceLectureCache.instance.removeLecture(widget.lectureId);
      if (!mounted) return;
      AppToast.showSnackBar(context, 
        const SnackBar(content: Text('Lecture deleted.')),
      );
      if (widget.onClose != null) {
        widget.onClose!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = lectureUserMessage(e);
      AppToast.showSnackBar(context, 
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _deletingLecture = false);
    }
  }

  bool get _extrasStillLoading =>
      (_transcriptLoading && !_transcriptFetched) ||
      (_flashcardsLoading && !_flashcardsFetched) ||
      (_quizLoading && !_quizFetched) ||
      (_revisionLoading && !_revisionFetched);

  Future<void> _loadFlashcards({bool force = false}) async {
    if (!force && _flashcardsFetched) return;
    if (force) {
      _flashcardsFetched = false;
      _snap.flashcardsFetched = false;
    }
    // Never blank the tab with a spinner if cards are already on screen.
    if (mounted) {
      setState(() {
        if (_flashcards.isEmpty) _flashcardsLoading = true;
        _flashcardsError = null;
      });
    }
    try {
      final data = await LectureService.instance.fetchFlashcards(widget.lectureId);
      if (!mounted) return;
      final cards = (data['cards'] as List?) ?? [];
      setState(() {
        _flashcards = cards
            .whereType<Map>()
            .map((c) => Flashcard.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        _flashcardsFetched = true;
        _flashcardsLoading = false;
        _flashcardsError = null;
      });
      _snap.applyFlashcards(cards: _flashcards, error: null);
      _persistCache();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _flashcardsFetched = true;
        _flashcardsLoading = false;
        _flashcardsError = e.toString();
      });
      _snap.applyFlashcards(cards: _flashcards, error: e.toString());
      _persistCache();
    }
  }

  Future<void> _generateFlashcards({bool regenerate = false}) async {
    await _generateViaStudyTool(
      toolType: 'flashcards',
      regenerate: regenerate || _flashcards.isNotEmpty,
      setGenerating: (v) => _flashcardsGenerating = v,
      setError: (e) => _flashcardsError = e,
      onPayload: (payload) {
        final cards = (payload['cards'] as List?) ?? [];
        _flashcards = cards
            .whereType<Map>()
            .map((c) => Flashcard.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        _flashcardsFetched = true;
        _flashcardsLoading = false;
        _snap.applyFlashcards(cards: _flashcards, error: null);
        _persistCache();
      },
    );
  }

  Future<void> _generateViaStudyTool({
    required String toolType,
    required bool regenerate,
    required void Function(bool) setGenerating,
    required void Function(String?) setError,
    required void Function(Map<String, dynamic> payload) onPayload,
  }) async {
    setState(() {
      setGenerating(true);
      setError(null);
    });
    try {
      final data = await LectureService.instance.lectureGenerateStudyTool(
        lectureId: widget.lectureId,
        toolType: toolType,
        regenerate: regenerate,
      );
      if (!mounted) return;
      final payload = data['payload'];
      final map = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      setState(() {
        onPayload(map);
        setGenerating(false);
      });
      unawaited(SessionLiveSync.instance.refreshAll());
      final charged = data['credits_charged'];
      final cached = data['cached'] == true;
      if (mounted) {
        AppToast.showSnackBar(
          context,
          SnackBar(
            content: Text(
              cached
                  ? StudentCopy.toolReady
                  : '$toolType ready — ${charged ?? '?'} credits used',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        setGenerating(false);
        setError(e.toString());
      });
    }
  }

  Future<void> _loadQuiz({bool force = false}) async {
    if (!force && _quizFetched) return;
    if (force) {
      _quizFetched = false;
      _snap.quizFetched = false;
    }
    if (mounted) {
      setState(() {
        if (_quizQuestions.isEmpty) _quizLoading = true;
        _quizError = null;
      });
    }
    try {
      final data = await LectureService.instance.fetchQuiz(widget.lectureId);
      if (!mounted) return;
      final questions = (data['questions'] as List?) ?? [];
      setState(() {
        _quizQuestions = questions
            .whereType<Map>()
            .map((q) => MCQQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList();
        _quizFetched = true;
        _quizLoading = false;
        _quizError = null;
      });
      _snap.applyQuiz(questions: _quizQuestions, error: null);
      _persistCache();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quizFetched = true;
        _quizLoading = false;
        _quizError = e.toString();
      });
      _snap.applyQuiz(questions: _quizQuestions, error: e.toString());
      _persistCache();
    }
  }

  Future<void> _generateQuiz({bool regenerate = false}) async {
    await _generateViaStudyTool(
      toolType: 'quiz',
      regenerate: regenerate || _quizQuestions.isNotEmpty,
      setGenerating: (v) => _quizGenerating = v,
      setError: (e) => _quizError = e,
      onPayload: (payload) {
        final questions = (payload['questions'] as List?) ?? [];
        _quizQuestions = questions
            .whereType<Map>()
            .map((q) => MCQQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList();
        _quizFetched = true;
        _quizLoading = false;
        _snap.applyQuiz(questions: _quizQuestions, error: null);
        _persistCache();
      },
    );
  }

  Future<void> _loadRevision({bool force = false}) async {
    if (!force && _revisionFetched) return;
    if (force) {
      _revisionFetched = false;
      _snap.revisionFetched = false;
    }
    if (mounted) {
      setState(() {
        if (_revisionSheet.isEmpty) _revisionLoading = true;
        _revisionError = null;
      });
    }
    try {
      final data = await LectureService.instance.fetchRevision(widget.lectureId);
      if (!mounted) return;
      setState(() {
        _revisionSheet = (data['revisionSheet'] as String?)?.trim() ?? '';
        final vp = data['visualPayload'] ?? data['visual_payload'];
        _revisionVisualPayload = vp is Map
            ? VisualPayloadData.fromJson(Map<String, dynamic>.from(vp))
            : null;
        _revisionFetched = true;
        _revisionLoading = false;
        _revisionError = null;
      });
      _snap.applyRevision(
        sheet: _revisionSheet,
        visualPayload: _revisionVisualPayload,
        error: null,
      );
      _persistCache();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _revisionFetched = true;
        _revisionLoading = false;
        _revisionError = e.toString();
      });
      _snap.applyRevision(
        sheet: _revisionSheet,
        visualPayload: _revisionVisualPayload,
        error: e.toString(),
      );
      _persistCache();
    }
  }

  Future<void> _generateRevision({bool regenerate = false}) async {
    await _generateViaStudyTool(
      toolType: 'revision',
      regenerate: regenerate || _revisionSheet.trim().isNotEmpty,
      setGenerating: (v) => _revisionGenerating = v,
      setError: (e) => _revisionError = e,
      onPayload: (payload) {
        _revisionSheet =
            (payload['revisionSheet'] as String?)?.trim() ??
                (payload['revision_sheet'] as String?)?.trim() ??
                '';
        final vp = payload['visualPayload'] ?? payload['visual_payload'];
        _revisionVisualPayload = vp is Map
            ? VisualPayloadData.fromJson(Map<String, dynamic>.from(vp))
            : null;
        _revisionFetched = true;
        _revisionLoading = false;
        _snap.applyRevision(
          sheet: _revisionSheet,
          visualPayload: _revisionVisualPayload,
          error: null,
        );
        _persistCache();
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transcriptSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTranscript({bool force = false}) async {
    if (!force && _transcriptFetched) return;
    if (force) {
      _transcriptFetched = false;
      _snap.transcriptFetched = false;
    }
    if (mounted) {
      setState(() {
        if (_transcript.isEmpty) _transcriptLoading = true;
      });
    }
    try {
      final data = await LectureService.instance.fetchTranscript(widget.lectureId);
      if (!mounted) return;
      setState(() {
        _transcript = (data['transcript'] as String?)?.trim() ?? '';
        _transcriptWordCount = (data['word_count'] as num?)?.toInt() ??
            countWords(_transcript);
        _transcriptFetched = true;
        _transcriptLoading = false;
      });
      _snap.applyTranscript(
        transcript: _transcript,
        wordCount: _transcriptWordCount,
      );
      _persistCache();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transcriptLoading = false;
        _transcriptFetched = true;
        _transcript = '';
      });
      _snap.applyTranscript(transcript: '', wordCount: 0);
      _persistCache();
    }
  }

  Future<void> _loadNotes({bool force = false}) async {
    // Never hide real notes behind a later failed request (all lectures).
    final canUseMemory = !force &&
        _snap.notesFetched &&
        !_snap.notesError &&
        (_snap.cleanNotes.isNotEmpty ||
            _snap.shortSummary.isNotEmpty ||
            _snap.keyPoints.isNotEmpty);
    if (canUseMemory) {
      if (mounted) {
        setState(() {
          _notesLoading = false;
          _notesError = false;
          _notesErrorMessage = null;
          _shortSummary = _snap.shortSummary;
          _cleanNotes = _snap.cleanNotes;
          _keyPoints = List<dynamic>.from(_snap.keyPoints);
          _importantTerms = List<dynamic>.from(_snap.importantTerms);
          _visualPayload = _snap.visualPayload;
        });
      }
      unawaited(_syncNotesInBackground());
      return;
    }

    if (_notesLoadInFlight && !force) return;
    if (force) {
      _snap.notesFetched = false;
      _snap.notesError = false;
    }

    final hasCachedNotes = _cleanNotes.isNotEmpty ||
        _shortSummary.isNotEmpty ||
        _keyPoints.isNotEmpty ||
        _importantTerms.isNotEmpty ||
        (_visualPayload != null && !_visualPayload!.isEmpty);
    final gen = ++_notesLoadGen;
    _notesLoadInFlight = true;

    if (mounted) {
      setState(() {
        if (!hasCachedNotes) _notesLoading = true;
        // Keep showing cached notes; clear error only when we have content path.
        if (hasCachedNotes) {
          _notesError = false;
          _notesErrorMessage = null;
        } else {
          _notesError = false;
          _notesErrorMessage = null;
        }
      });
    }
    try {
      final data = await LectureService.instance.fetchLectureNotes(widget.lectureId);
      if (!mounted || gen != _notesLoadGen) return;

      final summary = (data['short_summary'] as String?)?.trim() ?? '';
      final clean = (data['clean_notes'] as String?)?.trim() ?? '';
      final keys = (data['key_points'] as List?) ?? [];
      final terms = (data['important_terms'] as List?) ?? [];
      VisualPayloadData? visual;
      final vp = data['visual_payload'];
      if (vp is Map) {
        try {
          visual = VisualPayloadData.fromJson(Map<String, dynamic>.from(vp));
        } catch (_) {
          visual = null;
        }
      }

      setState(() {
        _shortSummary = summary;
        _cleanNotes = clean;
        _keyPoints = keys;
        _importantTerms = terms;
        _visualPayload = visual;
        _notesLoading = false;
        _notesError = false;
        _notesErrorMessage = null;
      });
      _snap.applyNotes(
        shortSummary: summary,
        cleanNotes: clean,
        keyPoints: keys,
        importantTerms: terms,
        visualPayload: visual,
        error: false,
      );
      _persistCache();
      await WorkspaceLectureCache.instance.saveToDisk(widget.lectureId, _snap);
    } catch (e) {
      if (!mounted || gen != _notesLoadGen) return;
      final msg = lectureUserMessage(e);
      final stillHaveNotes = _cleanNotes.isNotEmpty ||
          _shortSummary.isNotEmpty ||
          _keyPoints.isNotEmpty ||
          _importantTerms.isNotEmpty;
      setState(() {
        _notesLoading = false;
        // CRITICAL: never set error if notes already on screen.
        if (stillHaveNotes || hasCachedNotes) {
          _notesError = false;
          _notesErrorMessage = null;
        } else {
          _notesError = true;
          _notesErrorMessage = msg;
        }
      });
      if (!stillHaveNotes && !hasCachedNotes) {
        _snap.applyNotes(
          shortSummary: _shortSummary,
          cleanNotes: _cleanNotes,
          keyPoints: _keyPoints,
          importantTerms: _importantTerms,
          visualPayload: _visualPayload,
          error: true,
        );
        _persistCache();
      }
      if ((stillHaveNotes || hasCachedNotes) && mounted) {
        AppToast.showSnackBar(context, SnackBar(content: Text(msg)));
      }
    } finally {
      if (gen == _notesLoadGen) _notesLoadInFlight = false;
    }
  }

  Future<void> _syncNotesInBackground() async {
    try {
      final data = await LectureService.instance.fetchLectureNotes(widget.lectureId);
      if (!mounted) return;
      final clean = (data['clean_notes'] as String?)?.trim() ?? '';
      final summary = (data['short_summary'] as String?)?.trim() ?? '';
      if (clean.isEmpty && summary.isEmpty) return;
      setState(() {
        _shortSummary = summary;
        _cleanNotes = clean;
        _keyPoints = (data['key_points'] as List?) ?? [];
        _importantTerms = (data['important_terms'] as List?) ?? [];
        final vp = data['visual_payload'];
        _visualPayload = vp is Map
            ? VisualPayloadData.fromJson(Map<String, dynamic>.from(vp))
            : null;
        _notesError = false;
      });
      _snap.applyNotes(
        shortSummary: _shortSummary,
        cleanNotes: _cleanNotes,
        keyPoints: _keyPoints,
        importantTerms: _importantTerms,
        visualPayload: _visualPayload,
        error: false,
      );
      _persistCache();
      await WorkspaceLectureCache.instance.saveToDisk(widget.lectureId, _snap);
    } catch (_) {
      // Silent — UI already has memory cache.
    }
  }

  Future<void> _loadShareEligibility({bool force = false}) async {
    if (!force && _snap.metaFetched) {
      if (mounted) {
        setState(() {
          _metaSubject = _snap.metaSubject;
          _createdAt = _snap.createdAt;
          _lectureStatus = _snap.lectureStatus;
        });
      }
      return;
    }
    try {
      final meta = await LectureService.instance.getLectureMeta(widget.lectureId);
      if (!mounted) return;
      final subject = meta?['subject']?.toString();
      final created = parseCreatedAt(meta?['created_at']);
      final status = meta?['status']?.toString();
      if (!mounted) return;
      setState(() {
        _metaSubject = subject;
        _createdAt = created;
        _lectureStatus = status;
      });
      _snap.applyMeta(
        subject: subject,
        createdAt: created,
        status: status,
        canShare: false, // Personal Workspace never shares — Dashboard My Library only
      );
      _persistCache();
    } catch (_) {
      // Meta soft-fail — share stays hidden.
    }
  }

  String get _displaySubject {
    if (widget.subject != null && widget.subject!.isNotEmpty) {
      return widget.subject!;
    }
    return _metaSubject ?? '';
  }

  int get _headerReadingMinutes {
    if (_transcript.isNotEmpty) {
      return estimatedReadingMinutes(_transcript);
    }
    if (_cleanNotes.isNotEmpty) {
      return estimatedReadingMinutes(_cleanNotes);
    }
    if (_shortSummary.isNotEmpty) {
      return estimatedReadingMinutes(_shortSummary);
    }
    return 0;
  }

  @override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: _tabController,
    builder: (context, _) {
      final index = _tabController.index.clamp(
        0,
        _visibleTabs.length - 1,
      );
      final activeTab = _visibleTabs[index];

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),

            if (!widget.readOnly)
              _buildRecordingChipBar(context),

            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.getCardBorder(context),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      onTap: _handleTabTap,
                      isScrollable: true,
                      labelColor: AppTheme.accentColor,
                      unselectedLabelColor:
                          AppTheme.getSecondaryText(context),
                      indicatorColor: AppTheme.accentColor,
                      indicatorSize: TabBarIndicatorSize.label,
                      tabAlignment: TabAlignment.start,
                      tabs: _visibleTabs
                          .map(
                            (t) => Tab(
                              height: 44,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.icon, size: 16),
                                  const SizedBox(width: 6),
                                  Text(t.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  if (!widget.readOnly)
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: Icon(
                        Icons.more_vert,
                        color: AppTheme.getSecondaryText(context),
                      ),
                      enabled: !_deletingLecture,
                      onSelected: (value) {
                        if (value == 'delete') {
                          unawaited(_confirmDeleteLecture());
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(
                            'Delete lecture',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            _tabBodyForKey(context, activeTab.key),
          ],
        ),
      );
    },
  );
}

  Widget _buildRecordingChipBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.getCardBorder(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeStudyChipBar(
            toolStates: _chipStates,
            activeToolType: _activeChipType,
            recommended: const [],
            hideWhenNoRecommendation: false,
            moreHint: StudyToolCopy.recordingPaidFirstGenerate,
            extraMoreChips: const [
              HomeStudyChipDef(
                label: '5 Min',
                toolType: 'five_min_revision',
                icon: Icons.timer_outlined,
              ),
              HomeStudyChipDef(
  label: 'Visual',
  toolType: 'visual',
  icon: Icons.image_outlined,
),
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
            ],
            onTap: _onRecordingChip,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final subject = _displaySubject;
    final dateStr = formatCreatedDate(_createdAt);
    final readMins = _headerReadingMinutes;
    final metaParts = <String>[
      if (subject.isNotEmpty) subject,
      if (dateStr.isNotEmpty) dateStr,
      if (readMins > 0) 'Reading • ${formatReadingTime(readMins)}',
    ];

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
                if (metaParts.isNotEmpty)
                  Text(
                    metaParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_extrasStillLoading && !_refreshing)
                  Text(
                    'Preparing study tools…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentColor,
                          fontSize: 11,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh lecture content',
            onPressed: _refreshing ? null : _refreshAll,
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
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

  Widget _selectableScrollableTab(
  List<Widget> children, {
  required String sourceSurface,
}) {
  return SelectableStudyText(
    lectureId: widget.lectureId,
    sourceSurface: sourceSurface,
    enableAskAi: !widget.readOnly,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
}

  Widget _notesLoadingOrError() {
    final hasCachedNotes = _cleanNotes.isNotEmpty ||
        _shortSummary.isNotEmpty ||
        _keyPoints.isNotEmpty ||
        _importantTerms.isNotEmpty ||
        (_visualPayload != null && !_visualPayload!.isEmpty);

    if (_notesLoading && !_snap.notesFetched && !hasCachedNotes) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    if (_notesError) {
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load notes',
          reasons: [
            if (_notesErrorMessage != null && _notesErrorMessage!.isNotEmpty)
              _notesErrorMessage!,
            'Your study material may still be preparing',
            'Check your internet and tap Retry',
          ],
          primaryLabel: 'Retry',
          primaryElevated: false,
          onPrimary: () => _loadNotes(force: true),
        ),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _notesTab(BuildContext context) {
    final hasNotes = _cleanNotes.isNotEmpty ||
        (_visualPayload != null && !_visualPayload!.isEmpty);
    final hasAnyNotesContent =
        hasNotes || _keyPoints.isNotEmpty || _importantTerms.isNotEmpty;

    // Never hide loaded notes behind a stale error flag.
    if (_notesLoading && !hasAnyNotesContent) {
      return _notesLoadingOrError();
    }
    if (_notesError && !hasAnyNotesContent) {
      return _notesLoadingOrError();
    }

    if (!hasNotes && _keyPoints.isEmpty && _importantTerms.isEmpty) {
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.description_outlined,
          title: 'No notes yet',
          reasons: const [
            'Your study material is still being prepared',
            'Notes were not saved for this lecture yet',
            'Tap Retry after a moment',
          ],
          primaryLabel: 'Retry',
          primaryElevated: false,
          onPrimary: () => _loadNotes(force: true),
        ),
      ]);
    }

    final children = <Widget>[
      Row(
        children: [
          Expanded(child: _sectionLabel('CLEAN NOTES')),
        ],
      ),
      const SizedBox(height: 10),
      _placeholderCard(
        child: hasNotes
            ? SmartEducationalContent(
                markdownBody: _cleanNotes,
                visualPayload: _visualPayload,
              )
            : Text(
                'No clean notes for this lecture yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
              ),
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

    return _selectableScrollableTab(children, sourceSurface: 'notes');
  }

  Widget _summaryTab(BuildContext context) {
    if (_notesLoading && _shortSummary.isEmpty && !_notesError) {
      return _notesLoadingOrError();
    }
    if (_notesError && _shortSummary.isEmpty && _cleanNotes.isEmpty) {
      return _notesLoadingOrError();
    }

    if (_shortSummary.isEmpty) {
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.summarize_outlined,
          title: 'No summary yet',
          reasons: const [
            'Your study material is still being prepared',
            'Summary was not saved for this lecture yet',
          ],
          primaryLabel: 'Retry',
          primaryElevated: false,
          onPrimary: () => _loadNotes(force: true),
        ),
      ]);
    }

    return _selectableScrollableTab([
      Row(
        children: [
          Expanded(child: _sectionLabel('SHORT SUMMARY')),
        ],
      ),
      const SizedBox(height: 10),
      _placeholderCard(
        child: Text(
          _shortSummary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ),
    ], sourceSurface: 'summary');
  }

  Widget _transcriptTab(BuildContext context) {
    // Spinner only on first fetch — never on tab revisit after cache hit.
    if (_transcriptLoading && !_transcriptFetched && _transcript.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transcript.isEmpty) {
      final status = _lectureStatus ?? '';
      final isError = status == 'error';
      final isProcessing = status.isNotEmpty &&
          status != 'done' &&
          status != 'error';

      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.article_outlined,
          title: 'Transcript is not available',
          reasons: [
            if (isProcessing) 'Your study material is still being prepared',
            if (isError) 'We couldn’t prepare the transcript. Please try again.',
            if (!isProcessing && !isError)
              'This lecture was imported without a transcript',
            'Or preparation finished but no transcript was saved',
          ],
          primaryLabel: 'Retry',
          primaryElevated: false,
          onPrimary: () => _loadTranscript(force: true),
        ),
      ]);
    }

    final query = _transcriptQuery.trim().toLowerCase();
    final displayText = query.isEmpty
        ? _transcript
        : _transcript
            .split('\n')
            .where((line) => line.toLowerCase().contains(query))
            .join('\n');
    final words = _transcriptWordCount > 0
        ? _transcriptWordCount
        : countWords(_transcript);
    final mins = estimatedReadingMinutes(_transcript);

    return _selectableScrollableTab([
      Row(
        children: [
          Expanded(child: _sectionLabel('CLEAN TRANSCRIPT')),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '$words Words · Reading Time • ${formatReadingTime(mins)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _transcriptSearchController,
        decoration: InputDecoration(
          hintText: 'Search within transcript',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (v) => setState(() => _transcriptQuery = v),
      ),
      const SizedBox(height: 12),
      _placeholderCard(
        child: Text(
          displayText.isEmpty
              ? 'No lines match your search.'
              : displayText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ),
    ], sourceSurface: 'transcript');
  }

  Widget _flashcardsTab(BuildContext context) {
    if (_flashcardsLoading && !_flashcardsFetched && _flashcards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_flashcardsError != null && _flashcards.isEmpty) {
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.style_outlined,
          title: 'Could not load flashcards',
          reasons: const [
            'Network issue — try again',
            'Flashcards may not be ready yet',
          ],
          primaryLabel: 'Retry',
          primaryElevated: false,
          onPrimary: () => _loadFlashcards(force: true),
        ),
      ]);
    }

    if (_flashcards.isEmpty) {
      if (widget.readOnly) {
        return _scrollableTab([
          WorkspaceEmptyState(
            icon: Icons.style_outlined,
            title: 'No Flashcards Shared',
            reasons: const [
              'Flashcards appear when your teacher generates and shares this lecture',
            ],
            primaryLabel: 'Retry',
            primaryElevated: false,
            onPrimary: () => _loadFlashcards(force: true),
          ),
        ]);
      }
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.style_outlined,
          title: 'No Flashcards Yet',
          reasons: [
            'Generate flashcards from this lecture’s notes',
            '${CreditCosts.flashcards} credits per generation',
          ],
          primaryLabel:
              'Generate Flashcards (${CreditCosts.flashcards} credits)',
          primaryLoading: _flashcardsGenerating,
          onPrimary: _generateFlashcards,
        ),
      ]);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _sectionLabel('FLASHCARDS')),
                  if (!widget.readOnly)
                    TextButton.icon(
                      onPressed: _flashcardsGenerating
                          ? null
                          : () => _generateFlashcards(regenerate: true),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        _flashcardsGenerating
                            ? '…'
                            : StudyToolCopy.regenerateButton,
                      ),
                    ),
                ],
              ),
              Text(
                StudyToolCopy.recordingPaidFirstGenerate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SelectableStudyText(
            lectureId: widget.lectureId,
            sourceSurface: 'flashcard',
            enableAskAi: !widget.readOnly,
            child: FlashcardStackView(
              flashcards: _flashcards,
              lectureId: widget.lectureId,
            ),
          ),
        ),
      ],
    );
  }

  Widget _quizTab(BuildContext context) {
    if (_quizLoading && !_quizFetched && _quizQuestions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quizError != null && _quizQuestions.isEmpty) {
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.quiz_outlined,
          title: 'Could not load quiz',
          reasons: const [
            'Network issue — try again',
            'Quiz may not be ready yet',
          ],
          primaryLabel: 'Retry',
          primaryElevated: false,
          onPrimary: () => _loadQuiz(force: true),
        ),
      ]);
    }

    if (_quizQuestions.isEmpty) {
      if (widget.readOnly) {
        return _scrollableTab([
          WorkspaceEmptyState(
            icon: Icons.quiz_outlined,
            title: 'No Quiz Shared Yet',
            reasons: const [
              'Your teacher has not shared a quiz for this lecture',
            ],
            primaryLabel: 'Retry',
            primaryElevated: false,
            onPrimary: () => _loadQuiz(force: true),
          ),
        ]);
      }
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.quiz_outlined,
          title: 'No Quiz Yet',
          reasons: [
            'Generate 20 MCQs from this lecture’s notes',
            '${CreditCosts.quiz20Mcq} credits per generation',
          ],
          primaryLabel: 'Generate Quiz (${CreditCosts.quiz20Mcq} credits)',
          primaryLoading: _quizGenerating,
          onPrimary: _generateQuiz,
        ),
      ]);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _sectionLabel('QUIZ (20 MCQ)')),
                  if (!widget.readOnly)
                    TextButton.icon(
                      onPressed: _quizGenerating
                          ? null
                          : () => _generateQuiz(regenerate: true),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        _quizGenerating
                            ? '…'
                            : StudyToolCopy.regenerateButton,
                      ),
                    ),
                ],
              ),
              Text(
                StudyToolCopy.recordingPaidFirstGenerate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MCQQuizView(
            questions: _quizQuestions,
            lectureId: widget.lectureId,
            onOpenRevision: () {
              final i = _visibleTabs.indexWhere(
                (t) => t.key == ShareChipCatalog.revision,
              );
              if (i >= 0) _tabController.animateTo(i);
            },
            onGenerateNewQuiz: widget.readOnly ? null : _generateQuiz,
          ),
        ),
      ],
    );
  }

  Widget _revisionTab(BuildContext context) {
    if (_revisionLoading && !_revisionFetched && _revisionSheet.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_revisionError != null && _revisionSheet.isEmpty) {
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.assignment_outlined,
          title: 'Could not load revision sheet',
          reasons: const [
            'Network issue — try again',
            'Revision may not be ready yet',
          ],
          primaryLabel: 'Retry',
          primaryElevated: false,
          onPrimary: () => _loadRevision(force: true),
        ),
      ]);
    }

    if (_revisionSheet.isEmpty) {
      if (widget.readOnly) {
        return _scrollableTab([
          WorkspaceEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No Revision Shared',
            reasons: const [
              'Revision appears when your teacher generates it for this lecture',
            ],
            primaryLabel: 'Retry',
            primaryElevated: false,
            onPrimary: () => _loadRevision(force: true),
          ),
        ]);
      }
      return _scrollableTab([
        WorkspaceEmptyState(
          icon: Icons.assignment_outlined,
          title: 'No Revision Sheet Yet',
          reasons: [
            'Generate an exam-focused recap from notes',
            '${CreditCosts.revisionNotes} credits per generation',
          ],
          primaryLabel:
              'Generate Revision (${CreditCosts.revisionNotes} credits)',
          primaryLoading: _revisionGenerating,
          onPrimary: _generateRevision,
        ),
      ]);
    }

    return _selectableScrollableTab([
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionLabel('REVISION SHEET')),
              if (!widget.readOnly)
                TextButton.icon(
                  onPressed: _revisionGenerating
                      ? null
                      : () => _generateRevision(regenerate: true),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _revisionGenerating
                        ? '…'
                        : StudyToolCopy.regenerateButton,
                  ),
                ),
            ],
          ),
          Text(
            StudyToolCopy.recordingPaidFirstGenerate,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  fontSize: 11,
                ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _placeholderCard(
        child: SmartEducationalContent(
          markdownBody: _revisionSheet,
          visualPayload: _revisionVisualPayload,
        ),
      ),
    ], sourceSurface: 'revision');
  }

  Widget _tabBodyForKey(BuildContext context, String key) {
    switch (key) {
      case ShareChipCatalog.notes:
        return _notesTab(context);
      case ShareChipCatalog.summary:
        return _summaryTab(context);
      case ShareChipCatalog.transcript:
        return _transcriptTab(context);
      case ShareChipCatalog.flashcards:
        return _flashcardsTab(context);
      case ShareChipCatalog.quiz:
        return _quizTab(context);
      case ShareChipCatalog.revision:
        return _revisionTab(context);
      case 'ask_ai':
        return _askAiTab(context);
      case ShareChipCatalog.importantQuestions:
        return _SharedExtraTab(
          lectureId: widget.lectureId,
          chip: ShareChipCatalog.importantQuestions,
        );
      case ShareChipCatalog.mindMap:
        return _SharedExtraTab(
          lectureId: widget.lectureId,
          chip: ShareChipCatalog.mindMap,
        );
      case ShareChipCatalog.fiveMinRevision:
        return _SharedExtraTab(
          lectureId: widget.lectureId,
          chip: ShareChipCatalog.fiveMinRevision,
        );
      case ShareChipCatalog.visual:
        return _visualOnlyTab(context);
      case ShareChipCatalog.learnMore:
      case ShareChipCatalog.memoryTricks:
      case ShareChipCatalog.commonMistakes:
      case ShareChipCatalog.cheatSheet:
      case ShareChipCatalog.teacherTips:
      case ShareChipCatalog.examBooster:
        return _SharedExtraTab(
          lectureId: widget.lectureId,
          chip: key,
        );
      default:
        return const Center(child: Text('Not available'));
    }
  }

  Widget _visualOnlyTab(BuildContext context) {
    if (_notesLoading && _cleanNotes.isEmpty && _visualPayload == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_visualPayload == null) {
      return const WorkspaceEmptyState(
        icon: Icons.image_outlined,
        title: 'No diagram shared',
        reasons: [
          'Teacher did not include a visual for this share.',
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SmartEducationalContent(
          markdownBody: '',
          visualPayload: _visualPayload,
        ),
      ],
    );
  }

  Widget _askAiTab(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('Ask AI'),
                ),
                body: SafeArea(
                  child: WorkspaceAskAiPane(
                    lectureId: widget.lectureId,
                  ),
                ),
              ),
            ),
          );
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Open Ask AI'),
      ),
    ),
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
}

/// Read-only shared Home-style extra (IQ / Mind Map / 5-min) — no Generate.
class _SharedExtraTab extends StatefulWidget {
  final String lectureId;
  final String chip;

  const _SharedExtraTab({
    required this.lectureId,
    required this.chip,
  });

  @override
  State<_SharedExtraTab> createState() => _SharedExtraTabState();
}

class _SharedExtraTabState extends State<_SharedExtraTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> data;
      switch (widget.chip) {
        case ShareChipCatalog.importantQuestions:
          data = await LectureService.instance
              .fetchImportantQuestions(widget.lectureId);
          break;
        case ShareChipCatalog.mindMap:
          data = await LectureService.instance.fetchMindMap(widget.lectureId);
          break;
        case ShareChipCatalog.fiveMinRevision:
          data = await LectureService.instance
              .fetchFiveMinRevision(widget.lectureId);
          break;
        default:
          // Home-style extras — free read (students / reopen).
          final result = await LectureService.instance.lectureFetchStudyTool(
            lectureId: widget.lectureId,
            toolType: widget.chip,
          );
          final p = result['payload'];
          data = p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return WorkspaceEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        reasons: [_error!],
      );
    }
    final data = _data ?? {};
    switch (widget.chip) {
      case ShareChipCatalog.importantQuestions:
        final qs = (data['questions'] as List?) ?? [];
        return ImportantQuestionsView(
          questions: qs
              .whereType<Map>()
              .map((e) =>
                  ImportantQuestion.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      case ShareChipCatalog.mindMap:
        final root = data['root'];
        return MindMapView(
          title: (data['title'] as String?) ?? 'Mind Map',
          root: root is Map
              ? MindMapNodeData.fromJson(Map<String, dynamic>.from(root))
              : null,
        );
      case ShareChipCatalog.fiveMinRevision:
      case ShareChipCatalog.learnMore:
      case ShareChipCatalog.memoryTricks:
      case ShareChipCatalog.commonMistakes:
      case ShareChipCatalog.cheatSheet:
      case ShareChipCatalog.teacherTips:
      case ShareChipCatalog.examBooster:
        final sheet = (data['revisionSheet'] as String?)?.trim() ??
            (data['revision_sheet'] as String?)?.trim() ??
            (data['markdown'] as String?)?.trim() ??
            '';
        if (sheet.isEmpty && (data['tricks'] is! List) && (data['tips'] is! List)) {
          return WorkspaceEmptyState(
            icon: Icons.article_outlined,
            title: 'Not shared yet',
            reasons: const ['Teacher has not generated this chip.'],
          );
        }
        if (sheet.isNotEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SmartEducationalContent(markdownBody: sheet),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              data.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
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
  int? initialTabIndex,
  bool readOnly = false,
  List<String>? allowedChips,
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
                    key: ValueKey(lectureId),
                    lectureId: lectureId,
                    title: title,
                    subject: subject,
                    initialTabIndex: initialTabIndex,
                    readOnly: readOnly,
                    allowedChips: allowedChips,
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
                  key: ValueKey(lectureId),
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
  }/// Opens [StudyWorkspace] as a FULL SCREEN page (not a popup sheet) —
/// used from Group Info so students get a proper dedicated study screen.
Future<void> showStudyWorkspaceFullScreen(
  BuildContext context, {
  required String lectureId,
  required String title,
  String? subject,
  int? initialTabIndex,
  bool readOnly = false,
  List<String>? allowedChips,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (routeContext) {
        return Scaffold(
          body: SafeArea(
            child: StudyWorkspace(
              key: ValueKey(lectureId),
              lectureId: lectureId,
              title: title,
              subject: subject,
              initialTabIndex: initialTabIndex,
              readOnly: readOnly,
              allowedChips: allowedChips,
              onClose: () => Navigator.of(routeContext).pop(),
            ),
          ),
        );
      },
    ),
  );
}

