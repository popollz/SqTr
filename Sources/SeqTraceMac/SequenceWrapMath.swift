import Foundation

enum SequenceWrapMath {
    /// Inserts newlines every `lineLength` characters (used for sequence display; not MainActor-isolated).
    static func wrapText(_ s: String, lineLength: Int) -> String {
        guard lineLength > 10 else { return s }
        var out: [String] = []
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: lineLength, limitedBy: s.endIndex) ?? s.endIndex
            out.append(String(s[i..<j]))
            i = j
        }
        return out.joined(separator: "\n")
    }

    static func wrappedToLinear(_ wrapped: String, affectedRange: NSRange) -> (Int, Int) {
        let ns = wrapped as NSString
        let start = offsetExcludingNewlines(in: ns, utf16Location: affectedRange.location)
        let end = offsetExcludingNewlines(in: ns, utf16Location: affectedRange.location + affectedRange.length)
        return (start, max(0, end - start))
    }

    static func offsetExcludingNewlines(in ns: NSString, utf16Location: Int) -> Int {
        let len = min(utf16Location, ns.length)
        let prefix = ns.substring(to: len)
        return prefix.filter { $0 != "\n" }.count
    }

    static func wrappedRange(fromUnwrapped unwrapped: NSRange, in wrapped: String) -> NSRange {
        guard unwrapped.location != NSNotFound else {
            return NSRange(location: 0, length: 0)
        }
        let start = utf16Offset(in: wrapped, linearIndex: unwrapped.location)
        if unwrapped.length == 0 {
            return NSRange(location: start, length: 0)
        }
        let end = utf16Offset(in: wrapped, linearIndex: unwrapped.location + unwrapped.length)
        return NSRange(location: start, length: max(0, end - start))
    }

    static func utf16Offset(in wrapped: String, linearIndex: Int) -> Int {
        guard linearIndex > 0 else { return 0 }
        let ns = wrapped as NSString
        var linear = 0
        var u = 0
        while u < ns.length, linear < linearIndex {
            let ch = ns.character(at: u)
            if ch != 10 { linear += 1 }
            u += 1
        }
        return u
    }

    static func linearRange(fromWrappedSelection wr: NSRange, in wrapped: String) -> NSRange {
        let ns = wrapped as NSString
        let loc = offsetExcludingNewlines(in: ns, utf16Location: wr.location)
        let end = offsetExcludingNewlines(in: ns, utf16Location: wr.location + wr.length)
        return NSRange(location: loc, length: max(0, end - loc))
    }
}
