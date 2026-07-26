/// Parse invite join code from web hash / path.
///
/// Examples:
/// - `http://localhost:8080/#/join/485022` → fragment `/join/485022`
/// - `https://sonaxia.com/#/join/485022`
class InviteDeepLink {
  InviteDeepLink._();

  static String? joinCodeFromUri(Uri uri) {
    final fromFragment = _codeFromPath(uri.fragment);
    if (fromFragment != null) return fromFragment;
    return _codeFromPath(uri.path);
  }

  static String? _codeFromPath(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return null;
    if (!path.startsWith('/')) path = '/$path';
    // Strip query if present in fragment.
    path = path.split('?').first;
    const prefix = '/join/';
    if (!path.startsWith(prefix)) return null;
    final code = path.substring(prefix.length).split('/').first.trim();
    if (code.length < 4) return null;
    return code.toUpperCase();
  }
}
