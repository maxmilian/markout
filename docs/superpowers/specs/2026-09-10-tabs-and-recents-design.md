# Document Tabs and Recent Documents

**Date:** 2026-09-10
**Status:** Approved

## Problem

Markout opens every document in its own window. Working across several
Markdown files means a screen full of overlapping windows and ⌘` cycling, with
no way to see at a glance which documents are open.

Reopening a file is just as awkward. macOS keeps a recent-documents list for
document apps, but Markout's is permanently empty — `File ▸ Open Recent`
contains only *Clear Menu*, launch after launch (see *Spike Findings* for why).
The only route back to a file is the open panel and a memory of where it lives.

## Goal

1. Several open documents share one window as native macOS tabs.
2. Launching Markout with nothing to open presents a welcome window listing
   recently opened documents, each one click away.

## Decisions (locked during brainstorming)

1. **Native window tabs, not a custom tab bar.** `DocumentGroup` stays; each
   tab remains a full document window, so saving, autosave, versions, state
   restoration, `Reload from Disk`, `DocumentActions` and `EditorBridge` are
   untouched.
2. **A welcome window** is the entry point to history — not a toolbar dropdown.
   The gap being filled is the "just launched, can't remember where that file
   lives" moment. The window can also be summoned mid-session, which covers
   switching files while editing; the system's own `File ▸ Open Recent` stays
   empty and is left alone.
3. **Recency order only.** No pinning.
4. **Missing files stay in the list, greyed out and unclickable**, with a
   tooltip explaining the file was not found — rather than silently vanishing
   when a volume is not mounted.
5. **Each row shows filename, abbreviated directory path, and relative time.**
   No content preview, so the list never reads a file to draw itself.
6. **Markout keeps its own recents list.** The system list cannot be relied on
   (see below).

## Spike Findings (2026-09-10)

Verified against a debug build on macOS 26.6.2, ad-hoc signed, with the system
setting *Prefer tabs when opening documents* left at its default
(*In Full Screen Only*).

**These launch behaviors are OS-version sensitive and were not verified on the
macOS 14 deployment floor.** Whether `DocumentGroup` opens a panel, an untitled
document, or nothing has changed between releases. The launch logic is therefore
written to be indifferent to which of them happens: close a blank, unedited,
un-restored document if one appeared, and show the welcome window if no document
remains — an outcome that is correct on any of those variants.

**Tabbing must be explicit.** Setting `tabbingMode = .preferred` on a document
window after it exists is too late — two documents still opened as two separate
windows. Actively joining the new window to an existing one works:

```
attach title=spike-a.md host=spike-b.md group=2
later  group=2 tabBarVisible=true selected=spike-a.md
```

**`applicationShouldOpenUntitledFile` is never called.** SwiftUI's
`DocumentGroup` creates the launch document itself, bypassing the app delegate.
Two further behaviors follow:

- By default macOS shows an app-centric *Open* panel at launch. Registering
  `NSShowAppCentricOpenPanelInsteadOfUntitledFile = false` suppresses it, after
  which an untitled document is created instead.
- That untitled document can be closed immediately after launch. Measured:
  `docs=0` with no leftover window, and the welcome window then displays
  cleanly. Launching with a file argument, and system state restoration, both
  produce a non-empty document set and correctly skip the welcome window.

**The system recents list does not persist for this app.** Within one run
`NSDocumentController.shared.recentDocumentURLs` is correct; across launches it
is always empty, and the app's own `File ▸ Open Recent` submenu contains only
*Clear Menu*. macOS stores the list in
`~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/tech.ankey.markout.sfl4`,
whose `items` array is an empty `NSArray` while TextEdit's and Preview's
equivalents are 10 KB of real entries. That file also carries a
`com.apple.LSSharedFileList.DesignatedRequirement` key, and Markout is ad-hoc
signed (`Signature=adhoc`, `TeamIdentifier=not set`), so its code-signing
identity differs on every build. The leading explanation is that macOS drops a
list it cannot match to a stable designated requirement. The cause is not
proven, but the consequence is: **the welcome window must not read its list
from `NSDocumentController`.**

## Behavior Model

### Tabs

Every document window is tagged with the tabbing identifier
`tech.ankey.Markout.document` and `tabbingMode = .preferred`. A new document
window then joins an existing group via `addTabbedWindow(_:ordered: .above)` and
becomes the selected tab.

**Which group it joins matters.** Once a tab has been dragged out, more than one
document tab group exists, and picking an arbitrary one would undo the drag-out
the user just performed, or move the new window to another screen. The host is
chosen in this order:

1. The group of the app's key window, if that window is a document window.
2. Otherwise the group of the app's main window, under the same condition.
3. Otherwise the first visible document window in a different group.
4. Otherwise none — the window opens as the first tab of its own group.

A new document therefore always appears in the group, and on the screen, the
user is currently working in.

The system then provides, at no cost: the tab bar, ⌘⇧[ / ⌘⇧], drag-out to a
separate window, drag-in to merge, *Merge All Windows*, and per-tab close.

Windows that are not documents — the welcome window and the Settings window —
never participate: the welcome window is created with
`tabbingMode = .disallowed`, and no window is accepted as a tab host unless it
carries Markout's document tabbing identifier. This matters when the user has
set *Prefer tabs when opening documents* to *Always*, which is why that setting
is part of the manual verification below.

### Recent documents

A store persists at `~/Library/Application Support/Markout/recents.json`. The
debug build and the installed build share the bundle identifier, and therefore
this file; the two lists mixing is harmless. A file whose `version` is not `1`
decodes to an empty list rather than being reinterpreted.

```json
{ "version": 1,
  "entries": [ { "path": "/Users/u/notes/spec.md", "openedAt": 1789027521.8 } ] }
```

Rules, all pure functions over the decoded model:

- Recording a URL moves it to the front; an existing entry for the same path is
  replaced, never duplicated. Paths are compared after
  `standardizedFileURL.resolvingSymlinksInPath()`, which removes `.`/`..` and
  resolves symlinks. Symlink resolution only applies to paths that exist, so a
  file recorded while its volume was mounted and again while it was not can
  produce two entries. That is accepted: keeping an unreachable file visible
  matters more than perfect de-duplication.
- The list is capped at 10 entries; the oldest fall off.
- The most recently recorded document is first. Recording inserts at the front rather than sorting by `openedAt`, so a caller that backdates an entry does not reorder the list.
- Presence on disk is resolved at display time, never stored — a file on an
  unmounted volume must not be dropped from the list.
- A document is recorded when its window has a file URL, so an unsaved
  *Untitled* document never enters the list; saving it under a name does.
- `openedAt` is the time the document was opened or saved, not the time its tab
  was last selected. Switching tabs does not reorder the list.
- Opening a file that is already open — from the welcome window or anywhere
  else — brings its existing window forward rather than creating a second
  document, and refreshes its `openedAt`.

A row is presented as: display name (filename), abbreviated directory
(`~/side/ankey/markout/docs`), and a relative time (`Today 14:02`, `Yesterday`,
`Sep 7`, `Sep 7, 2025`). Copy is English, matching the rest of the app's UI.
Rows whose file is missing render dimmed and are not clickable. Because nothing
on disk notifies the app when a recorded file is renamed, the list is re-read
every time the welcome window is shown.

### Launch

| Situation | Outcome |
|---|---|
| Files passed by Finder / CLI / drag onto icon | Documents open as tabs; no welcome window |
| System state restoration reopens documents | Restored documents; no welcome window |
| Nothing to open | The launch-created untitled document is closed; the welcome window appears |
| All document windows closed while running | App stays running; welcome window is *not* forced back |
| Dock icon clicked, or the app reactivated, with no windows open | The welcome window appears |
| An unsaved *Untitled* document is restored by autosave | It survives; the welcome window does not appear |

The welcome window can be summoned at any time from `Window ▸ Welcome to
Markout`. Choosing a row opens that document through
`NSDocumentController.shared.openDocument(withContentsOf:display:)`, **not** the
SwiftUI `openDocument` environment action: the welcome window is hosted outside
the `DocumentGroup` scene, where that environment value has no scene to route
into. The document controller is SwiftUI's own, so the file still opens as a
normal document window — and therefore as a tab, recorded in the store by
`ContentView`. The welcome window closes only once the document has actually
opened; if opening fails, it stays put and the list is re-read so the row dims.

## Components

| File | Responsibility | Verification |
|---|---|---|
| `Document/RecentDocuments.swift` | `RecentDocument` model and `RecentDocumentsStore`: record, cap, order, encode/decode, path abbreviation, relative-time formatting | Swift Testing unit tests |
| `App/WelcomeView.swift` | SwiftUI list of recents, New / Open buttons, dimmed missing rows | Manual, by launching the app |
| `App/WelcomeWindowController.swift` | Creates and holds the AppKit-hosted welcome window (`NSHostingController`), `tabbingMode = .disallowed` | Manual |
| `App/WindowTabbing.swift` | `NSViewRepresentable` that tags the document window and joins the tab group | Manual |
| `App/AppDelegate.swift` | Registers `NSShowAppCentricOpenPanelInsteadOfUntitledFile = false`; closes the launch untitled document; decides whether to show the welcome window | Manual |

Changes to existing files are deliberately small:

- `ContentView` gains `.background(WindowTabbingAccessor())` and records the
  document in the recents store when `documentURL` becomes non-nil.
- `MarkoutApp` gains `@NSApplicationDelegateAdaptor` and a `Window ▸ Welcome to
  Markout` command.

The welcome window is AppKit-hosted rather than a SwiftUI `Window` scene
because it must be opened from the app delegate at launch, and macOS 14 offers
no supported way to open a `Window` scene from there (`defaultLaunchBehavior`
is macOS 15+).

## Error Handling

- **Store file missing or corrupt** — treated as an empty list; the next
  recorded document rewrites it. A malformed file is never surfaced as an error
  to the user.
- **Store write failure** — ignored. Recents are a convenience; a failed write
  must not interrupt opening or saving a document.
- **Chosen file disappeared between drawing the list and the click** —
  `openDocument` throws; the row switches to its dimmed state and the welcome
  window stays open.
- **No existing window to join** — the document window simply opens as the
  first window of a new tab group.
- **Store file from a future version** — decoded as an empty list; the next
  recorded document rewrites it in the current format.

## Testing

Unit tests (`Tests/MarkoutTests/RecentDocumentsTests.swift`), all against pure
functions:

- Recording a new URL puts it at the front.
- Recording an existing URL moves it to the front without duplicating.
- The list is capped at 10, dropping the oldest.
- Paths differing only by `..`/symlink form are treated as the same entry.
- Encoding then decoding round-trips entries and their order.
- A corrupt or absent file decodes to an empty list.
- Path abbreviation replaces the home directory with `~`.
- Relative-time formatting yields today / yesterday / dated forms.

Verified manually by launching the app, per the project's convention for
AppKit/WebKit edges:

- Two documents open as two tabs in one window; ⌘⇧] switches.
- A tab drags out to its own window and merges back.
- Launch with no documents shows the welcome window; launch with a file
  argument does not.
- A recorded file, then renamed on disk, renders dimmed and unclickable the
  next time the welcome window is shown.
- Recents survive quitting and relaunching the app.
- With *Prefer tabs when opening documents* set to *Always*, neither the welcome
  window nor Settings is absorbed into the document tab group.
- With the welcome window frontmost, the Format menu, `Reload from Disk` and the
  Export commands are disabled — they must never act on a background tab's
  document. (`DocumentActions` is published through `.focusedSceneValue`, and the
  welcome window is an AppKit window outside the scene graph, so this needs
  checking rather than assuming.)
- After switching tabs, `⌘R` and Export act on the newly selected tab's file.

## Out of Scope

- Pinning or reordering recents.
- Content previews or thumbnails in the welcome window.
- A toolbar recents dropdown inside document windows.
- Restoring which tab was selected, or tab order, across launches — whatever
  macOS state restoration already does is what we get.
- Clearing the recents list, or removing a single entry from it.
- Sandboxing. The store keeps plain paths, which is sufficient for an
  unsandboxed app; a sandboxed build would have to store security-scoped
  bookmarks instead, and the `version` field exists to migrate that.
- Fixing the ad-hoc signing situation so the system recents list persists. Even
  if a Developer ID signature later revives the system list, this store stays —
  the welcome window needs paths, timestamps and existence checks that the
  system list does not expose.
