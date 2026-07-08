import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Options controlling how `MarkdownRenderer` emits HTML.
struct RenderOptions {
    /// When true, emit `data-sourcepos="startLine:col-endLine:col"` on block elements
    /// (via `CMARK_OPT_SOURCEPOS`). Used by scroll sync to map editor lines to preview blocks.
    var sourcePositions: Bool

    init(sourcePositions: Bool = false) {
        self.sourcePositions = sourcePositions
    }

    static let `default` = RenderOptions()
}

enum MarkdownRenderer {
    private static let extensionNames = [
        "table", "strikethrough", "autolink", "tasklist", "tagfilter",
    ]

    static func renderHTMLBody(_ markdown: String, options: RenderOptions = .default) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        var cmarkOptions = CMARK_OPT_DEFAULT
        if options.sourcePositions {
            cmarkOptions |= CMARK_OPT_SOURCEPOS
        }

        guard let parser = cmark_parser_new(cmarkOptions) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        cmark_parser_feed(parser, markdown, markdown.utf8.count)
        guard let doc = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(doc) }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let htmlPtr = cmark_render_html(doc, cmarkOptions, extensions) else { return "" }
        defer { free(htmlPtr) }

        return String(cString: htmlPtr)
    }
}
