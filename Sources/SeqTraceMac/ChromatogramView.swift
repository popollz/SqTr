import AppKit
import SwiftUI

struct ChromatogramControls: Equatable {
    var zoomX: Double = 1.0
    var zoomY: Double = 1.0
    var offsetX: Double = 0.0
}

struct ChromatogramView: View {
    let trace: ABITrace
    var title: String? = nil
    var showSequencePanel: Bool = true
    /// When set (e.g. contig view), overrides selection-based highlight on the trace.
    var externalHighlightSampleRange: ClosedRange<Int>? = nil
    /// Optional external control for pan/zoom (used to keep multiple chromatograms in sync).
    var controls: Binding<ChromatogramControls>? = nil

    @State private var zoomX: Double = 1.0
    @State private var offsetX: Double = 0.0
    @State private var zoomY: Double = 1.0
    @State private var edited: EditedBaseCalls
    @State private var selectedUnwrapped: NSRange = NSRange(location: 0, length: 0)

    init(
        trace: ABITrace,
        title: String? = nil,
        showSequencePanel: Bool = true,
        externalHighlightSampleRange: ClosedRange<Int>? = nil,
        controls: Binding<ChromatogramControls>? = nil
    ) {
        self.trace = trace
        self.title = title
        self.showSequencePanel = showSequencePanel
        self.externalHighlightSampleRange = externalHighlightSampleRange
        self.controls = controls
        _edited = State(initialValue: EditedBaseCalls(trace: trace))
        _selectedUnwrapped = State(initialValue: NSRange(location: 0, length: 0))
    }

    var body: some View {
        let zoomXBinding = controls?.zoomX ?? $zoomX
        let zoomYBinding = controls?.zoomY ?? $zoomY
        let offsetXBinding = controls?.offsetX ?? $offsetX

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title ?? trace.fileName)
                    .font(.headline)

                Spacer()

                Text("\(trace.sampleCount) samples")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ChromatogramCanvas(
                samplesA: trace.samplesA,
                samplesC: trace.samplesC,
                samplesG: trace.samplesG,
                samplesT: trace.samplesT,
                bases: String(edited.bases),
                peakLocations: edited.peakLocations,
                qualities: edited.qualities,
                highlightSampleRange: computedHighlightSampleRange(),
                zoomX: zoomXBinding.wrappedValue,
                zoomY: zoomYBinding.wrappedValue,
                offsetX: offsetXBinding.wrappedValue
            )
            .background(.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.black.opacity(0.08), lineWidth: 1)
            }

            HStack(spacing: 12) {
                Text("Zoom")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: zoomXBinding, in: 1...12, step: 0.25)
                    .frame(width: 220)

                Text("Height")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: zoomYBinding, in: 0.5...4, step: 0.05)
                    .frame(width: 180)

                Text("Pan")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: offsetXBinding, in: 0...1, step: 0.001)
                    .frame(width: 220)

                Spacer()

                if !edited.bases.isEmpty {
                    Text("Bases: \(edited.bases.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if showSequencePanel {
                GroupBox("Sequence") {
                    if !edited.bases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer(minLength: 0)
                                Button("Copy sequence") {
                                    SequenceClipboard.copyPlainText(String(edited.bases))
                                }
                                .help("Copy the full edited sequence as plain text (one line).")
                            }
                            AB1SequenceTextEditor(edited: $edited, selectedUnwrapped: $selectedUnwrapped)
                                .frame(minHeight: 120)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No base-called sequence found in this file.")
                                .font(.callout)
                            Text("Next step is to read additional ABIF tags (e.g. alternative basecall/quality fields) depending on your instrument output.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .onChange(of: trace.fileName) { _ in
            edited = EditedBaseCalls(trace: trace)
            selectedUnwrapped = NSRange(location: 0, length: 0)
        }
    }

    private func computedHighlightSampleRange() -> ClosedRange<Int>? {
        if let ext = externalHighlightSampleRange {
            return ext
        }
        guard showSequencePanel else { return nil }
        let peaks = edited.peakLocations
        guard !peaks.isEmpty else { return nil }
        let sel = selectedUnwrapped
        if sel.length > 0 {
            let lo = sel.location
            let hi = sel.location + sel.length - 1
            guard lo < edited.bases.count, hi < edited.bases.count, lo <= hi else { return nil }
            let s0 = peaks[lo]
            let s1 = peaks[hi]
            return min(s0, s1)...max(s0, s1)
        }
        if sel.length == 0, sel.location >= 0, sel.location < peaks.count {
            let s = peaks[sel.location]
            return s...s
        }
        return nil
    }
}

private struct ChromatogramCanvas: View {
    let samplesA: [UInt16]
    let samplesC: [UInt16]
    let samplesG: [UInt16]
    let samplesT: [UInt16]
    let bases: String
    let peakLocations: [Int]
    let qualities: [UInt8]?
    let highlightSampleRange: ClosedRange<Int>?
    let zoomX: Double
    let zoomY: Double
    let offsetX: Double

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let count = min(samplesA.count, samplesC.count, samplesG.count, samplesT.count)
                if count <= 1 { return }

                let visibleCount = max(50, Int(Double(count) / zoomX))
                let maxStart = max(0, count - visibleCount)
                let start = Int(Double(maxStart) * offsetX)
                let end = min(count, start + visibleCount)
                if end - start <= 1 { return }

                let sliceCount = end - start
                let labelAreaHeight: Double = (!bases.isEmpty && !peakLocations.isEmpty) ? 28 : 8
                let traceHeight = max(10, size.height - labelAreaHeight)

                let maxValue = max(
                    samplesA[start..<end].max() ?? 1,
                    samplesC[start..<end].max() ?? 1,
                    samplesG[start..<end].max() ?? 1,
                    samplesT[start..<end].max() ?? 1
                )

                func x(_ i: Int) -> Double {
                    let t = Double(i - start) / Double(max(1, sliceCount - 1))
                    return t * size.width
                }

                func y(_ v: UInt16) -> Double {
                    let t = Double(v) / Double(max(1, maxValue))
                    let scaled = min(1.0, t * zoomY)
                    return traceHeight - scaled * (traceHeight - 8) - 4
                }

                drawLine(ctx: &ctx, size: size, color: .red,   start: start, end: end, samples: samplesT, x: x, y: y)
                drawLine(ctx: &ctx, size: size, color: .blue,  start: start, end: end, samples: samplesC, x: x, y: y)
                drawLine(ctx: &ctx, size: size, color: .green, start: start, end: end, samples: samplesA, x: x, y: y)
                drawLine(ctx: &ctx, size: size, color: .black, start: start, end: end, samples: samplesG, x: x, y: y)

                if let hr = highlightSampleRange {
                    let lo = hr.lowerBound
                    let hi = hr.upperBound
                    let visLo = max(lo, start)
                    let visHi = min(hi, end - 1)
                    if visLo <= visHi {
                        let x0 = x(visLo)
                        let x1 = x(visHi)
                        if visLo == visHi {
                            var path = Path()
                            path.move(to: CGPoint(x: x0, y: 0))
                            path.addLine(to: CGPoint(x: x0, y: traceHeight))
                            ctx.stroke(path, with: .color(.yellow.opacity(0.85)), lineWidth: 2)
                        } else {
                            let rect = CGRect(x: min(x0, x1), y: 0, width: abs(x1 - x0), height: traceHeight)
                            ctx.fill(Path(rect), with: .color(.yellow.opacity(0.22)))
                            var left = Path()
                            left.move(to: CGPoint(x: min(x0, x1), y: 0))
                            left.addLine(to: CGPoint(x: min(x0, x1), y: traceHeight))
                            var right = Path()
                            right.move(to: CGPoint(x: max(x0, x1), y: 0))
                            right.addLine(to: CGPoint(x: max(x0, x1), y: traceHeight))
                            ctx.stroke(left, with: .color(.yellow.opacity(0.55)), lineWidth: 1.5)
                            ctx.stroke(right, with: .color(.yellow.opacity(0.55)), lineWidth: 1.5)
                        }
                    }
                }

                drawBaseCalls(
                    ctx: &ctx,
                    size: size,
                    start: start,
                    end: end,
                    traceHeight: traceHeight
                )
            }
        }
        .frame(minHeight: 380)
        .padding(10)
    }

    private func drawLine(
        ctx: inout GraphicsContext,
        size: CGSize,
        color: Color,
        start: Int,
        end: Int,
        samples: [UInt16],
        x: (Int) -> Double,
        y: (UInt16) -> Double
    ) {
        var path = Path()
        path.move(to: CGPoint(x: x(start), y: y(samples[start])))
        if end - start <= 2 {
            path.addLine(to: CGPoint(x: x(end - 1), y: y(samples[end - 1])))
        } else {
            for i in (start + 1)..<end {
                path.addLine(to: CGPoint(x: x(i), y: y(samples[i])))
            }
        }

        ctx.stroke(
            path,
            with: .color(color.opacity(0.95)),
            lineWidth: 1.2
        )
    }

    private func drawBaseCalls(
        ctx: inout GraphicsContext,
        size: CGSize,
        start: Int,
        end: Int,
        traceHeight: Double
    ) {
        guard !bases.isEmpty, !peakLocations.isEmpty else { return }

        let baseChars = Array(bases)
        let n = min(baseChars.count, peakLocations.count)
        if n == 0 { return }

        let yBases = traceHeight + 10
        // Draw quality values inside the chromatogram area (near the top), SeqTrace-style.
        let yQuals = 10.0

        var lastX: Double = -Double.infinity
        let minSpacing: Double = 8

        for i in 0..<n {
            let loc = peakLocations[i]
            if loc < start || loc >= end { continue }

            let xPos = Double(loc - start) / Double(max(1, (end - start) - 1)) * size.width
            if xPos - lastX < minSpacing { continue } // avoid unreadable overlap when zoomed out
            lastX = xPos

            let base = String(baseChars[i]).uppercased()
            let color: Color = switch base {
            case "A": .green
            case "C": .blue
            case "G": .black
            case "T": .red
            default: .secondary
            }

            if let qualities, i < qualities.count {
                let q = Int(qualities[i])
                ctx.draw(
                    Text("\(q)")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: xPos, y: yQuals),
                    anchor: .center
                )
            }

            ctx.draw(
                Text(base)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(color),
                at: CGPoint(x: xPos, y: yBases),
                anchor: .center
            )
        }
    }
}

