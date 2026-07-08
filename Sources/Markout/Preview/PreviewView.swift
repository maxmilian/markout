import SwiftUI
import WebKit

enum PreviewInjection {
    static func script(forBody body: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [body], options: [])
        let json = String(decoding: data, as: UTF8.self)
        let literal = String(json.dropFirst().dropLast())
        return "setContent(\(literal));"
    }

    static func themeScript(isDark: Bool) -> String {
        "setTheme(\(isDark ? "true" : "false"));"
    }
}

struct PreviewView: NSViewRepresentable {
    let htmlBody: String
    let isDark: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.pendingBody = htmlBody
        context.coordinator.isDark = isDark
        webView.loadHTMLString(HTMLTemplate.page(theme: isDark ? .dark : .light), baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.isLoaded else {
            context.coordinator.pendingBody = htmlBody
            context.coordinator.isDark = isDark
            return
        }
        webView.evaluateJavaScript(PreviewInjection.themeScript(isDark: isDark))
        webView.evaluateJavaScript(PreviewInjection.script(forBody: htmlBody))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var isLoaded = false
        var pendingBody = ""
        var isDark = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            webView.evaluateJavaScript(PreviewInjection.themeScript(isDark: isDark))
            webView.evaluateJavaScript(PreviewInjection.script(forBody: pendingBody))
        }
    }
}
