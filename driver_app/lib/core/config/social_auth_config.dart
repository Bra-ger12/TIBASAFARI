/// Client-side identifier for Google sign-in. This is public (not a
/// secret) but still needs to be supplied at build/run time via
/// --dart-define-from-file=env.json — see env.json / .gitignore.
class SocialAuthConfig {
  /// Google Cloud Console → APIs & Services → Credentials → the *Web*
  /// application OAuth client ID (used as GoogleSignIn's serverClientId so
  /// the backend can verify the id_token's audience). Shared with
  /// patient_app — the backend validates against a list of client IDs, not
  /// a single per-app value.
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  static bool get googleConfigured => googleServerClientId.isNotEmpty;
}
