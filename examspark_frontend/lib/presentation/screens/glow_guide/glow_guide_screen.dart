import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  static const _openings = [
    'What would you like to understand today: skin, body, baby care, or cloth?',
    'Let’s look at what you need help with: skin, body, baby care, or cloth.',
    'I can help you reason through skin, body, baby care, or cloth questions.',
  ];

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _messages = <_GlowMessage>[];
  Uint8List? _attachment;
  String? _attachmentName;
  String? _category;
  String? _sessionId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _GlowMessage(
        _openings[DateTime.now().millisecond % _openings.length],
        false,
        chips: _categories.map((item) => item.$1).toList(),
      ),
    );
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

  Future<void> _selectCategory(String label) async {
    const categoryMap = {
      'Skin Care': 'skin',
      'Body Care': 'body',
      'Baby Skin Care': 'baby',
      'Cloth Guide': 'cloth',
    };
    final selectedCategory = categoryMap[label];
    if (selectedCategory != null) {
      _category = selectedCategory;
    }
    _text.text = label;
    await _send();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if ((text.isEmpty && _attachment == null) || _sending) return;
    final image = _attachment;
    final imageName = _attachmentName;
    setState(() {
      _sending = true;
      _messages.add(_GlowMessage(
        text.isEmpty ? 'Photo attached' : text,
        true,
        image: image,
        imageName: imageName,
      ));
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
      );
      if (!mounted) return;
      final options = (result['question_options'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList() ??
          const <String>[];
      setState(() {
        _sessionId = result['session_id'] as String? ?? _sessionId;
        _category = result['category'] as String? ?? _category;
        _messages.add(_GlowMessage(
          result['reply'] as String? ?? 'I need a little more detail.',
          false,
          chips: options,
        ));
        _sending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(_GlowMessage(
          'GlowGuide is unavailable right now. Please try again.',
          false,
        ));
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
      _messages
        ..clear()
        ..add(_GlowMessage(
          _openings[DateTime.now().millisecond % _openings.length],
          false,
          chips: _categories.map((item) => item.$1).toList(),
        ));
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
            const ListTile(title: Text('GlowGuide History')),
            for (final session in sessions)
              ListTile(
                leading: const Icon(Icons.eco_outlined),
                title: Text((session['category_type'] as String?) ?? 'GlowGuide'),
                subtitle: Text((session['updated_at'] as String?) ?? ''),
                onTap: () => Navigator.pop(sheetContext, session['id'] as String?),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final restored = await LectureService.instance.restoreGlowGuideSession(selected);
    if (!mounted) return;
    final restoredMessages = (restored['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((message) => _GlowMessage(
              message['message']?.toString() ?? '',
              message['role'] == 'user',
            ))
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
          _category == null ? 'GlowGuide 🌿' : 'GlowGuide 🌿 · $_category',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'New GlowGuide chat',
            onPressed: _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'GlowGuide history',
            onPressed: _sending ? null : _openHistory,
            icon: const Icon(Icons.history_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messageTile(_messages[index]),
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _messageTile(_GlowMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .86),
          child: Column(
            crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.image != null)
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
                    child: Image.memory(message.image!, width: 180, height: 140, fit: BoxFit.cover),
                  ),
                ),
              if (message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: AppTheme.getPrimaryText(context),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              if (message.chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.chips.map((chip) => ActionChip(
                    label: Text(chip),
                    avatar: Icon(_iconFor(chip), size: 16),
                    onPressed: () => _selectCategory(chip),
                  )).toList(),
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
                          child: Image.memory(_attachment!, width: 72, height: 72, fit: BoxFit.cover),
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
                              foregroundColor: AppTheme.getCardBackground(context),
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
                    icon: Icon(Icons.arrow_upward_rounded, color: AppTheme.accentColor),
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
  const _GlowMessage(this.text, this.isUser, {this.chips = const [], this.image, this.imageName});
  final String text;
  final bool isUser;
  final List<String> chips;
  final Uint8List? image;
  final String? imageName;
}

class _PreviewAction extends StatelessWidget {
  const _PreviewAction({required this.label, required this.icon, required this.onTap});
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
