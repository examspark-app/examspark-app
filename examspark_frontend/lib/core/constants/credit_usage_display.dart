import 'package:examspark_frontend/core/constants/credit_costs.dart';

/// Dashboard translated usage estimates — single shared credit pool.
class CreditUsageDisplay {
  CreditUsageDisplay._();

  /// Primary stat: lecture sessions if ALL credits used only for ~60min recording.
  static int estimateLectureSessions(int creditsRemaining) {
    final perSession = CreditCosts.recordCreditsPerMinute * 60;
    if (perSession <= 0) return 0;
    return creditsRemaining ~/ perSession;
  }

  static int estimateAskAiQuestions(int creditsRemaining) {
    if (CreditCosts.askAiNormal <= 0) return 0;
    return creditsRemaining ~/ CreditCosts.askAiNormal;
  }

  /// Recommended primary dashboard line.
  static String primaryBalanceLine(int creditsRemaining) {
    final sessions = estimateLectureSessions(creditsRemaining);
    return '≈ $sessions Lecture Sessions (if used only for recording)';
  }

  static const String multiStatDisclaimer =
      'Remaining AI Usage (estimates only — using one reduces the others, '
      'all draw from the same balance)';
}
