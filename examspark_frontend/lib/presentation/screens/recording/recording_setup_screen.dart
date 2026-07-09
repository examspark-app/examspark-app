import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Screen 1: Recording Setup Screen
/// User chooses transcription quality before starting recording
class RecordingSetupScreen extends StatefulWidget {
  const RecordingSetupScreen({super.key});

  @override
  State<RecordingSetupScreen> createState() => _RecordingSetupScreenState();
}

class _RecordingSetupScreenState extends State<RecordingSetupScreen> {
  // Selected transcription quality (default: fast)
  TranscriptionQuality _selectedQuality = TranscriptionQuality.fast;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Lecture'),
      ),
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading Section
                  const Text(
                    'Choose transcription quality',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can change this anytime',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),

                  // Selectable Cards
                  SelectableOptionCard(
                    icon: Icons.bolt_outlined,
                    title: 'Fast (Recommended)',
                    subtitle: 'Best for clear classroom audio',
                    isSelected: _selectedQuality == TranscriptionQuality.fast,
                    onTap: () => setState(() => _selectedQuality = TranscriptionQuality.fast),
                  ),
                  const SizedBox(height: AppTheme.elementSpacing),
                  SelectableOptionCard(
                    icon: Icons.shield_outlined,
                    title: 'High Accuracy',
                    subtitle: 'Best for noisy rooms or unclear speech',
                    isSelected: _selectedQuality == TranscriptionQuality.highAccuracy,
                    onTap: () => setState(() => _selectedQuality = TranscriptionQuality.highAccuracy),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Fixed Button
          Container(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _handleContinue,
                child: const Text('Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue() {
    // Navigate to next screen (Recording/Upload screen)
    // Placeholder for now
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlaceholderScreen(
          title: 'Recording/Upload',
          message: 'This screen will be built next',
        ),
      ),
    );
  }
}

/// Reusable selectable option card widget
class SelectableOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectableOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.getAccentTint(context)
            : AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: isSelected ? AppTheme.accentColor : AppTheme.getCardBorder(context),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentColor.withOpacity(0.1)
                        : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? AppTheme.accentColor
                        : AppTheme.getPrimaryText(context),
                  ),
                ),
                const SizedBox(width: 16),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.accentColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Transcription quality options
enum TranscriptionQuality {
  fast,
  highAccuracy,
}

/// Placeholder screen for navigation
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: AppTheme.getSecondaryText(context),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
