# Swift SeqTrace — User guide (internal testing)

**Version:** see **Swift SeqTrace → About Swift SeqTrace** for the exact build you are running.

## What this app does

Swift SeqTrace is a native, Swift-based sequence trace editor for fast and reliable DNA data analysis. It is inspired by the classic [SeqTrace](https://github.com/stuckyb/seqtrace) project.

The app opens **Applied Biosystems-style** `.ab1` / `.abi` (ABIF) trace files and draws the four-dye **chromatogram**. You can also open **two traces** to build a simple **contig** view.

## Install (internal build)

1. Unzip or mount the build you received (e.g. `SwiftSeqTrace-0.1.0-b1.dmg`).
2. Drag **Swift SeqTrace.app** to **Applications** (or run it from the disk image).
3. If macOS blocks the app (unsigned build): **Control-click** the app → **Open** → confirm **Open** once.

## Basic use

1. Launch **Swift SeqTrace**.
2. **Open .ab1 / .abi…** — choose a single trace file.
3. **Open pair (F+R)…** — choose **two** `.ab1` files (forward + reverse) for contig assembly.

Menu shortcuts match the buttons where shown.

## Sequence panel & selection

- **Single trace:** The **Sequence** box is a real text editor with **A/C/G/T coloring** (green / blue / dark / red). **Copy sequence** copies the **full** edited sequence (one plain-text line). **Click or drag** to select bases; the chromatogram shows a **yellow band** (or a thin line at the caret) on the matching trace region. **⌘C** / context **Copy** copies the **selection** (or the base at the caret). **⌘X** / **Cut** copies then removes the selection (or one base at the caret). **Right-click** also has **Delete**, **Replace with N**, etc.
- **Pair / contig:** **Copy consensus** copies the **full** consensus string. Selection **Copy** / **Cut** / **Delete** work like single-trace. **Right-click** for **Cut**, **Copy**, **Delete**, **Replace with N**, **Use Forward base**, and **Use Reverse base** (when one base is selected, the toolbar can still set F/R/N).

## Limitations (this milestone)

- Channel order is assumed as **DATA9=A, DATA10=C, DATA11=G, DATA12=T**. Some instruments encode order in **FWO_1**; results may look wrong until that is implemented.
- This is an **early internal** build: expect rough edges.

## Where to get help in the app

- **Swift SeqTrace → About Swift SeqTrace** — version, build, description, and feedback contact.
- **Help → Swift SeqTrace User Guide** (shortcut **⇧⌘?**) — opens this file from the app bundle.

## Reporting issues

Include:

1. **Version and build** from **About**.
2. What you did (single file vs pair, file type).
3. Whether you can share a **sample `.ab1`** (or a redacted copy) with the contact below.

**Feedback:** use the address shown in **About Swift SeqTrace** (set in source as `AppInfo.feedbackContact` for each release).
