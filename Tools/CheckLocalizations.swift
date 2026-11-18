// Checks the translations against the strings the code actually uses.
//
//   swift Tools/CheckLocalizations.swift <stringsdata folder> <Support/Localization/App>
//
// The .stringsdata files come from compiling with -emit-localized-strings
// (./build.sh test does this). Every key the code uses must be in
// en.lproj/Localizable.strings, every language must have exactly the same
// keys, and each translation must keep the same format placeholders.
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: CheckLocalizations.swift <stringsdata folder> <localization folder>")
    exit(2)
}
let dataFolder = URL(fileURLWithPath: arguments[1])
let localizationFolder = URL(fileURLWithPath: arguments[2])
let fileManager = FileManager.default

// Keys used in code.
var used = Set<String>()
for file in (try? fileManager.contentsOfDirectory(at: dataFolder, includingPropertiesForKeys: nil)) ?? []
    where file.pathExtension == "stringsdata" {
    guard let data = try? Data(contentsOf: file),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tables = json["tables"] as? [String: [[String: Any]]] else { continue }
    for (_, entries) in tables {
        for entry in entries {
            if let key = entry["key"] as? String { used.insert(key) }
        }
    }
}
guard !used.isEmpty else {
    print("✗ No localization keys found in \(dataFolder.path)")
    exit(1)
}

func strings(_ language: String) -> [String: String] {
    let file = localizationFolder.appendingPathComponent("\(language).lproj/Localizable.strings")
    return NSDictionary(contentsOf: file) as? [String: String] ?? [:]
}

/// Format placeholders by type, ignoring positions (%1$@ counts as %@).
func placeholders(_ text: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(@|lld|ld|d|lf|f|s)"#)
    let ns = text as NSString
    return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        .map { ns.substring(with: $0.range(at: 1)) }
        .sorted()
}

var problems: [String] = []
let english = strings("en")
for key in used.subtracting(english.keys).sorted() {
    problems.append("en: missing \"\(key)\"")
}
for key in Set(english.keys).subtracting(used).sorted() {
    problems.append("en: no longer used \"\(key)\"")
}

let languages = ((try? fileManager.contentsOfDirectory(atPath: localizationFolder.path)) ?? [])
    .filter { $0.hasSuffix(".lproj") && $0 != "en.lproj" }
    .map { String($0.dropLast(6)) }
    .sorted()
for language in languages {
    let translated = strings(language)
    for key in Set(english.keys).subtracting(translated.keys).sorted() {
        problems.append("\(language): missing \"\(key)\"")
    }
    for key in Set(translated.keys).subtracting(english.keys).sorted() {
        problems.append("\(language): extra \"\(key)\"")
    }
    for (key, value) in translated where english[key] != nil && placeholders(key) != placeholders(value) {
        problems.append("\(language): placeholders differ in \"\(key)\" → \"\(value)\"")
    }
}

if problems.isEmpty {
    print("✓ \(english.count) strings, translated into \(languages.count) languages (\(languages.joined(separator: ", ")))")
} else {
    problems.forEach { print("✗ \($0)") }
    exit(1)
}
