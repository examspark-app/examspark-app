import 'package:examspark_frontend/core/models/teacher_achievement_model.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';

/// Verification state shown as a badge on the teacher's public profile.
enum TeacherVerificationStatus { verified, pending, unverified }

/// One optional public trust link (Dashboard edit + student profile icons).
enum TeacherSocialKind {
  website,
  youtube,
  instagram,
  facebook,
  linkedin,
  whatsapp,
  telegram,
  x,
}

extension TeacherSocialKindX on TeacherSocialKind {
  String get columnKey => switch (this) {
        TeacherSocialKind.website => 'link_website',
        TeacherSocialKind.youtube => 'link_youtube',
        TeacherSocialKind.instagram => 'link_instagram',
        TeacherSocialKind.facebook => 'link_facebook',
        TeacherSocialKind.linkedin => 'link_linkedin',
        TeacherSocialKind.whatsapp => 'link_whatsapp',
        TeacherSocialKind.telegram => 'link_telegram',
        TeacherSocialKind.x => 'link_x',
      };

  String get label => switch (this) {
        TeacherSocialKind.website => 'Website',
        TeacherSocialKind.youtube => 'YouTube',
        TeacherSocialKind.instagram => 'Instagram',
        TeacherSocialKind.facebook => 'Facebook',
        TeacherSocialKind.linkedin => 'LinkedIn',
        TeacherSocialKind.whatsapp => 'WhatsApp',
        TeacherSocialKind.telegram => 'Telegram',
        TeacherSocialKind.x => 'X (Twitter)',
      };

  String get hint => switch (this) {
        TeacherSocialKind.website => 'https://yoursite.com',
        TeacherSocialKind.youtube => 'https://youtube.com/@channel',
        TeacherSocialKind.instagram => 'https://instagram.com/username',
        TeacherSocialKind.facebook => 'https://facebook.com/page',
        TeacherSocialKind.linkedin => 'https://linkedin.com/in/username',
        TeacherSocialKind.whatsapp => 'wa.me/91… or +91…',
        TeacherSocialKind.telegram => 'https://t.me/username',
        TeacherSocialKind.x => 'https://x.com/username',
      };
}

/// Full public Teacher Profile — Teacher Dashboard + Group Info (students).
///
/// Backed by `teacher_profiles`. Optional social links = trust only (no in-app chat).
class TeacherProfileModel {
  final String id;
  final String? userId;
  final String fullName;
  final String? photoUrl;
  final String subject;
  final String? bio;
  final String? qualification;
  final int experienceYears;
  final String? city;
  final String? state;
  /// Teaching language(s) — comma-separated (multi OK). Optional.
  final String? language;
  /// Class / levels offered — comma-separated (multi, no max). Optional.
  final String? classLevels;
  /// Boards / exams offered — comma-separated (multi, no max). Optional.
  final String? exams;
  final String? linkWebsite;
  final String? linkYoutube;
  final String? linkInstagram;
  final String? linkFacebook;
  final String? linkLinkedin;
  final String? linkWhatsapp;
  final String? linkTelegram;
  final String? linkX;
  final TeacherVerificationStatus verificationStatus;
  final DateTime joinedSince;
  final int totalStudents;
  final int totalGroups;
  final int totalSharedLectures;
  /// When true, students see profile certificates (Group Info). Default false.
  /// Not the same as Get Verified (AI Trusted badge).
  final bool showCertificatesOnProfile;
  final List<TeacherCertificateModel> certificates;
  final List<TeacherAchievementModel> achievements;

  const TeacherProfileModel({
    required this.id,
    this.userId,
    required this.fullName,
    this.photoUrl,
    required this.subject,
    this.bio,
    this.qualification,
    this.experienceYears = 0,
    this.city,
    this.state,
    this.language,
    this.classLevels,
    this.exams,
    this.linkWebsite,
    this.linkYoutube,
    this.linkInstagram,
    this.linkFacebook,
    this.linkLinkedin,
    this.linkWhatsapp,
    this.linkTelegram,
    this.linkX,
    this.verificationStatus = TeacherVerificationStatus.unverified,
    required this.joinedSince,
    this.totalStudents = 0,
    this.totalGroups = 0,
    this.totalSharedLectures = 0,
    this.showCertificatesOnProfile = false,
    this.certificates = const [],
    this.achievements = const [],
  });

  bool get isVerified => verificationStatus == TeacherVerificationStatus.verified;

  /// Multi-subject stored as comma-separated in [subject] column.
  static List<String> parseSubjects(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String joinSubjects(List<String> subjects) {
    return subjects
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  List<String> get subjectsList => parseSubjects(subject);

  List<String> get languagesList => parseSubjects(language);

  List<String> get classLevelsList => parseSubjects(classLevels);

  List<String> get examsList => parseSubjects(exams);

  String get locationLabel {
    final c = city?.trim() ?? '';
    final s = state?.trim() ?? '';
    if (c.isNotEmpty && s.isNotEmpty) return '$c, $s';
    if (c.isNotEmpty) return c;
    if (s.isNotEmpty) return s;
    return '';
  }

  String? linkFor(TeacherSocialKind kind) {
    final raw = switch (kind) {
      TeacherSocialKind.website => linkWebsite,
      TeacherSocialKind.youtube => linkYoutube,
      TeacherSocialKind.instagram => linkInstagram,
      TeacherSocialKind.facebook => linkFacebook,
      TeacherSocialKind.linkedin => linkLinkedin,
      TeacherSocialKind.whatsapp => linkWhatsapp,
      TeacherSocialKind.telegram => linkTelegram,
      TeacherSocialKind.x => linkX,
    };
    final t = raw?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  /// Filled links only — for student icons / dashboard preview.
  List<(TeacherSocialKind, String)> get filledSocialLinks {
    final out = <(TeacherSocialKind, String)>[];
    for (final kind in TeacherSocialKind.values) {
      final v = linkFor(kind);
      if (v != null) out.add((kind, v));
    }
    return out;
  }

  bool get hasSocialLinks => filledSocialLinks.isNotEmpty;

  /// Normalize for open + save. Empty → null.
  static String? normalizeSocialInput(TeacherSocialKind kind, String? raw) {
    var t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    if (kind == TeacherSocialKind.whatsapp) {
      return _normalizeWhatsApp(t);
    }
    if (!t.contains('://')) {
      t = 'https://$t';
    }
    return t;
  }

  static String _normalizeWhatsApp(String input) {
    final lower = input.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return input.trim();
    }
    if (lower.startsWith('wa.me/')) {
      return 'https://$input';
    }
    // Digits / +phone → wa.me
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    var phone = digits.replaceAll('+', '');
    if (phone.isEmpty) return input.trim();
    if (phone.length == 10) phone = '91$phone';
    return 'https://wa.me/$phone';
  }

  static String? _opt(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory TeacherProfileModel.fromMap(
    Map<String, dynamic> map, {
    List<TeacherCertificateModel> certificates = const [],
    List<TeacherAchievementModel> achievements = const [],
    int totalStudents = 0,
    int totalGroups = 0,
    int totalSharedLectures = 0,
  }) {
    return TeacherProfileModel(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      fullName: map['full_name'] as String,
      photoUrl: map['photo_url'] as String?,
      subject: map['subject'] as String,
      bio: map['bio'] as String?,
      qualification: map['qualification'] as String?,
      experienceYears: (map['experience_years'] as num?)?.toInt() ?? 0,
      city: map['city'] as String?,
      state: map['state'] as String?,
      language: _opt(map, 'language'),
      classLevels: _opt(map, 'class_levels'),
      exams: _opt(map, 'exams'),
      linkWebsite: _opt(map, 'link_website'),
      linkYoutube: _opt(map, 'link_youtube'),
      linkInstagram: _opt(map, 'link_instagram'),
      linkFacebook: _opt(map, 'link_facebook'),
      linkLinkedin: _opt(map, 'link_linkedin'),
      linkWhatsapp: _opt(map, 'link_whatsapp'),
      linkTelegram: _opt(map, 'link_telegram'),
      linkX: _opt(map, 'link_x'),
      verificationStatus: TeacherVerificationStatus.values.firstWhere(
        (s) => s.name == map['verification_status'],
        orElse: () => TeacherVerificationStatus.unverified,
      ),
      joinedSince: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      totalStudents: totalStudents,
      totalGroups: totalGroups,
      totalSharedLectures: totalSharedLectures,
      showCertificatesOnProfile: map['show_certificates_on_profile'] == true,
      certificates: certificates,
      achievements: achievements,
    );
  }

  Map<String, dynamic> toMap({required String userId}) {
    return {
      'user_id': userId,
      'full_name': fullName,
      'photo_url': photoUrl,
      'subject': subject,
      'bio': bio,
      'qualification': qualification,
      'experience_years': experienceYears,
      'city': city,
      'state': state,
      'language': language,
      'class_levels': classLevels,
      'exams': exams,
      'link_website': linkWebsite,
      'link_youtube': linkYoutube,
      'link_instagram': linkInstagram,
      'link_facebook': linkFacebook,
      'link_linkedin': linkLinkedin,
      'link_whatsapp': linkWhatsapp,
      'link_telegram': linkTelegram,
      'link_x': linkX,
      'verification_status': verificationStatus.name,
      'show_certificates_on_profile': showCertificatesOnProfile,
    };
  }

  bool get hasAchievements =>
      (showCertificatesOnProfile && certificates.isNotEmpty) ||
      achievements.isNotEmpty;

  /// Certificates safe to show on student-facing UI.
  List<TeacherCertificateModel> get certificatesForStudents =>
      showCertificatesOnProfile ? certificates : const [];

  TeacherProfileModel copyWith({
    String? fullName,
    String? photoUrl,
    String? subject,
    String? bio,
    String? qualification,
    int? experienceYears,
    String? city,
    String? state,
    String? language,
    String? classLevels,
    String? exams,
    String? linkWebsite,
    String? linkYoutube,
    String? linkInstagram,
    String? linkFacebook,
    String? linkLinkedin,
    String? linkWhatsapp,
    String? linkTelegram,
    String? linkX,
    bool clearSocial = false,
    TeacherVerificationStatus? verificationStatus,
    int? totalStudents,
    int? totalGroups,
    int? totalSharedLectures,
    bool? showCertificatesOnProfile,
    List<TeacherCertificateModel>? certificates,
    List<TeacherAchievementModel>? achievements,
  }) {
    return TeacherProfileModel(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      subject: subject ?? this.subject,
      bio: bio ?? this.bio,
      qualification: qualification ?? this.qualification,
      experienceYears: experienceYears ?? this.experienceYears,
      city: city ?? this.city,
      state: state ?? this.state,
      language: language ?? this.language,
      classLevels: classLevels ?? this.classLevels,
      exams: exams ?? this.exams,
      linkWebsite: clearSocial ? linkWebsite : (linkWebsite ?? this.linkWebsite),
      linkYoutube: clearSocial ? linkYoutube : (linkYoutube ?? this.linkYoutube),
      linkInstagram:
          clearSocial ? linkInstagram : (linkInstagram ?? this.linkInstagram),
      linkFacebook:
          clearSocial ? linkFacebook : (linkFacebook ?? this.linkFacebook),
      linkLinkedin:
          clearSocial ? linkLinkedin : (linkLinkedin ?? this.linkLinkedin),
      linkWhatsapp:
          clearSocial ? linkWhatsapp : (linkWhatsapp ?? this.linkWhatsapp),
      linkTelegram:
          clearSocial ? linkTelegram : (linkTelegram ?? this.linkTelegram),
      linkX: clearSocial ? linkX : (linkX ?? this.linkX),
      verificationStatus: verificationStatus ?? this.verificationStatus,
      joinedSince: joinedSince,
      totalStudents: totalStudents ?? this.totalStudents,
      totalGroups: totalGroups ?? this.totalGroups,
      totalSharedLectures: totalSharedLectures ?? this.totalSharedLectures,
      showCertificatesOnProfile:
          showCertificatesOnProfile ?? this.showCertificatesOnProfile,
      certificates: certificates ?? this.certificates,
      achievements: achievements ?? this.achievements,
    );
  }

  /// Replace all social fields from normalized map (empty → null).
  TeacherProfileModel withSocialLinks(Map<TeacherSocialKind, String?> links) {
    return copyWith(
      clearSocial: true,
      linkWebsite: links[TeacherSocialKind.website],
      linkYoutube: links[TeacherSocialKind.youtube],
      linkInstagram: links[TeacherSocialKind.instagram],
      linkFacebook: links[TeacherSocialKind.facebook],
      linkLinkedin: links[TeacherSocialKind.linkedin],
      linkWhatsapp: links[TeacherSocialKind.whatsapp],
      linkTelegram: links[TeacherSocialKind.telegram],
      linkX: links[TeacherSocialKind.x],
    );
  }
}
