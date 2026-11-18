import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
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
    /// copyright and credits come from `AppInfo`.
    @objc func showAbout(_ sender: Any?) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let body: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let credits = NSMutableAttributedString(string: "Created by ", attributes: body)
        credits.append(NSAttributedString(string: AppInfo.author, attributes: body.merging([
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]) { $1 }))

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .version: "",   // the build number equals the version; don't repeat it in parentheses
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): AppInfo.copyright,
        ])
        NSApp.activate()
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(sender)
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
