//
//  EditorTests.swift
//  Markdown
//
//  Copyright © 2026 Advandz Technologies, LLC.
//

// Headless checks for editor logic and rendering. Run with ./build.sh test
import AppKit

@main
enum EditorTests {
    static var failures = 0

    static func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
        if condition { print("  ✓ \(name)") } else { failures += 1; print("  ✗ \(name) \(detail())") }
    }

    static func editor(_ text: String, caret: Int? = nil) -> MarkdownTextView {
        let (_, view) = MarkdownTextView.makeScrollable()
        view.string = text
        view.setSelectedRange(NSRange(location: caret ?? (text as NSString).length, length: 0))
        return view
    }

    static func main() {
        _ = NSApplication.shared
        Preferences.registerDefaults()

        print("List continuation")
        var v = editor("- [ ] Apples")
        v.insertNewline(nil)
        check("checklist continues", v.string == "- [ ] Apples\n- [ ] ", v.string.debugDescription)
        v = editor("1. One")
        v.insertNewline(nil)
        check("numbered list increments", v.string == "1. One\n2. ", v.string.debugDescription)
        v = editor("  * Nested")
        v.insertNewline(nil)
        check("indent and marker kept", v.string == "  * Nested\n  * ", v.string.debugDescription)
        v = editor("- one\n- ")
        v.insertNewline(nil)
        check("empty item ends list", v.string == "- one\n", v.string.debugDescription)
        v = editor("> quote")
        v.insertNewline(nil)
        check("quote continues", v.string == "> quote\n> ", v.string.debugDescription)
        v = editor("plain")
        v.insertNewline(nil)
        check("plain newline", v.string == "plain\n", v.string.debugDescription)

        print("Formatting")
        v = editor("word")
        v.setSelectedRange(NSRange(location: 0, length: 4))
        v.mdBold(nil)
        check("bold wraps", v.string == "**word**", v.string)
        v.mdBold(nil)
        check("bold toggles off", v.string == "word", v.string)
        v = editor("a\nb")
        v.setSelectedRange(NSRange(location: 0, length: 3))
        v.mdBulletList(nil)
        check("bullets added", v.string == "- a\n- b", v.string.debugDescription)
        v.setSelectedRange(NSRange(location: 0, length: 7))
        v.mdBulletList(nil)
        check("bullets removed", v.string == "a\nb", v.string.debugDescription)
        v.setSelectedRange(NSRange(location: 0, length: 3))
        v.mdNumberedList(nil)
        check("numbered list", v.string == "1. a\n2. b", v.string.debugDescription)
        v = editor("Title")
        v.mdHeading2(nil)
        check("heading 2", v.string == "## Title", v.string)
        v.mdHeading1(nil)
        check("heading 1 replaces level", v.string == "# Title", v.string)
        v.mdHeading1(nil)
        check("heading toggles off", v.string == "Title", v.string)
        v = editor("- item")
        v.insertTab(nil)
        check("tab indents list item", v.string == "    - item", v.string.debugDescription)
        v.insertBacktab(nil)
        check("shift-tab outdents", v.string == "- item", v.string.debugDescription)

        print("Highlighting & rendering")
        let sample = (try? String(contentsOfFile: "Samples/Welcome.md", encoding: .utf8)) ?? MarkdownGuide.text
        v = editor(sample)
        v.applyPreferences()
        check("highlighter ran", v.textStorage?.length == (sample as NSString).length)
        let fences = MarkdownHighlighter.fencedBlocks(in: "---\na: 1\n---\ntext\n```js\nx\n```\n~~~\nopen" as NSString)
        check("front matter + 2 fences", fences.count == 3, "\(fences.count)")
        check("closed fence has 2 lines", fences.count == 3 && fences[1].fences.count == 2)
        check("unclosed fence runs to end", fences.count == 3 && fences[2].fences.count == 1)
        let rule = MarkdownHighlighter.fencedBlocks(in: "---\nnot front matter\n```\ncode\n```" as NSString)
        check("unclosed '---' is a rule", rule.count == 1, "\(rule.count)")
        let inline = MarkdownHighlighter.fencedBlocks(in: "```not`a fence\ntext" as NSString)
        check("backticks in info string", inline.isEmpty)

        let html = MarkdownRenderer.html(from: sample)
        for needle in ["<h1 id=", "<table>", "<pre><code class=\"language-swift\"", "type=\"checkbox\" disabled checked",
                       "<blockquote>", "<hr>", "<details>", "<del>", "<ol>"] {
            check("renders \(needle)", html.contains(needle))
        }
        let badge = MarkdownRenderer.html(from: "[![b](x.svg)](https://a.b)")
        check("linked image", badge.contains("<a href=\"https://a.b\"><img src=\"x.svg\""), badge)
        let table = MarkdownRenderer.html(from: "| a | b |\n|--|--|\n| 1 |  |\n")
        check("empty cells padded", table.contains("<td>1</td><td></td>"), table)
        let script = MarkdownRenderer.html(from: "Hi <b>there</b> & `<x>`")
        check("escaping", script.contains("&amp;") && script.contains("<code>&lt;x&gt;</code>"), script)

        print("Update versions")
        check("parses v-prefixed tag", AppVersion("v1.2.3")?.components == [1, 2, 3])
        check("parses bare tag", AppVersion("2.0")?.description == "2.0.0")
        check("ignores pre-releases", AppVersion("1.3.0-beta.1") == nil)
        check("ignores non-version tags", AppVersion("latest") == nil && AppVersion("v1..2") == nil)
        check("numeric, not text, order", AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        check("1.0 equals 1.0.0", AppVersion("1.0")! == AppVersion("1.0.0")!)
        check("patch is newer", AppVersion("v1.0.1")! > AppVersion("1.0.0")!)
        let newest = AppVersion.newest(in: ["v1.0.0", "v1.2.0-rc1", "nightly", "v1.1.5", "1.1.10"])
        check("newest release tag", newest?.tag == "1.1.10", String(describing: newest?.tag))
        check("no version tags", AppVersion.newest(in: ["main", "docs"]) == nil)
        check("download must be https", Updater.isTrusted(URL(string: "https://github.com/a.dmg")!)
              && !Updater.isTrusted(URL(string: "http://example.com/a.dmg")!)
              && Updater.isTrusted(URL(string: "http://127.0.0.1:8000/a.dmg")!))

        print("Local resources")
        let base = LocalResources.baseURL(for: URL(fileURLWithPath: "/Volumes/My Disk/Notes"))
        check("base URL", base.absoluteString == "mdpreview://local/Volumes/My%20Disk/Notes/", base.absoluteString)
        let image = URL(string: "img/a%20b.png", relativeTo: base)!.absoluteURL
        check("relative image maps to file", LocalResources.fileURL(for: image)?.path == "/Volumes/My Disk/Notes/img/a b.png",
              String(describing: LocalResources.fileURL(for: image)?.path))
        let anchor = LocalResources.fileURL(for: URL(string: "#intro", relativeTo: base)!.absoluteURL)
        check("fragment kept", anchor?.fragment == "intro" && anchor?.path == "/Volumes/My Disk/Notes",
              String(describing: anchor))
        check("other schemes ignored", LocalResources.fileURL(for: URL(string: "https://a.b/c.png")!) == nil)
        let servable = ["png", "svg", "jpg", "gif", "mp4", "css", "woff2", "ttf"].allSatisfy {
            LocalResources.mimeType(forExtension: $0) != nil
        }
        let refused = ["md", "txt", "swift", "plist", "html", ""].allSatisfy {
            LocalResources.mimeType(forExtension: $0) == nil
        }
        check("serves media, not documents", servable && refused)

        print(failures == 0 ? "All tests passed" : "\(failures) test(s) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
