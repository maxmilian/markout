import Foundation
import cmark_gfm
import cmark_gfm_extensions

enum MarkdownRenderer {
    private static let extensionNames = [
        "table", "strikethrough", "autolink", "tasklist", "tagfilter",
    ]

    static func renderHTMLBody(_ markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        let options = CMARK_OPT_DEFAULT
        guard let parser = cmark_parser_new(options) else { return "" }
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
        guard let htmlPtr = cmark_render_html(doc, options, extensions) else { return "" }
        defer { free(htmlPtr) }

        return String(cString: htmlPtr)
    }
}
