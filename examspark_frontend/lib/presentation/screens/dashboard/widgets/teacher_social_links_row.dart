import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Student-facing (and teacher preview) trust link icons — only filled links.
class TeacherSocialLinksRow extends StatelessWidget {
  final TeacherProfileModel profile;
  final bool compact;

  const TeacherSocialLinksRow({
    super.key,
    required this.profile,
    this.compact = false,
  });

  Future<void> _open(
    BuildContext context,
    TeacherSocialKind kind,
    String raw,
  ) async {
    final normalized =
        TeacherProfileModel.normalizeSocialInput(kind, raw) ?? raw.trim();
    var uri = Uri.tryParse(normalized);
    if (uri == null || !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      final withHttps = normalized.contains('://') ? normalized : 'https://$normalized';
      uri = Uri.tryParse(withHttps);
    }
    if (uri == null || !uri.hasScheme) {
      if (context.mounted) {
        AppToast.showSnackBar(context, 
          const SnackBar(content: Text('Invalid link — use full URL like https://…')),
        );
      }
      return;
    }
    try {
      final ok = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
      if (!ok && context.mounted) {
        AppToast.showSnackBar(context, 
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showSnackBar(context, 
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  IconData _icon(TeacherSocialKind kind) {
    return switch (kind) {
      TeacherSocialKind.website => Icons.language,
      TeacherSocialKind.youtube => Icons.play_circle_outline,
      TeacherSocialKind.instagram => Icons.camera_alt_outlined,
      TeacherSocialKind.facebook => Icons.public,
      TeacherSocialKind.linkedin => Icons.work_outline,
      TeacherSocialKind.whatsapp => Icons.chat_outlined,
      TeacherSocialKind.telegram => Icons.send_outlined,
      TeacherSocialKind.x => Icons.alternate_email,
    };
  }

  @override
  Widget build(BuildContext context) {
    final links = profile.filledSocialLinks;
    if (links.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!compact) ...[
          Text(
            'Find me online',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in links)
              Tooltip(
                message: entry.$1.label,
                child: InkWell(
                  onTap: () => _open(context, entry.$1, entry.$2),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: compact ? 36 : 40,
                    height: compact ? 36 : 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getAccentTint(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.getCardBorder(context)),
                    ),
                    child: Icon(
                      _icon(entry.$1),
                      size: compact ? 18 : 20,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
