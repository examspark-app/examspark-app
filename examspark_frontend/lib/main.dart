import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/router/app_navigation.dart';
import 'package:examspark_frontend/core/router/app_router.dart';
import 'package:examspark_frontend/core/router/invite_deep_link.dart';
import 'package:examspark_frontend/core/services/pending_invite_store.dart';
import 'package:examspark_frontend/core/services/pending_referral_store.dart';
import 'package:examspark_frontend/core/services/share_receiver_service.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/services/fcm_push_service.dart';
import 'package:examspark_frontend/core/services/crashlytics_service.dart';
import 'package:examspark_frontend/presentation/widgets/auth_gate.dart';
import 'package:app_links/app_links.dart';
import 'package:examspark_frontend/core/payments/payment_service.dart';

// NEW:
import 'dart:js_interop';

@JS('forceReloadExamSparkApp')
external void _forceReloadExamSparkAppJS();

void _webForceReload() {
  if (!kIsWeb) return;
  try {
    _forceReloadExamSparkAppJS();
  } catch (_) {}
}

Future<void> _checkWebVersionBumpAndReload() async {
  if (!kIsWeb) return;
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final current = '${packageInfo.version}+${packageInfo.buildNumber}';
    final prefs = await SharedPreferences.getInstance();
    const key = 'examspark_known_app_version';
    final stored = prefs.getString(key);
    if (stored == null) {
      await prefs.setString(key, current);
      return;
    }
    if (stored != current) {
      await prefs.setString(key, current);
      _webForceReload();
    }
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web-only: let Flutter render its own text-selection context menu
  // (e.g. our "Reply" button) instead of the browser's native right-click
  // menu, which otherwise blocks custom menus from ever showing.
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }

  // Background payment listener
  PaymentService.instance.initialize();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env optional when using --dart-define
  }

  final url = dotenv.maybeGet('SUPABASE_URL') ?? AppConfig.supabaseUrl;

  final key = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? AppConfig.supabaseAnonKey;

  if (url.isNotEmpty && key.isNotEmpty) {
    await SupabaseClient.instance.initialize(url: url, anonKey: key);
  }

  runApp(const ExamSparkApp());
}

class ExamSparkApp extends StatefulWidget {
  const ExamSparkApp({super.key});

  @override
  State<ExamSparkApp> createState() => _ExamSparkAppState();
}

class _ExamSparkAppState extends State<ExamSparkApp> {
  bool _inviteDeepLinkHandled = false;

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _nativeLinkSub;

  @override
  void initState() {
    super.initState();

    // First frame ke baad non-critical services start karo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBackgroundServices();
      _openInviteDeepLink();
      if (kIsWeb) {
        Future<void>.delayed(
          const Duration(seconds: 3),
          _checkWebVersionBumpAndReload,
        );
      }
    });

    if (!kIsWeb) {
      _listenNativeDeepLinks();
      _listenSharedFiles();
    }
  }

  Future<void> _initializeBackgroundServices() async {
    await CrashlyticsService.instance.initialize();
    final posthogApiKey = dotenv.maybeGet('POSTHOG_API_KEY') ?? '';

    final posthogHost =
        dotenv.maybeGet('POSTHOG_HOST') ?? 'https://us.i.posthog.com';

    if (posthogApiKey.isNotEmpty) {
      try {
        final posthogConfig = PostHogConfig(posthogApiKey);

        posthogConfig.host = posthogHost;
        posthogConfig.sessionReplay = false;

        await Posthog().setup(posthogConfig);

        final currentUser = SupabaseClient.instance.currentUser;

        if (currentUser != null) {
          await Posthog().identify(userId: currentUser.id);
        }
      } catch (_) {
        // Analytics failure must never affect app startup.
      }
    }

    try {
      await FcmPushService.instance.start();
    } catch (_) {}
  }

  /// Android/iOS App Links.
  ///
  /// Uri.base only works on Flutter Web, so native platforms
  /// need this separate listener.
  void _listenNativeDeepLinks() {
    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) {
            _handleNativeUri(uri);
          }
        })
        .catchError((_) {});

    _nativeLinkSub = _appLinks.uriLinkStream.listen(
      _handleNativeUri,
      onError: (_) {},
    );
  }

  Future<void> _handleNativeUri(Uri uri) async {
    final code = InviteDeepLink.joinCodeFromUri(uri);

    if (code == null) return;

    await PendingInviteStore.save(code);

    for (var i = 0; i < 20; i++) {
      final nav = AppNavigation.key.currentState;

      if (nav != null) {
        nav.pushNamed('/join/$code');
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Photo / PDF / audio shared into the app from:
  /// Gallery, WhatsApp, Gmail, Files app, etc.
  ///
  /// Video is rejected inside ShareReceiverService.
  ///
  /// Files land on RecorderScreen.
  /// Existing subscription/credit checks continue to apply there.
  void _listenSharedFiles() {
    ShareReceiverService.instance.onFilesReceived = _handleSharedFiles;

    ShareReceiverService.instance.start();
  }

  Future<void> _handleSharedFiles(List files) async {
    for (var i = 0; i < 20; i++) {
      final nav = AppNavigation.key.currentState;

      if (nav != null) {
        nav.pushNamed('/recorder', arguments: {'initialInputMethod': 'shared'});
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _openInviteDeepLink() async {
    if (_inviteDeepLinkHandled) return;

    final code = InviteDeepLink.joinCodeFromUri(Uri.base);

    final referralCode = InviteDeepLink.referralCodeFromUri(Uri.base);
    if (referralCode != null) {
      await PendingReferralStore.save(referralCode);
      final nav = AppNavigation.key.currentState;
      if (nav != null && SupabaseClient.instance.currentUser == null) {
        nav.pushNamed('/login', arguments: {'startInSignUp': true});
      }
    }

    if (code == null) return;

    _inviteDeepLinkHandled = true;

    await PendingInviteStore.save(code);

    // Navigator key may not be ready on the very first frame.
    for (var i = 0; i < 20; i++) {
      final nav = AppNavigation.key.currentState;

      if (nav != null) {
        nav.pushNamed('/join/$code');
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void dispose() {
    _nativeLinkSub?.cancel();

    ShareReceiverService.instance.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.materialTitle,
      debugShowCheckedModeBanner: false,

      navigatorKey: AppNavigation.key,

      // PostHog automatically tracks screen/page navigation.
      navigatorObservers: [PosthogObserver()],

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      home: const AuthGate(),

      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
