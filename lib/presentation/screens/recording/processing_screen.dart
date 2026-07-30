import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Screen 3: Processing Screen
/// Full-screen distraction-free layout with real-time Supabase integration
class ProcessingScreen extends StatefulWidget {
  final String lectureId;

  const ProcessingScreen({
    super.key,
    required this.lectureId,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  ProcessingStage _currentStage = ProcessingStage.splitting;
  double _progressValue = 0.0;
  bool _hasError = false;
  String _errorMessage = '';

  final List<ProcessingStep> _steps = const [
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

  int get _currentStepIndex {
    switch (_currentStage) {
      case ProcessingStage.splitting:
        return 0;
      case ProcessingStage.transcribing:
        return 1;
      case ProcessingStage.indexing:
        return 2;
      case ProcessingStage.generating:
      case ProcessingStage.almostDone:
        return 3;
      case ProcessingStage.done:
        return _steps.length;
    }
  }

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _startRealtimeListener();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  void _startRealtimeListener() {
    // Real-time listener on Supabase lectures table
    final supabase = SupabaseClient.instance.client;
    
    supabase
        .from('lectures')
        .stream(primaryKey: ['id'])
        .eq('id', widget.lectureId)
        .listen((data) {
      if (data.isEmpty) return;
      
      final lecture = data.first;
      final status = lecture['status'] as String?;
      
      if (mounted) {
        _updateProgressBasedOnStatus(status);
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to connect to server';
        });
      }
    });
  }

  void _updateProgressBasedOnStatus(String? status) {
    if (status == null) return;

    switch (status.toLowerCase()) {
      case 'splitting':
        setState(() {
          _currentStage = ProcessingStage.splitting;
          _progressValue = 0.25;
        });
        break;
      case 'transcribing':
        setState(() {
          _currentStage = ProcessingStage.transcribing;
          _progressValue = 0.50;
        });
        break;
      case 'indexing':
        setState(() {
          _currentStage = ProcessingStage.indexing;
          _progressValue = 0.75;
        });
        break;
      case 'generating':
        setState(() {
          _currentStage = ProcessingStage.generating;
          _progressValue = 0.90;
        });
        break;
      case 'almost_done':
        setState(() {
          _currentStage = ProcessingStage.almostDone;
          _progressValue = 0.95;
        });
        break;
      case 'done':
        setState(() {
          _currentStage = ProcessingStage.done;
          _progressValue = 1.0;
        });
        // Auto-navigate to notes result screen
        _navigateToNotesResult();
        break;
      case 'error':
        setState(() {
          _hasError = true;
          _errorMessage = 'Processing failed on server';
        });
        break;
    }
  }

  void _navigateToNotesResult() {
    // Small delay to show completion
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/notes_result',
          arguments: {'lectureId': widget.lectureId},
        );
      }
    });
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Stop processing?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Processing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Processing'),
          ),
        ],
      ),
    );
  }

  void _continueInBackground() {
    Navigator.pop(context);
    // Show notification when complete (would use local notifications plugin)
  }

  void _retryProcessing() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _currentStage = ProcessingStage.splitting;
      _progressValue = 0.0;
    });
    // Restart the pipeline by calling the backend again
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            children: [
              // Cancel button
              Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: _showCancelDialog,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // Progress overview + step list
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Animated icon + overall progress
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Opacity(
                              opacity: _opacityAnimation.value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  _getStageIcon(),
                                  size: 36,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getStageTitle(),
                        style: Theme.of(context).textTheme.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStageSubtitle(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.getCardBackground(context),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                          border: Border.all(color: AppTheme.getCardBorder(context)),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _progressValue,
                                minHeight: 6,
                                backgroundColor: AppTheme.getCardBorder(context),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _currentStage == ProcessingStage.done
                                      ? Colors.green
                                      : AppTheme.accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentStage == ProcessingStage.done
                                  ? 'Complete!'
                                  : 'Step ${_currentStepIndex.clamp(1, _steps.length)} of ${_steps.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Staged step list
                      ...List.generate(_steps.length, (index) {
                        final step = _steps[index];
                        final isPast = index < _currentStepIndex;
                        final isCurrent = index == _currentStepIndex &&
                            _currentStage != ProcessingStage.done;
                        final isFuture = !isPast && !isCurrent;
                        return _buildStepItem(
                          step: step,
                          isCurrent: isCurrent,
                          isPast: isPast,
                          isFuture: isFuture,
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Background mode hook
              Column(
                children: [
                  Text(
                    'You can leave this screen — we\'ll notify you when it\'s ready.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _continueInBackground,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      ),
                    ),
                    child: const Text('Continue in Background'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Alert icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),

              // Error heading
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Error subtext
              Text(
                _errorMessage.isNotEmpty ? _errorMessage : 'Please try again',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Retry button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _retryProcessing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStageIcon() {
    switch (_currentStage) {
      case ProcessingStage.splitting:
        return Icons.content_cut;
      case ProcessingStage.transcribing:
        return Icons.transcribe;
      case ProcessingStage.indexing:
        return Icons.search;
      case ProcessingStage.generating:
        return Icons.note_add;
      case ProcessingStage.almostDone:
      case ProcessingStage.done:
        return Icons.check_circle;
    }
  }

  String _getStageTitle() {
    switch (_currentStage) {
      case ProcessingStage.splitting:
        return 'Splitting audio into segments...';
      case ProcessingStage.transcribing:
        return 'Transcribing your lecture...';
      case ProcessingStage.indexing:
        return 'Saving for smart search...';
      case ProcessingStage.generating:
        return 'Generating your notes...';
      case ProcessingStage.almostDone:
        return 'Almost done...';
      case ProcessingStage.done:
        return 'Complete!';
    }
  }

  String _getStageSubtitle() {
    switch (_currentStage) {
      case ProcessingStage.splitting:
        return 'Preparing for parallel processing';
      case ProcessingStage.transcribing:
        return 'Converting speech to text using AI';
      case ProcessingStage.indexing:
        return 'Indexing for future Q&A';
      case ProcessingStage.generating:
        return 'Creating structured learning content';
      case ProcessingStage.almostDone:
        return 'Finalizing your notes';
      case ProcessingStage.done:
        return 'Your notes are ready';
    }
  }

  Widget _buildStepItem({
    required ProcessingStep step,
    required bool isCurrent,
    required bool isPast,
    required bool isFuture,
  }) {
    final accentColor = isPast ? Colors.green : AppTheme.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: isCurrent
              ? AppTheme.accentColor
              : isPast
                  ? Colors.green
                  : AppTheme.getCardBorder(context),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isFuture
                  ? AppTheme.getCardBorder(context)
                  : accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPast ? Icons.check : step.icon,
              color: isFuture
                  ? AppTheme.getSecondaryText(context)
                  : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isFuture
                        ? AppTheme.getSecondaryText(context)
                        : AppTheme.getPrimaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isFuture
                        ? AppTheme.getSecondaryText(context)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentColor,
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

  const ProcessingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

enum ProcessingStage {
  splitting,
  transcribing,
  indexing,
  generating,
  almostDone,
  done,
}
