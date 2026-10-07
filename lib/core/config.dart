import 'package:flutter/foundation.dart';

class AppConfig {
  /// Public API. Nginx on the VPS proxies this host to 127.0.0.1:3000.
  static const productionApiUrl = 'https://backend-mail.ibelucky.com';

  /// Only for a debug build on this machine. A phone or a browser elsewhere cannot use it.
  static const debugApiUrl = 'http://127.0.0.1:3000';

  static String get apiBase {
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) {
      return defined.replaceAll(RegExp(r'/+$'), '');
    }
    if (kReleaseMode) return productionApiUrl;
    return debugApiUrl;
  }
}
