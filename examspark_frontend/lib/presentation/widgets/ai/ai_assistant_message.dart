import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

  /// ChatGPT / Claude style markdown look — clean headings, spaced
  /// paragraphs, readable bullets, subtle bold, and a distinct code block
  /// background so formulas/code never blend into normal prose.
  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final primary = AppTheme.getPrimaryText(context);
    final secondary = AppTheme.getSecondaryText(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const baseFontSize = 15.0;
    const baseHeight = 1.55;

    return MarkdownStyleSheet(
      p: TextStyle(
        color: primary,
        fontSize: baseFontSize,
        height: baseHeight,
        fontWeight: FontWeight.w400,
      ),
      // Bigger, clearly separated section headings — like ChatGPT's "##".
      h1: TextStyle(
        color: primary,
        fontSize: 22,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      h2: TextStyle(
        color: primary,
        fontSize: 19,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      h3: TextStyle(
        color: primary,
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      h1Padding: const EdgeInsets.only(top: 14, bottom: 6),
      h2Padding: const EdgeInsets.only(top: 12, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 10, bottom: 4),
      strong: TextStyle(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: baseFontSize,
        height: baseHeight,
      ),
      em: TextStyle(
        color: primary,
        fontStyle: FontStyle.italic,
        fontSize: baseFontSize,
        height: baseHeight,
      ),
      // Clean round bullets with breathing room — not cramped dashes.
      listBullet: TextStyle(
        color: primary,
        fontSize: baseFontSize,
        height: baseHeight,
      ),
      listIndent: 20,
      listBulletPadding: const EdgeInsets.only(right: 8),
      blockSpacing: 10,
      // Distinct code/formula styling so `E = mc²` never looks like prose.
      code: TextStyle(
        color: primary,
        fontSize: baseFontSize - 1,
        fontFamily: 'monospace',
        backgroundColor: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      // Table look for compact fact tables (revision sheets etc).
      tableHead: TextStyle(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: baseFontSize - 1,
      ),
      tableBody: TextStyle(
        color: primary,
        fontSize: baseFontSize - 1,
        height: 1.4,
      ),
      tableBorder: TableBorder.all(
        color: AppTheme.getCardBorder(context),
        width: 1,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      blockquoteDecoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: secondary, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.getCardBorder(context)),
        ),
      ),
    );
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
            child: MarkdownBody(
              data: widget.text,
              selectable: false, // SelectionArea already handles selection
              styleSheet: _markdownStyle(context),
              softLineBreak: true,
            ),
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