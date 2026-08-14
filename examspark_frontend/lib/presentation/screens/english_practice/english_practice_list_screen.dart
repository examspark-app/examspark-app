import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';

/// Shows past English Practice conversations + a "New chat" button.
class EnglishPracticeListScreen extends StatefulWidget {
  const EnglishPracticeListScreen({super.key});

  @override
  State<EnglishPracticeListScreen> createState() => _EnglishPracticeListScreenState();
}

class _EnglishPracticeListScreenState extends State<EnglishPracticeListScreen> {
  List<Map<String, dynamic>>? _sessions;
  bool _loading = true;

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
    // Refresh the list after coming back (new/updated sessions show up).
    _load();
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
                    final focus = (s['target_focus'] as String?)?.trim();
                    final subtitle = [
                      if (focus != null && focus.isNotEmpty) focus,
                      '${s['message_count'] ?? 0} messages',
                      _formatDate(s['updated_at'] as String?),
                    ].where((e) => e.isNotEmpty).join(' · ');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.getAccentTint(context),
                        child: Icon(Icons.chat_bubble_outline, color: AppTheme.accentColor),
                      ),
                      title: Text(
                        (s['title'] as String?)?.trim().isNotEmpty == true
                            ? s['title'] as String
                            : 'English Practice',
                      ),
                      subtitle: Text(subtitle),
                      onTap: () => _openSession(s['id'] as String?),
                    );
                  },
                ),
    );
  }
}