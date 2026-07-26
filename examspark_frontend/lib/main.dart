import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/router/app_navigation.dart';
import 'package:examspark_frontend/core/router/app_router.dart';
import 'package:examspark_frontend/core/router/invite_deep_link.dart';
import 'package:examspark_frontend/core/services/pending_invite_store.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/services/fcm_push_service.dart';
import 'package:examspark_frontend/presentation/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // FCM: soft-fails until founder adds google-services.json (FOUNDER_FCM_SETUP.md).
  try {
    await FcmPushService.instance.start();
  } catch (_) {}

  runApp(const ExamSparkApp());
}

class ExamSparkApp extends StatefulWidget {
  const ExamSparkApp({super.key});

  @override
  State<ExamSparkApp> createState() => _ExamSparkAppState();
}

class _ExamSparkAppState extends State<ExamSparkApp> {
  bool _inviteDeepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    // `home: AuthGate` ignores URL hash — open /join/CODE after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInviteDeepLink());
  }

  Future<void> _openInviteDeepLink() async {
    if (_inviteDeepLinkHandled) return;
    final code = InviteDeepLink.joinCodeFromUri(Uri.base);
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.materialTitle,
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigation.key,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
