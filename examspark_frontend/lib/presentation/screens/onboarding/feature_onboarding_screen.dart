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
      _FeatureCardData(
        icon: Icons.smart_toy_outlined,
        iconColor: const Color(0xFF7C4DFF),
        title: 'Study AI',
        tagline: 'Turn any lecture into a full study kit',
        bullets: const [
          'Record a class, get clean notes and summary',
          'Auto quiz, flashcards and revision sheets',
          'Ask AI anything about the lecture',
        ],
        ctaLabel: 'Try Study AI',
        popular: true,
        feature: 'ai',
      ),
      _FeatureCardData(
        icon: Icons.record_voice_over_outlined,
        iconColor: const Color(0xFF12A594),
        title: 'English practice',
        tagline: 'Speak, roleplay, get fluent by doing',
        bullets: const [
          'Live voice chat with instant correction',
          'Roleplay interviews, travel, office chats',
          'Any language, any accent, your pace',
        ],
        ctaLabel: 'Try English practice',
        popular: false,
        feature: 'english',
      ),
      _FeatureCardData(
        icon: Icons.auto_awesome_outlined,
        iconColor: const Color(0xFFD85A30),
        title: 'Skin care AI',
        tagline: 'Glow, body and baby care guidance',
        bullets: const [
          'Science-based skin and body routines',
          'Baby skin care and cloth guidance',
          'Chat in your own language',
        ],
        ctaLabel: 'Try Skin care AI',
        popular: false,
        feature: 'glowguide',
      ),
    ];

    return Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.light
    ? AppTheme.lightBackground
    : AppTheme.darkBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final isMobile = screenW < 700;

            final outerPad = isMobile ? 16.0 : 32.0;
            final headlineSize = isMobile ? 22.0 : 28.0;
            final subSize = isMobile ? 13.5 : 15.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(outerPad, 28, outerPad, outerPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Sonaxia',
                    style: TextStyle(
                      color: AppTheme.getPrimaryText(context),
                      fontSize: headlineSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the feature you want to begin with.',
                    style: TextStyle(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: subSize,
                    ),
                  ),
                  const SizedBox(height: 24),
                  isMobile
                      ? Column(
                          children: [
                            for (final c in cards) ...[
                              _FeatureCard(data: c, onTap: () => onFeatureSelected(c.feature)),
                              const SizedBox(height: 14),
                            ],
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < cards.length; i++) ...[
                              Expanded(
                                child: _FeatureCard(
                                  data: cards[i],
                                  onTap: () => onFeatureSelected(cards[i].feature),
                                ),
                              ),
                              if (i != cards.length - 1) const SizedBox(width: 16),
                            ],
                          ],
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

class _FeatureCardData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String tagline;
  final List<String> bullets;
  final String ctaLabel;
  final bool popular;
  final String feature;

  const _FeatureCardData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.tagline,
    required this.bullets,
    required this.ctaLabel,
    required this.popular,
    required this.feature,
  });
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.data, required this.onTap});

  final _FeatureCardData data;
  final VoidCallback onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final borderColor = d.popular ? d.iconColor : AppTheme.getCardBorder(context);
    final borderWidth = d.popular ? 2.0 : 1.1;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 0.99 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Material(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(18),
          elevation: _hover ? 6 : 2,
          shadowColor: d.iconColor.withValues(alpha: 0.15),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: d.iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: Icon(d.icon, color: d.iconColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppTheme.getPrimaryText(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  d.tagline,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.getSecondaryText(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (final b in d.bullets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: d.iconColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: AppTheme.getPrimaryText(context).withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: d.popular
                                ? d.iconColor
                                : AppTheme.getCardBackground(context),
                            foregroundColor: d.popular
                                ? Colors.white
                                : AppTheme.getPrimaryText(context),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: d.popular
                                  ? BorderSide.none
                                  : BorderSide(color: AppTheme.getCardBorder(context)),
                            ),
                          ),
                          child: Text(
                            d.ctaLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (d.popular)
                  Positioned(
                    top: -11,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: d.iconColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Most popular',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}