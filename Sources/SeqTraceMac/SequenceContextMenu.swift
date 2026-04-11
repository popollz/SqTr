import AppKit

/// Builds the custom sequence context menu (Cut, Copy, Delete, Replace with N, optional F/R). Used from `NSTextViewDelegate.textView(_:menu:for:at:)`.
enum SequenceContextMenu {
    enum Style {
        case singleFile
        case pairConsensus
    }

    static func makeMenu(proxy: SequenceMenuProxy, style: Style) -> NSMenu {
        let menu = NSMenu(title: "Sequence")

        let cutItem = NSMenuItem(
            title: "Cut",
            action: #selector(SequenceMenuProxy.seqMenuCut(_:)),
            keyEquivalent: ""
        )
        cutItem.target = proxy

        let copyItem = NSMenuItem(
            title: "Copy",
            action: #selector(SequenceMenuProxy.seqMenuCopySelection(_:)),
            keyEquivalent: ""
        )
        copyItem.target = proxy

        let deleteItem = NSMenuItem(
            title: "Delete",
            action: #selector(SequenceMenuProxy.seqMenuDelete(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = proxy

        let replaceNItem = NSMenuItem(
            title: "Replace with N",
            action: #selector(SequenceMenuProxy.seqMenuReplaceN(_:)),
            keyEquivalent: ""
        )
        replaceNItem.target = proxy

        menu.addItem(cutItem)
        menu.addItem(copyItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(deleteItem)
        menu.addItem(replaceNItem)

        if style == .pairConsensus {
            let fItem = NSMenuItem(
                title: "Use Forward base",
                action: #selector(SequenceMenuProxy.seqMenuUseForward(_:)),
                keyEquivalent: ""
            )
            fItem.target = proxy
            let rItem = NSMenuItem(
                title: "Use Reverse base",
                action: #selector(SequenceMenuProxy.seqMenuUseReverse(_:)),
                keyEquivalent: ""
            )
            rItem.target = proxy
            menu.addItem(NSMenuItem.separator())
            menu.addItem(fItem)
            menu.addItem(rItem)
        }

        return menu
    }
}
