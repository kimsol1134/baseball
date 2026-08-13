enum StableHash {
    static func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return String(format: "%016llx", hash)
    }

    static func fnv1a64Value(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}

/// A display-only identity key that keeps one player's generated portrait stable across every
/// screen and save. It intentionally does not participate in simulation commitments or RNG.
public enum PlayerAppearanceSeed {
    public static func make(careerSeed: String, lifeNumber: Int) -> String {
        "player-\(StableHash.fnv1a64("\(careerSeed)|life:\(max(1, lifeNumber))|appearance-v1"))"
    }
}
