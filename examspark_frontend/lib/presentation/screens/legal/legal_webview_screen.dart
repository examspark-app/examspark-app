import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// ============================================================
/// TASK 4 — Legal Document Viewer
/// ============================================================
/// Opens a legal document in the device/browser's own browser.
/// Works identically and safely on Android, iOS, and Web (Chrome) —
/// no native WebView plugin required, so there is nothing platform
/// specific that can break compilation.
class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

enum _LoadState { loading, opened, error }

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  _LoadState _state = _LoadState.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() => _state = _LoadState.loading);
    final uri = Uri.parse(widget.url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _state = opened ? _LoadState.opened : _LoadState.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_state == _LoadState.loading)
                  const CircularProgressIndicator()
                else
                  Icon(
                    _state == _LoadState.error
                        ? Icons.error_outline_rounded
                        : Icons.open_in_new_rounded,
                    size: 56,
                    color: AppTheme.getSecondaryText(context),
                  ),
                const SizedBox(height: 16),
                Text(
                  _state == _LoadState.error
                      ? "Couldn't open this page"
                      : _state == _LoadState.opened
                          ? 'Opened in your browser'
                          : 'Opening...',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _state == _LoadState.error
                      ? 'Please check your internet connection and try again.'
                      : 'If nothing happened, tap the button below.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open page'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}