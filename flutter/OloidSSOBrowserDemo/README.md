# Oloid SSO Browser Demo

A small **Flutter (iOS + Android)** sample for developers integrating the Oloid
SSO/login page. It demonstrates every supported way to open the SSO URL and —
most importantly — helps you diagnose **why the page sometimes shows up as an
all-blank white screen**.

Tap **Login with Oloid**, then pick a launch mechanism:

| Picker option | iOS | Android |
| --- | --- | --- |
| In-app browser | `SFSafariViewController` | Chrome Custom Tabs |
| Auth session | `ASWebAuthenticationSession` | Custom Tab auth |
| Embedded WebView | `WKWebView` | Android WebView |
| ⚠️ WebView — JS DISABLED (buggy) | reproduces the blank page | reproduces the blank page |

## Configuration

Edit the constants at the top of [`lib/main.dart`](lib/main.dart):

```dart
const String kSsoUrl = 'https://guitarcenter.previewoloid.net/login';
const String kCallbackScheme = 'oloidsso'; // only used by the auth-session option
```

## Run

```bash
flutter pub get
flutter run            # pick an iOS simulator or Android device/emulator
```

---

# Why the WebView shows a blank / white page

The Oloid login page is a **client-rendered single-page app (SPA)**: the server
returns an almost-empty HTML shell with `HTTP 200`, and JavaScript then builds
the entire UI and calls the backend API. Because the network request *succeeds*,
a blank page is confusing — it is **not** a 404/500 or a TLS error. Below are the
real causes, in the order you should check them.

### 1. JavaScript is disabled (most common) ⭐

> **🔑 In a Flutter app, enabling JavaScript is a MUST — it is NOT enabled by
> default.** This is the single biggest difference from building a native iOS
> app. A native `WKWebView` (and `SFSafariViewController`) ships with JavaScript
> **already ON**, so the SSO page "just works." Flutter's `webview_flutter` is
> the opposite: it creates the `WebViewController` with JavaScript **OFF by
> default**, so you *must* explicitly call
> `setJavaScriptMode(JavaScriptMode.unrestricted)`. Developers coming from the
> native iOS app are caught out by this — the same URL that rendered natively
> shows up blank in Flutter purely because of this default.

| | JavaScript default | Need to enable it? |
| --- | --- | --- |
| Native iOS `WKWebView` | **Enabled** | No |
| Native iOS `SFSafariViewController` | **Enabled** | No |
| Flutter `webview_flutter` | **Disabled** | **Yes — required** |

If you forget to enable it, the SPA never renders → blank page.

```dart
// ❌ Blank page — the minimal snippet from the plugin's basic example
WebViewController()
  ..loadRequest(Uri.parse(url));

// ✅ Correct — JavaScript must be enabled for a client-rendered page
WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)   // <-- the line that matters
  ..loadRequest(Uri.parse(url));
```

> This sample lets you reproduce it live: the **"⚠️ WebView — JS DISABLED
> (buggy)"** picker option opens the *same* WebView with
> `JavaScriptMode.disabled` and you'll see the blank window. The normal
> **WKWebView / Android WebView** option works because JS is enabled.

### 2. Android: missing `INTERNET` permission (blank only in release) ⭐

Flutter auto-adds the `INTERNET` permission for **debug/profile** builds, but
**not** for release. If your *main* manifest doesn't declare it, the WebView
can't fetch anything in a release build → blank page that "works in debug."

`android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>
    ...
</manifest>
```

### 3. The page loads but its API/JS bundle fails

JS runs, but a request to the backend (e.g. `api.previewoloid.net`) or the JS
bundle fails, so the SPA renders nothing. Usually environment-specific:

- The device/network can't reach the API (preview/staging behind **VPN or an IP
  allowlist**; works on your machine, blank on the customer's network).
- A `Content-Security-Policy` blocks a script the page needs.
- CORS / mixed-content blocking inside the WebView.

How to confirm: enable WebView debugging and watch the JS console (see below).

### 4. Cookies / DOM storage blocked

WebViews block third-party cookies aggressively (ITP on iOS). If the auth SDK
relies on cookies or `localStorage` that get cleared/partitioned, bootstrap
fails → blank. Use a **persistent** data store and don't clear cookies between
loads.

### 5. iOS App Transport Security (ATS)

HTTPS with a valid cert is fine (this URL has a valid Amazon-issued cert). But
if a resource is served over plain HTTP, or the server only negotiates an old
TLS version/cipher, ATS blocks it. Avoid adding blanket
`NSAllowsArbitraryLoads`; fix the server instead.

### 6. WebView never sized / wrong widget tree

A `WebViewWidget` placed in an unbounded box (e.g. a `Column` without
`Expanded`) can collapse to zero height and look blank. Give it bounded
constraints (`Expanded`, `Scaffold.body`, a sized container).

### 7. Renderer process crashed (rare)

Out-of-memory on a heavy page kills the web content process, leaving a blank
view. Handle it: on iOS implement `webViewWebContentProcessDidTerminate` and
reload; on Android listen for render-process-gone.

---

## Fast diagnosis checklist

1. Is it blank in **debug too**, or **only release**? Only release → almost
   certainly the Android `INTERNET` permission (#2).
2. Did you call **`setJavaScriptMode(JavaScriptMode.unrestricted)`**? (#1)
3. Open the **same URL in the device's system browser** (Safari/Chrome). If that
   is also blank, it's a network/API/server issue (#3), not your WebView code.
4. Turn on **WebView debugging** and read the JS console:
   - iOS: the underlying `WKWebView` is inspectable via **Safari ▸ Develop ▸
     [device]** (set `isInspectable = true` on iOS 16.4+).
   - Android: `WebView.setWebContentsDebuggingEnabled(true)`, then
     **chrome://inspect** on desktop Chrome.
5. Check the response code/headers: a `200` with a blank body confirms the SPA
   never rendered (JS/API), not a transport failure.

## TL;DR

> A blank WebView with this SSO URL is **almost always JavaScript being disabled**
> (Flutter's default) or, on Android release builds, the **missing `INTERNET`
> permission**. Everything else is environment-specific (network/CSP/cookies).
