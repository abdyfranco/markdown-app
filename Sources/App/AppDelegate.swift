//
//  AppDelegate.swift
//  Markdown
//
//  Copyright © 2026 Advandz Technologies, LLC.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settingsWindow: NSWindow?
    private weak var settingsParent: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        _ = NSDocumentController.shared
        NSApp.mainMenu = MainMenu.make()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Updater.shared.start()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: Actions

    /// The About panel: name, version and icon come from the bundle; the
    /// copyright comes from `AppInfo`.
    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .version: "",   // the build number equals the version; don't repeat it in parentheses
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): AppInfo.copyright,
        ])
        NSApp.activate()
    }

    /// Settings opens as a sheet on the front document window, which it blocks
    /// until Done, Return, Escape or ⌘W closes it. With no document window open,
    /// it's a centered app-modal window instead.
    @objc func showSettings(_ sender: Any?) {
        if let window = settingsWindow {   // already open
            (settingsParent ?? window).makeKeyAndOrderFront(sender)
            return
        }
        if let parent = frontDocumentWindow() {
            let window = makeSettingsWindow(maxHeight: parent.contentLayoutRect.height - 24)
            settingsWindow = window
            settingsParent = parent
            parent.makeKeyAndOrderFront(sender)
            parent.beginSheet(window) { [weak self] _ in
                self?.settingsWindow = nil
                self?.settingsParent = nil
            }
        } else {
            let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
            let window = makeSettingsWindow(maxHeight: screenHeight - 120)
            settingsWindow = window
            window.center()
            NSApp.activate()
            NSApp.runModal(for: window)   // returns once windowWillClose stops the modal session
            settingsWindow = nil
        }
    }

    /// Done, Escape, ⌘W and the close button all end up here.
    private func closeSettings() {
        guard let window = settingsWindow else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }

    private func frontDocumentWindow() -> NSWindow? {
        NSApp.orderedWindows.first {
            $0.windowController?.document != nil && $0.isVisible && !$0.isMiniaturized
        }
    }

    private func makeSettingsWindow(maxHeight: CGFloat) -> NSWindow {
        let close: () -> Void = { [weak self] in self?.closeSettings() }
        let hosting = NSHostingController(rootView: SettingsView(done: close))
        hosting.sizingOptions = [.preferredContentSize]
        if hosting.view.fittingSize.height > maxHeight {
            // Too tall for the window: scroll the form instead of hanging past its bottom.
            hosting.rootView = SettingsView(done: close, height: maxHeight)
        }
        let window = SettingsWindow(contentViewController: hosting)
        window.title = String(localized: "Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.dismiss = close
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === settingsWindow, NSApp.modalWindow === window else { return }
        NSApp.stopModal()
    }

    @objc func showMarkdownGuide(_ sender: Any?) {
        let controller = NSDocumentController.shared
        guard let document = try? controller.makeUntitledDocument(ofType: MarkdownDocument.markdownType)
                as? MarkdownDocument else { return }
        document.initialText = MarkdownGuide.text
        document.initialMode = .split
        controller.addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
    }
}

/// The Settings sheet or window: Escape, ⌘W and the close button do what Done does.
private final class SettingsWindow: NSWindow {
    var dismiss: () -> Void = {}

    override func cancelOperation(_ sender: Any?) { dismiss() }
    override func performClose(_ sender: Any?) { dismiss() }

    // A sheet doesn't get File > Close, so it handles ⌘W itself.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            dismiss()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
