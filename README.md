# Oloid WebKey SSO — Sample Apps

Reference sample apps showing how to open the Oloid WebKey SSO URL across
platforms, and how to diagnose the common **blank / white page** problem.

## Structure

| Folder | Contents | Status |
| --- | --- | --- |
| [`flutter/`](flutter/) | Flutter app (iOS + Android) — `OloidSSOBrowserDemo` | ✅ Available |
| [`react/`](react/) | React / React Native sample | ⏳ Coming soon |
| [`native-ios/`](native-ios/) | Native iOS (Swift) sample | ⏳ Coming soon |
| [`native-android/`](native-android/) | Native Android (Kotlin) sample | ⏳ Coming soon |

## Getting started

Each platform folder is self-contained. See the README inside each folder.

For the Flutter sample:

```bash
cd flutter/OloidSSOBrowserDemo
flutter pub get
flutter run
```

> Set your tenant WebKey SSO instance URL in the app's config before running
> (e.g. `kSsoUrl` in `flutter/OloidSSOBrowserDemo/lib/main.dart`).
