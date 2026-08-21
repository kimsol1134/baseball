package com.solkim.baseball.core.portrait

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class AvatarPartsTest {
    @Test
    fun hashMatchesFnv1aVectors() {
        assertEquals(0x811c9dc5u, AvatarParts.hash(""))
        assertEquals(0xe40c292cu, AvatarParts.hash("a"))
        assertEquals(0xbf9cf968u, AvatarParts.hash("foobar"))
    }

    @Test
    fun sameSeedGivesSameFace() {
        assertEquals(AvatarParts.of("김도현", AvatarRole.COACH), AvatarParts.of("김도현", AvatarRole.COACH))
    }

    @Test
    fun roleChangesTheFace() {
        assertNotEquals(AvatarParts.of("김도현", AvatarRole.COACH), AvatarParts.of("김도현", AvatarRole.CATCHER))
    }

    @Test
    fun facesVaryAcrossNames() {
        val names = listOf("김도현", "박서준", "이민재", "최우성", "정하늘", "강태현", "윤지호", "임건우", "오세훈", "한동엽", "신재호", "조민석", "배성우", "노경민", "황시원", "문재윤")
        val faces = names.map { AvatarParts.of(it, AvatarRole.PLAYER) }
        assertTrue(faces.map { it.skinIndex }.toSet().size >= 3)
        assertEquals(names.size, faces.toSet().size)
    }

    @Test
    fun rivalAlwaysWearsHeadgear() {
        listOf("문재윤", "강태현", "정하늘", "임건우").forEach {
            assertTrue(AvatarParts.of(it, AvatarRole.RIVAL).showHat)
        }
    }
}
