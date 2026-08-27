import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai_model_selector.dart';

class BottomInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecord;
  final bool recordLocked;
  final bool isSending;
  final VoidCallback? onYoutube;
  final String selectedModel;
  final ValueChanged<String>? onModelChanged;

  /// Pinned attachment (set by parent after camera/gallery pick).
  final Uint8List? attachmentBytes;
  final String? attachmentName;
  final bool attachmentIsImage;
  final VoidCallback? onRemoveAttachment;

  /// Claude-style Reply context.
  final String? replyText;
  final VoidCallback? onClearReply;

  const BottomInputBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.onRecord,
    this.recordLocked = false,
    this.onYoutube,
    this.selectedModel = 'qwen3',
    this.onModelChanged,
    this.isSending = false,
    this.attachmentBytes,
    this.attachmentName,
    this.attachmentIsImage = true,
    this.onRemoveAttachment,
    this.replyText,
    this.onClearReply,
  });

  @override
  State<BottomInputBar> createState() => _BottomInputBarState();
}

class _BottomInputBarState extends State<BottomInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText && mounted) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasAttachment =>
      widget.attachmentBytes != null && widget.attachmentBytes!.isNotEmpty;

  bool get _hasReply =>
      widget.replyText != null && widget.replyText!.trim().isNotEmpty;

  void _handleSend() {
    if (widget.isSending) return;

    final text = _controller.text.trim();

    // Attachment ya sirf reply-quote (bina question ke) bhi bhej sakte hain —
    // AI khali chhodne par khud "explain karo" samajh lega.
    if (text.isEmpty && !_hasAttachment && !_hasReply) return;

    FocusScope.of(context).unfocus();

    widget.onSend(text);

    _controller.clear();

    // Reply quote ko parent clear karega after send request is handed off.
    if (_hasReply) {
      widget.onClearReply?.call();
    }
  }

  Color _actionColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black
        : Colors.white;
  }

  Color _actionIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Colors.black;
  }

  Widget _buildReplyPreview(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final selected = widget.replyText!.trim();

    final preview = selected.length > 420
        ? '${selected.substring(0, 420)}…'
        : selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: isLight
              ? const Color(0xFFF5F5F5)
              : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: AppTheme.accentColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Replying to selected text',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    preview,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppTheme.getPrimaryText(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Remove reply',
              onPressed: widget.isSending ? null : widget.onClearReply,
              icon: const Icon(Icons.close_rounded, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentChip(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFF0F0F0) : const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFDDDDDD)
                  : const Color(0xFF3A3A3A),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: widget.attachmentIsImage
                    ? Image.memory(
                        widget.attachmentBytes!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        color: isLight
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                        child: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 26,
                        ),
                      ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: widget.onRemoveAttachment,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  final isLight = Theme.of(context).brightness == Brightness.light;
  final actionColor = _actionColor(context);
  final actionIconColor = _actionIconColor(context);
  final muted = isLight ? Colors.black54 : Colors.white60;

  final canSend =
      (_hasText || _hasAttachment || _hasReply) && !widget.isSending;

  final pillBg = isLight ? Colors.white : const Color(0xFF1C1C1E);
  final pillBorder =
      isLight ? const Color(0xFFDDDDDD) : const Color(0xFF3A3A3C);

  return SafeArea(
  top: false,
  child: Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: pillBorder,
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.30),
                blurRadius: 14,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasReply) _buildReplyPreview(context),
              if (_hasAttachment) _buildAttachmentChip(context),

              // ---- Text field (auto-grow) ----
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 10,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: AppTheme.getPrimaryText(context),
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: _hasAttachment
                        ? 'Add a caption (optional)...'
                        : _hasReply
                            ? 'Ask about the selected text...'
                            : 'Ask sonaxia ...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    hintStyle: TextStyle(
                      color: muted,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // ---- Ek hi row me sab controls ----
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 22),
                    color: muted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    onPressed: widget.onAttach,
                  ),
                  if (widget.onModelChanged != null)
                    AiModelSelector(
                      selectedModel: widget.selectedModel,
                      onSelected: widget.onModelChanged!,
                    ),
                  const Spacer(),
                  if (widget.onYoutube != null)
                    IconButton(
                      icon: Icon(
                        Icons.smart_display_rounded,
                        color: Colors.redAccent,
                        size: 21,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      onPressed: widget.onYoutube,
                      tooltip: 'YouTube Notes',
                    ),
                  IconButton(
                    icon: Icon(
                      widget.recordLocked
                          ? Icons.lock_outline_rounded
                          : Icons.mic_none_rounded,
                      color: muted,
                      size: 21,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    onPressed: widget.onRecord,
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: canSend ? _handleSend : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: actionIconColor,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: isLight
                            ? const Color(0xFFE5E5EA)
                            : const Color(0xFF2C2C2E),
                        disabledForegroundColor: isLight
                            ? const Color(0xFF8E8E93)
                            : Colors.white38,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: canSend ? actionIconColor : null,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---- ADD THIS: disclaimer line below the input pill ----
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Sonaxia can make mistakes. Please double-check responses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: muted,
            ),
          ),
        ),
      ],
    ),
  ),
);
}