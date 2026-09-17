# Notice and attribution

## Relationship to WinDirStat

WinDirStatMac is inspired by, and named in reference to, **WinDirStat**, "a
free, open-source disk usage analyzer for Microsoft Windows" — original author
**Bernhard Seifert**, with major contributions from Bryan Berns and Oliver
Schneider and the rest of the WinDirStat community listed in the project's own
[CONTRIBUTORS.md](https://github.com/windirstat/windirstat/blob/master/CONTRIBUTORS.md).
Official site [windirstat.net](https://windirstat.net), source code at
[github.com/windirstat/windirstat](https://github.com/windirstat/windirstat).
Copyright © Bernhard Seifert and the WinDirStat contributors, licensed under
the GNU General Public License, version 2 or (at the licensor's option) any
later version (GPL-2.0-or-later).

**No source code from WinDirStat is included in or was copied into this
project.** WinDirStat is implemented in C++ using the Microsoft Foundation
Class library and Win32-specific APIs (NTFS/MTP directory enumeration, ACL-based
permissions, the Windows registry, `uxtheme` dark-mode hooks, COM shell
integration) that do not compile or run on macOS and have no macOS equivalent
to port to. WinDirStatMac is a ground-up reimplementation, written in Swift for
SwiftUI/AppKit, of the same *category* of tool: scan a folder, show its
contents as a sortable tree with sizes, break it down by file extension,
visualize it as an interactive treemap, and offer cleanup actions on what you
find.

What WinDirStatMac does take from WinDirStat, conceptually:

- The overall feature set and workflow (tree + extension list + treemap +
  cleanup actions) that WinDirStat popularized on Windows.
- The choice of a **squarified treemap layout** (the algorithm family
  described by Bruls, Huizing, and van Wijk, 2000) for the treemap
  visualization — the same family of algorithm WinDirStat itself uses. The
  implementation in `Packages/DirStatCore/Sources/DirStatCore/Treemap` was
  written from scratch against the published algorithm description, not
  transcribed from WinDirStat's own `TreeMapLayout.cpp`.

Because this project's design is derived from WinDirStat's in these ways, it
is licensed under the same license WinDirStat uses — GPL-2.0-or-later — out of
respect for the original project's terms and intent, even though no GPL-licensed
source was directly reused.

## Trademark note

"WinDirStat" is the name of the upstream project referenced above. This
project's working name, "WinDirStatMac," is chosen for clarity about its
lineage during development. Anyone shipping a public release of this codebase
should confirm the final product name doesn't create confusion with, or
improperly imply endorsement by, the WinDirStat project before distributing it.

## Third-party code

WinDirStatMac currently has no third-party library dependencies — it's built
entirely on Apple's own Foundation, AppKit, SwiftUI, and Swift Concurrency, plus
Swift Testing (bundled with the Swift toolchain) for the test suite. If any
external dependency is added later, its license must be checked for
compatibility with GPL-2.0-or-later and recorded in this file before it ships.
