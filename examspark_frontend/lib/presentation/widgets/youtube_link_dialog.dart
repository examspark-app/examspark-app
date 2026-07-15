import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// "Paste a YouTube link" — captions → Notes + Summary (PDF-parity).
/// Quiz / Flashcards are separate credit actions later. Public videos only, ≤1 hour.
Future<void> showYoutubeLinkDialog(
  BuildContext context, {
  required ValueChanged<String> onSubmit,
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
      title: const Text('YouTube Link → Notes'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a public YouTube video link (up to 1 hour). We will turn captions into '
              'Notes and Summary — same as a PDF/lecture. Quiz and Flashcards cost extra credits later.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
              ),
              validator: (value) {
                final url = value?.trim() ?? '';
                if (url.isEmpty) return 'Please paste a YouTube link';
                final isYoutube = url.contains('youtube.com/watch') ||
                    url.contains('youtu.be/') ||
                    url.contains('youtube.com/shorts/');
                if (!isYoutube) return 'That doesn\'t look like a YouTube link';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Cost: ${CreditCosts.youtubeUpTo20Min}–${CreditCosts.youtube40To60Min} credits '
              'by length (≤20 / 20–40 / 40–60 min). Public videos with captions only — '
              'private, unlisted, age-restricted or region-locked are not supported.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final url = controller.text.trim();
            Navigator.of(context).pop();
            onSubmit(url);
          },
          child: const Text('Generate Notes'),
        ),
      ],
    ),
  );
}
