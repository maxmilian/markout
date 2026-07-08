import Foundation

enum HTMLTemplate {
    enum Theme: String {
        case light
        case dark
    }

    /// P1-compatible overload: uses the bundled default stylesheet (or the fallback under test).
    static func page(theme: Theme) -> String {
        page(theme: theme, previewCSS: css)
    }

    /// Full preview document. `previewCSS` is the selected `PreviewTheme`'s stylesheet, embedded
    /// inline; the bundled highlight.js / KaTeX / Mermaid assets are linked relative to the
    /// WebView's `baseURL` (`Bundle.main.resourceURL`).
    static func page(theme: Theme, previewCSS: String) -> String {
        let themeAttr = theme == .dark ? " data-theme=\"dark\"" : ""
        return """
        <!DOCTYPE html>
        <html\(themeAttr)>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="PreviewAssets/katex/katex.min.css">
        <link rel="stylesheet" href="PreviewAssets/highlight/highlight-light.css">
        <link rel="stylesheet" href="PreviewAssets/highlight/highlight-dark.css">
        <style>
        \(previewCSS)
        </style>
        </head>
        <body>
        <div id="content"></div>
        <script src="PreviewAssets/highlight/highlight.min.js"></script>
        <script src="PreviewAssets/katex/katex.min.js"></script>
        <script src="PreviewAssets/mermaid/mermaid.min.js"></script>
        <script>
        if (typeof mermaid !== 'undefined') {
          mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });
        }

        function renderMath(root) {
          if (typeof katex === 'undefined') return;
          function render(el, display) {
            try {
              katex.render(el.textContent, el, { displayMode: display, throwOnError: false });
            } catch (e) {
              el.classList.add('markout-error');
              el.textContent = String(e);
            }
          }
          root.querySelectorAll('.math-inline').forEach(function (el) { render(el, false); });
          root.querySelectorAll('.math-display').forEach(function (el) { render(el, true); });
        }

        function renderDiagrams(root) {
          if (typeof mermaid === 'undefined') return;
          root.querySelectorAll('code.language-mermaid').forEach(function (code) {
            var host = code.closest('pre') || code;
            var div = document.createElement('div');
            div.className = 'mermaid';
            div.textContent = code.textContent;
            host.replaceWith(div);
          });
          try { mermaid.run({ querySelector: '#content .mermaid' }); } catch (e) {}
        }

        function highlightCode(root) {
          if (typeof hljs === 'undefined') return;
          root.querySelectorAll('pre code:not(.language-mermaid)').forEach(function (block) {
            try { hljs.highlightElement(block); } catch (e) {}
          });
        }

        function afterRender() {
          var content = document.getElementById('content');
          renderDiagrams(content);
          highlightCode(content);
          renderMath(content);
        }

        function setContent(html) {
          document.getElementById('content').innerHTML = html;
          afterRender();
        }

        function setTheme(dark) {
          document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
        }

        function scrollToSourceLine(line) {
          var els = document.querySelectorAll('#content [data-sourcepos]');
          var target = null;
          for (var i = 0; i < els.length; i++) {
            var start = parseInt(els[i].getAttribute('data-sourcepos'), 10);
            if (isNaN(start)) continue;
            if (start <= line) { target = els[i]; }
            else { break; }
          }
          if (target) { target.scrollIntoView({ block: 'start', behavior: 'auto' }); }
        }

        function scrollToFraction(frac) {
          var h = document.body.scrollHeight - window.innerHeight;
          window.scrollTo(0, Math.max(0, h) * Math.max(0, Math.min(1, frac)));
        }
        </script>
        </body>
        </html>
        """
    }

    /// The bundled default preview stylesheet (P1), used by the `page(theme:)` overload.
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
