# Per-Panel Appearance Toggle (System / Light / Dark)

**Date:** 2026-07-08
**Status:** Approved

## Problem

The editor pane and preview pane derive their light/dark appearance from
unrelated mechanisms, so they can disagree. The editor uses a fixed
`editorThemeID` (default `markout-light`, a hard white background that never
follows the OS). The preview uses `github` CSS, which *does* follow the OS via
`data-theme`. On a Mac in Dark Mode this yields a white editor next to a black
preview. There is no quick, discoverable control to set each pane's appearance.

## Goal

Give each pane its own compact toolbar control that switches between
**System / Light / Dark**, independently. Out of the box both follow the
system, so the panes are consistent by default.

## Decisions (locked during brainstorming)

1. **Two independent controls**, one per pane — not a single unified toggle.
2. **Fixed theme mapping** for Light/Dark (simplest):
   - Editor: Light → `markout-light`, Dark → `markout-dark`.
   - Preview: `github` CSS (already supports both via `data-theme`).
3. **Remove** the now-redundant theme pickers: the toolbar "Preview Theme"
   dropdown, the Settings *Editor theme* picker, and the Settings *Preview
   built-in theme* picker.
4. **Keep** the custom preview CSS feature as an escape hatch.
5. **Default `system`** for both panes.

## Behavior Model

Two persisted settings, each `{system, light, dark}`:

- `editorAppearance` (default `system`)
- `previewAppearance` (default `system`)

Effective darkness for a pane:

```
isDark(mode, systemIsDark) =
    mode == .system ? systemIsDark
  : mode == .dark
```

`systemIsDark` comes from SwiftUI `@Environment(\.colorScheme) == .dark`.

Derived outputs:

- Editor theme id: `isDark ? "markout-dark" : "markout-light"`.
- Preview `isDark` flag: the pane's effective darkness (drives `data-theme`).

## Components

### AppearanceResolver (new, pure)

Small pure helper holding the two rules above, so the logic is unit-testable
away from AppKit/WebKit:

```swift
enum AppearanceMode: String, CaseIterable { case system, light, dark }

enum AppearanceResolver {
    static func isDark(mode: AppearanceMode, systemIsDark: Bool) -> Bool
    static func editorThemeID(isDark: Bool) -> String   // markout-dark / markout-light
}
```

### Toolbar controls (ContentView)

Two `Menu`s in the window toolbar, each offering System / Light / Dark:

- SF Symbols per option: System `circle.lefthalf.filled`, Light `sun.max`,
  Dark `moon`.
- Distinguished by a leading glyph + tooltip: editor menu uses
  `square.lefthalf.filled` / "Editor appearance"; preview menu uses `eye` /
  "Preview appearance". Each menu's button shows the current mode's icon.
- The existing "Preview Theme" picker (`ContentView.swift:99–108`) is removed.

### Settings changes

- **Editor tab:** remove the *Editor theme* picker. Font size, soft wrap, line
  numbers, etc. stay.
- **Preview tab:** remove the built-in theme picker. Keep custom CSS: an
  "Import custom CSS…" action plus a **"Use custom CSS for preview"** checkbox,
  driven by the existing `previewThemeID == "custom"` sentinel +
  `customPreviewCSSPath`. When enabled and a path is set, the preview uses that
  CSS; the appearance icon still sets `data-theme` for the custom CSS to react
  to. When disabled, the preview uses `github`.
- Appearance modes are controlled solely from the toolbar (persisted via
  `@AppStorage`); Settings does not duplicate them.

## Data Flow

`ContentView` observes `@Environment(\.colorScheme)`, `editorAppearance`,
`previewAppearance`:

1. Compute `editorIsDark` / `previewIsDark` via `AppearanceResolver.isDark`.
2. Pass `AppearanceResolver.editorThemeID(isDark: editorIsDark)` to `EditorView`
   as `editorThemeID`.
3. Pass `previewIsDark` to `PreviewView` as `isDark`.
4. `activeTheme` for the preview: custom CSS when the sentinel is active,
   otherwise the `github` theme.

Both changes flow through existing observation paths:

- `EditorView.updateNSView` already treats a theme-id change as
  `appearanceChanged` → reconfigures the text view and rehighlights.
- `PreviewView` already sets `data-theme` from its `isDark` input; a change
  re-runs the JS `setTheme(dark)` hook (verify the SwiftUI update path fires on
  `isDark` change — instrument if needed).

## Settings Keys

New (in `Settings/SettingsKeys.swift`):

- `SettingsKey.editorAppearance` / `SettingsDefault.editorAppearance = "system"`
- `SettingsKey.previewAppearance` / `SettingsDefault.previewAppearance = "system"`

`editorThemeID` and `previewThemeID` keys remain (the `"custom"` sentinel still
drives custom CSS); the built-in-theme *pickers* are what get removed, not the
underlying stores.

## Backward Compatibility

- `EditorThemeStore` keeps all four themes; the UI simply never selects
  Solarized/Dracula. `EditorThemeStoreTests` / `PreviewThemeStoreTests` and the
  `HTMLTemplate` / `PreviewThemeStore` APIs are untouched and stay green.
- Only the ContentView wiring, the Settings UI, and the two new keys change.

## Testing

- **Unit (Swift Testing):** `AppearanceResolver` truth table —
  `{system, light, dark} × {systemIsDark true/false}` for `isDark`, and
  `editorThemeID(isDark:)` maps to the two markout ids.
- **Manual:** launch the app; verify each toolbar menu switches its pane;
  System follows a live OS appearance change; custom CSS still loads and reacts
  to the icon's Light/Dark.

## Out of Scope (YAGNI)

- Per-document (rather than app-wide) appearance.
- Re-surfacing Solarized/Dracula or built-in preview CSS themes in any picker.
- Auto-generating a light/dark pair from an arbitrary custom CSS.
