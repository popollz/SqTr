import AppKit
import SwiftUI

/// Monospaced wrapped sequence editor with base coloring and a custom context menu (single trace).
struct AB1SequenceTextEditor: NSViewRepresentable {
    @Binding var edited: EditedBaseCalls
    @Binding var selectedUnwrapped: NSRange

    var lineLength: Int = 80

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let tv = SequenceColoredTextView()
        tv.menuMode = .singleFile
        tv.delegate = context.coordinator
        tv.isRichText = true
        tv.importsGraphics = false
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        tv.font = font
        tv.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.allowsUndo = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let proxy = SequenceMenuProxy()
        let coord = context.coordinator
        proxy.onCut = { [weak coord] in coord?.performCutFromMenu() }
        proxy.onCopySelection = { [weak coord] in coord?.performCopySelectionFromMenu() }
        proxy.onDelete = { [weak coord] in
            coord?.performDeleteFromMenu()
        }
        proxy.onReplaceN = { [weak coord] in
            coord?.performReplaceNFromMenu()
        }
        proxy.onUseForward = nil
        proxy.onUseReverse = nil
        tv.menuProxy = proxy
        coord.menuProxy = proxy

        scroll.documentView = tv
        context.coordinator.textView = tv

        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        context.coordinator.parent = self
        let wrapped = SequenceWrapMath.wrapText(String(edited.bases), lineLength: lineLength)
        if tv.string != wrapped {
            context.coordinator.isProgrammaticStringUpdate = true
            context.coordinator.setWrappedAttributed(wrapped, on: tv)
            context.coordinator.isProgrammaticStringUpdate = false
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AB1SequenceTextEditor
        weak var textView: SequenceColoredTextView?
        weak var menuProxy: SequenceMenuProxy?
        var isProgrammaticStringUpdate = false
        var isProgrammaticSelectionUpdate = false

        init(_ parent: AB1SequenceTextEditor) {
            self.parent = parent
        }

        /// `NSTextView` builds the context menu through the delegate; `menu(for:)` on the view is not used.
        func textView(_ textView: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            guard let proxy = menuProxy else { return menu }
            return SequenceContextMenu.makeMenu(proxy: proxy, style: .singleFile)
        }

        func setWrappedAttributed(_ wrapped: String, on tv: NSTextView) {
            let font = tv.font ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let attr = SequenceBaseColors.attributedString(for: wrapped, font: font)
            tv.textStorage?.setAttributedString(attr)
        }

        private func currentLinearSelection() -> NSRange {
            guard let tv = textView else { return NSRange(location: 0, length: 0) }
            let wr = tv.selectedRange()
            let wrapped = tv.string as NSString
            return SequenceWrapMath.linearRange(fromWrappedSelection: wr, in: wrapped as String)
        }

        func performCopySelectionFromMenu() {
            let lin = currentLinearSelection()
            let bases = parent.edited.bases
            if lin.length > 0 {
                let end = min(lin.location + lin.length, bases.count)
                guard lin.location < end else { return }
                let text = String(bases[lin.location..<end])
                SequenceClipboard.copyPlainText(text)
            } else if lin.location < bases.count {
                SequenceClipboard.copyPlainText(String(bases[lin.location]))
            }
        }

        func performCutFromMenu() {
            guard let tv = textView else { return }
            let lin = currentLinearSelection()
            let bases = parent.edited.bases
            if lin.length > 0 {
                let end = min(lin.location + lin.length, bases.count)
                guard lin.location < end else { return }
                let text = String(bases[lin.location..<end])
                SequenceClipboard.copyPlainText(text)
                apply(linearLoc: lin.location, linearLen: lin.length, replacement: "", on: tv)
            } else if lin.location < bases.count {
                SequenceClipboard.copyPlainText(String(bases[lin.location]))
                apply(linearLoc: lin.location, linearLen: 1, replacement: "", on: tv)
            }
        }

        func performDeleteFromMenu() {
            guard let tv = textView else { return }
            let lin = currentLinearSelection()
            if lin.length > 0 {
                apply(linearLoc: lin.location, linearLen: lin.length, replacement: "", on: tv)
            } else if lin.location < parent.edited.bases.count {
                apply(linearLoc: lin.location, linearLen: 1, replacement: "", on: tv)
            }
        }

        func performReplaceNFromMenu() {
            guard let tv = textView else { return }
            let lin = currentLinearSelection()
            if lin.length > 0 {
                let repl = String(repeating: "N", count: lin.length)
                apply(linearLoc: lin.location, linearLen: lin.length, replacement: repl, on: tv)
            } else if lin.location < parent.edited.bases.count {
                apply(linearLoc: lin.location, linearLen: 1, replacement: "N", on: tv)
            }
        }

        private func apply(linearLoc: Int, linearLen: Int, replacement: String, on tv: NSTextView) {
            let repl = replacement.replacingOccurrences(of: "\n", with: "")
            var next = parent.edited
            next.applyLinearEdit(location: linearLoc, length: linearLen, replacement: repl)
            parent.edited = next

            let newWrapped = SequenceWrapMath.wrapText(String(next.bases), lineLength: parent.lineLength)
            isProgrammaticStringUpdate = true
            setWrappedAttributed(newWrapped, on: tv)
            isProgrammaticStringUpdate = false

            let newLinearPos = linearLoc + repl.count
            let clamped = max(0, min(newLinearPos, next.bases.count))
            let newSel = NSRange(location: clamped, length: 0)
            parent.selectedUnwrapped = newSel
            let wrappedSel = SequenceWrapMath.wrappedRange(fromUnwrapped: newSel, in: newWrapped)
            isProgrammaticSelectionUpdate = true
            tv.setSelectedRange(wrappedSel)
            isProgrammaticSelectionUpdate = false
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            let repl = (replacementString ?? "").replacingOccurrences(of: "\n", with: "")
            let wrapped = textView.string as NSString
            let (linearLoc, linearLen) = SequenceWrapMath.wrappedToLinear(wrapped as String, affectedRange: affectedCharRange)
            apply(linearLoc: linearLoc, linearLen: linearLen, replacement: repl, on: textView)
            return false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView, !isProgrammaticSelectionUpdate, !isProgrammaticStringUpdate else { return }
            let wrapped = tv.string as NSString
            let wr = tv.selectedRange()
            let linear = SequenceWrapMath.linearRange(fromWrappedSelection: wr, in: wrapped as String)
            if parent.selectedUnwrapped != linear {
                parent.selectedUnwrapped = linear
            }
        }
    }
}
