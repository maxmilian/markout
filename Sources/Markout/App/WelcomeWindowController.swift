import AppKit
import SwiftUI

/// Owns the welcome window.
///
/// It is an AppKit window rather than a SwiftUI `Window` scene because the app delegate has to open
/// it at launch, and macOS 14 has no supported way to open a scene from there.
@MainActor
final class WelcomeWindowController {
    static let shared = WelcomeWindowController()

    private var window: NSWindow?

    func show() {
        // Re-read the list on every show. Whether a row is dimmed, and the relative time it
        // displays, are computed while drawing — and nothing tells the app when a recorded file is
        // renamed or deleted behind its back. Reassigning `entries` republishes even when the
        // contents are unchanged, which is what forces the redraw.
        RecentDocumentsStore.shared.reload()

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = WelcomeView(
            store: RecentDocumentsStore.shared,
            onOpen: { [weak self] url in
                // Open first, close second: if the file vanished between drawing the list and the
                // click, the welcome window must stay where it is rather than flicker away and back.
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { document, _, error in
                    guard error == nil else {
                        RecentDocumentsStore.shared.reload()
                        return
                    }
                    // Recording here (not only in ContentView) also refreshes `openedAt` when the
                    // document was already open: the document controller just presents its
                    // existing window, so no new ContentView task fires.
                    if let fileURL = document?.fileURL {
                        RecentDocumentsStore.shared.record(fileURL)
                    }
                    self?.close()
                }
            },
            onNewDocument: { [weak self] in
                self?.close()
                NSDocumentController.shared.newDocument(nil)
            },
            onOpenPanel: {
                NSDocumentController.shared.openDocument(nil)
            })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Welcome to Markout"
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func close() {
        window?.close()
    }
}
