import AppKit
import SwiftUI

let markoutDocumentTabbingIdentifier = NSWindow.TabbingIdentifier("tech.ankey.Markout.document")

/// Joins each new document window into Markout's single tab group.
///
/// `DocumentGroup` gives every document its own window. Setting `tabbingMode` on a window that
/// already exists is too late to group it, so the new window explicitly adds itself as a tab of an
/// existing document window. Everything else — the tab bar, ⌘⇧[ / ⌘⇧], drag-out, Merge All
/// Windows — is then handled by AppKit.
struct WindowTabbingAccessor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        /// Set once this window has joined a tab group, so later re-renders — which fire on every
        /// keystroke — neither rescan for a host nor re-merge a tab the user dragged out.
        var joined = false
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    /// The view has no window during `makeNSView`, and there is no callback for gaining one, so the
    /// attempt is repeated from `updateNSView` until it succeeds once. A fresh window can already
    /// carry a non-nil `tabGroup` (it may even be a lone group after a drag-out), so "has this
    /// window ever joined?" is tracked in the coordinator rather than inferred from `tabGroup`.
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { joinTabGroup(from: nsView, context: context) }
    }

    private func joinTabGroup(from view: NSView, context: Context) {
        guard !context.coordinator.joined else { return }
        guard let window = view.window else { return }
        window.tabbingMode = .preferred
        window.tabbingIdentifier = markoutDocumentTabbingIdentifier

        guard let host = tabHost(for: window) else { return }
        context.coordinator.joined = true
        host.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
    }

    /// The window whose tab group the new document should join.
    ///
    /// Preferring the key (then main) window keeps a new document in the group the user is working
    /// in, and on that group's screen. Falling back to any document window would drop it into an
    /// arbitrary group — including one the user just deliberately dragged out.
    private func tabHost(for window: NSWindow) -> NSWindow? {
        func isCandidate(_ candidate: NSWindow) -> Bool {
            candidate !== window
                && candidate.tabbingIdentifier == markoutDocumentTabbingIdentifier
                && candidate.isVisible
                && candidate.tabGroup !== window.tabGroup
        }

        if let key = NSApp.keyWindow, isCandidate(key) { return key }
        if let main = NSApp.mainWindow, isCandidate(main) { return main }
        return NSApp.windows.first(where: isCandidate)
    }
}
