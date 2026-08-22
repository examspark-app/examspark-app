import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/ai/ai_typewriter_text.dart';
import 'package:examspark_frontend/presentation/widgets/home/home_ai_visual_card.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';
import 'package:examspark_frontend/core/utils/dom_selection.dart';

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

  /// Called with the selected text when the user taps "Ask AI" from the
  /// text-selection toolbar.
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
  String _selectedText = '';
  String? _pendingReply;

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
    // Standard chat-app reading typography — same body text size WhatsApp /
    // Telegram / ChatGPT mobile use (15px), with a comfortable 1.5 line
    // height for paragraphs and neutral letter-spacing (no artificial
    // tightening/loosening).
    final textStyle = TextStyle(
      color: AppTheme.getPrimaryText(context),
      fontSize: 15,
      height: 1.5,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
    );

    final body = widget.animate && !_revealDone
        ? AiTypewriterText(
            text: widget.text,
            style: textStyle,
            onComplete: _onTypewriterComplete,
          )
        : SelectionArea(
            onSelectionChanged: (content) {
              final text = (content?.plainText ?? '').trim();
              if (text.isNotEmpty && text != _pendingReply) {
                setState(() {
                  _selectedText = text;
                  _pendingReply = text;
                });
              }
            },
            child: Text(widget.text, style: textStyle),
          );

    final maxW = MediaQuery.sizeOf(context).width;
    // Match ChatGPT Web's optimal reading width (~768px max for text blocks)
    // while keeping comfortable margins on mobile devices.
    final cardMax = maxW < 768 ? maxW - 20 : 760.0;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardMax),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: body,
            ),
            if (_pendingReply != null && _pendingReply!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final text = _pendingReply!;
                    setState(() {
                      _pendingReply = null;
                      _selectedText = '';
                    });
                    final callback = widget.onSelectAi;
                    if (callback == null) return;
                    await callback('reply', text);
                  },
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
            if (_hasVisual && _revealDone) ...[
              const SizedBox(height: 16),
              HomeAiVisualCard(visualPayload: widget.visualPayload!),
            ],
            if (widget.trustLine != null && _revealDone) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.trustLine!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ),
            ],
            if (widget.trailing != null && _revealDone) ...[
              const SizedBox(height: 16),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
