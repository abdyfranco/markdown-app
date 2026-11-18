import AppKit
import WebKit

/// Owns the preview web view. The page shell is loaded once; edits are
/// pushed in by replacing the article's HTML, which keeps the scroll position.
@MainActor
final class PreviewController: NSObject, WKNavigationDelegate {
    let webView: WKWebView

    private let shellURL: URL
    private var baseURL: URL?
    private var currentHTML = ""
    private var isLoaded = false

    var zoom: CGFloat = 1 {
        didSet { if webView.pageZoom != zoom { webView.pageZoom = zoom } }
    }

    private static let appCSS = """
    .markdown-body { padding-top: 36px; }
    #content:empty::before {
      content: "Nothing to preview yet";
      display: block;
      margin-top: 32vh;
      text-align: center;
      font-size: 15px;
      color: var(--tertiary);
    }
    """

    init(baseURL: URL?) {
        self.baseURL = baseURL
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        shellURL = directory.appendingPathComponent(UUID().uuidString + ".html")

        let configuration = WKWebViewConfiguration()
        // Documents may contain raw HTML: never run scripts from content.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = false
        webView.setAccessibilityLabel("Preview")
        loadShell()
    }

    isolated deinit {
        try? FileManager.default.removeItem(at: shellURL)
    }

    private func loadShell() {
        isLoaded = false
        let base = baseURL ?? FileManager.default.homeDirectoryForCurrentUser
        let page = PreviewTheme.page(body: currentHTML, baseURL: base, extraCSS: Self.appCSS)
        do {
            try page.write(to: shellURL, atomically: true, encoding: .utf8)
            // Read access lets relative images next to the document load.
            webView.loadFileURL(shellURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        } catch {
            webView.loadHTMLString(page, baseURL: base)
        }
    }

    // MARK: Content

    func setContent(_ html: String) {
        guard html != currentHTML else { return }
        currentHTML = html
        guard isLoaded else { return }
        run("document.getElementById('content').innerHTML = \(Self.json(html));")
    }

    func setBaseURL(_ url: URL?) {
        guard url?.standardizedFileURL != baseURL?.standardizedFileURL else { return }
        baseURL = url
        loadShell()
    }

    func setTopInset(_ inset: CGFloat) {
        let insets = NSEdgeInsets(top: inset, left: 0, bottom: 0, right: 0)
        if webView.obscuredContentInsets.top != inset {
            webView.obscuredContentInsets = insets
        }
    }

    func scroll(toFraction fraction: CGFloat) {
        guard isLoaded else { return }
        run("(function(){var e=document.scrollingElement;e.scrollTop=\(fraction)*(e.scrollHeight-e.clientHeight);})();")
    }

    // MARK: Search

    func find(_ query: String, backwards: Bool = false) {
        guard isLoaded, !query.isEmpty else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        webView.find(query, configuration: configuration) { _ in }
    }

    /// Counts case-insensitive occurrences in the rendered text.
    func countMatches(_ query: String, completion: @escaping (Int) -> Void) {
        guard isLoaded, !query.isEmpty else { completion(0); return }
        let script = """
        (function(q){var t=(document.getElementById('content')||document.body).innerText.toLowerCase();\
        q=q.toLowerCase();var n=0,i=0;while(q&&(i=t.indexOf(q,i))!==-1){n++;i+=q.length;}return n;})(\(Self.json(query)))
        """
        webView.evaluateJavaScript(script, in: nil, in: .defaultClient) { result in
            if case .success(let value) = result, let number = value as? NSNumber {
                completion(number.intValue)
            } else {
                completion(0)
            }
        }
    }

    func selectedText(completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("window.getSelection().toString()", in: nil, in: .defaultClient) { result in
            if case .success(let value) = result, let text = value as? String { completion(text) } else { completion("") }
        }
    }

    func clearFind() {
        guard isLoaded else { return }
        run("window.getSelection().removeAllRanges();")
    }

    private func run(_ script: String) {
        webView.evaluateJavaScript(script, in: nil, in: .defaultClient) { _ in }
    }

    private static func json(_ string: String) -> String {
        guard let data = try? JSONEncoder().encode(string),
              let encoded = String(data: data, encoding: .utf8) else { return "\"\"" }
        return encoded
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        webView.pageZoom = zoom
        // The shell may have been written before the latest render arrived.
        run("document.getElementById('content').innerHTML = \(Self.json(currentHTML));")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }

        if url.isFileURL, url.standardizedFileURL.path == shellURL.standardizedFileURL.path,
           navigationAction.navigationType != .linkActivated {
            return .allow
        }
        guard navigationAction.navigationType == .linkActivated else {
            return url.scheme == "about" ? .allow : .cancel
        }
        open(url)
        return .cancel
    }

    private func open(_ url: URL) {
        if url.isFileURL {
            let base = (baseURL ?? FileManager.default.homeDirectoryForCurrentUser).standardizedFileURL.path
            let path = url.standardizedFileURL.path
            if let fragment = url.fragment(percentEncoded: false), path == base || path == shellURL.path {
                run("var t=document.getElementById(\(Self.json(fragment)));if(t){t.scrollIntoView({behavior:'smooth',block:'start'});}")
                return
            }
            let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "mdtext"]
            if markdownExtensions.contains(url.pathExtension.lowercased()) {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                return
            }
        }
        NSWorkspace.shared.open(url)
    }
}
