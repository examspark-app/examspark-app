/// One clear line for study tools (Home vs recording differ on purpose).
/// Student-facing — no "database" / RAG jargon.
import 'package:examspark_frontend/core/constants/student_copy.dart';

class StudyToolCopy {
  StudyToolCopy._();

  /// Home AI chips — first open free from saved result.
  static const String freeDbVsRegenerateAi = StudentCopy.savedFree;

  /// Recording / Study Workspace — first AI generate is paid; reopen free.
  static const String recordingPaidFirstGenerate =
      StudentCopy.recordingPaidFirst;

  static const String regenerateButton = StudentCopy.regenerateButton;

  static String creditsFooter({required bool fromDatabase, int? charged}) {
    return StudentCopy.creditsFooter(
      fromSaved: fromDatabase,
      charged: charged,
    );
  }
}
