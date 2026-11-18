import AppKit

/// Builds the menu bar in code (there's no nib in this project).
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu: appMenu())
        main.addItem(submenu: fileMenu())
        main.addItem(submenu: editMenu())
        main.addItem(submenu: formatMenu())
        main.addItem(submenu: viewMenu())
        let window = windowMenu()
        main.addItem(submenu: window)
        NSApp.windowsMenu = window
        let help = helpMenu()
        main.addItem(submenu: help)
        NSApp.helpMenu = help
        return main
    }

    private static let appName = "Markdown"

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: appName)
        menu.addItem("About \(appName)", #selector(AppDelegate.showAbout(_:)))
        menu.addItem("Check for Updates…", #selector(Updater.checkForUpdates(_:))).target = Updater.shared
        menu.addItem(.separator())
        menu.addItem("Settings…", #selector(AppDelegate.showSettings(_:)), ",")
        menu.addItem(.separator())
        let services = NSMenu(title: "Services")
        menu.addItem(submenu: services)
        NSApp.servicesMenu = services
        menu.addItem(.separator())
        menu.addItem("Hide \(appName)", #selector(NSApplication.hide(_:)), "h")
        menu.addItem("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
        menu.addItem("Show All", #selector(NSApplication.unhideAllApplications(_:)))
        menu.addItem(.separator())
        menu.addItem("Quit \(appName)", #selector(NSApplication.terminate(_:)), "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem("New", #selector(NSDocumentController.newDocument(_:)), "n")
        menu.addItem("Open…", #selector(NSDocumentController.openDocument(_:)), "o")
        menu.addItem(.separator())
        menu.addItem("Close", #selector(NSWindow.performClose(_:)), "w")
        menu.addItem("Save…", #selector(NSDocument.save(_:)), "s")
        menu.addItem("Duplicate", #selector(NSDocument.duplicate(_:)), "s", [.command, .shift])
        menu.addItem("Rename…", #selector(NSDocument.rename(_:)))
        menu.addItem("Move To…", #selector(NSDocument.move(_:)))
        menu.addItem("Revert to Saved", #selector(NSDocument.revertToSaved(_:)))
        menu.addItem(.separator())
        menu.addItem("Export as PDF…", #selector(MarkdownDocument.exportPDF(_:)), "e", [.command, .option])
        menu.addItem("Export as HTML…", #selector(MarkdownDocument.exportHTML(_:)), "e", [.command, .shift])
        menu.addItem("Copy HTML", #selector(MarkdownDocument.copyHTML(_:)), "c", [.command, .option, .shift])
        menu.addItem(.separator())
        menu.addItem("Page Setup…", #selector(NSDocument.runPageLayout(_:)), "p", [.command, .shift])
        menu.addItem("Print…", #selector(NSDocument.printDocument(_:)), "p")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem("Undo", Selector(("undo:")), "z")
        menu.addItem("Redo", Selector(("redo:")), "z", [.command, .shift])
        menu.addItem(.separator())
        menu.addItem("Cut", #selector(NSText.cut(_:)), "x")
        menu.addItem("Copy", #selector(NSText.copy(_:)), "c")
        menu.addItem("Paste", #selector(NSText.paste(_:)), "v")
        menu.addItem("Paste and Match Style", #selector(NSTextView.pasteAsPlainText(_:)), "v", [.command, .option, .shift])
        menu.addItem("Delete", #selector(NSText.delete(_:)))
        menu.addItem("Select All", #selector(NSText.selectAll(_:)), "a")
        menu.addItem(.separator())

        let find = NSMenu(title: "Find")
        typealias W = DocumentWindowController
        find.addItem("Find…", #selector(W.focusSearch(_:)), "f")
        find.addItem("Find and Replace…", #selector(NSTextView.performFindPanelAction(_:)), "f", [.command, .option], tag: 12)
        find.addItem("Find Next", #selector(W.findNextMatch(_:)), "g")
        find.addItem("Find Previous", #selector(W.findPreviousMatch(_:)), "g", [.command, .shift])
        find.addItem("Use Selection for Find", #selector(W.useSelectionForFind(_:)), "e")
        find.addItem("Jump to Selection", #selector(NSResponder.centerSelectionInVisibleArea(_:)), "j")
        menu.addItem(submenu: find)

        let spelling = NSMenu(title: "Spelling and Grammar")
        spelling.addItem("Show Spelling and Grammar", #selector(NSText.showGuessPanel(_:)), ":")
        spelling.addItem("Check Document Now", #selector(NSText.checkSpelling(_:)), ";")
        spelling.addItem("Check Spelling While Typing", #selector(NSTextView.toggleContinuousSpellChecking(_:)))
        menu.addItem(submenu: spelling)

        let transformations = NSMenu(title: "Transformations")
        transformations.addItem("Make Upper Case", #selector(NSResponder.uppercaseWord(_:)))
        transformations.addItem("Make Lower Case", #selector(NSResponder.lowercaseWord(_:)))
        transformations.addItem("Capitalize", #selector(NSResponder.capitalizeWord(_:)))
        menu.addItem(submenu: transformations)
        return menu
    }

    private static func formatMenu() -> NSMenu {
        typealias T = MarkdownTextView
        let menu = NSMenu(title: "Format")
        menu.addItem("Bold", #selector(T.mdBold(_:)), "b")
        menu.addItem("Italic", #selector(T.mdItalic(_:)), "i")
        menu.addItem("Strikethrough", #selector(T.mdStrikethrough(_:)), "x", [.command, .shift])
        menu.addItem("Code", #selector(T.mdInlineCode(_:)), "c", [.command, .option])
        menu.addItem("Link…", #selector(T.mdLink(_:)), "k")
        menu.addItem(.separator())
        menu.addItem("Heading 1", #selector(T.mdHeading1(_:)), "1", [.command, .option])
        menu.addItem("Heading 2", #selector(T.mdHeading2(_:)), "2", [.command, .option])
        menu.addItem("Heading 3", #selector(T.mdHeading3(_:)), "3", [.command, .option])
        menu.addItem("Body", #selector(T.mdBody(_:)), "0", [.command, .option])
        menu.addItem(.separator())
        menu.addItem("Bulleted List", #selector(T.mdBulletList(_:)), "8", [.command, .shift])
        menu.addItem("Numbered List", #selector(T.mdNumberedList(_:)), "9", [.command, .shift])
        menu.addItem("Checklist", #selector(T.mdChecklist(_:)), "l", [.command, .shift])
        menu.addItem("Quote", #selector(T.mdQuote(_:)), "'")
        menu.addItem("Code Block", #selector(T.mdCodeBlock(_:)), "b", [.command, .option])
        menu.addItem("Divider", #selector(T.mdHorizontalRule(_:)), "-", [.command, .option])
        return menu
    }

    private static func viewMenu() -> NSMenu {
        typealias W = DocumentWindowController
        let menu = NSMenu(title: "View")
        menu.addItem("Editor", #selector(W.showEditor(_:)), "1")
        menu.addItem("Split", #selector(W.showSplit(_:)), "2")
        menu.addItem("Preview", #selector(W.showPreview(_:)), "3")
        menu.addItem("Next View", #selector(W.cycleViewMode(_:)), "\\", [.command])
        menu.addItem(.separator())
        menu.addItem("Show Word Count", #selector(W.toggleWordCount(_:)))
        menu.addItem(.separator())
        menu.addItem("Bigger", #selector(W.zoomIn(_:)), "+")
        menu.addItem("Smaller", #selector(W.zoomOut(_:)), "-")
        menu.addItem("Actual Size", #selector(W.zoomReset(_:)), "0")
        menu.addItem(.separator())
        menu.addItem("Show Toolbar", #selector(NSWindow.toggleToolbarShown(_:)), "t", [.command, .option])
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        menu.addItem("Zoom", #selector(NSWindow.performZoom(_:)))
        menu.addItem(.separator())
        menu.addItem("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        menu.addItem("Markdown Guide", #selector(AppDelegate.showMarkdownGuide(_:)), "?")
        return menu
    }
}

private extension NSMenu {
    @discardableResult
    func addItem(_ title: String, _ action: Selector?, _ key: String = "",
                 _ modifiers: NSEvent.ModifierFlags = [.command], tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        item.tag = tag
        addItem(item)
        return item
    }

    func addItem(submenu: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
