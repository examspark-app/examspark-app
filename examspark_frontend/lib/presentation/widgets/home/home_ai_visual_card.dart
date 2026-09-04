import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';
import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';

/// Dedicated Visual Card under Home AI answer — never dump diagrams into chat text.
/// Founder Lock: Home AI Mobile UX (Jul 18, 2026).
class HomeAiVisualCard extends StatefulWidget {
  final Map<String, dynamic> visualPayload;
  final bool initiallyExpanded;
  final VoidCallback? onRetry;

  const HomeAiVisualCard({
    super.key,
    required this.visualPayload,
    this.initiallyExpanded = true,
    this.onRetry,
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

  Widget _buildErrorState(BuildContext context) {
    final border = AppTheme.getCardBorder(context);
    final secondary = AppTheme.getSecondaryText(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Colors.amber.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Visual Explanation unavailable',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.getPrimaryText(context),
                  ),
                ),
                Text(
                  'Could not load visual diagram',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onRetry != null)
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentColor,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visualPayload['has_error'] == true ||
        widget.visualPayload['error'] != null) {
      return _buildErrorState(context);
    }

    VisualPayloadData data;
    try {
      data = VisualPayloadData.fromJson(widget.visualPayload);
    } catch (_) {
      return _buildErrorState(context);
    }

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
                      'Visual Explanation',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SmartEducationalContent(
                    markdownBody: '',
                    visualPayload: data,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showFullView(context, data),
                        icon: const Icon(Icons.fullscreen_rounded, size: 16),
                        label: const Text('Full View', style: TextStyle(fontSize: 11.5)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accentColor,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => _downloadVisual(context, data),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download', style: TextStyle(fontSize: 11.5)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accentColor,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ],
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

  void _showFullView(BuildContext context, VisualPayloadData data) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: AppTheme.getCardBackground(ctx),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text(
                  'Visual Explanation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SmartEducationalContent(
                      markdownBody: '',
                      visualPayload: data,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadVisual(BuildContext context, VisualPayloadData data) {
    AppToast.show(
      'Visual diagram saved to Study Workspace!',
      isError: false,
    );
  }
}
