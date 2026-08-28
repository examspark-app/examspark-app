import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/presentation/widgets/workspace_ask_ai_pane.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/utils/dom_selection.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Study content selection → Reply → Home chat composer.
///
/// Group shared / read-only: [enableAskAi] false — select/copy only, no Reply.
class SelectableStudyText extends StatefulWidget {
  final Widget child;
  final String lectureId;
  final String sourceSurface;
  final bool enableAskAi;

  const SelectableStudyText({
    super.key,
    required this.child,
    required this.lectureId,
    required this.sourceSurface,
    this.enableAskAi = true,
  });

  @override
  State<SelectableStudyText> createState() => _SelectableStudyTextState();
}

class _SelectableStudyTextState extends State<SelectableStudyText> {
  String _selected = '';
  Timer? _poll;

  @override
  void initState() {
    super.initState();

    if (!widget.enableAskAi) return;

    // Web: SelectionArea often won't fire selection callbacks — poll DOM.
    _poll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final dom = readDomTextSelection();

      if (dom == null) {
        if (_selected.isNotEmpty && mounted) {
          setState(() => _selected = '');
        }
        return;
      }

      if (dom == _selected) return;

      if (mounted) {
        setState(() => _selected = dom);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<String> _bestEffortSelectedText(
    SelectableRegionState selectableRegionState,
  ) async {
    var text = _selected.trim();

    if (text.isEmpty) {
      text = (readDomTextSelection() ?? '').trim();
    }

    if (text.isEmpty) {
      for (final item
          in selectableRegionState.contextMenuButtonItems) {
        if (item.type == ContextMenuButtonType.copy) {
          item.onPressed?.call();
          break;
        }
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 40),
      );

      final data =
          await Clipboard.getData(Clipboard.kTextPlain);

      text = data?.text?.trim() ?? '';
    }

    return text;
  }

  Future<void> _replyWithSelectedText(
    SelectableRegionState selectableRegionState,
  ) async {
    if (!widget.enableAskAi) return;

    ContextMenuController.removeAny();

    final text = await _bestEffortSelectedText(
      selectableRegionState,
    );

    if (text.isEmpty) {
      if (!mounted) return;

      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text(
            'Pehle text select (highlight) karo, phir Reply ↩ dabao.',
          ),
        ),
      );

      return;
    }

        if (!mounted) return;
    _openWorkspaceAskAi(text);
  }

  Future<void> _replyFromTopButton() async {
    if (!widget.enableAskAi) return;

    var text = _selected.trim();

    if (text.isEmpty) {
      text = (readDomTextSelection() ?? '').trim();
    }

    if (text.isEmpty) {
      final data =
          await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text?.trim() ?? '';
    }

    if (text.isEmpty) {
      if (!mounted) return;

      AppToast.showSnackBar(
        context,
        const SnackBar(
          content: Text(
            'Pehle text select (highlight) karo, phir Reply ↩ dabao.',
          ),
        ),
      );

      return;
    }

        if (!mounted) return;
    _openWorkspaceAskAi(text);
  }
  
  void _openWorkspaceAskAi(String text) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ask AI')),
          body: SafeArea(
            child: WorkspaceAskAiPane(
              lectureId: widget.lectureId,
              initialQuery: text,
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (!widget.enableAskAi) {
      return SelectionArea(
        child: widget.child,
      );
    }

    final hasSelection = _selected.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: hasSelection
              ? AppTheme.getAccentTint(context)
              : AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: hasSelection ? _replyFromTopButton : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: hasSelection
                        ? AppTheme.accentColor
                        : AppTheme.getSecondaryText(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasSelection ? 'Reply ↩' : 'Highlight text',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: hasSelection
                          ? AppTheme.getPrimaryText(context)
                          : AppTheme.getSecondaryText(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasSelection
                          ? '· ask about this selection'
                          : '· select text first',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getSecondaryText(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: SelectionArea(
            contextMenuBuilder: (
              context,
              selectableRegionState,
            ) {
              final items = <ContextMenuButtonItem>[
                ContextMenuButtonItem(
                  label: 'Reply ↩',
                  onPressed: () {
                    unawaited(
                      _replyWithSelectedText(
                        selectableRegionState,
                      ),
                    );
                  },
                ),
                ...selectableRegionState.contextMenuButtonItems,
              ];

              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: selectableRegionState.contextMenuAnchors,
                buttonItems: items,
              );
            },
            child: widget.child,
          ),
        ),
      ],
    );
  }
}