import 'package:flutter/material.dart';

/// TODO: GET /api/v1/admin/payments
class AdminPaymentsListScreen extends StatelessWidget {
  const AdminPaymentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _placeholderScaffold(context, 'Payments', 'List all payment records');
  }
}

class AdminSubscriptionsScreen extends StatelessWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _placeholderScaffold(context, 'Subscriptions', 'Active and pending subscriptions');
  }
}

class AdminFailedPaymentsScreen extends StatelessWidget {
  const AdminFailedPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _placeholderScaffold(context, 'Failed Payments', 'Failed and cancelled payments');
  }
}

class AdminRefundsScreen extends StatelessWidget {
  const AdminRefundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _placeholderScaffold(context, 'Refund Status', 'Refund requests and status');
  }
}

class AdminManualCreditsScreen extends StatelessWidget {
  const AdminManualCreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _placeholderScaffold(
      context,
      'Manual Credit Adjustment',
      'POST /api/v1/admin/credits/adjust — audit logged',
    );
  }
}

class AdminTransactionsScreen extends StatelessWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _placeholderScaffold(context, 'Transaction History', 'payment_transactions + credit_history');
  }
}

class AdminRevenueScreen extends StatelessWidget {
  const AdminRevenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _placeholderScaffold(context, 'Revenue Dashboard', 'GET /api/v1/admin/revenue');
  }
}

Widget _placeholderScaffold(BuildContext context, String title, String subtitle) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_outlined, size: 48),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text('TODO: Admin integration pending'),
          ],
        ),
      ),
    ),
  );
}
