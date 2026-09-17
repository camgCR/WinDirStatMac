// SPDX-License-Identifier: GPL-2.0-or-later
/// Pure, UI-free CSV text formatting — separate from `FileSystemTree`'s tree
/// walk so the escaping rules (the part actually worth testing carefully) can
/// be exercised directly against hand-built rows.
public enum CSVFormatter {
    public static let header = ["Path", "Name", "Type", "Size (logical)", "Size (on disk)", "Extension"]

    public static func format(rows: [CSVRow]) -> String {
        var lines: [String] = [header.map(escape).joined(separator: ",")]
        for row in rows {
            let fields = [
                row.path,
                row.name,
                row.type.rawValue,
                String(row.sizeLogical),
                String(row.sizeAllocated),
                row.extensionName ?? "",
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 4180: a field containing a comma, quote, or line break is wrapped in
    /// quotes, with any quote inside it doubled.
    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
