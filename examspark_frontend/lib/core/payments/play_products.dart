/// Google Play product IDs — must match Play Console + backend payment_catalog.py.
class PlayProducts {
  PlayProducts._();

  static const Map<String, String> planToProduct = {
    'plan_199': 'examspark_plan_199',
    'plan_299': 'examspark_plan_299',
    'plan_499': 'examspark_plan_499',
    'plan_999': 'examspark_plan_999',
    'teacher': 'examspark_plan_teacher',
  };

  static const Map<String, String> packToProduct = {
    'pack_100': 'examspark_pack_100',
    'pack_500': 'examspark_pack_500',
    'pack_1000': 'examspark_pack_1000',
    'pack_5000': 'examspark_pack_5000',
    'pack_10000': 'examspark_pack_10000',
  };

  static String? productForPlan(String planId) => planToProduct[planId];

  static String? productForPack(String packId) => packToProduct[packId];

  static bool isSubscriptionProduct(String productId) =>
      planToProduct.containsValue(productId);
}
