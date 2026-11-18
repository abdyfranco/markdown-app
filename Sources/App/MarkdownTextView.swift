import AppKit

/// Plain-text Markdown editor with live syntax highlighting, a centred
/// reading column, smart list continuation and formatting commands.
final class MarkdownTextView: NSTextView {

    private var theme = EditorTheme()
    private var isHighlighting = false
    var maxColumnWidth: CGFloat = 720

    static func makeScrollable() -> (NSScrollView, MarkdownTextView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = true

        let textView = MarkdownTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0
        textView.configure()

        scrollView.documentView = textView
        return (scrollView, textView)
    }

    private func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        allowsDocumentBackgroundColorChange = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        smartInsertDeleteEnabled = false
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        textColor = .labelColor
        insertionPointColor = .controlAccentColor
        setAccessibilityLabel(String(localized: "Markdown editor"))

        let placeholder = NSAttributedString(string: String(localized: "Start writing…"), attributes: [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: theme.base,
        ])
        if responds(to: NSSelectorFromString("setPlaceholderAttributedString:")) {
            setValue(placeholder, forKey: "placeholderAttributedString")
        }
    }

    // MARK: Preferences & layout

    func applyPreferences() {
        let defaults = UserDefaults.standard
        theme = EditorTheme(font: Preferences.currentFont, size: Preferences.currentFontSize)
        maxColumnWidth = defaults.bool(forKey: Preferences.limitLineWidth) ? 720 : .greatestFiniteMagnitude
        isContinuousSpellCheckingEnabled = defaults.bool(forKey: Preferences.checkSpelling)
        font = theme.base
        typingAttributes = theme.baseAttributes
        defaultParagraphStyle = theme.paragraph
        updateInsets()
        highlightAll()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateInsets(width: newSize.width)
    }

    private func updateInsets(width: CGFloat? = nil) {
        let width = width ?? frame.width
        let horizontal = max(28, (width - maxColumnWidth) / 2)
        let inset = NSSize(width: horizontal.rounded(), height: 28)
        if textContainerInset != inset { textContainerInset = inset }
    }

    // MARK: Highlighting

    /// Fence lines per code block; when this changes, the whole document is re-styled.
    private var fenceSignature: [Int] = []

    func highlightAll() {
        guard let storage = textStorage else { return }
        let blocks = MarkdownHighlighter.fencedBlocks(in: storage.string as NSString)
        fenceSignature = blocks.map(\.fences.count)
        highlight(storage, in: NSRange(location: 0, length: storage.length), blocks: blocks)
    }

    /// Re-styles after an edit. Small documents are re-highlighted in full;
    /// larger ones only around the edited lines, unless a code fence was
    /// added or removed (which changes the styling of everything after it).
    func highlight(editedRange: NSRange) {
        guard let storage = textStorage, !isHighlighting else { return }
        let ns = storage.string as NSString
        let blocks = MarkdownHighlighter.fencedBlocks(in: ns)
        let signature = blocks.map(\.fences.count)
        let structureChanged = signature != fenceSignature
        fenceSignature = signature

        if structureChanged || ns.length < 20_000 {
            highlight(storage, in: NSRange(location: 0, length: ns.length), blocks: blocks)
            return
        }
        let safe = NSIntersectionRange(editedRange, NSRange(location: 0, length: ns.length))
        var range = ns.paragraphRange(for: safe)
        // Include a line either side: setext underlines style the line above.
        if range.location > 0 {
            range = NSUnionRange(range, ns.paragraphRange(for: NSRange(location: range.location - 1, length: 0)))
        }
        if NSMaxRange(range) < ns.length {
            range = NSUnionRange(range, ns.paragraphRange(for: NSRange(location: NSMaxRange(range), length: 0)))
        }
        highlight(storage, in: range, blocks: blocks)
    }

    private func highlight(_ storage: NSTextStorage, in range: NSRange, blocks: [MarkdownHighlighter.FencedBlock]) {
        guard range.length > 0 else { return }
        isHighlighting = true
        defer { isHighlighting = false }
        MarkdownHighlighter.apply(theme: theme, to: storage, in: range, blocks: blocks, matches: searchMatches)
    }

    // MARK: Search

    /// All case- and diacritic-insensitive occurrences of `query`.
    func ranges(of query: String, limit: Int = 5_000) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        let ns = string as NSString
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: ns.length)
        while result.count < limit {
            let found = ns.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
            guard found.location != NSNotFound, found.length > 0 else { break }
            result.append(found)
            let next = NSMaxRange(found)
            searchRange = NSRange(location: next, length: ns.length - next)
        }
        return result
    }

    /// Search matches painted by the highlighter (see `MarkdownHighlighter`).
    private(set) var searchMatches: [NSRange] = []

    /// Updates the highlighted search matches, restyling only what changed.
    func highlightMatches(_ ranges: [NSRange]) {
        guard ranges != searchMatches, let storage = textStorage else { return }
        let previous = searchMatches
        searchMatches = ranges
        let ns = storage.string as NSString
        let changed = previous + ranges
        guard ns.length >= 20_000, changed.count <= 400 else {
            highlightAll()
            return
        }
        let blocks = MarkdownHighlighter.fencedBlocks(in: ns)
        var restyled = IndexSet()
        for range in changed {
            let safe = NSIntersectionRange(range, NSRange(location: 0, length: ns.length))
            let paragraph = ns.paragraphRange(for: safe)
            guard !restyled.contains(integersIn: paragraph.location..<NSMaxRange(paragraph)) else { continue }
            restyled.insert(integersIn: paragraph.location..<NSMaxRange(paragraph))
            highlight(storage, in: paragraph, blocks: blocks)
        }
    }

    func showMatch(_ range: NSRange) {
        setSelectedRange(range)
        scrollRangeToVisible(range)
        showFindIndicator(for: range)
    }

    // MARK: Smart editing

    private static let listPrefix = try! NSRegularExpression(
        pattern: #"^([ \t]*)(?:([-*+])|(\d{1,9})([.)])|(>))([ \t]+)(\[[ xX]\][ \t]+)?"#
    )

    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let selection = selectedRange()
        let lineRange = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        var lineEnd = NSMaxRange(lineRange)
        if lineEnd > lineRange.location, ns.character(at: lineEnd - 1) == 10 { lineEnd -= 1 }
        let line = ns.substring(with: NSRange(location: lineRange.location, length: lineEnd - lineRange.location))

        guard let match = Self.listPrefix.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
              selection.location >= lineRange.location + match.range.length else {
            super.insertNewline(sender)
            return
        }

        let l = line as NSString
        func group(_ i: Int) -> String? {
            let r = match.range(at: i)
            return r.location == NSNotFound ? nil : l.substring(with: r)
        }

        // An empty item ends the list.
        if match.range.length == l.length, selection.length == 0 {
            let prefixRange = NSRange(location: lineRange.location, length: match.range.length)
            replace(prefixRange, with: "", selecting: NSRange(location: lineRange.location, length: 0), actionName: nil)
            return
        }

        let indent = group(1) ?? ""
        var marker = group(2) ?? group(5) ?? ""
        if let number = group(3).flatMap(Int.init), let delimiter = group(4) {
            marker = "\(number + 1)\(delimiter)"
        }
        let spacing = group(6) ?? " "
        let task = group(7) != nil ? "[ ] " : ""
        insertText("\n" + indent + marker + spacing + task, replacementRange: selection)
    }

    override func insertTab(_ sender: Any?) {
        if adjustListIndent(outdent: false) { return }
        super.insertTab(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        if adjustListIndent(outdent: true) { return }
        super.insertBacktab(sender)
    }

    /// Indents or outdents list items touched by the selection.
    private func adjustListIndent(outdent: Bool) -> Bool {
        let ns = string as NSString
        let range = ns.lineRange(for: selectedRange())
        let block = ns.substring(with: range)
        var lines = block.components(separatedBy: "\n")
        let trailingNewline = block.hasSuffix("\n")
        if trailingNewline { lines.removeLast() }
        let isList = lines.allSatisfy { line in
            line.trimmingCharacters(in: .whitespaces).isEmpty ||
            Self.listPrefix.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
        }
        guard isList, !lines.isEmpty else { return false }

        let updated = lines.map { line -> String in
            guard !line.isEmpty else { return line }
            if outdent {
                if line.hasPrefix("    ") { return String(line.dropFirst(4)) }
                if line.hasPrefix("\t") { return String(line.dropFirst()) }
                return String(line.drop(while: { $0 == " " }))
            }
            return "    " + line
        }
        let replacement = updated.joined(separator: "\n") + (trailingNewline ? "\n" : "")
        let delta = (replacement as NSString).length - range.length
        let selection = selectedRange()
        let newLocation = max(range.location, selection.location + (lines.count == 1 ? delta : 0))
        replace(range, with: replacement,
                selecting: lines.count == 1
                    ? NSRange(location: newLocation, length: selection.length)
                    : NSRange(location: range.location, length: (replacement as NSString).length - (trailingNewline ? 1 : 0)),
                actionName: outdent ? String(localized: "Outdent") : String(localized: "Indent"))
        return true
    }

    // MARK: Formatting commands

    @objc func mdBold(_ sender: Any?) {
        toggleWrap("**", placeholder: String(localized: "bold text"), name: String(localized: "Bold"))
    }
    @objc func mdItalic(_ sender: Any?) {
        toggleWrap("*", placeholder: String(localized: "italic text"), name: String(localized: "Italic"))
    }
    @objc func mdStrikethrough(_ sender: Any?) {
        toggleWrap("~~", placeholder: String(localized: "text"), name: String(localized: "Strikethrough"))
    }
    @objc func mdInlineCode(_ sender: Any?) {
        toggleWrap("`", placeholder: String(localized: "code"), name: String(localized: "Code"))
    }

    @objc func mdHeading1(_ sender: Any?) { setHeading(1) }
    @objc func mdHeading2(_ sender: Any?) { setHeading(2) }
    @objc func mdHeading3(_ sender: Any?) { setHeading(3) }
    @objc func mdBody(_ sender: Any?) { setHeading(0) }

    @objc func mdBulletList(_ sender: Any?) { toggleLinePrefix(.bullet) }
    @objc func mdNumberedList(_ sender: Any?) { toggleLinePrefix(.numbered) }
    @objc func mdChecklist(_ sender: Any?) { toggleLinePrefix(.checklist) }
    @objc func mdQuote(_ sender: Any?) { toggleLinePrefix(.quote) }

    @objc func mdLink(_ sender: Any?) {
        let selection = selectedRange()
        let selected = (string as NSString).substring(with: selection)
        let clipboard = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        func isURL(_ s: String?) -> Bool {
            guard let s, !s.contains(" "), let url = URL(string: s), let scheme = url.scheme else { return false }
            return ["http", "https", "mailto"].contains(scheme.lowercased())
        }

        let placeholder = String(localized: "link")
        let actionName = String(localized: "Link")
        if isURL(selected) {
            let text = "[\(placeholder)](\(selected))"
            replace(selection, with: text,
                    selecting: NSRange(location: selection.location + 1, length: (placeholder as NSString).length),
                    actionName: actionName)
        } else {
            let label = selected.isEmpty ? placeholder : selected
            let url = isURL(clipboard) ? clipboard! : "https://"
            let text = "[\(label)](\(url))"
            let labelLength = (label as NSString).length
            let selectRange = selected.isEmpty
                ? NSRange(location: selection.location + 1, length: labelLength)
                : NSRange(location: selection.location + labelLength + 3, length: (url as NSString).length)
            replace(selection, with: text, selecting: selectRange, actionName: actionName)
        }
    }

    @objc func mdCodeBlock(_ sender: Any?) {
        let ns = string as NSString
        let selection = selectedRange()
        if selection.length == 0 {
            let insertion = "```\n\n```"
            let atLineStart = selection.location == 0 || ns.character(at: selection.location - 1) == 10
            let text = (atLineStart ? "" : "\n") + insertion + "\n"
            let caret = selection.location + (atLineStart ? 4 : 5)
            replace(selection, with: text, selecting: NSRange(location: caret, length: 0), actionName: String(localized: "Code Block"))
        } else {
            let range = ns.lineRange(for: selection)
            var body = ns.substring(with: range)
            if !body.hasSuffix("\n") { body += "\n" }
            replace(range, with: "```\n" + body + "```\n",
                    selecting: NSRange(location: range.location + 3, length: 0), actionName: String(localized: "Code Block"))
        }
    }

    @objc func mdHorizontalRule(_ sender: Any?) {
        let ns = string as NSString
        let selection = selectedRange()
        let atLineStart = selection.location == 0 || ns.character(at: selection.location - 1) == 10
        let text = (atLineStart ? "" : "\n") + "\n---\n\n"
        replace(selection, with: text,
                selecting: NSRange(location: selection.location + (text as NSString).length, length: 0),
                actionName: String(localized: "Divider"))
    }

    // MARK: Editing helpers

    func replace(_ range: NSRange, with text: String, selecting selection: NSRange, actionName: String?) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
        setSelectedRange(selection)
        scrollRangeToVisible(selection)
        if let actionName { undoManager?.setActionName(actionName) }
    }

    private func toggleWrap(_ marker: String, placeholder: String, name: String) {
        let ns = string as NSString
        let selection = selectedRange()
        let m = (marker as NSString).length
        let selected = ns.substring(with: selection)

        // Already wrapped just outside the selection → unwrap.
        if selection.location >= m, NSMaxRange(selection) + m <= ns.length,
           ns.substring(with: NSRange(location: selection.location - m, length: m)) == marker,
           ns.substring(with: NSRange(location: NSMaxRange(selection), length: m)) == marker {
            let outer = NSRange(location: selection.location - m, length: selection.length + 2 * m)
            replace(outer, with: selected,
                    selecting: NSRange(location: outer.location, length: selection.length), actionName: name)
            return
        }
        // Selection includes the markers → unwrap.
        if selected.count > 2 * marker.count, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            replace(selection, with: inner,
                    selecting: NSRange(location: selection.location, length: (inner as NSString).length), actionName: name)
            return
        }
        let body = selected.isEmpty ? placeholder : selected
        replace(selection, with: marker + body + marker,
                selecting: NSRange(location: selection.location + m, length: (body as NSString).length), actionName: name)
    }

    private static let headingPrefix = try! NSRegularExpression(pattern: #"^#{1,6}[ \t]+"#)
    private static let anyLinePrefix = try! NSRegularExpression(
        pattern: #"^([ \t]*)(?:[-*+][ \t]+\[[ xX]\][ \t]+|[-*+][ \t]+|\d{1,9}[.)][ \t]+|>[ \t]?)"#
    )

    private func setHeading(_ level: Int) {
        let ns = string as NSString
        let range = ns.lineRange(for: selectedRange())
        let lines = ns.substring(with: range)
        let trailing = lines.hasSuffix("\n")
        var parts = lines.components(separatedBy: "\n")
        if trailing { parts.removeLast() }

        let prefix = String(repeating: "#", count: level) + (level > 0 ? " " : "")
        let alreadyThisLevel = level > 0 && parts.allSatisfy { $0.hasPrefix(prefix) && !$0.hasPrefix(prefix + "#") }
        let updated = parts.map { line -> String in
            let l = line as NSString
            let stripped = Self.headingPrefix.stringByReplacingMatches(
                in: line, range: NSRange(location: 0, length: l.length), withTemplate: "")
            if line.trimmingCharacters(in: .whitespaces).isEmpty && parts.count > 1 { return line }
            return alreadyThisLevel ? stripped : prefix + stripped
        }
        let replacement = updated.joined(separator: "\n") + (trailing ? "\n" : "")
        let caret = range.location + (replacement as NSString).length - (trailing ? 1 : 0)
        replace(range, with: replacement, selecting: NSRange(location: caret, length: 0),
                actionName: level == 0 ? String(localized: "Body") : String(localized: "Heading \(level)"))
    }

    enum LineKind {
        case bullet, numbered, checklist, quote

        var name: String {
            switch self {
            case .bullet: String(localized: "Bulleted List")
            case .numbered: String(localized: "Numbered List")
            case .checklist: String(localized: "Checklist")
            case .quote: String(localized: "Quote")
            }
        }

        var existing: NSRegularExpression {
            switch self {
            case .bullet: try! NSRegularExpression(pattern: #"^[ \t]*[-*+][ \t]+(?!\[[ xX]\])"#)
            case .numbered: try! NSRegularExpression(pattern: #"^[ \t]*\d{1,9}[.)][ \t]+"#)
            case .checklist: try! NSRegularExpression(pattern: #"^[ \t]*[-*+][ \t]+\[[ xX]\][ \t]+"#)
            case .quote: try! NSRegularExpression(pattern: #"^[ \t]*>"#)
            }
        }

        func prefix(_ index: Int) -> String {
            switch self {
            case .bullet: "- "
            case .numbered: "\(index + 1). "
            case .checklist: "- [ ] "
            case .quote: "> "
            }
        }
    }

    private func toggleLinePrefix(_ kind: LineKind) {
        let ns = string as NSString
        let range = ns.lineRange(for: selectedRange())
        let block = ns.substring(with: range)
        let trailing = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if trailing { lines.removeLast() }

        func isBlank(_ line: String) -> Bool { line.trimmingCharacters(in: .whitespaces).isEmpty }
        func matches(_ regex: NSRegularExpression, _ line: String) -> Bool {
            regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
        }
        let regex = kind.existing
        let nonEmpty = lines.filter { !isBlank($0) }
        let removing = !nonEmpty.isEmpty && nonEmpty.allSatisfy { matches(regex, $0) }

        var index = 0
        let updated = lines.map { line -> String in
            if isBlank(line) && lines.count > 1 { return line }
            let l = line as NSString
            var indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            var content = String(line.dropFirst(indent.count))
            if let match = Self.anyLinePrefix.firstMatch(in: line, range: NSRange(location: 0, length: l.length)) {
                indent = l.substring(with: match.range(at: 1))
                content = l.substring(from: match.range.length)
                if content.hasPrefix(" ") && kind == .quote { content.removeFirst() }
            }
            defer { index += 1 }
            return removing ? indent + content : indent + kind.prefix(index) + content
        }
        let replacement = updated.joined(separator: "\n") + (trailing ? "\n" : "")
        let caret = range.location + (replacement as NSString).length - (trailing ? 1 : 0)
        replace(range, with: replacement, selecting: NSRange(location: caret, length: 0), actionName: kind.name)
    }
}

// MARK: - Theme

struct EditorTheme {
    var base: NSFont
    var bold: NSFont
    var italic: NSFont
    var boldItalic: NSFont
    var heading: NSFont
    var code: NSFont
    var paragraph: NSParagraphStyle

    init(font: EditorFont = .monospaced, size: CGFloat = 14) {
        base = font.font(size: size)
        bold = font.font(size: size, weight: .bold)
        italic = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        boldItalic = NSFontManager.shared.convert(bold, toHaveTrait: .italicFontMask)
        heading = font.font(size: size, weight: .bold)
        code = .monospacedSystemFont(ofSize: font == .monospaced ? size : size * 0.92, weight: .regular)

        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = font == .monospaced ? 1.32 : 1.38
        style.paragraphSpacing = 2
        paragraph = style
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: base, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
    }
}
