# Markdown

A small, native macOS app for reading, editing and creating Markdown, designed for macOS Tahoe's Liquid Glass. It comes with a QuickLook extension, so pressing Space on a `.md` file in Finder shows it rendered.

Created by Abdy Franco and released under the [MIT License](LICENSE.md).

## Features

- **Three views.** Editor, Split and Preview, from the glass segmented control or ⌘1 / ⌘2 / ⌘3. In Split, the preview follows the editor as you scroll.
- **Search, like Preview.** A search field at the top right of the toolbar. It stays compact when idle and widens while you're searching.
  - Matches are highlighted as you type, and a glass pill shows how many there are.
  - Return or ⌘G goes to the next match; Shift-Return or ⇧⌘G to the previous one.
  - ⌘F jumps to the field, and ⌘E searches for the current selection.
  - It works in the editor and the rendered preview. In Split, both panes highlight matches.
- **A quiet editor.**
  - Syntax highlighting: markup fades back and content stays readable.
  - The text sits in a centred column.
  - Choice of SF Mono, SF Pro or New York.
  - Return continues lists, checklists and quotes. Return on an empty item ends the list.
  - Tab and Shift-Tab indent and outdent list items.
  - Find and Replace is on ⌥⌘F.
- **Formatting commands** in the Format menu and the toolbar's Aa button:
  - Bold, italic, strikethrough, code, links, headings, lists, checklists, quotes, code blocks and dividers.
  - ⌘K turns a URL on the clipboard into a link.
- **GitHub-style rendering** with Apple's own CommonMark parser:
  - Tables, task lists, fenced code, strikethrough and autolinks.
  - Raw HTML (`<details>`, `<kbd>` and so on), YAML front matter, and relative images.
- **Export and print.**
  - **Export as PDF** (⌥⌘E) writes paginated, print-styled pages, always in the light theme, with code wrapped and images included.
  - Export as HTML, Copy HTML, and Print.
  - All of these work from any view.
- **Proper documents.** Autosave, versions (Revert To), Rename and Move, tabs, Open Recent, and detection of changes made by other apps.
- **QuickLook preview.** Space in Finder renders the file with the same stylesheet as the app, in light and dark.
- **Updates from GitHub.** Markdown checks this repository's tags once a day, and whenever you choose **Markdown → Check for Updates…**. When there's a newer version, it shows the release notes and offers **Install Update**, **Later** or **Skip This Version**. Installing downloads the release's DMG, checks it, swaps the app in place and restarts. You can turn automatic checks off in **Settings → Updates**.

## Building from scratch

The project builds with Apple's command-line tools and a small shell script. There's no Xcode project, no package manager and nothing to download during the build.

### 1. Requirements

- A Mac running **macOS 26 (Tahoe)** or later, with Apple silicon or Intel. The build is a universal app that runs natively on both.
- One of these toolchains:
  - **Xcode 26** (recommended). Needed for the Liquid Glass app icon that follows Light, Dark, Clear and Tinted. Icon Composer is included.
  - **Command Line Tools** only. Builds everything, but the app gets a static icon.

### 2. Set up the toolchain

**With Xcode**, install it from the App Store, then run these once. The first two need your administrator password.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

```bash
sudo xcodebuild -license accept
```

```bash
xcodebuild -runFirstLaunch
```

**Without Xcode**, install the Command Line Tools:

```bash
xcode-select --install
```

Check that Swift is available. It should report Swift 6 targeting macOS 26:

```bash
swift --version
```

### 3. Get the source

Put the project folder anywhere; a path with spaces is fine. Open Terminal in it:

```bash
cd ~/path/to/project
```

If the scripts lost their executable bit (some archive tools strip it), restore it:

```bash
chmod +x build.sh Tools/make-icon.sh
```

### 4. Run the tests

```bash
./build.sh test
```

This compiles the app's code into a headless test runner and should end with `All tests passed`.

### 5. Build and install

```bash
./build.sh install
```

In order, this:

1. Compiles the QuickLook extension (`Sources/Shared` and `Sources/QuickLook`) for arm64 and x86_64, merges the two with `lipo`, and signs it with its sandbox entitlements.
2. Compiles the app (`Sources/Shared` and `Sources/App`) the same way, as a universal binary.
3. Compiles `Support/AppIcon.icon` into `Assets.car` with Xcode's `actool`. Without Xcode it uses `Support/AppIcon.icns` instead and says so.
4. Signs the app ad hoc and checks the signature.
5. Packs the app into a disk image, `build/Markdown-1.0.0.dmg`, with a shortcut to Applications to drag it onto. The version number comes from `Support/App-Info.plist`.
6. Copies the app to `~/Applications/Markdown.app`, registers it with Launch Services and turns on the QuickLook extension.

Then open **Markdown** from `~/Applications`, or install and launch in one step:

```bash
./build.sh run
```

### 6. Check QuickLook

Select a Markdown file in Finder and press **Space**. You should see it rendered. If you see plain text, see [QuickLook](#quicklook) below.

### Build script reference

| Command | What it does |
|:--|:--|
| `./build.sh` | Build the universal app and the DMG into `./build` |
| `./build.sh install` | Build, install in `~/Applications` and register QuickLook |
| `./build.sh run` | Install, then launch |
| `./build.sh test` | Run the headless editor and renderer tests |
| `ARCHS=arm64 ./build.sh` | Build for one architecture only, which is faster while developing |
| `./Tools/make-icon.sh` | Re-render the fallback `.icns` and the appearance previews from `AppIcon.icon` (`--layers` also regenerates the artwork) |

### Troubleshooting

| What you see | What to do |
|:--|:--|
| `Using static icon (install Xcode …)` | Xcode isn't the selected toolchain. Run the `xcode-select` step above. |
| `actool failed; using the static AppIcon.icns` | Run `xcodebuild -runFirstLaunch` once, then build again. |
| `permission denied: ./build.sh` | Run `chmod +x build.sh Tools/make-icon.sh`. |
| `open` fails with error -600 right after installing | The previous copy was still quitting. Run the command again. |
| The Dock still shows an old icon | It's cached. Run `killall Dock`; Finder refreshes on its own. |

### Distributing

`build/Markdown-1.0.0.dmg` is the file to share. It holds the universal app; to install, open it and drag **Markdown** onto **Applications**.

The build is signed ad hoc, which is fine on the Mac that built it. On other Macs, Gatekeeper blocks ad-hoc apps from the internet. To share the app widely, sign it with a Developer ID certificate and notarize it.

### Publishing a release

The updater looks at the repository's tags and picks the highest version, such as `v1.0.1` or `1.0.1`; pre-release tags like `v1.1.0-beta` are ignored. It then installs the `.dmg` attached to that tag's GitHub release. To publish a version:

1. Set the new version in `CFBundleShortVersionString` and `CFBundleVersion`, in both `Support/App-Info.plist` and `Support/QuickLook-Info.plist`.
2. Build it, which also produces `build/Markdown-<version>.dmg`:

   ```bash
   ./build.sh
   ```

3. Commit, then tag the version and push the tag:

   ```bash
   git tag v1.0.1 && git push origin v1.0.1
   ```

4. Create a release for the tag with the DMG attached. The release notes appear in the update prompt.

   ```bash
   gh release create v1.0.1 build/Markdown-1.0.1.dmg --title "Markdown 1.0.1" --notes "What changed"
   ```

If the newest tag has no release or no DMG, the prompt offers **View Release** instead of installing. Installing in place also needs the app to be in a folder it can write to, such as `~/Applications`, or `/Applications` for an administrator.

## After installing

### Make it the default Markdown app

Open **Markdown → Settings… → Make Default**, or choose **Get Info → Open with → Change All…** on any `.md` file in Finder.

### QuickLook

Select a Markdown file in Finder and press **Space**. If you see plain text instead, check that **Markdown Preview** is turned on in **System Settings → General → Login Items & Extensions → Quick Look**, then run `qlmanage -r`.

> **Finder thumbnails:** on macOS 26.4, Finder's icon thumbnails for Markdown files come from the system's built-in plain-text thumbnailer. In testing, a third-party thumbnail extension that claimed Markdown was never called, although the same extension worked for a non-text file type. So this app ships only the preview extension: icons show plain text, and the Space-bar preview is fully rendered.

## App icon

The icon is an **Icon Composer** document, [`Support/AppIcon.icon`](Support/AppIcon.icon). Open it in Icon Composer to inspect or tweak it. It's built the Liquid Glass way: a gradient backdrop, plus layered vector artwork that the system turns into glass with specular highlights, translucency and depth.

| Group | Layers | Glass |
|:--|:--|:--|
| Mark | `mark.svg`, the M↓ | individual lighting, coloured shadow |
| Page | `fold.svg`, `lines.svg`, `page.svg` | frosted (translucency 0.35, blur), neutral shadow |

- **Default:** a vivid blue gradient with a frosted white page and a blue mark.
- **Dark:** a deep graphite backdrop with a slate glass page and a glowing light-blue mark.
- **Clear and Tinted:** the system derives these from the layers ("Mono" in Icon Composer), so the page and mark read as separate glass shapes.

The artwork is generated by `Tools/MakeIconLayers.swift`. `Tools/make-icon.sh` uses Icon Composer's command-line tool to render the fallback `.icns`, plus a preview of each appearance in `build/icon-previews/`. With Xcode those previews cover Default, Dark, Clear Light, Clear Dark, Tinted Light and Tinted Dark.

**Xcode is needed for live appearance switching.** Compiling a `.icon` into an app needs Xcode's `actool` (see [Building from scratch](#building-from-scratch)). With it, the Dock and Finder follow Light, Dark, Clear and Tinted. With only the Command Line Tools, the app uses a static `AppIcon.icns` rendered from the Default appearance.

## Keyboard shortcuts

| Action | Shortcut |
|:--|:--|
| Editor · Split · Preview | ⌘1 · ⌘2 · ⌘3 (⌘\\ cycles) |
| Search · Next · Previous | ⌘F · ⌘G · ⇧⌘G |
| Search for selection | ⌘E |
| Find and Replace (editor) | ⌥⌘F |
| Bold · Italic · Strikethrough | ⌘B · ⌘I · ⇧⌘X |
| Inline code · Code block | ⌥⌘C · ⌥⌘B |
| Link | ⌘K |
| Heading 1 / 2 / 3 · Body | ⌥⌘1 / ⌥⌘2 / ⌥⌘3 · ⌥⌘0 |
| Bulleted · Numbered · Checklist | ⇧⌘8 · ⇧⌘9 · ⇧⌘L |
| Quote · Divider | ⌘' · ⌥⌘- |
| Bigger · Smaller · Actual size | ⌘+ · ⌘- · ⌘0 |
| Export as PDF · Export as HTML | ⌥⌘E · ⇧⌘E |
| Print | ⌘P |

## Project layout

```
Sources/
  Shared/       MarkdownRenderer (Markdown → HTML), PreviewTheme (HTML + CSS)
  App/          AppKit document app with SwiftUI views
                  MarkdownDocument       NSDocument: reading, saving, print, PDF & HTML export
                  DocumentWindowController / DocumentToolbar   window, glass toolbar, search field
                  ContentView            split layout, status pill
                  MarkdownTextView / MarkdownHighlighter   editor, smart lists, formatting, highlighting
                  PreviewController      WKWebView preview (content JavaScript disabled)
                  PrintRenderer          offscreen page for printing and PDF export
                  Updater                update checks against GitHub tags, prompt and installer
                  MainMenu, SettingsView, Preferences, MarkdownGuide, AppInfo (author & copyright)
  QuickLook/    Data-based QuickLook preview extension
Support/        Info.plists, entitlements, AppIcon.icon (Icon Composer), fallback AppIcon.icns
Tests/          Headless tests (./build.sh test)
Samples/        Welcome.md
Tools/          Icon layer generator, framing and icon build script
```

Markdown is parsed by Foundation's `AttributedString(markdown:)` (cmark-gfm). The renderer walks its presentation intents to rebuild HTML, so the app and the QuickLook extension render identically.

## Uninstall

```bash
rm -rf ~/Applications/Markdown.app && qlmanage -r
```

## License

Copyright © 2026 Abdy Franco.

Markdown is released under the **MIT License**: you may use, copy, modify and distribute it, as long as the copyright and permission notice are included. See [LICENSE.md](LICENSE.md) for the full text.

The app itself carries only the copyright line. It appears in the About panel (**Markdown → About Markdown**) and in Finder's **Get Info**.
