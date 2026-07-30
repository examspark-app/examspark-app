import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/group_channel_row.dart';

/// One card in the group channel feed — lecture, notes, quiz, announcement.
/// Premium ExamSpark card style: dark card, gradient icon badge, soft
/// elevation, pinned/newest items get a blue accent highlight.
class PinnedContentTile extends StatelessWidget {
  final GroupSharedItem item;
  final VoidCallback? onTap;
  /// Teacher-only: pin / unpin (sticky top). Null for students.
  final VoidCallback? onTogglePin;
  /// True for the most recent post in the feed — gets a bold accent title
  /// + "NEW" badge so it stands out as the newest content.
  final bool isNewest;

  const PinnedContentTile({
    super.key,
    required this.item,
    this.onTap,
    this.onTogglePin,
    this.isNewest = false,
  });

  // Consistent accent blue — matches the verified badge elsewhere in the
  // app, so the whole Group Info screen reads as one cohesive "modern
  // dark + blue" premium palette instead of mixing in the green brand
  // accent on this one card.
  static const Color _accent = Color(0xFF1D9BF0);
  static const Color _accentSoft = Color(0xFF34C7FF);
  static const _card = Color(0xFF121212);
  static const _borderSubtle = Color(0x1FFFFFFF);
  static const _textSecondary = Color(0xFFA8A8A8);

  IconData get _icon {
    switch (item.type) {
      case GroupSharedItemType.lecture:
        return Icons.play_circle_outline;
      case GroupSharedItemType.homework:
        return Icons.assignment_outlined;
      case GroupSharedItemType.notes:
        return Icons.description_outlined;
      case GroupSharedItemType.quiz:
        return Icons.quiz_outlined;
      case GroupSharedItemType.announcement:
        return Icons.campaign_outlined;
    }
  }

  String get _typeLabel {
    switch (item.type) {
      case GroupSharedItemType.lecture:
        return 'Lecture';
      case GroupSharedItemType.homework:
        return 'Homework';
      case GroupSharedItemType.notes:
        return 'Notes';
      case GroupSharedItemType.quiz:
        return 'Quiz';
      case GroupSharedItemType.announcement:
        return 'Announcement';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = GroupChannelRow.formatActivityDate(item.sharedAt);
    final highlight = isNewest || item.isPinned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: highlight ? _accent.withValues(alpha: 0.5) : _borderSubtle,
                width: highlight ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: highlight
                      ? _accent.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.25),
                  blurRadius: highlight ? 18 : 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: item.isPinned
                          ? [_accent, _accentSoft]
                          : [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                    ),
                    border: Border.all(
                      color: item.isPinned
                          ? Colors.transparent
                          : _borderSubtle,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _icon,
                    size: 21,
                    color: item.isPinned ? Colors.white : _accentSoft,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: item.isPinned ? _accentSoft : _textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          if (item.isPinned) ...[
                            const _Chip(
                              icon: Icons.push_pin,
                              label: 'Pinned',
                              color: _accent,
                            ),
                            const SizedBox(width: 6),
                          ] else if (isNewest) ...[
                            const _Chip(
                              icon: Icons.fiber_new_rounded,
                              label: 'New',
                              color: _accent,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _typeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if ((item.body ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          item.body!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.42,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTogglePin != null)
                  IconButton(
                    tooltip: item.isPinned ? 'Unpin' : 'Pin to top',
                    onPressed: onTogglePin,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 20,
                      color: item.isPinned ? _accent : _textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}