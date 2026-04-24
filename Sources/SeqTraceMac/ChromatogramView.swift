import AppKit
import SwiftUI

struct ChromatogramControls: Equatable {
    var zoomX: Double = 1.0
    var zoomY: Double = 1.0
    var offsetX: Double = 0.0
}

/// 4Peaks-style palette for A/C/G/T used both by the DNA strip and the header readout.
private func baseColor(_ letter: String) -> Color {
    switch letter.uppercased() {
    case "A": return .green
    case "C": return .blue
    case "G": return .black
    case "T": return .red
    default:  return .secondary
    }
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
    @State private var isSequenceExpanded: Bool = false
    @State private var showGearPopover: Bool = false

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

        VStack(alignment: .leading, spacing: 6) {
            header

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

            toolbar(
                zoomXBinding: zoomXBinding,
                zoomYBinding: zoomYBinding,
                offsetXBinding: offsetXBinding
            )

            if showSequencePanel {
                sequenceDrawer
            }
        }
        .onChange(of: trace.fileName) { _ in
            edited = EditedBaseCalls(trace: trace)
            selectedUnwrapped = NSRange(location: 0, length: 0)
            isSequenceExpanded = false
        }
    }

    // MARK: - Header (4Peaks-style)

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let info = currentBaseInfo {
                HStack(spacing: 2) {
                    Text("Base ")
                        .foregroundStyle(.secondary)
                    Text(info.letter)
                        .fontWeight(.semibold)
                        .foregroundStyle(baseColor(info.letter))
                    Text("\(info.oneBasedIndex)")
                        .fontWeight(.semibold)
                    if let q = info.quality {
                        Text(", Quality: \(q)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 13))
            } else {
                Text("\(trace.sampleCount) samples")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(title ?? trace.fileName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var currentBaseInfo: (letter: String, oneBasedIndex: Int, quality: UInt8?)? {
        guard !edited.bases.isEmpty else { return nil }
        let loc = selectedUnwrapped.location
        guard loc >= 0, loc < edited.bases.count else { return nil }
        let letter = String(edited.bases[loc]).uppercased()
        let quality = edited.qualities.flatMap { qs in
            (loc < qs.count) ? qs[loc] : nil
        }
        return (letter, loc + 1, quality)
    }

    // MARK: - Bottom toolbar (minimal, 4Peaks-style)

    @ViewBuilder
    private func toolbar(
        zoomXBinding: Binding<Double>,
        zoomYBinding: Binding<Double>,
        offsetXBinding: Binding<Double>
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                showGearPopover.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Advanced display controls")
            .popover(isPresented: $showGearPopover, arrowEdge: .top) {
                gearPopoverContent(
                    zoomYBinding: zoomYBinding,
                    offsetXBinding: offsetXBinding
                )
            }

            Slider(value: zoomXBinding, in: 1...12, step: 0.25)
                .frame(maxWidth: 320)

            Text(String(format: "%.1f×", zoomXBinding.wrappedValue))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

            Spacer()

            if !edited.bases.isEmpty {
                Button {
                    SequenceClipboard.copyPlainText(String(edited.bases))
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .help("Copy the full sequence as plain text")
            }
        }
    }

    @ViewBuilder
    private func gearPopoverContent(
        zoomYBinding: Binding<Double>,
        offsetXBinding: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Peak height")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Slider(value: zoomYBinding, in: 0.5...4, step: 0.05)
                        .frame(width: 200)
                    Text(String(format: "%.2f×", zoomYBinding.wrappedValue))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Pan")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: offsetXBinding, in: 0...1, step: 0.001)
                    .frame(width: 256)
            }
        }
        .padding(14)
    }

    // MARK: - Sequence drawer

    @ViewBuilder
    private var sequenceDrawer: some View {
        if edited.bases.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No base-called sequence found in this file.")
                    .font(.callout)
                Text("Next step is to read additional ABIF tags (e.g. alternative basecall/quality fields) depending on your instrument output.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        } else {
            DisclosureGroup(isExpanded: $isSequenceExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button("Copy sequence") {
                            SequenceClipboard.copyPlainText(String(edited.bases))
                        }
                        .help("Copy the full edited sequence as plain text (one line).")
                    }
                    AB1SequenceTextEditor(edited: $edited, selectedUnwrapped: $selectedUnwrapped)
                        .frame(minHeight: 120)
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 6) {
                    Text("Sequence")
                        .font(.subheadline)
                    Text("(\(edited.bases.count) bases)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
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

// MARK: - Canvas

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

    /// Height of the colored DNA strip drawn at the top of the canvas.
    private let stripHeight: Double = 22
    /// Selection column: minimum visible width when only a single base is selected.
    private let singleBaseColumnWidth: Double = 16
    /// Max PHRED score used when normalizing the quality histogram.
    private let maxPhred: Double = 60

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

                let hasStrip = !bases.isEmpty && !peakLocations.isEmpty
                let stripTop: Double = 0
                let stripBottom: Double = hasStrip ? stripHeight : 0

                let traceTop = stripBottom
                let traceHeight = max(10, size.height - traceTop)

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
                    return traceTop + traceHeight - scaled * (traceHeight - 6) - 3
                }

                // 1) Pale-blue quality histogram behind traces.
                drawQualityHistogram(
                    ctx: &ctx,
                    size: size,
                    start: start,
                    end: end,
                    traceTop: traceTop,
                    traceHeight: traceHeight,
                    x: x
                )

                // 2) Selection column (full height: spans strip + traces).
                drawSelectionColumn(
                    ctx: &ctx,
                    size: size,
                    start: start,
                    end: end,
                    canvasHeight: size.height,
                    x: x
                )

                // 3) Trace lines.
                drawLine(ctx: &ctx, size: size, color: .red,   start: start, end: end, samples: samplesT, x: x, y: y)
                drawLine(ctx: &ctx, size: size, color: .blue,  start: start, end: end, samples: samplesC, x: x, y: y)
                drawLine(ctx: &ctx, size: size, color: .green, start: start, end: end, samples: samplesA, x: x, y: y)
                drawLine(ctx: &ctx, size: size, color: .black, start: start, end: end, samples: samplesG, x: x, y: y)

                // 4) Top DNA strip (colored letters).
                if hasStrip {
                    drawTopStrip(
                        ctx: &ctx,
                        size: size,
                        start: start,
                        end: end,
                        stripTop: stripTop,
                        stripBottom: stripBottom,
                        x: x
                    )
                }

                // 5) Small max-peak-height label at top-left, like 4Peaks.
                ctx.draw(
                    Text("\(maxValue)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: 4, y: stripBottom + 4),
                    anchor: .topLeading
                )
            }
        }
        .frame(minHeight: 300)
    }

    private func drawQualityHistogram(
        ctx: inout GraphicsContext,
        size: CGSize,
        start: Int,
        end: Int,
        traceTop: Double,
        traceHeight: Double,
        x: (Int) -> Double
    ) {
        guard let qualities, !peakLocations.isEmpty, !qualities.isEmpty else { return }
        let n = min(qualities.count, peakLocations.count)
        if n == 0 { return }

        let maxBarHeight = traceHeight * 0.60
        let histogramColor = Color(red: 0.61, green: 0.76, blue: 0.94).opacity(0.28)

        for i in 0..<n {
            let loc = peakLocations[i]
            if loc < start || loc >= end { continue }

            let leftMid: Int
            if i > 0 {
                leftMid = (peakLocations[i - 1] + loc) / 2
            } else {
                leftMid = loc - 4
            }
            let rightMid: Int
            if i < n - 1 {
                rightMid = (peakLocations[i + 1] + loc) / 2
            } else {
                rightMid = loc + 4
            }

            let clampedLeft = max(start, min(end - 1, leftMid))
            let clampedRight = max(start, min(end - 1, rightMid))
            let xLeft = x(clampedLeft)
            let xRight = x(clampedRight)
            if xRight - xLeft <= 0 { continue }

            let qNorm = min(Double(qualities[i]) / maxPhred, 1.0)
            let barHeight = qNorm * maxBarHeight
            let y0 = traceTop + (traceHeight - barHeight)

            let rect = CGRect(x: xLeft, y: y0, width: xRight - xLeft, height: barHeight)
            ctx.fill(Path(rect), with: .color(histogramColor))
        }
    }

    private func drawSelectionColumn(
        ctx: inout GraphicsContext,
        size: CGSize,
        start: Int,
        end: Int,
        canvasHeight: Double,
        x: (Int) -> Double
    ) {
        guard let hr = highlightSampleRange else { return }
        let lo = hr.lowerBound
        let hi = hr.upperBound
        let visLo = max(lo, start)
        let visHi = min(hi, end - 1)
        if visLo > visHi { return }

        let x0 = x(visLo)
        let x1 = x(visHi)

        let fill = Color.accentColor.opacity(0.18)
        let stroke = Color.accentColor.opacity(0.55)

        if visLo == visHi {
            let w = singleBaseColumnWidth
            let rect = CGRect(x: x0 - w / 2, y: 0, width: w, height: canvasHeight)
            ctx.fill(Path(rect), with: .color(fill))
            var line = Path()
            line.move(to: CGPoint(x: x0, y: 0))
            line.addLine(to: CGPoint(x: x0, y: canvasHeight))
            ctx.stroke(line, with: .color(stroke), lineWidth: 1)
        } else {
            let minX = min(x0, x1)
            let maxX = max(x0, x1)
            let rect = CGRect(x: minX, y: 0, width: maxX - minX, height: canvasHeight)
            ctx.fill(Path(rect), with: .color(fill))
            var left = Path()
            left.move(to: CGPoint(x: minX, y: 0))
            left.addLine(to: CGPoint(x: minX, y: canvasHeight))
            var right = Path()
            right.move(to: CGPoint(x: maxX, y: 0))
            right.addLine(to: CGPoint(x: maxX, y: canvasHeight))
            ctx.stroke(left, with: .color(stroke), lineWidth: 1)
            ctx.stroke(right, with: .color(stroke), lineWidth: 1)
        }
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

    private func drawTopStrip(
        ctx: inout GraphicsContext,
        size: CGSize,
        start: Int,
        end: Int,
        stripTop: Double,
        stripBottom: Double,
        x: (Int) -> Double
    ) {
        let baseChars = Array(bases)
        let n = min(baseChars.count, peakLocations.count)
        if n == 0 { return }

        let yCenter = (stripTop + stripBottom) / 2
        var lastX: Double = -.infinity
        let minSpacing: Double = 8

        for i in 0..<n {
            let loc = peakLocations[i]
            if loc < start || loc >= end { continue }

            let xPos = x(loc)
            if xPos - lastX < minSpacing { continue }
            lastX = xPos

            let base = String(baseChars[i]).uppercased()
            ctx.draw(
                Text(base)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(baseColor(base)),
                at: CGPoint(x: xPos, y: yCenter),
                anchor: .center
            )
        }
    }
}
