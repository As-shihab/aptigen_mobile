import 'package:flutter/material.dart';
import '../core/theme/theme_controller.dart';
import 'app.dart';

void bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppController.init();
  runApp(builder());
}
