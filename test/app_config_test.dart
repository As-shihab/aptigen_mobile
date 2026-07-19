import 'package:aptigen_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api base points to aptigen production', () {
    expect(AppConfig.apiBase, 'https://api.aptigen.net');
  });

  test('v8 base contains aptigen prefix', () {
    expect(AppConfig.v8Base, contains('/aptigen/'));
  });
}
