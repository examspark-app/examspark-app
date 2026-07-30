import 'package:flutter/material.dart';

/// Admin hub — payment management pages (all pending).
class AdminPaymentHubScreen extends StatelessWidget {
  const AdminPaymentHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminItem('Payments', Icons.payments_outlined, '/admin/payments/list'),
      _AdminItem('Subscriptions', Icons.card_membership_outlined, '/admin/subscriptions'),
      _AdminItem('Failed Payments', Icons.error_outline, '/admin/payments/failed'),
      _AdminItem('Refund Status', Icons.undo_outlined, '/admin/refunds'),
      _AdminItem('Manual Credit Adjustment', Icons.tune, '/admin/credits/manual'),
      _AdminItem('Transaction History', Icons.history, '/admin/transactions'),
      _AdminItem('Revenue Dashboard', Icons.bar_chart, '/admin/revenue'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Payments')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, i) {
          final item = items[i];
          return ListTile(
            leading: Icon(item.icon),
            title: Text(item.title),
            subtitle: const Text('TODO: Connect FastAPI /api/v1/admin/*'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, item.route),
          );
        },
      ),
    );
  }
}

class _AdminItem {
  final String title;
  final IconData icon;
  final String route;
  _AdminItem(this.title, this.icon, this.route);
}
