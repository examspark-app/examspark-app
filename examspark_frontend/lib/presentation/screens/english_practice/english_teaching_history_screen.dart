import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/roleplay_transcript_screen.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

const _violet = Color(0xFF5137ED);

/// Authenticated English Teaching history. The API determines the current user
/// from the access token; this screen never sends or accepts a user id.
class EnglishTeachingHistoryScreen extends StatefulWidget {
  const EnglishTeachingHistoryScreen({super.key});

  @override
  State<EnglishTeachingHistoryScreen> createState() =>
      _EnglishTeachingHistoryScreenState();
}

class _EnglishTeachingHistoryScreenState
    extends State<EnglishTeachingHistoryScreen> {
  int _mode = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _chat = const [];
  List<Map<String, dynamic>> _roleplay = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        LectureService.instance.listEnglishPracticeSessions(),
        LectureService.instance.listEnglishRoleplaySessions(),
      ]);
      if (!mounted) return;
      setState(() {
        _chat = results[0];
        _roleplay = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openChat(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EnglishPracticeScreen(sessionId: id)),
    );
    if (mounted) _load();
  }

  Future<void> _openRoleplay(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoleplayTranscriptScreen(sessionId: id)),
    );
    if (mounted) _load();
  }

  Future<void> _showChatActions(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null || id.isEmpty) return;
    final pinned = item['pinned'] == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(pinned ? 'Unpin' : 'Pin to top'),
              onTap: () => Navigator.pop(sheetContext, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(sheetContext, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'pin') {
      try {
        await LectureService.instance.englishPracticePinSession(id, !pinned);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(pinned ? 'Unpinned' : 'Pinned to top')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update chat: $e')),
          );
        }
      }
      await _load();
      return;
    }

    if (action == 'rename') {
      final controller = TextEditingController(
        text: (item['title'] as String?)?.trim() ?? '',
      );
      final title = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rename chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(
              hintText: 'Chat name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (title == null || title.isEmpty) return;
      try {
        await LectureService.instance.englishPracticeRenameSession(id, title);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat renamed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not rename chat: $e')),
          );
        }
      }
      await _load();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This conversation will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await LectureService.instance.englishPracticeDeleteSession(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete chat: $e')),
        );
      }
    }
    await _load();
  }

  String _date(String? source) {
    final value = source == null ? null : DateTime.tryParse(source)?.toLocal();
    if (value == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${months[value.month - 1]} ${value.day}, ${value.year} · '
        '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final items = _mode == 0 ? _chat : _roleplay;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEAF7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    _tab('Chat', Icons.chat_bubble_outline, 0),
                    _tab('Roleplay', Icons.masks_outlined, 1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _violet))
                  : _error != null
                  ? _state(
                      icon: Icons.cloud_off_outlined,
                      title: 'Could not load history',
                      detail: _error!,
                      action: 'Retry',
                      onAction: _load,
                    )
                  : items.isEmpty
                  ? _state(
                      icon: _mode == 0
                          ? Icons.chat_bubble_outline
                          : Icons.masks_outlined,
                      title: _mode == 0
                          ? 'No chat history yet'
                          : 'No roleplay history yet',
                      detail: 'Your saved conversations will appear here.',
                    )
                  : RefreshIndicator(
                      color: _violet,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _historyItem(items[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, IconData icon, int index) {
    final selected = _mode == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => setState(() => _mode = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.getCardBackground(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x12000000), blurRadius: 5)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? _violet : const Color(0xFF6C6A80)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _violet : const Color(0xFF6C6A80),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> item) {
    final roleplay = _mode == 1;
    final title = roleplay
        ? (item['scenario'] as String? ?? 'Roleplay')
        : ((item['title'] as String?)?.trim().isNotEmpty == true
              ? item['title'] as String
              : 'English Practice');
    final preview = (item['preview'] as String? ?? '').trim();
    final date = _date((item['updated_at'] ?? item['started_at']) as String?);
    return Material(
      color: AppTheme.getCardBackground(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => roleplay
            ? _openRoleplay(item['id'] as String)
            : _openChat(item['id'] as String),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEAE6FF),
                ),
                child: Icon(
                  roleplay ? Icons.masks_outlined : Icons.chat_bubble_outline,
                  color: _violet,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF6D6B7E)),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF9290A2))),
                  ],
                ),
              ),
              if (!roleplay)
                IconButton(
                  tooltip: 'Chat options',
                  icon: const Icon(Icons.more_vert, color: Color(0xFF8F8C9D)),
                  onPressed: () => _showChatActions(item),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF8F8C9D)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String detail,
    String? action,
    VoidCallback? onAction,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: _violet),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 6),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6D6B7E))),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(action)),
          ],
        ],
      ),
    ),
  );
}
