import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/payments/payment_service.dart';
import 'package:examspark_frontend/core/payments/models/payment_result.dart';
import 'package:examspark_frontend/core/payments/subscription_plans.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/constants/credit_usage_display.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Subscription Screen & Credit Management — Credits summary, history,
/// student vs teacher plan cards, INR credit packs (no Extra Hours / USD).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentPlanId = 'free';
  String _currentPlanName = 'Free';
  int _remainingCredits = 0;
  int _planMonthlyCredits = 50;
  String _periodLabel = '—';
  bool _paying = false;
  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];

  List<SubscriptionPlan> get _studentPlans => SubscriptionPlans.all
      .where((p) => p.id != 'teacher')
      .map(_toUiPlan)
      .toList();

  SubscriptionPlan get _teacherPlan => _toUiPlan(SubscriptionPlans.teacher);

  SubscriptionPlan _toUiPlan(SubscriptionPlanDef p) => SubscriptionPlan(
        id: p.id,
        name: p.name,
        price: p.priceInr,
        credits: p.monthlyCredits,
        features: p.features,
        isPopular: p.isPopular,
      );

  /// Used = allotment − balance when balance ≤ allotment; else top-ups inflate balance.
  int get _usedCredits {
    if (_remainingCredits >= _planMonthlyCredits) return 0;
    return _planMonthlyCredits - _remainingCredits;
  }

  bool get _balanceIncludesTopUps =>
      _remainingCredits > _planMonthlyCredits;

  double get _progressValue {
    if (_planMonthlyCredits <= 0) return 0;
    if (_balanceIncludesTopUps) return 1;
    return (_remainingCredits / _planMonthlyCredits).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await SupabaseClient.instance.getUserProfile(userId);
      final planId = await SupabaseClient.instance.getPlanTier(userId);
      final planDef = SubscriptionPlans.byId(planId) ?? SubscriptionPlans.free;
      final txs =
          await SupabaseClient.instance.getCreditTransactions(userId);
      final periodEnd = await _fetchPeriodEnd(userId);

      if (!mounted) return;
      setState(() {
        _currentPlanId = planId;
        _currentPlanName = planDef.name;
        _remainingCredits = profile?['credits_balance'] as int? ?? 0;
        _planMonthlyCredits = planDef.monthlyCredits;
        _periodLabel = periodEnd ?? (planId == 'free' ? 'Free plan' : 'Active');
        _transactions = txs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _fetchPeriodEnd(String userId) async {
    try {
      final row = await SupabaseClient.instance.client
          .from('user_subscriptions')
          .select('current_period_end')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('current_period_end', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final raw = row['current_period_end'] as String?;
      if (raw == null || raw.isEmpty) return null;
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt == null) return null;
      return _formatDate(dt);
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${_formatDate(dt)} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Plans & Credits',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          if (_paying)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCreditsSummary(),
                    const SizedBox(height: 28),
                    _sectionTitle('Student plans'),
                    const SizedBox(height: 12),
                    ..._studentPlans.map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PlanCard(
                          plan: plan,
                          isCurrentPlan: plan.id == _currentPlanId,
                          onUpgrade: () =>
                              _initiatePaymentGatewayCheckout(plan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle('Teacher plan'),
                    const SizedBox(height: 4),
                    Text(
                      'For teachers who share lectures with Groups',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                          ),
                    ),
                    const SizedBox(height: 12),
                    PlanCard(
                      plan: _teacherPlan,
                      isCurrentPlan: _teacherPlan.id == _currentPlanId,
                      onUpgrade: () =>
                          _initiatePaymentGatewayCheckout(_teacherPlan),
                      upgradeLabel: 'Get Teacher plan',
                    ),
                    const SizedBox(height: 28),
                    _sectionTitle('Buy Extra Credits'),
                    const SizedBox(height: 4),
                    Text(
                      'One-time packs — no plan change',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildInrPackGrid(),
                    const SizedBox(height: 28),
                    _sectionTitle('Credit history'),
                    const SizedBox(height: 12),
                    _buildCreditHistory(),
                    const SizedBox(height: 28),
                    _sectionTitle('Credit costs'),
                    const SizedBox(height: 12),
                    _buildCostReference(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildCreditsSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.getAccentTint(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentPlanName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                _periodLabel == 'Free plan' || _periodLabel == '—'
                    ? _periodLabel
                    : 'Until $_periodLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_remainingCredits',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor,
                    ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'credits left',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CreditUsageDisplay.primaryBalanceLine(_remainingCredits),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statChip(
                  label: 'Plan allotment',
                  value: '$_planMonthlyCredits',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statChip(
                  label: 'Used (est.)',
                  value: '$_usedCredits',
                ),
              ),
            ],
          ),
          if (_balanceIncludesTopUps) ...[
            const SizedBox(height: 10),
            Text(
              'Balance is higher than this month’s plan allotment (includes top-ups).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progressValue,
              minHeight: 6,
              backgroundColor: AppTheme.getCardBorder(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInrPackGrid() {
    final packs = SubscriptionPlans.creditPacks;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: packs.length,
      itemBuilder: (context, index) {
        final pack = packs[index];
        return InkWell(
          onTap: _paying ? null : () => _confirmPackPurchase(pack),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.getCardBorder(context)),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              color: AppTheme.getCardBackground(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pack.credits}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'credits',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.getAccentTint(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '₹${pack.priceInr}',
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

  Widget _buildCreditHistory() {
    if (_transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No credit activity yet. Ask AI, recording, and purchases will show in history.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/credits/history'),
              child: const Text('Open Credits History'),
            ),
          ],
        ),
      );
    }

    final shown = _transactions.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppTheme.getCardBorder(context)),
            _historyRow(shown[i]),
          ],
          Divider(height: 1, color: AppTheme.getCardBorder(context)),
          ListTile(
            dense: true,
            title: Text(
              'View full history',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentColor,
                  ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: AppTheme.accentColor,
            ),
            onTap: () => Navigator.pushNamed(context, '/credits/history'),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> row) {
    final amount = row['amount'] as int? ?? 0;
    final isCredit = amount > 0;
    final description = (row['description'] as String?)?.trim().isNotEmpty == true
        ? row['description'] as String
        : (row['action'] as String?) ?? 'Credit change';
    final raw = row['created_at'] as String?;
    final dt = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
    final when = dt != null ? _formatDateTime(dt) : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: isCredit ? Colors.green.shade700 : AppTheme.accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}$amount',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green.shade700 : AppTheme.accentColor,
                ),
          ),
        ],
      ),
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
            'Feature credit costs',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          _buildCostRow(
            'Recording / Audio (per minute)',
            CreditCosts.recordCreditsPerMinute,
          ),
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

  void _confirmPackPurchase(CreditPackDef pack) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Text('Purchase Credits'),
        content: Text(
          'Buy ${pack.credits} credits for ₹${pack.priceInr}?\n\n'
          'If payment is not configured yet, you will see a clear message — nothing is faked as paid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _initiateCreditPackCheckout(pack);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateCreditPackCheckout(CreditPackDef pack) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to buy credits')),
      );
      return;
    }
    if (_paying) return;
    setState(() => _paying = true);
    final result = await PaymentService.instance.purchaseCreditPack(
      userId: userId,
      pack: pack,
    );
    if (!mounted) return;
    setState(() => _paying = false);

    if (result.status == PaymentResultStatus.verified) {
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Credits added: ${result.creditsAllocated ?? pack.credits}',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _initiatePaymentGatewayCheckout(SubscriptionPlan plan) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to upgrade')),
      );
      return;
    }

    if (plan.id == 'free') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Free plan — no payment needed')),
      );
      return;
    }

    final planDef = SubscriptionPlans.byId(plan.id);
    if (planDef == null) return;

    if (_paying) return;
    setState(() => _paying = true);

    final result = await PaymentService.instance.purchasePlan(
      userId: userId,
      plan: planDef,
    );

    if (!mounted) return;
    setState(() => _paying = false);

    if (result.status == PaymentResultStatus.verified) {
      await _refreshAll();
      if (!mounted) return;
      _showPaymentSuccessSheet(plan);
      return;
    }

    if (result.status == PaymentResultStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment cancelled')),
      );
      return;
    }

    // Includes notConfigured — never fake success
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
              '${plan.name} is now active',
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
                  Navigator.pop(context);
                  _refreshAll();
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
  final String upgradeLabel;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrentPlan,
    required this.onUpgrade,
    this.upgradeLabel = 'Upgrade',
  });

  @override
  Widget build(BuildContext context) {
    final isFree = plan.price == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: isCurrentPlan || plan.isPopular
              ? AppTheme.accentColor
              : AppTheme.getCardBorder(context),
          width: isCurrentPlan || plan.isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      isFree ? '₹0' : '₹${plan.price}/month',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          Text(
            'What you get',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
          const SizedBox(height: 10),
          ...plan.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isCurrentPlan
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.getSecondaryText(context),
                      side: BorderSide(color: AppTheme.getCardBorder(context)),
                    ),
                    child: const Text('Current Plan'),
                  )
                : isFree
                    ? OutlinedButton(
                        onPressed: null,
                        child: const Text('Included on signup'),
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
                        child: Text(upgradeLabel),
                      ),
          ),
        ],
      ),
    );
  }
}

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
