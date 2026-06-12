import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// CONFIG — fill these in for your environment.
///
/// [kSsoUrl] is the page opened by every launch method below.
/// Add your tenant WebKey SSO instance URL here
/// (e.g. `https://<your-tenant>.previewoloid.net/login`).
const String kSsoUrl = '';

/// Custom URL scheme the SSO flow redirects back to when login finishes.
/// Used ONLY by the auth-session option (ASWebAuthenticationSession / Custom
/// Tab). Must match the scheme registered in the iOS Info.plist and Android
/// manifest. If your SSO never redirects to this scheme, that option simply
/// stays open until the user cancels — still fine for a demo.
const String kCallbackScheme = 'oloidsso';
/// ─────────────────────────────────────────────────────────────────────────

bool get _isIOS => !kIsWeb && Platform.isIOS;

void main() => runApp(const OloidSsoApp());

/// The launch mechanisms we can demo. The same Dart option maps to a different
/// native browser on each platform (see the table in the README / titles).
enum SsoMethod {
  inAppBrowser,
  authSession,
  webView,
  webViewNoJs; // intentionally buggy: JavaScript disabled -> blank page repro

  /// Title shown in the picker, platform-aware so a demo reads correctly.
  String get title {
    switch (this) {
      case SsoMethod.inAppBrowser:
        return _isIOS ? 'SFSafariViewController' : 'Chrome Custom Tabs';
      case SsoMethod.authSession:
        return _isIOS ? 'ASWebAuthenticationSession' : 'Custom Tab Auth Session';
      case SsoMethod.webView:
        return _isIOS ? 'WKWebView' : 'Android WebView';
      case SsoMethod.webViewNoJs:
        return '⚠️ WebView — JS DISABLED (buggy)';
    }
  }

  String get subtitle {
    switch (this) {
      case SsoMethod.inAppBrowser:
        return 'In-app system browser. Shares cookies with the system browser.';
      case SsoMethod.authSession:
        return 'Ephemeral auth flow that returns the callback URL to the app.';
      case SsoMethod.webView:
        return 'Web view embedded inside the app. Full control, no browser chrome.';
      case SsoMethod.webViewNoJs:
        return 'Same WebView WITHOUT setJavaScriptMode -> the SPA never renders. '
            'Reproduces the all-blank window developers report.';
    }
  }

  IconData get icon {
    switch (this) {
      case SsoMethod.inAppBrowser:
        return Icons.public;
      case SsoMethod.authSession:
        return Icons.verified_user_outlined;
      case SsoMethod.webView:
        return Icons.web_asset;
      case SsoMethod.webViewNoJs:
        return Icons.bug_report;
    }
  }
}

class OloidSsoApp extends StatelessWidget {
  const OloidSsoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oloid SSO Browser Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF171C2E), useMaterial3: true),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _status;
  bool _busy = false;

  Future<void> _onLoginTapped() async {
    final method = await showModalBottomSheet<SsoMethod>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                _isIOS ? 'Open SSO with… (iOS)' : 'Open SSO with… (Android)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            for (final m in SsoMethod.values)
              ListTile(
                leading: Icon(m.icon),
                title: Text(m.title),
                subtitle: Text(m.subtitle),
                onTap: () => Navigator.pop(ctx, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (method != null) await _launch(method);
  }

  Future<void> _launch(SsoMethod method) async {
    setState(() {
      _busy = true;
      _status = 'Opening ${method.title}…';
    });
    try {
      switch (method) {
        case SsoMethod.inAppBrowser:
          await _launchInAppBrowser();
          _setStatus('${method.title}: opened');
        case SsoMethod.authSession:
          final result = await _launchAuthSession();
          _setStatus('${method.title}: $result');
        case SsoMethod.webView:
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const WebViewPage(url: kSsoUrl),
          ));
          _setStatus('${method.title}: closed');
        case SsoMethod.webViewNoJs:
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const WebViewPage(url: kSsoUrl, disableJs: true),
          ));
          _setStatus('${method.title}: closed (was it blank?)');
      }
    } catch (e) {
      _setStatus('${method.title} failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// SFSafariViewController (iOS) / Chrome Custom Tabs (Android).
  Future<void> _launchInAppBrowser() async {
    final ok = await launchUrl(
      Uri.parse(kSsoUrl),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!ok) throw 'launchUrl returned false';
  }

  /// ASWebAuthenticationSession (iOS) / Custom Tab auth (Android).
  Future<String> _launchAuthSession() async {
    final result = await FlutterWebAuth2.authenticate(
      url: kSsoUrl,
      callbackUrlScheme: kCallbackScheme,
    );
    return result; // the full callback URL when SSO redirects back
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF171C2E);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.shield, size: 84, color: navy),
              const SizedBox(height: 20),
              const Text('Oloid SSO Browser Demo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(kSsoUrl,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const Spacer(),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_status!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _busy ? null : _onLoginTapped,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_outline),
                  label: const Text('Login with Oloid',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// Embedded web view page — WKWebView on iOS, Android WebView on Android.
///
/// [disableJs] = true reproduces the common bug: webview_flutter ships with
/// JavaScript DISABLED by default. The SSO page is a client-rendered SPA, so
/// without JS the body never renders and you get an all-blank window.
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key, required this.url, this.disableJs = false});
  final String url;
  final bool disableJs;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // ⚠️ REQUIRED. The Oloid SSO/login page is a client-rendered SPA: the
      // server returns an almost-empty HTML shell (HTTP 200) and JavaScript
      // builds the entire UI. webview_flutter creates the controller with
      // JavaScript DISABLED by default — so if you remove this line, or set it
      // to JavaScriptMode.disabled, the page loads "successfully" but the body
      // never renders and you get an ALL-BLANK WHITE PAGE.
      // Keep it on JavaScriptMode.unrestricted for the SSO URL to display.
      // (disableJs == true is the in-app demo toggle that reproduces the bug.)
      ..setJavaScriptMode(
          widget.disableJs ? JavaScriptMode.disabled : JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.disableJs ? 'Login (JS disabled)' : 'Login'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
