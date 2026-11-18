import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(Preferences.editorFont) private var font = EditorFont.monospaced.rawValue
    @AppStorage(Preferences.fontSize) private var fontSize = 14.0
    @AppStorage(Preferences.limitLineWidth) private var limitLineWidth = true
    @AppStorage(Preferences.checkSpelling) private var checkSpelling = true
    @AppStorage(Preferences.openMode) private var openMode = ViewMode.preview.rawValue
    @AppStorage(Preferences.showWordCount) private var showWordCount = true
    @State private var isDefaultApp = false

    private let markdown = UTType("net.daringfireball.markdown") ?? .plainText

    var body: some View {
        Form {
            Section("Editor") {
                Picker("Font", selection: $font) {
                    ForEach(EditorFont.allCases) { Text($0.title).tag($0.rawValue) }
                }
                LabeledContent("Size") {
                    HStack(spacing: 6) {
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Stepper("Size", value: $fontSize, in: 10...32, step: 1)
                            .labelsHidden()
                    }
                }
                Toggle("Limit line width", isOn: $limitLineWidth)
                Toggle("Check spelling while typing", isOn: $checkSpelling)
            }

            Section("Documents") {
                Picker("Open files in", selection: $openMode) {
                    ForEach(ViewMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Show word count", isOn: $showWordCount)
            }

            Section {
                LabeledContent {
                    Button("Extensions…") { openExtensionSettings() }
                } label: {
                    Text("Quick Look previews")
                    Text("Select a Markdown file in Finder and press Space.")
                }
                LabeledContent {
                    Button(isDefaultApp ? "Default" : "Make Default") { makeDefault() }
                        .disabled(isDefaultApp)
                } label: {
                    Text("Default app for .md files")
                    Text("Open Markdown files in this app with a double-click.")
                }
            } header: {
                Text("System")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: refreshDefault)
    }

    private func refreshDefault() {
        let current = NSWorkspace.shared.urlForApplication(toOpen: markdown)
        isDefaultApp = current.flatMap { Bundle(url: $0)?.bundleIdentifier } == Bundle.main.bundleIdentifier
    }

    private func makeDefault() {
        Task {
            try? await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: markdown)
            refreshDefault()
        }
    }

    private func openExtensionSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension?ExtensionItems",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }
}
