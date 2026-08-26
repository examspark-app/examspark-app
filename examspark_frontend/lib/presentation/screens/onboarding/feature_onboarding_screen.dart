import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class FeatureOnboardingScreen extends StatelessWidget {
  const FeatureOnboardingScreen({
    super.key,
    required this.userId,
    required this.onFeatureSelected,
  });

  final String userId;
  final void Function(String feature) onFeatureSelected;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _FeatureCard(
        title: 'Study AI',
        subtitle: 'Chat with lectures, summaries, quizzes & notes',
        onTap: () => onFeatureSelected('ai'),
      ),
      _FeatureCard(
        title: 'English Practice',
        subtitle: 'Learn any language — chat, speak, roleplay',
        onTap: () => onFeatureSelected('english'),
      ),
      _FeatureCard(
        title: 'Skin Care AI',
        subtitle: 'Science-based glow, body & cloth care guidance',
        onTap: () => onFeatureSelected('glowguide'),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final isMobile = screenW < 520;

            final outerPad = isMobile ? 16.0 : 28.0;
            final headlineSize = isMobile ? 22.0 : 26.0;
            final subSize = isMobile ? 13.5 : 14.5;

            return Padding(
              padding: EdgeInsets.fromLTRB(outerPad, 28, outerPad, outerPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Sonaxia',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: headlineSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the feature you want to begin with.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: subSize,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: cards.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: isMobile ? 12 : 16),
                      itemBuilder: (_, index) => cards[index],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF7C4DFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _isPressed = true),
      onExit: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: _isPressed ? 5 : 2,
            shadowColor: purple.withValues(alpha: 0.18),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onHighlightChanged: (highlighted) {
                setState(() => _isPressed = highlighted);
              },
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: purple.withValues(alpha: 0.55),
                    width: 1.1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: purple.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
