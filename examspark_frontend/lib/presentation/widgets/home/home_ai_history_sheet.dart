import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Phase 4D — Home AI Study History list (open = restore, 0 credits).
Future<String?> showHomeAiHistorySheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _HomeAiHistorySheet(),
  );
}

class _HomeAiHistorySheet extends StatefulWidget {
  const _HomeAiHistorySheet();

  @override
  State<_HomeAiHistorySheet> createState() => _HomeAiHistorySheetState();
}

class _HomeAiHistorySheetState extends State<_HomeAiHistorySheet> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await LectureService.instance.homeAiListSessions(
        query: q,
      );
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Delete chat?'),
        content: const Text('This chat will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await LectureService.instance.homeAiDeleteSession(id);
      if (!mounted) return;
      setState(() {
        _sessions.removeWhere((s) => s['id'] == id);
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(context,
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
        ),
      );
    }
  }

  Future<void> _rename(String id, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Chat title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty) return;
    try {
      await LectureService.instance.homeAiRenameSession(id, newTitle);
      if (!mounted) return;
      setState(() {
        final idx = _sessions.indexWhere((s) => s['id'] == id);
        if (idx != -1) _sessions[idx]['title'] = newTitle;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(context,
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
        ),
      );
    }
  }

  Future<void> _togglePin(String id, bool currentlyPinned) async {
    try {
      await LectureService.instance.homeAiPinSession(id, !currentlyPinned);
      if (!mounted) return;
      setState(() {
        final idx = _sessions.indexWhere((s) => s['id'] == id);
        if (idx != -1) _sessions[idx]['pinned'] = !currentlyPinned;
        _sessions.sort((a, b) {
          final ap = a['pinned'] == true ? 1 : 0;
          final bp = b['pinned'] == true ? 1 : 0;
          return bp.compareTo(ap);
        });
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showSnackBar(context,
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
        ),
      );
    }
  }

  void _showOptionsSheet(String id, String title, bool pinned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.getCardBorder(ctx),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(id, title);
              },
            ),
            ListTile(
              leading: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(pinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(id, pinned);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _delete(id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Study History',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search sessions…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onSubmitted: (v) => _load(q: v),
                textInputAction: TextInputAction.search,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Open = same Q + answer + chips. Long-press for options.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => _load(q: _search.text),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _sessions.isEmpty
                          ? Center(
                              child: Text(
                                'No saved study sessions yet.\nAsk a question on Home first.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                              itemCount: _sessions.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final s = _sessions[i];
                                final id = s['id'] as String? ?? '';
                                final title =
                                    (s['title'] as String?)?.trim().isNotEmpty ==
                                            true
                                        ? s['title'] as String
                                        : 'Study session';
                                final pinned = s['pinned'] == true;
                                final updated =
                                    (s['updated_at'] as String?) ?? '';
                                return ListTile(
                                  leading: Icon(
                                    pinned
                                        ? Icons.push_pin_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    color: AppTheme.accentColor,
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: updated.isEmpty
                                      ? null
                                      : Text(
                                          updated.length >= 10
                                              ? updated.substring(0, 10)
                                              : updated,
                                        ),
                                  onTap: id.isEmpty
                                      ? null
                                      : () => Navigator.pop(context, id),
                                  onLongPress: id.isEmpty
                                      ? null
                                      : () => _showOptionsSheet(id, title, pinned),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}