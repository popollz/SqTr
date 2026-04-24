import AppKit
import SwiftUI

struct ContigView: View {
    let result: ContigResult

    @State private var showFullAlignment = false
    @State private var consensusCells: [ConsensusCell]
    @State private var selectedConsensusUnwrapped: NSRange = NSRange(location: 0, length: 0)
    @State private var forwardControls = ChromatogramControls()
    @State private var reverseControls = ChromatogramControls()

    init(result: ContigResult) {
        self.result = result
        let cons = Array(result.consensus)
        let cells: [ConsensusCell] = cons.enumerated().map { (i, ch) in
            ConsensusCell(column: result.consensusToColumn[i], base: ch)
        }
        _consensusCells = State(initialValue: cells)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contig")
                            .font(.headline)
                        Text("\(result.forwardName)  +  \(result.reverseName)\(result.reverseWasReverseComplemented ? " (rev-comp)" : "")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 8)

                    Text("score \(result.alignmentScore)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .layoutPriority(1)
                        .fixedSize()
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 14) {
                    ChromatogramView(
                        trace: result.forwardTrace,
                        title: "Forward: \(result.forwardName)",
                        showSequencePanel: false,
                        externalHighlightSampleRange: highlightSampleRange(for: .forward),
                        controls: $forwardControls
                    )
                    .frame(minHeight: 360)

                    ChromatogramView(
                        trace: result.orientedReverseTrace,
                        title: "Reverse: \(result.reverseName)\(result.reverseWasReverseComplemented ? " (oriented)" : "")",
                        showSequencePanel: false,
                        externalHighlightSampleRange: highlightSampleRange(for: .reverse),
                        controls: $reverseControls
                    )
                    .frame(minHeight: 360)
                }

                GroupBox("Consensus") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Spacer(minLength: 0)
                            Button("Copy consensus") {
                                SequenceClipboard.copyPlainText(String(consensusCells.map(\.base)))
                            }
                            .help("Copy the full consensus sequence as plain text (one line).")
                        }
                        ConsensusSequenceTextEditor(
                            cells: $consensusCells,
                            selectedUnwrapped: $selectedConsensusUnwrapped,
                            forwardBaseAt: { idx in baseFromRead(.forward, consensusIndex: idx) },
                            reverseBaseAt: { idx in baseFromRead(.reverse, consensusIndex: idx) }
                        )
                            .frame(minHeight: 110)

                        if selectedConsensusUnwrapped.length == 1 {
                            consensusOneBaseToolbar(index: selectedConsensusUnwrapped.location)
                        }

                        Text("Select bases (click or drag) to highlight both chromatograms. Edit in place; Delete removes the selection. Pasting into the consensus is only allowed over an existing selection (no insertions at the caret).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Toggle("Show alignment", isOn: $showFullAlignment)
                    Spacer()
                    Text("Tip: mismatches are marked with “·”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if showFullAlignment {
                    GroupBox("Alignment (F vs R)") {
                        ScrollView([.vertical, .horizontal]) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(alignmentLines(), id: \.self.key) { line in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.f)
                                            .font(.system(.body, design: .monospaced))
                                        Text(line.mid)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text(line.r)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    Divider()
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .frame(minHeight: 220)
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .onChange(of: selectedConsensusUnwrapped.location) { _ in
            focusChromatograms()
        }
        .onChange(of: selectedConsensusUnwrapped.length) { _ in
            focusChromatograms()
        }
        .onChange(of: consensusCells.count) { _ in
            focusChromatograms()
        }
    }

    @ViewBuilder
    private func consensusOneBaseToolbar(index: Int) -> some View {
        HStack(spacing: 10) {
            if let b = baseFromRead(.forward, consensusIndex: index) {
                Button("Use forward (\(String(b)))") {
                    applyEdit(at: index, base: b)
                }
            }
            if let b = baseFromRead(.reverse, consensusIndex: index) {
                Button("Use reverse (\(String(b)))") {
                    applyEdit(at: index, base: b)
                }
            }
                                Button("Set N") {
                                    applyEdit(at: index, base: Character("N"))
                                }
        }
        .font(.footnote)
    }

    private enum ReadSide { case forward, reverse }

    private func highlightSampleRange(for side: ReadSide) -> ClosedRange<Int>? {
        let ns = selectedConsensusUnwrapped
        let cells = consensusCells
        guard !cells.isEmpty else { return nil }

        if ns.length > 0 {
            let lo = ns.location
            let hi = ns.location + ns.length - 1
            guard lo < cells.count, hi < cells.count, lo <= hi else { return nil }
            var samples: [Int] = []
            for idx in lo...hi {
                if let s = sampleIndex(for: side, consensusIndex: idx) {
                    samples.append(s)
                }
            }
            guard let mn = samples.min(), let mx = samples.max() else { return nil }
            return mn...mx
        }

        if ns.length == 0, ns.location >= 0, ns.location < cells.count {
            if let s = sampleIndex(for: side, consensusIndex: ns.location) {
                return s...s
            }
        }
        return nil
    }

    private func sampleIndex(for side: ReadSide, consensusIndex: Int) -> Int? {
        let cells = consensusCells
        guard consensusIndex >= 0, consensusIndex < cells.count else { return nil }
        let col = cells[consensusIndex].column

        switch side {
        case .forward:
            guard let baseIdx = result.forwardBaseIndexByColumn[safe: col] ?? nil else { return nil }
            return result.forwardTrace.peakLocations?[safe: baseIdx]
        case .reverse:
            guard let baseIdx = result.reverseBaseIndexByColumn[safe: col] ?? nil else { return nil }
            return result.orientedReverseTrace.peakLocations?[safe: baseIdx]
        }
    }

    private func applyEdit(at idx: Int, base: Character) {
        guard idx >= 0, idx < consensusCells.count else { return }
        consensusCells[idx].base = base
        focusChromatograms()
    }

    private func deleteBase(at idx: Int) {
        guard idx >= 0, idx < consensusCells.count else { return }
        consensusCells.remove(at: idx)
        let newLen = consensusCells.count
        let loc = min(idx, max(0, newLen - 1))
        selectedConsensusUnwrapped = NSRange(location: loc, length: 0)
        focusChromatograms()
    }

    private func alignmentLines() -> [(key: String, f: String, mid: String, r: String)] {
        let f = result.alignedForward
        let r = result.alignedReverse
        let n = min(f.count, r.count)
        let chunk = 80

        var out: [(String, String, String, String)] = []
        var i = 0
        while i < n {
            let j = min(n, i + chunk)
            let fSub = substring(f, i, j)
            let rSub = substring(r, i, j)
            let mid = mismatchLine(fSub, rSub)
            out.append(("\(i)", fSub, mid, rSub))
            i = j
        }
        return out
    }

    private func mismatchLine(_ f: String, _ r: String) -> String {
        let fc = Array(f)
        let rc = Array(r)
        let n = min(fc.count, rc.count)
        var out: [Character] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let a = fc[i]
            let b = rc[i]
            if a == b && a != "-" {
                out.append("|")
            } else if a == "-" || b == "-" {
                out.append(" ")
            } else {
                out.append("·")
            }
        }
        return String(out)
    }

    private func substring(_ s: String, _ start: Int, _ end: Int) -> String {
        let a = s.index(s.startIndex, offsetBy: start, limitedBy: s.endIndex) ?? s.endIndex
        let b = s.index(s.startIndex, offsetBy: end, limitedBy: s.endIndex) ?? s.endIndex
        return String(s[a..<b])
    }

    private func baseFromRead(_ side: ReadSide, consensusIndex: Int) -> Character? {
        guard consensusIndex >= 0, consensusIndex < consensusCells.count else { return nil }
        let col = consensusCells[consensusIndex].column

        switch side {
        case .forward:
            guard let baseIdx = result.forwardBaseIndexByColumn[safe: col] ?? nil else { return nil }
            guard let bases = result.forwardTrace.bases else { return nil }
            return Array(bases)[safe: baseIdx]
        case .reverse:
            guard let baseIdx = result.reverseBaseIndexByColumn[safe: col] ?? nil else { return nil }
            guard let bases = result.orientedReverseTrace.bases else { return nil }
            return Array(bases)[safe: baseIdx]
        }
    }

    private func focusChromatograms() {
        if let sample = highlightSampleRange(for: .forward)?.lowerBound {
            forwardControls.offsetX = focusOffset(sampleIndex: sample, sampleCount: result.forwardTrace.sampleCount, zoomX: forwardControls.zoomX)
        }
        if let sample = highlightSampleRange(for: .reverse)?.lowerBound {
            reverseControls.offsetX = focusOffset(sampleIndex: sample, sampleCount: result.orientedReverseTrace.sampleCount, zoomX: reverseControls.zoomX)
        }
    }

    private func focusOffset(sampleIndex: Int, sampleCount: Int, zoomX: Double) -> Double {
        guard sampleCount > 1 else { return 0 }
        let visibleCount = max(50, Int(Double(sampleCount) / zoomX))
        let maxStart = max(0, sampleCount - visibleCount)
        if maxStart == 0 { return 0 }
        let targetStart = max(0, min(maxStart, sampleIndex - visibleCount / 2))
        return Double(targetStart) / Double(maxStart)
    }
}

private extension Collection {
    subscript(safe idx: Index) -> Element? {
        indices.contains(idx) ? self[idx] : nil
    }
}
