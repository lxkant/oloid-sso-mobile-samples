# Flutter — Oloid WebKey SSO samples

Flutter sample(s) for opening the Oloid WebKey SSO URL.

| Sample | Description |
| --- | --- |
| [`OloidSSOBrowserDemo/`](OloidSSOBrowserDemo/) | Opens the SSO URL via SFSafariViewController / ASWebAuthenticationSession / WKWebView (iOS) and Custom Tabs / WebView (Android). |

```bash
cd OloidSSOBrowserDemo
flutter pub get
flutter run
```

> Set your tenant WebKey SSO instance URL in `OloidSSOBrowserDemo/lib/main.dart`
> (the `kSsoUrl` constant) before running.

---

## ⚠️ Common issue: blank / white page

**If the WebView shows a blank white page, JavaScript is almost always not enabled.**

The Oloid login page is a **client-rendered single-page app (SPA)**: the server
returns an almost-empty HTML shell (`HTTP 200`) and JavaScript builds the whole
UI. So if JavaScript is off, the page "loads successfully" but renders nothing.

### Why this bites Flutter specifically

`webview_flutter` creates the `WebViewController` with **JavaScript DISABLED by
default** — the opposite of a native iOS `WKWebView`, which has it **enabled**.
A developer who saw the URL work in the native iOS app gets a blank page in
Flutter purely because of this default.

| | JavaScript default | Must enable it? |
| --- | --- | --- |
| Native iOS `WKWebView` | **Enabled** | No |
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

### Other things that can cause a blank page

1. **JavaScript disabled** (above) — most common. ⭐
2. **Android: missing `INTERNET` permission** — auto-added in debug, NOT in
   release, so it works in debug and goes blank in release. Add
   `<uses-permission android:name="android.permission.INTERNET"/>` to
   `android/app/src/main/AndroidManifest.xml`.
3. **API/JS bundle unreachable** — device can't reach the backend (VPN/IP
   allowlist), or CSP/CORS blocks a script.
4. **Cookies / DOM storage blocked** by the WebView.

See [`OloidSSOBrowserDemo/README.md`](OloidSSOBrowserDemo/README.md) for the full
troubleshooting guide and a built-in toggle that reproduces the blank page live.
