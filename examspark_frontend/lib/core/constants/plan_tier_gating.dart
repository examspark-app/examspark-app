/// Plan-tier feature gating — Free = credits; audio record/upload needs ₹499+.
/// Founder Jul 15, 2026 (audio lock corrected to ₹499) — see CREDIT_ECONOMY.md
enum GatedFeature {
  askAi,
  pdfAnalysis,
  diagramAnalysis,
  youtubeLink,
  recordLecture,
  flashcards,
  quiz,
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
    // Only plan lock: audio record + audio upload (₹499+).
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

  static int _rank(String planId) {
    final i = planRank.indexOf(planId);
    return i < 0 ? 0 : i;
  }

  static String lockMessage(GatedFeature feature) {
    switch (feature) {
      case GatedFeature.recordLecture:
        // Hardcoded ₹499 — do not derive from plan id label (avoids stale ₹199 UI).
        return 'This feature needs the ₹499+ Plan.\n'
            'Audio recording and audio upload unlock from the ₹499 Plan.';
      case GatedFeature.pdfAnalysis:
      case GatedFeature.diagramAnalysis:
      case GatedFeature.youtubeLink:
      case GatedFeature.flashcards:
      case GatedFeature.quiz:
      case GatedFeature.askAi:
        return 'Available on Free and all paid plans (uses credits).';
    }
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
      default:
        return null;
    }
  }
}
