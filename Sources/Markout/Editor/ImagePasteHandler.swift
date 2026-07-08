import AppKit

/// Turns a pasted/dropped image into a Markdown image link, saving the bytes beside the document.
enum ImagePasteHandler {
    /// Saves `image` via `AssetStore` and returns `![](path)` to insert at the caret.
    static func markdownLink(for image: NSImage, documentURL: URL?) throws -> String {
        let path = try AssetStore.save(image, forDocumentAt: documentURL, preferredName: nil)
        return "![](\(path))"
    }
}
