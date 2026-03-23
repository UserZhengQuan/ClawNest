import SwiftUI
import WebKit

enum DashboardLifecycleEvent {
    case loading
    case ready
    case failed(String)
}

struct DashboardWebView: NSViewRepresentable {
    let url: URL
    let reloadToken: UUID
    let onStateChange: (DashboardLifecycleEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: onStateChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(URLRequest(url: url))
        context.coordinator.lastToken = reloadToken
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let shouldReload = context.coordinator.lastToken != reloadToken || nsView.url != url
        guard shouldReload else { return }

        context.coordinator.lastToken = reloadToken
        nsView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onStateChange: (DashboardLifecycleEvent) -> Void
        var lastToken = UUID()

        init(onStateChange: @escaping (DashboardLifecycleEvent) -> Void) {
            self.onStateChange = onStateChange
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onStateChange(.loading)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onStateChange(.ready)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onStateChange(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onStateChange(.failed(error.localizedDescription))
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            onStateChange(.failed("The embedded dashboard web process terminated unexpectedly."))
        }
    }
}
