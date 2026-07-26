import 'dart:async';

import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/router/app_navigation.dart';

/// Global toast that always sits above bottom sheets, dialogs, and routes.
/// Use this instead of [ScaffoldMessenger] so messages are never hidden.
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    String message, {
    bool isError = true,
    BuildContext? context,
    Duration? duration,
  }) {
    final text = message.trim();
    if (text.isEmpty) return;

    final overlay = _overlay(context);
    if (overlay == null) return;

    hide();

    final entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.paddingOf(ctx).top + 10;
        return Positioned(
          top: top,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isError
                          ? const Color(0xFFB71C1C)
                          : const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: hide,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    _entry = entry;
    _timer = Timer(duration ?? Duration(seconds: isError ? 6 : 4), hide);
  }

  /// Drop-in for [ScaffoldMessenger.showSnackBar] — keeps content text on top.
  static void showSnackBar(BuildContext context, SnackBar snackBar) {
    final text = _textFromContent(snackBar.content);
    final bg = snackBar.backgroundColor;
    final isError = _looksError(text, bg);
    show(
      text.isEmpty ? 'Done' : text,
      isError: isError,
      context: context,
      duration: snackBar.duration,
    );
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static OverlayState? _overlay(BuildContext? context) {
    final ctx =
        context ?? AppNavigation.key.currentContext;
    if (ctx == null) return null;
    try {
      return Overlay.of(ctx, rootOverlay: true);
    } catch (_) {
      return null;
    }
  }

  static String _textFromContent(Widget content) {
    if (content is Text) return content.data ?? '';
    if (content is RichText) return content.text.toPlainText();
    if (content is Expanded) return _textFromContent(content.child);
    if (content is Flexible) return _textFromContent(content.child);
    if (content is Padding) {
      final child = content.child;
      return child == null ? '' : _textFromContent(child);
    }
    if (content is SizedBox) {
      final child = content.child;
      return child == null ? '' : _textFromContent(child);
    }
    if (content is Icon) return '';
    if (content is Row) {
      return content.children
          .map(_textFromContent)
          .where((s) => s.isNotEmpty)
          .join(' ');
    }
    if (content is Column) {
      return content.children
          .map(_textFromContent)
          .where((s) => s.isNotEmpty)
          .join(' ');
    }
    // Never show Widget.toString() (e.g. "Row(direction: ...)") to users.
    return '';
  }

  static bool _looksError(String text, Color? background) {
    final lower = text.toLowerCase();
    if (lower.contains('fail') ||
        lower.contains('error') ||
        lower.contains('could not') ||
        lower.contains('invalid') ||
        lower.contains('required') ||
        lower.contains('denied') ||
        lower.contains('locked') ||
        lower.contains('try again') ||
        lower.contains('missing') ||
        lower.contains('not allowed') ||
        lower.contains('unable') ||
        lower.contains('timeout') ||
        lower.contains('forbidden') ||
        lower.contains('unauthorized')) {
      return true;
    }
    return false;
  }
}
