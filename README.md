# WinDirStatMac

A native macOS disk usage visualizer — folder tree, extension breakdown, and an
interactive treemap — built with Swift, SwiftUI, and AppKit. No web views, no
Electron.

WinDirStatMac is a from-scratch reimplementation of the ideas behind
[WinDirStat](https://windirstat.net) ([source](https://github.com/windirstat/windirstat)) —
created by **Bernhard Seifert** and maintained today by Bryan Berns, Oliver
Schneider, and the WinDirStat community — for macOS. WinDirStat itself is a
Windows-only C++/MFC application; none of its source is portable to or reused
on macOS. This project instead reimplements the same kind of tool (disk scan →
folder tree with sizes → extension list → squarified treemap → cleanup
actions) natively for macOS, informed by WinDirStat's feature set and its
choice of the squarified treemap layout algorithm. See [NOTICE.md](NOTICE.md)
for the full attribution.

## Status

Actively being built out. Current native-engine and app-shell functionality:

- Concurrent POSIX-based directory scanner (`Packages/DirStatCore`)
- Folder tree view with size bars (`NSOutlineView`)
- Interactive nested treemap (hover, click-to-select, double-click-to-zoom,
  breadcrumb)
- Per-extension breakdown panel
- Cleanup actions (reveal in Finder, open, move to Trash, delete permanently)
  with a Full Disk Access onboarding banner

Not yet implemented: duplicate file finder, sunburst/flame graph views,
permissions viewer, file search, CSV import/export, localization, code signing
and notarization for distribution outside this development environment.

## Building

Requires Xcode 16+ / Swift 6 toolchain, macOS 14+.

```bash
swift build            # build
swift run               # run the app
swift test --package-path Packages/DirStatCore   # run the core engine's unit tests
```

## License

WinDirStatMac is licensed under the **GNU General Public License v2.0 or
later** (GPL-2.0-or-later) — see [LICENSE](LICENSE). This matches the license
of the WinDirStat project that inspired it. See [NOTICE.md](NOTICE.md) for why,
and for the full attribution to the original project and its authors.
