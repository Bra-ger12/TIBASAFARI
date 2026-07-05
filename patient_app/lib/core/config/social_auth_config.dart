/// Client-side identifiers for Google/Apple sign-in. These are public
/// (not secrets) but still need to be supplied at build/run time via
/// --dart-define-from-file=env.json — see env.json / .gitignore.
class SocialAuthConfig {
  /// Google Cloud Console → APIs & Services → Credentials → the *Web*
  /// application OAuth client ID (used as GoogleSignIn's serverClientId so
  /// the backend can verify the id_token's audience).
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  /// Apple Developer Portal → Identifiers → the Services ID configured for
  /// "Sign in with Apple". Only required for the Android/web fallback flow
  /// — native iOS/macOS sign-in doesn't need it.
  static const String appleServiceId =
      String.fromEnvironment('APPLE_SERVICE_ID', defaultValue: '');

  /// The HTTPS redirect URI registered against that Services ID (must be a
  /// real endpoint you control that relays back to the app). Only required
  /// for the Android/web fallback flow.
  static const String appleRedirectUri =
      String.fromEnvironment('APPLE_REDIRECT_URI', defaultValue: '');

  static bool get googleConfigured => googleServerClientId.isNotEmpty;

  static bool get appleWebFlowConfigured =>
      appleServiceId.isNotEmpty && appleRedirectUri.isNotEmpty;
}
