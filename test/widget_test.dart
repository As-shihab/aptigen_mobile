import 'package:aptigen_mobile/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app can be instantiated', () {
    const app = AptigenApp();

    expect(app, isNotNull);
  });
}
