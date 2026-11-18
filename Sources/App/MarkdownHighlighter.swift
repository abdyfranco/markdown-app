import AppKit

/// Lightweight, regex-based Markdown syntax highlighting for the editor.
/// Markup characters fade back; content keeps the reading color.
enum MarkdownHighlighter {

    private static func regex(_ pattern: String, _ options: NSRegularExpression.Options = [.anchorsMatchLines]) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static let heading = regex(#"^[ \t]{0,3}(#{1,6})(?=[ \t]|$).*$"#)
    private static let setext = regex(#"^[ \t]{0,3}(=+|-+)[ \t]*$"#)
    private static let blockquote = regex(#"^[ \t]{0,3}(>[> \t]*)(.*)$"#)
    private static let listMarker = regex(#"^[ \t]*([-*+]|\d{1,9}[.)])[ \t]+(\[[ xX]\](?=[ \t]))?"#)
    private static let rule = regex(#"^[ \t]{0,3}(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})$"#)
    private static let bold = regex(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private static let italic = regex(#"(?<![*_\w\\])([*_])(?=[^\s*_])(.+?)(?<=[^\s\\*_])\1(?![*_\w])"#)
    private static let strike = regex(#"(~~)(?=\S)(.+?)(?<=\S)~~"#)
    private static let inlineCode = regex(#"(`+)(?!`)(.+?)(?<!`)\1(?!`)"#)
    private static let link = regex(#"(!?\[)([^\]\n]*)(\]\()([^)\n]*)(\))"#)
    private static let referenceDefinition = regex(#"^[ \t]{0,3}\[[^\]\n]+\]:[ \t]+\S.*$"#)
    private static let autolink = regex(#"<(?:https?|mailto):[^>\s]+>|(?<![(<"\w/])https?://[^\s<>()\[\]]*[^\s<>()\[\].,;:!?'"]"#)
    private static let html = regex(#"<!--[\s\S]*?-->|</?[A-Za-z][A-Za-z0-9-]*(?:\s[^<>\n]*)?/?>"#, [])
    private static let tableRule = regex(#"^[ \t]*\|?[ \t]*:?-{2,}:?[ \t]*(?:\|[ \t]*:?-{2,}:?[ \t]*)+\|?[ \t]*$"#)
    private static let tablePipe = regex(#"(?<!\\)\|"#, [])

    static func apply(theme: EditorTheme, to storage: NSTextStorage, in range: NSRange,
                      blocks: [FencedBlock]? = nil, matches: [NSRange] = []) {
        let string = storage.string
        let ns = string as NSString
        guard range.length > 0, NSMaxRange(range) <= ns.length else { return }

        let markup = NSColor.tertiaryLabelColor
        let secondary = NSColor.secondaryLabelColor
        let accent = NSColor.controlAccentColor
        let codeFill = NSColor.quaternarySystemFill

        func each(_ regex: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            regex.enumerateMatches(in: string, range: range) { match, _, _ in
                if let match { body(match) }
            }
        }
        func color(_ color: NSColor, _ r: NSRange) {
            guard r.location != NSNotFound, r.length > 0 else { return }
            storage.addAttribute(.foregroundColor, value: color, range: r)
        }
        func font(_ font: NSFont, _ r: NSRange) {
            guard r.location != NSNotFound, r.length > 0 else { return }
            storage.addAttribute(.font, value: font, range: r)
        }

        storage.beginEditing()
        storage.setAttributes(theme.baseAttributes, range: range)

        each(heading) { m in
            font(theme.heading, m.range)
            color(markup, m.range(at: 1))
        }
        each(setext) { m in
            // Only an underline directly below a paragraph line is a heading.
            let start = m.range.location
            guard start > 0 else { return }
            let previous = ns.lineRange(for: NSRange(location: start - 1, length: 0))
            let text = ns.substring(with: previous).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !text.hasPrefix("#"), !text.hasPrefix(">"), !text.hasPrefix("-") else { return }
            font(theme.heading, previous)
            color(markup, m.range)
        }
        each(rule) { m in color(markup, m.range) }
        each(blockquote) { m in
            color(secondary, m.range(at: 2))
            color(accent.withAlphaComponent(0.7), m.range(at: 1))
        }
        each(listMarker) { m in
            color(accent, m.range(at: 1))
            color(accent, m.range(at: 2))
        }
        each(tableRule) { m in color(markup, m.range) }
        each(tablePipe) { m in color(markup, m.range) }

        each(bold) { m in
            storage.enumerateAttribute(.font, in: m.range) { value, r, _ in
                let current = value as? NSFont ?? theme.base
                font(current == theme.italic ? theme.boldItalic : theme.bold, r)
            }
            color(markup, NSRange(location: m.range.location, length: m.range(at: 1).length))
            color(markup, NSRange(location: NSMaxRange(m.range) - m.range(at: 1).length, length: m.range(at: 1).length))
        }
        each(italic) { m in
            storage.enumerateAttribute(.font, in: m.range) { value, r, _ in
                let current = value as? NSFont ?? theme.base
                font(current == theme.bold || current == theme.heading ? theme.boldItalic : theme.italic, r)
            }
            color(markup, NSRange(location: m.range.location, length: 1))
            color(markup, NSRange(location: NSMaxRange(m.range) - 1, length: 1))
        }
        each(strike) { m in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range(at: 2))
            color(secondary, m.range(at: 2))
            color(markup, m.range(at: 1))
            color(markup, NSRange(location: NSMaxRange(m.range) - 2, length: 2))
        }
        each(link) { m in
            color(markup, m.range(at: 1))
            color(accent, m.range(at: 2))
            color(markup, m.range(at: 3))
            color(markup, m.range(at: 4))
            color(markup, m.range(at: 5))
        }
        each(referenceDefinition) { m in color(markup, m.range) }
        each(autolink) { m in color(accent, m.range) }
        each(html) { m in color(markup, m.range) }

        each(inlineCode) { m in
            storage.removeAttribute(.strikethroughStyle, range: m.range)
            font(theme.code, m.range)
            color(secondary, m.range(at: 2))
            color(markup, m.range(at: 1))
            color(markup, NSRange(location: NSMaxRange(m.range) - m.range(at: 1).length, length: m.range(at: 1).length))
            storage.addAttribute(.backgroundColor, value: codeFill, range: m.range)
        }

        // Fenced code blocks and front matter override everything inside them.
        for block in blocks ?? fencedBlocks(in: ns) {
            let target = NSIntersectionRange(block.body, range)
            if target.length > 0 {
                storage.removeAttribute(.backgroundColor, range: target)
                storage.removeAttribute(.strikethroughStyle, range: target)
                font(theme.code, target)
                color(secondary, target)
            }
            for fence in block.fences {
                let r = NSIntersectionRange(fence, range)
                if r.length > 0 { color(markup, r) }
            }
        }

        // Search matches sit on top of everything else.
        if !matches.isEmpty {
            let findColor = NSColor.findHighlightColor.withAlphaComponent(0.45)
            for match in matches {
                let r = NSIntersectionRange(match, range)
                if r.length > 0 { storage.addAttribute(.backgroundColor, value: findColor, range: r) }
            }
        }

        storage.endEditing()
    }

    struct FencedBlock {
        var body: NSRange
        var fences: [NSRange]
    }

    /// Finds fenced code blocks (``` / ~~~) and YAML front matter.
    /// Only lines that begin with a fence character are examined closely.
    static func fencedBlocks(in ns: NSString, allowFrontMatter: Bool = true) -> [FencedBlock] {
        let backtick: unichar = 0x60, tilde: unichar = 0x7E, space: unichar = 0x20
        let tab: unichar = 0x09, dash: unichar = 0x2D, dot: unichar = 0x2E
        let length = ns.length
        var blocks: [FencedBlock] = []
        var open: (marker: unichar, count: Int, range: NSRange)?
        var frontMatterOpen: NSRange?
        var location = 0
        var isFirstLine = true

        func lineText(_ start: Int, _ end: Int) -> String {
            ns.substring(with: NSRange(location: start, length: end - start))
        }

        while location < length {
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            ns.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd,
                            for: NSRange(location: location, length: 0))
            let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
            defer { location = lineEnd; isFirstLine = false }
            if lineEnd <= lineStart { break }

            // First non-space character (fences allow up to three spaces of indent).
            var i = lineStart
            while i < contentsEnd, i - lineStart < 4, ns.character(at: i) == space { i += 1 }
            let indent = i - lineStart
            let first: unichar = i < contentsEnd ? ns.character(at: i) : 0

            if let fm = frontMatterOpen {
                if first == dash || first == dot {
                    let text = lineText(lineStart, contentsEnd)
                    if text == "---" || text == "..." {
                        blocks.append(FencedBlock(body: NSRange(location: NSMaxRange(fm), length: lineStart - NSMaxRange(fm)),
                                                  fences: [fm, lineRange]))
                        frontMatterOpen = nil
                    }
                }
                continue
            }
            if allowFrontMatter && isFirstLine && first == dash && lineText(lineStart, contentsEnd) == "---" {
                frontMatterOpen = lineRange
                continue
            }
            guard indent <= 3, first == backtick || first == tilde else { continue }

            var run = 0
            var j = i
            while j < contentsEnd, ns.character(at: j) == first { run += 1; j += 1 }

            if let current = open {
                guard first == current.marker, run >= current.count else { continue }
                var k = j
                while k < contentsEnd, ns.character(at: k) == space || ns.character(at: k) == tab { k += 1 }
                if k == contentsEnd {
                    let bodyStart = NSMaxRange(current.range)
                    blocks.append(FencedBlock(body: NSRange(location: bodyStart, length: lineStart - bodyStart),
                                              fences: [current.range, lineRange]))
                    open = nil
                }
            } else if run >= 3 {
                // A backtick fence's info string may not contain backticks.
                if first == backtick, lineText(j, contentsEnd).contains("`") { continue }
                open = (first, run, lineRange)
            }
        }

        // An opening "---" that never closes was a horizontal rule, not front matter.
        if frontMatterOpen != nil {
            return fencedBlocks(in: ns, allowFrontMatter: false)
        }
        // Unclosed blocks run to the end of the document.
        if let current = open {
            let bodyStart = NSMaxRange(current.range)
            blocks.append(FencedBlock(body: NSRange(location: bodyStart, length: length - bodyStart), fences: [current.range]))
        }
        return blocks
    }
}
