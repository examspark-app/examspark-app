import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Extra Features Rendering Widgets
/// Modular minimalist views for MCQ, Flashcards, and RAG Chat

// ==================== MCQ QUIZ VIEW ====================

class MCQQuizView extends StatefulWidget {
  final List<MCQQuestion> questions;

  const MCQQuizView({
    super.key,
    required this.questions,
  });

  @override
  State<MCQQuizView> createState() => _MCQQuizViewState();
}

class _MCQQuizViewState extends State<MCQQuizView> {
  int _currentQuestionIndex = 0;
  final Map<int, String?> _selectedAnswers = {};
  final Map<int, bool> _answeredQuestions = {};

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

    final currentQuestion = widget.questions[_currentQuestionIndex];
    final isAnswered = _answeredQuestions[_currentQuestionIndex] ?? false;
    final selectedAnswer = _selectedAnswers[_currentQuestionIndex];
    final isCorrect = selectedAnswer == currentQuestion.correctAnswer;

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Row(
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${((_currentQuestionIndex + 1) / widget.questions.length * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // Question
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentQuestion.question,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Options
                ...currentQuestion.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final optionLetter = String.fromCharCode(65 + index); // A, B, C, D
                  final isSelected = selectedAnswer == optionLetter;
                  final isCorrectOption = optionLetter == currentQuestion.correctAnswer;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OptionButton(
                      letter: optionLetter,
                      text: option,
                      isSelected: isSelected,
                      isAnswered: isAnswered,
                      isCorrectOption: isCorrectOption,
                      onTap: isAnswered ? null : () => _selectAnswer(optionLetter),
                    ),
                  );
                }),

                // Explanation hint
                if (isAnswered) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.getAccentTint(context),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      border: Border.all(
                        color: AppTheme.accentColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppTheme.accentColor,
                            ),
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
                          currentQuestion.explanation ?? 'No explanation provided',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Navigation buttons
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
                  onPressed: _currentQuestionIndex < widget.questions.length - 1
                      ? () => setState(() => _currentQuestionIndex++)
                      : null,
                  child: Text(
                    _currentQuestionIndex < widget.questions.length - 1
                        ? 'Next'
                        : 'Finish',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectAnswer(String optionLetter) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = optionLetter;
      _answeredQuestions[_currentQuestionIndex] = true;
    });
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
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine styling based on state
    Color? backgroundColor;
    Color? borderColor;
    Color? textColor;

    if (isAnswered) {
      if (isSelected && isCorrectOption) {
        // Correct answer selected
        backgroundColor = AppTheme.getAccentTint(context);
        borderColor = AppTheme.accentColor;
        textColor = AppTheme.accentColor;
      } else if (isSelected && !isCorrectOption) {
        // Wrong answer selected
        backgroundColor = Colors.transparent;
        borderColor = AppTheme.getPrimaryText(context);
        textColor = AppTheme.getPrimaryText(context);
      } else if (!isSelected && isCorrectOption) {
        // Show correct answer
        backgroundColor = AppTheme.getAccentTint(context);
        borderColor = AppTheme.accentColor;
        textColor = AppTheme.accentColor;
      } else {
        // Unselected option
        backgroundColor = Colors.transparent;
        borderColor = AppTheme.getCardBorder(context);
        textColor = AppTheme.getSecondaryText(context);
      }
    } else {
      // Not answered yet
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
            color: borderColor!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor!,
                  width: 1,
                ),
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
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                ),
              ),
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

  const FlashcardStackView({
    super.key,
    required this.flashcards,
  });

  @override
  State<FlashcardStackView> createState() => _FlashcardStackViewState();
}

class _FlashcardStackViewState extends State<FlashcardStackView>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _nextCard() {
    if (_currentIndex < widget.flashcards.length - 1) {
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

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
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

    final currentCard = widget.flashcards[_currentIndex];

    return Column(
      children: [
        // Card counter
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Text(
            'Card ${_currentIndex + 1} of ${widget.flashcards.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        // Flashcard
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_flipAnimation.value * 3.14159),
                    child: child,
                  );
                },
                child: _isFlipped
                    ? _buildCardBack(currentCard)
                    : _buildCardFront(currentCard),
              ),
            ),
          ),
        ),

        // Navigation buttons
        Padding(
          padding: const EdgeInsets.all(AppTheme.screenPadding),
          child: Row(
            children: [
              IconButton(
                onPressed: _currentIndex > 0 ? _previousCard : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 32,
              ),
              const Spacer(),
              IconButton(
                onPressed: _currentIndex < widget.flashcards.length - 1
                    ? _nextCard
                    : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 32,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardFront(Flashcard card) {
    return Container(
      width: 320,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
          width: 1,
        ),
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
          card.front,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCardBack(Flashcard card) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(3.14159),
      child: Container(
        width: 320,
        height: 200,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.getAccentTint(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(
            color: AppTheme.accentColor,
            width: 1,
          ),
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
