import 'package:flutter/material.dart';

/// Screen 3: Processing Screen
/// Shows staged progress (not a single generic spinner)
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  int _currentStep = 0;
  bool _isComplete = false;

  final List<ProcessingStep> _steps = [
    ProcessingStep(
      icon: Icons.content_cut,
      title: 'Splitting audio into segments...',
      subtitle: 'Preparing for parallel processing',
    ),
    ProcessingStep(
      icon: Icons.transcribe,
      title: 'Transcribing...',
      subtitle: 'Converting speech to text using AI',
    ),
    ProcessingStep(
      icon: Icons.search,
      title: 'Saving for smart search (RAG)...',
      subtitle: 'Indexing for future Q&A',
    ),
    ProcessingStep(
      icon: Icons.note_add,
      title: 'Generating your notes...',
      subtitle: 'Creating structured learning content',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  void _startProcessing() {
    // Simulate processing steps
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _currentStep = 1);
    }).then((_) {
      return Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _currentStep = 2);
      });
    }).then((_) {
      return Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _currentStep = 3);
      });
    }).then((_) {
      return Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isComplete = true);
          _showCompletionNotification();
        }
      });
    });
  }

  void _showCompletionNotification() {
    // Show notification when complete
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Your notes are ready ✅'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Navigate to results after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/results');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress Overview
              Container(
                padding: const EdgeInsets.all(20),
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
                  children: [
                    // Overall Progress Bar
                    LinearProgressIndicator(
                      value: (_currentStep + 1) / _steps.length,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isComplete ? Colors.green : Colors.black87,
                      ),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isComplete ? 'Complete!' : 'Step ${_currentStep + 1} of ${_steps.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Staged Progress Steps
              Expanded(
                child: ListView.builder(
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    final isCurrent = index == _currentStep;
                    final isPast = index < _currentStep;
                    final isFuture = index > _currentStep;

                    return _buildStepItem(
                      step: step,
                      isCurrent: isCurrent,
                      isPast: isPast,
                      isFuture: isFuture,
                      index: index,
                    );
                  },
                ),
              ),
              
              // Background Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can background this app. We\'ll notify you when your notes are ready.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required ProcessingStep step,
    required bool isCurrent,
    required bool isPast,
    required bool isFuture,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? Colors.black87
              : isPast
                  ? Colors.green
                  : Colors.grey[300]!,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Step Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCurrent
                  ? Colors.black87
                  : isPast
                      ? Colors.green
                      : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPast ? Icons.check : step.icon,
              color: isCurrent || isPast ? Colors.white : Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Step Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isFuture ? Colors.grey[400] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isFuture ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Loading Indicator for Current Step
          if (isCurrent)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
              ),
            ),
        ],
      ),
    );
  }
}

class ProcessingStep {
  final IconData icon;
  final String title;
  final String subtitle;

  ProcessingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
