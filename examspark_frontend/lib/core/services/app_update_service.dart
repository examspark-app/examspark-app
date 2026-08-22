import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.sonialabs.sonaxia';

  bool _isNewer(String remote, String local) {
    List<int> parts(String value) => value
        .trim()
        .replaceFirst('+', '.')
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    final r = parts(remote);
    final l = parts(local);
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  Future<Map<String, String>?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (kIsWeb) {
        final versionUri = Uri.base.resolve(
          'version.json?check=${DateTime.now().millisecondsSinceEpoch}',
        );
        final webResponse = await http.get(
          versionUri,
          headers: const {'Cache-Control': 'no-cache'},
        );
        if (webResponse.statusCode == 200) {
          final webData = jsonDecode(webResponse.body);
          final latestWeb = webData is Map<String, dynamic>
              ? webData['version']?.toString().trim()
              : null;
          if (latestWeb != null && _isNewer(latestWeb, currentVersion)) {
            return {
              'latestVersion': latestWeb,
              'updateMessage':
                  'A new version of Sonaxia is available. Tap refresh to update.',
            };
          }
        }
      }

      final row = await SupabaseClient.instance.client
          .from('app_version_config')
          .select('latest_version, update_message')
          .eq('id', 1)
          .maybeSingle();

      if (row == null) return null;
      final latest = (row['latest_version'] as String?)?.trim();
      if (latest == null || latest.isEmpty) return null;

      if (!_isNewer(latest, currentVersion)) return null;

      return {
        'latestVersion': latest,
        'updateMessage': (row['update_message'] as String?)?.trim() ??
            'A new version of Sonaxia is available.',
      };
    } catch (_) {
      return null;
    }
  }
}