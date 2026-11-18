import AppKit

enum ViewMode: String, CaseIterable, Identifiable {
    case edit, split, preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: String(localized: "Editor")
        case .split: String(localized: "Split")
        case .preview: String(localized: "Preview")
        }
    }

    var symbol: String {
        switch self {
        case .edit: "square.and.pencil"
        case .split: "rectangle.split.2x1"
        case .preview: "eye"
        }
    }

    var shortcut: String {
        switch self {
        case .edit: "1"
        case .split: "2"
        case .preview: "3"
        }
    }
}

enum EditorFont: String, CaseIterable, Identifiable {
    case monospaced, system, serif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monospaced: "SF Mono"
        case .system: "SF Pro"
        case .serif: "New York"
        }
    }

    func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .monospaced:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        case .system:
            return .systemFont(ofSize: size, weight: weight)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withDesign(.serif) {
                return NSFont(descriptor: descriptor, size: size) ?? base
            }
            return base
        }
    }
}

enum Preferences {
    static let editorFont = "editorFont"
    static let fontSize = "fontSize"
    static let limitLineWidth = "limitLineWidth"
    static let openMode = "openMode"
    static let showWordCount = "showWordCount"
    static let checkSpelling = "checkSpelling"
    static let statusStyle = "statusStyle"
    static let checkForUpdates = "checkForUpdates"
    static let lastUpdateCheck = "lastUpdateCheck"
    static let skippedVersion = "skippedVersion"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            editorFont: EditorFont.monospaced.rawValue,
            fontSize: 14.0,
            limitLineWidth: true,
            openMode: ViewMode.preview.rawValue,
            showWordCount: true,
            checkSpelling: true,
            statusStyle: 0,
            checkForUpdates: true,
        ])
    }

    static var currentFont: EditorFont {
        EditorFont(rawValue: UserDefaults.standard.string(forKey: editorFont) ?? "") ?? .monospaced
    }

    static var currentFontSize: CGFloat {
        let size = UserDefaults.standard.double(forKey: fontSize)
        return CGFloat(min(max(size, 10), 32))
    }

    static var defaultOpenMode: ViewMode {
        ViewMode(rawValue: UserDefaults.standard.string(forKey: openMode) ?? "") ?? .preview
    }

    static func adjustFontSize(by delta: CGFloat) {
        let size = delta == 0 ? 14 : min(max(currentFontSize + delta, 10), 32)
        UserDefaults.standard.set(Double(size), forKey: fontSize)
    }
}
