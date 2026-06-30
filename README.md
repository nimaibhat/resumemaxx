# resumemaxx

A native macOS app for working on LaTeX resumes: a resume copilot chat on the
left, a live PDF preview on the right, and a library of your resumes in the
sidebar. The assistant is Claude (via the Claude Agent SDK) running on your
existing Claude subscription.

This is the native rewrite. The original terminal (TUI) version lives on the
`tui` branch.

## Why native

The work of editing a resume is mouse driven: select text, zoom into a region,
scroll, search. A real PDF view (PDFKit) gives all of that for free, with no
flicker on recompile. The terminal version had to rasterize the PDF and stream
it through tmux, which fought the workflow.

## What it does

- Sidebar lists the resumes in a folder you pick.
- Selecting one compiles it with latexmk into a contained build dir and shows
  the PDF. Saving the file recompiles and reloads the preview, keeping your
  scroll position and zoom.
- The assistant chat edits the open file directly. It always knows which file
  you are on, so it never asks. Its edits appear in the preview as soon as it
  saves.

## Requirements

- macOS 14 or later
- Xcode and [XcodeGen](https://github.com/yonsm/XcodeGen) to build
  (`brew install xcodegen`)
- Node 18 or later (for the assistant sidecar)
- A TeX distribution with `latexmk` (for example TeX Live or BasicTeX)
- Claude Code signed in, or `CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY` set

## Build and run

```sh
brew install xcodegen
cd sidecar && npm install && cd ..
xcodegen generate
open resumemaxx.xcodeproj   # then press Run in Xcode
```

Or build and launch from the command line:

```sh
xcodegen generate
xcodebuild -project resumemaxx.xcodeproj -scheme resumemaxx \
  -configuration Debug -derivedDataPath .build_xcode \
  CODE_SIGNING_ALLOWED=NO build
open .build_xcode/Build/Products/Debug/resumemaxx.app
```

## How it works

```
SwiftUI app
  Sidebar  ............ scans a folder for .tex resumes
  PreviewColumn ....... PDFKit (selection, region zoom, scroll, search)
  ChatPanel ........... streaming chat
        |
   Sidecar.swift  <--- newline-delimited JSON --->  sidecar/sidecar.mjs
                                                       @anthropic-ai/claude-agent-sdk
  LatexCompiler ....... latexmk into .resumemaxx/build
  FileWatcher ......... recompiles on save (debounced)
```

The Node sidecar drives the Claude Agent SDK, streams text and tool events back
to the app, and keeps a separate conversation per resume.

## Distribution

The app bundles only the small sidecar source; the Node runtime installs into
Application Support on first run, so the `.app` has no third-party binaries to
sign. To produce a signed, notarized build:

```sh
# one-time: store notarytool credentials
xcrun notarytool store-credentials resumemaxx-notary \
  --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PW

SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="resumemaxx-notary" \
  ./scripts/release.sh
```

This requires an Apple Developer account (Developer ID certificate). The script
builds Release, signs with the hardened runtime + `app/resumemaxx.entitlements`,
notarizes, and staples.

## Layout

- `app/` SwiftUI sources (project generated from `project.yml` by XcodeGen)
- `sidecar/` Node Agent SDK backend
- `scripts/release.sh` signed + notarized build
- `tui` branch: the original terminal version

## License

MIT
