import WebKit

/// Exports the live preview WebView to PDF, so the output matches exactly what the user sees
/// (including highlighted code, KaTeX math, and Mermaid diagrams).
enum PDFExporter {
    static func export(from webView: WKWebView, to url: URL) async throws {
        let data = try await webView.pdf(configuration: WKPDFConfiguration())
        try data.write(to: url)
    }
}
