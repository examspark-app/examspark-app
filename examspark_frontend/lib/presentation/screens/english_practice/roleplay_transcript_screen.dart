import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

const _violet = Color(0xFF5137ED);

/// Read-only saved roleplay. It intentionally has no recorder or player.
class RoleplayTranscriptScreen extends StatefulWidget {
  const RoleplayTranscriptScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<RoleplayTranscriptScreen> createState() => _RoleplayTranscriptScreenState();
}

class _RoleplayTranscriptScreenState extends State<RoleplayTranscriptScreen> {
  Map<String, dynamic>? _session;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await LectureService.instance.restoreEnglishRoleplaySession(widget.sessionId);
      if (mounted) setState(() => _session = value);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final messages = session?['messages'] as List? ?? const [];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session?['scenario'] as String? ?? 'Roleplay history',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: session == null && _error == null
                  ? const Center(child: CircularProgressIndicator(color: _violet))
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.history_toggle_off_outlined, size: 44, color: _violet),
                          const SizedBox(height: 12),
                          const Text('This conversation is unavailable.', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6D6B7E))),
                          const SizedBox(height: 14),
                          OutlinedButton(onPressed: _load, child: const Text('Retry')),
                        ]),
                      ),
                    )
                  : messages.isEmpty
                  ? const Center(child: Text('No saved transcript for this roleplay.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = Map<String, dynamic>.from(messages[index] as Map);
                        final isUser = message['role'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                            decoration: BoxDecoration(
                              color: isUser ? _violet : AppTheme.getCardBackground(context),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Text(
                              message['message'] as String? ?? '',
                              style: TextStyle(color: isUser ? Colors.white : AppTheme.getPrimaryText(context), height: 1.35),
                            ),
                          ),
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
