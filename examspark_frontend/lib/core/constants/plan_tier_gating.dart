/// Plan-tier feature gating — v2 credit economy.
enum GatedFeature {
  askAi,
  pdfAnalysis,
  diagramAnalysis,
  recordLecture,
  flashcards,
  quiz,
}

class PlanTierGating {
  PlanTierGating._();

  static const Map<GatedFeature, String> minimumPlanId = {
    GatedFeature.askAi: 'free',
    // CREDIT_ECONOMY.md Jul 12: PDF Analysis (text-only) moved into Free.
    GatedFeature.pdfAnalysis: 'free',
    GatedFeature.diagramAnalysis: 'plan_199',
    GatedFeature.flashcards: 'plan_199',
    GatedFeature.quiz: 'plan_199',
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
        return '🔒 This feature needs the ₹499+ Plan\n'
            'Recording is available starting from the ₹499 Plan.';
      case GatedFeature.pdfAnalysis:
        return 'PDF Analysis is available on Free and all paid plans.';
      case GatedFeature.diagramAnalysis:
      case GatedFeature.flashcards:
      case GatedFeature.quiz:
        return '🔒 This feature needs the ₹199+ Plan\n'
            'Upgrade to unlock photo/diagram and study features.';
      case GatedFeature.askAi:
        return 'Ask AI is available on all plans.';
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
      case 'record':
      case 'transcribe':
      case 'record_lecture':
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
