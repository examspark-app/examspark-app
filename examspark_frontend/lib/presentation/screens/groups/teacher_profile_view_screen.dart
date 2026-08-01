import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/teacher_profile_header.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Full teacher profile page — opened from Discovery card tap.
/// Shows bio (via TeacherProfileHeader) + all of that
/// teacher's groups with Join/Open buttons.
class TeacherProfileViewScreen extends StatefulWidget {
  final String teacherUserId;

  const TeacherProfileViewScreen({super.key, required this.teacherUserId});

  @override
  State<TeacherProfileViewScreen> createState() => _TeacherProfileViewScreenState();
}

class _TeacherProfileViewScreenState extends State<TeacherProfileViewScreen> {
  TeacherProfileModel? _profile;
  List<GroupModel> _groups = [];
  bool _loading = true;
  String? _joiningGroupId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await GroupsRepository.instance
        .fetchTeacherProfileByUserId(widget.teacherUserId);
    final groups = await GroupsRepository.instance
        .fetchGroupsForTeacher(widget.teacherUserId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _joinGroup(GroupModel group) async {
    if (_joiningGroupId != null) return;
    setState(() => _joiningGroupId = group.id);
    try {
      final updated = await GroupsRepository.instance.toggleMembership(group);
      if (!mounted) return;
      setState(() {
        _joiningGroupId = null;
        _groups = _groups.map((g) => g.id == group.id ? updated : g).toList();
      });
      Navigator.pushNamed(context, '/group_info', arguments: {'groupId': updated.id});
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningGroupId = null);
      AppToast.showSnackBar(context, SnackBar(content: Text('$e')));
    }
  }

  void _openGroup(GroupModel group) {
    Navigator.pushNamed(context, '/group_info', arguments: {'groupId': group.id});
  }

  /// Opens the certificate badge — shows exactly what the teacher chose to
  /// share on their profile (title + review status per certificate).
  void _showCertificatesSheet() {
    final profile = _profile;
    if (profile == null) return;
    final certs = profile.certificatesForStudents;
    if (certs.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificates',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${certs.length} shared by this teacher',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(sheetContext),
                      ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: certs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CertificateTile(certificate: certs[i]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('Profile not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeacherProfileHeader(
              teacher: profile,
              onTapCertificates: _showCertificatesSheet,
            ),
            const SizedBox(height: 24),

            Text(
              'GROUPS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.getSecondaryText(context),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            if (_groups.isEmpty)
              Text(
                'This teacher has no groups yet.',
                style: TextStyle(
                  color: AppTheme.getSecondaryText(context),
                  fontSize: 13,
                ),
              )
            else
              for (final g in _groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.getCardBackground(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.getCardBorder(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                style: TextStyle(
                                  color: AppTheme.getPrimaryText(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${g.studentsCount} students · ${g.sharedLecturesCount} lectures',
                                style: TextStyle(
                                  color: AppTheme.getSecondaryText(context),
                                  fontSize: 12,
                                ),
                              ),
                              if (g.quickInfoChips.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final label in g.quickInfoChips)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.getAccentTint(context),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.accentColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (g.isJoined)
                          OutlinedButton(
                            onPressed: () => _openGroup(g),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.getPrimaryText(context),
                              side: BorderSide(color: AppTheme.getCardBorder(context)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Open'),
                          )
                        else
                          ElevatedButton(
                            onPressed: _joiningGroupId == g.id ? null : () => _joinGroup(g),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _joiningGroupId == g.id
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Join'),
                          ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// One row inside the certificates bottom sheet — title + review status.
class _CertificateTile extends StatelessWidget {
  final TeacherCertificateModel certificate;

  const _CertificateTile({required this.certificate});

  Color _statusColor(BuildContext context) {
    switch (certificate.status) {
      case CertificateStatus.verified:
        return const Color(0xFF2E7D32);
      case CertificateStatus.pending:
        return AppTheme.getSecondaryText(context);
      case CertificateStatus.rejected:
        return const Color(0xFFB71C1C);
    }
  }

  String _statusLabel() {
    switch (certificate.status) {
      case CertificateStatus.verified:
        return 'Verified';
      case CertificateStatus.pending:
        return 'Pending review';
      case CertificateStatus.rejected:
        return 'Rejected';
    }
  }

  IconData _statusIcon() {
    switch (certificate.status) {
      case CertificateStatus.verified:
        return Icons.verified_rounded;
      case CertificateStatus.pending:
        return Icons.hourglass_top_rounded;
      case CertificateStatus.rejected:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(), size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              certificate.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}