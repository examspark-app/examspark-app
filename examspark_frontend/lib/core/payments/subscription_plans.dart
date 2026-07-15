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

/// A-la-carte credit top-up — for users who don't want to upgrade their
/// subscription plan but need more credits this month. Founder-locked
/// Jul 13, 2026: priced so the per-credit rate is always >= the cheapest
/// subscription plan's rate (plan_199 = ~₹0.153/credit), so top-ups never
/// undercut the incentive to subscribe. No teacher commission applies to
/// top-up purchases (commission is on recurring subscription price only).
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

  int get priceInr => priceInrPaise ~/ 100;

  double get effectiveRupeePerCredit => credits > 0 ? priceInr / credits : 0;
}

class SubscriptionPlans {
  SubscriptionPlans._();

  static const free = SubscriptionPlanDef(
    id: 'free',
    name: 'Free',
    tier: 'free',
    monthlyCredits: 75,
    priceInrPaise: 0,
    maxGroups: 0,
    features: [
      '75 credits/month',
      'Ask AI + PDF Analysis',
      'No audio or photo/diagram upload',
      'Cannot join Groups',
    ],
  );

  static const plan199 = SubscriptionPlanDef(
    id: 'plan_199',
    name: '₹199',
    tier: 'plan_199',
    monthlyCredits: 1500,
    priceInrPaise: 19900,
    maxGroups: 1,
    features: [
      '1,500 credits/month',
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
    monthlyCredits: 16000,
    priceInrPaise: 199900,
    maxGroups: -1,
    features: [
      '16,000 credits/month',
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
    CreditPackDef(id: 'pack_100', name: '100 Credits', credits: 100, priceInrPaise: 2500),
    CreditPackDef(id: 'pack_500', name: '500 Credits', credits: 500, priceInrPaise: 11000),
    CreditPackDef(id: 'pack_1000', name: '1,000 Credits', credits: 1000, priceInrPaise: 20000),
    CreditPackDef(id: 'pack_5000', name: '5,000 Credits', credits: 5000, priceInrPaise: 85000),
    CreditPackDef(id: 'pack_10000', name: '10,000 Credits', credits: 10000, priceInrPaise: 150000),
  ];

  static CreditPackDef? creditPackById(String id) {
    for (final p in creditPacks) {
      if (p.id == id) return p;
    }
    return null;
  }
}
