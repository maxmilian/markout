import Foundation

/// 純選取轉換的回傳值：轉換後的完整文字，以及調整後的選取範圍。
struct FormatResult: Equatable {
    let text: String
    let selection: NSRange
}

/// 純函式的 Markdown 選取轉換工具。
///
/// 所有函式皆為 total：任何輸入都不會 crash（越界的 NSRange 會被夾到合法範圍）。
/// 一律以 `NSString` / `NSRange` 操作（UTF-16 offset），避免 String.Index 換算錯亂。
enum MarkdownFormatter {

    // MARK: - Wrap toggles

    static func toggleBold(text: String, selection: NSRange) -> FormatResult {
        toggleWrap(text: text, selection: selection, marker: "**")
    }

    static func toggleItalic(text: String, selection: NSRange) -> FormatResult {
        toggleWrap(text: text, selection: selection, marker: "*")
    }

    static func toggleInlineCode(text: String, selection: NSRange) -> FormatResult {
        toggleWrap(text: text, selection: selection, marker: "`")
    }

    /// 包上 / 剝掉標記的共用邏輯。
    ///
    /// 偵測邏輯：取出選取範圍子字串，若其頭尾皆為 `marker`（且長度足夠容納兩個 marker）
    /// 則視為「已包住」→ 移除頭尾標記（unwrap）；否則包上標記（wrap）。
    ///
    /// selection 調整：
    /// - wrap：可見文字往後位移一個 marker 長度，故 location += markerLen、length 不變。
    /// - unwrap：可見文字往前位移一個 marker 長度，故 location -= markerLen（夾到 >= 0）、
    ///   length 縮掉兩個 marker（夾到 >= 0）。
    private static func toggleWrap(text: String, selection: NSRange, marker: String) -> FormatResult {
        let ns = text as NSString
        let range = clamp(selection, length: ns.length)
        let markerLen = (marker as NSString).length
        let selected = ns.substring(with: range)

        let isWrapped = selected.count >= 2 * marker.count
            && selected.hasPrefix(marker)
            && selected.hasSuffix(marker)

        if isWrapped {
            // 剝掉頭尾標記
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            let newText = ns.replacingCharacters(in: range, with: inner)
            let newLoc = max(0, range.location - markerLen)
            let newLen = max(0, range.length - 2 * markerLen)
            return FormatResult(text: newText, selection: NSRange(location: newLoc, length: newLen))
        } else {
            let wrapped = marker + selected + marker
            let newText = ns.replacingCharacters(in: range, with: wrapped)
            let newLoc = range.location + markerLen
            return FormatResult(text: newText, selection: NSRange(location: newLoc, length: range.length))
        }
    }

    // MARK: - Line-prefix ops

    /// 對 selection 所在行，移除既有 `^#{1,6}\s` 前綴後，加上 `level` 個 `#` + 空白。
    static func setHeading(text: String, level: Int, selection: NSRange) -> FormatResult {
        let clampedLevel = min(max(level, 1), 6)
        let hashes = String(repeating: "#", count: clampedLevel) + " "
        return editLine(text: text, selection: selection) { line in
            let stripped = stripLeadingHeading(line)
            return hashes + stripped
        }
    }

    /// 行首 `- ` toggle：已有則移除，沒有則加上。
    static func toggleList(text: String, selection: NSRange) -> FormatResult {
        toggleLinePrefix(text: text, selection: selection, prefix: "- ")
    }

    /// 行首 `> ` toggle：已有則移除，沒有則加上。
    static func toggleBlockquote(text: String, selection: NSRange) -> FormatResult {
        toggleLinePrefix(text: text, selection: selection, prefix: "> ")
    }

    private static func toggleLinePrefix(text: String, selection: NSRange, prefix: String) -> FormatResult {
        editLine(text: text, selection: selection) { line in
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
            } else {
                return prefix + line
            }
        }
    }

    // MARK: - Link

    /// selection 非空 → `[選取文字](url)`；selection 空 → `[](url)`。
    static func makeLink(text: String, url: String, selection: NSRange) -> FormatResult {
        let ns = text as NSString
        let range = clamp(selection, length: ns.length)
        let selected = ns.substring(with: range)
        let replacement = "[\(selected)](\(url))"
        let newText = ns.replacingCharacters(in: range, with: replacement)
        // 讓可見文字（連結標題）維持被選取：跳過開頭的 "["
        let newLoc = range.location + 1
        return FormatResult(text: newText, selection: NSRange(location: newLoc, length: range.length))
    }

    // MARK: - Helpers

    /// 把可能越界的 NSRange 夾到 `[0, length]`，確保 total（不 crash）。
    private static func clamp(_ range: NSRange, length: Int) -> NSRange {
        let loc = min(max(range.location, 0), length)
        let len = min(max(range.length, 0), length - loc)
        return NSRange(location: loc, length: len)
    }

    /// 找出 selection.location 所在行的行範圍，套用 transform 後回寫。
    /// selection 調整：以行首為錨點，把選取平移到轉換後的行首（維持零長度游標於行首之後）。
    private static func editLine(text: String, selection: NSRange, transform: (String) -> String) -> FormatResult {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)
        let lineRange = ns.lineRange(for: NSRange(location: clamped.location, length: 0))
        // lineRange 含換行字元；只轉換行內容、保留尾端換行。
        let lineWithTerminator = ns.substring(with: lineRange)
        let (content, terminator) = splitTerminator(lineWithTerminator)
        let newContent = transform(content)
        let newLine = newContent + terminator
        let newText = ns.replacingCharacters(in: lineRange, with: newLine)
        // 游標放到轉換後行首（lineRange.location），維持原長度但夾到新文字範圍。
        let newLength = (newText as NSString).length
        let loc = min(lineRange.location, newLength)
        let len = min(clamped.length, newLength - loc)
        return FormatResult(text: newText, selection: NSRange(location: loc, length: len))
    }

    /// 拆出行內容與尾端換行（\n / \r\n / \r）。
    private static func splitTerminator(_ line: String) -> (content: String, terminator: String) {
        if line.hasSuffix("\r\n") {
            return (String(line.dropLast(2)), "\r\n")
        } else if line.hasSuffix("\n") {
            return (String(line.dropLast(1)), "\n")
        } else if line.hasSuffix("\r") {
            return (String(line.dropLast(1)), "\r")
        }
        return (line, "")
    }

    /// 移除行首的 `#{1,6}` 加後續空白（若有）。
    private static func stripLeadingHeading(_ line: String) -> String {
        var idx = line.startIndex
        var hashCount = 0
        while idx < line.endIndex, line[idx] == "#", hashCount < 6 {
            hashCount += 1
            idx = line.index(after: idx)
        }
        guard hashCount > 0 else { return line }
        // 吃掉標記後的空白
        while idx < line.endIndex, line[idx] == " " || line[idx] == "\t" {
            idx = line.index(after: idx)
        }
        return String(line[idx...])
    }
}
