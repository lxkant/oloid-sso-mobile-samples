import SwiftUI
import WebKit

/// A SwiftUI wrapper around `WKWebView`.
///
/// Uses a non-persistent data store so each launch starts with a clean
/// cookie / cache jar (handy for a login-flow POC). Flip `usePersistentStore`
/// to `true` if you want cookies to survive between launches.
struct WebView: UIViewRepresentable {
    let url: URL
    var usePersistentStore: Bool = false

    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = usePersistentStore
            ? .default()
            : .nonPersistent()
        // Allow JS-driven navigation and modern web auth flows.
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // Let media (e.g. "Login with Face" camera) start without an extra gesture.
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = []

        // Pipe the page's JS console + errors back to the native Xcode log so a
        // blank (client-rendered) page reveals WHY it failed to render.
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "logging")
        controller.addUserScript(WKUserScript(
            source: Coordinator.consoleBridgeJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        if #available(iOS 16.4, *) {
            webView.isInspectable = true   // enables Safari ▸ Develop inspection of this WKWebView
        }
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op: navigation is driven by the initial load and user interaction.
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private let parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Injected at document start: forwards console.*, window.onerror, and
        // unhandled promise rejections to the native handler named "logging".
        static let consoleBridgeJS = """
        (function() {
          function send(level, args) {
            try {
              window.webkit.messageHandlers.logging.postMessage(
                level + ': ' + Array.prototype.map.call(args, function(a) {
                  try { return typeof a === 'object' ? JSON.stringify(a) : String(a); }
                  catch (e) { return String(a); }
                }).join(' ')
              );
            } catch (e) {}
          }
          ['log','warn','error','info'].forEach(function(level) {
            var orig = console[level];
            console[level] = function() { send(level, arguments); orig.apply(console, arguments); };
          });
          window.addEventListener('error', function(e) {
            send('error', [e.message + ' @ ' + (e.filename || '') + ':' + (e.lineno || '')]);
          });
          window.addEventListener('unhandledrejection', function(e) {
            send('error', ['unhandledrejection: ' + (e.reason && e.reason.message ? e.reason.message : e.reason)]);
          });
        })();
        """

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "logging" else { return }
            print("[WebView][JS] \(message.body)")
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.errorMessage = nil
            print("[WebView] ▶︎ start loading: \(webView.url?.absoluteString ?? "?")")
        }

        // Inspect the HTTP response so a 4xx/5xx (which renders blank) is visible.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let http = navigationResponse.response as? HTTPURLResponse {
                print("[WebView] ◀︎ HTTP \(http.statusCode) for \(http.url?.absoluteString ?? "?")")
                if http.statusCode >= 400 {
                    DispatchQueue.main.async {
                        self.parent.errorMessage = "Server returned HTTP \(http.statusCode)."
                    }
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title ?? ""
            print("[WebView] ✓ finished: title=\(webView.title ?? "")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.errorMessage = error.localizedDescription
            print("[WebView] ✗ didFail: \(error)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            let ns = error as NSError
            parent.errorMessage = "\(error.localizedDescription) (code \(ns.code))"
            print("[WebView] ✗ didFailProvisional: \(ns.domain) \(ns.code) — \(error.localizedDescription)")
        }

        // Detect the renderer process being killed (a common cause of a sudden blank page).
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            print("[WebView] ⚠︎ web content process terminated — reloading")
            parent.errorMessage = "Web content crashed. Reloading…"
            webView.reload()
        }

        // POC ONLY: accept the preview environment's TLS certificate so a
        // self-signed / untrusted cert doesn't fail silently to a blank page.
        // Remove this for production — it disables certificate validation.
        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let trust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            print("[WebView] 🔒 accepting server trust for \(challenge.protectionSpace.host)")
            completionHandler(.useCredential, URLCredential(trust: trust))
        }

        // Open `target="_blank"` / popup links in the same web view.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
