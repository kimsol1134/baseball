enum StableHash {
    static func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return String(format: "%016llx", hash)
    }
}

