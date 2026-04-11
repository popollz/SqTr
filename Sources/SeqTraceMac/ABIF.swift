import Foundation

enum ABIFError: Error, CustomStringConvertible {
    case notABIF
    case truncated(String)
    case invalidDirectory
    case unsupportedDataType(UInt16)
    case missingTag(name: String, number: Int)

    var description: String {
        switch self {
        case .notABIF: return "Not an ABIF/AB1 file (missing ABIF magic)."
        case .truncated(let what): return "File truncated while reading \(what)."
        case .invalidDirectory: return "Invalid ABIF directory."
        case .unsupportedDataType(let t): return "Unsupported ABIF element type \(t)."
        case .missingTag(let name, let number): return "Missing ABIF tag \(name)\(number)."
        }
    }
}

/// Minimal ABIF (Applied Biosystems) reader sufficient for AB1 chromatograms.
struct ABIFFile: Sendable {
    struct DirEntry: Sendable, Hashable {
        var name: String           // 4 chars
        var number: Int            // e.g. 9..12 for DATA9..DATA12
        var elementType: UInt16    // ABIF type code
        var elementSize: UInt16    // bytes per element
        var elementCount: Int
        var dataSize: Int
        var dataOffset: Int
    }

    let data: Data
    let directory: [DirEntry]

    func entry(named name: String, number: Int) -> DirEntry? {
        directory.first(where: { $0.name == name && $0.number == number })
    }

    func bytes(for entry: DirEntry) throws -> Data {
        if entry.dataOffset < 0 || entry.dataSize < 0 || entry.dataOffset + entry.dataSize > data.count {
            throw ABIFError.truncated("tag \(entry.name)\(entry.number) bytes")
        }
        return data.subdata(in: entry.dataOffset..<(entry.dataOffset + entry.dataSize))
    }
}

extension ABIFFile {
    static func read(url: URL) throws -> ABIFFile {
        let data = try Data(contentsOf: url)
        return try read(data: data)
    }

    static func read(data: Data) throws -> ABIFFile {
        guard data.count >= 6 else { throw ABIFError.truncated("header") }
        guard data.readASCII(offset: 0, count: 4) == "ABIF" else { throw ABIFError.notABIF }

        // ABIF layout:
        // 0..3  "ABIF"
        // 4..5  version (UInt16 BE)
        // 6..   root directory entry (28 bytes), whose elementCount is dirCount and dataOffset is dirOffset.
        let root = try readDirEntry(from: data, base: 6)
        let dirCount = root.elementCount
        let dirOffset = root.dataOffset

        if dirCount <= 0 || dirOffset <= 0 || dirOffset + dirCount * 28 > data.count {
            throw ABIFError.invalidDirectory
        }

        var entries: [DirEntry] = []
        entries.reserveCapacity(dirCount)

        for i in 0..<dirCount {
            let base = dirOffset + i * 28
            entries.append(try readDirEntry(from: data, base: base))
        }

        return ABIFFile(data: data, directory: entries)
    }

    private static func readDirEntry(from data: Data, base: Int) throws -> DirEntry {
        guard base >= 0, base + 28 <= data.count else {
            throw ABIFError.truncated("directory entry at \(base)")
        }

        let name = data.readASCII(offset: base + 0, count: 4)
        let number = Int(try data.readInt32BE(offset: base + 4))
        let elementType = try data.readUInt16BE(offset: base + 8)
        let elementSize = try data.readUInt16BE(offset: base + 10)
        let elementCount = Int(try data.readInt32BE(offset: base + 12))
        let dataSize = Int(try data.readInt32BE(offset: base + 16))
        let dataOffsetOrInline = Int(try data.readInt32BE(offset: base + 20))

        let offset: Int
        if dataSize <= 4 {
            // Inline in the "data offset" field area.
            offset = base + 20
        } else {
            offset = dataOffsetOrInline
        }

        return DirEntry(
            name: name,
            number: number,
            elementType: elementType,
            elementSize: elementSize,
            elementCount: elementCount,
            dataSize: dataSize,
            dataOffset: offset
        )
    }
}

private extension Data {
    func readASCII(offset: Int, count: Int) -> String {
        let end = Swift.min(self.count, offset + count)
        guard offset >= 0, offset < end else { return "" }
        let sub = self.subdata(in: offset..<end)
        return String(bytes: sub, encoding: .ascii) ?? ""
    }

    func readUInt16BE(offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { throw ABIFError.truncated("UInt16 at \(offset)") }
        return (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    func readInt32BE(offset: Int) throws -> Int32 {
        guard offset >= 0, offset + 4 <= count else { throw ABIFError.truncated("Int32 at \(offset)") }
        let b0 = Int32(self[offset]) << 24
        let b1 = Int32(self[offset + 1]) << 16
        let b2 = Int32(self[offset + 2]) << 8
        let b3 = Int32(self[offset + 3])
        return b0 | b1 | b2 | b3
    }
}

