# Flutter — Oloid WebKey SSO samples

Flutter sample(s) showing how to open the Oloid WebKey SSO URL on **iOS and
Android**, and how to diagnose the common **blank / white page**.

| Sample | Description |
| --- | --- |
| [`OloidSSOBrowserDemo/`](OloidSSOBrowserDemo/) | Opens the SSO URL four ways and lets you reproduce the blank-page bug live. |

## Contents

- [Quick start](#quick-start)
- [How it opens the SSO URL](#how-it-opens-the-sso-url)
- [⚠️ Common issue: blank / white page](#️-common-issue-blank--white-page)
- [Platform setup requirements](#platform-setup-requirements)
- [Debugging a blank page](#debugging-a-blank-page)

## Quick start

```bash
cd OloidSSOBrowserDemo
flutter pub get
flutter run            # choose an iOS simulator or Android device/emulator
```

> **Set your tenant URL first.** Open `OloidSSOBrowserDemo/lib/main.dart` and set
> the `kSsoUrl` constant to your tenant WebKey SSO instance URL
> (e.g. `https://<your-tenant>.previewoloid.net/login`).

## How it opens the SSO URL

Tap **Login with Oloid**, then pick a mechanism. The same Dart option maps to
the right native browser per platform:

| Picker option | iOS | Android | Plugin |
| --- | --- | --- | --- |
| In-app browser | `SFSafariViewController` | Chrome Custom Tabs | `url_launcher` |
| Auth session | `ASWebAuthenticationSession` | Custom Tab auth | `flutter_web_auth_2` |
| Embedded WebView | `WKWebView` | Android WebView | `webview_flutter` |
| ⚠️ WebView — JS disabled | (reproduces blank page) | (reproduces blank page) | `webview_flutter` |

---

## ⚠️ Common issue: blank / white page

**If the WebView shows a blank white page, JavaScript is almost always not enabled.**

The Oloid login page is a **client-rendered single-page app (SPA)**: the server
returns an almost-empty HTML shell (`HTTP 200`) and JavaScript builds the whole
UI. So if JavaScript is off, the page "loads successfully" but renders nothing —
no error, no 404, just a white screen.

### Why this bites Flutter specifically

`webview_flutter` creates the `WebViewController` with **JavaScript DISABLED by
default** — the opposite of a native iOS `WKWebView`, which has it **enabled**.
A developer who saw the URL work in the native iOS app gets a blank page in
Flutter purely because of this default.

| | JavaScript default | Must enable it? |
| --- | --- | --- |
| Native iOS `WKWebView` | **Enabled** | No |
| Native iOS `SFSafariViewController` | **Enabled** | No |
| Flutter `webview_flutter` | **Disabled** | **Yes — required** |

### The fix

```dart
// ❌ Blank page — JavaScript is off by default
WebViewController()
  ..loadRequest(Uri.parse(url));

// ✅ Correct — enable JavaScript for the SPA to render
WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)   // <-- the line that matters
  ..loadRequest(Uri.parse(url));
```

### See it yourself

The app has a built-in toggle to reproduce it: tap **Login with Oloid** →
**⚠️ WebView — JS DISABLED (buggy)** to see the blank window, then the normal
**WKWebView / Android WebView** option to see it render. Same WebView, same URL —
the only difference is `JavaScriptMode`.

### Other things that can cause a blank page

| # | Cause | Notes |
| --- | --- | --- |
| 1 | **JavaScript disabled** ⭐ | The default above. Most common. |
| 2 | **Android: missing `INTERNET` permission** ⭐ | Auto-added in debug, NOT in release → works in debug, blank in release. |
| 3 | API / JS bundle unreachable | Device can't reach the backend (VPN / IP allowlist), or CSP / CORS blocks a script. |
| 4 | Cookies / DOM storage blocked | Auth SDK can't bootstrap if storage is cleared/partitioned. |
| 5 | WebView not sized | `WebViewWidget` in an unbounded box collapses to zero height. |

---

## Platform setup requirements

### Android (`android/app/src/main/AndroidManifest.xml`)

- **`INTERNET` permission** (required for release builds, or the WebView is blank):
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```
- **`<queries>` for `url_launcher`** (Android 11+, to open https / custom tabs).
- **`flutter_web_auth_2` callback activity** for the auth-session option's
  redirect scheme (must match `kCallbackScheme`).

The sample already configures all three.

### iOS

- HTTPS with a valid certificate works out of the box (no ATS exception needed).
- The auth-session option uses `ASWebAuthenticationSession`; its callback scheme
  is `kCallbackScheme`. Only relevant if your SSO redirects back to a custom
  scheme to finish login.

## Debugging a blank page

1. Is it blank in **debug too**, or **only release**? Only release → almost
   certainly the Android `INTERNET` permission (#2 above).
2. Did you call **`setJavaScriptMode(JavaScriptMode.unrestricted)`**? (#1)
3. Open the **same URL in the device's system browser** (Safari/Chrome). If
   that's also blank, it's a network/API/server issue (#3), not your WebView code.
4. Inspect the WebView's JS console:
   - **iOS** — Safari ▸ Develop ▸ [device] ▸ the WebView (set `isInspectable = true`
     on the underlying WKWebView, iOS 16.4+).
   - **Android** — `WebView.setWebContentsDebuggingEnabled(true)`, then
     `chrome://inspect` in desktop Chrome.

See [`OloidSSOBrowserDemo/README.md`](OloidSSOBrowserDemo/README.md) for the full
troubleshooting reference.
