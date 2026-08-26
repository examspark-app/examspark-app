import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/theme/responsive.dart';

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
    final screenW = MediaQuery.sizeOf(context).width;
    final isCompact = Responsive.isMobile(context);

    final effectiveTileSize = isCompact
        ? (tileSize * (screenW < 360 ? 0.82 : 1.0)).clamp(18.0, tileSize)
        : tileSize;
    final effectiveFontSize = isCompact
        ? (fontSize * (screenW < 360 ? 0.85 : 1.0)).clamp(12.0, fontSize)
        : fontSize;

    final letterSize = effectiveTileSize >= 48
        ? effectiveTileSize * 0.5
        : (effectiveTileSize * 0.52).clamp(12.0, 16.0);
    final radius = effectiveTileSize >= 48 ? 16.0 : 8.0;
    final logoPadding = effectiveTileSize >= 48 ? 6.0 : 3.0;

    return Semantics(
      label: '${AppBrand.name} app logo',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: effectiveTileSize,
              maxHeight: effectiveTileSize,
            ),
            child: Container(
              width: effectiveTileSize,
              height: effectiveTileSize,
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(radius),
              ),
              padding: EdgeInsets.all(logoPadding),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius - logoPadding),
                child: Image.network(
                  AppBrand.logoPath,
                  fit: BoxFit.contain,
                  width: effectiveTileSize - logoPadding * 2,
                  height: effectiveTileSize - logoPadding * 2,
                  errorBuilder: (context, error, stackTrace) {
                    return FittedBox(
                      fit: BoxFit.contain,
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
                    );
                  },
                ),
              ),
            ),
          ),
          if (showWordmark) ...[
            const SizedBox(width: 10),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                AppBrand.name,
                style: AppBrand.wordmarkStyle(
                  context,
                  fontSize: effectiveFontSize,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
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