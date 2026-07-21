import Foundation

enum ZIPArchive {
    private static let localHeaderSignature: UInt32 = 0x04034b50
    private static let centralHeaderSignature: UInt32 = 0x02014b50
    private static let endSignature: UInt32 = 0x06054b50
    private static let utf8Flag: UInt16 = 0x0800
    private static let maximumEntrySize = 64 * 1_024 * 1_024
    private static let maximumArchiveSize = 256 * 1_024 * 1_024

    private struct CentralRecord {
        let name: [UInt8]
        let checksum: UInt32
        let size: UInt32
        let localOffset: UInt32
    }

    static func encode(entries: [String: Data]) throws -> Data {
        guard entries.count <= Int(UInt16.max) else {
            throw SaveArchiveError.invalidArchive("too many ZIP entries")
        }

        var archive = Data()
        var records: [CentralRecord] = []

        for name in entries.keys.sorted() {
            try validateEntryName(name)
            guard let contents = entries[name] else { continue }
            guard contents.count <= maximumEntrySize,
                  contents.count <= Int(UInt32.max),
                  archive.count <= Int(UInt32.max) else {
                throw SaveArchiveError.invalidArchive("ZIP entry is too large: \(name)")
            }
            let nameBytes = Array(name.utf8)
            guard nameBytes.count <= Int(UInt16.max) else {
                throw SaveArchiveError.invalidArchive("ZIP entry name is too long: \(name)")
            }

            let checksum = CRC32.checksum(contents)
            let size = UInt32(contents.count)
            let localOffset = UInt32(archive.count)
            archive.appendLittleEndian(localHeaderSignature)
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(utf8Flag)
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0x0021))
            archive.appendLittleEndian(checksum)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(UInt16(nameBytes.count))
            archive.appendLittleEndian(UInt16(0))
            archive.append(contentsOf: nameBytes)
            archive.append(contents)
            records.append(
                CentralRecord(
                    name: nameBytes,
                    checksum: checksum,
                    size: size,
                    localOffset: localOffset
                )
            )
        }

        guard archive.count <= Int(UInt32.max) else {
            throw SaveArchiveError.invalidArchive("ZIP archive is too large")
        }
        let centralOffset = UInt32(archive.count)

        for record in records {
            archive.appendLittleEndian(centralHeaderSignature)
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(utf8Flag)
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0x0021))
            archive.appendLittleEndian(record.checksum)
            archive.appendLittleEndian(record.size)
            archive.appendLittleEndian(record.size)
            archive.appendLittleEndian(UInt16(record.name.count))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt32(0))
            archive.appendLittleEndian(record.localOffset)
            archive.append(contentsOf: record.name)
        }

        guard archive.count <= Int(UInt32.max) else {
            throw SaveArchiveError.invalidArchive("ZIP central directory is too large")
        }
        let centralSize = UInt32(archive.count) - centralOffset
        let entryCount = UInt16(records.count)
        archive.appendLittleEndian(endSignature)
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(entryCount)
        archive.appendLittleEndian(entryCount)
        archive.appendLittleEndian(centralSize)
        archive.appendLittleEndian(centralOffset)
        archive.appendLittleEndian(UInt16(0))

        guard archive.count <= maximumArchiveSize else {
            throw SaveArchiveError.invalidArchive("ZIP archive exceeds the supported size")
        }
        return archive
    }

    static func decode(_ archive: Data) throws -> [String: Data] {
        guard archive.count <= maximumArchiveSize else {
            throw SaveArchiveError.invalidArchive("ZIP archive exceeds the supported size")
        }
        guard let endOffset = findEndRecord(in: archive) else {
            throw SaveArchiveError.invalidArchive("ZIP end record is missing")
        }

        let disk = try archive.readUInt16LE(at: endOffset + 4)
        let centralDisk = try archive.readUInt16LE(at: endOffset + 6)
        let entriesOnDisk = try archive.readUInt16LE(at: endOffset + 8)
        let entryCount = try archive.readUInt16LE(at: endOffset + 10)
        let centralSize = try archive.readUInt32LE(at: endOffset + 12)
        let centralOffset = try archive.readUInt32LE(at: endOffset + 16)
        guard disk == 0, centralDisk == 0, entriesOnDisk == entryCount else {
            throw SaveArchiveError.invalidArchive("multi-disk ZIP archives are unsupported")
        }
        guard Int(centralOffset) + Int(centralSize) <= endOffset else {
            throw SaveArchiveError.invalidArchive("ZIP central directory is out of bounds")
        }

        var cursor = Int(centralOffset)
        var entries: [String: Data] = [:]
        for _ in 0..<Int(entryCount) {
            guard try archive.readUInt32LE(at: cursor) == centralHeaderSignature else {
                throw SaveArchiveError.invalidArchive("invalid ZIP central directory header")
            }
            let flags = try archive.readUInt16LE(at: cursor + 8)
            let method = try archive.readUInt16LE(at: cursor + 10)
            let checksum = try archive.readUInt32LE(at: cursor + 16)
            let compressedSize = try archive.readUInt32LE(at: cursor + 20)
            let uncompressedSize = try archive.readUInt32LE(at: cursor + 24)
            let nameLength = Int(try archive.readUInt16LE(at: cursor + 28))
            let extraLength = Int(try archive.readUInt16LE(at: cursor + 30))
            let commentLength = Int(try archive.readUInt16LE(at: cursor + 32))
            let startDisk = try archive.readUInt16LE(at: cursor + 34)
            let localOffset = Int(try archive.readUInt32LE(at: cursor + 42))
            let nameStart = cursor + 46
            let recordEnd = nameStart + nameLength + extraLength + commentLength

            guard recordEnd <= archive.count,
                  method == 0,
                  compressedSize == uncompressedSize,
                  Int(uncompressedSize) <= maximumEntrySize,
                  flags & 0x0009 == 0,
                  startDisk == 0 else {
                throw SaveArchiveError.invalidArchive("unsupported or malformed ZIP entry")
            }
            let nameData = try archive.checkedSubdata(in: nameStart..<(nameStart + nameLength))
            guard let name = String(data: nameData, encoding: .utf8) else {
                throw SaveArchiveError.invalidArchive("ZIP entry name is not UTF-8")
            }
            try validateEntryName(name)
            guard entries[name] == nil else {
                throw SaveArchiveError.invalidArchive("duplicate ZIP entry: \(name)")
            }

            let contents = try readLocalEntry(
                archive,
                offset: localOffset,
                expectedName: name,
                expectedFlags: flags,
                expectedChecksum: checksum,
                expectedSize: uncompressedSize
            )
            entries[name] = contents
            cursor = recordEnd
        }

        guard cursor == Int(centralOffset) + Int(centralSize) else {
            throw SaveArchiveError.invalidArchive("ZIP central directory size mismatch")
        }
        return entries
    }

    private static func readLocalEntry(
        _ archive: Data,
        offset: Int,
        expectedName: String,
        expectedFlags: UInt16,
        expectedChecksum: UInt32,
        expectedSize: UInt32
    ) throws -> Data {
        guard try archive.readUInt32LE(at: offset) == localHeaderSignature else {
            throw SaveArchiveError.invalidArchive("invalid ZIP local header")
        }
        let flags = try archive.readUInt16LE(at: offset + 6)
        let method = try archive.readUInt16LE(at: offset + 8)
        let checksum = try archive.readUInt32LE(at: offset + 14)
        let compressedSize = try archive.readUInt32LE(at: offset + 18)
        let uncompressedSize = try archive.readUInt32LE(at: offset + 22)
        let nameLength = Int(try archive.readUInt16LE(at: offset + 26))
        let extraLength = Int(try archive.readUInt16LE(at: offset + 28))
        let nameStart = offset + 30
        let nameData = try archive.checkedSubdata(in: nameStart..<(nameStart + nameLength))
        let dataStart = nameStart + nameLength + extraLength
        let dataEnd = dataStart + Int(compressedSize)

        guard String(data: nameData, encoding: .utf8) == expectedName,
              flags == expectedFlags,
              method == 0,
              checksum == expectedChecksum,
              compressedSize == expectedSize,
              uncompressedSize == expectedSize else {
            throw SaveArchiveError.invalidArchive("ZIP local and central records disagree")
        }
        let contents = try archive.checkedSubdata(in: dataStart..<dataEnd)
        guard CRC32.checksum(contents) == expectedChecksum else {
            throw SaveArchiveError.invalidArchive("ZIP CRC mismatch: \(expectedName)")
        }
        return contents
    }

    private static func findEndRecord(in archive: Data) -> Int? {
        guard archive.count >= 22 else { return nil }
        let minimum = max(0, archive.count - 65_557)
        for offset in stride(from: archive.count - 22, through: minimum, by: -1) {
            if (try? archive.readUInt32LE(at: offset)) == endSignature,
               let commentLength = try? archive.readUInt16LE(at: offset + 20),
               offset + 22 + Int(commentLength) == archive.count {
                return offset
            }
        }
        return nil
    }

    private static func validateEntryName(_ name: String) throws {
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        guard !name.isEmpty,
              !name.hasPrefix("/"),
              !name.contains("\\"),
              !name.contains(":"),
              !components.contains(".."),
              !components.contains(".") else {
            throw SaveArchiveError.invalidArchive("unsafe ZIP entry name: \(name)")
        }
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }

    func readUInt16LE(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else {
            throw SaveArchiveError.invalidArchive("ZIP read is out of bounds")
        }
        let start = startIndex + offset
        return UInt16(self[start]) | UInt16(self[start + 1]) << 8
    }

    func readUInt32LE(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else {
            throw SaveArchiveError.invalidArchive("ZIP read is out of bounds")
        }
        let start = startIndex + offset
        return UInt32(self[start])
            | UInt32(self[start + 1]) << 8
            | UInt32(self[start + 2]) << 16
            | UInt32(self[start + 3]) << 24
    }

    func checkedSubdata(in range: Range<Int>) throws -> Data {
        guard range.lowerBound >= 0, range.upperBound <= count else {
            throw SaveArchiveError.invalidArchive("ZIP entry is out of bounds")
        }
        return subdata(in: range)
    }
}
