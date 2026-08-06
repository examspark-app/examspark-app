/// Plan-tier feature gating.
///
/// UPDATED (Aug 2026): recording / audio upload is now open on every plan
/// (including Free) for both students and teachers — the app is
/// credit-based, so usage is metered by credits spent per action, not by
/// a plan-tier lock. `isFeatureUnlocked` / `isStudentAudioUnlocked` /
/// `isTeacherLiveRecordUnlocked` below all now return true unconditionally
/// so nothing in the UI shows a "needs ₹499+ Plan" / "needs Teacher plan"
/// message for recording. The gating machinery (enum, minimumPlanId map,
/// planRank) is kept in place — unused right now, but here if plan-based
/// gating is ever reintroduced for something else.
///
/// See CREDIT_ECONOMY.md · TEACHER_PLATFORM.md
enum GatedFeature {
  askAi,
  pdfAnalysis,
  diagramAnalysis,
  youtubeLink,
  recordLecture,
  flashcards,
  quiz,
  revision,
  importantQuestions,
  mindMap,
}

class PlanTierGating {
  PlanTierGating._();

  static const Map<GatedFeature, String> minimumPlanId = {
    GatedFeature.askAi: 'free',
    GatedFeature.pdfAnalysis: 'free',
    GatedFeature.diagramAnalysis: 'free',
    GatedFeature.youtubeLink: 'free',
    GatedFeature.flashcards: 'free',
    GatedFeature.quiz: 'free',
    GatedFeature.revision: 'free',
    GatedFeature.importantQuestions: 'free',
    GatedFeature.mindMap: 'free',
    // Open on every plan now — credit-based, not plan-locked (see note above).
    GatedFeature.recordLecture: 'free',
  };

  static const List<String> planRank = [
    'free',
    'plan_199',
    'plan_299',
    'plan_499',
    'plan_999',
    'teacher',
  ];

  static bool isFeatureUnlocked({
    required String currentPlanId,
    required GatedFeature feature,
  }) {
    final requiredPlan = minimumPlanId[feature]!;
    return _rank(currentPlanId) >= _rank(requiredPlan);
  }

  /// Student path: Record + Upload Audio from Home — open on every plan
  /// (including Free); credits are still charged per use.
  static bool isStudentAudioUnlocked(String currentPlanId) {
    return true;
  }

  /// Teacher Dashboard / teacherRecordOnly live Record — open on every
  /// plan (including Free); credits are still charged per use.
  static bool isTeacherLiveRecordUnlocked(String currentPlanId) {
    return true;
  }

  static int _rank(String planId) {
    final i = planRank.indexOf(planId);
    return i < 0 ? 0 : i;
  }

  static String lockMessage(GatedFeature feature) {
    switch (feature) {
      case GatedFeature.recordLecture:
      case GatedFeature.pdfAnalysis:
      case GatedFeature.diagramAnalysis:
      case GatedFeature.youtubeLink:
      case GatedFeature.flashcards:
      case GatedFeature.quiz:
      case GatedFeature.revision:
      case GatedFeature.importantQuestions:
      case GatedFeature.mindMap:
      case GatedFeature.askAi:
        return 'Available on Free and all paid plans (uses credits).';
    }
  }

  static String teacherLiveRecordLockMessage() {
    return 'Teacher live Record is available on every plan (uses credits).';
  }

  static String teacherShareWorkspaceLockMessage() {
    return 'Sharing Study Workspace to Groups is available on every plan (uses credits).';
  }

  static GatedFeature? featureFromAction(String action) {
    switch (action.toLowerCase()) {
      case 'rag':
      case 'ask_ai':
      case 'ask-rag':
        return GatedFeature.askAi;
      case 'pdf':
      case 'pdf_ingest':
        return GatedFeature.pdfAnalysis;
      case 'diagram':
      case 'image':
      case 'photo':
      case 'qwen3_vl':
      case 'ocr':
        return GatedFeature.diagramAnalysis;
      case 'youtube':
      case 'youtube_link':
        return GatedFeature.youtubeLink;
      case 'record':
      case 'transcribe':
      case 'record_lecture':
      case 'audio_upload':
        return GatedFeature.recordLecture;
      case 'flashcard':
      case 'flashcards':
        return GatedFeature.flashcards;
      case 'mcq':
      case 'quiz':
        return GatedFeature.quiz;
      case 'revision':
      case 'revision_sheet':
        return GatedFeature.revision;
      case 'important_questions':
      case 'important-questions':
        return GatedFeature.importantQuestions;
      case 'mind_map':
      case 'mind-map':
        return GatedFeature.mindMap;
      default:
        return null;
    }
  }
}