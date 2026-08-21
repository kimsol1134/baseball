package com.solkim.baseball.core.portrait

/** Desktop/iOS FNV-1a 32-bit face recipe. Same name always yields the same face. */
public data class AvatarParts(
    val skinIndex: Int,
    val hairColorIndex: Int,
    val jerseyIndex: Int,
    val faceShape: Int,
    val eyeStyle: Int,
    val browStyle: Int,
    val mouthStyle: Int,
    val hairStyle: Int,
    val cheekMark: Boolean,
    val agedCoach: Boolean,
    val showHat: Boolean,
    val role: AvatarRole,
) {
    public val faceRadiusX: Double get() = if (faceShape == 0) 13.5 else if (faceShape == 1) 12.2 else 14.5
    public val faceRadiusY: Double get() = if (faceShape == 1) 15.8 else 14.6

    public companion object {
        public fun hash(seed: String): UInt {
            var value = 0x811c9dc5u
            for (byte in seed.encodeToByteArray()) {
                value = value xor byte.toUByte().toUInt()
                value *= 0x01000193u
            }
            return value
        }

        public fun of(seed: String, role: AvatarRole): AvatarParts {
            val hashed = hash("${role.wire}:$seed")
            fun pick(shift: Int, count: Int): Int = ((hashed shr shift) % count.toUInt()).toInt()
            val agedCoach = role == AvatarRole.COACH && pick(21, 3) > 0
            return AvatarParts(
                skinIndex = pick(0, 5),
                hairColorIndex = if (agedCoach) 3 else pick(3, 3),
                jerseyIndex = pick(6, 5),
                faceShape = pick(9, 3),
                eyeStyle = pick(11, 3),
                browStyle = pick(13, 3),
                mouthStyle = pick(15, 4),
                hairStyle = pick(17, 5),
                cheekMark = pick(19, 4) == 0,
                agedCoach = agedCoach,
                showHat = role == AvatarRole.PLAYER || role == AvatarRole.RIVAL || (role == AvatarRole.COACH && pick(20, 2) == 0),
                role = role,
            )
        }
    }
}

public enum class AvatarRole(public val wire: String) {
    PLAYER("player"),
    COACH("coach"),
    CATCHER("catcher"),
    RIVAL("rival"),
}
