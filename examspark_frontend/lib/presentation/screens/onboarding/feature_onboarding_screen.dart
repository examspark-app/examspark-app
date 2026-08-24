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
        title: 'AI Learning',
        subtitle: 'Chat, summarize lectures, generate quizzes & notes',
        onTap: () => onFeatureSelected('ai'),
      ),
      _FeatureCard(
        title: 'English Practice',
        subtitle: 'Learn any language — chat, speak, or roleplay',
        onTap: () => onFeatureSelected('english'),
      ),
      _FeatureCard(
        title: 'GlowGuide',
        subtitle: 'Science-based skin, body & cloth care guidance',
        onTap: () => onFeatureSelected('glowguide'),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Sonaxia',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the feature you want to begin with.',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) => cards[index],
                ),
              ),
            ],
          ),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isPressed = true),
      onExit: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: _isPressed ? 4 : 1,
          shadowColor: AppTheme.glowGuidePurple.withValues(alpha: 0.16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onHighlightChanged: (highlighted) {
              setState(() => _isPressed = highlighted);
            },
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.glowGuidePurple.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: AppTheme.glowGuidePurple,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
