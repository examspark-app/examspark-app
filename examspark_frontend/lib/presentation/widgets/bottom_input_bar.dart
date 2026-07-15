import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Sticky bottom input bar for the Home (conversation) tab.
/// Per UX rule: Attachment · Record · Text · Send.
class BottomInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecord;

  /// When true, mic shows a lock affordance (still tappable → parent shows upgrade).
  final bool recordLocked;

  /// "YouTube Link → Notes" — founder-requested placement: its own icon
  /// right next to Record, not buried inside the Attach (+) sheet. Null
  /// hides the icon entirely.
  final VoidCallback? onYoutube;

  const BottomInputBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    required this.onRecord,
    this.onYoutube,
    this.recordLocked = false,
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
      if (hasText != _hasText) setState(() => _hasText = hasText);
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: AppTheme.getCardBorder(context))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Attach',
              onPressed: widget.onAttach,
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.getCardBorder(context)),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: const InputDecoration(
                    hintText: 'Ask anything…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            if (widget.onYoutube != null)
              IconButton(
                icon: const Icon(Icons.smart_display_outlined),
                color: const Color(0xFFEA4335),
                tooltip: 'YouTube link → Notes',
                onPressed: widget.onYoutube,
              ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: _hasText
                  ? IconButton(
                      key: const ValueKey('send'),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _handleSend,
                    )
                  : IconButton(
                      key: const ValueKey('mic'),
                      icon: Icon(
                        widget.recordLocked
                            ? Icons.lock_outline
                            : Icons.mic_none_rounded,
                      ),
                      tooltip: widget.recordLocked
                          ? 'Audio needs ₹499+ Plan'
                          : 'Record',
                      style: IconButton.styleFrom(
                        backgroundColor: widget.recordLocked
                            ? Colors.grey.shade500
                            : AppTheme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: widget.onRecord,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
