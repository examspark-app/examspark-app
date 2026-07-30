import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/recording/recording_setup_screen.dart';
import 'package:examspark_frontend/presentation/screens/recording/processing_screen.dart';
import 'package:examspark_frontend/presentation/screens/recording/notes_result_screen.dart';
import 'package:examspark_frontend/presentation/screens/subscription/subscription_screen.dart';

void main() {
  runApp(const ExamSparkApp());
}

class ExamSparkApp extends StatelessWidget {
  const ExamSparkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamSpark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const RecordingSetupScreen(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/processing':
        final args = settings.arguments as Map<String, dynamic>?;
        final lectureId = args?['lectureId'] as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => ProcessingScreen(lectureId: lectureId),
          settings: settings,
        );
      case '/notes_result':
      case '/results':
        final args = settings.arguments as Map<String, dynamic>?;
        final lectureId = args?['lectureId'] as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => NotesResultScreen(lectureId: lectureId),
          settings: settings,
        );
      case '/subscription':
        return MaterialPageRoute(
          builder: (_) => const SubscriptionScreen(),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
