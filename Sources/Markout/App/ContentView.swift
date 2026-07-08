import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("previewThemeID") private var previewThemeID = "github"

    @State private var renderedHTML: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var previewScrollLine: Int?

    private var activeTheme: PreviewTheme {
        PreviewThemeStore.theme(id: previewThemeID)
            ?? PreviewThemeStore.theme(id: "default")
            ?? PreviewTheme(id: "default", name: "Default", css: HTMLTemplate.css)
    }

    var body: some View {
        HSplitView {
            EditorView(text: $document.text, onVisibleLineChange: { line in
                previewScrollLine = line
            })
            .frame(minWidth: 320)
            PreviewView(
                htmlBody: renderedHTML,
                isDark: colorScheme == .dark,
                previewCSS: activeTheme.css,
                scrollLine: previewScrollLine
            )
            .frame(minWidth: 320)
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Preview Theme", selection: $previewThemeID) {
                    ForEach(PreviewThemeStore.bundled) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .onAppear { render(document.text) }
        .onChange(of: document.text) { _, newValue in
            scheduleRender(newValue)
        }
    }

    private func scheduleRender(_ markdown: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            render(markdown)
        }
    }

    /// P2 pipeline: protect math → render GFM (with source positions) → reinsert math for KaTeX.
    private func render(_ markdown: String) {
        let (protected, spans) = MathExtractor.extract(markdown)
        let raw = MarkdownRenderer.renderHTMLBody(protected, options: .init(sourcePositions: true))
        renderedHTML = MathExtractor.reinsert(raw, spans: spans)
    }
}
