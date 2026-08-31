package com.solkim.baseball.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class AppLayerBoundaryTest {
    @Test
    fun appSourcesDoNotImportGameCore() {
        val roots = listOf(File("src/main"), File("src/androidTest")).filter { it.exists() }
        assertTrue("app source roots", roots.isNotEmpty())
        val hits = roots.flatMap { root ->
            root.walkTopDown()
                .filter { it.isFile && (it.extension == "kt" || it.extension == "java") }
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
}
