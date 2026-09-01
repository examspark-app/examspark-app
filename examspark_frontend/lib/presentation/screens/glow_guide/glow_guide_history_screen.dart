import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/presentation/screens/glow_guide/glow_guide_screen.dart';

class GlowGuideHistoryScreen extends StatefulWidget {
  const GlowGuideHistoryScreen({super.key});

  @override
  State<GlowGuideHistoryScreen> createState() => _GlowGuideHistoryScreenState();
}

class _GlowGuideHistoryScreenState extends State<GlowGuideHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = const [];

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
      final sessions = await LectureService.instance.listGlowGuideSessions();
      final unique = <String, Map<String, dynamic>>{};
      for (final session in sessions) {
        final id = session['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) unique.putIfAbsent(id, () => session);
      }
      final sorted = unique.values.toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['updated_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['updated_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final byTime = bTime.compareTo(aTime);
          if (byTime != 0) return byTime;
          return (b['id']?.toString() ?? '').compareTo(a['id']?.toString() ?? '');
        });
      if (!mounted) return;
      setState(() {
        _sessions = sorted;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openSession(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GlowGuideScreen(sessionId: id)),
    );
    if (mounted) _load();
  }

  Future<void> _rename(Map<String, dynamic> session) async {
    final id = session['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final controller = TextEditingController(
      text: session['title']?.toString() ?? '',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename GlowGuide chat'),
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
      await LectureService.instance.renameGlowGuideSession(id, title);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rename chat: $error')),
      );
    }
  }

  String _date(String? source) {
    final value = source == null ? null : DateTime.tryParse(source)?.toLocal();
    if (value == null) return '';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
        '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $period';
  }

  String _title(Map<String, dynamic> session) {
    final title = session['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    final category = session['category_type']?.toString().trim() ?? '';
    return category.isEmpty ? 'GlowGuide Chat' : category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GlowGuide History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _sessions.isEmpty
                  ? const Center(child: Text('No GlowGuide history yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final session = _sessions[index];
                          final id = session['id']?.toString() ?? '';
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.eco_outlined, color: Color(0xFFB64B85)),
                              title: Text(_title(session), maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(_date(session['updated_at']?.toString())),
                              onTap: () => _openSession(id),
                              trailing: IconButton(
                                tooltip: 'Rename chat',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _rename(session),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
