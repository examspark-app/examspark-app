import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/services/home_ask_bridge.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/utils/dom_selection.dart';

/// Study content selection → default **Ask AI** → Home chat (app-wide).
///
/// Visible **Ask AI** bar (Web-safe). Context menu Ask AI as backup.
class SelectableStudyText extends StatefulWidget {
  final Widget child;
  final String lectureId;
  final String sourceSurface;

  const SelectableStudyText({
    super.key,
    required this.child,
    required this.lectureId,
    required this.sourceSurface,
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
    // Web: SelectionArea often won't fire selection callbacks — poll DOM.
    _poll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final dom = readDomTextSelection();
      if (dom == null) {
        if (_selected.isNotEmpty && mounted) setState(() => _selected = '');
        return;
      }
      if (dom == _selected) return;
      if (mounted) setState(() => _selected = dom);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _askAi(String selected) async {
    final trimmed = selected.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle text select (highlight) karo, phir Ask AI.'),
        ),
      );
      return;
    }
    final prompt = homeAskPromptFromSelection(trimmed);

    final route = ModalRoute.of(context);
    if (route is ModalBottomSheetRoute && context.mounted) {
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    HomeAskBridge.instance.requestAsk(prompt);
  }

  Future<void> _askAiBestEffort() async {
    var text = _selected.trim();
    text = text.isNotEmpty ? text : (readDomTextSelection() ?? '');
    if (text.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text?.trim() ?? '';
    }
    if (!mounted) return;
    await _askAi(text);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: hasSelection
              ? AppTheme.getAccentTint(context)
              : AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _askAiBestEffort,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ask AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getPrimaryText(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasSelection
                          ? '· send selection to Home'
                          : '· highlight text, then tap',
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
            contextMenuBuilder: (context, selectableRegionState) {
              final items = <ContextMenuButtonItem>[
                ContextMenuButtonItem(
                  label: 'Ask AI',
                  onPressed: () async {
                    ContextMenuController.removeAny();
                    var text = _selected.trim();
                    if (text.isEmpty) {
                      text = readDomTextSelection() ?? '';
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
                    if (text.isEmpty || !context.mounted) return;
                    await _askAi(text);
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
