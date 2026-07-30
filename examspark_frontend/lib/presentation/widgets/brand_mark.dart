import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Shared Sonaxia mark + wordmark (Home top bar, Login, etc.).
class BrandMark extends StatelessWidget {
  final double tileSize;
  final double fontSize;
  final bool showWordmark;

  const BrandMark({
    super.key,
    this.tileSize = 30,
    this.fontSize = 17,
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    final letterSize = tileSize >= 48 ? tileSize * 0.5 : 16.0;
    final radius = tileSize >= 48 ? 16.0 : 8.0;
    return Semantics(
      label: '${AppBrand.name} app logo',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(radius),
            ),
            alignment: Alignment.center,
            child: Text(
              AppBrand.markLetter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: letterSize,
                height: 1,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (showWordmark) ...[
            const SizedBox(width: 10),
            Text(
              AppBrand.name,
              style: AppBrand.wordmarkStyle(context, fontSize: fontSize),
            ),
          ],
        ],
      ),
    );
  }
}

/// Login hero: big tile + wordmark stacked (clear brand first).
class BrandHero extends StatelessWidget {
  const BrandHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandMark(tileSize: 64, showWordmark: false),
        const SizedBox(height: 16),
        Text(
          AppBrand.name,
          style: AppBrand.heroWordmarkStyle(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
