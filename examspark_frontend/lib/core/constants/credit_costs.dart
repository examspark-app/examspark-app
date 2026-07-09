/// Immutable credit cost constants for ExamSpark enterprise features
/// All values are in credits and match the Master Setup Prompt specification
class CreditCosts {
  CreditCosts._();

  // Transcription costs
  static const int whisperTurboHour = 37;
  static const int whisperNonTurboHour = 99;

  // LLM processing costs
  static const int qwen3Text = 1;
  static const int qwen3VL = 2;

  // Feature generation costs (each = 1 credit)
  static const int mcqGeneration = 1;
  static const int revisionGeneration = 1;
  static const int importantQuestionsGeneration = 1;
  static const int answerKeyGeneration = 1;
  static const int flashcardGeneration = 1;
  
  // RAG and ingest costs
  static const int ragQuery = 1;
  static const int pdfTextIngest = 1;

  // Helper method to get cost by action type
  static int getCostForAction(String action, {bool useTurbo = true}) {
    switch (action.toLowerCase()) {
      case 'transcribe':
        return useTurbo ? whisperTurboHour : whisperNonTurboHour;
      case 'mcq':
        return mcqGeneration;
      case 'revision':
      case 'revision_sheet':
        return revisionGeneration;
      case 'important_questions':
        return importantQuestionsGeneration;
      case 'answer_key':
        return answerKeyGeneration;
      case 'flashcard':
        return flashcardGeneration;
      case 'rag':
        return ragQuery;
      case 'pdf_ingest':
        return pdfTextIngest;
      case 'qwen3_vl':
        return qwen3VL;
      case 'qwen3_text':
        return qwen3Text;
      default:
        return 0;
    }
  }
}
