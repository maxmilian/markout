import Foundation

/// What "Reload from Disk" should do, given the file's current bytes and the editor's buffer.
///
/// Pure so it can be unit-tested; `ContentView.reloadFromDisk` supplies the I/O and the alert.
enum ReloadDecision: Equatable {
    /// The file could not be read (missing, unreadable, or the document was never saved).
    case unreadable
    /// Disk and buffer already agree — nothing to do.
    case upToDate
    /// Only the file changed; the associated value is the text to load.
    case reload(String)
    /// Both sides changed: the file differs *and* the buffer has unsaved edits. Reloading would
    /// discard those edits, so the caller must confirm first. The associated value is the disk text.
    case conflict(String)

    static func evaluate(diskText: String?, bufferText: String, hasUnsavedChanges: Bool) -> ReloadDecision {
        guard let diskText else { return .unreadable }
        if diskText == bufferText { return .upToDate }
        return hasUnsavedChanges ? .conflict(diskText) : .reload(diskText)
    }
}
