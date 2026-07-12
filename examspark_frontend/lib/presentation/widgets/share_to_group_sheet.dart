import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

enum _ShareContentType { lecture, notes, quiz }

/// Founder-locked Jul 12, 2026: only lectures captured via a real mic
/// recording may be shared into a Group (fake-teacher prevention) — the
/// caller (`StudyWorkspace`) is responsible for only offering this sheet
/// when `lecture.source_type == 'recorded'`.
Future<void> showShareToGroupSheet(
  BuildContext context, {
  required String lectureId,
  required String lectureTitle,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShareToGroupSheet(lectureId: lectureId, lectureTitle: lectureTitle),
  );
}

class _ShareToGroupSheet extends StatefulWidget {
  final String lectureId;
  final String lectureTitle;

  const _ShareToGroupSheet({required this.lectureId, required this.lectureTitle});

  @override
  State<_ShareToGroupSheet> createState() => _ShareToGroupSheetState();
}

class _ShareToGroupSheetState extends State<_ShareToGroupSheet> {
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _selectedClassId;
  _ShareContentType _contentType = _ShareContentType.lecture;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final classes = await ClassService.instance.getTeacherClasses();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _loading = false;
      if (classes.isNotEmpty) _selectedClassId = classes.first['id'] as String?;
    });
  }

  Future<void> _share() async {
    final classId = _selectedClassId;
    if (classId == null) return;
    setState(() => _sharing = true);
    try {
      await ClassService.instance.shareItemToGroup(
        classId: classId,
        type: _contentType.name,
        title: widget.lectureTitle,
        lectureId: widget.lectureId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared to group')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share to Group', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Only real recordings can be shared — every group\'s content stays genuinely from its own teacher.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_classes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Create a group first from the Teacher Dashboard.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else ...[
              Text('Share as', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _typeChip(_ShareContentType.lecture, 'Lecture'),
                  _typeChip(_ShareContentType.notes, 'Notes'),
                  _typeChip(_ShareContentType.quiz, 'Quiz'),
                ],
              ),
              const SizedBox(height: 16),
              Text('Select group', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final c in _classes)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: c['id'] as String,
                  groupValue: _selectedClassId,
                  onChanged: (v) => setState(() => _selectedClassId = v),
                  title: Text(c['name'] as String? ?? 'Class'),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sharing ? null : _share,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                  ),
                  child: _sharing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Share'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeChip(_ShareContentType type, String label) {
    final selected = _contentType == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _contentType = type),
    );
  }
}
