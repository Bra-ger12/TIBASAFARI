import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists JWT tokens securely across app restarts.
class AuthStorage {
  AuthStorage._();
  static final instance = AuthStorage._();

  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'driver_access_token';
  static const _kRefreshToken = 'driver_refresh_token';
  static const _kUserId = 'driver_user_id';

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
    if (userId != null) {
      await _storage.write(key: _kUserId, value: userId);
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<String?> getUserId() => _storage.read(key: _kUserId);

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
