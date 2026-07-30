/// Credit Economy — Record/Audio = per-minute; other features stay session-based.
///
/// Founder Jul 22, 2026: Recording + Audio Upload = 1 credit/min (actual length,
/// round up, max 180). YouTube stays banded (10/20/40).
class CreditCosts {
  CreditCosts._();

  /// Backend only — never show in UI. Charged-value per credit.
  static const double internalRupeePerCredit = 0.15;

  // Recording / Audio Upload — per-minute (actual length)
  static const int recordCreditsPerMinute = 1;
  /// Hard max for Record / audio upload (3 hours).
  static const int recordMaxMinutes = 180;
  // Legacy band constants (pre–per-minute) — reference / old imports only.
  static const int recordUpTo30Min = 40;
  static const int record30To60Min = 80;
  static const int record60To90Min = 120;
  static const int record90To180Min = 240;
  static const int summaryWithRecording = 0;

  // YouTube Link → Notes: cheaper than Record (10/20/40). Max 90 minutes.
  static const int youtubeUpTo30Min = 10;
  static const int youtube30To60Min = 20;
  static const int youtube60To90Min = 40;
  static const int youtubeMaxMinutes = 90;
  // Legacy names used in UI copy.
  static const int youtubeUpTo20Min = youtubeUpTo30Min;
  static const int youtube20To40Min = youtube30To60Min;
  static const int youtube40To60Min = youtube60To90Min;

  // Ask AI
  static const int askAiNormal = 5;
  static const int askAiDeep = 12;
  /// Live web search (Tavily) — current events last resort only. 2× normal.
  static const int askAiWebSearch = 10;
  static const int askAiWebSearchDeep = 20;

  /// Home study chips after a successful Home AI answer — **0 credits**
  /// (Founder Phase 4C Final Hardening Jul 17, 2026). First Ask still costs
  /// [askAiNormal]/[askAiDeep]. Explicit Regenerate is charged server-side.
  static const int homeChipMindMap = 0;
  static const int homeChipImportantQuestions = 0;

  // Select & Ask AI (Phase 6) — selection-scoped
  static const int selectAiExplain = 2;
  static const int selectAiMiniQuiz = 3;
  static const int selectAiMiniFlashcards = 3;

  // Generated content
  static const int flashcards = 5;
  static const int quiz20Mcq = 5;
  static const int importantQuestions = 20;
  static const int revisionNotes = 5;
  /// Home chip — short 5-minute recap (same credit as Revision Notes).
  static const int fiveMinRevision = 5;
  static const int formulaSheet = 15;
  static const int mindMap = 30;

  // Vision / documents
  static const int diagramImage = 25;
  /// Home AI Camera / Upload Image → chat (not Study Workspace). Founder Jul 18.
  static const int homeAiVision = 10;
  static const int pdfAnalysis = 20;
  static const int ocrImage = 15;

  // Other
  static const int translate = 8;
  static const int voiceRead = 5;

  // Legacy aliases (existing code paths)
  static const int recordLecture = record30To60Min;
  static const int whisperTurboHour = record30To60Min;
  static const int whisperNonTurboHour = record30To60Min;
  static const int askAi = askAiNormal;
  static const int ragQuery = askAiNormal;
  static const int pdfTextIngest = pdfAnalysis;
  static const int qwen3VL = diagramImage;
  static const int flashcardGeneration = flashcards;
  static const int mcqGeneration = quiz20Mcq;
  static const int revisionGeneration = revisionNotes;
  static const int importantQuestionsGeneration = importantQuestions;
  static const int answerKeyGeneration = quiz20Mcq;
  static const int mindMapGeneration = mindMap;
  static const int qwen3Text = askAiNormal;

  /// Recording / Audio Upload: 1 credit per minute (clamp 1–180).
  static int recordCreditsForDurationMinutes(int minutes) {
    final clamped = minutes.clamp(1, recordMaxMinutes);
    return clamped * recordCreditsPerMinute;
  }

  /// Duration bucket for YouTube (10/20/40).
  static int youtubeCreditsForDurationMinutes(int minutes) {
    if (minutes <= 30) return youtubeUpTo30Min;
    if (minutes <= 60) return youtube30To60Min;
    if (minutes <= 90) return youtube60To90Min;
    return youtube60To90Min;
  }

  static int selectAiCostForAction(String action) {
    switch (action.toLowerCase()) {
      case 'generate_quiz':
      case 'quiz':
      case 'mini_quiz':
        return selectAiMiniQuiz;
      case 'generate_flashcards':
      case 'flashcards':
      case 'mini_flashcards':
        return selectAiMiniFlashcards;
      default:
        return selectAiExplain;
    }
  }

  static int getCostForAction(String action, {bool useTurbo = true, bool deep = false}) {
    switch (action.toLowerCase()) {
      case 'select_ai':
      case 'select-ai':
      case 'explain':
      case 'simplify':
      case 'memory_trick':
      case 'exam_view':
      case 'ask_followup':
        return selectAiExplain;
      case 'generate_quiz':
      case 'mini_quiz':
        return selectAiMiniQuiz;
      case 'generate_flashcards':
      case 'mini_flashcards':
        return selectAiMiniFlashcards;
      case 'transcribe':
      case 'record':
      case 'record_lecture':
        return record30To60Min;
      case 'youtube':
      case 'youtube_link':
        return youtube30To60Min;
      case 'pdf':
      case 'pdf_ingest':
      case 'pdf_analysis':
        return pdfAnalysis;
      case 'diagram':
      case 'diagram_analysis':
      case 'qwen3_vl':
      case 'image':
      case 'photo':
        return diagramImage;
      case 'ocr':
      case 'ocr_image':
        return ocrImage;
      case 'rag':
      case 'ask_ai':
      case 'ask-rag':
        return deep ? askAiDeep : askAiNormal;
      case 'flashcard':
      case 'flashcards':
        return flashcards;
      case 'mcq':
      case 'quiz':
        return quiz20Mcq;
      case 'revision':
      case 'revision_sheet':
        return revisionNotes;
      case 'five_min_revision':
      case 'five-min-revision':
      case '5_minute_revision':
        return fiveMinRevision;
      case 'important_questions':
        return importantQuestions;
      case 'answer_key':
        return quiz20Mcq;
      case 'mind_map':
        return mindMap;
      case 'formula':
      case 'formula_sheet':
        return formulaSheet;
      case 'translate':
        return translate;
      case 'voice_read':
        return voiceRead;
      case 'summary':
        return summaryWithRecording;
      case 'qwen3_text':
        return askAiNormal;
      default:
        return 0;
    }
  }
}
