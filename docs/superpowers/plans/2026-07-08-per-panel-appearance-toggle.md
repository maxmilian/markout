# Per-Panel Appearance Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the editor pane and preview pane each an independent toolbar control switching between System / Light / Dark, defaulting to System so both follow macOS and stay consistent.

**Architecture:** A pure `AppearanceResolver` maps a `{system,light,dark}` mode plus the current OS appearance to an effective `isDark`, and `isDark` to the editor theme id. `ContentView` holds two persisted `@AppStorage` modes, computes each pane's `isDark`, and feeds the existing `EditorView` (`editorThemeID`) and `PreviewView` (`isDark`) inputs. Two toolbar `Menu`s set the modes; the old built-in theme pickers are removed, custom preview CSS is kept.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit/WebKit, XcodeGen, Swift Testing.

## Global Constraints

- Target macOS 14.0, Swift 5.9, ad-hoc signed, no sandbox.
- The Xcode project is generated from `project.yml` by XcodeGen — run `xcodegen generate` after adding/removing source files.
- Backward compatibility is additive: keep `EditorThemeStore` (all 4 themes), `PreviewThemeStore`, and `HTMLTemplate` APIs unchanged; existing tests stay green.
- Editor Light theme id is exactly `markout-light`, Dark is exactly `markout-dark`.
- Preview built-in theme id is exactly `github`; custom-CSS sentinel id is exactly `custom` (constant `customPreviewThemeID`).
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) in `Tests/MarkoutTests/`.
- Commits are Conventional Commits.

Build & test commands:

```sh
xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd -only-testing:MarkoutTests/<Suite>
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd
```

---

### Task 1: AppearanceResolver (pure logic + tests)

**Files:**
- Create: `Sources/Markout/Settings/AppearanceResolver.swift`
- Test: `Tests/MarkoutTests/AppearanceResolverTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum AppearanceMode: String, CaseIterable { case system, light, dark }`
  - `AppearanceResolver.isDark(mode: AppearanceMode, systemIsDark: Bool) -> Bool`
  - `AppearanceResolver.editorThemeID(isDark: Bool) -> String`

- [ ] **Step 1: Write the failing test**

Create `Tests/MarkoutTests/AppearanceResolverTests.swift`:

```swift
import Testing
@testable import Markout

struct AppearanceResolverTests {
    @Test func systemFollowsOS() {
        #expect(AppearanceResolver.isDark(mode: .system, systemIsDark: true) == true)
        #expect(AppearanceResolver.isDark(mode: .system, systemIsDark: false) == false)
    }

    @Test func lightAndDarkOverrideOS() {
        #expect(AppearanceResolver.isDark(mode: .light, systemIsDark: true) == false)
        #expect(AppearanceResolver.isDark(mode: .light, systemIsDark: false) == false)
        #expect(AppearanceResolver.isDark(mode: .dark, systemIsDark: true) == true)
        #expect(AppearanceResolver.isDark(mode: .dark, systemIsDark: false) == true)
    }

    @Test func editorThemeMapping() {
        #expect(AppearanceResolver.editorThemeID(isDark: true) == "markout-dark")
        #expect(AppearanceResolver.editorThemeID(isDark: false) == "markout-light")
    }

    @Test func rawValuesAreStable() {
        #expect(AppearanceMode(rawValue: "system") == .system)
        #expect(AppearanceMode(rawValue: "light") == .light)
        #expect(AppearanceMode(rawValue: "dark") == .dark)
        #expect(AppearanceMode(rawValue: "garbage") == nil)
    }
}
```

- [ ] **Step 2: Regenerate project and run test to verify it fails**

```sh
xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd -only-testing:MarkoutTests/AppearanceResolverTests
```
Expected: FAIL to build — `AppearanceResolver` / `AppearanceMode` not found.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/Markout/Settings/AppearanceResolver.swift`:

```swift
import Foundation

/// A pane's appearance choice. Persisted as its raw string via `@AppStorage`.
enum AppearanceMode: String, CaseIterable {
    case system, light, dark
}

/// Pure mapping from an `AppearanceMode` (+ the OS appearance) to concrete appearance.
enum AppearanceResolver {
    /// `.system` follows the OS; `.light`/`.dark` override it.
    static func isDark(mode: AppearanceMode, systemIsDark: Bool) -> Bool {
        switch mode {
        case .system: return systemIsDark
        case .light:  return false
        case .dark:   return true
        }
    }

    /// The editor theme id for a given darkness (fixed Markout light/dark pair).
    static func editorThemeID(isDark: Bool) -> String {
        isDark ? "markout-dark" : "markout-light"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd -only-testing:MarkoutTests/AppearanceResolverTests
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```sh
git add Sources/Markout/Settings/AppearanceResolver.swift Tests/MarkoutTests/AppearanceResolverTests.swift project.yml
git commit -m "feat: add AppearanceResolver for per-pane light/dark resolution"
```

---

### Task 2: Settings keys and defaults

**Files:**
- Modify: `Sources/Markout/Settings/SettingsKeys.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `SettingsKey.editorAppearance` = `"editorAppearance"`, `SettingsKey.previewAppearance` = `"previewAppearance"`
  - `SettingsDefault.editorAppearance` = `"system"`, `SettingsDefault.previewAppearance` = `"system"`

- [ ] **Step 1: Add the keys**

In `Sources/Markout/Settings/SettingsKeys.swift`, inside `enum SettingsKey`, after the `customPreviewCSSPath` line, add:

```swift
    static let editorAppearance = "editorAppearance"
    static let previewAppearance = "previewAppearance"
```

Inside `enum SettingsDefault`, after the `customPreviewCSSPath` line, add:

```swift
    static let editorAppearance = "system"
    static let previewAppearance = "system"
```

- [ ] **Step 2: Verify it builds**

```sh
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```sh
git add Sources/Markout/Settings/SettingsKeys.swift
git commit -m "feat: add editor/preview appearance settings keys"
```

---

### Task 3: Wire ContentView (compute isDark, feed panes, toolbar menus)

**Files:**
- Modify: `Sources/Markout/App/ContentView.swift`

**Interfaces:**
- Consumes: `AppearanceMode`, `AppearanceResolver.isDark(mode:systemIsDark:)`, `AppearanceResolver.editorThemeID(isDark:)` (Task 1); `SettingsKey.editorAppearance`, `SettingsKey.previewAppearance`, `SettingsDefault.editorAppearance`, `SettingsDefault.previewAppearance` (Task 2).
- Produces: editor/preview panes driven by the two appearance modes; two toolbar appearance menus.

- [ ] **Step 1: Replace the editor-theme storage with appearance modes**

In `ContentView.swift`, replace this line (currently line 19):

```swift
    @AppStorage(SettingsKey.editorThemeID) private var editorThemeID = SettingsDefault.editorThemeID
```

with:

```swift
    @AppStorage(SettingsKey.editorAppearance) private var editorAppearance = SettingsDefault.editorAppearance
    @AppStorage(SettingsKey.previewAppearance) private var previewAppearance = SettingsDefault.previewAppearance
```

- [ ] **Step 2: Add computed darkness properties**

In `ContentView.swift`, immediately after the `activeTheme` computed property (it ends at the line with `?? PreviewTheme(id: "default", name: "Default", css: HTMLTemplate.css)` then `}`), add:

```swift
    private var systemIsDark: Bool { colorScheme == .dark }

    private var editorIsDark: Bool {
        AppearanceResolver.isDark(
            mode: AppearanceMode(rawValue: editorAppearance) ?? .system,
            systemIsDark: systemIsDark)
    }

    private var previewIsDark: Bool {
        AppearanceResolver.isDark(
            mode: AppearanceMode(rawValue: previewAppearance) ?? .system,
            systemIsDark: systemIsDark)
    }
```

- [ ] **Step 3: Feed the panes**

In the `EditorView(...)` initializer call, replace the argument:

```swift
                    editorThemeID: editorThemeID,
```

with:

```swift
                    editorThemeID: AppearanceResolver.editorThemeID(isDark: editorIsDark),
```

In the `PreviewView(...)` initializer call, replace:

```swift
                    isDark: colorScheme == .dark,
```

with:

```swift
                    isDark: previewIsDark,
```

- [ ] **Step 4: Replace the Preview Theme toolbar picker with two appearance menus**

In the `.toolbar { ... }` block, replace this entire `ToolbarItem` (currently the last toolbar item, lines ~98–108):

```swift
            ToolbarItem(placement: .automatic) {
                Picker("Preview Theme", selection: $previewThemeID) {
                    ForEach(PreviewThemeStore.bundled) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                    if !customPreviewCSSPath.isEmpty {
                        Text("Custom").tag(customPreviewThemeID)
                    }
                }
                .pickerStyle(.menu)
            }
```

with:

```swift
            ToolbarItem(placement: .automatic) {
                appearanceMenu(
                    title: "Editor appearance", glyph: "square.lefthalf.filled",
                    selection: $editorAppearance)
            }
            ToolbarItem(placement: .automatic) {
                appearanceMenu(
                    title: "Preview appearance", glyph: "eye",
                    selection: $previewAppearance)
            }
```

- [ ] **Step 5: Add the `appearanceMenu` helper**

In `ContentView.swift`, add this method inside `ContentView` (place it just before the `activeTheme` computed property):

```swift
    /// A toolbar menu offering System / Light / Dark for one pane. `glyph` distinguishes the
    /// editor menu from the preview menu; the checkmark in the menu shows the current mode.
    private func appearanceMenu(title: String, glyph: String, selection: Binding<String>) -> some View {
        Menu {
            Picker(title, selection: selection) {
                Label("System", systemImage: "circle.lefthalf.filled").tag(AppearanceMode.system.rawValue)
                Label("Light", systemImage: "sun.max").tag(AppearanceMode.light.rawValue)
                Label("Dark", systemImage: "moon").tag(AppearanceMode.dark.rawValue)
            }
            .pickerStyle(.inline)
        } label: {
            Label(title, systemImage: glyph)
        }
        .help(title)
    }
```

- [ ] **Step 6: Verify it builds**

```sh
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd
```
Expected: `** BUILD SUCCEEDED **`. (`previewThemeID` and `customPreviewCSSPath` `@AppStorage` remain used by `activeTheme`, so no unused-warning cleanup is needed.)

- [ ] **Step 7: Commit**

```sh
git add Sources/Markout/App/ContentView.swift
git commit -m "feat: drive editor/preview panes from per-pane appearance menus"
```

---

### Task 4: Settings UI (remove theme pickers, keep custom CSS)

**Files:**
- Modify: `Sources/Markout/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `SettingsKey.previewThemeID`, `SettingsKey.customPreviewCSSPath`, `customPreviewThemeID`, `PreviewThemeStore.custom(fromFileURL:)` (existing).
- Produces: Editor tab without a theme picker; Preview tab with a custom-CSS toggle + chooser only.

- [ ] **Step 1: Remove the Editor theme picker**

In `EditorSettingsTab`, delete this `@AppStorage` line:

```swift
    @AppStorage(SettingsKey.editorThemeID) private var editorThemeID = SettingsDefault.editorThemeID
```

and delete this `Picker` from its `body`:

```swift
            Picker("Editor theme", selection: $editorThemeID) {
                ForEach(EditorThemeStore.all) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }
```

- [ ] **Step 2: Replace the Preview tab body**

Replace the entire `PreviewSettingsTab` struct with:

```swift
private struct PreviewSettingsTab: View {
    @AppStorage(SettingsKey.previewThemeID) private var previewThemeID = SettingsDefault.previewThemeID
    @AppStorage(SettingsKey.customPreviewCSSPath) private var customCSSPath = SettingsDefault.customPreviewCSSPath

    private var customName: String? {
        customCSSPath.isEmpty ? nil : URL(fileURLWithPath: customCSSPath).lastPathComponent
    }

    /// On/off for using the imported custom CSS, backed by the `previewThemeID` sentinel.
    private var useCustom: Binding<Bool> {
        Binding(
            get: { previewThemeID == customPreviewThemeID },
            set: { previewThemeID = $0 ? customPreviewThemeID : SettingsDefault.previewThemeID })
    }

    var body: some View {
        Form {
            Text("Light / Dark is controlled per pane from the toolbar.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Toggle("Use custom CSS for preview", isOn: useCustom)
                .disabled(customName == nil)

            if let customName {
                LabeledContent("Custom CSS", value: customName)
            }

            HStack {
                Button("Choose custom CSS…", action: chooseCustomCSS)
                if customName != nil {
                    Button("Clear", role: .destructive) {
                        customCSSPath = ""
                        if previewThemeID == customPreviewThemeID {
                            previewThemeID = SettingsDefault.previewThemeID
                        }
                    }
                }
            }
        }
    }

    private func chooseCustomCSS() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "css") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Validate it is readable before selecting it.
        guard PreviewThemeStore.custom(fromFileURL: url) != nil else { return }
        customCSSPath = url.path
        previewThemeID = customPreviewThemeID
    }
}
```

- [ ] **Step 3: Verify it builds**

```sh
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run the full test suite (no regressions)**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' -derivedDataPath .build/dd
```
Expected: all tests pass (existing suites + `AppearanceResolverTests`).

- [ ] **Step 5: Commit**

```sh
git add Sources/Markout/Settings/SettingsView.swift
git commit -m "feat: replace theme pickers with per-pane appearance + custom CSS toggle"
```

---

### Task 5: Manual verification (AppKit/WebKit edges)

**Files:** none (manual).

- [ ] **Step 1: Build and launch**

```sh
xcodebuild build -project Markout.xcodeproj -scheme Markout -configuration Release -destination 'platform=macOS' -derivedDataPath .build/dd
open .build/dd/Build/Products/Release/Markout.app
```

- [ ] **Step 2: Verify the two toolbar menus**

Confirm two appearance menus appear in the toolbar (a half-square glyph for Editor, an eye glyph for Preview), each offering System / Light / Dark with a checkmark on the current choice.

- [ ] **Step 3: Verify independent switching**

- Set Editor = Light, Preview = Dark → left pane light, right pane dark. Swap → reverses.
- Set both = System, then toggle macOS System Settings ▸ Appearance between Light and Dark → both panes follow live.

- [ ] **Step 4: Verify custom CSS still works**

In Preferences ▸ Preview, choose a `.css` file, enable "Use custom CSS for preview" → preview uses it; toggling the Preview appearance icon between Light/Dark still flips `data-theme` for that CSS. Clear removes it and reverts to `github`.

---

## Self-Review

**Spec coverage:**
- Two independent controls → Task 3 (two toolbar menus). ✓
- Fixed theme mapping (editor markout light/dark; preview github) → Task 1 `editorThemeID`, Task 3 wiring. ✓
- Remove Preview Theme dropdown + Settings editor/preview built-in pickers → Task 3 Step 4, Task 4 Steps 1–2. ✓
- Keep custom preview CSS → Task 4 Step 2 (toggle + chooser + sentinel). ✓
- Default `system` both panes → Task 2. ✓
- `AppearanceResolver` pure + unit tests → Task 1. ✓
- Data flow via existing observation (EditorView theme change, PreviewView isDark reload) → Task 3 Step 3; verified `PreviewView.needsReload` reacts to `isDark`. ✓
- Backward compat: stores/APIs untouched → only ContentView/SettingsView/keys change; `EditorThemeStore.all` still referenced? Task 4 removes its only picker use — the store stays defined and tested but is no longer referenced by UI, which is fine (its tests target the store directly). ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `AppearanceMode.rawValue` (String) used consistently in `@AppStorage`, `Binding<String>`, and `.tag(...)`. `editorThemeID(isDark:)` and `isDark(mode:systemIsDark:)` signatures match between Task 1 and Task 3. ✓
