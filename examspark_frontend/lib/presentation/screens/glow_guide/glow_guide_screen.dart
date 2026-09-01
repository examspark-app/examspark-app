import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart'
    as app_supabase;
import 'package:examspark_frontend/core/services/feature_analytics_tracker.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/glow_guide/glow_guide_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';
class GlowGuideScreen extends StatefulWidget {
  const GlowGuideScreen({super.key, this.startFresh = false, this.sessionId});

  final bool startFresh;
  final String? sessionId;

  @override
  State<GlowGuideScreen> createState() => _GlowGuideScreenState();
}

class _GlowGuideScreenState extends State<GlowGuideScreen> {
  static const _categories = [
    ('Skin Care', Icons.face_retouching_natural_outlined),
    ('Body Care', Icons.spa_outlined),
    ('Baby Skin Care', Icons.child_friendly_outlined),
    ('Cloth Guide', Icons.checkroom_outlined),
    ('Hair Care', Icons.content_cut_outlined),
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
    'hair': [
      'Hair loss',
      'Hair whitening',
      'General hair care',
      'Short to long growth',
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
  String? _gender;
  String? _age;
  String? _seasonWeather;
  String? _sessionId;
  String? _analyticsSessionKey;
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
  bool _customInputFlowOpen = false;

  @override
  void initState() {
    super.initState();
    _analyticsSessionKey =
        FeatureAnalyticsTracker.instance.startFeature('glowguide');
    if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
      _restoreSessionById(widget.sessionId!);
    } else if (widget.startFresh) {
      _showLanguageChoice();
    } else {
      _openLatestOrFresh();
    }
  }

  Future<void> _restoreSessionById(String sessionId) async {
    try {
      final restored = await LectureService.instance.restoreGlowGuideSession(sessionId);
      if (!mounted) return;
      final restoredMessages = (restored['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((message) => _GlowMessage(
                message['message']?.toString() ?? '',
                message['role'] == 'user',
                imageUrl: message['image_url']?.toString(),
              ))
          .toList();
      setState(() {
        _restoring = false;
        _sessionId = sessionId;
        _category = restored['category'] as String?;
        final title = restored['title']?.toString().trim() ?? '';
        _sessionTitle = title.isEmpty ? _deriveTitleFromMessages(restoredMessages) : title;
        _sessionComplete = restored['status'] == 'archived' ||
            (restored['exchange_count'] as num? ?? 0) >= 100;
        _hasLoadedPreferredLanguage = true;
        _messages..clear()..addAll(restoredMessages);
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _messages.add(_GlowMessage('Could not open this chat. Please try again.', false));
      });
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
    if (_hasLoadedPreferredLanguage) return;
    setState(() {
      _customInputFlowOpen = false;
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
    final lang = trimmed == 'Auto-detect' ? 'MATCH_QUESTION' : trimmed;
    _lastCustomLanguageLabel = trimmed == 'Auto-detect' ? null : trimmed;
    setState(() {
      _customInputFlowOpen = false;
      _preferredLanguage = lang;
    });
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
      _customInputFlowOpen = false;
      if (!_messages.any((message) => message.chips.isNotEmpty && !message.isLanguageChips)) {
        _messages.add(
          _GlowMessage(
            'First, what do you need help with?\nPick a guide or type your own topic (e.g. hair care, kids dress).',
            false,
            chips: [
              ..._categories.map((item) => item.$1),
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
    _lastCustomCategoryLabel = trimmed;
    setState(() => _customInputFlowOpen = false);
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
          '${display ?? key} selected. Just so I can guide you accurately — is this for a male or female?',
          false,
          chips: const ['Male', 'Female'],
          isGenderChips: true,
        ),
      );
    });
    _scrollToBottom();
  }

  void _selectGender(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    setState(() {
      _gender = clean;
      _messages.add(
        _GlowMessage(
          'Got it. What age should I consider for this guidance?',
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
        FeatureAnalyticsTracker.instance.stopFeature(_analyticsSessionKey);
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
    await _showImagePreview(Image.memory(bytes, fit: BoxFit.contain));
  }

  Future<void> _previewNetworkPhoto(String url) async {
    await _showImagePreview(Image.network(url, fit: BoxFit.contain));
  }

  Future<void> _showImagePreview(Widget image) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: image,
            ),
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
    'Hair Care': 'hair',
  };

  Future<void> _selectCategory(String label) async {
    await _chooseTopCategory(label);
  }

  Future<void> _selectConcern(String concern) async {
    if (_sending) return;
    if (concern == _typeOwnOption) {
      setState(() => _customInputFlowOpen = true);
      return;
    }

    setState(() => _customInputFlowOpen = false);
    _sessionTitle ??= _niceTitleFromConcern(concern);
    _text.text = concern;
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
    text,   // ← khaali rehne do agar photo-only hai
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
        age: _gender != null ? '$_gender${_age != null ? ", $_age" : ""}' : _age,
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
            sources: (result['sources'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                const [],
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GlowGuideHistoryScreen()),
    );
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
    'hair': 'Hair Care',
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

  // ← YAHAN PASTE KARO (naya method neeche se shuru)
  MarkdownStyleSheet _markdownStyle(
    BuildContext context,
    Color primaryText,
    bool isDark,
  ) {
    const baseFontSize = 15.5;
    const baseHeight = 1.6;
    return MarkdownStyleSheet(
      p: TextStyle(color: primaryText, fontSize: baseFontSize, height: baseHeight),
      h1: TextStyle(color: primaryText, fontSize: 20, height: 1.4, fontWeight: FontWeight.w700),
      h2: TextStyle(color: primaryText, fontSize: 17.5, height: 1.4, fontWeight: FontWeight.w700),
      h3: TextStyle(color: primaryText, fontSize: 16, height: 1.4, fontWeight: FontWeight.w600),
      strong: TextStyle(color: primaryText, fontWeight: FontWeight.w700, fontSize: baseFontSize, height: baseHeight),
      em: TextStyle(color: primaryText, fontStyle: FontStyle.italic, fontSize: baseFontSize, height: baseHeight),
      listBullet: TextStyle(color: primaryText, fontSize: baseFontSize, height: baseHeight),
      listIndent: 18,
      blockSpacing: 8,
      code: TextStyle(
        color: primaryText,
        fontSize: baseFontSize - 1,
        fontFamily: 'monospace',
        backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        color: AppTheme.glowGuidePink.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppTheme.glowGuidePink, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
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
                        if (message.image != null) {
                          setState(() {
                            _attachment = message.image;
                            _attachmentName = message.imageName;
                          });
                          _previewPhoto();
                        } else if (message.imageUrl != null) {
                          _previewNetworkPhoto(message.imageUrl!);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: message.image != null
                            ? Image.memory(
                                message.image!,
                                width: 164,
                                height: 124,
                                fit: BoxFit.cover,
                              )
                            : (message.imageUrl != null
                                  ? Image.network(
                                      message.imageUrl!,
                                      width: 164,
                                      height: 124,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleUser,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: bubbleUser.withOpacity(isDark ? 0.16 : 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                              letterSpacing: 0.1,
                            ),
                          ),
                        )
                                            : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.verdict != null) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.eco_rounded,
                                      size: 13,
                                      color: AppTheme.glowGuidePink,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'GLOWGUIDE ASSESSMENT',
                                      style: TextStyle(
                                        color: AppTheme.glowGuidePink,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              SelectionArea(
                                child: MarkdownBody(
                                  data: message.text,
                                  selectable: false,
                                  styleSheet: _markdownStyle(
                                    context,
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1B2C),
                                    isDark,
                                  ),
                                  softLineBreak: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                                if ((message.confidenceNote ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: subText.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fact_check_outlined,
                            size: 13,
                            color: subText,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              message.confidenceNote!,
                              style: TextStyle(
                                color: subText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if ((message.detailedBreakdown ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailedBreakdownExpander(
                    breakdown: message.detailedBreakdown!,
                  ),
                ],
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SourceChips(sources: message.sources),
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
                if (message.hasCustomInput && _customInputFlowOpen) ...[
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
                      setState(() => _customInputFlowOpen = false);
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
                  _NumberedOptionCard(
                    options: message.chips,
                    textColor: chipText,
                    subText: subText,
                    borderColor: chipBorder,
                    bg: chipBg,
                    onSelect: (chip) {
                      if (_sending || _sessionComplete) return;
                      if (chip == _typeOwnOption) {
                        _selectConcern(chip);
                        return;
                      }
                      if (message.isLanguageChips) {
                        _selectLanguage(chip);
                      } else if (message.isCategoryChips) {
                        _chooseTopCategory(chip);
                      } else if (message.isGenderChips) {
                        _selectGender(chip);
                      } else if (message.isAgeChips) {
                        _selectAge(chip);
                      } else if (message.isSeasonChips) {
                        _selectSeasonWeather(chip);
                      } else if (message.isConcernChips) {
                        final isCatHeader = _categories.any(
                          (c) => c.$1 == chip,
                        );
                        if (isCatHeader) {
                          _chooseTopCategory(chip);
                        } else {
                          _selectConcern(chip);
                        }
                      } else {
                        _selectConcern(chip);
                      }
                    },
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
                                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: _text,
                    focusNode: _textFocus,
                    minLines: 1,
                    maxLines: 10,
                    textAlign: TextAlign.start,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E1B2C),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask about skin, body care, or cloth...',
                      hintTextDirection: TextDirection.ltr,
                      hintStyle: TextStyle(
                        color: subText,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isCollapsed: true,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
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
                              Icons.add_rounded,
                              color: subText,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: AppTheme.glowGuidePink,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _sending || _sessionComplete ? null : _send,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 22,
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
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.glowGuidePink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Opening last chat…',
                        style: TextStyle(
                          color: subText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleAi,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: bubbleAiBorder,
                                width: 0.8,
                              ),
                            ),
                            child: _webSearchStatus == 'searching'
                                ? _WebSearchBubble()
                                : _processingPhoto
                                ? _PhotoAnalyzingBubble(
                                    image: _messages.isNotEmpty
                                        ? _messages.last.image
                                        : null,
                                  )
                                : const _PurpleTypingDots(),
                          ),
                        ),
                      );
                    }
                    return renderTile(_messages[index]);
                  },
                ),
              ),
            const SizedBox(height: 6),
            _restoring ? const SizedBox.shrink() : renderInput(),
            if (!_restoring) _buildDisclaimer(isDark, subText),
          ],
        ),
      ),
    );
  }
      Widget _buildDisclaimer(bool isDark, Color subText) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://sites.google.com/view/sonaxia/support');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          'Sonaxia AI can make mistakes. Please double-check responses.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subText.withOpacity(0.55),
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
  Widget _verdictBadge(String verdict) {
  final Color color;
  final IconData icon;
  final String label;
  final String subtitle;
  switch (verdict) {
    case 'harmful':
      color = const Color(0xFFD64545);
      icon = Icons.report_gmailerrorred_rounded;
      label = 'Not Suitable';
      subtitle = 'May not be the right fit for your skin';
      break;
    case 'good_fit':
      color = const Color(0xFF2FA75F);
      icon = Icons.verified_rounded;
      label = 'Safe to Use';
      subtitle = 'Suitable based on what you shared';
      break;
    case 'careful':
      color = const Color(0xFFC98A1F);
      icon = Icons.shield_outlined;
      label = 'Use with Caution';
      subtitle = 'Some considerations before using';
      break;
    default:
      return const SizedBox.shrink();
  }
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.28), width: 1.1),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
    this.isGenderChips = false,
    this.isAgeChips = false,
    this.isSeasonChips = false,
    this.hasCustomInput = false,
    this.categoryHeaderChips = const [],
    this.verdict,
    this.confidenceNote,
    this.detailedBreakdown,
    this.sources = const [],
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
  final bool isGenderChips;
  final bool isAgeChips;
  final bool isSeasonChips;
  final bool hasCustomInput;
  final List<String> categoryHeaderChips;
  final String? verdict;
  final String? confidenceNote;
  final String? detailedBreakdown;
  final List<Map<String, dynamic>> sources;
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
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.glowGuidePink.withValues(alpha: 0.35),
              ),
              color: AppTheme.glowGuidePink.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.description_outlined,
                  size: 17,
                  color: AppTheme.glowGuidePink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _expanded
                        ? 'Hide detailed breakdown'
                        : 'View full ingredient breakdown',
                    style: const TextStyle(
                      color: AppTheme.glowGuidePink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppTheme.glowGuidePink.withOpacity(0.7),
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
              child: CircleAvatar(
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
class _SourceChips extends StatelessWidget {
  const _SourceChips({required this.sources});
  final List<Map<String, dynamic>> sources;

  String? _domainFrom(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      return host.startsWith('www.') ? host.substring(4) : host;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF1C1C1F) : const Color(0xFFF6F3FB);
    final chipBorder = isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE3DDF3);
    final textColor = isDark ? Colors.white60 : Colors.black54;

    final seen = <String>{};
    final chips = <Widget>[];
    for (final source in sources) {
      final url = source['url']?.toString();
      final domain = _domainFrom(url);
      if (domain == null || !seen.add(domain)) continue;
      chips.add(
        InkWell(
          onTap: url == null
              ? null
              : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipBorder, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    'https://www.google.com/s2/favicons?domain=$domain&sz=64',
                    width: 14,
                    height: 14,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.public_rounded,
                      size: 14,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  domain,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}
class _WebSearchBubble extends StatefulWidget {
  const _WebSearchBubble();

  @override
  State<_WebSearchBubble> createState() => _WebSearchBubbleState();
}

class _WebSearchBubbleState extends State<_WebSearchBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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
      builder: (_, __) {
        final pulse = 1 - (_controller.value - 0.5).abs() * 2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.glowGuidePink.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.glowGuidePink.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 16,
                color: AppTheme.glowGuidePink.withOpacity(0.55 + pulse * 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                'Searching trusted sources…',
                style: TextStyle(
                  color: AppTheme.glowGuidePink.withOpacity(0.55 + pulse * 0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _NumberedOptionCard extends StatelessWidget {
  const _NumberedOptionCard({
    required this.options,
    required this.onSelect,
    required this.textColor,
    required this.subText,
    required this.borderColor,
    required this.bg,
  });

  final List<String> options;
  final ValueChanged<String> onSelect;
  final Color textColor;
  final Color subText;
  final Color borderColor;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            InkWell(
              onTap: () => onSelect(options[i]),
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(14) : Radius.zero,
                bottom: i == options.length - 1
                    ? const Radius.circular(14)
                    : Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: subText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        options[i],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: subText,
                    ),
                  ],
                ),
              ),
            ),
            if (i != options.length - 1)
              Divider(height: 1, color: borderColor),
          ],
        ],
      ),
    );
  }
}