import Foundation

/// What the preview should do with a clicked link.
enum LinkAction: Equatable {
    /// Let the WebView navigate itself (in-page anchors, the initial template load).
    case allow
    /// Hand the URL to the system (browser, mail client, Preview…).
    case openExternally(URL)
    /// Open the file as another Markout document.
    case openDocument(URL)
    /// Swallow the navigation.
    case cancel
}

/// Decides what happens when a link in the preview is activated.
///
/// The preview is loaded with `loadHTMLString(_:baseURL: Bundle.main.resourceURL)`, so a relative
/// href in the Markdown resolves against the app bundle instead of the document's folder. Anything
/// that lands under `baseURL` is therefore re-resolved against the document's directory before it
/// is acted on.
enum LinkPolicy {
    /// Extensions that Markout opens itself rather than handing to the system.
    private static let documentExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn", "markdn", "text", "txt",
    ]

    static func action(
        for url: URL?,
        isLinkActivation: Bool,
        baseURL: URL? = nil,
        documentURL: URL? = nil
    ) -> LinkAction {
        // Template loads and script-driven navigations are not link clicks; leave them alone.
        guard isLinkActivation else { return .allow }
        guard let url else { return .cancel }
        guard url.isFileURL else {
            // http/https, mailto, tel, custom schemes — the system knows what to do with them.
            return .openExternally(url)
        }

        let relative = relativePath(of: url, under: baseURL)

        // A bare `#anchor` resolves to the base URL itself: keep it inside the preview.
        if relative?.isEmpty == true || (relative == nil && url.fragment != nil && url.path.isEmpty) {
            return url.fragment == nil ? .cancel : .allow
        }

        let target = resolve(url, relative: relative, documentURL: documentURL)
        if documentExtensions.contains(target.pathExtension.lowercased()) {
            return .openDocument(target)
        }
        return .openExternally(target)
    }

    /// The part of `url` below `baseURL`, or nil when `url` is not inside it.
    private static func relativePath(of url: URL, under baseURL: URL?) -> String? {
        guard let baseURL, baseURL.isFileURL else { return nil }
        let base = baseURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == base { return "" }
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }

    /// Re-anchors a bundle-relative href onto the document's folder; absolute paths pass through.
    private static func resolve(_ url: URL, relative: String?, documentURL: URL?) -> URL {
        guard let relative, !relative.isEmpty,
              let documentURL, documentURL.isFileURL else {
            return url.standardizedFileURL
        }
        return URL(fileURLWithPath: relative, relativeTo: documentURL.deletingLastPathComponent())
            .standardizedFileURL
    }
}
