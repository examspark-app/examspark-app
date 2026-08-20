import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';

class EnglishPracticeListScreen extends StatefulWidget {
  const EnglishPracticeListScreen({super.key});

  @override
  State<EnglishPracticeListScreen> createState() =>
      _EnglishPracticeListScreenState();
}

class _EnglishPracticeListScreenState extends State<EnglishPracticeListScreen> {
  List<Map<String, dynamic>>? _sessions;
  bool _loading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await LectureService.instance.listEnglishPracticeSessions();
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessions = [];
        _loading = false;
      });
    }
  }

  void _openSession(String? sessionId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnglishPracticeScreen(sessionId: sessionId),
      ),
    );
    _load();
  }

  Future<void> _showActions(Map<String, dynamic> session) async {
    final id = session['id'] as String?;
    if (id == null) return;
    final pinned = (session['pinned'] as bool?) ?? false;
    final currentTitle =
        (session['title'] as String?)?.trim().isNotEmpty == true
            ? session['title'] as String
            : 'English Practice';

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(pinned ? 'Unpin' : 'Pin to top'),
              onTap: () => Navigator.pop(ctx, pinned ? 'unpin' : 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(
                'Delete',
                style:
                    TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'pin':
      case 'unpin':
        try {
          await LectureService.instance
              .englishPracticePinSession(id, action == 'pin');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(action == 'pin' ? 'Pinned to top' : 'Unpinned'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not update: $e')),
            );
          }
        }
        _load();
        break;
      case 'rename':
        final controller = TextEditingController(text: currentTitle);
        final newTitle = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (newTitle != null && newTitle.isNotEmpty) {
          try {
            await LectureService.instance
                .englishPracticeRenameSession(id, newTitle);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Renamed')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not rename: $e')),
              );
            }
          }
          _load();
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete chat?'),
            content: const Text(
                'This conversation will be permanently deleted. This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await LectureService.instance.englishPracticeDeleteSession(id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleted')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not delete: $e')),
              );
            }
          }
          _load();
        }
        break;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('English Practice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: () => _openSession(null),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_sessions == null || _sessions!.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No conversations yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openSession(null),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Start practicing'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.screenPadding),
                  itemCount: _sessions!.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = _sessions![i];
                    final pinned = (s['pinned'] as bool?) ?? false;
                    final focus = (s['target_focus'] as String?)?.trim();
                    final subtitle = [
                      if (focus != null && focus.isNotEmpty) focus,
                      '${s['message_count'] ?? 0} messages',
                      _formatDate(s['updated_at'] as String?),
                    ].where((e) => e.isNotEmpty).join(' · ');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.getAccentTint(context),
                        child: Icon(
                            pinned
                                ? Icons.push_pin
                                : Icons.chat_bubble_outline,
                            color: AppTheme.accentColor),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              (s['title'] as String?)?.trim().isNotEmpty ==
                                      true
                                  ? s['title'] as String
                                  : 'English Practice',
                            ),
                          ),
                          if (pinned)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.push_pin,
                                  size: 16,
                                  color: AppTheme.accentColor),
                            ),
                        ],
                      ),
                      subtitle: Text(subtitle),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Options',
                        onPressed: () => _showActions(s),
                      ),
                      onTap: () => _openSession(s['id'] as String?),
                      onLongPress: () => _showActions(s),
                    );
                  },
                ),
    );
  }
}
