import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @Environment(\.colorScheme) private var colorScheme

    @State private var renderedHTML: String = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        HSplitView {
            EditorView(text: $document.text)
                .frame(minWidth: 320)
            PreviewView(htmlBody: renderedHTML, isDark: colorScheme == .dark)
                .frame(minWidth: 320)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear { render(document.text) }
        .onChange(of: document.text) { _, newValue in
            scheduleRender(newValue)
        }
    }

    private func scheduleRender(_ markdown: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            render(markdown)
        }
    }

    private func render(_ markdown: String) {
        renderedHTML = MarkdownRenderer.renderHTMLBody(markdown)
    }
}
