import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_reading_utils.dart';

/// In-memory + SharedPreferences Study Workspace cache (Phase 4E P0).
///
/// Open lecture once → fetch once → switch tabs instantly.
/// Repeat open: memory → disk → network (silent sync).
class WorkspaceLectureCache {
  WorkspaceLectureCache._();
  static final WorkspaceLectureCache instance = WorkspaceLectureCache._();

  static const _prefsPrefix = 'ws_notes_v1_';

  final Map<String, WorkspaceLectureSnapshot> _byLectureId = {};

  WorkspaceLectureSnapshot? get(String lectureId) => _byLectureId[lectureId];

  WorkspaceLectureSnapshot put(String lectureId, WorkspaceLectureSnapshot snap) {
    _byLectureId[lectureId] = snap;
    return snap;
  }

  /// Returns existing snapshot or creates an empty one and stores it.
  WorkspaceLectureSnapshot getOrCreate(String lectureId) {
    return _byLectureId.putIfAbsent(lectureId, () => WorkspaceLectureSnapshot());
  }

  void invalidate(String lectureId) => _byLectureId.remove(lectureId);

  /// Drop memory + SharedPreferences cache after permanent lecture delete.
  Future<void> removeLecture(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) return;
    _byLectureId.remove(id);
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('$_prefsPrefix$id');
    } catch (_) {}
  }

  void clearAll() => _byLectureId.clear();

  Future<WorkspaceLectureSnapshot?> loadFromDisk(String lectureId) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('$_prefsPrefix$lectureId');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final snap = WorkspaceLectureSnapshot.fromJson(Map<String, dynamic>.from(map));
      if (!snap.hasUsableNotes) return null;
      _byLectureId[lectureId] = snap;
      return snap;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToDisk(String lectureId, WorkspaceLectureSnapshot snap) async {
    if (!snap.hasUsableNotes) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('$_prefsPrefix$lectureId', jsonEncode(snap.toJson()));
    } catch (_) {}
  }
}

/// All Study Workspace payloads for one lecture (session memory + disk).
class WorkspaceLectureSnapshot {
  String? metaSubject;
  DateTime? createdAt;
  String? lectureStatus;
  bool canShareToGroup = false;
  bool metaFetched = false;

  bool notesFetched = false;
  bool notesError = false;
  String shortSummary = '';
  String cleanNotes = '';
  List<dynamic> keyPoints = [];
  List<dynamic> importantTerms = [];
  VisualPayloadData? visualPayload;

  bool transcriptFetched = false;
  String transcript = '';
  int transcriptWordCount = 0;

  bool flashcardsFetched = false;
  String? flashcardsError;
  List<Flashcard> flashcards = [];

  bool quizFetched = false;
  String? quizError;
  List<MCQQuestion> quizQuestions = [];

  bool revisionFetched = false;
  String? revisionError;
  String revisionSheet = '';
  VisualPayloadData? revisionVisualPayload;

  WorkspaceLectureSnapshot();

  bool get hasAnyCoreContent =>
      notesFetched || transcriptFetched || flashcardsFetched || quizFetched || revisionFetched;

  bool get hasUsableNotes =>
      cleanNotes.trim().isNotEmpty ||
      shortSummary.trim().isNotEmpty ||
      keyPoints.isNotEmpty ||
      importantTerms.isNotEmpty;

  void applyMeta({
    String? subject,
    DateTime? createdAt,
    String? status,
    bool? canShare,
  }) {
    if (subject != null) metaSubject = subject;
    if (createdAt != null) this.createdAt = createdAt;
    if (status != null) lectureStatus = status;
    if (canShare != null) canShareToGroup = canShare;
    metaFetched = true;
  }

  void applyNotes({
    required String shortSummary,
    required String cleanNotes,
    required List<dynamic> keyPoints,
    required List<dynamic> importantTerms,
    VisualPayloadData? visualPayload,
    required bool error,
  }) {
    this.shortSummary = shortSummary;
    this.cleanNotes = cleanNotes;
    this.keyPoints = keyPoints;
    this.importantTerms = importantTerms;
    this.visualPayload = visualPayload;
    notesError = error;
    notesFetched = true;
  }

  void applyTranscript({
    required String transcript,
    required int wordCount,
  }) {
    this.transcript = transcript;
    transcriptWordCount = wordCount > 0 ? wordCount : countWords(transcript);
    transcriptFetched = true;
  }

  void applyFlashcards({
    required List<Flashcard> cards,
    String? error,
  }) {
    flashcards = cards;
    flashcardsError = error;
    flashcardsFetched = true;
  }

  void applyQuiz({
    required List<MCQQuestion> questions,
    String? error,
  }) {
    quizQuestions = questions;
    quizError = error;
    quizFetched = true;
  }

  void applyRevision({
    required String sheet,
    VisualPayloadData? visualPayload,
    String? error,
  }) {
    revisionSheet = sheet;
    revisionVisualPayload = visualPayload;
    revisionError = error;
    revisionFetched = true;
  }

  Map<String, dynamic> toJson() => {
        'shortSummary': shortSummary,
        'cleanNotes': cleanNotes,
        'keyPoints': keyPoints,
        'importantTerms': importantTerms,
        'visualPayload': null, // P0: notes text first; visual rehydrates on sync
        'notesFetched': notesFetched,
        'notesError': notesError,
        'transcript': transcript,
        'transcriptWordCount': transcriptWordCount,
        'transcriptFetched': transcriptFetched,
        'revisionSheet': revisionSheet,
        'revisionFetched': revisionFetched,
        'metaSubject': metaSubject,
        'lectureStatus': lectureStatus,
      };

  factory WorkspaceLectureSnapshot.fromJson(Map<String, dynamic> json) {
    final snap = WorkspaceLectureSnapshot();
    snap.shortSummary = (json['shortSummary'] as String?) ?? '';
    snap.cleanNotes = (json['cleanNotes'] as String?) ?? '';
    snap.keyPoints = (json['keyPoints'] as List?) ?? [];
    snap.importantTerms = (json['importantTerms'] as List?) ?? [];
    final vp = json['visualPayload'];
    snap.visualPayload = vp is Map
        ? VisualPayloadData.fromJson(Map<String, dynamic>.from(vp))
        : null;
    snap.notesFetched = json['notesFetched'] as bool? ?? snap.hasUsableNotes;
    snap.notesError = false;
    snap.transcript = (json['transcript'] as String?) ?? '';
    snap.transcriptWordCount = json['transcriptWordCount'] as int? ?? 0;
    snap.transcriptFetched = json['transcriptFetched'] as bool? ?? false;
    snap.revisionSheet = (json['revisionSheet'] as String?) ?? '';
    snap.revisionFetched = json['revisionFetched'] as bool? ?? false;
    snap.metaSubject = json['metaSubject'] as String?;
    snap.lectureStatus = json['lectureStatus'] as String?;
    return snap;
  }
}
