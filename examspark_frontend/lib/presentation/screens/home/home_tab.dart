import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';
import 'package:examspark_frontend/presentation/widgets/bottom_input_bar.dart';
import 'package:examspark_frontend/presentation/widgets/lecture_card.dart';
import 'package:examspark_frontend/presentation/widgets/youtube_link_dialog.dart';

typedef OpenWorkspace = void Function(String lectureId, String title, String? subject);

/// Home = Chat Screen. ChatGPT-simple conversation, no sidebar (lecture
/// history now lives in the Library tab). Credits + recent lectures are
/// real Supabase/LectureService data — the general chat reply is a
/// placeholder until the Ask AI backend is wired (Phase 4/5).
class HomeTab extends StatefulWidget {
  final OpenWorkspace onOpenWorkspace;
  final ValueChanged<int> onGoToTab;

  const HomeTab({super.key, required this.onOpenWorkspace, required this.onGoToTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _ChatBubble {
  final String text;
  final bool isUser;
  const _ChatBubble(this.text, this.isUser);
}

class _HomeTabState extends State<HomeTab> {
  int _creditsBalance = 0;
  String _userName = 'User';
  List<Map<String, dynamic>> _recentLectures = [];
  final List<_ChatBubble> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = SupabaseClient.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await SupabaseClient.instance.getUserProfile(user.id);
      final lectures = await LectureService.instance.getLecturesForUser();
      if (!mounted) return;
      setState(() {
        _creditsBalance = profile?['credits_balance'] as int? ?? 0;
        _userName = (profile?['full_name'] as String?) ?? user.email ?? 'User';
        _recentLectures = lectures.take(5).toList();
      });
    } catch (_) {
      // Non-fatal: home still works without profile/lecture data.
    }
  }

  void _handleSend(String text) {
    setState(() {
      _messages.add(_ChatBubble(text, true));
      _messages.add(const _ChatBubble(
        'This is a placeholder AI reply. Real Ask AI answers connect once the RAG '
        'pipeline is wired (Phase 4/5).',
        false,
      ));
    });
  }

  void _handleRecord() {
    Navigator.pushNamed(context, '/recording_setup');
  }

  void _handleAttach() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _UploadOptionsSheet(),
    );
  }

  void _handleYoutube() {
    showYoutubeLinkDialog(
      context,
      onSubmit: (url) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube Notes — coming soon (backend pipeline in Phase 5)')),
        );
      },
    );
  }

  void _openLecture(Map<String, dynamic> lecture) {
    final id = lecture['id'] as String?;
    if (id == null) return;
    widget.onOpenWorkspace(id, lecture['title'] as String? ?? 'Lecture', lecture['subject'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        showLogo: true,
        creditsBalance: _creditsBalance,
        userName: _userName,
        onSearchTap: () => _showComingSoon('Search'),
        onNotificationTap: () => _showComingSoon('Notifications'),
        onCreditsTap: () => widget.onGoToTab(4),
        onProfileTap: () => widget.onGoToTab(4),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildWelcome(context) : _buildConversation(context),
          ),
          BottomInputBar(
            onSend: _handleSend,
            onAttach: _handleAttach,
            onRecord: _handleRecord,
            onYoutube: _handleYoutube,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        children: [
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: Icon(Icons.auto_awesome, size: 56, color: AppTheme.accentColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask anything or record a lecture',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Notes, summary, flashcards and quiz appear together in your Study Workspace.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (_recentLectures.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Continue where you left off',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            for (final lecture in _recentLectures)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LectureCard(
                  title: lecture['title'] as String? ?? 'Untitled Lecture',
                  subject: lecture['subject'] as String?,
                  dateLabel: _formatDate(lecture['created_at']),
                  onTap: () => _openLecture(lecture),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final bubble = _messages[index];
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: bubble.isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bubble.isUser ? AppTheme.accentColor : AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(16),
                  border: bubble.isUser ? null : Border.all(color: AppTheme.getCardBorder(context)),
                ),
                child: Text(
                  bubble.text,
                  style: TextStyle(
                    color: bubble.isUser ? Colors.white : AppTheme.getPrimaryText(context),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature — coming soon')));
  }
}

class _UploadOptionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            Text('Add content', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _option(context, Icons.picture_as_pdf_outlined, 'PDF Document'),
            _option(context, Icons.image_outlined, 'Image / Photo'),
            _option(context, Icons.mic_outlined, 'Audio File'),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, IconData icon, String label) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppTheme.getAccentTint(context), borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Icon(icon, color: AppTheme.accentColor, size: 20),
      ),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label upload — coming soon')));
      },
    );
  }
}
