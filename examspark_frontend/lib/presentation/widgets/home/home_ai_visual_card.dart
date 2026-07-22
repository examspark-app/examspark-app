import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Dedicated Visual Card under Home AI answer — never dump diagrams into chat text.
/// Founder Lock: Home AI Mobile UX (Jul 18, 2026).
class HomeAiVisualCard extends StatefulWidget {
  final Map<String, dynamic> visualPayload;
  final bool initiallyExpanded;

  const HomeAiVisualCard({
    super.key,
    required this.visualPayload,
    this.initiallyExpanded = true,
  });

  @override
  State<HomeAiVisualCard> createState() => _HomeAiVisualCardState();
}

class _HomeAiVisualCardState extends State<HomeAiVisualCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final data = VisualPayloadData.fromJson(widget.visualPayload);
    if (data.isEmpty) return const SizedBox.shrink();

    final secondary = AppTheme.getSecondaryText(context);
    final border = AppTheme.getCardBorder(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_mosaic_outlined,
                    size: 18,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visual',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.getPrimaryText(context),
                      ),
                    ),
                  ),
                  Text(
                    _expanded ? 'Hide' : 'Show',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: secondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SmartEducationalContent(
                markdownBody: '',
                visualPayload: data,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
