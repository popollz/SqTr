import Foundation

struct ContigResult: Sendable, Equatable {
    var forwardName: String
    var reverseName: String
    var reverseWasReverseComplemented: Bool

    var forwardTrace: ABITrace
    /// Reverse trace in the oriented direction used for alignment/consensus.
    var orientedReverseTrace: ABITrace

    var alignedForward: String
    var alignedReverse: String
    var consensus: String
    /// Index i in consensus -> alignment column index.
    var consensusToColumn: [Int]
    /// For each alignment column, forward base index (into forwardTrace.bases) or nil if gap.
    var forwardBaseIndexByColumn: [Int?]
    /// For each alignment column, reverse base index (into orientedReverseTrace.bases) or nil if gap.
    var reverseBaseIndexByColumn: [Int?]
    var alignmentScore: Int
}

enum ContigBuilder {
    static func build(forward: ABITrace, reverse: ABITrace) throws -> ContigResult {
        guard let fSeq = forward.bases, !fSeq.isEmpty else {
            throw NSError(domain: "SwiftSeqTrace", code: 2, userInfo: [NSLocalizedDescriptionKey: "Forward read has no base calls (PBAS)."])
        }
        guard let rSeq0 = reverse.bases, !rSeq0.isEmpty else {
            throw NSError(domain: "SwiftSeqTrace", code: 3, userInfo: [NSLocalizedDescriptionKey: "Reverse read has no base calls (PBAS)."])
        }

        // Try aligning reverse as-is and reverse-complemented; pick the better one.
        let a1 = Aligner.globalAlign(fSeq, rSeq0)
        let rSeqRC = DNA.reverseComplement(rSeq0)
        let a2 = Aligner.globalAlign(fSeq, rSeqRC)

        let best: AlignmentResult
        let reverseWasRC: Bool
        if a2.score > a1.score {
            best = a2
            reverseWasRC = true
        } else {
            best = a1
            reverseWasRC = false
        }

        let orientedReverse = reverseWasRC ? orientReverseTrace(reverse) : reverse

        let consensusAligned = consensusAlignedFromAlignment(
            alignedF: best.alignedA,
            alignedR: best.alignedB,
            forwardQual: forward.qualities,
            reverseQual: reverseWasRC ? reversedQualities(reverse.qualities) : reverse.qualities
        )
        let mapping = buildIndexMapping(alignedF: best.alignedA, alignedR: best.alignedB, consensusAligned: consensusAligned)
        let consensus = consensusAligned.replacingOccurrences(of: "-", with: "")

        return ContigResult(
            forwardName: forward.fileName,
            reverseName: reverse.fileName,
            reverseWasReverseComplemented: reverseWasRC,
            forwardTrace: forward,
            orientedReverseTrace: orientedReverse,
            alignedForward: best.alignedA,
            alignedReverse: best.alignedB,
            consensus: consensus,
            consensusToColumn: mapping.consensusToColumn,
            forwardBaseIndexByColumn: mapping.forwardBaseIndexByColumn,
            reverseBaseIndexByColumn: mapping.reverseBaseIndexByColumn,
            alignmentScore: best.score
        )
    }

    private static func reversedQualities(_ q: [UInt8]?) -> [UInt8]? {
        guard let q else { return nil }
        return Array(q.reversed())
    }

    private static func orientReverseTrace(_ t: ABITrace) -> ABITrace {
        // Flip samples left-to-right and reverse-complement base calls so the chromatogram reads in the same direction.
        let count = t.sampleCount
        let flipLoc: ([Int]?) -> [Int]? = { locs in
            guard let locs, count > 0 else { return locs }
            return locs.map { (count - 1) - $0 }.reversed()
        }

        return ABITrace(
            fileName: t.fileName,
            samplesA: Array(t.samplesA.reversed()),
            samplesC: Array(t.samplesC.reversed()),
            samplesG: Array(t.samplesG.reversed()),
            samplesT: Array(t.samplesT.reversed()),
            bases: t.bases.map(DNA.reverseComplement),
            peakLocations: flipLoc(t.peakLocations),
            qualities: t.qualities.map { Array($0.reversed()) }
        )
    }

    private static func consensusAlignedFromAlignment(
        alignedF: String,
        alignedR: String,
        forwardQual: [UInt8]?,
        reverseQual: [UInt8]?
    ) -> String {
        let f = Array(alignedF)
        let r = Array(alignedR)
        let n = min(f.count, r.count)

        var out: [Character] = []
        out.reserveCapacity(n)

        var fi = 0
        var ri = 0

        func q(_ arr: [UInt8]?, _ i: Int) -> Int {
            guard let arr, i >= 0, i < arr.count else { return -1 }
            return Int(arr[i])
        }

        for k in 0..<n {
            let fc = f[k]
            let rc = r[k]

            let fIsGap = (fc == "-")
            let rIsGap = (rc == "-")

            let fq = fIsGap ? -1 : q(forwardQual, fi)
            let rq = rIsGap ? -1 : q(reverseQual, ri)

            let chosen: Character
            if fIsGap && rIsGap {
                chosen = "N"
            } else if fIsGap {
                chosen = normalizeBase(rc)
            } else if rIsGap {
                chosen = normalizeBase(fc)
            } else if normalizeBase(fc) == normalizeBase(rc) {
                chosen = normalizeBase(fc)
            } else {
                // Mismatch: choose higher-quality base if available; else N.
                if fq >= 0 || rq >= 0 {
                    chosen = (fq >= rq) ? normalizeBase(fc) : normalizeBase(rc)
                } else {
                    chosen = "N"
                }
            }

            out.append(chosen)
            if !fIsGap { fi += 1 }
            if !rIsGap { ri += 1 }
        }

        return String(out)
    }

    private static func normalizeBase(_ c: Character) -> Character {
        let u = String(c).uppercased()
        return u.first.map { ["A", "C", "G", "T"].contains(String($0)) ? $0 : "N" } ?? "N"
    }

    private static func buildIndexMapping(
        alignedF: String,
        alignedR: String,
        consensusAligned: String
    ) -> (consensusToColumn: [Int], forwardBaseIndexByColumn: [Int?], reverseBaseIndexByColumn: [Int?]) {
        let f = Array(alignedF)
        let r = Array(alignedR)
        let c = Array(consensusAligned)
        let n = min(f.count, r.count, c.count)

        var fByCol: [Int?] = Array(repeating: nil, count: n)
        var rByCol: [Int?] = Array(repeating: nil, count: n)
        var consToCol: [Int] = []
        consToCol.reserveCapacity(n)

        var fi = 0
        var ri = 0
        for col in 0..<n {
            if f[col] != "-" { fByCol[col] = fi; fi += 1 }
            if r[col] != "-" { rByCol[col] = ri; ri += 1 }
            if c[col] != "-" { consToCol.append(col) }
        }

        return (consToCol, fByCol, rByCol)
    }
}

