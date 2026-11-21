//
//  DocumentWindowController.swift
//  Markdown
//
//  Copyright © 2026 Advandz Technologies, LLC.
//

import AppKit
import SwiftUI

final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    let model: EditorModel

    // Toolbar items kept for updates (see DocumentToolbar.swift).
    var modeItem: NSToolbarItemGroup?
    var formatItem: NSMenuToolbarItem?
    var searchItem: NSSearchToolbarItem?
    var searchMaxWidth: NSLayoutConstraint?

    @MainActor
    init(model: EditorModel) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .automatic
        window.minSize = NSSize(width: 520, height: 360)
        window.tabbingMode = .automatic
        window.collectionBehavior.insert(.fullScreenPrimary)

        let hosting = NSHostingController(rootView: ContentView(model: model))
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 1040, height: 760))

        super.init(window: window)
        window.delegate = self
        window.toolbar = makeToolbar()

        model.onModeChange = { [weak self] mode in self?.toolbarModeDidChange(mode) }
        model.onSearchTextChange = { [weak self] text in self?.toolbarSearchTextDidChange(text) }
        model.onSearchFocusRequest = { [weak self] in self?.focusSearchField() }
        Self.place(window)
    }

    /// Centers the first window, then cascades new ones from the key window.
    private static func place(_ window: NSWindow) {
        if let anchor = NSApp.keyWindow ?? NSApp.mainWindow,
           anchor.windowController is DocumentWindowController {
            // Passing .zero returns the next cascade point without moving the anchor.
            window.setFrameTopLeftPoint(anchor.cascadeTopLeft(from: .zero))
        } else {
            window.center()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        MainActor.assumeIsolated {
            if model.mode != .preview {
                window?.makeFirstResponder(model.textView)
            }
        }
    }

    // MARK: View mode actions (⌘1 / ⌘2 / ⌘3)

    @objc func showEditor(_ sender: Any?) { setMode(.edit) }
    @objc func showSplit(_ sender: Any?) { setMode(.split) }
    @objc func showPreview(_ sender: Any?) { setMode(.preview) }

    @objc func cycleViewMode(_ sender: Any?) {
        MainActor.assumeIsolated {
            let all = ViewMode.allCases
            let index = all.firstIndex(of: model.mode) ?? 0
            model.mode = all[(index + 1) % all.count]
        }
    }

    // MARK: Search (⌘F / ⌘G / ⇧⌘G / ⌘E)

    @objc func focusSearch(_ sender: Any?) {
        MainActor.assumeIsolated { model.requestSearchFocus() }
    }

    @objc func findNextMatch(_ sender: Any?) {
        MainActor.assumeIsolated { model.findNext() }
    }

    @objc func findPreviousMatch(_ sender: Any?) {
        MainActor.assumeIsolated { model.findNext(backwards: true) }
    }

    @objc func useSelectionForFind(_ sender: Any?) {
        MainActor.assumeIsolated { model.useSelectionForSearch() }
    }

    @objc func zoomIn(_ sender: Any?) { Preferences.adjustFontSize(by: 1) }
    @objc func zoomOut(_ sender: Any?) { Preferences.adjustFontSize(by: -1) }
    @objc func zoomReset(_ sender: Any?) { Preferences.adjustFontSize(by: 0) }

    @objc func toggleWordCount(_ sender: Any?) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: Preferences.showWordCount), forKey: Preferences.showWordCount)
    }

    private func setMode(_ mode: ViewMode) {
        MainActor.assumeIsolated {
            withAnimation(.smooth(duration: 0.25)) { model.mode = mode }
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        MainActor.assumeIsolated {
            switch menuItem.action {
            case #selector(showEditor(_:)): menuItem.state = model.mode == .edit ? .on : .off
            case #selector(showSplit(_:)): menuItem.state = model.mode == .split ? .on : .off
            case #selector(showPreview(_:)): menuItem.state = model.mode == .preview ? .on : .off
            case #selector(toggleWordCount(_:)):
                menuItem.state = UserDefaults.standard.bool(forKey: Preferences.showWordCount) ? .on : .off
            default: break
            }
            return true
        }
    }
}
