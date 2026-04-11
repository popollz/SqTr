import Foundation

struct AlignmentResult: Sendable, Equatable {
    var alignedA: String
    var alignedB: String
    var score: Int
}

enum Aligner {
    /// Simple global alignment (Needleman–Wunsch) for DNA strings.
    /// Scoring: match=+2, mismatch=-1, gap=-2
    static func globalAlign(_ a: String, _ b: String) -> AlignmentResult {
        let aChars = Array(a)
        let bChars = Array(b)
        let n = aChars.count
        let m = bChars.count

        if n == 0 && m == 0 { return AlignmentResult(alignedA: "", alignedB: "", score: 0) }
        if n == 0 {
            return AlignmentResult(alignedA: String(repeating: "-", count: m), alignedB: b, score: -2 * m)
        }
        if m == 0 {
            return AlignmentResult(alignedA: a, alignedB: String(repeating: "-", count: n), score: -2 * n)
        }

        let match = 2
        let mismatch = -1
        let gap = -2

        // DP score matrix (n+1) x (m+1), stored row-major.
        var dp = Array(repeating: 0, count: (n + 1) * (m + 1))
        var bt = Array(repeating: UInt8(0), count: (n + 1) * (m + 1)) // 0=diag,1=up,2=left

        func idx(_ i: Int, _ j: Int) -> Int { i * (m + 1) + j }

        for i in 1...n {
            dp[idx(i, 0)] = i * gap
            bt[idx(i, 0)] = 1
        }
        for j in 1...m {
            dp[idx(0, j)] = j * gap
            bt[idx(0, j)] = 2
        }

        for i in 1...n {
            for j in 1...m {
                let sDiag = dp[idx(i - 1, j - 1)] + (aChars[i - 1] == bChars[j - 1] ? match : mismatch)
                let sUp = dp[idx(i - 1, j)] + gap
                let sLeft = dp[idx(i, j - 1)] + gap

                var best = sDiag
                var dir: UInt8 = 0
                if sUp > best { best = sUp; dir = 1 }
                if sLeft > best { best = sLeft; dir = 2 }

                dp[idx(i, j)] = best
                bt[idx(i, j)] = dir
            }
        }

        // Backtrack
        var i = n
        var j = m
        var outA: [Character] = []
        var outB: [Character] = []
        outA.reserveCapacity(n + m)
        outB.reserveCapacity(n + m)

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && bt[idx(i, j)] == 0 {
                outA.append(aChars[i - 1])
                outB.append(bChars[j - 1])
                i -= 1; j -= 1
            } else if i > 0 && (j == 0 || bt[idx(i, j)] == 1) {
                outA.append(aChars[i - 1])
                outB.append("-")
                i -= 1
            } else {
                outA.append("-")
                outB.append(bChars[j - 1])
                j -= 1
            }
        }

        outA.reverse()
        outB.reverse()

        return AlignmentResult(
            alignedA: String(outA),
            alignedB: String(outB),
            score: dp[idx(n, m)]
        )
    }
}

enum DNA {
    static func reverseComplement(_ s: String) -> String {
        let map: [Character: Character] = [
            "A": "T", "T": "A", "C": "G", "G": "C",
            "a": "t", "t": "a", "c": "g", "g": "c",
            "N": "N", "n": "n",
            "-": "-"
        ]
        return String(s.reversed().map { map[$0] ?? "N" })
    }
}

