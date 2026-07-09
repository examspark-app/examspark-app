import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';

/// Displays tiered plans array with credit top-up purchase options
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _creditsBalance = 0;
  String _selectedPlan = 'Basic';

  @override
  void initState() {
    super.initState();
    _loadUserCredits();
  }

  Future<void> _loadUserCredits() async {
    // Load user's current credit balance
    // This would typically come from Supabase
    setState(() => _creditsBalance = 50); // Mock value
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription & Credits'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Card
            _buildBalanceCard(),
            const SizedBox(height: 24),
            // Tiered Plans
            _buildSectionTitle('Subscription Plans'),
            const SizedBox(height: 12),
            _buildPlans(),
            const SizedBox(height: 24),
            // Credit Top-ups
            _buildSectionTitle('Credit Top-ups'),
            const SizedBox(height: 12),
            _buildTopUpOptions(),
            const SizedBox(height: 24),
            // Credit Cost Reference
            _buildSectionTitle('Credit Costs'),
            const SizedBox(height: 12),
            _buildCostReference(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_creditsBalance Credits',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlans() {
    final plans = [
      _PlanData('Starter', 0, 'Basic features', Colors.grey),
      _PlanData('Basic', 9.99, '100 credits/month', Colors.blue),
      _PlanData('Standard', 19.99, '500 credits/month', Colors.purple),
      _PlanData('Pro', 49.99, 'Unlimited credits', Colors.orange),
    ];

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: plans.length,
        itemBuilder: (context, index) {
          final plan = plans[index];
          final isSelected = _selectedPlan == plan.name;
          
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? plan.color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? plan.color.withOpacity(0.1) : Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: plan.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${plan.price}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.features,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: plan.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Current Plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopUpOptions() {
    final topUps = [
      _TopUpData(50, 4.99),
      _TopUpData(100, 8.99),
      _TopUpData(250, 19.99),
      _TopUpData(500, 34.99),
      _TopUpData(1000, 59.99),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
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
          final topUp = topUps[index];
          return InkWell(
            onTap: () => _handleTopUp(topUp.credits, topUp.price),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${topUp.credits}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('credits'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\$${topUp.price}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCostReference() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Feature Credit Costs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildCostRow('Whisper Turbo (1 hour)', CreditCosts.whisperTurboHour),
          _buildCostRow('Whisper Standard (1 hour)', CreditCosts.whisperStandardHour),
          _buildCostRow('Qwen3 Text Processing', CreditCosts.qwen3Text),
          _buildCostRow('Qwen3-VL Image Processing', CreditCosts.qwen3VL),
          _buildCostRow('MCQ Generation', CreditCosts.mcqGeneration),
          _buildCostRow('Flashcard Generation', CreditCosts.flashcardGeneration),
          _buildCostRow('Mind Map Generation', CreditCosts.mindMapGeneration),
          _buildCostRow('RAG Query', CreditCosts.ragQuery),
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
          Text(
            feature,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            '$cost credits',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
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
        title: const Text('Purchase Credits'),
        content: Text('Purchase $credits credits for \$$price?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _creditsBalance += credits);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully purchased $credits credits!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }
}

class _PlanData {
  final String name;
  final double price;
  final String features;
  final Color color;

  _PlanData(this.name, this.price, this.features, this.color);
}

class _TopUpData {
  final int credits;
  final double price;

  _TopUpData(this.credits, this.price);
}
