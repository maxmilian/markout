import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    var text: String

    init(text: String = "") {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [UTType("net.daringfireball.markdown")!, .plainText] }
    static var writableContentTypes: [UTType] { [UTType("net.daringfireball.markdown")!] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = Self.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Self.encode(text))
    }

    /// Serializes document text to UTF-8 file bytes. Used by `fileWrapper(configuration:)`.
    static func encode(_ text: String) -> Data {
        Data(text.utf8)
    }

    /// Decodes file bytes to document text. UTF-8 with a lenient fallback for
    /// malformed input. Used by `init(configuration:)`.
    static func decode(_ data: Data) -> String {
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(decoding: data, as: UTF8.self)
    }
}
