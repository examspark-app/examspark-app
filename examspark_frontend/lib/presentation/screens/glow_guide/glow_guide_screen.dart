import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart'
    as app_supabase;
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class GlowGuideScreen extends StatefulWidget {
  const GlowGuideScreen({super.key, this.startFresh = false});

  final bool startFresh;

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
  final _textFocus = FocusNode();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _messages = <_GlowMessage>[];
  Uint8List? _attachment;
  String? _attachmentName;
  String? _category;
  String? _age;
  String? _seasonWeather;
  String? _sessionId;
  bool _sending = false;
  bool _sessionComplete = false;
  bool _usedWebSearch = false;
  String? _webSearchStatus;
  bool _processingPhoto = false;
  String _preferredLanguage = 'MATCH_QUESTION';
  bool _hasLoadedPreferredLanguage = false;
  String? _lastSubmittedKey;
  String? _sessionTitle;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    if (widget.startFresh) {
      _showLanguageChoice();
    } else {
      _openLatestOrFresh();
    }
  }

  Future<void> _openLatestOrFresh() async {
    setState(() => _restoring = true);
    try {
      final didRestore = await _tryRestoreLatestSession();
      if (didRestore) return;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _restoring = false);
    _showLanguageChoice();
  }

  Future<bool> _tryRestoreLatestSession() async {
  final sessions = await LectureService.instance.listGlowGuideSessions();
if (sessions.isEmpty) return false;
final sorted = [...sessions]..sort((a, b) {
  final aTime = DateTime.tryParse(
        (a['updated_at'] ?? a['created_at'] ?? '').toString(),
      ) ??
      DateTime(1970);
  final bTime = DateTime.tryParse(
        (b['updated_at'] ?? b['created_at'] ?? '').toString(),
      ) ??
      DateTime(1970);
  return bTime.compareTo(aTime);
});
final latest = sorted.first;
    final id = latest['id']?.toString();
    if (id == null || id.isEmpty) return false;
    final restored =
        await LectureService.instance.restoreGlowGuideSession(id);
    if (!mounted) return true;
    final messageList = restored['messages'] as List? ?? const [];
    final restoredMessages = messageList
    .whereType<Map>()
    .map(
      (message) => _GlowMessage(
        message['message']?.toString() ?? '',
        message['role'] == 'user',
        imageUrl: message['image_url']?.toString(),
        chips: (message['question_options'] as List?)
                ?.map((c) => c.toString())
                .where((c) => c.trim().isNotEmpty)
                .toList() ??
            const [],
        verdict: message['verdict']?.toString(),
        confidenceNote: message['confidence_note']?.toString(),
        detailedBreakdown: message['detailed_breakdown']?.toString(),
      ),
    )
    .toList();
    final computedTitle =
        (restored['title']?.toString().trim().isNotEmpty ?? false)
            ? restored['title'].toString()
            : _deriveTitleFromMessages(restoredMessages);
    setState(() {
      _restoring = false;
      _sessionId = id;
      _category = restored['category'] as String?;
      _sessionTitle = computedTitle;
      _usedWebSearch = false;
      _sessionComplete =
          restored['status'] == 'archived' ||
          (restored['exchange_count'] as num? ?? 0) >= 100;
      _hasLoadedPreferredLanguage = true;
      _messages
        ..clear()
        ..addAll(restoredMessages);
    });
    _scrollToBottom();
    return true;
  }

  String _deriveTitleFromMessages(List<_GlowMessage> list) {
    _GlowMessage? firstUserMessage;
    for (final m in list) {
      if (m.isUser && m.text.trim().isNotEmpty) {
        firstUserMessage = m;
        break;
      }
    }
    final raw = firstUserMessage?.text.trim() ?? '';
    if (raw.isEmpty) return 'Skin Care AI';
    if (raw.length <= 56) return raw;
    return '${raw.substring(0, 53)}…';
  }

  void _showLanguageChoice() {
    if (!mounted) return;
    setState(() {
      _hasLoadedPreferredLanguage = true;
      _messages.add(
        _GlowMessage(
          'Which language would you like to chat in?\nPick a preset below, or type your own (हिन्दी, বাংলা, anything).',
          false,
          chips: const [
            'Auto-detect',
            'English',
            'Hindi',
            'Bengali',
            'Save & continue',
          ],
          isLanguageChips: true,
          hasCustomInput: true,
        ),
      );
    });
  }

  String? _lastCustomLanguageLabel;

  Future<void> _selectLanguage(String label) async {
    if (_sending) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == 'Save & continue') {
      final raw = _lastCustomLanguageLabel?.trim();
      final useLang = raw != null && raw.isNotEmpty
          ? raw
          : _preferredLanguage == 'MATCH_QUESTION'
          ? 'MATCH_QUESTION'
          : (_preferredLanguage.isEmpty ? 'MATCH_QUESTION' : _preferredLanguage);
      final code = useLang == 'Auto-detect' ? 'MATCH_QUESTION' : useLang;
      setState(() => _preferredLanguage = code);
      unawaited(_savePreferredLanguage(code));
      if (mounted) _showCategoryChoices();
      return;
    }
    final lang = trimmed == 'Auto-detect' ? 'MATCH_QUESTION' : trimmed;
    _lastCustomLanguageLabel = trimmed == 'Auto-detect' ? null : trimmed;
    setState(() => _preferredLanguage = lang);
    await _savePreferredLanguage(lang);
    if (mounted) _showCategoryChoices();
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

  String? _lastCustomCategoryLabel;

  void _showCategoryChoices() {
    if (!mounted) return;
    setState(() {
      if (!_messages.any((message) => message.chips.isNotEmpty && !message.isLanguageChips)) {
        _messages.add(
          _GlowMessage(
            'First, what do you need help with?\nPick a guide or type your own topic (e.g. hair care, kids dress).',
            false,
            chips: [
              ..._categories.map((item) => item.$1),
              'Save & continue',
            ],
            isCategoryChips: true,
            hasCustomInput: true,
          ),
        );
      }
    });
  }

  Future<void> _chooseTopCategory(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == 'Save & continue') {
      final raw = _lastCustomCategoryLabel?.trim();
      final hasCustom = raw != null && raw.isNotEmpty;
      if (!hasCustom && (_category == null || _category!.isEmpty)) return;
      if (hasCustom) {
        final key = _categoryKeyForLabel(raw) ?? raw.toLowerCase();
        _continueAfterCategoryChoice(key, raw);
        return;
      }
      // Preset category was already tapped — just move forward using it.
      final display = _category != null
          ? _prettyCategory(_category!)
          : null;
      _continueAfterCategoryChoice(_category!, display);
      return;
    }
    _lastCustomCategoryLabel = trimmed;
    final key = _categoryKeyForLabel(trimmed);
    if (key == null) {
      _continueAfterCategoryChoice(trimmed.toLowerCase(), trimmed);
      return;
    }
    _continueAfterCategoryChoice(key, trimmed);
  }

  String? _categoryKeyForLabel(String label) {
    for (final entry in _categoryMap.entries) {
      if (entry.key.trim().toLowerCase() == label.trim().toLowerCase()) {
        return entry.value;
      }
    }
    for (final c in _categories) {
      if (c.$1.trim().toLowerCase() == label.trim().toLowerCase()) {
        return _categoryMap[c.$1];
      }
    }
    return null;
  }

  void _continueAfterCategoryChoice(String key, String? display) {
    setState(() {
      _category = key;
      _sessionTitle ??= display ?? key;
      _messages.add(
        _GlowMessage(
          '${display ?? key} selected. What age should I consider for this guidance?',
          false,
          chips: const ['Baby', 'Child', 'Teen', 'Adult'],
          isAgeChips: true,
          hasCustomInput: true,
        ),
      );
    });
    _scrollToBottom();
  }

  void _selectAge(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    setState(() {
      _age = clean;
      _messages.add(
        _GlowMessage(
          'What season or weather should I consider?',
          false,
          chips: const ['Winter', 'Summer', 'Monsoon', 'Humid', 'Dry'],
          isSeasonChips: true,
          hasCustomInput: true,
        ),
      );
    });
    _scrollToBottom();
  }

  void _selectSeasonWeather(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final concerns = [
      ..._concernsByCategory[_category] ?? const <String>[],
      _typeOwnOption,
    ];
    setState(() {
      _seasonWeather = clean;
      _messages.add(
        _GlowMessage(
          'Thanks. What would you like to check?',
          false,
          chips: concerns,
          isConcernChips: true,
          categoryHeaderChips: [for (final c in _categories) c.$1],
        ),
      );
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _text.dispose();
    _textFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _focusTextInput() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_textFocus);
    });
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
    await _chooseTopCategory(label);
  }

  Future<void> _selectConcern(String concern) async {
    if (_sending) return;
    if (concern == _typeOwnOption) {
      _text.clear();
      _focusTextInput();
      return;
    }
    _sessionTitle ??= _niceTitleFromConcern(concern);
    _text.text = concern;
    _focusTextInput();
    await _send();
  }

  String _niceTitleFromConcern(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'Skin Care AI';
    if (t.length <= 56) return t;
    return '${t.substring(0, 53)}…';
  }

  Future<void> _send() async {
    if (_sending || _sessionComplete) return;
    final text = _text.text.trim();
    if (text.isEmpty && _attachment == null) return;
    _sending = true; // synchronous lock — closes the gap before setState fires
    final image = _attachment;
    final imageName = _attachmentName;
    final languageForRequest = _preferredLanguage;
    final submissionKey =
        '${_sessionId ?? 'new'}:${image != null ? 'photo' : 'text'}:${text.isEmpty ? 'photo' : text}:${DateTime.now().microsecondsSinceEpoch}';
    _lastSubmittedKey = submissionKey;
    if (_sessionTitle == null && text.trim().isNotEmpty) {
      _sessionTitle = _niceTitleFromConcern(text);
    }
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
      final result = await LectureService.instance.glowGuideTurnStream(
        text: text,
        category: _category,
        sessionId: _sessionId,
        age: _age,
        weather: _seasonWeather,
        imageBytes: image,
        filename: imageName,
        language: languageForRequest,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _webSearchStatus = status);
        },
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
            detailedBreakdown: result['detailed_breakdown'] as String?,
          ),
        );
        _sending = false;
        _processingPhoto = false;
        _sessionComplete = result['session_complete'] == true;
        _usedWebSearch = result['used_web_search'] == true;
        _webSearchStatus = null;
      });
      _scrollToBottom();
      if (_usedWebSearch) _showResearchSourceNotice();
      if (_sessionComplete) _promptNewChat();
    } catch (error) {
      if (!mounted || _lastSubmittedKey != submissionKey) return;
      setState(() {
        _sending = false;
        _processingPhoto = false;
        _webSearchStatus = null;
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
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => const GlowGuideScreen(startFresh: true),
    ),
  );
}

  void _showResearchSourceNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_usedWebSearch) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer checked with live web research.')),
      );
    });
  }

  void _promptNewChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sessionComplete) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Chat complete'),
          content: const Text(
            'This chat reached 100 exchanges. Start a new chat to continue with a fresh context.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _newChat();
              },
              child: const Text('New Chat'),
            ),
          ],
        ),
      );
    });
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
                  _deriveHistoryTitle(session),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
    final computedTitle =
        (restored['title']?.toString().trim().isNotEmpty ?? false)
            ? restored['title'].toString()
            : _deriveTitleFromMessages(restoredMessages);
    setState(() {
      _sessionId = selected;
      _category = restored['category'] as String?;
      _sessionTitle = computedTitle;
      _usedWebSearch = false;
      _sessionComplete =
          restored['status'] == 'archived' ||
          (restored['exchange_count'] as num? ?? 0) >= 100;
      _hasLoadedPreferredLanguage = true;
      _messages
        ..clear()
        ..addAll(restoredMessages);
    });
    _scrollToBottom();
  }

  String _deriveHistoryTitle(Map session) {
    final title = session['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    final category = (session['category_type'] as String?)?.trim();
    final preview = (session['first_message_preview'] as String?)?.trim();
    if (preview != null && preview.isNotEmpty) {
      final nice = preview.length <= 60 ? preview : '${preview.substring(0, 57)}…';
      return nice;
    }
    if (category != null && category.isNotEmpty) return category;
    return 'Skin Care AI';
  }

  static const _reverseCategoryMap = {
    'skin': 'Skin Care',
    'body': 'Body Care',
    'baby': 'Baby Skin Care',
    'cloth': 'Cloth Guide',
  };

  String _prettyCategory(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return 'Skin Care AI';
    if (_reverseCategoryMap.containsKey(r)) return _reverseCategoryMap[r]!;
    // fallback: sentence case first letter
    return '${r[0].toUpperCase()}${r.substring(1)}';
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
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final background =
        isDark ? AppTheme.darkBackground : const Color(0xFFFAF7FB);
    final textColor =
        isDark ? Colors.white : const Color(0xFF20182B);
    final subText =
        isDark ? Colors.white60 : Colors.black54;
    final divider =
        isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE9E5F3);
    final bubbleUser = isDark
        ? const Color(0xFF5137ED)
        : const Color(0xFF6F56FF);
    final bubbleAi =
        isDark ? const Color(0xFF1A1A1D) : Colors.white;
    final bubbleAiBorder =
        isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE9E5F3);
    final inputBg =
        isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF3EFFB);
    final inputBorder =
        isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE4DEF4);
    final chipBg =
        isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF6F3FB);
    final chipBorder =
        isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE3DDF3);
    final chipText =
        isDark ? Colors.white : const Color(0xFF3C375A);

    Widget renderTile(_GlowMessage message) {
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
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
                  ),
                if (message.verdict != null) ...[
                  const SizedBox(height: 6),
                  _verdictBadge(message.verdict!),
                  const SizedBox(height: 6),
                ],
                if (message.text.isNotEmpty)
                  message.isUser
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: bubbleUser,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: bubbleUser.withOpacity(isDark ? 0.18 : 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              height: 1.45,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: bubbleAi,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: bubbleAiBorder,
                              width: 0.8,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF000000)
                                          .withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: SelectionArea(
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E1B2C),
                                fontSize: 15.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                if ((message.confidenceNote ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: subText,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            message.confidenceNote!,
                            style: TextStyle(
                              color: subText,
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if ((message.detailedBreakdown ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailedBreakdownExpander(
                    breakdown: message.detailedBreakdown!,
                  ),
                ],
                if (message.categoryHeaderChips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: message.categoryHeaderChips.map((c) {
                      final active = _category != null &&
                          (_categoryKeyForLabel(c) ?? c.toLowerCase()) ==
                              _category;
                      return ChoiceChip(
                        label: Text(
                          c,
                          style: TextStyle(
                            color: active ? Colors.white : chipText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: active,
                        selectedColor: AppTheme.glowGuidePink,
                        backgroundColor: chipBg,
                        side: BorderSide(
                          color: active
                              ? AppTheme.glowGuidePink
                              : chipBorder,
                          width: 0.8,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: -3,
                        ),
                        onSelected: (_) => _chooseTopCategory(c),
                      );
                    }).toList(),
                  ),
                ],
                if (message.hasCustomInput) ...[
                  const SizedBox(height: 12),
                  _CustomTopicInput(
                    hint: message.isLanguageChips
                        ? 'Or type your own language…'
                        : 'Or type your own topic (e.g. hair care, kids dress)',
                    label: message.isLanguageChips
                        ? _lastCustomLanguageLabel
                        : _lastCustomCategoryLabel,
                    onSaved: (value) {
                      if (_sending || _sessionComplete) return;
                      if (message.isLanguageChips) {
                        setState(() => _lastCustomLanguageLabel = value);
                      } else if (message.isCategoryChips) {
                        setState(() => _lastCustomCategoryLabel = value);
                      } else if (message.isAgeChips) {
                        _age = value;
                      } else if (message.isSeasonChips) {
                        _seasonWeather = value;
                      }
                    },
                    onSubmitted: (value) {
                      if (_sending || _sessionComplete || value.trim().isEmpty) {
                        return;
                      }
                      if (message.isLanguageChips) {
                        _selectLanguage(value);
                      } else if (message.isCategoryChips) {
                        _chooseTopCategory(value);
                      }
                    },
                  ),
                ],
                if (message.chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.chips.map((chip) {
                      final isTypeOwn = chip == _typeOwnOption;
                      final isSave = chip == 'Save & continue';
                      final isCatHeader = message.isConcernChips &&
                          _categories.any((c) => c.$1 == chip);
                      return ActionChip(
                        label: Text(
                          chip,
                          style: TextStyle(
                            color: isSave || isTypeOwn
                                ? AppTheme.glowGuidePink
                                : (isCatHeader
                                    ? subText
                                    : chipText),
                            fontSize: 13.5,
                            fontWeight: isSave || isTypeOwn
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontStyle: isTypeOwn
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        backgroundColor: isSave
                            ? AppTheme.glowGuidePink.withOpacity(0.08)
                            : (isCatHeader
                                ? chipBg.withOpacity(0.8)
                                : chipBg),
                        side: BorderSide(
                          color: isSave
                              ? AppTheme.glowGuidePink.withOpacity(0.45)
                              : chipBorder,
                          width: 0.9,
                        ),
                        avatar: isTypeOwn
                            ? Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppTheme.glowGuidePink,
                              )
                            : (isSave
                                ? Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 15,
                                    color: AppTheme.glowGuidePink,
                                  )
                                : null),
                        onPressed: _sending || _sessionComplete
                            ? null
                            : () {
                                if (message.isLanguageChips) {
                                  _selectLanguage(chip);
                                } else if (message.isCategoryChips) {
                                  _chooseTopCategory(chip);
                                } else if (message.isAgeChips) {
                                  _selectAge(chip);
                                } else if (message.isSeasonChips) {
                                  _selectSeasonWeather(chip);
                                } else if (message.isConcernChips) {
                                  if (isCatHeader) {
                                    _chooseTopCategory(chip);
                                  } else {
                                    _selectConcern(chip);
                                  }
                                } else {
                                  _selectCategory(chip);
                                }
                              },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

  Widget renderInput() {
  final hasPhoto = _attachment != null;
  return SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: inputBorder,
            width: 1,
          ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF3A2B7B))
                      .withOpacity(isDark ? 0.25 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhoto)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
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
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark ? Colors.white : Colors.black54,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF2A2A2E)
                                    : Colors.white,
                                foregroundColor:
                                    isDark ? Colors.white : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _choosePhoto,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              color: subText,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: _text,
                          focusNode: _textFocus,
                          minLines: 1,
                          maxLines: 8,
                          textInputAction: TextInputAction.newline,
                          onSubmitted: (_) => _send(),
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1E1B2C),
                            fontSize: 15,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Ask about skin, body care, or cloth...',
                            hintStyle: TextStyle(
                              color: subText,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            isCollapsed: true,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Material(
                        color: AppTheme.glowGuidePink,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap:
                              _sending || _sessionComplete ? null : _send,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
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

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: background,
        canvasColor: background,
        splashColor: AppTheme.babyPink.withValues(alpha: 0.35),
        highlightColor: AppTheme.babyPink.withValues(alpha: 0.2),
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          foregroundColor: textColor,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        iconTheme: IconThemeData(color: subText),
        dividerTheme: DividerThemeData(color: divider),
      ),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: textColor,
          elevation: 0,
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sessionTitle ?? 'GlowGuide ✨',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((_category ?? '').trim().isNotEmpty &&
                  (_sessionTitle ?? '').trim().isNotEmpty &&
                  _sessionTitle != _category)
                Text(
                  _prettyCategory(_category!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          iconTheme: IconThemeData(color: subText),
          actions: [
            IconButton(
              tooltip: 'New chat',
              onPressed: _newChat,
              icon: Icon(Icons.add_comment_outlined, color: subText),
            ),
            IconButton(
              tooltip: 'Chat history',
              onPressed: _sending || _restoring ? null : _openHistory,
              icon: Icon(Icons.history_outlined, color: subText),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: divider,
            ),
          ),
        ),
        body: Column(
          children: [
            if (!_hasLoadedPreferredLanguage) const SizedBox(height: 8),
            if (_restoring)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.glowGuidePink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Opening last chat…',
                        style: TextStyle(
                          color: subText,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_sending && index == _messages.length) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _webSearchStatus == 'searching'
                              ? const _WebSearchBubble()
                              : _processingPhoto
                              ? _PhotoAnalyzingBubble(
                                  image: _messages.isNotEmpty
                                      ? _messages.last.image
                                      : null,
                                )
                              : const _PurpleTypingDots(),
                        ),
                      );
                    }
                    return renderTile(_messages[index]);
                  },
                ),
              ),
            const SizedBox(height: 6),
            _restoring ? const SizedBox.shrink() : renderInput(),
          ],
        ),
      ),
    );
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
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
    this.isCategoryChips = false,
    this.isAgeChips = false,
    this.isSeasonChips = false,
    this.hasCustomInput = false,
    this.categoryHeaderChips = const [],
    this.verdict,
    this.confidenceNote,
    this.detailedBreakdown,
  });
  final String text;
  final bool isUser;
  final List<String> chips;
  final Uint8List? image;
  final String? imageName;
  final String? imageUrl;
  final bool isLanguageChips;
  final bool isConcernChips;
  final bool isCategoryChips;
  final bool isAgeChips;
  final bool isSeasonChips;
  final bool hasCustomInput;
  final List<String> categoryHeaderChips;
  final String? verdict;
  final String? confidenceNote;
  final String? detailedBreakdown;
}

class _DetailedBreakdownExpander extends StatefulWidget {
  const _DetailedBreakdownExpander({required this.breakdown});

  final String breakdown;

  @override
  State<_DetailedBreakdownExpander> createState() =>
      _DetailedBreakdownExpanderState();
}

class _DetailedBreakdownExpanderState
    extends State<_DetailedBreakdownExpander>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.glowGuidePink.withValues(alpha: 0.5),
              ),
              color: AppTheme.glowGuidePink.withValues(alpha: 0.06),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.manage_search_rounded,
                  size: 16,
                  color: AppTheme.glowGuidePink,
                ),
                const SizedBox(width: 6),
                Text(
                  _expanded ? 'Hide breakdown' : '  See detailed breakdown',
                  style: const TextStyle(
                    color: AppTheme.glowGuidePink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.glowGuidePink.withValues(alpha: 0.04),
                border: Border.all(
                  color: AppTheme.glowGuidePink.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                widget.breakdown,
                style: TextStyle(
                  color: AppTheme.getPrimaryText(context),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WebSearchBubble extends StatelessWidget {
  const _WebSearchBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.glowGuidePink,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Web search',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
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
                backgroundColor: AppTheme.glowGuidePink,
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
              child: Container(height: 3, color: AppTheme.glowGuidePink),
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
        backgroundColor: AppTheme.babyPink,
        foregroundColor: AppTheme.babyPinkMaroon,
      ),
    );
  }
}

class _CustomTopicInput extends StatefulWidget {
  const _CustomTopicInput({
    required this.hint,
    required this.label,
    required this.onSaved,
    required this.onSubmitted,
  });
  final String hint;
  final String? label;
  final ValueChanged<String> onSaved;
  final ValueChanged<String> onSubmitted;

  @override
  State<_CustomTopicInput> createState() => _CustomTopicInputState();
}

class _CustomTopicInputState extends State<_CustomTopicInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.label ?? '');
  }

  @override
  void didUpdateWidget(covariant _CustomTopicInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label != oldWidget.label &&
        widget.label != _ctrl.text) {
      _ctrl.text = widget.label ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF6F3FB);
    final border = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE3DDF3);
    final textColor = isDark ? Colors.white : const Color(0xFF3C375A);
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final accent = AppTheme.glowGuidePink;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.9),
      ),
      padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: hintColor, fontSize: 13.5),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                final clean = value.trim();
                widget.onSaved(clean);
                widget.onSubmitted(clean);
              },
              onChanged: (value) {
                widget.onSaved(value.trim());
              },
            ),
          ),        // ← Expanded band
        ],          // ← Row ke children list band (Save button hatane ke baad ye last item hai)
      ),            // ← Row band
    );              // ← Container band
  }                 // ← build method band
}           