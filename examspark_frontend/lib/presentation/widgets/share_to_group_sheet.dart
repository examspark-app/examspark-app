import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/plan_tier_gating.dart';
import 'package:examspark_frontend/core/constants/share_chip_catalog.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Founder-locked Jul 12, 2026: only lectures captured via a real mic
/// recording may be shared into a Group (fake-teacher prevention).
/// Jul 25: Teacher ₹2,999 · chips picker · optional message + pin.
/// Share entry: Teacher Dashboard → My Library (not personal Workspace).
Future<void> showShareToGroupSheet(
  BuildContext context, {
  required String lectureId,
  required String lectureTitle,
}) async {
  final userId = SupabaseClient.instance.currentUser?.id;
  if (userId != null) {
    try {
      final plan = await SupabaseClient.instance.getPlanTier(userId);
      if (!PlanTierGating.isTeacherLiveRecordUnlocked(plan)) {
        if (context.mounted) {
          AppToast.showSnackBar(
            context,
            SnackBar(
              content: Text(PlanTierGating.teacherShareWorkspaceLockMessage()),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
        return;
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.showSnackBar(
          context,
          const SnackBar(
            content: Text('Could not verify Teacher plan — share locked.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
      return;
    }
  }

  if (!context.mounted) return;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ShareToGroupSheet(
        lectureId: lectureId,
        lectureTitle: lectureTitle,
      ),
    ),
  );
}

class _ShareToGroupSheet extends StatefulWidget {
  final String lectureId;
  final String lectureTitle;

  const _ShareToGroupSheet({
    required this.lectureId,
    required this.lectureTitle,
  });

  @override
  State<_ShareToGroupSheet> createState() => _ShareToGroupSheetState();
}

class _ShareToGroupSheetState extends State<_ShareToGroupSheet> {
  List<Map<String, dynamic>> _classes = [];
  List<String> _availableChips = [];
  final Set<String> _selectedChips = {};
  final _messageController = TextEditingController();
  bool _loading = true;
  String? _selectedClassId;
  bool _pinToTop = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ClassService.instance.getTeacherClasses(),
      ClassService.instance.listShareableChips(widget.lectureId),
    ]);
    final classes = results[0] as List<Map<String, dynamic>>;
    final chips = results[1] as List<String>;

    // Hide groups that already have this lecture linked (unique class+lecture).
    final alreadyShared = <String>{};
    try {
      final rows = await SupabaseClient.instance.client
          .from('group_shared_items')
          .select('class_id')
          .eq('lecture_id', widget.lectureId);
      for (final raw in List<Map<String, dynamic>>.from(rows as List)) {
        final id = raw['class_id'] as String?;
        if (id != null) alreadyShared.add(id);
      }
    } catch (_) {}

    final available = classes.where((c) {
      final id = c['id'] as String?;
      return id != null && !alreadyShared.contains(id);
    }).toList();

    if (!mounted) return;
    setState(() {
      _classes = available;
      _availableChips = chips;
      _selectedChips
        ..clear()
        ..addAll(chips); // default = All generated
      _loading = false;
      if (available.isNotEmpty) {
        _selectedClassId = available.first['id'] as String?;
      } else {
        _selectedClassId = null;
      }
    });
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      _selectedChips.clear();
      if (selectAll) _selectedChips.addAll(_availableChips);
    });
  }

  Future<void> _share() async {
    final classId = _selectedClassId;
    if (classId == null) return;
    if (_selectedChips.isEmpty) {
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text('Select at least one chip to share'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      final message = _messageController.text.trim();
      // Feed type stays "lecture"; chips control what students can open.
      // Ask AI is never shareable.
      final chips = _selectedChips
          .where((c) => c.trim().toLowerCase() != 'ask_ai')
          .toList();
      await ClassService.instance.shareItemToGroup(
        classId: classId,
        type: 'lecture',
        title: widget.lectureTitle,
        lectureId: widget.lectureId,
        body: message.isEmpty ? null : message,
        isPinned: _pinToTop,
        sharedChips: chips,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text('Shared to group (free — no new AI / no credits)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      AppToast.showSnackBar(
        context,
        SnackBar(
          content: Text(
            msg.contains('Already shared')
                ? 'Already shared here'
                : 'Could not share: $msg',
          ),
          backgroundColor: msg.contains('Already shared')
              ? const Color(0xFFC62828)
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _availableChips.isNotEmpty &&
        _selectedChips.length == _availableChips.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share to Group',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'From Teacher Dashboard → My Library. '
                'Free link (no regenerate). Optional message + pin for students.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  maxLength: 500,
                  enabled: !_sharing,
                  decoration: InputDecoration(
                    labelText: 'Message (optional)',
                    hintText: 'e.g. Revise before Friday test',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadius),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'What to share',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_availableChips.isEmpty)
                  Text(
                    'No generated chips yet. Open Study Workspace, generate '
                    'Notes / Quiz / Flashcards / etc., then share again.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allSelected,
                    tristate: false,
                    onChanged: (v) => _toggleAll(v ?? false),
                    title: const Text('All generated chips'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  for (final chip in _availableChips)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _selectedChips.contains(chip),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedChips.add(chip);
                          } else {
                            _selectedChips.remove(chip);
                          }
                        });
                      },
                      title: Text(
                        ShareChipCatalog.labelFor(chip) ?? chip,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
                const SizedBox(height: 12),
                if (_classes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No groups left to share — already shared everywhere, '
                      'or create a group first from the Teacher Dashboard.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else ...[
                  Text(
                    'Select group',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  for (final c in _classes)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: c['id'] as String,
                      groupValue: _selectedClassId,
                      onChanged: (v) => setState(() => _selectedClassId = v),
                      title: Text(c['name'] as String? ?? 'Class'),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _pinToTop,
                    onChanged: (v) => setState(() => _pinToTop = v),
                    title: const Text('Pin to top'),
                    subtitle: Text(
                      'Important shares stay above newer posts',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    secondary: Icon(
                      Icons.push_pin_outlined,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_sharing ||
                              _availableChips.isEmpty ||
                              _selectedChips.isEmpty)
                          ? null
                          : _share,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.borderRadius),
                        ),
                      ),
                      child: _sharing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_pinToTop ? 'Share & Pin' : 'Share'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
