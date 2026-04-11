import Foundation

enum ABITraceReader {
    static func read(url: URL) throws -> ABITrace {
        let abif = try ABIFFile.read(url: url)

        // Prefer common processed traces DATA9..12, but many files use DATA1..4 (or other sets).
        // We'll detect the best 4-channel DATA set and then map channels using FWO_1 when present.
        let (dataEntries, sampleCount) = try findBestTraceDataEntries(in: abif)
        let channelOrder = (try? readASCIIString(abif, name: "FWO_", number: 1))
            .flatMap(parseFWO)

        let dataByBase = try mapDataEntriesToBases(
            abif: abif,
            entries: dataEntries,
            channelOrder: channelOrder
        )

        let a = dataByBase["A"] ?? []
        let c = dataByBase["C"] ?? []
        let g = dataByBase["G"] ?? []
        let t = dataByBase["T"] ?? []

        if a.count != sampleCount || c.count != sampleCount || g.count != sampleCount || t.count != sampleCount {
            // If mapping failed (missing bases), fall back to positional mapping.
            let raw = try dataEntries.map { try readUInt16Array(abif, entry: $0) }
            let fallback = padToFourUInt16(raw)
            return ABITrace(
                fileName: url.lastPathComponent,
                samplesA: fallback[0],
                samplesC: fallback[1],
                samplesG: fallback[2],
                samplesT: fallback[3],
                bases: readBestBases(abif),
                peakLocations: readBestPeakLocations(abif),
                qualities: readBestQualities(abif)
            )
        }

        let bases = readBestBases(abif)
        let peakLocs = readBestPeakLocations(abif)
        let quals = readBestQualities(abif)

        return ABITrace(
            fileName: url.lastPathComponent,
            samplesA: a,
            samplesC: c,
            samplesG: g,
            samplesT: t,
            bases: bases,
            peakLocations: peakLocs,
            qualities: quals
        )
    }

    private static func readBestBases(_ abif: ABIFFile) -> String? {
        // Many AB1 files store the (possibly edited) basecalls in PBAS2.
        // PBAS1 is commonly the original basecalls.
        let candidates: [(String, Int)] = [("PBAS", 2), ("PBAS", 1)]
        for (name, num) in candidates {
            if let s = try? readASCIIString(abif, name: name, number: num), !s.isEmpty {
                return s
            }
        }
        return nil
    }

    private static func readBestPeakLocations(_ abif: ABIFFile) -> [Int]? {
        let candidates: [(String, Int)] = [("PLOC", 2), ("PLOC", 1)]
        for (name, num) in candidates {
            if let arr = try? readInt16OrInt32ArrayAsInt(abif, name: name, number: num), !arr.isEmpty {
                return arr
            }
        }
        return nil
    }

    private static func readBestQualities(_ abif: ABIFFile) -> [UInt8]? {
        let candidates: [(String, Int)] = [("PCON", 2), ("PCON", 1)]
        for (name, num) in candidates {
            if let arr = try? readUInt8Array(abif, name: name, number: num), !arr.isEmpty {
                return arr
            }
        }
        return nil
    }

    private static func readUInt16Array(_ abif: ABIFFile, name: String, number: Int) throws -> [UInt16] {
        guard let entry = abif.entry(named: name, number: number) else {
            throw ABIFError.missingTag(name: name, number: number)
        }
        return try readUInt16Array(abif, entry: entry)
    }

    private static func readUInt16Array(_ abif: ABIFFile, entry: ABIFFile.DirEntry) throws -> [UInt16] {
        let bytes = try abif.bytes(for: entry)
        if entry.elementSize != 2 { throw ABIFError.unsupportedDataType(entry.elementType) }

        var out: [UInt16] = []
        out.reserveCapacity(entry.elementCount)

        for i in 0..<entry.elementCount {
            let o = i * 2
            if o + 2 > bytes.count { break }
            let v = (UInt16(bytes[o]) << 8) | UInt16(bytes[o + 1])
            out.append(v)
        }
        return out
    }

    private static func readUInt8Array(_ abif: ABIFFile, name: String, number: Int) throws -> [UInt8] {
        guard let entry = abif.entry(named: name, number: number) else {
            throw ABIFError.missingTag(name: name, number: number)
        }
        let bytes = try abif.bytes(for: entry)
        return [UInt8](bytes.prefix(entry.elementCount))
    }

    private static func readASCIIString(_ abif: ABIFFile, name: String, number: Int) throws -> String {
        guard let entry = abif.entry(named: name, number: number) else {
            throw ABIFError.missingTag(name: name, number: number)
        }
        let bytes = try abif.bytes(for: entry)
        return String(bytes: bytes.prefix(entry.dataSize), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters.union(.newlines)) ?? ""
    }

    private static func readInt16OrInt32ArrayAsInt(_ abif: ABIFFile, name: String, number: Int) throws -> [Int] {
        guard let entry = abif.entry(named: name, number: number) else {
            throw ABIFError.missingTag(name: name, number: number)
        }
        let bytes = try abif.bytes(for: entry)

        if entry.elementSize == 2 {
            var out: [Int] = []
            out.reserveCapacity(entry.elementCount)
            for i in 0..<entry.elementCount {
                let o = i * 2
                if o + 2 > bytes.count { break }
                let raw = Int16(bitPattern: (UInt16(bytes[o]) << 8) | UInt16(bytes[o + 1]))
                out.append(Int(raw))
            }
            return out
        }

        if entry.elementSize == 4 {
            var out: [Int] = []
            out.reserveCapacity(entry.elementCount)
            for i in 0..<entry.elementCount {
                let o = i * 4
                if o + 4 > bytes.count { break }
                let b0 = Int32(bytes[o]) << 24
                let b1 = Int32(bytes[o + 1]) << 16
                let b2 = Int32(bytes[o + 2]) << 8
                let b3 = Int32(bytes[o + 3])
                out.append(Int(b0 | b1 | b2 | b3))
            }
            return out
        }

        throw ABIFError.unsupportedDataType(entry.elementType)
    }

    private static func findBestTraceDataEntries(in abif: ABIFFile) throws -> ([ABIFFile.DirEntry], Int) {
        let candidates = abif.directory.filter {
            $0.name == "DATA" &&
            $0.elementSize == 2 &&
            $0.elementCount > 200 &&
            $0.dataSize == $0.elementCount * Int($0.elementSize)
        }

        // First try the classic processed set.
        let classic = [9, 10, 11, 12].compactMap { abif.entry(named: "DATA", number: $0) }
        if classic.count == 4 {
            let c0 = classic[0].elementCount
            if classic.allSatisfy({ $0.elementCount == c0 }) { return (classic, c0) }
        }

        // Group by elementCount; pick the largest group with >= 4 entries and highest elementCount.
        let grouped = Dictionary(grouping: candidates, by: { $0.elementCount })
        let best = grouped
            .filter { $0.value.count >= 4 }
            .sorted {
                if $0.key != $1.key { return $0.key > $1.key }
                return $0.value.count > $1.value.count
            }
            .first

        if let best {
            let entries = best.value.sorted { $0.number < $1.number }
            return (Array(entries.prefix(4)), best.key)
        }

        // Last chance: try DATA1..4 even if elementCount heuristic failed.
        let first = [1, 2, 3, 4].compactMap { abif.entry(named: "DATA", number: $0) }
        if first.count == 4 {
            let c0 = first[0].elementCount
            return (first, c0)
        }

        throw ABIFError.missingTag(name: "DATA", number: 9)
    }

    private static func parseFWO(_ raw: String) -> [String]? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let chars = cleaned.map { String($0) }.filter { ["A", "C", "G", "T"].contains($0) }
        return chars.count == 4 ? chars : nil
    }

    private static func mapDataEntriesToBases(
        abif: ABIFFile,
        entries: [ABIFFile.DirEntry],
        channelOrder: [String]?
    ) throws -> [String: [UInt16]] {
        let arrays = try entries.map { try readUInt16Array(abif, entry: $0) }
        let arrays4 = padToFourUInt16(arrays)

        guard let channelOrder else {
            // Unknown order; return positional mapping (will be overridden by fallback if needed).
            return ["A": arrays4[0], "C": arrays4[1], "G": arrays4[2], "T": arrays4[3]]
        }

        // channelOrder describes the base for each channel in order of selected DATA entries.
        var out: [String: [UInt16]] = [:]
        for i in 0..<4 {
            out[channelOrder[i]] = arrays4[i]
        }
        return out
    }

    private static func padToFourUInt16(_ arr: [[UInt16]]) -> [[UInt16]] {
        if arr.count >= 4 { return Array(arr.prefix(4)) }
        guard let first = arr.first else { return [[], [], [], []] }
        return arr + Array(repeating: first, count: 4 - arr.count)
    }
}

