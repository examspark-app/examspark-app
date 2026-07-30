import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_toast.dart';

/// Invite payload for Study Group QR (same link students use to join).
class GroupInviteQrData {
  final String groupName;
  final String joinCode;
  final String shareLink;

  const GroupInviteQrData({
    required this.groupName,
    required this.joinCode,
    required this.shareLink,
  });

  factory GroupInviteQrData.fromCode({
    required String groupName,
    required String joinCode,
  }) {
    final code = joinCode.trim().toUpperCase();
    return GroupInviteQrData(
      groupName: groupName,
      joinCode: code,
      shareLink: AppBrand.inviteJoinUrl(code),
    );
  }
}

/// Teacher-facing QR sheet — screenshot / show in class. No chat.
Future<void> showGroupInviteQrSheet(
  BuildContext context, {
  required GroupInviteQrData invite,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GroupInviteQrSheet(invite: invite),
  );
}

class _GroupInviteQrSheet extends StatelessWidget {
  final GroupInviteQrData invite;

  const _GroupInviteQrSheet({required this.invite});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.getCardBorder(context),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Invite QR',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              invite.groupName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Students scan this with any QR app, or type the code.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getCardBorder(context)),
              ),
              child: QrImageView(
                data: invite.shareLink,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0D0D0D),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0D0D0D),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              invite.joinCode,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontSize: 22,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              invite.shareLink,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: invite.joinCode));
                      AppToast.showSnackBar(context, 
                        const SnackBar(content: Text('Invite code copied')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: invite.shareLink));
                      AppToast.showSnackBar(context, 
                        const SnackBar(content: Text('Share link copied')),
                      );
                    },
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Copy link'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: screenshot this QR for WhatsApp / classroom board.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getSecondaryText(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
