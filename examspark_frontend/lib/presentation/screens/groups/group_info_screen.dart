import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/constants/plan_tier_gating.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/models/suggested_teacher_model.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/class_service.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/pinned_content_tile.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/suggested_teacher_card.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/teacher_achievements_section.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/teacher_profile_header.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/buy_plan_sheet.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Group Information screen — inspired by WhatsApp Group Info, but built
/// as ExamSpark's own Study Community pattern: no chat, no messaging,
/// only the teacher's profile + study content.
///
/// Opened when a student taps a teacher's photo or the group name.
/// Placeholder data only — see GroupsRepository.
class GroupInfoScreen extends StatefulWidget {
  final String groupId;

  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  GroupModel? _group;
  List<SuggestedTeacherModel> _suggestedTeachers = [];
  bool _isLoading = true;
  bool _isJoinUpdating = false;
  String? _updatingSuggestedId;
  Map<String, dynamic>? _couponStatus;

  bool get _isGroupTeacher {
    final group = _group;
    final uid = SupabaseClient.instance.currentUser?.id;
    // Owner only (`class_folders.teacher_id`) — never students / other teachers.
    return group?.isOwnedByUser(uid) ?? false;
  }

  Future<void> _togglePin(GroupSharedItem item) async {
    final group = _group;
    if (group == null || !_isGroupTeacher) return;
    final next = !item.isPinned;
    try {
      await ClassService.instance.setSharedItemPinned(
        itemId: item.id,
        isPinned: next,
      );
      if (!mounted) return;
      final updated = GroupSharedItem.sortedForFeed(
        group.recentSharedItems.map(
          (i) => i.id == item.id ? i.copyWith(isPinned: next) : i,
        ),
      );
      setState(() {
        _group = group.copyWith(recentSharedItems: updated);
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(context, 
        SnackBar(content: Text('Could not update pin: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final group = await GroupsRepository.instance.fetchGroupById(widget.groupId);
    final suggested = await GroupsRepository.instance.fetchSuggestedTeachers();
    final couponStatus =
        await GroupsRepository.instance.fetchCouponMembershipStatus(widget.groupId);
    if (!mounted) return;
    setState(() {
      _group = group;
      _suggestedTeachers = suggested.where((t) => t.id != group?.teacher.id).toList();
      _couponStatus = couponStatus;
      _isLoading = false;
    });
    // Student opened channel → daily active heartbeat (teacher dashboard).
    if (group != null && group.isJoined) {
      final uid = SupabaseClient.instance.currentUser?.id;
      if (uid != null && group.teacher.userId != uid) {
        // ignore: unawaited_futures
        ClassService.instance.pingGroupActive(group.id);
      }
    }
  }

  Future<void> _toggleJoin() async {
    final group = _group;
    if (group == null || _isJoinUpdating) return;

    // Spinner set FIRST (before any await) so the button shows busy
    // feedback on the very first tap instead of sitting there doing
    // nothing while the group-limit check round-trips to the server —
    // that gap was making it look unresponsive and inviting a second tap.
    setState(() => _isJoinUpdating = true);

    // Only newly joining is gated by the plan's group limit — leaving is
    // always allowed.
    if (!group.isJoined) {
      final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
      if (!eligibility.allowed) {
        if (!mounted) return;
        setState(() => _isJoinUpdating = false);
        showBuyPlanSheet(context, eligibility);
        return;
      }
    }

    final wasJoined = group.isJoined;
    try {
      final updated = await GroupsRepository.instance.toggleMembership(group);
      if (!mounted) return;
      setState(() {
        _group = updated;
        _isJoinUpdating = false;
      });
      AppToast.showSnackBar(context, 
        SnackBar(content: Text(updated.isJoined ? 'Joined "${updated.name}"' : 'Left "${updated.name}"')),
      );
    } on GroupMembershipException catch (e) {
      if (!mounted) return;
      setState(() => _isJoinUpdating = false);
      if (e.isPendingApproval) {
        AppToast.showSnackBar(context, SnackBar(content: Text(e.message)));
        return;
      }
      if (!wasJoined) {
        final eligibility = await GroupsRepository.instance.canJoinAnotherGroup();
        if (!mounted) return;
        if (!eligibility.allowed || e.isJoinLimit) {
          showBuyPlanSheet(context, eligibility);
          return;
        }
      }
      AppToast.showSnackBar(context, SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleSuggested(SuggestedTeacherModel teacher) async {
    setState(() => _updatingSuggestedId = teacher.id);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _suggestedTeachers = _suggestedTeachers
          .map((t) => t.id == teacher.id ? t.copyWith(isJoined: !t.isJoined) : t)
          .toList();
      _updatingSuggestedId = null;
    });
  }

  /// Opens shared feed item: real Study Workspace for notes/lecture, real quiz
  /// from lecture extras for quiz shares. Viewing is free (teacher paid gen).
  Future<void> _openSharedItem(GroupSharedItem item) async {
    // Coupon path after month: stay in group, but lock content until upgrade.
    final coupon = _couponStatus;
    if (coupon != null &&
        coupon['joined_via_coupon'] == true &&
        coupon['access_active'] != true) {
      if (!mounted) return;
      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text(
            'Coupon free month ended — content is locked. Upgrade a paid plan to unlock. You stay in this group.',
          ),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    if (item.type == GroupSharedItemType.announcement) {
      _showAnnouncementSheet(item);
      return;
    }

    final lectureId = item.lectureId?.trim();
    if (lectureId == null || lectureId.isEmpty) {
      if (!mounted) return;
      AppToast.showSnackBar(context, 
        const SnackBar(
          content: Text('This shared item has no lecture linked yet.'),
        ),
      );
      return;
    }

    if (item.type == GroupSharedItemType.quiz &&
        (item.sharedChips == null || item.sharedChips!.isEmpty)) {
      // Legacy quiz-only shares (before chip picker).
      await _openSharedQuiz(item, lectureId);
      return;
    }

    if (item.type == GroupSharedItemType.notes ||
        item.type == GroupSharedItemType.lecture ||
        item.type == GroupSharedItemType.quiz) {
      if (!mounted) return;
      final msg = (item.body ?? '').trim();
      if (msg.isNotEmpty) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(item.title),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open study'),
              ),
            ],
          ),
        );
        if (open != true || !mounted) return;
      }
      await showStudyWorkspaceFullScreen(
        context,
        lectureId: lectureId,
        title: item.title,
        readOnly: true,
        allowedChips: item.sharedChips,
        initialTabIndex: 0,
      );
      return;
    }

    // Homework / other — show title + body if any.
    _showAnnouncementSheet(item);
  }

  void _showAnnouncementSheet(GroupSharedItem item) {
    final text = (item.body ?? '').trim();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
              Row(
                children: [
                  Icon(Icons.campaign_outlined, color: AppTheme.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                "From ${_group?.teacher.fullName ?? 'your teacher'} • ${_typeLabel(item.type)}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (text.isNotEmpty)
                Text(text, style: Theme.of(context).textTheme.bodyMedium)
              else
                Text(
                  'No message text.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
              const SizedBox(height: 8),
              Text(
                'Students can read only — no comments.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPostAnnouncementSheet() async {
    final group = _group;
    if (group == null || !_isGroupTeacher) return;

    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId != null) {
      try {
        final plan = await SupabaseClient.instance.getPlanTier(userId);
        if (!PlanTierGating.isTeacherLiveRecordUnlocked(plan)) {
          if (!mounted) return;
          AppToast.showSnackBar(
            context,
            SnackBar(
              content: Text(PlanTierGating.teacherShareWorkspaceLockMessage()),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;
        AppToast.showSnackBar(
          context,
          const SnackBar(
            content: Text('Could not verify Teacher plan — post locked.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
        return;
      }
    }

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var pin = false;
    var posting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post announcement',
                        style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Only you can post. Students can read — not comment.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g. Tomorrow class cancelled',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyController,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: 'Message',
                          hintText: 'Write your announcement…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: pin,
                        onChanged: posting
                            ? null
                            : (v) => setModal(() => pin = v),
                        title: const Text('Pin to top'),
                        secondary: Icon(
                          Icons.push_pin_outlined,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: posting
                              ? null
                              : () async {
                                  final title = titleController.text.trim();
                                  final body = bodyController.text.trim();
                                  if (title.isEmpty || body.isEmpty) {
                                    AppToast.showSnackBar(context, 
                                      const SnackBar(
                                        content: Text('Title and message required'),
                                      ),
                                    );
                                    return;
                                  }
                                  setModal(() => posting = true);
                                  try {
                                    final row =
                                        await ClassService.instance.postAnnouncement(
                                      classId: group.id,
                                      title: title,
                                      body: body,
                                      isPinned: pin,
                                    );
                                    if (!mounted) return;
                                    Navigator.pop(ctx);
                                    final item = GroupSharedItem.fromMap(row);
                                    final next = GroupSharedItem.sortedForFeed([
                                      item,
                                      ...group.recentSharedItems,
                                    ]);
                                    setState(() {
                                      _group = group.copyWith(recentSharedItems: next);
                                    });
                                    AppToast.showSnackBar(context, 
                                      const SnackBar(
                                        content: Text('Announcement posted'),
                                      ),
                                    );
                                  } catch (e) {
                                    setModal(() => posting = false);
                                    if (!mounted) return;
                                    AppToast.showSnackBar(context, 
                                      SnackBar(content: Text('Could not post: $e')),
                                    );
                                  }
                                },
                          child: posting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(pin ? 'Post & Pin' : 'Post'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    titleController.dispose();
    bodyController.dispose();
  }

  Future<void> _openSharedQuiz(GroupSharedItem item, String lectureId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final data = await LectureService.instance.fetchQuiz(lectureId);
      final questions = (data['questions'] as List?) ?? [];
      final parsed = questions
          .whereType<Map>()
          .map((q) => MCQQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
      if (!mounted) return;
      Navigator.pop(context);
      if (parsed.isEmpty) {
        AppToast.showSnackBar(context, 
          const SnackBar(
            content: Text(
              'No quiz yet for this lecture. Ask your teacher to generate & share Quiz.',
            ),
          ),
        );
        return;
      }
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getCardBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: MCQQuizView(
                    questions: parsed,
                    lectureId: lectureId,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.showSnackBar(context, 
        SnackBar(content: Text('Could not open quiz: $e')),
      );
    }
  }

  String _typeLabel(GroupSharedItemType type) {
    switch (type) {
      case GroupSharedItemType.lecture:
        return 'Lecture';
      case GroupSharedItemType.homework:
        return 'Homework';
      case GroupSharedItemType.notes:
        return 'Notes';
      case GroupSharedItemType.quiz:
        return 'Quiz';
      case GroupSharedItemType.announcement:
        return 'Announcement';
    }
  }

  void _shareGroup() {
    final group = _group;
    if (group == null) return;
    // Uses the same joinCode-based link format as the Teacher Dashboard's
    // "Share Invite Link" — was previously `group.id` (a UUID), which
    // didn't match the dashboard's link at all.
    final link = AppBrand.inviteJoinUrl(group.joinCode);
    Clipboard.setData(ClipboardData(text: link));
    AppToast.showSnackBar(context, SnackBar(content: Text('Group link copied: $link')));
  }

  void _reportGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
        title: const Text('Report Group'),
        content: const Text('Report this group for inappropriate content or behaviour?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AppToast.showSnackBar(context, 
                const SnackBar(content: Text('Report submitted. Our team will review it.')),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  String? _couponBannerText() {
    final s = _couponStatus;
    if (s == null) return null;
    final via = s['joined_via_coupon'] == true;
    if (!via) return null;
    final active = s['access_active'] == true;
    final urgency = s['in_urgency_window'] == true;
    if (active) {
      return 'Coupon access active — first-month free. Upgrade before it ends to keep full access.';
    }
    if (urgency) {
      return 'Your free access ended. Upgrade within 7 days, or progress/history access may stay restricted.';
    }
    return 'Coupon free access ended. Upgrade your plan to unlock full group content.';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final group = _group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
        body: const Center(child: Text('Group not found')),
      );
    }

    final teacher = group.teacher;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              group.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${group.studentsCount} students · Teacher posts only',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppTheme.getSecondaryText(context),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Top: Teacher profile (channel owner) ----
            TeacherProfileHeader(teacher: teacher),
            if (_couponBannerText() != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getAccentTint(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _couponBannerText()!,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ---- Join (students) / Announce (teacher) ----
            if (!group.isJoined)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isJoinUpdating ? null : _toggleJoin,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_isJoinUpdating ? 'Joining...' : 'Join Group'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              )
            else if (_isGroupTeacher)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showPostAnnouncementSheet,
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Post announcement'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppTheme.getCardBorder(context)),
                ),
                child: Text(
                  'Teacher posts only (notes / quiz / lectures). '
                  'You can read — no messages, no announcements from students.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareGroup,
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: Text(_isGroupTeacher ? 'Share invite' : 'Copy invite link'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reportGroup,
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('Report'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      foregroundColor: AppTheme.getSecondaryText(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ---- Channel feed first (list rhythm, not chat) ----
            if (group.recentSharedItems.isNotEmpty || _isGroupTeacher) ...[
              _buildSectionHeader('CHANNEL FEED'),
              const SizedBox(height: 4),
              Text(
                _isGroupTeacher
                    ? 'You post here. Students only read. Pin keeps post on top.'
                    : 'Teacher posts only. Tap to read — no reply / no write.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
              ),
              const SizedBox(height: 8),
              if (group.recentSharedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _isGroupTeacher
                        ? 'No posts yet. Share a lecture or Post announcement (+ Pin).'
                        : 'No posts from teacher yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                  ),
                )
              else
                for (final item in GroupSharedItem.sortedForFeed(group.recentSharedItems))
                  PinnedContentTile(
                    item: item,
                    onTap: () => _openSharedItem(item),
                    onTogglePin: _isGroupTeacher ? () => _togglePin(item) : null,
                  ),
              const SizedBox(height: 28),
            ],

            // ---- Group Information ----
            _buildSectionHeader('GROUP INFORMATION'),
            const SizedBox(height: 12),
            _buildInfoCard(context, group),
            const SizedBox(height: 28),

          

            // ---- Leave (students only — teacher owns the group) ----
            if (group.isJoined && !_isGroupTeacher) ...[
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _isJoinUpdating ? null : _toggleJoin,
                  icon: const Icon(Icons.exit_to_app, size: 15),
                  label: Text(
                    _isJoinUpdating ? 'Updating...' : 'Leave Group',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ---- Suggested Teachers ----
            if (_suggestedTeachers.isNotEmpty) ...[
              _buildSectionHeader('SUGGESTED TEACHERS'),
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestedTeachers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final t = _suggestedTeachers[index];
                    return SuggestedTeacherCard(
                      teacher: t,
                      onJoinToggle: () => _toggleSuggested(t),
                      isUpdating: _updatingSuggestedId == t.id,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.getSecondaryText(context), letterSpacing: 1),
    );
  }

  Widget _buildInfoCard(BuildContext context, GroupModel group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(icon: Icons.people_outline, label: '${group.studentsCount} students'),
              const SizedBox(width: 20),
              _StatItem(icon: Icons.menu_book_outlined, label: '${group.sharedLecturesCount} lectures'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.getSecondaryText(context)),
              const SizedBox(width: 6),
              Text(
                'Created ${_formatDate(group.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context)),
              ),
            ],
          ),
          if (group.rules.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 1, color: AppTheme.getCardBorder(context)),
            const SizedBox(height: 16),
            Text('Rules', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final rule in group.rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(rule, style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ),
          ],
          if (group.allowedContent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Allowed Content', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.allowedContent
                  .map(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.getAccentTint(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(c, style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.w500)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.getSecondaryText(context)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context))),
      ],
    );
  }
}
