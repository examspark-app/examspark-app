import 'dart:async';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class GlowGuideRotatingButton extends StatefulWidget {
  const GlowGuideRotatingButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<GlowGuideRotatingButton> createState() => _GlowGuideRotatingButtonState();
}

class _GlowGuideRotatingButtonState extends State<GlowGuideRotatingButton> {
  static const labels = [
    'Skin Care',
    'Body Care',
    'Baby Skin Care',
    'Cloth Guide',
  ];

  var _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % labels.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: widget.onTap,
      icon: const Icon(Icons.eco_outlined, size: 17),
      label: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .35),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          labels[_index],
          key: ValueKey(labels[_index]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.glowGuidePurple,
        side: const BorderSide(color: AppTheme.glowGuidePurple),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
