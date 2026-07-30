import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/suggested_teacher_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/verified_badge.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Compact horizontal-scroll card used in the "Suggested Teachers" row
/// below the Group Info screen.
class SuggestedTeacherCard extends StatelessWidget {
  final SuggestedTeacherModel teacher;
  final VoidCallback onJoinToggle;
  final bool isUpdating;
  /// Tapping anywhere on the card except the Join button — opens that
  /// teacher's group/profile. Null hides the tap affordance (card is
  /// then only interactive via the Join button).
  final VoidCallback? onOpen;

  const SuggestedTeacherCard({
    super.key,
    required this.teacher,
    required this.onJoinToggle,
    this.isUpdating = false,
    this.onOpen,
  });

  // Consistent accent blue — matches the verified badge and channel feed
  // elsewhere on Group Info, so this card doesn't stand out with the old
  // green brand accent.
  static const Color _accent = Color(0xFF1D9BF0);

  String get _locationLabel {
    final c = teacher.city?.trim() ?? '';
    final s = teacher.state?.trim() ?? '';
    if (c.isNotEmpty && s.isNotEmpty) return '$c, $s';
    if (c.isNotEmpty) return c;
    if (s.isNotEmpty) return s;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = teacher.name.trim().isEmpty ? 'Teacher' : teacher.name;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 156,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.getCardBackground(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.getCardBorder(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.4)],
                      ),
                    ),
                    child: InitialsAvatar(
                      name: displayName,
                      photoUrl: teacher.photoUrl,
                      size: 54,
                    ),
                  ),
                  if (teacher.isVerified)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.getCardBackground(context),
                          shape: BoxShape.circle,
                        ),
                        child: const VerifiedBadge(size: 15),
                      ),
                    ),
                  // Match Score Badge on top-left if available
                  if (teacher.matchScore != null)
                    Positioned(
                      left: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${teacher.matchScore}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                teacher.subject,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                      fontSize: 11,
                    ),
              ),
              if (_locationLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: AppTheme.getSecondaryText(context),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        _locationLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                              fontSize: 10.5,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              if (teacher.matchesLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  teacher.matchesLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: teacher.isJoined
                    ? OutlinedButton(
                        onPressed: isUpdating ? null : onJoinToggle,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(32),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        child: isUpdating
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Joined'),
                      )
                    : ElevatedButton(
                        onPressed: isUpdating ? null : onJoinToggle,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(32),
                          padding: EdgeInsets.zero,
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        child: isUpdating
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Join'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}