import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/models/suggested_teacher_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/pinned_content_tile.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/suggested_teacher_card.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/teacher_achievements_section.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/teacher_profile_header.dart';
import 'package:examspark_frontend/presentation/screens/recording/widgets/extra_features_views.dart';
import 'package:examspark_frontend/presentation/widgets/ask_ai_selectable_text.dart';
import 'package:examspark_frontend/presentation/widgets/buy_plan_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final group = await GroupsRepository.instance.fetchGroupById(widget.groupId);
    final suggested = await GroupsRepository.instance.fetchSuggestedTeachers();
    if (!mounted) return;
    setState(() {
      _group = group;
      _suggestedTeachers = suggested.where((t) => t.id != group?.teacher.id).toList();
      _isLoading = false;
    });
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

    final updated = await GroupsRepository.instance.toggleMembership(group);
    if (!mounted) return;
    setState(() {
      _group = updated;
      _isJoinUpdating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated.isJoined ? 'Joined "${updated.name}"' : 'Left "${updated.name}"')),
    );
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

  /// Opens a shared feed item — an interactive MCQ quiz for `quiz` items,
  /// a simple read-only viewer sheet for everything else. Real quiz/notes
  /// content lives in R2 (`group_shared_items.r2_path` — metadata-only
  /// Postgres rule); the sample questions/placeholder text here are a UI
  /// preview until Phase 5 wires the real fetch.
  void _openSharedItem(GroupSharedItem item) {
    if (item.type == GroupSharedItemType.quiz) {
      showModalBottomSheet(
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                        child: Text(item.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(child: MCQQuizView(questions: _sampleQuizQuestions())),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              Text(item.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Shared by ${_group?.teacher.fullName ?? 'your teacher'} • ${_typeLabel(item.type)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(color: AppTheme.getCardBorder(context)),
                ),
                child: AskAiSelectableText(
                  text: 'Full content viewing connects once Cloudflare R2 storage is wired (Phase 5) — '
                      'this preview just confirms the item shared correctly.',
                  style: Theme.of(context).textTheme.bodySmall,
                  onAskAi: _askAiAboutSharedContent,
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

  /// "Select text → Ask AI" entry point for shared Group content
  /// (`AskAiSelectableText`). Group items don't have a `lectureId` wired on
  /// the client model yet, so this shows the same "connects once Phase 5
  /// RAG is wired" placeholder used elsewhere on this screen instead of the
  /// lecture-specific `RAGChatModal` — the selection UX itself is real and
  /// ready for when the backend fetch lands.
  void _askAiAboutSharedContent(String selectedText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
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
                    const Icon(Icons.auto_awesome, size: 18),
                    const SizedBox(width: 8),
                    Text('Ask AI', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardBackground(context),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    border: Border.all(color: AppTheme.getCardBorder(context)),
                  ),
                  child: Text('"$selectedText"', style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask AI on shared Group content connects once Cloudflare R2 + FastAPI RAG (Phase 5) are wired — '
                  'same Ask AI flow you already have on your own lectures.',
                  style: Theme.of(context).textTheme.bodySmall,
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
      ),
    );
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

  List<MCQQuestion> _sampleQuizQuestions() => [
        MCQQuestion(
          question: 'When did the First World War begin?',
          options: ['1345', '1914', '1934', '1945'],
          correctAnswer: '1914',
          explanation: 'World War I began on 28 July 1914.',
        ),
        MCQQuestion(
          question: 'Which treaty officially ended the First World War?',
          options: ['Treaty of Versailles', 'Treaty of Paris', 'Treaty of Rome', 'Treaty of Vienna'],
          correctAnswer: 'Treaty of Versailles',
          explanation: 'Signed in 1919 at the Paris Peace Conference.',
        ),
      ];

  void _shareGroup() {
    final group = _group;
    if (group == null) return;
    // Uses the same joinCode-based link format as the Teacher Dashboard's
    // "Share Invite Link" — was previously `group.id` (a UUID), which
    // didn't match the dashboard's link at all.
    final link = 'examspark.app/join/${group.joinCode}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group link copied: $link')));
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted. Our team will review it.')),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
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
        title: Text(group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Top Section: Teacher Profile ----
            TeacherProfileHeader(teacher: teacher),
            const SizedBox(height: 24),

            // ---- Buttons: Join/Leave, Share, Report ----
            SizedBox(
              width: double.infinity,
              child: group.isJoined
                  ? OutlinedButton.icon(
                      onPressed: _isJoinUpdating ? null : _toggleJoin,
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: Text(_isJoinUpdating ? 'Updating...' : 'Leave Group'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _isJoinUpdating ? null : _toggleJoin,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(_isJoinUpdating ? 'Joining...' : 'Join Group'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareGroup,
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share Group'),
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

            // ---- Middle Section: Group Information ----
            _buildSectionHeader('GROUP INFORMATION'),
            const SizedBox(height: 12),
            _buildInfoCard(context, group),
            const SizedBox(height: 28),

            // ---- Teacher Achievements (only if uploaded) ----
            TeacherAchievementsSection(certificates: teacher.certificates, achievements: teacher.achievements),
            if (teacher.hasAchievements) const SizedBox(height: 28),

            // ---- Bottom Section: Recent Shared Content ----
            if (group.recentSharedItems.isNotEmpty) ...[
              _buildSectionHeader('RECENT SHARED CONTENT'),
              const SizedBox(height: 12),
              for (final item in group.recentSharedItems)
                PinnedContentTile(item: item, onTap: () => _openSharedItem(item)),
              const SizedBox(height: 16),
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
