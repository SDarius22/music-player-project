# Music Player Frontend

Flutter client for the peer-assisted music streaming system.

## Development

```bash
flutter pub get
flutter run -d linux
flutter run -d chrome -t lib/main_web.dart
```

Use `--dart-define=API_BASE_URL=...` and `--dart-define=WS_BASE_URL=...` to point the app at a non-local backend.

## Validation

```bash
dart format lib test integration_test
dart analyze
flutter test
```
