import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String defaultBaseUrl = 'http://127.0.0.1:5000';
  static const String defaultWsUrl = 'ws://127.0.0.1:5000/slt/v1/ws';

  static String get apiBaseUrl {
    try {
      final envVal = dotenv.env['API_BASE_URL'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return defaultBaseUrl;
  }

  static String get sltWsUrl {
    try {
      final envVal = dotenv.env['SLT_WS_URL'] ?? dotenv.env['WS_URL'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return defaultWsUrl;
  }
}
