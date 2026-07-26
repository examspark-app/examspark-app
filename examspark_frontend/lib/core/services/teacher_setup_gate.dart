import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Founder-locked Jul 25, 2026 — hard lock order:
/// 1) Full profile (no cert required)
/// 2) Get Verified (AI soft) → unlocks buy
/// 3) Teacher ₹2,999 → unlocks Create Group
/// Profile PDF/photo cert = optional, teacher choice for students — NOT the gate.
/// Spec: TEACHER_PLATFORM.md §1b
class TeacherSetupGateStatus {
  final bool hasTeacherPlan;
  final bool hasVerified;
  final bool hasFullName;
  final bool hasSubject;
  final bool hasCity;
  final bool hasState;
  final bool hasQualification;
  /// Optional profile display only — never blocks buy / Create Group.
  final bool hasCertificate;
  final String planId;

  const TeacherSetupGateStatus({
    required this.hasTeacherPlan,
    required this.hasVerified,
    required this.hasFullName,
    required this.hasSubject,
    required this.hasCity,
    required this.hasState,
    required this.hasQualification,
    required this.hasCertificate,
    required this.planId,
  });

  /// Name + subjects + location + qualification. Certificates are optional.
  bool get profileGateComplete =>
      hasFullName &&
      hasSubject &&
      hasCity &&
      hasState &&
      hasQualification;

  /// Buy Teacher plan only after AI Get Verified.
  bool get canBuyTeacherPlan => profileGateComplete && hasVerified;

  /// Create Group only after AI verified + Teacher plan.
  bool get canCreateGroup =>
      profileGateComplete && hasVerified && hasTeacherPlan;

  /// Get Verified (AI) after profile — before payment.
  bool get canGetVerified => profileGateComplete;

  List<String> get missingLabels {
    final out = <String>[];
    if (!hasFullName) out.add('Full Name');
    if (!hasSubject) out.add('Teaching Subject (1+)');
    if (!hasCity) out.add('City');
    if (!hasState) out.add('State');
    if (!hasQualification) out.add('Qualification');
    if (!hasVerified) out.add('Get Verified — AI Trusted badge');
    if (!hasTeacherPlan) out.add('Teacher plan (₹2,999)');
    return out;
  }

  List<String> get missingProfileLabels {
    final out = <String>[];
    if (!hasFullName) out.add('Full Name');
    if (!hasSubject) out.add('Teaching Subject');
    if (!hasCity) out.add('City');
    if (!hasState) out.add('State');
    if (!hasQualification) out.add('Qualification');
    return out;
  }

  int get checklistDone {
    var n = 0;
    if (hasFullName) n++;
    if (hasSubject) n++;
    if (hasCity) n++;
    if (hasState) n++;
    if (hasQualification) n++;
    if (hasVerified) n++;
    if (hasTeacherPlan) n++;
    return n;
  }

  static const int checklistTotal = 7;

  /// Next primary CTA — profile → AI verify → buy plan.
  TeacherSetupGatePrimary get primaryAction {
    if (!profileGateComplete) return TeacherSetupGatePrimary.editProfile;
    if (!hasVerified) return TeacherSetupGatePrimary.getVerified;
    if (!hasTeacherPlan) return TeacherSetupGatePrimary.buyPlan;
    return TeacherSetupGatePrimary.none;
  }

  factory TeacherSetupGateStatus.from({
    required String planId,
    required TeacherProfileModel? profile,
  }) {
    final p = profile;
    final nameOk = (p?.fullName.trim().isNotEmpty ?? false) &&
        (p!.fullName.trim().toLowerCase() != 'new teacher');
    final subjects = TeacherProfileModel.parseSubjects(p?.subject);
    return TeacherSetupGateStatus(
      planId: planId,
      hasTeacherPlan: planId == 'teacher',
      hasVerified: p?.isVerified ?? false,
      hasFullName: nameOk,
      hasSubject: subjects.isNotEmpty,
      hasCity: p?.city?.trim().isNotEmpty ?? false,
      hasState: p?.state?.trim().isNotEmpty ?? false,
      hasQualification: p?.qualification?.trim().isNotEmpty ?? false,
      hasCertificate: p?.certificates.isNotEmpty ?? false,
    );
  }
}

enum TeacherSetupGatePrimary { getVerified, buyPlan, editProfile, none }

class TeacherSetupGate {
  TeacherSetupGate._();

  static Future<TeacherSetupGateStatus> evaluate(
    TeacherProfileModel? profile,
  ) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    var planId = 'free';
    if (userId != null) {
      try {
        planId = await SupabaseClient.instance.getPlanTier(userId);
      } catch (_) {
        planId = 'free';
      }
    }
    return TeacherSetupGateStatus.from(planId: planId, profile: profile);
  }
}
