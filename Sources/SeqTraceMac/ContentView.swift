import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var loadState: LoadState = .idle

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Open .ab1 / .abi…") {
                    openFile()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Open pair (F+R)…") {
                    openPair()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Spacer()
            }

            Group {
                switch loadState {
                case .idle:
                    UnavailablePlaceholder(
                        title: "Open an AB1/ABI file",
                        systemImage: "waveform.path.ecg",
                        message: "Choose an .ab1 file to view its chromatogram, or open a pair to build a contig."
                    )
                case .loading:
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let trace):
                    ChromatogramView(trace: trace)
                case .pairLoaded(let result):
                    ContigView(result: result)
                case .failed(let message):
                    UnavailablePlaceholder(
                        title: "Couldn’t open file",
                        systemImage: "exclamationmark.triangle",
                        message: message
                    )
                }
            }
            .frame(minHeight: 420)
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 520)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.abiTrace, .abiTraceAlt]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await load(url: url)
            }
        }
    }

    private func openPair() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.abiTrace, .abiTraceAlt]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                await loadPair(urls: urls)
            }
        }
    }

    @MainActor
    private func load(url: URL) async {
        loadState = .loading
        do {
            let trace = try ABITraceReader.read(url: url)
            loadState = .loaded(trace)
        } catch {
            loadState = .failed(String(describing: error))
        }
    }

    @MainActor
    private func loadPair(urls: [URL]) async {
        loadState = .loading
        do {
            guard urls.count == 2 else {
                throw NSError(domain: "SwiftSeqTrace", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please select exactly 2 AB1/ABI files (forward and reverse)."])
            }

            let t1 = try ABITraceReader.read(url: urls[0])
            let t2 = try ABITraceReader.read(url: urls[1])
            let result = try ContigBuilder.build(forward: t1, reverse: t2)
            loadState = .pairLoaded(result)
        } catch {
            loadState = .failed(String(describing: error))
        }
    }
}

private enum LoadState {
    case idle
    case loading
    case loaded(ABITrace)
    case pairLoaded(ContigResult)
    case failed(String)
}

private extension UTType {
    static let abiTrace = UTType(filenameExtension: "ab1") ?? .data
    static let abiTraceAlt = UTType(filenameExtension: "abi") ?? .data
}

private struct UnavailablePlaceholder: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

