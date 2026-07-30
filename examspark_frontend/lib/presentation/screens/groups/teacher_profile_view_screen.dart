import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/teacher_achievements_section.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/teacher_profile_header.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Full teacher profile page — opened from Discovery card tap.
/// Shows bio/achievements (via TeacherProfileHeader) + all of that
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

  static const _bg = Color(0xFF000000);
  static const _card = Color(0xFF121212);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFFA8A8A8);
  static const _borderSubtle = Color(0x1FFFFFFF);

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: _textPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('Profile not found', style: TextStyle(color: _textPrimary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPrimary,
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
            TeacherProfileHeader(teacher: profile),
            const SizedBox(height: 24),
            TeacherAchievementsSection(
              certificates: profile.certificatesForStudents,
              achievements: profile.achievements,
            ),
            if (profile.hasAchievements) const SizedBox(height: 24),

            const Text(
              'GROUPS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _textSecondary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            if (_groups.isEmpty)
              const Text(
                'This teacher has no groups yet.',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              )
            else
              for (final g in _groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${g.studentsCount} students · ${g.sharedLecturesCount} lectures',
                                style: const TextStyle(color: _textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (g.isJoined)
                          OutlinedButton(
                            onPressed: () => _openGroup(g),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textPrimary,
                              side: const BorderSide(color: _borderSubtle),
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