import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/router/app_navigation.dart';
import 'package:examspark_frontend/core/router/app_router.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
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

  runApp(const ExamSparkApp());
}

class ExamSparkApp extends StatelessWidget {
  const ExamSparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamSpark',
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
