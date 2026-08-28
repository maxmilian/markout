import Foundation
import Testing
@testable import Markout

struct LinkPolicyTests {
    let bundle = URL(fileURLWithPath: "/Applications/Markout.app/Contents/Resources", isDirectory: true)
    let document = URL(fileURLWithPath: "/Users/me/notes/index.md")

    @Test func httpLinkOpensExternally() {
        let url = URL(string: "https://example.com/page")!
        #expect(LinkPolicy.action(for: url, isLinkActivation: true, baseURL: bundle, documentURL: document)
                == .openExternally(url))
    }

    @Test func mailtoOpensExternally() {
        let url = URL(string: "mailto:someone@example.com")!
        #expect(LinkPolicy.action(for: url, isLinkActivation: true) == .openExternally(url))
    }

    @Test func nonLinkNavigationIsAllowed() {
        let url = URL(string: "https://example.com")!
        #expect(LinkPolicy.action(for: url, isLinkActivation: false, baseURL: bundle) == .allow)
    }

    @Test func inPageAnchorStaysInPreview() {
        let anchor = URL(string: "#section", relativeTo: bundle)!.absoluteURL
        #expect(LinkPolicy.action(for: anchor, isLinkActivation: true, baseURL: bundle, documentURL: document)
                == .allow)
    }

    @Test func relativeMarkdownResolvesNextToTheDocument() {
        let url = URL(string: "other.md", relativeTo: bundle)!.absoluteURL
        let expected = URL(fileURLWithPath: "/Users/me/notes/other.md")
        #expect(LinkPolicy.action(for: url, isLinkActivation: true, baseURL: bundle, documentURL: document)
                == .openDocument(expected))
    }

    @Test func relativeSubfolderMarkdownResolvesNextToTheDocument() {
        let url = URL(string: "sub/deep.markdown", relativeTo: bundle)!.absoluteURL
        let expected = URL(fileURLWithPath: "/Users/me/notes/sub/deep.markdown")
        #expect(LinkPolicy.action(for: url, isLinkActivation: true, baseURL: bundle, documentURL: document)
                == .openDocument(expected))
    }

    @Test func relativeNonMarkdownFileGoesToTheSystem() {
        let url = URL(string: "spec.pdf", relativeTo: bundle)!.absoluteURL
        let expected = URL(fileURLWithPath: "/Users/me/notes/spec.pdf")
        #expect(LinkPolicy.action(for: url, isLinkActivation: true, baseURL: bundle, documentURL: document)
                == .openExternally(expected))
    }

    @Test func absoluteMarkdownPathOpensAsDocument() {
        let url = URL(fileURLWithPath: "/Users/me/elsewhere/todo.md")
        #expect(LinkPolicy.action(for: url, isLinkActivation: true, baseURL: bundle, documentURL: document)
                == .openDocument(url))
    }

    @Test func unsavedDocumentKeepsTheBundleRelativeURL() {
        let url = URL(string: "other.md", relativeTo: bundle)!.absoluteURL
        #expect(LinkPolicy.action(for: url, isLinkActivation: true, baseURL: bundle, documentURL: nil)
                == .openDocument(url.standardizedFileURL))
    }

    @Test func missingURLIsCancelled() {
        #expect(LinkPolicy.action(for: nil, isLinkActivation: true, baseURL: bundle) == .cancel)
    }
}
