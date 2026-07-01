import 'package:web/web.dart' as web;

class AuthStorage {
  static const _accessKey = 'ts_admin_access';
  static const _refreshKey = 'ts_admin_refresh';

  static void saveTokens({required String access, required String refresh}) {
    web.window.localStorage.setItem(_accessKey, access);
    web.window.localStorage.setItem(_refreshKey, refresh);
  }

  static String? get accessToken {
    final t = web.window.localStorage.getItem(_accessKey);
    return (t == null || t.isEmpty) ? null : t;
  }

  static String? get refreshToken {
    final t = web.window.localStorage.getItem(_refreshKey);
    return (t == null || t.isEmpty) ? null : t;
  }

  static bool get isLoggedIn {
    final t = accessToken;
    return t != null && t.isNotEmpty;
  }

  static void clear() {
    web.window.localStorage.removeItem(_accessKey);
    web.window.localStorage.removeItem(_refreshKey);
  }
}
