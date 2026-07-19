import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const String appName = 'Aptigen';

  // Debug → localhost:3400  |  Release build → api.aptigen.net
  static const String apiBase = kDebugMode
      ? 'https://api.aptigen.net'
      : 'https://api.aptigen.net';

  static const String v8Base = '$apiBase/aptigen/';
  static const String apiPrefix = '$apiBase/api/';
}
