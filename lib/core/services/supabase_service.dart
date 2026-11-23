import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _initialized = false;

  static bool get isConfigured =>
      _url.startsWith('https://') && _anonKey.isNotEmpty;

  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase has not been initialized.');
    }
    return Supabase.instance.client;
  }

  static User? get currentUser =>
      _initialized ? client.auth.currentUser : null;

  static Future<void> initialize() async {
    if (_initialized || !isConfigured) return;

    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _initialized = true;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String displayName = '',
  }) {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: 'animefriends://login-callback',
      data: {
        'username': username.trim().toLowerCase(),
        'display_name': displayName.trim(),
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() => client.auth.signOut();
}
