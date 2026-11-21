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

    /// Settings is app-modal: the other windows don't take clicks or keys until
    /// it's closed with its close button, ⌘W or Escape.
    @objc func showSettings(_ sender: Any?) {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        guard NSApp.modalWindow !== window else {
            window.makeKeyAndOrderFront(sender)
            return
        }
        window.center()
        NSApp.activate()
        NSApp.runModal(for: window)   // returns once windowWillClose stops the modal session
    }

    private func makeSettingsWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView())
        hosting.sizingOptions = [.preferredContentSize]
        let window = SettingsWindow(contentViewController: hosting)
        window.title = String(localized: "Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
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

/// The Settings window, which closes on Escape like other modal windows.
private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }
}
