import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide SupabaseClient;
import 'package:examspark_frontend/core/constants/class_levels.dart';
import 'package:examspark_frontend/core/constants/custom_field_option.dart';
import 'package:examspark_frontend/core/constants/exam_boards.dart';
import 'package:examspark_frontend/core/constants/teaching_languages.dart';
import 'package:examspark_frontend/core/constants/subjects.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/suggested_teacher_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/buy_plan_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// WhatsApp-style teacher discovery — search + filters + match-score ranking.
/// Filters: City · Subject · Class · Board. Displays teacher profiles along with their active groups/batches.
class TeacherDiscoveryScreen extends StatefulWidget {
  const TeacherDiscoveryScreen({super.key, this.embedded = false});

  /// When true, used as Groups tab sub-view (no Scaffold app bar).
  final bool embedded;

  @override
  State<TeacherDiscoveryScreen> createState() => _TeacherDiscoveryScreenState();
}

class _TeacherDiscoveryScreenState extends State<TeacherDiscoveryScreen> {
  final _search = TextEditingController();
  final _locationFilter = TextEditingController();
  final Set<String> _filterSubjects = {};
  final Set<String> _filterClasses = {};
  final Set<String> _filterExams = {};
  final Set<String> _filterLanguages = {};
  String? _customSubject;
  List<SuggestedTeacherModel> _teachers = [];
  bool _loading = true;
  bool _filtersActive = false;
  String? _joiningId;
  RealtimeChannel? _channel;
  Timer? _realtimeDebounce;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _searchDebounce?.cancel();
    final ch = _channel;
    if (ch != null) {
      unawaited(SupabaseClient.instance.client.removeChannel(ch));
    }
    _search.dispose();
    _locationFilter.dispose();
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      final client = SupabaseClient.instance.client;
      final channel = client.channel('discover-teachers');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'teacher_profiles',
            callback: (_) => _scheduleRealtimeReload(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'class_folders',
            callback: (_) => _scheduleRealtimeReload(),
          )
          .subscribe();
      _channel = channel;
    } catch (_) {
      // Realtime optional — manual search / pull still works.
    }
  }

  void _scheduleRealtimeReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _load(silent: true);
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load();
    });
  }

  bool get _hasActiveFilters =>
      _filterSubjects.isNotEmpty ||
      _locationFilter.text.trim().isNotEmpty ||
      _filterClasses.isNotEmpty ||
      _filterExams.isNotEmpty ||
      _filterLanguages.isNotEmpty;

  String get _subjectChipLabel {
    if (_filterSubjects.isEmpty) return 'Subject';
    if (_filterSubjects.length == 1) {
      return 'Subject: ${_filterSubjects.first}';
    }
    return 'Subject: ${_filterSubjects.length} selected';
  }

  String get _locationChipLabel {
    final t = _locationFilter.text.trim();
    if (t.isEmpty) return 'City';
    return 'City: $t';
  }

  String get _classChipLabel {
    if (_filterClasses.isEmpty) return 'Class';
    if (_filterClasses.length == 1) {
      return 'Class: ${_filterClasses.first}';
    }
    return 'Class: ${_filterClasses.length} selected';
  }

  String get _boardChipLabel {
    if (_filterExams.isEmpty) return 'Board';
    if (_filterExams.length == 1) {
      return 'Board: ${_filterExams.first}';
    }
    return 'Board: ${_filterExams.length} selected';
  }
String get _languageChipLabel {
    if (_filterLanguages.isEmpty) return 'Language';
    if (_filterLanguages.length == 1) {
      return 'Language: ${_filterLanguages.first}';
    }
    return 'Language: ${_filterLanguages.length} selected';
  }
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _filtersActive = _hasActiveFilters;
      });
    } else if (mounted) {
      setState(() => _filtersActive = _hasActiveFilters);
    }
    final subjects = [
      ..._filterSubjects.where((s) => s != CustomFieldOption.label),
      if (_filterSubjects.contains(CustomFieldOption.label) &&
          (_customSubject ?? '').trim().isNotEmpty)
        _customSubject!.trim(),
    ];
    final list = await GroupsRepository.instance.discoverTeachers(
      query: _search.text.trim(),
      filterSubjects: subjects,
      filterLocation: _locationFilter.text.trim(),
      filterClassLevels: _filterClasses.toList(),
      filterExams: _filterExams.toList(),
      filterLanguages: _filterLanguages.toList(),
    );
    if (!mounted) return;
    setState(() {
      _teachers = list;
      _loading = false;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _filterSubjects.clear();
      _customSubject = null;
      _locationFilter.clear();
      _filterClasses.clear();
      _filterExams.clear();
      _filterLanguages.clear();
    });
    _load();
  }

  Future<void> _pickSubjects() async {
    final draft = Set<String>.from(_filterSubjects);
    final customCtrl = TextEditingController(text: _customSubject ?? '');
    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModal) {
              return Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.paddingOf(ctx).bottom,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by subject',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Multi-select — teacher matches if they teach any selected.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(ctx),
                          ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final s in [
                            ...kDiscoverSubjectOptions,
                            CustomFieldOption.label,
                          ])
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: draft.contains(s),
                              title: Text(s),
                              onChanged: (v) {
                                setModal(() {
                                  if (v == true) {
                                    draft.add(s);
                                  } else {
                                    draft.remove(s);
                                  }
                                });
                              },
                            ),
                          if (draft.contains(CustomFieldOption.label))
                            TextField(
                              controller: customCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Custom subject',
                                hintText: 'e.g. Accountancy, Botany',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            draft.clear();
                            customCtrl.clear();
                            Navigator.pop(ctx, true);
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      if (ok == true && mounted) {
        setState(() {
          _filterSubjects
            ..clear()
            ..addAll(draft);
          if (draft.contains(CustomFieldOption.label)) {
            final t = customCtrl.text.trim();
            _customSubject = t.isEmpty ? null : t;
          } else {
            _customSubject = null;
          }
        });
        await _load();
      }
    } finally {
      customCtrl.dispose();
    }
  }

  Future<void> _pickLocation() async {
    final ctrl = TextEditingController(text: _locationFilter.text);
    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by city / state',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Typos OK (fuzzy match) — e.g. kolkta → Kolkata',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(ctx),
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => Navigator.pop(ctx, true),
                    decoration: const InputDecoration(
                      hintText: 'City or state',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          ctrl.clear();
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (ok == true && mounted) {
        setState(() => _locationFilter.text = ctrl.text.trim());
        await _load();
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _pickClass() async {
    final draft = Set<String>.from(_filterClasses);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by class',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in ClassLevels.all)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: draft.contains(c),
                            title: Text(c),
                            onChanged: (v) {
                              setModal(() {
                                if (v == true) {
                                  draft.add(c);
                                } else {
                                  draft.remove(c);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          draft.clear();
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok == true && mounted) {
      setState(() {
        _filterClasses
          ..clear()
          ..addAll(draft);
      });
      await _load();
    }
  }

  Future<void> _pickBoard() async {
    final draft = Set<String>.from(_filterExams);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by board / exam',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in ExamBoards.all)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: draft.contains(e),
                            title: Text(e),
                            onChanged: (v) {
                              setModal(() {
                                if (v == true) {
                                  draft.add(e);
                                } else {
                                  draft.remove(e);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          draft.clear();
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok == true && mounted) {
      setState(() {
        _filterExams
          ..clear()
          ..addAll(draft);
      });
      await _load();
    }
  }
Future<void> _pickLanguage() async {
    final draft = Set<String>.from(_filterLanguages);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20, 12, 20, 20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by language',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.45),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final l in TeachingLanguages.all)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: draft.contains(l),
                            title: Text(l),
                            onChanged: (v) {
                              setModal(() {
                                if (v == true) {
                                  draft.add(l);
                                } else {
                                  draft.remove(l);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          draft.clear();
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok == true && mounted) {
      setState(() {
        _filterLanguages
          ..clear()
          ..addAll(draft);
      });
      await _load();
    }
  }
  Future<void> _openTeacherGroup(SuggestedTeacherModel t) async {
    final uid = t.userId;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        const SnackBar(content: Text('Could not open group')),
      );
      return;
    }
    final groupId =
        await GroupsRepository.instance.fetchOpenGroupIdForTeacher(uid);
    if (!mounted) return;
    if (groupId == null || groupId.isEmpty) {
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text(
            'Teacher ne abhi group create nahi kiya — invite / coupon se try karo.',
          ),
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/group_info',
      arguments: {'groupId': groupId},
    );
  }
Future<void> _openTeacherProfile(SuggestedTeacherModel t) async {
    final uid = t.userId;
    if (uid == null || uid.isEmpty) return;

    var groups = await GroupsRepository.instance.fetchGroupsForTeacher(uid);
    if (!mounted) return;

    if (groups.isEmpty) {
      AppToast.showSnackBar(
        context,
        const SnackBar(content: Text('Teacher ne abhi group create nahi kiya.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20, 16, 20, 20 + MediaQuery.paddingOf(ctx).bottom,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.name} — Select a group to join',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final g = groups[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.getCardBorder(ctx)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${g.studentsCount} students',
                                      style: TextStyle(
                                        color: AppTheme.getSecondaryText(ctx),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (g.isJoined)
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.pushNamed(
                                      context, '/group_info',
                                      arguments: {'groupId': g.id},
                                    );
                                  },
                                  child: const Text('Open'),
                                )
                              else
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _joinSpecificGroup(g, t);
                                  },
                                  child: const Text('Join'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _joinSpecificGroup(GroupModel group, SuggestedTeacherModel t) async {
    if (_joiningId != null) return;
    setState(() => _joiningId = t.id);

    final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
    if (!eligibility.allowed) {
      if (!mounted) return;
      setState(() => _joiningId = null);
      showBuyPlanSheet(context, eligibility);
      return;
    }

    try {
      final updated = await GroupsRepository.instance.toggleMembership(group);
      if (!mounted) return;
      setState(() {
        _joiningId = null;
        _teachers = _teachers
            .map((x) => x.id == t.id ? x.copyWith(isJoined: true) : x)
            .toList();
      });
      Navigator.pushNamed(
        context, '/group_info',
        arguments: {'groupId': updated.id},
      );
    } on GroupMembershipException catch (e) {
      if (!mounted) return;
      setState(() => _joiningId = null);
      if (e.isJoinLimit) {
        final el = await GroupsRepository.instance.canJoinAnotherGroup();
        if (!mounted) return;
        showBuyPlanSheet(context, el);
        return;
      }
      AppToast.showSnackBar(context, SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningId = null);
      AppToast.showSnackBar(context, SnackBar(content: Text('$e')));
    }
  }
  Future<void> _join(SuggestedTeacherModel t) async {
    if (_joiningId != null) return;
    setState(() => _joiningId = t.id);

    final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
    if (!eligibility.allowed) {
      if (!mounted) return;
      setState(() => _joiningId = null);
      showBuyPlanSheet(context, eligibility);
      return;
    }

    try {
      final group = await GroupsRepository.instance.joinFirstOpenGroupForTeacher(
        teacherProfileId: t.id,
        teacherUserId: t.userId,
      );
      if (!mounted) return;
      setState(() {
        _joiningId = null;
        _teachers = _teachers
            .map((x) => x.id == t.id ? x.copyWith(isJoined: true) : x)
            .toList();
      });
      if (group != null && group.id.isNotEmpty) {
        Navigator.pushNamed(
          context,
          '/group_info',
          arguments: {'groupId': group.id},
        );
      } else {
        AppToast.showSnackBar(
          context,
          const SnackBar(
            content: Text(
              'Teacher ne abhi group create nahi kiya — invite / coupon se try karo.',
            ),
          ),
        );
      }
    } on GroupMembershipException catch (e) {
      if (!mounted) return;
      setState(() => _joiningId = null);
      if (e.isJoinLimit) {
        final el = await GroupsRepository.instance.canJoinAnotherGroup();
        if (!mounted) return;
        showBuyPlanSheet(context, el);
        return;
      }
      AppToast.showSnackBar(context, SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _joiningId = null);
      AppToast.showSnackBar(context, SnackBar(content: Text('$e')));
    }
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        selected: active,
        onPressed: onTap,
        onDeleted: active ? onClear : null,
        deleteIcon: active
            ? const Icon(Icons.close, size: 16)
            : null,
        selectedColor: AppTheme.getAccentTint(context),
        checkmarkColor: AppTheme.accentColor,
        side: BorderSide(
          color: active
              ? AppTheme.accentColor
              : AppTheme.getCardBorder(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search teachers, subject, city, state (typos OK)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  _load();
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            children: [
              _filterChip(
                label: _locationChipLabel,
                active: _locationFilter.text.trim().isNotEmpty,
                onTap: _pickLocation,
                onClear: () {
                  setState(() => _locationFilter.clear());
                  _load();
                },
              ),
              _filterChip(
                label: _subjectChipLabel,
                active: _filterSubjects.isNotEmpty,
                onTap: _pickSubjects,
                onClear: () {
                  setState(() {
                    _filterSubjects.clear();
                    _customSubject = null;
                  });
                  _load();
                },
              ),
              _filterChip(
                label: _classChipLabel,
                active: _filterClasses.isNotEmpty,
                onTap: _pickClass,
                onClear: () {
                  setState(() => _filterClasses.clear());
                  _load();
                },
              ),
              _filterChip(
                label: _boardChipLabel,
                active: _filterExams.isNotEmpty,
                onTap: _pickBoard,
                onClear: () {
                  setState(() => _filterExams.clear());
                  _load();
                },
              ),
              _filterChip(
                label: _languageChipLabel,
                active: _filterLanguages.isNotEmpty,
                onTap: _pickLanguage,
                onClear: () {
                  setState(() => _filterLanguages.clear());
                  _load();
                },
              ),
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: const Text('Clear all'),
                    avatar: const Icon(Icons.filter_alt_off, size: 16),
                    onPressed: _clearAllFilters,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _teachers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _filtersActive || _search.text.trim().isNotEmpty
                                  ? 'No teachers match these filters — try adjusting your search'
                                  : 'No teachers with a group yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.getSecondaryText(context),
                              ),
                            ),
                            if (_filtersActive) ...[
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _clearAllFilters,
                                child: const Text('Clear all filters'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _teachers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final t = _teachers[i];
                          return _TeacherDiscoverCard(
                            teacher: t,
                            joining: _joiningId == t.id,
                            onJoin: t.isJoined ? null : () => _openTeacherProfile(t),
                            onOpen: t.isJoined
                                ? () => _openTeacherProfile(t)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Discover Teachers & Batches')),
      body: body,
    );
  }
}

class _TeacherDiscoverCard extends StatelessWidget {
  final SuggestedTeacherModel teacher;
  final bool joining;
  final VoidCallback? onJoin;
  final VoidCallback? onOpen;

  const _TeacherDiscoverCard({
    required this.teacher,
    required this.joining,
    this.onJoin,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final loc = [
      if ((teacher.city ?? '').isNotEmpty) teacher.city!,
      if ((teacher.state ?? '').isNotEmpty) teacher.state!,
    ].join(', ');

    // Extract groups/classes list if available in teacher model
    final groupsList = (teacher.groups ?? const []);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.getAccentTint(context),
                backgroundImage: teacher.photoUrl != null
                    ? NetworkImage(teacher.photoUrl!)
                    : null,
                child: teacher.photoUrl == null
                    ? Text(
                        teacher.name.isNotEmpty
                            ? teacher.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              // Match Score Badge if available
              if (teacher.matchScore != null)
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${teacher.matchScore}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  teacher.subject,
                  style: TextStyle(
                    color: AppTheme.getSecondaryText(context),
                    fontSize: 13,
                  ),
                ),
                if (loc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    loc,
                    style: TextStyle(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 12,
                    ),
                  ),
                ],
                // Display Teacher's Groups / Batches from class_folders
                if (groupsList.isNotEmpty) ...[
                  const SizedBox(height: 6),
                 Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: groupsList.map((g) {
                      String groupName = 'Group';
                      String? groupSub;
                      if (g is Map) {
                        groupName =
                            (g['name'] ?? g['subject'] ?? 'Group').toString();
                        final cl = g['class_level']?.toString();
                        if (cl != null && cl.trim().isNotEmpty) {
                          groupSub = cl.trim();
                        }
                      } else if (g is String) {
                        groupName = g;
                      }
                      final label =
                          groupSub != null ? '$groupName · $groupSub' : groupName;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.getCardBorder(context)),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getSecondaryText(context),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                ],
                if (teacher.matchesLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.getAccentTint(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      teacher.matchesLabel,
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (teacher.studentCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${teacher.studentCount} students',
                    style: TextStyle(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (teacher.isJoined)
                TextButton(
                  onPressed: onOpen,
                  child: Text(
                    'Open',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: joining ? null : onJoin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(60, 36),
                  ),
                  child: joining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}