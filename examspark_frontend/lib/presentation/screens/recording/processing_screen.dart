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

              // Centered content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated icon
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _opacityAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentColor.withOpacity(0.1),
                              ),
                              child: Icon(
                                _getStageIcon(),
                                size: 48,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Stage text
                    Text(
                      _getStageTitle(),
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subtext
                    Text(
                      _getStageSubtitle(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Progress bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _progressValue,
                          minHeight: 4,
                          backgroundColor: AppTheme.getCardBorder(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Progress percentage
                    Text(
                      '${(_progressValue * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
}

enum ProcessingStage {
  splitting,
  transcribing,
  indexing,
  generating,
  almostDone,
  done,
}
