import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// "Paste a YouTube link" — the Flutter side of the planned YouTube Link →
/// Notes feature (founder-locked Jul 12, 2026): no video download, just
/// the transcript (captions) piped into the same Notes/Summary/Flashcards/
/// Quiz pipeline as a recorded lecture. Public videos only, up to 1 hour.
/// [onSubmit] receives the pasted URL once it passes basic format
/// validation — the caller decides what happens next (real backend once
/// Phase 5 is wired; a "coming soon" message for now).
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
              'Paste a public YouTube video link (up to 1 hour) — we\'ll turn it into '
              'Notes, Summary, Flashcards & Quiz. No download needed.',
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
              'Cost: 35–100 credits depending on video length. Public videos only — '
              'private, unlisted, age-restricted or region-locked videos aren\'t supported.',
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
