import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/plan_tier_gating.dart';
import 'package:examspark_frontend/core/models/teacher_library_item.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';
import 'package:examspark_frontend/presentation/widgets/share_to_group_sheet.dart';

/// Teacher Dashboard — My Library (reusable content bank, free re-share).
class TeacherLibrarySection extends StatefulWidget {
  const TeacherLibrarySection({super.key});

  @override
  State<TeacherLibrarySection> createState() => _TeacherLibrarySectionState();
}

class _TeacherLibrarySectionState extends State<TeacherLibrarySection> {
  List<TeacherLibraryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ClassService.instance.fetchTeacherLibrary();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  Future<bool> _ensureTeacherPlan() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return false;
    try {
      final plan = await SupabaseClient.instance.getPlanTier(userId);
      if (PlanTierGating.isTeacherLiveRecordUnlocked(plan)) return true;
    } catch (_) {}
    if (!mounted) return false;
    AppToast.showSnackBar(
      context,
      SnackBar(
        content: Text(PlanTierGating.teacherShareWorkspaceLockMessage()),
        backgroundColor: const Color(0xFFC62828),
      ),
    );
    return false;
  }

  Future<void> _shareToAnotherGroup(TeacherLibraryItem item) async {
    if (!await _ensureTeacherPlan()) return;
    if (!mounted) return;
    await showShareToGroupSheet(
      context,
      lectureId: item.lectureId,
      lectureTitle: item.title,
    );
    if (!mounted) return;
    await _load();
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'My Library (share bank)',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        Text(
          'Teacher share bank — not the personal Library tab. '
          'Share recorded lectures to groups here (free link). '
          'Same lecture → same group only once.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.getSecondaryText(context),
              ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items.isEmpty)
          Text(
            'No lectures yet — Record a lecture to fill your Teacher Library.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length > 12 ? 12 : _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppTheme.getCardBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((item.subject ?? '').trim().isNotEmpty) item.subject!,
                        if (_dateLabel(item.createdAt).isNotEmpty)
                          _dateLabel(item.createdAt),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.sharedToLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.accentColor,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/study_workspace',
                              arguments: {
                                'lectureId': item.lectureId,
                                'title': item.title,
                                'subject': item.subject,
                              },
                            );
                          },
                          child: const Text('Open'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _shareToAnotherGroup(item),
                          icon: const Icon(Icons.share_outlined, size: 16),
                          label: const Text('Share to group'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        if (!_loading && _items.length > 12)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing latest 12. Personal full list = Library tab (no share). '
              'Share only from this My Library section.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
          ),
      ],
    );
  }
}
