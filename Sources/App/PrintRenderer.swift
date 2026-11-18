import AppKit
import WebKit

/// Renders a document into an offscreen web view for printing and PDF export,
/// so both work from any view mode and always use light, print styling.
@MainActor
final class PrintRenderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private let window: NSWindow
    private let pageURL: URL
    private var loadContinuation: CheckedContinuation<Void, Error>?

    init(width: CGFloat) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.shouldPrintBackgrounds = true   // code blocks, checked boxes
        let frame = NSRect(x: 0, y: 0, width: max(width, 320), height: 1000)
        webView = WKWebView(frame: frame, configuration: configuration)
        webView.appearance = NSAppearance(named: .aqua)

        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = webView

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        pageURL = directory.appendingPathComponent("print-\(UUID().uuidString).html")

        super.init()
        webView.navigationDelegate = self
    }

    /// Loads the page and waits until it (and its images) finished loading.
    func load(html: String) async throws {
        try html.write(to: pageURL, atomically: true, encoding: .utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadContinuation = continuation
            webView.loadFileURL(pageURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }
    }

    func printOperation(with info: NSPrintInfo) -> NSPrintOperation {
        let operation = webView.printOperation(with: info)
        if let view = operation.view, view.frame.isEmpty {
            view.frame = NSRect(origin: .zero, size: info.paperSize)
        }
        return operation
    }

    func cleanUp() {
        webView.stopLoading()
        window.contentView = nil
        try? FileManager.default.removeItem(at: pageURL)
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        navigationAction.navigationType == .linkActivated ? .cancel : .allow
    }
}
