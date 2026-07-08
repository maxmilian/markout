import Foundation

/// A named preview stylesheet. `css` is embedded into the preview `HTMLTemplate`.
struct PreviewTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let css: String
}

/// Loads bundled and user-supplied preview CSS themes.
enum PreviewThemeStore {
    /// Themes shipped in the app bundle under `PreviewAssets/themes/*.css`.
    static var bundled: [PreviewTheme] {
        guard let directory = Bundle.main.url(
            forResource: "themes", withExtension: nil, subdirectory: "PreviewAssets")
        else { return [] }
        return themes(inDirectory: directory)
    }

    /// Loads every `*.css` file in `url` as a `PreviewTheme`, sorted by filename.
    static func themes(inDirectory url: URL) -> [PreviewTheme] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil)
        else { return [] }

        return entries
            .filter { $0.pathExtension.lowercased() == "css" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { fileURL in
                guard let css = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
                let id = fileURL.deletingPathExtension().lastPathComponent
                return PreviewTheme(id: id, name: prettify(id), css: css)
            }
    }

    /// Looks up a bundled theme by id.
    static func theme(id: String) -> PreviewTheme? {
        bundled.first { $0.id == id }
    }

    /// Loads a user-supplied stylesheet file as a theme; nil if unreadable.
    static func custom(fromFileURL url: URL) -> PreviewTheme? {
        guard let css = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let id = "custom:" + url.deletingPathExtension().lastPathComponent
        return PreviewTheme(id: id, name: url.deletingPathExtension().lastPathComponent, css: css)
    }

    /// "github-dark-dimmed" -> "Github Dark Dimmed".
    private static func prettify(_ id: String) -> String {
        id.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
