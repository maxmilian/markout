import Foundation

enum HTMLTemplate {
    enum Theme: String {
        case light
        case dark
    }

    static func page(theme: Theme) -> String {
        let themeAttr = theme == .dark ? " data-theme=\"dark\"" : ""
        return """
        <!DOCTYPE html>
        <html\(themeAttr)>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(css)
        </style>
        </head>
        <body>
        <div id="content"></div>
        <script>
        function setContent(html) { document.getElementById('content').innerHTML = html; }
        function setTheme(dark) {
          document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
        }
        </script>
        </body>
        </html>
        """
    }

    static let css: String = {
        if let url = Bundle.main.url(forResource: "default", withExtension: "css"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            return s
        }
        return fallbackCSS
    }()

    private static let fallbackCSS = """
    body { font-family: -apple-system, sans-serif; line-height: 1.6; padding: 24px 32px; }
    #content { max-width: 900px; margin: 0 auto; }
    """
}
