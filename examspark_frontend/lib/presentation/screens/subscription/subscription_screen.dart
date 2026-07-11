import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/payments/payment_service.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';

/// Subscription Screen & Credit Management
/// Plan selection and credit purchase interface
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Current user plan data
  String _currentPlan = 'Free';
  int _remainingCredits = 3240;
  int _totalCredits = 5000;
  String _renewalDate = 'Feb 15, 2026';

  // Available plans (from canonical catalog — Credit Economy v2)
  late final List<SubscriptionPlan> _plans = SubscriptionPlans.all
      .map(
        (p) => SubscriptionPlan(
          id: p.id,
          name: p.name,
          price: p.priceInr,
          credits: p.monthlyCredits,
          features: p.features,
          isPopular: p.isPopular,
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final progressValue = _remainingCredits / _totalCredits;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Plans',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Banner
            _buildCurrentPlanBanner(progressValue),
            const SizedBox(height: 32),

            // Plans header
            Text(
              'Choose Your Plan',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Plan Cards List
            ..._plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PlanCard(
                plan: plan,
                isCurrentPlan: plan.id == _currentPlan.toLowerCase(),
                onUpgrade: () => _initiatePaymentGatewayCheckout(plan),
              ),
            )),

            const SizedBox(height: 32),

            // Extra Hours Add-on Section
            _buildExtraHoursSection(),

            const SizedBox(height: 32),

            // Credit Top-ups
            Text(
              'Credit Top-ups',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTopUpOptions(),

            const SizedBox(height: 32),

            // Credit Cost Reference
            Text(
              'Credit Costs',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildCostReference(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanBanner(double progressValue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.getAccentTint(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_currentPlan Plan',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Upgrade to get more credits',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$_remainingCredits',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $_totalCredits credits left',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: AppTheme.getCardBorder(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Resets on $_renewalDate',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getSecondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraHoursSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.getCardBorder(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buy Extra Hours',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹39/hour • Add more transcription time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _showExtraHoursPicker(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
            ),
            child: const Text('Buy Extra Hours'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpOptions() {
    const topUps = [
      (50, 4.99),
      (100, 8.99),
      (250, 19.99),
      (500, 34.99),
      (1000, 59.99),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: topUps.length,
      itemBuilder: (context, index) {
        final (credits, price) = topUps[index];
        return InkWell(
          onTap: () => _handleTopUp(credits, price),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.getCardBorder(context)),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              color: AppTheme.getCardBackground(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$credits',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'credits',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.getAccentTint(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '\$$price',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCostReference() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feature Credit Costs',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          _buildCostRow('Record ≤30 min', CreditCosts.recordUpTo30Min),
          _buildCostRow('Record 30–60 min', CreditCosts.record30To60Min),
          _buildCostRow('Record 60–90 min', CreditCosts.record60To90Min),
          _buildCostRow('Ask AI (Normal)', CreditCosts.askAiNormal),
          _buildCostRow('Ask AI (Deep)', CreditCosts.askAiDeep),
          _buildCostRow('PDF Analysis', CreditCosts.pdfAnalysis),
          _buildCostRow('Diagram / Image', CreditCosts.diagramImage),
          _buildCostRow('Quiz (20 MCQ)', CreditCosts.quiz20Mcq),
          _buildCostRow('Flashcards', CreditCosts.flashcards),
          _buildCostRow('Mind Map', CreditCosts.mindMap),
          _buildCostRow('Formula Sheet', CreditCosts.formulaSheet),
          _buildCostRow('Translate', CreditCosts.translate),
          _buildCostRow('Voice Read', CreditCosts.voiceRead),
        ],
      ),
    );
  }

  Widget _buildCostRow(String feature, int cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(feature, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            '$cost credits',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTopUp(int credits, double price) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Purchase Credits'),
        content: Text('Purchase $credits credits for \$$price?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Credit pack purchase via PaymentService.purchaseCreditPack
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Credit packs pending — payment gateway not connected (TODO)',
                  ),
                ),
              );
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }

  void _showExtraHoursPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExtraHoursPickerSheet(
        onPurchase: (hours) => _initiatePaymentGatewayCheckout(
          SubscriptionPlan(
            id: 'extra_hours',
            name: 'Extra Hours',
            price: 39 * hours,
            credits: hours * 100, // 100 credits per hour equivalent
            features: ['$hours hours of transcription'],
            isPopular: false,
          ),
        ),
      ),
    );
  }

  /// Payment flow: create order → pending → verify (no fake success).
  void _initiatePaymentGatewayCheckout(SubscriptionPlan plan) async {
    final planDef = SubscriptionPlans.all.firstWhere(
      (p) => p.id == plan.id,
      orElse: () => SubscriptionPlans.plan199,
    );

    final result = await PaymentService.instance.purchasePlan(
      userId: 'current_user', // TODO: Supabase auth user id
      plan: planDef,
    );

    if (!mounted) return;

    if (result.status == PaymentResultStatus.verified) {
      _showPaymentSuccessSheet(plan);
      return;
    }

    if (result.status == PaymentResultStatus.pending ||
        result.status == PaymentResultStatus.orderCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.orderId != null
                ? 'Order ${result.orderId} pending — complete payment when gateway is connected'
                : result.message,
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  void _showPaymentSuccessSheet(SubscriptionPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.getAccentTint(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 48,
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Plan activated!',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${plan.name} plan is now active',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.getSecondaryText(context),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close success sheet
                  // Update local state
                  setState(() {
                    _currentPlan = plan.id;
                    _totalCredits = plan.credits;
                    _remainingCredits = plan.credits;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PLAN CARD WIDGET ====================

class PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrentPlan;
  final VoidCallback onUpgrade;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrentPlan,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: plan.isPopular
              ? AppTheme.accentColor
              : AppTheme.getCardBorder(context),
          width: plan.isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with popular tag
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${plan.price}',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Most Popular',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${plan.credits} credits/month',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Features list
          ...plan.features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )),

          const SizedBox(height: 20),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isCurrentPlan
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppTheme.getSecondaryText(context),
                      side: BorderSide(
                        color: AppTheme.getCardBorder(context),
                      ),
                    ),
                    child: const Text('Current Plan'),
                  )
                : ElevatedButton(
                    onPressed: onUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isPopular
                          ? AppTheme.accentColor
                          : AppTheme.getPrimaryText(context),
                      foregroundColor: plan.isPopular
                          ? Colors.white
                          : AppTheme.getCardBackground(context),
                    ),
                    child: const Text('Upgrade'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== EXTRA HOURS PICKER SHEET ====================

class _ExtraHoursPickerSheet extends StatefulWidget {
  final Function(int) onPurchase;

  const _ExtraHoursPickerSheet({
    required this.onPurchase,
  });

  @override
  State<_ExtraHoursPickerSheet> createState() => _ExtraHoursPickerSheetState();
}

class _ExtraHoursPickerSheetState extends State<_ExtraHoursPickerSheet> {
  int _selectedHours = 1;
  final List<int> _hourOptions = [1, 5, 10];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Hours',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹39/hour • Flat rate',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 24),

          // Hour options
          Row(
            children: _hourOptions.map((hours) {
              final isSelected = _selectedHours == hours;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: hours < _hourOptions.last ? 12 : 0,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedHours = hours),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.getAccentTint(context)
                            : AppTheme.getCardBackground(context),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentColor
                              : AppTheme.getCardBorder(context),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$hours hr',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppTheme.accentColor
                                  : AppTheme.getPrimaryText(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${39 * hours}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? AppTheme.accentColor
                                  : AppTheme.getSecondaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Purchase button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                widget.onPurchase(_selectedHours);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Pay ₹${39 * _selectedHours}'),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SUBSCRIPTION PLAN MODEL ====================

class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final int credits;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.credits,
    required this.features,
    required this.isPopular,
  });
}
