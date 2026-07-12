/// Review state of an uploaded certificate. `pending` until the Phase 5 AI
/// real/fake document check runs; `rejected` surfaces a "Contact Support"
/// action in the edit sheet instead of silently blocking the teacher.
enum CertificateStatus { pending, verified, rejected }

/// One uploaded proof of qualification (certificate, degree, ID proof).
///
/// Backed by the Supabase `teacher_certificates` table (Phase 4). `imageUrl`
/// maps to the `file_url` column — stays null until Phase 5 wires Cloudflare
/// R2 upload; only the certificate's title + review `status` are persisted
/// to Postgres today (metadata only, per the storage rule).
class TeacherCertificateModel {
  final String id;
  final String title;
  final String? imageUrl;
  final CertificateStatus status;
  final DateTime uploadedAt;

  const TeacherCertificateModel({
    required this.id,
    required this.title,
    this.imageUrl,
    this.status = CertificateStatus.pending,
    required this.uploadedAt,
  });

  factory TeacherCertificateModel.fromMap(Map<String, dynamic> map) {
    return TeacherCertificateModel(
      id: map['id'] as String,
      title: map['title'] as String,
      imageUrl: map['file_url'] as String?,
      status: CertificateStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => CertificateStatus.pending,
      ),
      uploadedAt: map['uploaded_at'] != null
          ? DateTime.parse(map['uploaded_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({required String teacherId}) {
    return {
      'teacher_id': teacherId,
      'title': title,
      'file_url': imageUrl,
      'status': status.name,
    };
  }

  TeacherCertificateModel copyWith({
    String? title,
    String? imageUrl,
    CertificateStatus? status,
  }) {
    return TeacherCertificateModel(
      id: id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      uploadedAt: uploadedAt,
    );
  }
}
