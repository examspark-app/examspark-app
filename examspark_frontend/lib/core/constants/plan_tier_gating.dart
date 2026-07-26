/// Plan-tier feature gating.
///
/// Two **separate** audio rules (founder Jul 25, 2026):
/// - **Student** Home Record / Upload Audio → ₹499+ (`plan_499`, `plan_999`)
/// - **Teacher** live Record (Dashboard / teacherRecordOnly) → **Teacher ₹2,999 only**
///   (`teacher`) — NOT unlocked by student ₹499
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
    // Student audio only — Teacher live record uses [isTeacherLiveRecordUnlocked].
    GatedFeature.recordLecture: 'plan_499',
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

  /// Student path: Record + Upload Audio from Home — ₹499 / ₹999 / Teacher.
  /// (Teacher plan also ranks above ₹499 so teachers can use Home audio if needed.)
  static bool isStudentAudioUnlocked(String currentPlanId) {
    return isFeatureUnlocked(
      currentPlanId: currentPlanId,
      feature: GatedFeature.recordLecture,
    );
  }

  /// Teacher Dashboard / teacherRecordOnly live Record — **Teacher plan only**.
  /// Student ₹499 does **not** unlock this path.
  static bool isTeacherLiveRecordUnlocked(String currentPlanId) {
    return currentPlanId.trim().toLowerCase() == 'teacher';
  }

  static int _rank(String planId) {
    final i = planRank.indexOf(planId);
    return i < 0 ? 0 : i;
  }

  static String lockMessage(GatedFeature feature) {
    switch (feature) {
      case GatedFeature.recordLecture:
        return 'This feature needs the ₹499+ Plan.\n'
            'Audio recording and audio upload unlock from the ₹499 Plan.';
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
    return 'Teacher live Record needs the Teacher plan (₹2,999).\n'
        'When that month ends: Record + new Create Group + Share workspace '
        'lock until renew. Existing groups stay. Student ₹499 does not unlock Teacher Record.';
  }

  static String teacherShareWorkspaceLockMessage() {
    return 'Sharing Study Workspace to Groups needs active Teacher plan (₹2,999). '
        'Renew to share lectures, notes, quiz, or announcements.';
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
