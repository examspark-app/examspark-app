import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';

/// Screen 4: Notes Result Screen
/// View-only screen with modular sections and action chips
class NotesResultScreen extends StatefulWidget {
  final String lectureId;

  const NotesResultScreen({
    super.key,
    required this.lectureId,
  });

  @override
  State<NotesResultScreen> createState() => _NotesResultScreenState();
}

class _NotesResultScreenState extends State<NotesResultScreen> {
  String _lectureTitle = 'Lecture Notes';
  bool _isLoading = true;
  bool _hasError = false;

  // Data models
  Map<String, dynamic>? _notesData;
  Map<String, dynamic>? _transcriptData;
  Map<String, bool> _cachedExtras = {};

  // Loading states for action chips
  final Map<String, bool> _actionLoadingStates = {};

  @override
  void initState() {
    super.initState();
    _fetchLectureData();
    _enableScreenshotProtection();
  }

  void _enableScreenshotProtection() {
    SystemChannels.platform.invokeMethod('SystemChrome.enableSecureUI');
  }

  void _disableScreenshotProtection() {
    SystemChannels.platform.invokeMethod('SystemChrome.disableSecureUI');
  }

  Future<void> _fetchLectureData() async {
    try {
      final supabase = SupabaseClient.instance.client;

      // Fetch lecture details
      final lectureResponse = await supabase
          .from('lectures')
          .select('title, status')
          .eq('id', widget.lectureId)
          .single();

      // Fetch notes
      final notesResponse = await supabase
          .from('notes')
          .select('*')
          .eq('lecture_id', widget.lectureId)
          .maybeSingle();

      // Fetch transcript
      final transcriptResponse = await supabase
          .from('transcripts')
          .select('*')
          .eq('lecture_id', widget.lectureId)
          .maybeSingle();

      // Fetch cached extras
      final extrasResponse = await supabase
          .from('extras')
          .select('type')
          .eq('lecture_id', widget.lectureId);

      if (mounted) {
        setState(() {
          _lectureTitle = lectureResponse['title'] ?? 'Lecture Notes';
          _notesData = notesResponse;
          _transcriptData = transcriptResponse;
          _isLoading = false;

          // Build cached extras map
          if (extrasResponse != null) {
            for (var extra in extrasResponse) {
              _cachedExtras[extra['type']] = true;
            }
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _renameLecture() async {
    final controller = TextEditingController(text: _lectureTitle);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Rename Lecture'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final supabase = SupabaseClient.instance.client;
        await supabase
            .from('lectures')
            .update({'title': result})
            .eq('id', widget.lectureId);

        if (mounted) {
          setState(() {
            _lectureTitle = result;
          });
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to rename lecture')),
          );
        }
      }
    }
  }

  Future<void> _deleteLecture() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Delete Lecture'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = SupabaseClient.instance.client;
        await supabase
            .from('lectures')
            .delete()
            .eq('id', widget.lectureId);

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete lecture')),
          );
        }
      }
    }
  }

  Future<void> _handleAction(String actionType) async {
    // Check if already cached
    if (_cachedExtras[actionType] == true) {
      _openActionView(actionType);
      return;
    }

    // Credit pre-check
    final creditCheck = await _checkCredits(1);
    if (!creditCheck) {
      _showUpgradeAlert();
      return;
    }

    // Set loading state
    setState(() {
      _actionLoadingStates[actionType] = true;
    });

    try {
      // Call backend to generate content
      final supabase = SupabaseClient.instance.client;
      final response = await supabase.functions.invoke('process-lecture', body: {
        'action': actionType,
        'userId': supabase.auth.currentUser?.id,
        'content': _notesData?['clean_notes'] ?? '',
      });

      if (response.data['success'] == true) {
        // Mark as cached
        setState(() {
          _cachedExtras[actionType] = true;
          _actionLoadingStates[actionType] = false;
        });

        _openActionView(actionType);
      } else {
        throw Exception('Generation failed');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _actionLoadingStates[actionType] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate content')),
        );
      }
    }
  }

  Future<bool> _checkCredits(int required) async {
    try {
      final supabase = SupabaseClient.instance.client;
      final response = await supabase
          .from('users')
          .select('credits_balance')
          .eq('id', supabase.auth.currentUser?.id)
          .single();

      return response['credits_balance'] >= required;
    } catch (error) {
      return false;
    }
  }

  void _showUpgradeAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Not enough credits'),
        content: const Text('You need at least 1 credit to generate this content.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription');
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  void _openActionView(String actionType) {
    // Navigate to appropriate view based on action type
    // For now, show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: Text(actionType.toUpperCase()),
        content: Text('View for $actionType would open here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openRAGChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RAGChatModal(lectureId: widget.lectureId),
    );
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              const Text('Failed to load notes'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchLectureData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  elevation: 0,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: GestureDetector(
                    onTap: _renameLecture,
                    child: Text(
                      _lectureTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.getPrimaryText(context),
                      ),
                    ),
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'rename') {
                          _renameLecture();
                        } else if (value == 'delete') {
                          _deleteLecture();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Lecture'),
                        ),
                      ],
                    ),
                  ],
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.screenPadding),
                    child: _isLoading ? _buildShimmerContent() : _buildContent(),
                  ),
                ),

                // Bottom spacing for action bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),

            // Sticky Action Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                  vertical: 12,
                ),
                child: _buildActionBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerSection('SUMMARY'),
        const SizedBox(height: 16),
        _buildShimmerSection('KEY POINTS'),
        const SizedBox(height: 16),
        _buildShimmerSection('NOTES'),
        const SizedBox(height: 16),
        _buildShimmerSection('IMPORTANT TERMS'),
      ],
    );
  }

  Widget _buildShimmerSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.getSecondaryText(context),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  height: 16,
                  width: index == 2 ? double.infinity : 200,
                  decoration: BoxDecoration(
                    color: AppTheme.getCardBorder(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final summary = _notesData?['short_summary'] ?? '';
    final keyPoints = _notesData?['key_points'] as List?;
    final cleanNotes = _notesData?['clean_notes'] ?? '';
    final importantTerms = _notesData?['important_terms'] as List?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Section
        _buildSectionHeader('SUMMARY'),
        const SizedBox(height: 12),
        SectionCard(
          child: Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 24),

        // Key Points Section
        _buildSectionHeader('KEY POINTS'),
        const SizedBox(height: 12),
        SectionCard(
          child: keyPoints != null && keyPoints.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: keyPoints.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(
                            point.toString(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                )
              : Text(
                  'No key points available',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
        ),
        const SizedBox(height: 24),

        // Notes Section
        _buildSectionHeader('NOTES'),
        const SizedBox(height: 12),
        SectionCard(
          child: Text(
            cleanNotes,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 24),

        // Important Terms Section
        _buildSectionHeader('IMPORTANT TERMS'),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: importantTerms != null && importantTerms.isNotEmpty
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: importantTerms.length,
                  itemBuilder: (context, index) {
                    final term = importantTerms[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < importantTerms.length - 1 ? 12 : 0,
                      ),
                      child: TermChip(
                        term: term['term']?.toString() ?? '',
                        definition: term['definition']?.toString() ?? '',
                        onTap: () => _showTermDefinition(
                          term['term']?.toString() ?? '',
                          term['definition']?.toString() ?? '',
                        ),
                      ),
                    );
                  },
                )
              : Center(
                  child: Text(
                    'No terms available',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.getSecondaryText(context),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildActionBar() {
    final actions = [
      ('MCQ', 'mcq', Icons.quiz_outlined),
      ('Revision', 'revision', Icons.assignment_outlined),
      ('Important Qs', 'important_questions', Icons.help_outline),
      ('Answer Key', 'answer_key', Icons.check_circle_outline),
      ('Flashcards', 'flashcards', Icons.style_outlined),
      ('Ask (RAG)', 'rag', Icons.chat_bubble_outline),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final (label, type, icon) = actions[index];
          final isLoading = _actionLoadingStates[type] ?? false;
          final isCached = _cachedExtras[type] ?? false;

          return Padding(
            padding: EdgeInsets.only(
              right: index < actions.length - 1 ? 12 : 0,
            ),
            child: ActionChipButton(
              label: label,
              icon: icon,
              isLoading: isLoading,
              isCached: isCached,
              onTap: () {
                if (type == 'rag') {
                  _openRAGChat();
                } else {
                  _handleAction(type);
                }
              },
            ),
          );
        },
      ),
    );
  }

  void _showTermDefinition(String term, String definition) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 16),
            Text(
              definition,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MODULAR WIDGETS ====================

class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class TermChip extends StatelessWidget {
  final String term;
  final String definition;
  final VoidCallback onTap;

  const TermChip({
    super.key,
    required this.term,
    required this.definition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.getCardBorder(context),
            width: 1,
          ),
        ),
        child: Text(
          term,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class ActionChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool isCached;
  final VoidCallback onTap;

  const ActionChipButton({
    super.key,
    required this.label,
    required this.icon,
    this.isLoading = false,
    this.isCached = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isCached
              ? AppTheme.getAccentTint(context)
              : AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.getCardBorder(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.accentColor,
                  ),
                ),
              )
            else
              Icon(
                icon,
                size: 16,
                color: isCached
                    ? AppTheme.accentColor
                    : AppTheme.getPrimaryText(context),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: isLoading
                    ? AppTheme.getSecondaryText(context)
                    : AppTheme.getPrimaryText(context),
              ),
            ),
            if (isCached) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle,
                size: 12,
                color: AppTheme.accentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RAGChatModal extends StatefulWidget {
  final String lectureId;

  const RAGChatModal({
    super.key,
    required this.lectureId,
  });

  @override
  State<RAGChatModal> createState() => _RAGChatModalState();
}

class _RAGChatModalState extends State<RAGChatModal> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
      ));
      _messageController.clear();
      _isLoading = true;
    });

    try {
      final supabase = SupabaseClient.instance.client;
      final response = await supabase.functions.invoke('process-lecture', body: {
        'action': 'rag',
        'userId': supabase.auth.currentUser?.id,
        'query': message,
        'lectureId': widget.lectureId,
      });

      if (response.data['success'] == true) {
        setState(() {
          _messages.add(ChatMessage(
            text: response.data['result']['answer'] ?? 'No answer available',
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Failed to get answer. Please try again.',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.getCardBorder(context),
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Ask about this lecture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.getCardBorder(context),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      style: const TextStyle(fontSize: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: message.isUser
                ? AppTheme.accentColor
                : AppTheme.getCardBackground(context),
            borderRadius: BorderRadius.circular(16),
            border: message.isUser
                ? null
                : Border.all(
                    color: AppTheme.getCardBorder(context),
                  ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: message.isUser ? Colors.white : AppTheme.getPrimaryText(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}
