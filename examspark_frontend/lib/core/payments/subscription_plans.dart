/// Subscription plan catalog — Credit Economy v2 (Jul 2026).
class SubscriptionPlanDef {
  final String id;
  final String name;
  final String tier;
  final int monthlyCredits;
  final int priceInrPaise;
  final List<String> features;
  final bool isPopular;

  /// How many Groups a student on this plan may **join** at once. `-1` =
  /// unlimited join. Founder-locked Jul 26, 2026: free=0, plan_199=1,
  /// plan_499=3, plan_999=6, **teacher=0** (own Groups only — cannot join
  /// another teacher as a student). Create Group is separate (Teacher plan).
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
    monthlyCredits: 50,
    priceInrPaise: 0,
    maxGroups: 0,
    features: [
      '50 credits/month to get started',
      'Use for quick Ask AI + study help',
      'Beauty Care AI access on basics',
      'Language Practice starter access',
      'Upgrade later for premium models',
    ],
  );

  static const plan199 = SubscriptionPlanDef(
    id: 'plan_199',
    name: '₹199',
    tier: 'plan_199',
    monthlyCredits: 400,
    priceInrPaise: 19900,
    maxGroups: 1,
    features: [
      '400 AI Credits / Month',
      'Unlocks better AI model access',
      'Use for Language Practice + chat learning',
      'Beauty Care AI stays available',
      '1 Group included for collaboration',
      'More room for daily study tasks',
    ],
  );

  static const plan499 = SubscriptionPlanDef(
    id: 'plan_499',
    name: '₹499',
    tier: 'plan_499',
    monthlyCredits: 1000,
    priceInrPaise: 49900,
    maxGroups: 3,
    features: [
      '1,000 AI Credits / Month',
      'Unlocks best model access',
      'Language Practice without friction',
      'Beauty Care AI + full-study tools',
      'Claude Premium included',
      'Up to 3 Group joins included',
    ],
    isPopular: true,
  );

  static const plan999 = SubscriptionPlanDef(
    id: 'plan_999',
    name: '₹999',
    tier: 'plan_999',
    monthlyCredits: 2000,
    priceInrPaise: 99900,
    maxGroups: 6,
    features: [
      '2,000 AI Credits / Month',
      'Best model access for every feature',
      'Language Practice + roleplay ready',
      'Beauty Care AI included',
      'Premium usage with more room to explore',
      'Up to 6 Group joins included',
    ],
  );

  static const teacher = SubscriptionPlanDef(
    id: 'teacher',
    name: 'Teacher',
    tier: 'teacher',
    monthlyCredits: 10000,
    priceInrPaise: 299900,
    // Join as student = 0. Own Groups create = unlimited (separate gate).
    maxGroups: 0,
    features: [
      '10,000 AI Credits / Month',
      'Best model access across all tools',
      'Language Practice for teaching workflows',
      'Beauty Care AI + classroom tooling',
      'Create and manage your own groups',
      'Built for teacher-scale usage',
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
    CreditPackDef(
      id: 'pack_100',
      name: '100 Credits',
      credits: 100,
      priceInrPaise: 2500,
    ),
    CreditPackDef(
      id: 'pack_500',
      name: '500 Credits',
      credits: 500,
      priceInrPaise: 11000,
    ),
    CreditPackDef(
      id: 'pack_1000',
      name: '1,000 Credits',
      credits: 1000,
      priceInrPaise: 20000,
    ),
    CreditPackDef(
      id: 'pack_5000',
      name: '5,000 Credits',
      credits: 5000,
      priceInrPaise: 85000,
    ),
    CreditPackDef(
      id: 'pack_10000',
      name: '10,000 Credits',
      credits: 10000,
      priceInrPaise: 150000,
    ),
  ];

  static CreditPackDef? creditPackById(String id) {
    for (final p in creditPacks) {
      if (p.id == id) return p;
    }
    return null;
  }
}
