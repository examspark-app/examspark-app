import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class BottomInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecord;
  final bool recordLocked;
  final bool isSending;
  final VoidCallback? onYoutube;

  const BottomInputBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.onRecord,
    this.recordLocked = false,
    this.onYoutube,
    this.isSending = false,
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
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
  if (widget.isSending) return;

  final text = _controller.text.trim();
  if (text.isEmpty) return;

  FocusScope.of(context).unfocus();
  widget.onSend(text);
  _controller.clear();
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

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final actionColor = _actionColor(context);
    final actionIconColor = _actionIconColor(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFD9D9D9)
                  : const Color(0xFF333333),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Text field row — no border, sits inside the outer box.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.getPrimaryText(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask sonaxia ...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 10),
                    hintStyle: TextStyle(
                      color: isLight
                          ? Colors.grey.shade600
                          : Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              // Bottom icon row — "+" on the left, actions on the right,
              // all inside the same rounded box (Claude-style).
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 26),
                    color: AppTheme.getSecondaryText(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onAttach,
                  ),
                  const Spacer(),
                  if (widget.onYoutube != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: const Icon(
                          Icons.smart_display_rounded,
                          color: Color(0xFFEA4335),
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onYoutube,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(
                        widget.recordLocked
                            ? Icons.lock_outline_rounded
                            : Icons.mic_none_rounded,
                        color: AppTheme.getSecondaryText(context),
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onRecord,
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: actionColor,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        color: actionIconColor,
                        size: 16,
                      ),
                      onPressed: (!_hasText || widget.isSending) ? null : _handleSend,
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