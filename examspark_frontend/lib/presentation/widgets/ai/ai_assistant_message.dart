import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_typewriter_text.dart';
import 'package:examspark_frontend/presentation/widgets/home/home_ai_visual_card.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Left-aligned AI reply: Answer card → Visual card → study chips.
/// Founder Lock: Home AI Mobile UX — no diagram dump inside chat text.
/// No Ask/Explain/Simplify bar on the answer (same-reply spam removed).
class AiAssistantMessage extends StatefulWidget {
  final String text;
  final String? trustLine;
  final bool animate;
  final VoidCallback? onRevealComplete;
  final Widget? trailing;
  final Map<String, dynamic>? visualPayload;
  /// Deprecated — kept for call-site compat; ignored (no select chips).
  final Future<void> Function(String actionId, String selectedText)? onSelectAi;

  const AiAssistantMessage({
    super.key,
    required this.text,
    this.trustLine,
    this.animate = true,
    this.onRevealComplete,
    this.trailing,
    this.visualPayload,
    this.onSelectAi,
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

  @override
  void didUpdateWidget(covariant AiAssistantMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate && !_revealDone) {
      _revealDone = true;
    }
  }

  void _onTypewriterComplete() {
    if (!mounted) return;
    setState(() => _revealDone = true);
    widget.onRevealComplete?.call();
  }

  bool get _hasVisual {
    final raw = widget.visualPayload;
    if (raw == null || raw.isEmpty) return false;
    return !VisualPayloadData.fromJson(raw).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: AppTheme.getPrimaryText(context),
      height: 1.45,
      fontSize: 15,
    );

    final body = widget.animate && !_revealDone
        ? AiTypewriterText(
            text: widget.text,
            style: textStyle,
            onComplete: _onTypewriterComplete,
          )
        : SelectableText(widget.text, style: textStyle);

    final maxW = MediaQuery.sizeOf(context).width;
    final cardMax = maxW < 600 ? maxW - 32 : maxW * 0.72;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardMax),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.getCardBackground(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getCardBorder(context)),
              ),
              child: body,
            ),
            if (_hasVisual && _revealDone) ...[
              const SizedBox(height: 10),
              HomeAiVisualCard(visualPayload: widget.visualPayload!),
            ],
            if (widget.trustLine != null && _revealDone) ...[
              const SizedBox(height: 8),
              Text(
                widget.trustLine!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getSecondaryText(context),
                ),
              ),
            ],
            if (widget.trailing != null && _revealDone) ...[
              const SizedBox(height: 12),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
