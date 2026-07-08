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
    var previewCSS: String = HTMLTemplate.css
    /// When set, scroll the preview so the block at this 1-based source line is at the top.
    var scrollLine: Int? = nil
    /// Called once with the underlying WebView, so the owner can drive PDF export.
    var onWebViewReady: ((WKWebView) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        onWebViewReady?(webView)
        context.coordinator.configure(body: htmlBody, isDark: isDark, css: previewCSS)
        webView.loadHTMLString(
            HTMLTemplate.page(theme: isDark ? .dark : .light, previewCSS: previewCSS),
            baseURL: Bundle.main.resourceURL
        )
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        // A CSS/theme change requires a full template reload; body changes only inject.
        if coordinator.needsReload(isDark: isDark, css: previewCSS) {
            coordinator.configure(body: htmlBody, isDark: isDark, css: previewCSS)
            coordinator.isLoaded = false
            webView.loadHTMLString(
                HTMLTemplate.page(theme: isDark ? .dark : .light, previewCSS: previewCSS),
                baseURL: Bundle.main.resourceURL
            )
            return
        }

        coordinator.pendingBody = htmlBody
        guard coordinator.isLoaded else { return }
        webView.evaluateJavaScript(PreviewInjection.themeScript(isDark: isDark))
        webView.evaluateJavaScript(PreviewInjection.script(forBody: htmlBody))
        if let line = scrollLine, line != coordinator.lastScrollLine {
            coordinator.lastScrollLine = line
            webView.evaluateJavaScript("scrollToSourceLine(\(line));")
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var isLoaded = false
        var pendingBody = ""
        var isDark = false
        var css = ""
        var lastScrollLine: Int?

        func configure(body: String, isDark: Bool, css: String) {
            self.pendingBody = body
            self.isDark = isDark
            self.css = css
        }

        func needsReload(isDark: Bool, css: String) -> Bool {
            css != self.css || isDark != self.isDark
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            webView.evaluateJavaScript(PreviewInjection.themeScript(isDark: isDark))
            webView.evaluateJavaScript(PreviewInjection.script(forBody: pendingBody))
        }
    }
}
