import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// A reusable shimmering placeholder — drop this in anywhere a list/card
/// is waiting on data from the database (recent chats, subjects, profile
/// fields, etc.) instead of leaving a bare empty box that pops to real
/// content with no transition.
///
/// Usage:
/// ```dart
/// StreamBuilder<List<Chat>>(
///   stream: chatsStream,
///   builder: (context, snapshot) {
///     if (!snapshot.hasData) {
///       return Column(
///         children: List.generate(
///           6,
///           (_) => const Padding(
///             padding: EdgeInsets.symmetric(vertical: 6),
///             child: SkeletonLine(height: 20),
///           ),
///         ),
///       );
///     }
///     return _buildRealList(snapshot.data!);
///   },
/// )
/// ```
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.getCardBorder(context);
    final highlight = AppTheme.getCardBackground(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: ShaderMask(
              shaderCallback: (bounds) {
                final t = _controller.value;
                return LinearGradient(
                  begin: Alignment(-1.5 + 3 * t, 0),
                  end: Alignment(-0.5 + 3 * t, 0),
                  colors: [base, highlight, base],
                  stops: const [0.35, 0.5, 0.65],
                ).createShader(bounds);
              },
              child: Container(color: base),
            ),
          ),
        );
      },
    );
  }
}

/// Convenience wrapper for a single skeleton text line — the most common
/// case (a chat title, a name, a label).
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Skeleton(
          width: width ?? constraints.maxWidth,
          height: height,
          borderRadius: 6,
        );
      },
    );
  }
}

/// A full skeleton row shaped like a "Recent chats" list item — an icon
/// placeholder plus a title line, matching the real row's layout so there
/// is no size jump when the real data swaps in.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Skeleton(width: 20, height: 20, borderRadius: 5),
          const SizedBox(width: 14),
          Expanded(child: SkeletonLine(height: 15)),
        ],
      ),
    );
  }
}

/// A ready-to-use list of skeleton rows for the "Recent chats" drawer —
/// swap this in for the loading state so the transition from placeholder
/// to real chat list feels seamless instead of a 1-second box flash.
class SkeletonChatList extends StatelessWidget {
  const SkeletonChatList({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (_) => const SkeletonListTile(),
      ),
    );
  }
}