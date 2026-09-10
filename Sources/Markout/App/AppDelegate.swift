import AppKit
import SwiftUI

/// Turns "launched with nothing to open" into the welcome window.
///
/// SwiftUI's `DocumentGroup` insists on starting a document at launch and does not consult
/// `applicationShouldOpenUntitledFile`, so the blank document is closed right after it appears.
/// Documents opened from Finder, the CLI, or state restoration are present by then and are left
/// alone — the welcome window only appears when no document survives this check.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// How long to wait for `DocumentGroup` to create its launch document. Measured at ~0.3 s.
    private let launchSettleDelay: TimeInterval = 0.3

    override init() {
        super.init()
        UserDefaults.standard.register(
            defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + launchSettleDelay) {
            let controller = NSDocumentController.shared
            for document in controller.documents
            where document.fileURL == nil
                && !document.isDocumentEdited
                // An unsaved document restored from autosave also has no file URL and a clean
                // change count. It holds the user's work and must survive.
                && document.autosavedContentsFileURL == nil {
                document.close()
            }
            if controller.documents.isEmpty {
                WelcomeWindowController.shared.show()
            }
        }
    }

    /// The unit tests are hosted by this app, so launching them runs this delegate. Without this
    /// guard a welcome window pops up mid-test and steals focus. Swift Testing does not reliably
    /// set XCTest's own environment keys, so probe for the XCTest class too.
    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    /// Clicking the Dock icon with no windows open lands on the welcome window rather than nothing.
    /// Returns false — AppKit's documentation makes false mean "the app handled the reopen itself";
    /// returning true would let it run the default handling, which for a document-based app with no
    /// visible windows is opening a new untitled document on top of the welcome window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !Self.isRunningTests,
              !hasVisibleWindows, NSDocumentController.shared.documents.isEmpty else { return true }
        WelcomeWindowController.shared.show()
        return false
    }
}
