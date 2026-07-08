# `markout` CLI Command

**Date:** 2026-07-08
**Status:** Approved

## Problem

Markout is only launchable by double-clicking in Finder or via a document
association. There is no way to open a file from the terminal, unlike other
editors (`code file.md`, `subl file.md`).

## Goal

Running `markout <path>` in a terminal opens that file in Markout, reusing a
running instance if one exists. Running `markout` with no arguments just
launches the app. This must work out of the box for anyone who installs via
the existing Homebrew cask (`brew install --cask maxmilian/tap/markout`).

## Decisions (locked during brainstorming)

1. **Implementation**: a plain shell script bundled inside the app bundle at
   `Contents/Resources/markout`, not a separate compiled CLI target.
2. **App lookup**: the script shells out to `open -a Markout "$@"`, letting
   macOS LaunchServices resolve the app by name (equivalent to Spotlight
   lookup). It does not attempt to resolve its own bundle path via `readlink`
   chains — only one canonical install location (`/Applications`, via the
   cask) needs to be supported.
3. **Error handling**: none beyond what `open` already provides. A
   nonexistent path is left to `open`'s own stderr message and exit code —
   this is a thin wrapper, not a UX layer.
4. **Installation into PATH**: handled entirely by Homebrew. The cask
   (`maxmilian/homebrew-tap`, `Casks/markout.rb`) gets a `binary` stanza
   pointing at the bundled script, so `brew install --cask` symlinks it into
   `HOMEBREW_PREFIX/bin/markout` automatically, and `brew uninstall` /
   `brew upgrade` clean it up the same way (no manual `zap` needed).
5. **Docs**: only the main `README.md` gets a usage line; the translated
   README variants (ja/ko/zh-CN/zh-TW) are out of scope for this change.

## Design

### 1. `Resources/markout` (new file in this repo)

```sh
#!/bin/bash
exec open -a Markout "$@"
```

Executable bit set (`chmod +x`).

### 2. `project.yml`

Add this file to the `Markout` target's `sources` list as a resource, next to
the existing `default.css` resource entry:

```yaml
- path: Resources/markout
  buildPhase: resources
```

Xcode's Copy Bundle Resources phase preserves Unix file permissions, so the
executable bit survives into `Markout.app/Contents/Resources/markout`.

### 3. `homebrew-tap/Casks/markout.rb` (separate repo)

Add one line after `app "Markout.app"`:

```ruby
binary "#{appdir}/Markout.app/Contents/Resources/markout"
```

### 4. `README.md`

Add a one-line usage example under the existing Homebrew install
instructions, e.g.:

```sh
markout path/to/file.md   # opens the file in Markout
```

## Out of scope

- Compiled/native CLI target.
- Manual-install (non-Homebrew) instructions or symlink docs.
- Flags, `--help`, `--version`, stdin support, or any argument beyond passing
  paths straight through to `open`.
- Translated README updates.

## Verification

No pure logic exists here to unit-test — this is a packaging change.
Verification is manual:

1. `xcodegen generate` then build the app.
2. Run `Markout.app/Contents/Resources/markout <path>` directly from the
   build output and confirm it opens/focuses a window on that file.
3. In a local checkout of `homebrew-tap`, confirm the cask's `binary` stanza
   resolves (`brew audit`/local install) and that `markout <path>` works after
   installing.
