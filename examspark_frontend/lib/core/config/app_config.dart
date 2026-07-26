import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase and app configuration.
/// Copy `.env.example` to `.env` or pass --dart-define values at build time.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const String apiBaseUrl = String.fromEnvironment(
    'FASTAPI_BASE_URL',
    defaultValue: '',
  );

  /// Legacy alias — prefer FASTAPI_BASE_URL (see API_SETUP.md).
  static const String _legacyApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Checks the runtime `.env` file first (via `flutter_dotenv`, loaded in
  /// `main.dart`), then falls back to the compile-time --dart-define value —
  /// same bridge pattern `main.dart` uses for SUPABASE_URL/ANON_KEY, so
  /// `.env`'s `FASTAPI_BASE_URL` actually takes effect without needing
  /// --dart-define at every `flutter run`.
  static String get resolvedApiBaseUrl {
    final fromDotenv = dotenv.maybeGet('FASTAPI_BASE_URL') ?? dotenv.maybeGet('API_BASE_URL');
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    return apiBaseUrl.isNotEmpty ? apiBaseUrl : _legacyApiBaseUrl;
  }

  static bool get isApiConfigured => resolvedApiBaseUrl.isNotEmpty;

  /// Dev-only mock purchases (must match backend `IS_TESTING=true`).
  /// Never ship production builds with this enabled.
  static bool get isTesting {
    final fromDefine = const String.fromEnvironment('IS_TESTING', defaultValue: '');
    final raw = (dotenv.maybeGet('IS_TESTING') ?? fromDefine).trim().toLowerCase();
    return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
  }
}
