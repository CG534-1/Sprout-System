class SproutConfig {
  const SproutConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.apiBaseUrl,
    required this.firebaseApiKey,
    required this.firebaseAppId,
    required this.firebaseSenderId,
    required this.firebaseProjectId,
    required this.firebaseVapidKey,
  });

  factory SproutConfig.fromEnvironment() {
    return const SproutConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
      firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
      firebaseSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      firebaseVapidKey: String.fromEnvironment('FIREBASE_VAPID_KEY'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String apiBaseUrl;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseSenderId;
  final String firebaseProjectId;
  final String firebaseVapidKey;

  bool get ready =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && apiBaseUrl.isNotEmpty;

  bool get pushReady =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
