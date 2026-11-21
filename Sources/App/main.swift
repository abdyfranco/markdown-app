//
//  main.swift
//  Markdown
//
//  Copyright © 2026 Advandz Technologies, LLC.
//

import AppKit
import SwiftUI

@main
enum MarkdownMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
