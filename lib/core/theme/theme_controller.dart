import 'package:flutter/material.dart';
import '../storage/app_storage.dart';

class AppController {
  const AppController._();

  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> init() async {
    final saved = await AppStorage.getThemeMode();
    if (saved != null) {
      themeMode.value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  static void toggle(BuildContext context) {
    final isDark = themeMode.value == ThemeMode.dark ||
        (themeMode.value == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = next;
    AppStorage.setThemeMode(next.name);
  }
}
