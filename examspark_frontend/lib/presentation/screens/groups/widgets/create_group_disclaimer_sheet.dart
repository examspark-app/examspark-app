import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Soft one-time Create Group disclaimer (Notifications / product map A4).
/// Not legal KYC — reminder that Groups are broadcast, not chat.
Future<bool> showCreateGroupDisclaimerSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final secondary = AppTheme.getSecondaryText(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getCardBorder(ctx),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Before you Create Group',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Students see content you share. No chat. '
                'You are responsible for what you post.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: secondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Shown once — soft reminder only.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('I understand — Continue'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}
