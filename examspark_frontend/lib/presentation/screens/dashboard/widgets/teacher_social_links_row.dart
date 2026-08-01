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

  /// Brand-recognizable color per platform — helps students spot the
  /// right icon at a glance instead of every link looking identical.
  Color _brandColor(BuildContext context, TeacherSocialKind kind) {
    switch (kind) {
      case TeacherSocialKind.youtube:
        return const Color(0xFFFF0000);
      case TeacherSocialKind.instagram:
        return const Color(0xFFE1306C);
      case TeacherSocialKind.facebook:
        return const Color(0xFF1877F2);
      case TeacherSocialKind.linkedin:
        return const Color(0xFF0A66C2);
      case TeacherSocialKind.whatsapp:
        return const Color(0xFF25D366);
      case TeacherSocialKind.telegram:
        return const Color(0xFF229ED9);
      case TeacherSocialKind.x:
        // X's brand color is black/white — flip for dark mode so it stays visible.
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black;
      case TeacherSocialKind.website:
        return AppTheme.accentColor;
    }
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
              Builder(
                builder: (context) {
                  final color = _brandColor(context, entry.$1);
                  return Tooltip(
                    message: entry.$1.label,
                    child: InkWell(
                      onTap: () => _open(context, entry.$1, entry.$2),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: compact ? 36 : 40,
                        height: compact ? 36 : 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.getCardBorder(context)),
                        ),
                        child: Icon(
                          _icon(entry.$1),
                          size: compact ? 18 : 20,
                          color: color,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}