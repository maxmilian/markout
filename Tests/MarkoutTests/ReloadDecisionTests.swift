import Testing
@testable import Markout

struct ReloadDecisionTests {
    @Test func unreadableFileReportsUnreadable() {
        let decision = ReloadDecision.evaluate(diskText: nil, bufferText: "a", hasUnsavedChanges: false)
        #expect(decision == .unreadable)
    }

    @Test func identicalContentIsUpToDate() {
        let decision = ReloadDecision.evaluate(diskText: "same", bufferText: "same", hasUnsavedChanges: false)
        #expect(decision == .upToDate)
    }

    /// Even with the dirty flag set, matching bytes mean there is nothing to reload — this is the
    /// state right after a save, so it must not be reported as a conflict.
    @Test func identicalContentIsUpToDateEvenWhenDirty() {
        let decision = ReloadDecision.evaluate(diskText: "same", bufferText: "same", hasUnsavedChanges: true)
        #expect(decision == .upToDate)
    }

    @Test func externalChangeWithCleanBufferReloads() {
        let decision = ReloadDecision.evaluate(diskText: "new", bufferText: "old", hasUnsavedChanges: false)
        #expect(decision == .reload("new"))
    }

    @Test func externalChangeWithUnsavedEditsConflicts() {
        let decision = ReloadDecision.evaluate(diskText: "new", bufferText: "mine", hasUnsavedChanges: true)
        #expect(decision == .conflict("new"))
    }
}
