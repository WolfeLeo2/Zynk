class SupabaseConfig {
  static String get url {
    const url = String.fromEnvironment('SUPABASE_URL');
    if (url.isEmpty) {
      throw Exception('SUPABASE_URL not found in environment');
    }
    return url;
  }

  static String get anonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY not found in environment');
    }
    return key;
  }
}
