import Foundation

/// Builds a self-contained HTML document from a rendered body and stylesheet.
///
/// The output embeds the CSS inline and needs no network, so an exported file renders identically
/// offline. Pure; the caller supplies the already-rendered preview `body` and the active theme `css`.
enum HTMLExporter {
    static func standaloneHTML(body: String, css: String, title: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        \(css)
        </style>
        </head>
        <body>
        <div id="content">
        \(body)
        </div>
        </body>
        </html>
        """
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
