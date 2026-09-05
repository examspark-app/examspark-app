import 'package:flutter_test/flutter_test.dart';
import 'package:examspark_frontend/presentation/screens/glow_guide/glow_guide_screen.dart';

void main() {
  group('GlowGuide custom input visibility', () {
    test('hides custom input unless the user explicitly opens it', () {
      expect(
        glowGuideShouldShowCustomInput(
          hasCustomInput: true,
          isLanguageChips: false,
          isCategoryChips: false,
          isConcernChips: true,
          isAgeChips: false,
          isGenderChips: false,
          isSeasonChips: false,
          customInputFlowOpen: false,
        ),
        isFalse,
      );

      expect(
        glowGuideShouldShowCustomInput(
          hasCustomInput: true,
          isLanguageChips: false,
          isCategoryChips: false,
          isConcernChips: true,
          isAgeChips: false,
          isGenderChips: false,
          isSeasonChips: false,
          customInputFlowOpen: true,
        ),
        isTrue,
      );
    });
  });
}
