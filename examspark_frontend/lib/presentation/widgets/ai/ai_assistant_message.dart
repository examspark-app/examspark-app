import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_typewriter_text.dart';

/// Left-aligned AI reply bubble with optional typewriter + trust line.
class AiAssistantMessage extends StatefulWidget {
  final String text;
  final String? trustLine;
  final bool animate;
  final VoidCallback? onRevealComplete;
  final Widget? trailing;

  const AiAssistantMessage({
    super.key,
    required this.text,
    this.trustLine,
    this.animate = true,
    this.onRevealComplete,
    this.trailing,
  });

  @override
  State<AiAssistantMessage> createState() => _AiAssistantMessageState();
}

class _AiAssistantMessageState extends State<AiAssistantMessage> {
  bool _revealDone = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) {
      _revealDone = true;
    }
  }

  void _onTypewriterComplete() {
    if (!mounted) return;
    setState(() => _revealDone = true);
    widget.onRevealComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: AppTheme.getPrimaryText(context),
      height: 1.4,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.getCardBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getCardBorder(context)),
              ),
              child: widget.animate
                  ? AiTypewriterText(
                      text: widget.text,
                      style: textStyle,
                      onComplete: _onTypewriterComplete,
                    )
                  : SelectableText(widget.text, style: textStyle),
            ),
            if (widget.trustLine != null && _revealDone) ...[
              const SizedBox(height: 6),
              AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  widget.trustLine!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ),
            ],
            if (widget.trailing != null && _revealDone) ...[
              const SizedBox(height: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
