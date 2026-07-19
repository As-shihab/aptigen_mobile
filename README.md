# Aptigen Mobile

This is now a production-oriented Flutter app skeleton with a temporary webview shell for:

`https://aptigen.net`

## Current structure

```text
lib/
  app/
    app.dart
    bootstrap.dart
  core/
    config/
    theme/
  features/
    web_shell/
      presentation/
main.dart
test/
pubspec.yaml
```

## Current behavior

- app bootstraps through `lib/app/bootstrap.dart`
- root app lives in `lib/app/app.dart`
- shared config and theme live in `lib/core`
- the current feature is `web_shell`
- for now, the app only loads the production web app in a webview

## Important

Flutter SDK is not installed in this environment, so the native project folders were not generated here.

When Flutter is available, run this inside `D:\aptigen\mobile`:

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter test
flutter run
```

That will generate the native Flutter folders while keeping this app structure and code.
