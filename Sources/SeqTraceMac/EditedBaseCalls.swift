import Foundation

/// Editable base calls kept in lockstep with peak locations and qualities (single-trace view).
struct EditedBaseCalls: Equatable {
    var bases: [Character]
    var peakLocations: [Int]
    var qualities: [UInt8]?

    init(trace: ABITrace) {
        let raw = trace.bases ?? ""
        let peaks = trace.peakLocations ?? []
        let qIn = trace.qualities
        let n = min(raw.count, peaks.count)
        let chars = Array(raw)
        bases = Array(chars.prefix(n))
        peakLocations = Array(peaks.prefix(n))
        if let qIn, qIn.count >= n {
            qualities = Array(qIn.prefix(n))
        } else {
            qualities = nil
        }
    }

    var unwrappedString: String {
        String(bases)
    }

    /// Applies one NSTextView edit in **unwrapped** (no newlines) coordinates.
    mutating func applyLinearEdit(location: Int, length: Int, replacement: String) {
        let replStr = replacement.replacingOccurrences(of: "\n", with: "").uppercased()
        let replChars = Array(replStr)
        let loc = max(0, min(location, bases.count))
        let len = max(0, min(length, bases.count - loc))

        if len == 0, replChars.count == 1 {
            insertBase(replChars[0], at: loc)
            return
        }

        if replChars.isEmpty, len > 0 {
            bases.removeSubrange(loc..<(loc + len))
            peakLocations.removeSubrange(loc..<(loc + len))
            qualities?.removeSubrange(loc..<(loc + len))
            return
        }

        if replChars.count == len {
            for i in 0..<len {
                bases[loc + i] = normalizeBase(replChars[i])
            }
            return
        }

        if replChars.count < len {
            for i in 0..<replChars.count {
                bases[loc + i] = normalizeBase(replChars[i])
            }
            let deleteExtra = len - replChars.count
            let delStart = loc + replChars.count
            bases.removeSubrange(delStart..<(delStart + deleteExtra))
            peakLocations.removeSubrange(delStart..<(delStart + deleteExtra))
            qualities?.removeSubrange(delStart..<(delStart + deleteExtra))
            return
        }

        for i in 0..<len {
            bases[loc + i] = normalizeBase(replChars[i])
        }
        var insertAt = loc + len
        for ch in replChars.dropFirst(len) {
            insertBase(normalizeBase(ch), at: insertAt)
            insertAt += 1
        }
    }

    private mutating func insertBase(_ ch: Character, at loc: Int) {
        let peak = peakLocations[safe: loc - 1] ?? peakLocations[safe: loc] ?? peakLocations.last ?? 0
        let qInsert: UInt8 = qualities?[safe: loc - 1] ?? qualities?[safe: loc] ?? 0
        bases.insert(ch, at: loc)
        peakLocations.insert(peak, at: loc)
        qualities?.insert(qInsert, at: loc)
    }

    private func normalizeBase(_ c: Character) -> Character {
        let u = String(c).uppercased()
        guard let f = u.first else { return "N" }
        return ["A", "C", "G", "T"].contains(String(f)) ? f : "N"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
