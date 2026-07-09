import 'package:supabase_flutter/supabase_flutter.dart';

/// Standardized Supabase client for authentication and Edge Function integration
class SupabaseClient {
  SupabaseClient._();

  static final SupabaseClient instance = SupabaseClient._();

  late final Supabase _supabase;
  bool _isInitialized = false;

  /// Initialize Supabase with environment configuration
  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_isInitialized) return;

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    _supabase = Supabase.instance;
    _isInitialized = true;
  }

  /// Get the underlying Supabase client
  Supabase get client {
    if (!_isInitialized) {
      throw StateError('SupabaseClient not initialized. Call initialize() first.');
    }
    return _supabase;
  }

  /// Get current authenticated user
  User? get currentUser => client.auth.currentUser;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign out current user
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Invoke Edge Function with authentication
  Future<Map<String, dynamic>> invokeEdgeFunction({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    final response = await client.functions.invoke(
      functionName,
      body: body,
    );

    if (response.status != 200) {
      throw Exception('Edge Function error: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Get user profile from database
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return response;
  }

  /// Update user credits balance
  Future<void> updateCredits(String userId, int newBalance) async {
    await client
        .from('users')
        .update({'credits_balance': newBalance})
        .eq('id', userId);
  }

  /// Get user's credit transaction history
  Future<List<Map<String, dynamic>>> getCreditTransactions(String userId) async {
    final response = await client
        .from('credit_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response as List<Map<String, dynamic>>;
  }

  /// Stream real-time user profile updates
  Stream<Map<String, dynamic>> userProfileStream(String userId) {
    return client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((event) => event.first);
  }
}
