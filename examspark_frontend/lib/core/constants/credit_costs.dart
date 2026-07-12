/// Credit Economy v2 — feature/session-based, never per-minute in UI.
class CreditCosts {
  CreditCosts._();

  /// Backend only — never show in UI. Charged-value per credit.
  static const double internalRupeePerCredit = 0.15;

  // Recording by session duration bucket (NOT per-minute)
  static const int recordUpTo30Min = 40;
  static const int record30To60Min = 80;
  static const int record60To90Min = 120;
  static const int summaryWithRecording = 0;

  // YouTube Link → Notes (founder-locked Jul 12, 2026: ~₹15/hour basis,
  // cheaper than Record since there's no Whisper/STT cost — captions come
  // straight from the video). Public videos only, capped at 1 hour.
  static const int youtubeUpTo20Min = 35;
  static const int youtube20To40Min = 65;
  static const int youtube40To60Min = 100;
  static const int youtubeMaxMinutes = 60;

  // Ask AI
  static const int askAiNormal = 5;
  static const int askAiDeep = 12;

  // Generated content
  static const int flashcards = 20;
  static const int quiz20Mcq = 25;
  static const int importantQuestions = 20;
  static const int revisionNotes = 20;
  static const int formulaSheet = 15;
  static const int mindMap = 30;

  // Vision / documents
  static const int diagramImage = 25;
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

  /// Duration bucket for recording — never expose per-minute rate to user.
  static int recordCreditsForDurationMinutes(int minutes) {
    if (minutes <= 30) return recordUpTo30Min;
    if (minutes <= 60) return record30To60Min;
    if (minutes <= 90) return record60To90Min;
    return record60To90Min;
  }

  /// Duration bucket for YouTube Link → Notes. Videos longer than
  /// [youtubeMaxMinutes] are rejected before this is ever called.
  static int youtubeCreditsForDurationMinutes(int minutes) {
    if (minutes <= 20) return youtubeUpTo20Min;
    if (minutes <= 40) return youtube20To40Min;
    return youtube40To60Min;
  }

  static int getCostForAction(String action, {bool useTurbo = true, bool deep = false}) {
    switch (action.toLowerCase()) {
      case 'transcribe':
      case 'record':
      case 'record_lecture':
        return record30To60Min;
      case 'youtube':
      case 'youtube_link':
        return youtube20To40Min;
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
