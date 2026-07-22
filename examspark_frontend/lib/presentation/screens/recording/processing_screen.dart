import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/errors/lecture_user_message.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/utils/processing_time_estimate.dart';

/// Screen 3: Processing Screen
/// Full-screen distraction-free layout with real-time Supabase integration
class ProcessingScreen extends StatefulWidget {
  final String lectureId;

  /// Original upload bytes + args, forwarded from RecorderScreen so the
  /// Retry button can actually resend the same request instead of just
  /// resetting the progress bar. Null for lectures opened without them
  /// (e.g. a stale/refreshed page) — Retry falls back to "go back" then.
  final Uint8List? retryFileBytes;
  final String? retryFilename;
  final String? retrySourceType;
  final bool retryHighAccuracy;
  final int? retryDurationMinutes;

  /// YouTube Link → Notes retry (no file bytes).
  final String? retryYoutubeUrl;

  const ProcessingScreen({
    super.key,
    required this.lectureId,
    this.retryFileBytes,
    this.retryFilename,
    this.retrySourceType,
    this.retryHighAccuracy = false,
    this.retryDurationMinutes,
    this.retryYoutubeUrl,
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
  bool _isRetrying = false;
  bool _hasNavigatedToResult = false;
  String _errorMessage = '';
  StreamSubscription? _lectureSub;
  Timer? _statusPollTimer;
  Timer? _estimateTickTimer;
  late final ProcessingTimeEstimate _timeEstimate;
  late final DateTime _processingStartedAt;

  final List<ProcessingStep> _steps = const [
    ProcessingStep(
      icon: Icons.upload_file,
      title: 'Preparing & uploading...',
      subtitle: 'Getting your lecture ready',
    ),
    ProcessingStep(
      icon: Icons.transcribe,
      title: 'Listening to your lecture...',
      subtitle: 'Turning speech into text — long lectures take longer',
    ),
    ProcessingStep(
      icon: Icons.note_add,
      title: 'Generating your notes...',
      subtitle: 'Creating structured learning content',
    ),
    ProcessingStep(
      icon: Icons.check_circle_outline,
      title: 'Finalizing...',
      subtitle: 'Saving your notes',
    ),
  ];

  int get _currentStepIndex {
    switch (_currentStage) {
      case ProcessingStage.splitting:
        return 0;
      case ProcessingStage.transcribing:
        return 1;
      case ProcessingStage.generating:
      case ProcessingStage.indexing:
        return 2;
      case ProcessingStage.almostDone:
        return 3;
      case ProcessingStage.done:
        return _steps.length;
    }
  }

  @override
  void initState() {
    super.initState();
    _processingStartedAt = DateTime.now();
    _timeEstimate = ProcessingTimeEstimate.fromInputs(
      sourceType: widget.retrySourceType ??
          (widget.retryYoutubeUrl != null ? 'youtube_link' : 'recording'),
      durationMinutes: widget.retryDurationMinutes,
      fileBytes: widget.retryFileBytes?.length,
    );
    _initAnimation();
    _startRealtimeListener();
    _estimateTickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_hasNavigatedToResult && !_hasError) {
        setState(() {});
      }
    });
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  void _startRealtimeListener() {
    // Real-time listener on Supabase lectures table.
    // Stream WebSocket blips must NOT become sticky lecture failures (N101).
    final supabase = SupabaseClient.instance.client;

    _lectureSub?.cancel();
    _lectureSub = supabase
        .from('lectures')
        .stream(primaryKey: ['id'])
        .eq('id', widget.lectureId)
        .listen(
          (data) {
            if (data.isEmpty) return;

            final lecture = data.first;
            final status = lecture['status'] as String?;
            final errorMessage = lecture['error_message'] as String?;
            final duplicateOf = lecture['duplicate_of_lecture_id'] as String?;

            if (mounted) {
              _updateProgressBasedOnStatus(
                status,
                errorMessage: errorMessage,
                duplicateOfLectureId: duplicateOf,
              );
            }
          },
          onError: (error) {
            // Connection blip only — poll the row; do not show false error UI.
            debugPrint('lectures realtime stream error: $error');
            unawaited(_pollLectureStatusOnce());
            _scheduleStatusPollBackoff();
          },
        );
  }

  void _scheduleStatusPollBackoff() {
    _statusPollTimer?.cancel();
    // One short poll burst after realtime disconnects.
    var ticks = 0;
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      ticks++;
      unawaited(_pollLectureStatusOnce());
      if (ticks >= 10 || _hasNavigatedToResult || !mounted) {
        t.cancel();
      }
    });
  }

  Future<void> _pollLectureStatusOnce() async {
    if (!mounted || _hasNavigatedToResult) return;
    final row =
        await LectureService.instance.getLectureStatusRow(widget.lectureId);
    if (!mounted || row == null) return;
    _updateProgressBasedOnStatus(
      row['status'] as String?,
      errorMessage: row['error_message'] as String?,
      duplicateOfLectureId: row['duplicate_of_lecture_id'] as String?,
    );
  }

  void _updateProgressBasedOnStatus(
    String? status, {
    String? errorMessage,
    String? duplicateOfLectureId,
  }) {
    if (status == null) return;

    switch (status.toLowerCase()) {
      case 'splitting':
        setState(() {
          _currentStage = ProcessingStage.splitting;
          _progressValue = 0.15;
        });
        break;
      case 'transcribing':
        setState(() {
          _currentStage = ProcessingStage.transcribing;
          _progressValue = 0.40;
        });
        break;
      case 'indexing':
        // Legacy status — treat as notes generation (no fake jump to done).
        setState(() {
          _currentStage = ProcessingStage.generating;
          _progressValue = 0.70;
        });
        break;
      case 'generating':
        setState(() {
          _currentStage = ProcessingStage.generating;
          _progressValue = 0.70;
        });
        break;
      case 'almost_done':
        setState(() {
          _currentStage = ProcessingStage.almostDone;
          _progressValue = 0.90;
        });
        break;
      case 'done':
        final reusedId = duplicateOfLectureId;
        final isDup = reusedId != null && reusedId.trim().isNotEmpty;
        // Clear sticky false-errors from realtime blips so result can show.
        setState(() {
          _hasError = false;
          _errorMessage = '';
          _currentStage = ProcessingStage.done;
          _progressValue = 1.0;
        });
        // Auto-navigate to notes — original lecture when this was a duplicate.
        _navigateToNotesResult(
          targetLectureId: isDup ? reusedId.trim() : widget.lectureId,
          showDuplicateNotice: isDup,
        );
        break;
      case 'error':
        SystemSound.play(SystemSoundType.alert);
        setState(() {
          _hasError = true;
          // Map raw backend/DB error_message to student text + support code.
          // Technical detail stays in backend logs only.
          _errorMessage = lectureUserMessage(
            (errorMessage != null && errorMessage.trim().isNotEmpty)
                ? errorMessage.trim()
                : 'Processing failed',
          );
        });
        break;
    }
  }

  void _navigateToNotesResult({
    String? targetLectureId,
    bool showDuplicateNotice = false,
  }) {
    if (_hasNavigatedToResult) return;
    _hasNavigatedToResult = true;

    final id = (targetLectureId != null && targetLectureId.isNotEmpty)
        ? targetLectureId
        : widget.lectureId;
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      String title = 'Lecture';
      String? subject;
      try {
        final row = await SupabaseClient.instance.client
            .from('lectures')
            .select('title, subject')
            .eq('id', id)
            .maybeSingle();
        if (row != null) {
          title = row['title'] as String? ?? 'Lecture';
          subject = row['subject'] as String?;
        }
      } catch (_) {
        // Fall back to generic title; workspace still opens.
      }

      if (!mounted) return;

      // Clear recording/processing stack and open full-page result (like
      // old notes_result). Single pop left users stuck on Recording Setup
      // while workspace opened invisibly under AppShell.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/study_workspace',
        (route) => route.isFirst || route.settings.name == '/home',
        arguments: {
          'lectureId': id,
          'title': title,
          'subject': subject,
          'duplicateNotice': showDuplicateNotice,
        },
      );
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

  /// Actually re-sends the original file to the backend (previously this
  /// only reset the progress bar and never called the backend again, so
  /// Retry did nothing). Falls back to going back a screen if this
  /// ProcessingScreen was opened without the original bytes (e.g. a
  /// deep-link/refresh with no in-memory file to resend).
  Future<void> _retryProcessing() async {
    final youtubeUrl = widget.retryYoutubeUrl?.trim();
    final hasYoutube = youtubeUrl != null && youtubeUrl.isNotEmpty;
    if (!hasYoutube && widget.retryFileBytes == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _isRetrying = true;
      _hasError = false;
      _errorMessage = '';
      _currentStage = ProcessingStage.splitting;
      _progressValue = 0.0;
    });

    try {
      // Backend may already have finished while UI showed a false error.
      final existing =
          await LectureService.instance.getLectureStatusRow(widget.lectureId);
      final existingStatus =
          (existing?['status'] as String?)?.toLowerCase() ?? '';
      if (existingStatus == 'done') {
        final dup = existing?['duplicate_of_lecture_id'] as String?;
        _updateProgressBasedOnStatus(
          'done',
          duplicateOfLectureId: dup,
        );
        return;
      }

      if (hasYoutube) {
        await LectureService.instance.invokeYoutubeProcessing(
          lectureId: widget.lectureId,
          youtubeUrl: youtubeUrl,
        );
      } else {
        await LectureService.instance.invokeProcessing(
          lectureId: widget.lectureId,
          fileBytes: widget.retryFileBytes!,
          highAccuracy: widget.retryHighAccuracy,
          sourceType: widget.retrySourceType ?? 'recording',
          durationMinutes: widget.retryDurationMinutes,
          filename: widget.retryFilename ?? 'audio.webm',
        );
      }
      // Success path: the realtime listener above picks up 'transcribing' →
      // ... → 'done' and auto-navigates; nothing else to do here.
      await _pollLectureStatusOnce();
    } catch (e) {
      final raw = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (LectureService.isLikelyProcessNetworkFailure(e)) {
        final recovered = await LectureService.instance
            .recoverAfterProcessNetworkBlip(widget.lectureId);
        if (recovered) {
          await _pollLectureStatusOnce();
          final row = await LectureService.instance
              .getLectureStatusRow(widget.lectureId);
          final st = (row?['status'] as String?)?.toLowerCase() ?? '';
          if (st == 'done' && mounted) {
            _updateProgressBasedOnStatus(
              'done',
              duplicateOfLectureId: row?['duplicate_of_lecture_id'] as String?,
            );
          }
          return;
        }
      }
      final marked = await LectureService.instance.markErrorUnlessDone(
        widget.lectureId,
        raw,
      );
      if (!marked) {
        final row =
            await LectureService.instance.getLectureStatusRow(widget.lectureId);
        if (mounted) {
          _updateProgressBasedOnStatus(
            'done',
            duplicateOfLectureId: row?['duplicate_of_lecture_id'] as String?,
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = lectureUserMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  void dispose() {
    _estimateTickTimer?.cancel();
    _statusPollTimer?.cancel();
    _lectureSub?.cancel();
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
                                  color: AppTheme.accentColor.withValues(
                                    alpha: 0.1,
                                  ),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadius,
                          ),
                          border: Border.all(
                            color: AppTheme.getCardBorder(context),
                          ),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _progressValue,
                                minHeight: 6,
                                backgroundColor: AppTheme.getCardBorder(
                                  context,
                                ),
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
                            if (_currentStage != ProcessingStage.done) ...[
                              const SizedBox(height: 10),
                              Text(
                                _timeEstimate.headlineForStage(
                                  _estimateStageForUi(),
                                ),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.getPrimaryText(context),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _timeEstimate.elapsedLine(
                                  elapsed: DateTime.now().difference(
                                    _processingStartedAt,
                                  ),
                                  stage: _estimateStageForUi(),
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Staged step list
                      ...List.generate(_steps.length, (index) {
                        final step = _steps[index];
                        final isPast = index < _currentStepIndex;
                        final isCurrent =
                            index == _currentStepIndex &&
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadius,
                        ),
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
                  onPressed: _isRetrying ? null : _retryProcessing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                    ),
                  ),
                  child: _isRetrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Retry'),
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
        return Icons.upload_file;
      case ProcessingStage.transcribing:
        return Icons.transcribe;
      case ProcessingStage.indexing:
      case ProcessingStage.generating:
        return Icons.note_add;
      case ProcessingStage.almostDone:
        return Icons.check_circle_outline;
      case ProcessingStage.done:
        return Icons.check_circle;
    }
  }

  String _getStageTitle() {
    switch (_currentStage) {
      case ProcessingStage.splitting:
        return 'Preparing & uploading...';
      case ProcessingStage.transcribing:
        return 'Listening to your lecture...';
      case ProcessingStage.indexing:
      case ProcessingStage.generating:
        return 'Generating your notes...';
      case ProcessingStage.almostDone:
        return 'Finalizing...';
      case ProcessingStage.done:
        return 'Complete!';
    }
  }

  String _getStageSubtitle() {
    if (_currentStage == ProcessingStage.done) {
      return 'Your notes are ready';
    }
    return _timeEstimate.headlineForStage(_estimateStageForUi());
  }

  ProcessingEstimateStage _estimateStageForUi() {
    if (_currentStage == ProcessingStage.done) {
      return ProcessingEstimateStage.done;
    }
    final elapsed = DateTime.now().difference(_processingStartedAt);
    final base = switch (_currentStage) {
      ProcessingStage.splitting => ProcessingEstimateStage.preparing,
      ProcessingStage.transcribing => ProcessingEstimateStage.transcribing,
      ProcessingStage.indexing || ProcessingStage.generating =>
        ProcessingEstimateStage.notes,
      ProcessingStage.almostDone => ProcessingEstimateStage.tools,
      ProcessingStage.done => ProcessingEstimateStage.done,
    };
    if (elapsed.inSeconds > _timeEstimate.typicalHighSeconds &&
        base != ProcessingEstimateStage.done) {
      return ProcessingEstimateStage.overEstimate;
    }
    return base;
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
              color: isFuture ? AppTheme.getCardBorder(context) : accentColor,
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
                    color: isFuture ? AppTheme.getSecondaryText(context) : null,
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
