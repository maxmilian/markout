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
    @AppStorage(SettingsKey.previewThemeID) private var previewThemeID = SettingsDefault.previewThemeID
    @AppStorage(SettingsKey.editorFontSize) private var editorFontSize = SettingsDefault.editorFontSize
    @AppStorage(SettingsKey.editorAppearance) private var editorAppearance = SettingsDefault.editorAppearance
    @AppStorage(SettingsKey.previewAppearance) private var previewAppearance = SettingsDefault.previewAppearance
    @AppStorage(SettingsKey.softWrap) private var softWrap = SettingsDefault.softWrap
    @AppStorage(SettingsKey.showWordCount) private var showWordCount = SettingsDefault.showWordCount
    @AppStorage(SettingsKey.showLineNumbers) private var showLineNumbers = SettingsDefault.showLineNumbers
    @AppStorage(SettingsKey.customPreviewCSSPath) private var customPreviewCSSPath = SettingsDefault.customPreviewCSSPath

    @StateObject private var bridge = EditorBridge()
    @State private var renderedHTML: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var previewScrollLine: Int?
    @State private var showContents = false

    /// A toolbar menu offering System / Light / Dark for one pane. `glyph` distinguishes the
    /// editor menu from the preview menu; the checkmark in the menu shows the current mode.
    private func appearanceMenu(title: String, glyph: String, selection: Binding<String>) -> some View {
        Menu {
            Picker(title, selection: selection) {
                Label("System", systemImage: "circle.lefthalf.filled").tag(AppearanceMode.system.rawValue)
                Label("Light", systemImage: "sun.max").tag(AppearanceMode.light.rawValue)
                Label("Dark", systemImage: "moon").tag(AppearanceMode.dark.rawValue)
            }
            .pickerStyle(.inline)
        } label: {
            Label(title, systemImage: glyph)
        }
        .help(title)
    }

    private var activeTheme: PreviewTheme {
        if previewThemeID == customPreviewThemeID, !customPreviewCSSPath.isEmpty,
           let custom = PreviewThemeStore.custom(
            fromFileURL: URL(fileURLWithPath: customPreviewCSSPath)) {
            return custom
        }
        return PreviewThemeStore.theme(id: previewThemeID)
            ?? PreviewThemeStore.theme(id: "default")
            ?? PreviewTheme(id: "default", name: "Default", css: HTMLTemplate.css)
    }

    private var systemIsDark: Bool { colorScheme == .dark }

    private var editorIsDark: Bool {
        AppearanceResolver.isDark(
            mode: AppearanceMode(rawValue: editorAppearance) ?? .system,
            systemIsDark: systemIsDark)
    }

    private var previewIsDark: Bool {
        AppearanceResolver.isDark(
            mode: AppearanceMode(rawValue: previewAppearance) ?? .system,
            systemIsDark: systemIsDark)
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                if showContents {
                    contentsSidebar
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
                }
                EditorView(
                    text: $document.text,
                    onVisibleLineChange: { previewScrollLine = $0 },
                    documentURL: documentURL,
                    onEditorReady: { bridge.textView = $0 },
                    fontSize: editorFontSize,
                    editorThemeID: AppearanceResolver.editorThemeID(isDark: editorIsDark),
                    softWrap: softWrap,
                    showLineNumbers: showLineNumbers
                )
                .frame(minWidth: 320)
                PreviewView(
                    htmlBody: renderedHTML,
                    isDark: previewIsDark,
                    previewCSS: activeTheme.css,
                    scrollLine: previewScrollLine,
                    onWebViewReady: { bridge.webView = $0 }
                )
                .frame(minWidth: 320)
            }
            if showWordCount {
                statusBar
            }
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
            ToolbarItemGroup(placement: .automatic) {
                Button { applyFormat(.bold) } label: { Image(systemName: "bold") }
                    .help("Bold (⌘B)")
                Button { applyFormat(.italic) } label: { Image(systemName: "italic") }
                    .help("Italic (⌘I)")
                Button { applyFormat(.inlineCode) } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                    .help("Inline code")
                Button { applyFormat(.heading(2)) } label: { Image(systemName: "number") }
                    .help("Heading")
                Button { applyFormat(.blockquote) } label: { Image(systemName: "text.quote") }
                    .help("Blockquote")
                Button { applyFormat(.list) } label: { Image(systemName: "list.bullet") }
                    .help("List")
                Button { applyFormat(.link) } label: { Image(systemName: "link") }
                    .help("Link (⌘K)")
            }
            ToolbarItem(placement: .automatic) {
                appearanceMenu(
                    title: "Editor appearance", glyph: "square.lefthalf.filled",
                    selection: $editorAppearance)
            }
            ToolbarItem(placement: .automatic) {
                appearanceMenu(
                    title: "Preview appearance", glyph: "eye",
                    selection: $previewAppearance)
            }
        }
        .focusedSceneValue(\.documentActions, DocumentActions(
            exportHTML: exportHTML,
            exportPDF: exportPDF,
            insertTableOfContents: insertTableOfContents,
            format: applyFormat
        ))
        .onAppear { render(document.text) }
        .onChange(of: document.text) { _, newValue in scheduleRender(newValue) }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        let stats = DocumentStats.compute(document.text)
        return HStack(spacing: 6) {
            Spacer()
            Text("\(stats.words) words · \(stats.characters) chars · ~\(stats.readingMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.bar)
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

    /// Applies a `MarkdownFormatter` transform to the focused editor's current selection as a single
    /// undoable edit, then lets the delegate's `textDidChange` sync the binding and rehighlight.
    private func applyFormat(_ command: FormatCommand) {
        guard let textView = bridge.textView else { return }
        let text = textView.string
        let selection = textView.selectedRange()
        let result: FormatResult
        switch command {
        case .bold: result = MarkdownFormatter.toggleBold(text: text, selection: selection)
        case .italic: result = MarkdownFormatter.toggleItalic(text: text, selection: selection)
        case .inlineCode: result = MarkdownFormatter.toggleInlineCode(text: text, selection: selection)
        case .blockquote: result = MarkdownFormatter.toggleBlockquote(text: text, selection: selection)
        case .list: result = MarkdownFormatter.toggleList(text: text, selection: selection)
        case .link: result = MarkdownFormatter.makeLink(text: text, url: "https://", selection: selection)
        case .heading(let level): result = MarkdownFormatter.setHeading(text: text, level: level, selection: selection)
        }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        guard textView.shouldChangeText(in: fullRange, replacementString: result.text) else { return }
        textView.textStorage?.replaceCharacters(in: fullRange, with: result.text)
        textView.didChangeText()
        textView.setSelectedRange(result.selection)
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
