import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class BottomInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecord;
  final bool recordLocked;
  final VoidCallback? onYoutube;

  const BottomInputBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.onRecord,
    this.recordLocked = false,
    this.onYoutube,
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
    final text = _controller.text.trim();
    if (text.isEmpty) return;

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 28),
              color: AppTheme.getSecondaryText(context),
              onPressed: widget.onAttach,
            ),

            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 52,
                  maxHeight: 200,
                ),
                decoration: BoxDecoration(
  color: isLight
      ? const Color(0xFFF7F7F8)
      : const Color(0xFF111111),
  borderRadius: BorderRadius.circular(30),
  border: Border.all(
    color: isLight
        ? const Color(0xFFE5E5E5)
        : const Color(0xFF2A2A2A),
    width: 1,
  ),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.18),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ],
),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 8,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.getPrimaryText(context),
                  ),
                  decoration: InputDecoration(
                    hintText: "Ask sonaxia ...",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    hintStyle: TextStyle(
  color: isLight
      ? Colors.grey.shade600
      : Colors.grey.shade500,
  fontSize: 16,
),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 130,
                    ),

                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        if (widget.onYoutube != null)
                          IconButton(
                            icon: const Icon(
                              Icons.smart_display_rounded,
                              color: Color(0xFFEA4335),
                              size: 22,
                            ),
                            onPressed: widget.onYoutube,
                          ),

                        IconButton(
                          icon: Icon(
                            widget.recordLocked
                                ? Icons.lock_outline_rounded
                                : Icons.mic_none_rounded,
                            color: AppTheme.getSecondaryText(context),
                            size: 22,
                          ),
                          onPressed: widget.onRecord,
                        ),

                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: actionColor,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.arrow_upward_rounded,
                                color: actionIconColor,
                                size: 18,
                              ),
                              onPressed: _hasText ? _handleSend : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}