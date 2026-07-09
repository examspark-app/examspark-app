import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/presentation/screens/results/widgets/extra_actions_panel.dart';

/// Screen 4: Notes Result Screen
/// Default output sections always shown with clean, minimal ChatGPT-inspired design
/// View-only with screenshot protection, no export widgets for standard accounts
class NotesViewScreen extends StatefulWidget {
  final Map<String, dynamic> lectureData;

  const NotesViewScreen({
    super.key,
    required this.lectureData,
  });

  @override
  State<NotesViewScreen> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesViewScreen> {
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
    _enableScreenshotProtection();
  }

  void _enableScreenshotProtection() {
    SystemChannels.platform.invokeMethod('SystemChrome.enableSecureUI');
  }

  @override
  void dispose() {
    SystemChannels.platform.invokeMethod('SystemChrome.disableSecureUI');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final processedContent = widget.lectureData['processedContent'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lectureData['title'] ?? 'Lecture Notes',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Generated just now',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Screenshot protection indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[300]!),
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
              ],
            ),
          ),
          // Section Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_sections.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(right: index < _sections.length - 1 ? 24 : 0),
                    child: _buildSectionTab(_sections[index], index),
                  );
                }),
              ),
            ),
          ),
          // Content Area
          Expanded(
            child: _buildContent(processedContent),
          ),
          // Action Button Row
          const ExtraActionsPanel(),
        ],
      ),
    );
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
              color: isSelected ? Colors.black87 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: label.length * 8.0,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black87 : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic>? processedContent) {
    if (processedContent == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey300),
            SizedBox(height: 16),
            Text(
              'No content available',
              style: TextStyle(color: Colors.grey600),
            ),
          ],
        ),
      );
    }

    switch (_selectedSectionIndex) {
      case 0:
        return _buildShortSummary(processedContent['shortSummary']);
      case 1:
        return _buildKeyPoints(processedContent['keyPoints']);
      case 2:
        return _buildCleanNotes(processedContent['cleanNotes']);
      case 3:
        return _buildImportantTerms(processedContent['importantTerms']);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildShortSummary(dynamic content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.summarize, color: Colors.blue[700], size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content?.toString() ?? 'No summary available',
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyPoints(dynamic content) {
    final points = content as List?;
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: points?.length ?? 0,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
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
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  points?[index]?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCleanNotes(dynamic content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.description, color: Colors.green[700], size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Clean Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              content?.toString() ?? 'No clean notes available',
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportantTerms(dynamic content) {
    final terms = content as List?;
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: terms?.length ?? 0,
      itemBuilder: (context, index) {
        final term = terms?[index] as Map?;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.bookmark, color: Colors.purple[700], size: 18),
            ),
            title: Text(
              term?['term']?.toString() ?? 'Term ${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            children: [
              Text(
                term?['definition']?.toString() ?? 'No definition',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
