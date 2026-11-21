//
//  MarkdownDocument.swift
//  Markdown
//
//  Copyright © 2026 Advandz Technologies, LLC.
//

import AppKit
import UniformTypeIdentifiers

/// A Markdown file. The editor's text view owns the live text; the document
/// only holds the text that was read until its window is created.
@objc(MarkdownDocument)
final class MarkdownDocument: NSDocument {
    static let markdownType = "net.daringfireball.markdown"

    var initialText = ""
    var initialMode: ViewMode?
    private(set) var model: EditorModel?

    override class var autosavesInPlace: Bool { true }

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }

    override func makeWindowControllers() {
        MainActor.assumeIsolated {
            let mode = initialMode ?? (fileURL == nil ? .split : Preferences.defaultOpenMode)
            let model = EditorModel(text: initialText, mode: mode, document: self)
            self.model = model
            addWindowController(DocumentWindowController(model: model))
        }
    }

    // MARK: Reading & writing

    override func read(from data: Data, ofType typeName: String) throws {
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        // Reverting or reloading after an external change: update the live editor.
        if Thread.isMainThread {
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let model = self.model else { return false }
                model.replaceAllText(text)
                return true
            }
            if handled { return }
        }
        initialText = text
    }

    override func data(ofType typeName: String) throws -> Data {
        var text = initialText
        if Thread.isMainThread {
            text = MainActor.assumeIsolated { self.model?.text ?? self.initialText }
        }
        return Data(text.utf8)
    }

    override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
        if typeName == Self.markdownType { return "md" }
        return super.fileNameExtension(forType: typeName, saveOperation: saveOperation)
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.isExtensionHidden = false
        savePanel.canSelectHiddenExtension = true
        return true
    }

    override var fileURL: URL? {
        didSet {
            let url = fileURL
            if Thread.isMainThread {
                MainActor.assumeIsolated { model?.documentURLDidChange(url) }
            }
        }
    }

    // MARK: Printing & export

    /// Keeps the offscreen renderer alive while a print or export runs.
    private var activeRenderer: AnyObject?

    private var baseName: String { (displayName as NSString).deletingPathExtension }

    override func printDocument(_ sender: Any?) {
        runPrintOperation(savingTo: nil)
    }

    @objc func exportPDF(_ sender: Any?) {
        MainActor.assumeIsolated {
            guard let window = windowControllers.first?.window else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = baseName + ".pdf"
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                // Let the save sheet finish closing before the export sheet appears.
                DispatchQueue.main.async { self.runPrintOperation(savingTo: url) }
            }
        }
    }

    /// Prints, or writes a paginated PDF when `url` is given.
    private func runPrintOperation(savingTo url: URL?) {
        MainActor.assumeIsolated {
            guard activeRenderer == nil, let model, let window = windowControllers.first?.window else { return }

            let info = printInfo.copy() as! NSPrintInfo
            info.horizontalPagination = .fit
            info.verticalPagination = .automatic
            info.isHorizontallyCentered = false
            info.isVerticallyCentered = false
            info.topMargin = 54; info.bottomMargin = 54
            info.leftMargin = 60; info.rightMargin = 60
            if let url {
                info.jobDisposition = .save
                info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
            }

            let base = LocalResources.baseURL(for: fileURL?.deletingLastPathComponent())
            let html = PreviewTheme.page(body: MarkdownRenderer.html(from: model.text), title: baseName, baseURL: base)
            let renderer = PrintRenderer(width: info.paperSize.width - info.leftMargin - info.rightMargin)
            activeRenderer = renderer

            Task { @MainActor in
                do {
                    try await renderer.load(html: html, baseURL: base)
                } catch {
                    self.finishPrinting()
                    self.presentError(error)
                    return
                }
                let operation = renderer.printOperation(with: info)
                operation.jobTitle = self.baseName
                operation.showsPrintPanel = url == nil
                operation.showsProgressPanel = true
                operation.printPanel.options.formUnion([.showsPaperSize, .showsOrientation, .showsScaling])
                operation.runModal(for: window, delegate: self,
                                   didRun: #selector(self.printOperationDidRun(_:success:contextInfo:)),
                                   contextInfo: nil)
            }
        }
    }

    @objc private func printOperationDidRun(_ operation: NSPrintOperation, success: Bool,
                                            contextInfo: UnsafeMutableRawPointer?) {
        finishPrinting()
    }

    private func finishPrinting() {
        MainActor.assumeIsolated {
            (activeRenderer as? PrintRenderer)?.cleanUp()
            activeRenderer = nil
        }
    }

    @objc func exportHTML(_ sender: Any?) {
        MainActor.assumeIsolated {
            guard let model, let window = windowControllers.first?.window else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.html]
            panel.nameFieldStringValue = baseName + ".html"
            panel.canCreateDirectories = true
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                let html = PreviewTheme.page(body: MarkdownRenderer.html(from: model.text), title: self.baseName)
                do {
                    try html.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self.presentError(error)
                }
            }
        }
    }

    @objc func copyHTML(_ sender: Any?) {
        MainActor.assumeIsolated {
            guard let model else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(MarkdownRenderer.html(from: model.text), forType: .string)
        }
    }
}
