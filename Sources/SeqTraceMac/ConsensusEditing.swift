import Foundation

/// One consensus character aligned to an alignment column (pair / contig view).
struct ConsensusCell: Equatable {
    var column: Int
    var base: Character
}

extension Array where Element == ConsensusCell {
    mutating func applyLinearEdit(location: Int, length: Int, replacement: String) {
        let replStr = replacement.replacingOccurrences(of: "\n", with: "").uppercased()
        let replChars: [Character] = replStr.map { $0 }
        let loc = Swift.max(0, Swift.min(location, count))
        let len = Swift.max(0, Swift.min(length, count - loc))

        if len == 0, !replChars.isEmpty {
            return
        }

        if replChars.isEmpty, len > 0 {
            removeSubrange(loc..<(loc + len))
            return
        }

        if replChars.count == len {
            for i in 0..<len {
                self[loc + i].base = normalizeConsensusBase(replChars[i])
            }
            return
        }

        if replChars.count < len {
            for i in 0..<replChars.count {
                self[loc + i].base = normalizeConsensusBase(replChars[i])
            }
            let deleteExtra = len - replChars.count
            let delStart = loc + replChars.count
            removeSubrange(delStart..<(delStart + deleteExtra))
            return
        }

        for i in 0..<len {
            self[loc + i].base = normalizeConsensusBase(replChars[i])
        }
        var insertAt = loc + len
        for ch in replChars.dropFirst(len) {
            let col = self[safe: insertAt - 1]?.column ?? self[safe: insertAt]?.column ?? 0
            insert(ConsensusCell(column: col, base: normalizeConsensusBase(ch)), at: insertAt)
            insertAt += 1
        }
    }
}

private func normalizeConsensusBase(_ c: Character) -> Character {
    let u = String(c).uppercased()
    guard let f = u.first else { return "N" }
    return ["A", "C", "G", "T"].contains(String(f)) ? f : "N"
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
