# Swift SeqTrace

A native, Swift-based sequence trace editor for fast and reliable DNA data analysis. Inspired by the classic [SeqTrace](https://github.com/stuckyb/seqtrace) project.

First milestone: open an `.ab1` (ABIF) file and render the chromatogram traces.

## System requirements

- **Minimum macOS:** 13 (Ventura) or later. This matches `platforms: [.macOS(.v13)]` in `Package.swift` and the SwiftUI APIs used in the app.
- **Hardware:** Apple Silicon (arm64) and Intel (x86_64) Macs that can run Ventura or newer. Release builds can be shipped as a **universal binary** (both architectures in one app) so a single download runs on either CPU.
- **Note:** The minimum OS version is the same for universal and single-architecture builds; “universal” only means both CPU types are included, not a different macOS floor.

## Open in Xcode

- Open Xcode
- File → Open… → select the project folder (the one containing `Package.swift`)
- Press Run

## Build a DMG for the lab

From the repository root (full **Xcode** recommended if you want a **universal** Intel + Apple Silicon binary):

```bash
./scripts/make-dmg.sh
```

- Output: **`dist/SwiftSeqTrace-<version>-b<build>.dmg`** (version and build are read from `Sources/SeqTraceMac/AppInfo.swift`). The disk image contains **`Swift SeqTrace.app`**.
- **First open:** if the app is only ad-hoc signed, recipients may need **Control-click → Open** once.
- **Universal binary:** run with `BUILD_UNIVERSAL=1 ./scripts/make-dmg.sh` on a Mac that has Apple’s **xcbuild** (full Xcode install). Otherwise the script builds for **your Mac’s architecture only**.

## Help, About, and internal releases

- **User guide (bundled):** `Sources/SeqTraceMac/Resources/USER_GUIDE.md` — copied into the app; testers can open it via **Help → Swift SeqTrace User Guide** (⇧⌘?).
- **About:** **Swift SeqTrace → About Swift SeqTrace** shows version, build, description, and feedback from `AppInfo.swift`.
- **Dock icon:** a **waveform** SF Symbol is applied at launch as a placeholder until you add a real icon (`.icns` / asset catalog in your shipping app bundle).
- **Each internal drop:** bump `AppInfo.marketingVersion` / `AppInfo.build`, set `AppInfo.feedbackContact`, and ship the DMG or zip with a name that includes version + build.

## GitHub Releases

Published builds live under [Releases](https://github.com/popollz/SqTr/releases). For a new version: bump `AppInfo`, run `./scripts/make-dmg.sh`, commit and push, then tag and publish (example with [GitHub CLI](https://cli.github.com/) `gh`):

```bash
git tag -a v0.1.1 -m "Swift SeqTrace 0.1.1 (build 1)"
git push origin v0.1.1
gh release create v0.1.1 "./dist/SwiftSeqTrace-0.1.1-b1.dmg" --repo popollz/SqTr \
  --title "Swift SeqTrace 0.1.1 (build 1)" --notes "Short release notes here."
```

## Current status

- Opens `.ab1` files using an Open Panel
- Picks the best 4-channel `DATA` set (prefers `DATA9..DATA12`; falls back to `DATA1..DATA4` or the largest consistent set)
- Maps channels to bases using the instrument's `FWO_1` tag when present; falls back to positional mapping (`DATA9=A`, `DATA10=C`, `DATA11=G`, `DATA12=T`) when `FWO_1` is absent
- Unit-tested: see `Tests/SeqTraceMacTests/` (run with `swift test` or **⌘U** in Xcode)
