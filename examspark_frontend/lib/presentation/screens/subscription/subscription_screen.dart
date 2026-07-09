import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

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

  // Available plans
  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      id: 'free',
      name: 'Free',
      price: 0,
      credits: 100,
      features: [
        '100 credits/month',
        'Basic transcription',
        'Standard support',
      ],
      isPopular: false,
    ),
    SubscriptionPlan(
      id: 'starter',
      name: 'Starter',
      price: 99,
      credits: 500,
      features: [
        '500 credits/month',
        'Fast transcription',
        'Priority support',
        'RAG access',
      ],
      isPopular: false,
    ),
    SubscriptionPlan(
      id: 'growth',
      name: 'Growth',
      price: 499,
      credits: 2500,
      features: [
        '2,500 credits/month',
        'High accuracy mode',
        'Priority processing',
        'Advanced RAG',
        'Export features',
      ],
      isPopular: false,
    ),
    SubscriptionPlan(
      id: 'standard',
      name: 'Standard',
      price: 999,
      credits: 5000,
      features: [
        '5,000 credits/month',
        'All Growth features',
        'API access',
        'Team collaboration',
        'Analytics dashboard',
      ],
      isPopular: true,
    ),
    SubscriptionPlan(
      id: 'teacher',
      name: 'Teacher',
      price: 1999,
      credits: 8000,
      features: [
        '8,000 credits/month',
        'PDF export',
        'Branded PDF & shareable link',
        'Class folders management',
        'Logo branding',
        'Student analytics',
        'Bulk processing',
      ],
      isPopular: false,
    ),
  ];

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

  /// PENDING PAYMENT GATEWAY INTEGRATION
  /// This method is a placeholder for payment gateway integration
  /// TODO: Insert chosen Razorpay/Stripe production keys and plugin config here
  void _initiatePaymentGatewayCheckout(SubscriptionPlan plan) {
    // PENDING: Insert chosen Razorpay/Stripe production keys and plugin config here
    // 
    // Example Razorpay integration:
    // var options = {
    //   'key': 'YOUR_RAZORPAY_KEY',
    //   'amount': plan.price * 100, // Amount in paise
    //   'name': 'ExamSpark',
    //   'description': '${plan.name} Plan',
    //   'prefill': {'contact': '', 'email': ''},
    // };
    // razorpay.open(options);
    
    // Example Stripe integration:
    // await Stripe.instance.initPaymentSheet(
    //   paymentSheetParameters: SetupPaymentSheetParameters(
    //     merchantDisplayName: 'ExamSpark',
    //     paymentIntentClientSecret: paymentIntentClientSecret,
    //     // ... other parameters
    //   ),
    // );
    // await Stripe.instance.presentPaymentSheet();

    // SIMULATED SUCCESS CALLBACK
    // In production, this would be triggered after successful payment
    _showPaymentSuccessSheet(plan);
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
