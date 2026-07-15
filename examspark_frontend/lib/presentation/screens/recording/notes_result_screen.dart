import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/constants/ai_answer_meta.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/presentation/screens/results/widgets/extra_actions_panel.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_assistant_message.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_thinking_bubble.dart';
import 'package:examspark_frontend/presentation/widgets/ask_ai_selectable_text.dart';

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
  bool _extrasLoading = false;

  // Data models
  Map<String, dynamic>? _notesData;
  Map<String, dynamic>? _transcriptData;
  Map<String, bool> _cachedExtras = {};

  // Loading states for action chips
  final Map<String, bool> _actionLoadingStates = {};

  int _selectedSectionIndex = 0;

  final List<String> _sections = [
    'Short Summary',
    'Key Points',
    'Clean Notes',
    'Important Terms',
  ];

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

      // Notes content lives in R2 — FastAPI reads paths from Postgres metadata.
      final notesResponse = await LectureService.instance.fetchLectureNotes(
        widget.lectureId,
      );

      // Fetch transcript metadata (content path only; not shown on this screen yet)
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

  Future<void> _handleExtraAction(String actionType) async {
    if (actionType == 'rag') {
      _openRAGChat();
      return;
    }

    if (_cachedExtras[actionType] == true) {
      _openActionView(actionType);
      return;
    }

    final creditCheck = await _checkCredits(1);
    if (!creditCheck) {
      _showUpgradeAlert();
      return;
    }

    setState(() => _extrasLoading = true);

    try {
      final result = await LectureService.instance.invokeExtra(
        lectureId: widget.lectureId,
        action: actionType,
        content: _notesData?['clean_notes']?.toString() ?? '',
      );

      if (result['success'] == true) {
        setState(() {
          _cachedExtras[actionType] = true;
          _extrasLoading = false;
        });
        _openActionView(actionType);
      } else {
        throw Exception('Generation failed');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _extrasLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate content')),
        );
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
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase
          .from('users')
          .select('credits_balance')
          .eq('id', userId)
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

  void _openRAGChat({String? initialQuery}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RAGChatModal(
        lectureId: widget.lectureId,
        initialQuery: initialQuery,
      ),
    );
  }

  /// Entry point for the "select text → Ask AI" feature
  /// (`AskAiSelectableText`) — opens the same Ask AI chat used by the
  /// "Ask AI" action chip, pre-filled with the selected snippet.
  void _askAiAbout(String selectedText) {
    _openRAGChat(initialQuery: 'Explain: "$selectedText"');
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
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.security, size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Protected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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

                // Section tabs
                if (!_isLoading)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.screenPadding,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.getCardBorder(context)),
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_sections.length, (index) {
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < _sections.length - 1 ? 24 : 0,
                              ),
                              child: _buildSectionTab(_sections[index], index),
                            );
                          }),
                        ),
                      ),
                    ),
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
                child: ExtraActionsPanel(
                  isLoading: _extrasLoading,
                  onAction: _handleExtraAction,
                ),
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

    switch (_selectedSectionIndex) {
      case 0:
        return _buildShortSummary(summary);
      case 1:
        return _buildKeyPoints(keyPoints);
      case 2:
        return _buildCleanNotes(cleanNotes);
      case 3:
        return _buildImportantTerms(importantTerms);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionTab(String label, int index) {
    final isSelected = _selectedSectionIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSectionIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? AppTheme.getPrimaryText(context)
                  : AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: label.length * 8.0,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortSummary(dynamic content) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Summary',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AskAiSelectableText(
            text: content?.toString().isNotEmpty == true
                ? content.toString()
                : 'No summary available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
            onAskAi: _askAiAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPoints(List? points) {
    if (points == null || points.isEmpty) {
      return SectionCard(
        child: Text(
          'No key points available',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      children: List.generate(points.length, (index) {
        return Container(
          margin: EdgeInsets.only(bottom: index < points.length - 1 ? 12 : 0),
          child: SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AskAiSelectableText(
                    text: points[index].toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                    onAskAi: _askAiAbout,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCleanNotes(dynamic content) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Clean Notes',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AskAiSelectableText(
            text: content?.toString().isNotEmpty == true
                ? content.toString()
                : 'No clean notes available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
            onAskAi: _askAiAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildImportantTerms(List? terms) {
    if (terms == null || terms.isEmpty) {
      return SectionCard(
        child: Text(
          'No terms available',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      children: List.generate(terms.length, (index) {
        final term = terms[index] as Map?;
        return Container(
          margin: EdgeInsets.only(bottom: index < terms.length - 1 ? 12 : 0),
          child: SectionCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              leading: Icon(Icons.bookmark, color: AppTheme.accentColor, size: 18),
              title: Text(
                term?['term']?.toString() ?? 'Term ${index + 1}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AskAiSelectableText(
                    text: term?['definition']?.toString() ?? 'No definition',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                    onAskAi: _askAiAbout,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
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

  /// Pre-fills the input (does NOT auto-send) — used by the "select text →
  /// Ask AI" feature so the user can still edit their question before it
  /// costs credits.
  final String? initialQuery;

  const RAGChatModal({
    super.key,
    required this.lectureId,
    this.initialQuery,
  });

  @override
  State<RAGChatModal> createState() => _RAGChatModalState();
}

class _RAGChatModalState extends State<RAGChatModal> {
  late final TextEditingController _messageController =
      TextEditingController(text: widget.initialQuery ?? '');
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _conversationLanguage;
  String? _liveStreamText;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  static const List<String> _suggestionChips = [
    'Explain the main idea in simple words',
    'Give a short answer: what is this lecture about?',
    'Give a long answer suitable for exams',
    'What facts or numbers are mentioned?',
    'What should I remember for revision?',
    'List important terms and definitions',
    'Give a simple example from these notes',
  ];

  void _applySuggestion(String suggestion) {
    setState(() {
      _messageController.text = suggestion;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: suggestion.length),
      );
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
      ));
      _messageController.clear();
      _isLoading = true;
      _liveStreamText = null;
    });
    _scrollToBottom();

    try {
      await _runAskAiStream(message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _liveStreamText = null);
      try {
        await _runAskAiJson(message);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage(
            text: 'Ask AI failed: $error',
            isUser: false,
            animateReveal: false,
          ));
          _isLoading = false;
          _liveStreamText = null;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _runAskAiStream(String message) async {
    final done = await LectureService.instance.askAiStream(
      lectureId: widget.lectureId,
      query: message,
      mode: 'normal',
      conversationLanguage: _conversationLanguage,
      onToken: (delta) {
        if (!mounted) return;
        setState(() {
          _liveStreamText = (_liveStreamText ?? '') + delta;
        });
        _scrollToBottom();
      },
    );
    if (!mounted) return;
    _applyAskAiSuccess(done, animateReveal: false);
  }

  Future<void> _runAskAiJson(String message) async {
    final result = await LectureService.instance.askAi(
      lectureId: widget.lectureId,
      query: message,
      mode: 'normal',
      conversationLanguage: _conversationLanguage,
    );
    if (!mounted) return;
    _applyAskAiSuccess(result, animateReveal: true);
  }

  void _applyAskAiSuccess(
    Map<String, dynamic> result, {
    required bool animateReveal,
  }) {
    final answer = (result['answer'] as String?)?.trim();
    final trust = AiAnswerMeta.trustLine(
      answerSource: result['answer_source'] as String?,
      confidence: result['confidence'] as String?,
    );
    final convLang = result['conversation_language'] as String?;
    final hasAnswer = answer != null && answer.isNotEmpty;
    setState(() {
      if (convLang != null && convLang.isNotEmpty) {
        _conversationLanguage = convLang;
      }
      _messages.add(ChatMessage(
        text: hasAnswer ? answer : 'No answer available',
        isUser: false,
        trustLine: trust,
        animateReveal: hasAnswer && animateReveal,
      ));
      _isLoading = false;
      _liveStreamText = null;
    });
    _scrollToBottom();
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

          // Messages + suggestion chips (empty state)
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptySuggestions()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        if (_liveStreamText != null &&
                            _liveStreamText!.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AiAssistantMessage(
                              text: _liveStreamText!,
                              animate: false,
                            ),
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: AiThinkingBubble(),
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
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
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

  Widget _buildEmptySuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try asking about this lecture',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.getPrimaryText(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a suggestion to fill the box — edit if you want, then Send (uses 5 credits).',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.getSecondaryText(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestionChips.map((suggestion) {
              return OutlinedButton(
                onPressed: () => _applySuggestion(suggestion),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.getPrimaryText(context),
                  side: BorderSide(color: AppTheme.getCardBorder(context)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  suggestion,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (!message.isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AiAssistantMessage(
          text: message.text,
          trustLine: message.trustLine,
          animate: message.animateReveal,
          onRevealComplete: _scrollToBottom,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? trustLine;
  final bool animateReveal;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.trustLine,
    this.animateReveal = false,
  });
}
