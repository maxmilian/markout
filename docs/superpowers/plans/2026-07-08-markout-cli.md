# Markout CLI Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Running `markout <path>` in a terminal opens that file in the
Markout app (reusing a running instance), and this works automatically for
anyone who installs Markout via the existing Homebrew cask.

**Architecture:** A one-line shell script (`open -a Markout "$@"`) gets
bundled into the app at `Contents/Resources/markout` via `project.yml`. The
Homebrew cask in the separate `maxmilian/homebrew-tap` repo gets a `binary`
stanza pointing at that bundled script, so `brew install --cask` symlinks it
into `HOMEBREW_PREFIX/bin/markout`.

**Tech Stack:** Bash, XcodeGen (`project.yml`), Homebrew Cask (Ruby DSL).

## Global Constraints

- Deployment target: macOS 14.0 (from `project.yml` `options.deploymentTarget.macOS`).
- The Xcode project (`Markout.xcodeproj`) is generated from `project.yml` via
  `xcodegen generate` — never hand-edit the `.xcodeproj`; regenerate after
  any `project.yml` change.
- Ad-hoc code signing (`CODE_SIGN_IDENTITY: "-"`, `CODE_SIGNING_REQUIRED: NO`)
  — no notarization, no entitlements to worry about for a plain resource file.
- This spec covers only: the bundled script, the `project.yml` wiring, the
  cask `binary` stanza, and a `README.md` usage line. No compiled CLI target,
  no manual-install docs, no translated README updates, no flags beyond
  passing paths through to `open`.
- Cask repo location on this machine: `/Users/maxmilian/side/homebrew-tap`
  (already cloned; remote `git@github.com:maxmilian/homebrew-tap.git`).

---

### Task 1: Bundle the `markout` CLI script into the app

**Files:**
- Create: `Resources/markout`
- Modify: `project.yml` (Markout target `sources` list)

**Interfaces:**
- Produces: an executable file at `Markout.app/Contents/Resources/markout`
  after building, callable as `Contents/Resources/markout <path>`, which
  opens/focuses a Markout window on `<path>` (or launches Markout with no
  args).

- [ ] **Step 1: Create the script file**

Create `Resources/markout`:

```sh
#!/bin/bash
exec open -a Markout "$@"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x Resources/markout
```

- [ ] **Step 3: Wire it into `project.yml`**

Open `project.yml`. Find the `Markout` target's `sources` list:

```yaml
    sources:
      - Sources/Markout
      - path: Sources/Markout/Render/default.css
        buildPhase: resources
      - path: Resources/PreviewAssets
        type: folder
        buildPhase: resources
      - path: Resources/Assets.xcassets
        buildPhase: resources
```

Add a new entry for the script, right after the `Assets.xcassets` entry:

```yaml
      - path: Resources/markout
        buildPhase: resources
```

So the full `sources` list becomes:

```yaml
    sources:
      - Sources/Markout
      - path: Sources/Markout/Render/default.css
        buildPhase: resources
      - path: Resources/PreviewAssets
        type: folder
        buildPhase: resources
      - path: Resources/Assets.xcassets
        buildPhase: resources
      - path: Resources/markout
        buildPhase: resources
```

- [ ] **Step 4: Regenerate the Xcode project**

```bash
xcodegen generate
```

Expected: completes with `Generated project at Markout.xcodeproj`, no errors.

- [ ] **Step 5: Build the app**

```bash
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify the script landed in the bundle with the executable bit intact**

```bash
ls -l .build/dd/Build/Products/Debug/Markout.app/Contents/Resources/markout
```

Expected: file exists, permissions include `x` (e.g. `-rwxr-xr-x`).

- [ ] **Step 7: Verify it actually opens a file**

```bash
open .build/dd/Build/Products/Debug/Markout.app  # ensure app quit first if running, for a clean check
echo '# hello' > /tmp/markout-cli-test.md
.build/dd/Build/Products/Debug/Markout.app/Contents/Resources/markout /tmp/markout-cli-test.md
```

Expected: Markout opens (or an existing running instance focuses) a window
showing `markout-cli-test.md` with the `# hello` content.

- [ ] **Step 8: Commit**

```bash
git add Resources/markout project.yml
git commit -m "feat: add markout CLI script for opening files from the terminal"
```

---

### Task 2: Wire the script into the Homebrew cask

**Files:**
- Modify: `/Users/maxmilian/side/homebrew-tap/Casks/markout.rb`

**Interfaces:**
- Consumes: the bundled path from Task 1,
  `Markout.app/Contents/Resources/markout`.
- Produces: `brew install --cask markout` creates a symlink at
  `HOMEBREW_PREFIX/bin/markout` pointing into the installed app bundle.

- [ ] **Step 1: Confirm current cask contents**

```bash
cat /Users/maxmilian/side/homebrew-tap/Casks/markout.rb
```

Expected to see (current state, before this task's edit):

```ruby
cask "markout" do
  version "0.1.0"
  sha256 "fa3d661572ed08a62fd40119ddd6133b2cdc501a3ed4ebfd0ddecd45ce1caf39"

  url "https://github.com/maxmilian/markout/releases/download/v#{version}/Markout-v#{version}.dmg"
  name "Markout"
  desc "Native macOS Markdown editor with live preview, math, and diagrams"
  homepage "https://github.com/maxmilian/markout/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Markout.app"

  zap trash: "~/Library/Preferences/tech.ankey.Markout.plist"
end
```

- [ ] **Step 2: Add the `binary` stanza**

Edit `/Users/maxmilian/side/homebrew-tap/Casks/markout.rb` so the `app` line
is followed by a `binary` line:

```ruby
  app "Markout.app"
  binary "#{appdir}/Markout.app/Contents/Resources/markout"

  zap trash: "~/Library/Preferences/tech.ankey.Markout.plist"
```

- [ ] **Step 3: Run `brew audit` on the cask**

```bash
cd /Users/maxmilian/side/homebrew-tap
brew audit --cask Casks/markout.rb
```

Expected: no errors (warnings about the tap not being a recognized official
tap are fine; there should be no Ruby syntax or DSL errors).

- [ ] **Step 4: Locally reinstall the cask and verify the symlink**

```bash
brew reinstall --cask maxmilian/tap/markout
ls -l "$(brew --prefix)/bin/markout"
```

Expected: symlink exists, resolving to
`/Applications/Markout.app/Contents/Resources/markout`.

- [ ] **Step 5: Verify the installed CLI opens a file**

```bash
echo '# hello from cask' > /tmp/markout-cask-test.md
markout /tmp/markout-cask-test.md
```

Expected: Markout opens a window showing `markout-cask-test.md`.

- [ ] **Step 6: Commit in the tap repo**

```bash
cd /Users/maxmilian/side/homebrew-tap
git add Casks/markout.rb
git commit -m "feat: symlink markout CLI binary from app bundle"
```

---

### Task 3: Document the CLI in the README

**Files:**
- Modify: `README.md`

**Interfaces:**
- None (documentation only).

- [ ] **Step 1: Locate the Homebrew install section**

```bash
grep -n "Homebrew" README.md
```

Expected: a line around `### Homebrew` followed shortly by the
`brew install --cask maxmilian/tap/markout` line (per the existing README
structure referenced in this repo's `CLAUDE.md`).

- [ ] **Step 2: Add a CLI usage line**

Directly below the `brew install --cask maxmilian/tap/markout` code block in
`README.md`, add:

````markdown
Once installed, open any file from the terminal:

```sh
markout path/to/file.md
```
````

- [ ] **Step 3: Sanity-check the rendered Markdown**

```bash
grep -n -A3 "brew install --cask maxmilian/tap/markout" README.md
```

Expected: shows the install command immediately followed by the new
`markout path/to/file.md` usage block, with no broken code-fence nesting
(three-backtick fences must not be nested — confirm the surrounding fence
count is even).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document markout CLI usage"
```
