import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

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
    try {
      await LectureService.instance.homeAiDeleteSession(id);
      if (!mounted) return;
      setState(() {
        _sessions.removeWhere((s) => s['id'] == id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
        ),
      );
    }
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
                'Open = same Q + answer + chips. No AI · 0 credits.',
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
                                  trailing: IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _delete(id),
                                  ),
                                  onTap: id.isEmpty
                                      ? null
                                      : () => Navigator.pop(context, id),
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
