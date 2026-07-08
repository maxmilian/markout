import SwiftUI
import AppKit
import WebKit
import UniformTypeIdentifiers

/// Weak references to the AppKit views the menu commands need to act on.
final class EditorBridge: ObservableObject {
    weak var textView: MarkoutTextView?
    weak var webView: WKWebView?
}

struct ContentView: View {
    @Binding var document: MarkdownDocument
    var documentURL: URL? = nil

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("previewThemeID") private var previewThemeID = "github"

    @StateObject private var bridge = EditorBridge()
    @State private var renderedHTML: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var previewScrollLine: Int?
    @State private var showContents = false

    private var activeTheme: PreviewTheme {
        PreviewThemeStore.theme(id: previewThemeID)
            ?? PreviewThemeStore.theme(id: "default")
            ?? PreviewTheme(id: "default", name: "Default", css: HTMLTemplate.css)
    }

    var body: some View {
        HSplitView {
            if showContents {
                contentsSidebar
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
            }
            EditorView(
                text: $document.text,
                onVisibleLineChange: { previewScrollLine = $0 },
                documentURL: documentURL,
                onEditorReady: { bridge.textView = $0 }
            )
            .frame(minWidth: 320)
            PreviewView(
                htmlBody: renderedHTML,
                isDark: colorScheme == .dark,
                previewCSS: activeTheme.css,
                scrollLine: previewScrollLine,
                onWebViewReady: { bridge.webView = $0 }
            )
            .frame(minWidth: 320)
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showContents.toggle()
                } label: {
                    Label("Contents", systemImage: "list.bullet.indent")
                }
            }
            ToolbarItem(placement: .automatic) {
                Picker("Preview Theme", selection: $previewThemeID) {
                    ForEach(PreviewThemeStore.bundled) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .focusedSceneValue(\.documentActions, DocumentActions(
            exportHTML: exportHTML,
            exportPDF: exportPDF,
            insertTableOfContents: insertTableOfContents
        ))
        .onAppear { render(document.text) }
        .onChange(of: document.text) { _, newValue in scheduleRender(newValue) }
    }

    // MARK: - Table of contents sidebar

    private var contentsSidebar: some View {
        let located = TableOfContents.located(in: body(of: document.text))
        return List(located.indices, id: \.self) { i in
            let item = located[i]
            Button {
                previewScrollLine = item.line
            } label: {
                Text(item.heading.text)
                    .padding(.leading, CGFloat(item.heading.level - 1) * 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Rendering

    private func scheduleRender(_ markdown: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            render(markdown)
        }
    }

    /// P3 pipeline: strip front matter, then P2's protect-math → render → reinsert.
    private func render(_ markdown: String) {
        let body = body(of: markdown)
        let (protected, spans) = MathExtractor.extract(body)
        let raw = MarkdownRenderer.renderHTMLBody(protected, options: .init(sourcePositions: true))
        renderedHTML = MathExtractor.reinsert(raw, spans: spans)
    }

    private func body(of markdown: String) -> String {
        FrontMatterParser.split(markdown).body
    }

    // MARK: - Actions

    private var exportTitle: String {
        if let title = FrontMatterParser.split(document.text).front?.values["title"], !title.isEmpty {
            return title
        }
        return documentURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
    }

    private func suggestedName(ext: String) -> String {
        let base = documentURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        return "\(base).\(ext)"
    }

    private func exportHTML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = suggestedName(ext: "html")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let html = HTMLExporter.standaloneHTML(
            body: renderedHTML, css: activeTheme.css, title: exportTitle)
        try? Data(html.utf8).write(to: url)
    }

    private func exportPDF() {
        guard let webView = bridge.webView else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName(ext: "pdf")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { try? await PDFExporter.export(from: webView, to: url) }
    }

    private func insertTableOfContents() {
        let headings = TableOfContents.headings(in: body(of: document.text))
        guard !headings.isEmpty else { return }
        let list = TableOfContents.markdownList(headings) + "\n"
        if let textView = bridge.textView {
            textView.insertText(list, replacementRange: textView.selectedRange())
        } else {
            document.text = list + "\n" + document.text
        }
    }
}
