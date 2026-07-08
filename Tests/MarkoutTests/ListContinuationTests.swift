import Testing
@testable import Markout

struct ListContinuationTests {
    @Test func continuesUnordered() {
        #expect(ListContinuation.onReturn(line: "- item")
            == ListEdit(insert: "\n- ", removeCurrentMarker: false))
    }

    @Test func continuesOrderedIncrementing() {
        #expect(ListContinuation.onReturn(line: "2. item")
            == ListEdit(insert: "\n3. ", removeCurrentMarker: false))
    }

    @Test func continuesTaskListUnchecked() {
        #expect(ListContinuation.onReturn(line: "- [x] done")
            == ListEdit(insert: "\n- [ ] ", removeCurrentMarker: false))
    }

    @Test func emptyItemTerminates() {
        #expect(ListContinuation.onReturn(line: "- ")
            == ListEdit(insert: "", removeCurrentMarker: true))
    }

    @Test func emptyTaskItemTerminates() {
        #expect(ListContinuation.onReturn(line: "- [ ] ")
            == ListEdit(insert: "", removeCurrentMarker: true))
    }

    @Test func preservesIndentation() {
        #expect(ListContinuation.onReturn(line: "  - item")
            == ListEdit(insert: "\n  - ", removeCurrentMarker: false))
    }

    @Test func nonListReturnsNil() {
        #expect(ListContinuation.onReturn(line: "plain text") == nil)
    }

    @Test func bulletWithoutSpaceIsNotList() {
        #expect(ListContinuation.onReturn(line: "-nope") == nil)
    }
}
