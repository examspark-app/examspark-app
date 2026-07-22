import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:examspark_frontend/core/services/quiz_attempt_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/select_ai/selectable_study_text.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_action_bar.dart';
import 'package:examspark_frontend/presentation/widgets/study_workspace/workspace_progress_bar.dart';

/// Extra Features Rendering Widgets
/// Modular minimalist views for MCQ, Flashcards, and RAG Chat

// ==================== MCQ QUIZ VIEW ====================

class MCQQuizView extends StatefulWidget {
  final List<MCQQuestion> questions;
  final String? lectureId;
  final VoidCallback? onOpenRevision;
  final VoidCallback? onGenerateNewQuiz;

  const MCQQuizView({
    super.key,
    required this.questions,
    this.lectureId,
    this.onOpenRevision,
    this.onGenerateNewQuiz,
  });

  @override
  State<MCQQuizView> createState() => _MCQQuizViewState();
}

class _MCQQuizViewState extends State<MCQQuizView> {
  int _currentQuestionIndex = 0;
  final Map<int, String?> _selectedAnswers = {};
  final Map<int, bool> _submittedQuestions = {};
  bool _showCompletion = false;
  bool _attemptSaved = false;

  @override
  void didUpdateWidget(covariant MCQQuizView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questions != widget.questions) {
      _currentQuestionIndex = 0;
      _selectedAnswers.clear();
      _submittedQuestions.clear();
      _showCompletion = false;
      _attemptSaved = false;
    }
  }

  void _retryQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswers.clear();
      _submittedQuestions.clear();
      _showCompletion = false;
      _attemptSaved = false;
    });
  }

  Future<void> _persistAttemptOnce() async {
    if (_attemptSaved) return;
    final lectureId = widget.lectureId?.trim();
    if (lectureId == null || lectureId.isEmpty) return;
    final total = widget.questions.length;
    if (total <= 0) return;
    _attemptSaved = true;
    await QuizAttemptService.instance.recordAttempt(
      lectureId: lectureId,
      score: _score,
      total: total,
    );
  }

  int get _score {
    var correct = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      if (_submittedQuestions[i] == true &&
          _selectedAnswers[i] == widget.questions[i].correctAnswer) {
        correct++;
      }
    }
    return correct;
  }

  List<String> get _weakTopics {
    final topics = <String>[];
    for (var i = 0; i < widget.questions.length; i++) {
      if (_submittedQuestions[i] != true) continue;
      if (_selectedAnswers[i] == widget.questions[i].correctAnswer) continue;
      final q = widget.questions[i].question.trim();
      if (q.isEmpty) continue;
      final words = q
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 4)
          .take(3)
          .join(' ');
      if (words.isNotEmpty) topics.add(words);
    }
    return topics.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: AppTheme.getSecondaryText(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No questions available',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_showCompletion) {
      return _buildCompletion(context);
    }

    final currentQuestion = widget.questions[_currentQuestionIndex];
    final isSubmitted = _submittedQuestions[_currentQuestionIndex] ?? false;
    final selectedAnswer = _selectedAnswers[_currentQuestionIndex];
    final isCorrect = selectedAnswer == currentQuestion.correctAnswer;
    final total = widget.questions.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.screenPadding,
            AppTheme.screenPadding,
            8,
          ),
          child: WorkspaceProgressBar(
            current: _currentQuestionIndex + 1,
            total: total,
            label: 'Question',
            remainingSuffix: 'questions remaining',
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  currentQuestion.question,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 24),
                ...currentQuestion.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final optionLetter = String.fromCharCode(65 + index);
                  final isSelected = selectedAnswer == optionLetter;
                  final isCorrectOption =
                      optionLetter == currentQuestion.correctAnswer;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OptionButton(
                      letter: optionLetter,
                      text: option,
                      isSelected: isSelected,
                      isAnswered: isSubmitted,
                      isCorrectOption: isCorrectOption,
                      onTap: isSubmitted
                          ? null
                          : () => setState(
                                () => _selectedAnswers[_currentQuestionIndex] =
                                    optionLetter,
                              ),
                    ),
                  );
                }),
                if (isSubmitted) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppTheme.getAccentTint(context)
                          : Colors.red.withOpacity(0.06),
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(
                        color: isCorrect
                            ? AppTheme.accentColor.withOpacity(0.35)
                            : Colors.red.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: isCorrect ? AppTheme.accentColor : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isCorrect ? 'Correct' : 'Incorrect',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isCorrect
                                        ? AppTheme.accentColor
                                        : Colors.red,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildExplanation(context, currentQuestion),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentQuestionIndex > 0
                      ? () => setState(() => _currentQuestionIndex--)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.getCardBackground(context),
                    foregroundColor: AppTheme.getPrimaryText(context),
                    disabledBackgroundColor: AppTheme.getCardBorder(context),
                  ),
                  child: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _primaryAction(isSubmitted, selectedAnswer),
                  child: Text(_primaryLabel(isSubmitted)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  VoidCallback? _primaryAction(bool isSubmitted, String? selected) {
    if (!isSubmitted) {
      if (selected == null) return null;
      return () => setState(() {
            _submittedQuestions[_currentQuestionIndex] = true;
          });
    }
    if (_currentQuestionIndex < widget.questions.length - 1) {
      return () => setState(() => _currentQuestionIndex++);
    }
    return () {
      setState(() => _showCompletion = true);
      _persistAttemptOnce();
    };
  }

  String _primaryLabel(bool isSubmitted) {
    if (!isSubmitted) return 'Submit';
    if (_currentQuestionIndex < widget.questions.length - 1) {
      return 'Next Question';
    }
    return 'See Results';
  }

  Widget _buildExplanation(BuildContext context, MCQQuestion q) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.accentColor),
            const SizedBox(width: 8),
            Text(
              'Explanation',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          q.explanation ?? 'No explanation provided',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
        ),
      ],
    );

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: body,
    );

    if (widget.lectureId == null) return card;
    return SelectableStudyText(
      lectureId: widget.lectureId!,
      sourceSurface: 'quiz',
      child: card,
    );
  }

  Widget _buildCompletion(BuildContext context) {
    final total = widget.questions.length;
    final score = _score;
    final accuracy = total == 0 ? 0 : ((score / total) * 100).round();
    final weak = _weakTopics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(Icons.emoji_events_outlined, size: 48, color: AppTheme.accentColor),
          const SizedBox(height: 12),
          Text(
            'Quiz Complete',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
          _statCard(context, 'Score', '$score / $total'),
          const SizedBox(height: 10),
          _statCard(context, 'Accuracy', '$accuracy%'),
          const SizedBox(height: 16),
          Text(
            'Weak Topics',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (weak.isEmpty)
            Text(
              'Nice work — no weak topics spotted this round.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final t in weak)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $t',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          const SizedBox(height: 20),
          if (widget.onOpenRevision != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenRevision,
              icon: const Icon(Icons.assignment_outlined, size: 18),
              label: const Text('Recommended Revision'),
            ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _retryQuiz,
            child: const Text('Retry Quiz'),
          ),
          if (widget.onGenerateNewQuiz != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: widget.onGenerateNewQuiz,
              child: const Text('Generate New Quiz'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String letter;
  final String text;
  final bool isSelected;
  final bool isAnswered;
  final bool isCorrectOption;
  final VoidCallback? onTap;

  const _OptionButton({
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.isAnswered,
    required this.isCorrectOption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late Color backgroundColor;
    late Color borderColor;
    late Color textColor;

    if (isAnswered) {
      if (isSelected && isCorrectOption) {
        backgroundColor = AppTheme.getAccentTint(context);
        borderColor = AppTheme.accentColor;
        textColor = AppTheme.accentColor;
      } else if (isSelected && !isCorrectOption) {
        backgroundColor = Colors.transparent;
        borderColor = Colors.red.shade400;
        textColor = AppTheme.getPrimaryText(context);
      } else if (!isSelected && isCorrectOption) {
        backgroundColor = AppTheme.getAccentTint(context);
        borderColor = AppTheme.accentColor;
        textColor = AppTheme.accentColor;
      } else {
        backgroundColor = Colors.transparent;
        borderColor = AppTheme.getCardBorder(context);
        textColor = AppTheme.getSecondaryText(context);
      }
    } else {
      if (isSelected) {
        backgroundColor = AppTheme.getCardBackground(context);
        borderColor = AppTheme.getPrimaryText(context);
        textColor = AppTheme.getPrimaryText(context);
      } else {
        backgroundColor = Colors.transparent;
        borderColor = AppTheme.getCardBorder(context);
        textColor = AppTheme.getPrimaryText(context);
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(
            color: borderColor,
            width: isSelected || (isAnswered && isCorrectOption) ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text, style: TextStyle(color: textColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class MCQQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String? explanation;

  MCQQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
  });

  factory MCQQuestion.fromJson(Map<String, dynamic> json) {
    return MCQQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? '',
      explanation: json['explanation'],
    );
  }
}

// ==================== FLASHCARD STACK VIEW ====================

class FlashcardStackView extends StatefulWidget {
  final List<Flashcard> flashcards;
  final String? lectureId;

  const FlashcardStackView({
    super.key,
    required this.flashcards,
    this.lectureId,
  });

  @override
  State<FlashcardStackView> createState() => _FlashcardStackViewState();
}

class _FlashcardStackViewState extends State<FlashcardStackView>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late List<int> _order;
  int _currentIndex = 0;
  bool _isFlipped = false;
  final Set<int> _bookmarked = {};
  final Set<int> _difficult = {};
  bool _reviewDifficultOnly = false;

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.flashcards.length, (i) => i);
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadLocalPrefs();
  }

  @override
  void didUpdateWidget(covariant FlashcardStackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flashcards != widget.flashcards) {
      _order = List.generate(widget.flashcards.length, (i) => i);
      _currentIndex = 0;
      _isFlipped = false;
      _flipController.reset();
      _loadLocalPrefs();
    }
  }

  Future<void> _loadLocalPrefs() async {
    final id = widget.lectureId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    final bm = prefs.getStringList('fc_bm_$id') ?? [];
    final df = prefs.getStringList('fc_df_$id') ?? [];
    if (!mounted) return;
    setState(() {
      _bookmarked
        ..clear()
        ..addAll(bm.map(int.tryParse).whereType<int>());
      _difficult
        ..clear()
        ..addAll(df.map(int.tryParse).whereType<int>());
    });
  }

  Future<void> _persistLocalPrefs() async {
    final id = widget.lectureId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'fc_bm_$id',
      _bookmarked.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      'fc_df_$id',
      _difficult.map((e) => e.toString()).toList(),
    );
  }

  List<int> get _visibleOrder {
    if (!_reviewDifficultOnly) return _order;
    final filtered = _order.where(_difficult.contains).toList();
    return filtered.isEmpty ? _order : filtered;
  }

  int get _cardSourceIndex => _visibleOrder[_currentIndex];

  void _flipCard() {
    setState(() => _isFlipped = !_isFlipped);
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _nextCard() {
    if (_currentIndex < _visibleOrder.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
      _flipController.reverse();
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
      _flipController.reverse();
    }
  }

  void _shuffle() {
    setState(() {
      _order.shuffle(Random());
      _currentIndex = 0;
      _isFlipped = false;
      _reviewDifficultOnly = false;
    });
    _flipController.reverse();
  }

  void _toggleBookmark() {
    final idx = _cardSourceIndex;
    setState(() {
      if (_bookmarked.contains(idx)) {
        _bookmarked.remove(idx);
      } else {
        _bookmarked.add(idx);
      }
    });
    _persistLocalPrefs();
  }

  void _toggleDifficult() {
    final idx = _cardSourceIndex;
    setState(() {
      if (_difficult.contains(idx)) {
        _difficult.remove(idx);
      } else {
        _difficult.add(idx);
      }
    });
    _persistLocalPrefs();
  }

  void _toggleReviewDifficult() {
    setState(() {
      _reviewDifficultOnly = !_reviewDifficultOnly;
      _currentIndex = 0;
      _isFlipped = false;
    });
    _flipController.reverse();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  String _conceptLabel(Flashcard card) {
    final t = card.front.trim();
    if (t.length <= 24) return t;
    return '${t.substring(0, 24)}…';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style_outlined,
              size: 64,
              color: AppTheme.getSecondaryText(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No flashcards available',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final visible = _visibleOrder;
    if (visible.isEmpty) {
      return const Center(child: Text('No cards to show'));
    }
    final safeIndex = _currentIndex.clamp(0, visible.length - 1);
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = safeIndex);
      });
    }

    final sourceIdx = visible[safeIndex];
    final currentCard = widget.flashcards[sourceIdx];
    final isBookmarked = _bookmarked.contains(sourceIdx);
    final isDifficult = _difficult.contains(sourceIdx);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: WorkspaceProgressBar(
            current: safeIndex + 1,
            total: visible.length,
            label: 'Card',
            remainingSuffix: 'cards remaining',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: WorkspaceActionBar(
            actions: [
              WorkspaceActionItem(
                icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                tooltip: 'Bookmark card',
                active: isBookmarked,
                onPressed: _toggleBookmark,
              ),
              WorkspaceActionItem(
                icon: Icons.flag_outlined,
                tooltip: isDifficult ? 'Unmark difficult' : 'Mark difficult',
                active: isDifficult,
                onPressed: _toggleDifficult,
              ),
              WorkspaceActionItem(
                icon: Icons.shuffle,
                tooltip: 'Shuffle',
                onPressed: _shuffle,
              ),
              WorkspaceActionItem(
                icon: Icons.filter_list,
                tooltip: _difficult.isEmpty
                    ? 'Mark cards difficult to review later'
                    : (_reviewDifficultOnly
                        ? 'Show all cards'
                        : 'Review difficult only'),
                active: _reviewDifficultOnly,
                onPressed: _difficult.isEmpty ? null : _toggleReviewDifficult,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _badge(
                context,
                _conceptLabel(currentCard),
                AppTheme.getAccentTint(context),
                AppTheme.accentColor,
              ),
              if (isDifficult) ...[
                const SizedBox(width: 8),
                _badge(
                  context,
                  'Hard',
                  Colors.orange.withOpacity(0.12),
                  Colors.orange.shade800,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final angle = _flipAnimation.value * 3.14159;
                  final showBack = _flipAnimation.value >= 0.5;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(3.14159),
                            child: _buildCardBack(currentCard),
                          )
                        : _buildCardFront(currentCard),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: safeIndex > 0 ? _previousCard : null,
                  child: const Text('Previous'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Card ${safeIndex + 1} of ${visible.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      safeIndex < visible.length - 1 ? _nextCard : null,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(
    BuildContext context,
    String label,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }

  Widget _buildCardFront(Flashcard card) {
    return Container(
      width: 320,
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                card.front,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Text(
            'Tap to reveal answer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(Flashcard card) {
    return Container(
      width: 320,
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.accentColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.back,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                color: AppTheme.accentColor,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class Flashcard {
  final String front;
  final String back;

  Flashcard({
    required this.front,
    required this.back,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      front: json['front'] ?? json['question'] ?? '',
      back: json['back'] ?? json['answer'] ?? '',
    );
  }
}

// ==================== IMPORTANT QUESTIONS VIEW ====================

class ImportantQuestion {
  final String question;
  final String type;
  final int marks;
  final String? hint;

  ImportantQuestion({
    required this.question,
    required this.type,
    required this.marks,
    this.hint,
  });

  factory ImportantQuestion.fromJson(Map<String, dynamic> json) {
    return ImportantQuestion(
      question: json['question']?.toString() ?? '',
      type: json['type']?.toString() ?? 'short_answer',
      marks: (json['marks'] as num?)?.toInt() ?? 2,
      hint: json['hint']?.toString(),
    );
  }
}

class ImportantQuestionsView extends StatelessWidget {
  final List<ImportantQuestion> questions;

  const ImportantQuestionsView({
    super.key,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions available',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      itemCount: questions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final q = questions[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.getCardBackground(context),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(color: AppTheme.getCardBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Q${index + 1}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${q.marks} marks',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                q.question,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              if (q.hint != null && q.hint!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Hint: ${q.hint}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ==================== MIND MAP VIEW ====================

class MindMapNodeData {
  final String label;
  final List<MindMapNodeData> children;

  MindMapNodeData({
    required this.label,
    required this.children,
  });

  factory MindMapNodeData.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List? ?? [];
    return MindMapNodeData(
      label: json['label']?.toString() ?? '',
      children: rawChildren
          .whereType<Map>()
          .map((c) => MindMapNodeData.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }
}

class MindMapView extends StatelessWidget {
  final String title;
  final MindMapNodeData? root;

  const MindMapView({
    super.key,
    required this.title,
    required this.root,
  });

  @override
  Widget build(BuildContext context) {
    if (root == null || root!.label.isEmpty) {
      return Center(
        child: Text(
          'No mind map available',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        _MindMapBranch(node: root!, depth: 0),
      ],
    );
  }
}

class _MindMapBranch extends StatelessWidget {
  final MindMapNodeData node;
  final int depth;

  const _MindMapBranch({
    required this.node,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final leftPad = 12.0 * depth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: leftPad, bottom: 8, top: depth == 0 ? 0 : 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (depth > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Icon(
                    Icons.subdirectory_arrow_right,
                    size: 16,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: depth == 0
                        ? AppTheme.getAccentTint(context)
                        : AppTheme.getCardBackground(context),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    border: Border.all(
                      color: depth == 0
                          ? AppTheme.accentColor.withOpacity(0.4)
                          : AppTheme.getCardBorder(context),
                    ),
                  ),
                  child: Text(
                    node.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...node.children.map(
          (child) => _MindMapBranch(node: child, depth: depth + 1),
        ),
      ],
    );
  }
}

// ==================== RAG CHAT BOTTOM SHEET ====================

class RagChatBottomSheet extends StatefulWidget {
  final String lectureId;
  final List<ChatMessage>? initialMessages;

  const RagChatBottomSheet({
    super.key,
    required this.lectureId,
    this.initialMessages,
  });

  @override
  State<RagChatBottomSheet> createState() => _RagChatBottomSheetState();
}

class _RagChatBottomSheetState extends State<RagChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessages != null) {
      _messages.addAll(widget.initialMessages!);
    }
  }

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

    _scrollToBottom();

    try {
      // Simulate RAG API call
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _messages.add(ChatMessage(
          text: 'This is a simulated RAG response. In production, this would be grounded in the lecture context using vector similarity search.',
          isUser: false,
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (error) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Failed to get response. Please try again.',
          isUser: false,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Text(
                  'Ask about this lecture',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingIndicator();
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
                      hintText: 'Ask a question about this lecture...',
                      hintStyle: TextStyle(
                        color: AppTheme.getSecondaryText(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: AppTheme.getCardBorder(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: AppTheme.getCardBorder(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: AppTheme.accentColor,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
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
                    minimumSize: const Size(48, 48),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.isUser)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.getCardBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.getCardBorder(context),
                ),
              ),
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.getSecondaryText(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.getSecondaryText(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.getSecondaryText(context),
              shape: BoxShape.circle,
            ),
          ),
        ],
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

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}
