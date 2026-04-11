import AppKit

/// Routes context-menu actions from `SequenceColoredTextView` into Swift closures (avoids @objc on nested coordinators).
final class SequenceMenuProxy: NSObject {
    var onCut: (() -> Void)?
    var onCopySelection: (() -> Void)?
    var onDelete: (() -> Void)?
    var onReplaceN: (() -> Void)?
    var onUseForward: (() -> Void)?
    var onUseReverse: (() -> Void)?

    @objc func seqMenuCut(_ sender: Any?) {
        onCut?()
    }

    @objc func seqMenuCopySelection(_ sender: Any?) {
        onCopySelection?()
    }

    @objc func seqMenuDelete(_ sender: Any?) {
        onDelete?()
    }

    @objc func seqMenuReplaceN(_ sender: Any?) {
        onReplaceN?()
    }

    @objc func seqMenuUseForward(_ sender: Any?) {
        onUseForward?()
    }

    @objc func seqMenuUseReverse(_ sender: Any?) {
        onUseReverse?()
    }
}
