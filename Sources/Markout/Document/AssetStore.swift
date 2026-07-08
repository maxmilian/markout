import AppKit

/// Saves pasted/dropped images into an `assets/` folder beside the document.
///
/// `uniqueName` (the collision-safe naming) is pure and unit-tested; `save` is the thin file-writing
/// edge. When the document is unsaved (`docURL == nil`), images go to a temp folder and an absolute
/// `file:` URL is returned so the caller can prompt the user to save.
enum AssetStore {
    enum AssetError: Error { case encodingFailed }

    /// A filename that does not collide with `existing`, sanitizing `base` and suffixing `-1`, `-2`, …
    static func uniqueName(base: String, ext: String, existing: Set<String>) -> String {
        let stem = sanitize(base)
        var candidate = "\(stem).\(ext)"
        if !existing.contains(candidate) { return candidate }
        var i = 1
        while true {
            candidate = "\(stem)-\(i).\(ext)"
            if !existing.contains(candidate) { return candidate }
            i += 1
        }
    }

    /// Writes `image` as PNG beside the document; returns the path/URL to embed in Markdown.
    @discardableResult
    static func save(_ image: NSImage, forDocumentAt docURL: URL?, preferredName: String?) throws -> String {
        guard let png = pngData(image) else { throw AssetError.encodingFailed }
        let base = preferredName ?? "image"

        if let docURL {
            let dir = docURL.deletingLastPathComponent().appendingPathComponent("assets")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            let name = uniqueName(base: base, ext: "png", existing: existing)
            try png.write(to: dir.appendingPathComponent(name))
            return "assets/\(name)"
        } else {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("markout-assets")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            let name = uniqueName(base: base, ext: "png", existing: existing)
            let url = dir.appendingPathComponent(name)
            try png.write(to: url)
            return url.absoluteString
        }
    }

    // MARK: - Helpers

    private static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func sanitize(_ base: String) -> String {
        var out = ""
        var lastHyphen = false
        for scalar in base.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                out.unicodeScalars.append(scalar)
                lastHyphen = false
            } else if !lastHyphen {
                out.append("-")
                lastHyphen = true
            }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "image" : trimmed
    }
}
