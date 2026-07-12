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

  static String get resolvedApiBaseUrl =>
      apiBaseUrl.isNotEmpty ? apiBaseUrl : _legacyApiBaseUrl;

  static bool get isApiConfigured => resolvedApiBaseUrl.isNotEmpty;
}
