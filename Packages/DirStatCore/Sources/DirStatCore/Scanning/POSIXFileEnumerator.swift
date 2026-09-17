import Darwin

/// One entry read from a directory, already `fstatat`'d with `AT_SYMLINK_NOFOLLOW`.
/// For directory entries, `childFD` is a freshly `openat`'d file descriptor for
/// recursing into it (already opened here, while the parent directory's fd from
/// `fdopendir` is still valid) — `nil` if opening failed (permission denied).
struct RawDirEntry {
    let name: String
    let stat: stat
    let isDirectory: Bool
    let isSymlink: Bool
    let childFD: Int32?
}

/// Thin wrapper over the Darwin POSIX directory APIs. Uses `openat`/`fstatat`
/// relative to open directory file descriptors rather than `FileManager`/`URL`
/// (which bridge through CFURL and are materially slower at scan scale) and rather
/// than raw `fts()` (correct, but its `FTSENT` pointer/union fields are awkward to
/// wrap safely in Swift for little benefit here).
enum POSIXFileEnumerator {
    /// Opens `path` as a directory file descriptor, or `nil` if it can't be opened
    /// (doesn't exist, isn't a directory, or permission denied).
    static func openDirectory(atPath path: String) -> Int32? {
        let fd = open(path, O_RDONLY | O_DIRECTORY)
        return fd >= 0 ? fd : nil
    }

    /// Lists the entries of the directory referenced by `parentFD` (excluding "."
    /// and ".."), opening a child fd for each subdirectory entry along the way.
    /// Takes ownership of `parentFD`: it is closed (via `closedir`) before returning.
    static func listEntries(parentFD: Int32) -> [RawDirEntry] {
        guard let dirp = fdopendir(parentFD) else {
            close(parentFD)
            return []
        }
        defer { closedir(dirp) }

        let fd = dirfd(dirp)
        var results: [RawDirEntry] = []
        while let entry = readdir(dirp) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw -> String in
                let ptr = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
                return String(cString: ptr)
            }
            if name == "." || name == ".." { continue }

            var st = stat()
            guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else {
                // Vanished between readdir and stat, or an otherwise unreadable entry — skip it.
                continue
            }

            let isSymlink = (st.st_mode & S_IFMT) == S_IFLNK
            let isDirectory = !isSymlink && (st.st_mode & S_IFMT) == S_IFDIR

            var childFD: Int32?
            if isDirectory {
                let opened = openat(fd, name, O_RDONLY | O_DIRECTORY)
                childFD = opened >= 0 ? opened : nil
            }

            results.append(RawDirEntry(name: name, stat: st, isDirectory: isDirectory, isSymlink: isSymlink, childFD: childFD))
        }
        return results
    }
}
