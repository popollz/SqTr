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

## Chromatogram view (4Peaks-style)

- **Header readout:** the left side shows **Base _letter_ _number_, Quality: _q_** for whatever base is currently selected (color-coded A=green, C=blue, G=dark, T=red). Before you click anything, it shows **Base —** as a placeholder.
- **Top DNA strip:** bases are drawn as colored letters along the top of the trace so you can read the sequence without opening the sequence drawer.
- **Quality histogram:** a pale blue bar behind each base represents its **PHRED quality score** (higher = taller). The dashed horizontal lines mark **Q20** (≈ 1 % error) and **Q30** (≈ 0.1 % error) — bars that reach above Q20/Q30 are considered good/high quality.
- **Max peak label:** the small number at the top-left is the largest raw channel intensity in the currently visible window (useful when comparing files).
- **Toolbar:** the **⚙︎** button opens a popover with **Peak height** (Y-zoom) and **Pan** sliders. The main slider is horizontal zoom; the **copy icon** at the far right copies the full sequence.

## Interacting with the chromatogram

- **Click** anywhere on the trace to select the nearest base. The header updates, and a translucent blue column highlights that base across the strip and traces.
- **Drag** (click-and-drag on the trace) to **pan** left/right.
- **Pinch** (trackpad two-finger pinch) to **zoom in/out**. The view zooms around the center of what's currently visible so you don't lose your place.
- In **contig view**, clicking either the forward or reverse chromatogram moves the **consensus caret** — so both chromatograms re-highlight together.

## Sequence panel & selection

- **Single trace:** expand the **Sequence** drawer below the chromatogram to see the edited sequence as a real text editor with **A/C/G/T coloring**. **Copy sequence** copies the **full** edited sequence (one plain-text line). **Click or drag** in the drawer to select bases; the chromatogram shows a **blue selection column** (or a thin line at the caret) on the matching trace region. **⌘C** / context **Copy** copies the **selection** (or the base at the caret). **⌘X** / **Cut** copies then removes the selection (or one base at the caret). **Right-click** also has **Delete**, **Replace with N**, etc.
- **Pair / contig:** **Copy consensus** copies the **full** consensus string. Selection **Copy** / **Cut** / **Delete** work like single-trace. **Right-click** for **Cut**, **Copy**, **Delete**, **Replace with N**, **Use Forward base**, and **Use Reverse base** (when one base is selected, the toolbar can still set F/R/N).

## Limitations (this milestone)

- Channel order is read from the instrument's **FWO_1** tag when present; if it is missing, the app falls back to positional mapping (**DATA9=A, DATA10=C, DATA11=G, DATA12=T**). If traces ever look mis-assigned to the wrong base, please share the file via the feedback contact shown in **About**.
- **Trackpad two-finger swipe** does not yet pan the chromatogram — use **click-drag** on the trace, the **Pan slider** in the ⚙︎ popover, or pinch-to-zoom first and then pan. Scroll-wheel pan is planned for a later build.
- **Amino-acid translation** (reading-frame strip) is planned for the next release.
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
