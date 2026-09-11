package com.solkim.baseball.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class AppLayerBoundaryTest {
    @Test
    fun localeChromeHasKoreanEnglishAndJapaneseOpeningAutoReleaseAndHoldLabels() {
        val korean = readStrings("src/main/res/values/strings.xml")
        val english = readStrings("src/main/res/values-en/strings.xml")
        val japanese = readStrings("src/main/res/values-ja/strings.xml")
        assertTrue(korean.getValue("opening_what_this_is").contains("투구 슬라이더"))
        assertTrue(korean.getValue("settings_auto_release").contains("자동 릴리스"))
        assertEquals("누르고 있다가 놓기", korean.getValue("pitch_hold_to_release"))
        listOf("opening_what_this_is", "settings_auto_release", "pitch_hold_to_release").forEach { key ->
            val en = english.getValue(key)
            val ja = japanese.getValue(key)
            assertTrue("$key english blank", en.isNotBlank())
            assertTrue("$key japanese blank", ja.isNotBlank())
            assertTrue("$key english still korean", en != korean.getValue(key))
            assertTrue("$key japanese still korean", ja != korean.getValue(key))
        }
    }

    @Test
    fun appSourcesDoNotImportGameCore() {
        val roots = listOf(File("src/main"), File("src/androidTest"), File("src/test")).filter { it.exists() }
        assertTrue("app source roots", roots.isNotEmpty())
        val hits = roots.flatMap { root ->
            root.walkTopDown()
                .filter { it.isFile && (it.extension == "kt" || it.extension == "java") && it.name != "AppLayerBoundaryTest.kt" }
                .flatMap { file ->
                    file.readLines().mapIndexedNotNull { index, line ->
                        if (line.contains("com.solkim.baseball.core")) {
                            "${file.path}:${index + 1}: ${line.trim()}"
                        } else {
                            null
                        }
                    }
                }
        }
        assertFalse(
            "app must route core types through game-application:\n${hits.joinToString("\n")}",
            hits.isNotEmpty(),
        )
    }

    private fun readStrings(path: String): Map<String, String> {
        val file = File(path)
        assertTrue("missing $path at ${file.absolutePath}", file.isFile)
        val text = file.readText()
        val matches = Regex("""<string name="([^"]+)">([^<]*)</string>""").findAll(text)
        return matches.associate { it.groupValues[1] to it.groupValues[2].replace("\\'", "'") }
    }
}
