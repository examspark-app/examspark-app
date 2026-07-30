import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// "Paste a YouTube link" — captions first, Whisper fallback → Notes + Summary.
/// Same Record credit bands. Public videos, ≤90 minutes.
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
              'Paste a public YouTube link (up to 90 minutes). We use captions when '
              'available; otherwise we temporarily download audio for Whisper '
              '(audio is deleted after). Notes + Summary like a lecture. '
              'Quiz and Flashcards cost extra credits later.',
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
                final lower = url.toLowerCase();
                final isYoutube = lower.contains('youtube.com/watch') ||
                    lower.contains('youtu.be/') ||
                    lower.contains('youtube.com/shorts/') ||
                    lower.contains('youtube.com/embed/') ||
                    lower.contains('youtube.com/live/') ||
                    lower.contains('m.youtube.com');
                if (!isYoutube) return 'That doesn\'t look like a YouTube link';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Cost: ${CreditCosts.youtubeUpTo30Min}/${CreditCosts.youtube30To60Min}/'
              '${CreditCosts.youtube60To90Min} credits by length '
              '(≤30 / 30–60 / 60–90 min). Public videos only.',
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
