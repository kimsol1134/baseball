package com.solkim.baseball.application

import kotlin.test.*

class Round5RetentionTest {
    @Test fun nativeCompactionSurvivesRestartAndBackupWithoutReapplyingEvictedCommands() = kotlinx.coroutines.runBlocking {
        val dir = java.nio.file.Files.createTempDirectory("round5-retention-")
        var store = KotlinGameStore.open("r5", CSharpLegacyGameStoreRepository(dir, "r5"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val source = com.solkim.baseball.model.StrictJson.parseUtf8(javaClass.getResourceAsStream("/regression/round4-pro-week.json")!!.readBytes()) as com.solkim.baseball.model.JsonValue.Obj
            val payload = source["payload"] as com.solkim.baseball.model.JsonValue.Obj
            val historical = (0..2000).map { CommandReceiptRetention.id(it.toULong(), "settings") } + "phase7-legacy"
            val fixture = com.solkim.baseball.model.JsonValue.Obj(LinkedHashMap(payload.entries).apply {
                put("revision", com.solkim.baseball.model.JsonValue.Num("3000"))
                put("commandReceipts", com.solkim.baseball.model.JsonValue.Arr(historical.map(com.solkim.baseball.model.JsonValue::Str)))
            })
            store.importCareerBackup(CareerBackup.encode(fixture), store.current.revision)
            val pro = store.current.pro
            val id = CommandReceiptRetention.id(store.current.revision, "settings")
            store.dispatch(GameCommandEnvelope(id, "settings", store.current.revision, GameCommand.UpdateSettings(store.current.settings)))
            val backup = store.exportCareerBackup()
            store.close()
            store = KotlinGameStore.open("r5", CSharpLegacyGameStoreRepository(dir, "r5"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            val saved = com.solkim.baseball.model.StrictJson.parseUtf8(java.nio.file.Files.readAllBytes(dir.resolve("save.json"))) as com.solkim.baseball.model.JsonValue.Obj
            val receipts = (saved["payload"] as com.solkim.baseball.model.JsonValue.Obj).stringArray("commandReceipts")
            assertEquals(257, receipts.size); assertTrue("phase7-legacy" in receipts); assertEquals(pro, store.current.pro)
            val revision = store.current.revision
            assertFails { store.dispatch(GameCommandEnvelope(historical.first(), "settings", revision, GameCommand.UpdateSettings(store.current.settings))) }
            assertEquals(revision, store.current.revision)
            store.importCareerBackup(backup, revision)
            assertEquals(pro, store.current.pro)
            assertFails { store.dispatch(GameCommandEnvelope(id, "settings", store.current.revision, GameCommand.UpdateSettings(store.current.settings))) }
        } finally { store.close(); dir.toFile().deleteRecursively() }
        Unit
    }
    @Test fun receiptsKeepNewestRevisionsNotLexicallyLargestIdsAndPreserveOpaqueHistory() {
        val ids = (0..2000).map { CommandReceiptRetention.id(it.toULong(), "pitch") }
        val retained = CommandReceiptRetention.retain(ids.shuffled() + listOf("phase7-old-hash", "manual-release:old"))
        assertEquals(258, retained.size)
        assertTrue("phase7-old-hash" in retained)
        assertEquals((1745..2000).map { it.toULong() }.toSet(), retained.mapNotNull(CommandReceiptRetention::revision).toSet())
        assertEquals(retained, CommandReceiptRetention.retain(retained))
        assertFailsWith<IllegalArgumentException> { CommandReceiptRetention.validate(ids.first(), 2001UL) }
        assertFailsWith<IllegalArgumentException> { CommandReceiptRetention.validate("phase8-P-019-action-42-0", 2001UL) }
        CommandReceiptRetention.validate(ids.last(), 2000UL)
    }

    @Test fun replayBudgetPreservesOldReplaysAndEveryScorecard() {
        val original = PlayerAlbumPage(RecordScope("pro:test:1", "season", "player"), 8, 100, 4, 20, true, emptyList())
        var page = original
        repeat(1000) { i ->
            val pitch = AlbumPitch("$i", "four_seam", 1400, List(100) { it })
            page = page.copy(pitches = AlbumReplayRetention.append(listOf(page), page, pitch))
        }
        assertEquals(128, page.pitches.size)
        assertEquals(original, page.copy(pitches = emptyList()))
        assertEquals(page, PlayerAlbumCodec.decode(PlayerAlbumCodec.encode(listOf(page))).single())
        val imported = page.copy(pitches = (0..200).map { AlbumPitch("$it", "four_seam", 1400, listOf(1, 2, 3, 4)) })
        assertEquals(imported.pitches, AlbumReplayRetention.append(listOf(imported), imported, AlbumPitch("new", "four_seam", 1400, emptyList())))
    }

    @Test fun totalReplayCountAndTrajectoryBudgetApplyAcrossSeasons() {
        val pages = (0..3).map { season -> PlayerAlbumPage(RecordScope("pro:test:$season", "season", "player"), 0, 0, 0, 0, true, emptyList(),
            (0..127).map { AlbumPitch("$it", "four_seam", 1400, listOf(1, 2, 3, 4)) }) }
        val fresh = pages.first().copy(scope = RecordScope("pro:test:4", "season", "player"), pitches = emptyList())
        assertTrue(AlbumReplayRetention.append(pages + fresh, fresh, AlbumPitch("new", "four_seam", 1400, emptyList())).isEmpty())
        val large = fresh.copy(pitches = (0..15).map { AlbumPitch("$it", "four_seam", 1400, List(4096) { it }) })
        assertTrue(AlbumReplayRetention.append(listOf(large, fresh), fresh, AlbumPitch("new", "four_seam", 1400, listOf(1,2,3,4))).isEmpty())
    }
}
