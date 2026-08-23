import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart'
    as app_supabase;
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class GlowGuideScreen extends StatefulWidget {
  const GlowGuideScreen({super.key});

  @override
  State<GlowGuideScreen> createState() => _GlowGuideScreenState();
}

class _GlowGuideScreenState extends State<GlowGuideScreen> {
  static const _categories = [
    ('Skin Care', Icons.face_retouching_natural_outlined),
    ('Body Care', Icons.spa_outlined),
    ('Baby Skin Care', Icons.child_friendly_outlined),
    ('Cloth Guide', Icons.checkroom_outlined),
  ];

  static const _typeOwnOption = 'Something else — I\'ll type it';

  static const _concernsByCategory = {
    'skin': [
      'Acne / pimples',
      'Dark spots',
      'Dryness',
      'Oily skin',
      'Check a product label',
    ],
    'body': [
      'Body odor',
      'Dryness / patches',
      'Stretch marks',
      'Check a product label',
    ],
    'baby': [
      'Diaper rash',
      'Dry / sensitive skin',
      'New product check',
      'Other concern',
    ],
    'cloth': [
      'Check fabric composition',
      'Baby-safe check',
      'Season suitability',
      'Care instructions',
    ],
  };

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _messages = <_GlowMessage>[];
  Uint8List? _attachment;
  String? _attachmentName;
  String? _category;
  String? _sessionId;
  bool _sending = false;
  bool _processingPhoto = false;
  bool _showLanguageStep = true;
  String _preferredLanguage = 'MATCH_QUESTION';
  bool _hasLoadedPreferredLanguage = false;
  String? _lastSubmittedKey;
  final List<String> _languageOptions = const [
    'English',
    'Hindi',
    'Bengali',
    'Auto-detect',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferredLanguage();
  }

  void _showLanguageChoice() {
    if (!mounted) return;
    setState(() {
      _messages.add(
        _GlowMessage(
          'Which language would you like to chat in?',
          false,
          chips: _languageOptions,
          isLanguageChips: true,
        ),
      );
    });
  }

  Future<void> _loadPreferredLanguage() async {
    if (!app_supabase.SupabaseClient.instance.isInitialized) {
      if (!mounted) return;
      setState(() => _hasLoadedPreferredLanguage = true);
      _showLanguageChoice();
      return;
    }
    final user = app_supabase.SupabaseClient.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _hasLoadedPreferredLanguage = true);
      _showLanguageChoice();
      return;
    }
    try {
      final bundle = await app_supabase.SupabaseClient.instance
          .fetchStudentOnboardingBundle(user.id);
      final sp = bundle['student_profiles'];
      final raw = (sp is Map ? sp['preferred_language'] : null) as String?;
      final value = (raw ?? '').trim();
      if (value.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _preferredLanguage = value;
          _showLanguageStep = false;
          _hasLoadedPreferredLanguage = true;
        });
        _showCategoryChoices();
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _hasLoadedPreferredLanguage = true);
    _showLanguageChoice();
  }

  Future<void> _savePreferredLanguage(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    if (!app_supabase.SupabaseClient.instance.isInitialized) return;
    final user = app_supabase.SupabaseClient.instance.currentUser;
    if (user == null) return;
    _preferredLanguage = clean;
    await app_supabase.SupabaseClient.instance.saveGlowGuideLanguagePreference(
      user.id,
      clean,
    );
  }

  void _showCategoryChoices() {
    if (!mounted) return;
    setState(() {
      _showLanguageStep = false;
      if (!_messages.any((message) => message.chips.isNotEmpty)) {
        _messages.add(
          _GlowMessage(
            'Choose a guide:',
            false,
            chips: _categories.map((item) => item.$1).toList(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 3200,
      maxHeight: 3200,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _attachment = bytes;
      _attachmentName = image.name;
    });
  }

  Future<void> _previewPhoto() async {
    final bytes = _attachment;
    if (bytes == null) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Close preview',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                children: [
                  _PreviewAction(
                    label: 'Retake',
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _choosePhoto();
                    },
                  ),
                  const SizedBox(width: 8),
                  _PreviewAction(
                    label: 'Remove',
                    icon: Icons.delete_outline_rounded,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      setState(() {
                        _attachment = null;
                        _attachmentName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _categoryMap = {
    'Skin Care': 'skin',
    'Body Care': 'body',
    'Baby Skin Care': 'baby',
    'Cloth Guide': 'cloth',
  };

  Future<void> _selectCategory(String label) async {
    final selectedCategory = _categoryMap[label];
    if (selectedCategory == null) return;
    final concerns = [
      ..._concernsByCategory[selectedCategory] ?? const <String>[],
      _typeOwnOption,
    ];
    setState(() {
      _category = selectedCategory;
      _messages.add(
        _GlowMessage(
          'What would you like to check about your $label? Choose one, or just type your own question below — any language works.',
          false,
          chips: concerns,
          isConcernChips: true,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _selectConcern(String concern) async {
    if (concern == _typeOwnOption) {
      // No submission — the user is free to type their own concern, in
      // their own words and language, in the input box below.
      return;
    }
    _text.text = concern;
    await _send();
  }

  Future<void> _chooseLanguage(String option) async {
    if (option == 'Auto-detect') {
      _preferredLanguage = 'MATCH_QUESTION';
      await _savePreferredLanguage('MATCH_QUESTION');
    } else {
      _preferredLanguage = option;
      await _savePreferredLanguage(option);
    }
    if (mounted) _showCategoryChoices();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _text.text.trim();
    if (text.isEmpty && _attachment == null) return;
    _sending = true; // synchronous lock — closes the gap before setState fires
    final image = _attachment;
    final imageName = _attachmentName;
    final languageForRequest = _preferredLanguage;
    final submissionKey =
        '${_sessionId ?? 'new'}:${image != null ? 'photo' : 'text'}:${text.isEmpty ? 'photo' : text}:${DateTime.now().microsecondsSinceEpoch}';
    _lastSubmittedKey = submissionKey;
    setState(() {
      _sending = true;
      _processingPhoto = image != null;
      _messages.add(
        _GlowMessage(
          text.isEmpty ? 'Photo attached' : text,
          true,
          image: image,
          imageName: imageName,
        ),
      );
      _text.clear();
      _attachment = null;
      _attachmentName = null;
    });
    _scrollToBottom();
    try {
      final result = await LectureService.instance.glowGuideTurn(
        text: text,
        category: _category,
        sessionId: _sessionId,
        imageBytes: image,
        filename: imageName,
        language: languageForRequest,
      );
      if (!mounted || _lastSubmittedKey != submissionKey) return;
      final options =
          (result['question_options'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList() ??
          const <String>[];
      setState(() {
        _sessionId = result['session_id'] as String? ?? _sessionId;
        _category = result['category'] as String? ?? _category;
        _messages.add(
          _GlowMessage(
            result['reply'] as String? ?? 'I need a little more detail.',
            false,
            chips: options,
            verdict: result['verdict'] as String?,
            confidenceNote: result['confidence_note'] as String?,
          ),
        );
        _sending = false;
        _processingPhoto = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted || _lastSubmittedKey != submissionKey) return;
      setState(() {
        _sending = false;
        _processingPhoto = false;
        _messages.add(
          _GlowMessage(
            'Skin Care AI is unavailable right now. Please try again.',
            false,
          ),
        );
      });
    }
  }

  void _newChat() {
    if (_sending) return;
    setState(() {
      _sessionId = null;
      _category = null;
      _attachment = null;
      _attachmentName = null;
      _showLanguageStep =
          _preferredLanguage == 'MATCH_QUESTION' || _preferredLanguage.isEmpty;
      _messages.clear();
    });
    if (_showLanguageStep) {
      _showLanguageChoice();
    } else {
      _showCategoryChoices();
    }
  }

  Future<void> _openHistory() async {
    final sessions = await LectureService.instance.listGlowGuideSessions();
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Skin Care AI History')),
            for (final session in sessions)
              ListTile(
                leading: const Icon(Icons.eco_outlined),
                title: Text(
                  (session['category_type'] as String?) ?? 'Skin Care AI',
                ),
                subtitle: Text((session['updated_at'] as String?) ?? ''),
                onTap: () =>
                    Navigator.pop(sheetContext, session['id'] as String?),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final restored = await LectureService.instance.restoreGlowGuideSession(
      selected,
    );
    if (!mounted) return;
    final restoredMessages = (restored['messages'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (message) => _GlowMessage(
            message['message']?.toString() ?? '',
            message['role'] == 'user',
            imageUrl: message['image_url']?.toString(),
          ),
        )
        .toList();
    setState(() {
      _sessionId = selected;
      _category = restored['category'] as String?;
      _messages
        ..clear()
        ..addAll(restoredMessages);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _category == null
              ? 'Skin Care AI 🌿'
              : 'Skin Care AI 🌿 · $_category',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'New Skin Care AI chat',
            onPressed: _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'Skin Care AI history',
            onPressed: _sending ? null : _openHistory,
            icon: const Icon(Icons.history_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_hasLoadedPreferredLanguage) const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_sending && index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _processingPhoto
                          ? _PhotoAnalyzingBubble(
                              image: _messages.isNotEmpty
                                  ? _messages.last.image
                                  : null,
                            )
                          : const _PurpleTypingDots(),
                    ),
                  );
                }
                return _messageTile(_messages[index]);
              },
            ),
          ),
          const SizedBox(height: 8),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _messageTile(_GlowMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: message.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .86,
          ),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.image != null ||
                  (message.imageUrl?.isNotEmpty ?? false))
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _attachment = message.image;
                      _attachmentName = message.imageName;
                    });
                    _previewPhoto();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: message.image != null
                        ? Image.memory(
                            message.image!,
                            width: 180,
                            height: 140,
                            fit: BoxFit.cover,
                          )
                        : (message.imageUrl != null
                              ? Image.network(
                                  message.imageUrl!,
                                  width: 180,
                                  height: 140,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox.shrink()),
                  ),
                ),
              if (message.verdict != null) ...[
                const SizedBox(height: 8),
                _verdictBadge(message.verdict!),
              ],
              if (message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: AppTheme.getPrimaryText(context),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              if ((message.confidenceNote ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppTheme.getSecondaryText(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          message.confidenceNote!,
                          style: TextStyle(
                            color: AppTheme.getSecondaryText(context),
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppTheme.getCardBorder(context),
                      width: 1,
                    ),
                    color: AppTheme.getCardBackground(context),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.chips.map((chip) {
                      final isTypeOwn = chip == _typeOwnOption;
                      return ActionChip(
                        label: Text(
                          chip,
                          style: TextStyle(
                            color: isTypeOwn
                                ? AppTheme.glowGuidePurple
                                : AppTheme.getPrimaryText(context),
                            fontSize: 14,
                            fontWeight: isTypeOwn
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontStyle: isTypeOwn
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        backgroundColor: AppTheme.getCardBackground(context),
                        side: BorderSide(
                          color: AppTheme.glowGuidePurple.withValues(
                            alpha: isTypeOwn ? 0.55 : 0.3,
                          ),
                          width: 1,
                        ),
                        avatar: message.isLanguageChips
                            ? null
                            : Icon(
                                isTypeOwn
                                    ? Icons.edit_outlined
                                    : _iconFor(chip),
                                size: 16,
                                color: AppTheme.glowGuidePurple,
                              ),
                        onPressed: () {
                          if (message.isLanguageChips) {
                            _chooseLanguage(chip);
                          } else if (message.isConcernChips) {
                            _selectConcern(chip);
                          } else {
                            _selectCategory(chip);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String value) {
    for (final category in _categories) {
      if (category.$1 == value) return category.$2;
    }
    return Icons.check_rounded;
  }

  Widget _verdictBadge(String verdict) {
    final Color color;
    final IconData icon;
    final String label;
    switch (verdict) {
      case 'harmful':
        color = const Color(0xFFE05252);
        icon = Icons.warning_amber_rounded;
        label = 'Use with caution';
        break;
      case 'good_fit':
        color = const Color(0xFF40A85C);
        icon = Icons.check_circle_outline_rounded;
        label = 'Good fit';
        break;
      case 'careful':
        color = const Color(0xFFCC9A2E);
        icon = Icons.error_outline_rounded;
        label = 'Proceed carefully';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final hasPhoto = _attachment != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
          decoration: BoxDecoration(
            color: AppTheme.getCardBackground(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.getCardBorder(context)),
          ),
          child: Column(
            children: [
              if (hasPhoto)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: _previewPhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _attachment!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -7,
                          right: -7,
                          child: IconButton(
                            tooltip: 'Remove photo',
                            onPressed: () => setState(() {
                              _attachment = null;
                              _attachmentName = null;
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.getPrimaryText(context),
                              foregroundColor: AppTheme.getCardBackground(
                                context,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Add photo',
                    onPressed: _choosePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about skin, body care, or cloth...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.glowGuidePurpleLighter,
                          AppTheme.glowGuidePurple,
                        ],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowMessage {
  const _GlowMessage(
    this.text,
    this.isUser, {
    this.chips = const [],
    this.image,
    this.imageName,
    this.imageUrl,
    this.isLanguageChips = false,
    this.isConcernChips = false,
    this.verdict,
    this.confidenceNote,
  });
  final String text;
  final bool isUser;
  final List<String> chips;
  final Uint8List? image;
  final String? imageName;
  final String? imageUrl;
  final bool isLanguageChips;
  final bool isConcernChips;
  final String? verdict;
  final String? confidenceNote;
}

class _PurpleTypingDots extends StatefulWidget {
  const _PurpleTypingDots();

  @override
  State<_PurpleTypingDots> createState() => _PurpleTypingDotsState();
}

class _PurpleTypingDotsState extends State<_PurpleTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final phase = ((_controller.value * 3) - index).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Opacity(
              opacity: 0.35 + (phase * 0.65),
              child: const CircleAvatar(
                radius: 4,
                backgroundColor: Color(0xFF7C4DFF),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PhotoAnalyzingBubble extends StatefulWidget {
  const _PhotoAnalyzingBubble({required this.image});

  final Uint8List? image;

  @override
  State<_PhotoAnalyzingBubble> createState() => _PhotoAnalyzingBubbleState();
}

class _PhotoAnalyzingBubbleState extends State<_PhotoAnalyzingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.image == null) return const _PurpleTypingDots();
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => SizedBox(
        width: 120,
        height: 92,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                widget.image!,
                fit: BoxFit.cover,
                width: 120,
                height: 92,
              ),
            ),
            Positioned(
              top: _controller.value * 88,
              left: 0,
              right: 0,
              child: Container(height: 3, color: const Color(0xFF7C4DFF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  const _PreviewAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
    );
  }
}