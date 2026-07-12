/// Subscription plan catalog — Credit Economy v2 (Jul 2026).
class SubscriptionPlanDef {
  final String id;
  final String name;
  final String tier;
  final int monthlyCredits;
  final int priceInrPaise;
  final List<String> features;
  final bool isPopular;

  /// How many Groups a student on this plan may join at once. `-1` means
  /// unlimited. Founder-locked Jul 12, 2026: free=0, plan_199=1, plan_499=3,
  /// plan_999=6, teacher=-1. Enforced client-side for now (see
  /// `GroupsRepository.canJoinAnotherGroup()`) — real server-side
  /// enforcement is Phase 5.
  final int maxGroups;

  const SubscriptionPlanDef({
    required this.id,
    required this.name,
    required this.tier,
    required this.monthlyCredits,
    required this.priceInrPaise,
    required this.features,
    this.isPopular = false,
    this.maxGroups = 0,
  });

  bool get hasUnlimitedGroups => maxGroups < 0;

  int get priceInr => priceInrPaise ~/ 100;

  double get effectiveRupeePerCredit =>
      monthlyCredits > 0 ? priceInr / monthlyCredits : 0;
}

class CreditPackDef {
  final String id;
  final String name;
  final int credits;
  final int priceInrPaise;

  const CreditPackDef({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceInrPaise,
  });
}

class SubscriptionPlans {
  SubscriptionPlans._();

  static const free = SubscriptionPlanDef(
    id: 'free',
    name: 'Free',
    tier: 'free',
    monthlyCredits: 50,
    priceInrPaise: 0,
    maxGroups: 0,
    features: [
      '50 credits/month',
      'Ask AI only',
      'No audio, PDF, or photo upload',
      'Cannot join Groups',
    ],
  );

  static const plan199 = SubscriptionPlanDef(
    id: 'plan_199',
    name: '₹199',
    tier: 'plan_199',
    monthlyCredits: 1300,
    priceInrPaise: 19900,
    maxGroups: 1,
    features: [
      '1,300 credits/month',
      'Ask AI + PDF + Photo/Diagram',
      'Audio recording locked',
      'Join up to 1 Group',
    ],
  );

  static const plan499 = SubscriptionPlanDef(
    id: 'plan_499',
    name: '₹499',
    tier: 'plan_499',
    monthlyCredits: 3500,
    priceInrPaise: 49900,
    maxGroups: 3,
    features: [
      '3,500 credits/month',
      'Audio recording unlocked',
      'PDF + Diagram + Ask AI',
      'Join up to 3 Groups',
    ],
    isPopular: true,
  );

  static const plan999 = SubscriptionPlanDef(
    id: 'plan_999',
    name: '₹999',
    tier: 'plan_999',
    monthlyCredits: 8000,
    priceInrPaise: 99900,
    maxGroups: 6,
    features: [
      '8,000 credits/month',
      'Full access — no feature locks',
      'Join up to 6 Groups',
    ],
  );

  static const teacher = SubscriptionPlanDef(
    id: 'teacher',
    name: 'Teacher',
    tier: 'teacher',
    monthlyCredits: 20000,
    priceInrPaise: 199900,
    maxGroups: -1,
    features: [
      '20,000 credits/month',
      'Bulk Record Lecture',
      'PDF export + shareable links',
      'Class dashboard',
    ],
  );

  static const List<SubscriptionPlanDef> all = [
    free,
    plan199,
    plan499,
    plan999,
    teacher,
  ];

  static SubscriptionPlanDef? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static const List<CreditPackDef> creditPacks = [
    CreditPackDef(id: 'pack_500', name: '500 Credits', credits: 500, priceInrPaise: 19900),
  ];
}
