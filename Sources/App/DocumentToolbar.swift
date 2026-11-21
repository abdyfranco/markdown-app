//
//  DocumentToolbar.swift
//  Markdown
//
//  Copyright © 2026 Advandz Technologies, LLC.
//

import AppKit
import SwiftUI

/// The window toolbar: the view switcher in the centre, Format and Share
/// menus, and a search field at the trailing edge (like Preview).
/// Built with AppKit so every item gets the system's Liquid Glass treatment.
extension DocumentWindowController: NSToolbarDelegate, NSSearchFieldDelegate {

    enum ToolbarID {
        static let mode = NSToolbarItem.Identifier("view-mode")
        static let format = NSToolbarItem.Identifier("format")
        static let share = NSToolbarItem.Identifier("share")
        static let search = NSToolbarItem.Identifier("search")
    }

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "MarkdownDocumentToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [ToolbarID.mode]
        return toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, ToolbarID.mode, .flexibleSpace, ToolbarID.format, ToolbarID.share, ToolbarID.search]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        MainActor.assumeIsolated {
            switch identifier {
            case ToolbarID.mode: return makeModeItem()
            case ToolbarID.format: return makeFormatItem()
            case ToolbarID.share: return makeShareItem()
            case ToolbarID.search: return makeSearchItem()
            default: return nil
            }
        }
    }

    // MARK: Items

    @MainActor
    private func makeModeItem() -> NSToolbarItem {
        let modes = ViewMode.allCases
        let group = NSToolbarItemGroup(
            itemIdentifier: ToolbarID.mode,
            images: modes.map { symbol($0.symbol, $0.title) },
            selectionMode: .selectOne,
            labels: modes.map(\.title),
            target: self,
            action: #selector(modeControlChanged(_:))
        )
        group.label = String(localized: "View")
        group.controlRepresentation = .expanded
        for (item, mode) in zip(group.subitems, modes) {
            item.toolTip = "\(mode.title) (⌘\(mode.shortcut))"
        }
        group.selectedIndex = modes.firstIndex(of: model.mode) ?? 0
        modeItem = group
        return group
    }

    @MainActor
    private func makeFormatItem() -> NSToolbarItem {
        typealias T = MarkdownTextView
        let entries: [(String.LocalizationValue?, String, Selector)] = [
            ("Bold", "bold", #selector(T.mdBold(_:))),
            ("Italic", "italic", #selector(T.mdItalic(_:))),
            ("Strikethrough", "strikethrough", #selector(T.mdStrikethrough(_:))),
            ("Code", "chevron.left.forwardslash.chevron.right", #selector(T.mdInlineCode(_:))),
            ("Link", "link", #selector(T.mdLink(_:))),
            (nil, "", #selector(T.mdBold(_:))),
            ("Heading 1", "textformat.size.larger", #selector(T.mdHeading1(_:))),
            ("Heading 2", "textformat.size", #selector(T.mdHeading2(_:))),
            ("Heading 3", "textformat.size.smaller", #selector(T.mdHeading3(_:))),
            (nil, "", #selector(T.mdBold(_:))),
            ("Bulleted List", "list.bullet", #selector(T.mdBulletList(_:))),
            ("Numbered List", "list.number", #selector(T.mdNumberedList(_:))),
            ("Checklist", "checklist", #selector(T.mdChecklist(_:))),
            ("Quote", "text.quote", #selector(T.mdQuote(_:))),
            ("Code Block", "curlybraces", #selector(T.mdCodeBlock(_:))),
            ("Divider", "minus", #selector(T.mdHorizontalRule(_:))),
        ]
        let menu = NSMenu()
        for (title, image, action) in entries {
            guard let title = title.map({ String(localized: $0) }) else { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: title, action: #selector(applyFormat(_:)), keyEquivalent: "")
            item.target = self
            item.image = symbol(image, title)
            item.representedObject = NSStringFromSelector(action)
            menu.addItem(item)
        }
        let item = NSMenuToolbarItem(itemIdentifier: ToolbarID.format)
        item.label = String(localized: "Format")
        item.toolTip = item.label
        item.image = symbol("textformat", item.label)
        item.showsIndicator = false
        item.menu = menu
        item.isEnabled = model.mode != .preview
        formatItem = item
        return item
    }

    @MainActor
    private func makeShareItem() -> NSToolbarItem {
        let menu = NSMenu()
        let entries: [(String.LocalizationValue?, String, Selector)] = [
            ("Export as PDF…", "doc.text", #selector(MarkdownDocument.exportPDF(_:))),
            ("Export as HTML…", "chevron.left.forwardslash.chevron.right", #selector(MarkdownDocument.exportHTML(_:))),
            ("Copy HTML", "doc.on.doc", #selector(MarkdownDocument.copyHTML(_:))),
            (nil, "", #selector(MarkdownDocument.copyHTML(_:))),
            ("Print…", "printer", #selector(NSDocument.printDocument(_:))),
        ]
        for (title, image, action) in entries {
            guard let title = title.map({ String(localized: $0) }) else { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = model.document
            item.image = symbol(image, title)
            menu.addItem(item)
        }
        let item = NSMenuToolbarItem(itemIdentifier: ToolbarID.share)
        item.label = String(localized: "Share")
        item.toolTip = String(localized: "Export and print")
        item.image = symbol("square.and.arrow.up", item.label)
        item.showsIndicator = false
        item.menu = menu
        return item
    }

    /// Search field widths: compact while idle, wider while focused or in use.
    enum SearchWidth {
        static let idle: CGFloat = 190
        static let active: CGFloat = 290
    }

    @MainActor
    private func makeSearchItem() -> NSToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: ToolbarID.search)
        item.label = String(localized: "Search")
        let field = ExpandingSearchField()
        item.searchField = field
        field.placeholderString = item.label
        field.sendsSearchStringImmediately = true
        field.target = self
        field.action = #selector(searchFieldChanged(_:))
        field.delegate = self
        field.stringValue = model.searchText
        field.onEditingChange = { [weak self] _ in self?.updateSearchFieldWidth(animated: true) }
        item.preferredWidthForSearchField = SearchWidth.idle
        // The toolbar would otherwise stretch the field into all the free space.
        let maxWidth = field.widthAnchor.constraint(lessThanOrEqualToConstant: SearchWidth.idle)
        maxWidth.isActive = true
        searchMaxWidth = maxWidth
        searchItem = item
        return item
    }

    /// Expands the field while it has focus or holds a query; shrinks it back otherwise.
    @MainActor
    func updateSearchFieldWidth(animated: Bool) {
        guard let item = searchItem else { return }
        let field = item.searchField
        let isEditing = (field as? ExpandingSearchField)?.isEditing ?? false
        let target = isEditing || !field.stringValue.isEmpty ? SearchWidth.active : SearchWidth.idle
        guard item.preferredWidthForSearchField != target else { return }
        guard animated, let container = field.window?.contentView?.superview else {
            item.preferredWidthForSearchField = target
            searchMaxWidth?.constant = target
            return
        }
        // The toolbar lives in the window's frame view (the content view's superview).
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            item.preferredWidthForSearchField = target
            searchMaxWidth?.animator().constant = target
            container.layoutSubtreeIfNeeded()
        }
    }

    private func symbol(_ name: String, _ description: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: description) ?? NSImage()
    }

    // MARK: Actions

    @objc func modeControlChanged(_ sender: NSToolbarItemGroup) {
        let modes = ViewMode.allCases
        guard modes.indices.contains(sender.selectedIndex) else { return }
        MainActor.assumeIsolated {
            withAnimation(.smooth(duration: 0.25)) { model.mode = modes[sender.selectedIndex] }
        }
    }

    @objc func applyFormat(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        MainActor.assumeIsolated {
            let textView = model.textView
            guard model.mode != .preview, let window = textView.window else { return }
            window.makeFirstResponder(textView)
            textView.perform(NSSelectorFromString(name), with: nil)
        }
    }

    /// Every edit in the field, including the ✕ button, lands here.
    @objc func searchFieldChanged(_ sender: NSSearchField) {
        MainActor.assumeIsolated {
            if model.searchText != sender.stringValue { model.searchText = sender.stringValue }
            updateSearchFieldWidth(animated: true)
        }
    }

    /// Return finds the next match, Shift-Return the previous one.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        let backwards = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
        MainActor.assumeIsolated {
            if let field = control as? NSSearchField, model.searchText != field.stringValue {
                model.searchText = field.stringValue
            }
            model.findNext(backwards: backwards)
        }
        return true
    }

    // MARK: Model → toolbar

    @MainActor
    func toolbarModeDidChange(_ mode: ViewMode) {
        modeItem?.selectedIndex = ViewMode.allCases.firstIndex(of: mode) ?? 0
        formatItem?.isEnabled = mode != .preview
    }

    @MainActor
    func toolbarSearchTextDidChange(_ text: String) {
        if let field = searchItem?.searchField, field.stringValue != text {
            field.stringValue = text
        }
        updateSearchFieldWidth(animated: true)
    }

    @MainActor
    func focusSearchField() {
        guard let item = searchItem else { return }
        window?.makeKeyAndOrderFront(nil)
        item.beginSearchInteraction()
    }
}

/// A search field that reports when it starts and stops being edited,
/// so the toolbar can expand it on focus and shrink it when idle.
final class ExpandingSearchField: NSSearchField {
    var onEditingChange: ((Bool) -> Void)?
    private(set) var isEditing = false

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { setEditing(true) }
        return accepted
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        setEditing(false)
    }

    private func setEditing(_ editing: Bool) {
        guard editing != isEditing else { return }
        isEditing = editing
        onEditingChange?(editing)
    }
}
