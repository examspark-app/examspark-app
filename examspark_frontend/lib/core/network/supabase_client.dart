import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Standardized Supabase client for authentication and Edge Function integration
class SupabaseClient {
  SupabaseClient._();

  static final SupabaseClient instance = SupabaseClient._();

  late final supabase.SupabaseClient _client;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_isInitialized) return;

    await supabase.Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    _client = supabase.Supabase.instance.client;
    _isInitialized = true;
  }

  supabase.SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('SupabaseClient not initialized. Call initialize() first.');
    }
    return _client;
  }

  supabase.User? get currentUser {
    if (!_isInitialized) return null;
    return client.auth.currentUser;
  }

  Future<supabase.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<supabase.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

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

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    return response;
  }

  Future<void> updateCredits(String userId, int newBalance) async {
    await client
        .from('users')
        .update({'credits_balance': newBalance})
        .eq('id', userId);
  }

  Future<List<Map<String, dynamic>>> getCreditTransactions(String userId) async {
    final response = await client
        .from('credit_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Stream<Map<String, dynamic>> userProfileStream(String userId) {
    return client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((event) => event.first);
  }
}
